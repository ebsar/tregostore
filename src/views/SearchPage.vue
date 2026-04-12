<script setup>
import { computed, onBeforeUnmount, onMounted, reactive, ref, watch } from "vue";
import { RouterLink, useRoute, useRouter } from "vue-router";
import { fetchProtectedCollection, requestJson, resolveApiMessage, searchProductsByImage } from "../lib/api";
import { deriveSectionFromCategory } from "../lib/product-catalog";
import { clearRecentSearches, readRecentSearches, rememberRecentSearch, removeRecentSearch } from "../lib/search-history";
import {
  formatCategoryLabel,
  formatPrice,
  getProductDetailUrl,
  hasProductAvailableStock,
} from "../lib/shop";
import { consumePendingVisualSearchFile } from "../lib/visual-search-transfer";
import {
  compareState,
  ensureCompareItemsLoaded,
  toggleComparedProduct,
} from "../stores/product-compare";
import { appState, ensureSessionLoaded, markRouteReady, setCartItems } from "../stores/app-state";

const route = useRoute();
const router = useRouter();
const SEARCH_INPUT_DEBOUNCE_MS = 320;
const SEARCH_GRID_PAGE_SIZE = 8;
const SEARCH_SERVER_PAGE_SIZE = SEARCH_GRID_PAGE_SIZE;
const SEARCH_VISUAL_FETCH_LIMIT = 48;
const SEARCH_PRICE_SLIDER_DEFAULT_MAX = 10000;
const SMART_SEARCH_MARKERS = new Set(["dua", "doja", "kerkoj", "kerko", "trego", "shfaq", "gjej"]);
const GROUPED_PAGE_SECTIONS = new Set(["clothing", "cosmetics"]);
const SEARCH_PROMPT_SUGGESTIONS = [
  "me trego maica te kuqe",
  "dua atlete te bardha",
  "kerkoj produkte per shtepi",
];
const draftQuery = ref("");
const recentSearches = ref([]);
const products = ref([]);
const availableFilters = ref(createEmptyProductFacets());
const wishlistIds = ref([]);
const cartIds = ref([]);
const busyWishlistIds = ref([]);
const busyCartIds = ref([]);
const totalProductsCount = ref(0);
const filtersVisible = ref(false);
const visualSearchInputElement = ref(null);
const visualSearchFile = ref(null);
const visualSearchPreviewUrl = ref("");
const visualSearchFileName = ref("");
const visualSearchActive = ref(false);
const visualSearchBusy = ref(false);
const currentGridPage = ref(1);
const selectedBrands = ref([]);
const minPriceInput = ref("");
const maxPriceInput = ref("");
const selectedPriceRange = ref("");
const filters = reactive({
  pageSection: "",
  category: "",
  productType: "",
  size: "",
  color: "",
  sort: "popular",
});
const ui = reactive({
  message: "",
  type: "",
});
let searchDebounceTimeoutId = 0;
let catalogRequestId = 0;

const activeQuery = computed(() => String(route.query.q || "").trim());
const featuredCollection = computed(() => String(route.query.featured || "").trim().toLowerCase());
const availablePageSectionOptions = computed(() => availableFilters.value.pageSections);
const availableCategoryOptions = computed(() =>
  !filters.pageSection || !GROUPED_PAGE_SECTIONS.has(filters.pageSection)
    ? []
    : availableFilters.value.categories.filter((option) =>
        String(option.pageSection || "") === filters.pageSection,
      ),
);
const availableProductTypeOptions = computed(() =>
  !filters.pageSection
    ? []
    : availableFilters.value.productTypes.filter((option) => {
        const matchesSection = String(option.pageSection || "") === filters.pageSection;
        const hasNestedCategories = availableCategoryOptions.value.length > 0;
        const matchesCategory = !hasNestedCategories || String(option.category || "") === filters.category;
        return matchesSection && matchesCategory;
      }),
);
const availableSizeOptions = computed(() => availableFilters.value.sizes);
const availableColorOptions = computed(() => availableFilters.value.colors);
const shouldShowProductTypeFilter = computed(() => {
  if (!filters.pageSection || availableProductTypeOptions.value.length === 0) {
    return false;
  }

  return availableCategoryOptions.value.length === 0 || Boolean(filters.category);
});
const shouldRequestFacets = computed(() => true);
const comparedProductIds = computed(() =>
  compareState.items
    .map((item) => Number(item.id || item.productId || 0))
    .filter((id) => Number.isFinite(id) && id > 0),
);
const sidebarCategoryOptions = computed(() => {
  const nestedCategoryOptions = availableCategoryOptions.value.length > 0
    ? availableCategoryOptions.value.map((option) => ({
        ...option,
        kind: "category",
      }))
    : [];

  if (nestedCategoryOptions.length > 0) {
    return [
      { value: "", label: "All Category", kind: "clear" },
      ...nestedCategoryOptions,
    ];
  }

  return [
    { value: "", label: "All Category", kind: "clear" },
    ...availablePageSectionOptions.value.map((option) => ({
      ...option,
      kind: "pageSection",
    })),
  ];
});
const activeSidebarCategoryValue = computed(() => filters.category || filters.pageSection || "");
const popularBrandOptions = computed(() => {
  if (Array.isArray(availableFilters.value.brands) && availableFilters.value.brands.length > 0) {
    return availableFilters.value.brands
      .slice(0, 8)
      .map((brand) => ({
        label: String(brand.label || brand.value || "").trim(),
        count: Number(brand.count || 0),
      }))
      .filter((brand) => brand.label);
  }

  const counts = new Map();

  products.value.forEach((product) => {
    const label = getProductBrandLabel(product);
    if (!label) {
      return;
    }

    counts.set(label, (counts.get(label) || 0) + 1);
  });

  return [...counts.entries()]
    .sort((left, right) => right[1] - left[1] || left[0].localeCompare(right[0]))
    .slice(0, 6)
    .map(([label, count]) => ({ label, count }));
});
const totalGridPageCount = computed(() =>
  Math.max(
    1,
    Math.ceil(
      (visualSearchActive.value ? filteredProducts.value.length : totalProductsCount.value) / SEARCH_GRID_PAGE_SIZE,
    ),
  ),
);
const paginatedProducts = computed(() => {
  if (!visualSearchActive.value) {
    return products.value;
  }

  const start = (currentGridPage.value - 1) * SEARCH_GRID_PAGE_SIZE;
  return filteredProducts.value.slice(start, start + SEARCH_GRID_PAGE_SIZE);
});
const visibleGridPages = computed(() => {
  const totalPages = totalGridPageCount.value;
  if (totalPages <= 6) {
    return Array.from({ length: totalPages }, (_, index) => index + 1);
  }

  let start = Math.max(1, currentGridPage.value - 2);
  let end = Math.min(totalPages, start + 5);
  start = Math.max(1, end - 5);

  return Array.from({ length: end - start + 1 }, (_, index) => start + index);
});
const activeFilterChips = computed(() => {
  const nextChips = [];

  if (activeSidebarCategoryValue.value) {
    nextChips.push({
      key: `category-${activeSidebarCategoryValue.value}`,
      label: getFacetOptionLabel(
        sidebarCategoryOptions.value,
        activeSidebarCategoryValue.value,
        activeSidebarCategoryValue.value,
      ),
      type: "category",
    });
  }

  if (selectedPriceRange.value) {
    nextChips.push({
      key: `price-${selectedPriceRange.value}`,
      label: getPriceRangeLabel(selectedPriceRange.value),
      type: "price-range",
    });
  } else if (minPriceInput.value || maxPriceInput.value) {
    const minLabel = minPriceInput.value ? `$${minPriceInput.value}` : "$0";
    const maxLabel = maxPriceInput.value ? `$${maxPriceInput.value}` : "Any";
    nextChips.push({
      key: "price-custom",
      label: `${minLabel} - ${maxLabel}`,
      type: "price-custom",
    });
  }

  selectedBrands.value.forEach((brand) => {
    nextChips.push({
      key: `brand-${brand}`,
      label: brand,
      type: "brand",
      value: brand,
    });
  });

  return nextChips;
});
const formattedResultsCount = computed(() =>
  new Intl.NumberFormat("en-US").format(
    visualSearchActive.value ? filteredProducts.value.length : totalProductsCount.value,
  ),
);
const breadcrumbTail = computed(() => {
  if (filters.category) {
    return getFacetOptionLabel(availableCategoryOptions.value, filters.category, formatCategoryLabel(filters.category));
  }

  if (filters.pageSection) {
    return getFacetOptionLabel(availablePageSectionOptions.value, filters.pageSection, formatCategoryLabel(filters.pageSection));
  }

  if (activeQuery.value) {
    return activeQuery.value;
  }

  return "Shop Grid";
});
const priceSliderBounds = computed(() => {
  const pricePoints = products.value
    .map((product) => Number(product?.price || 0))
    .filter((value) => Number.isFinite(value) && value > 0);
  const highestPrice = pricePoints.length > 0 ? Math.max(...pricePoints) : SEARCH_PRICE_SLIDER_DEFAULT_MAX;
  const normalizedMax = Math.max(
    SEARCH_PRICE_SLIDER_DEFAULT_MAX,
    Math.ceil(highestPrice / 10) * 10,
  );

  return {
    min: 0,
    max: normalizedMax,
  };
});
const priceSliderValues = computed(() => {
  const { min, max } = priceSliderBounds.value;
  const { minPrice, maxPrice } = resolveActivePriceBounds();

  return {
    minValue: Number.isFinite(minPrice) ? minPrice : min,
    maxValue: Number.isFinite(maxPrice) ? maxPrice : max,
  };
});
const priceTrackStyle = computed(() => {
  const { min, max } = priceSliderBounds.value;
  const { minValue, maxValue } = priceSliderValues.value;
  const span = Math.max(1, max - min);
  const start = Math.max(0, Math.min(100, ((minValue - min) / span) * 100));
  const end = Math.max(start, Math.min(100, ((maxValue - min) / span) * 100));

  return {
    "--track-start": `${start}%`,
    "--track-end": `${end}%`,
  };
});

const filteredProducts = computed(() => {
  const nextProducts = [...products.value];
  if (!visualSearchActive.value) {
    return nextProducts;
  }

  if (selectedBrands.value.length > 0) {
    const activeBrandSet = new Set(selectedBrands.value);
    const brandFilteredProducts = nextProducts.filter((product) =>
      activeBrandSet.has(getProductBrandLabel(product)),
    );
    nextProducts.splice(0, nextProducts.length, ...brandFilteredProducts);
  }

  const { minPrice, maxPrice } = resolveActivePriceBounds();
  if (Number.isFinite(minPrice) || Number.isFinite(maxPrice)) {
    const priceFilteredProducts = nextProducts.filter((product) => {
      const price = Number(product?.price || 0);
      if (!Number.isFinite(price)) {
        return false;
      }

      if (Number.isFinite(minPrice) && price < minPrice) {
        return false;
      }

      if (Number.isFinite(maxPrice) && price > maxPrice) {
        return false;
      }

      return true;
    });
    nextProducts.splice(0, nextProducts.length, ...priceFilteredProducts);
  }

  if (filters.sort === "price-asc") {
    nextProducts.sort((left, right) => Number(left.price || 0) - Number(right.price || 0));
  } else if (filters.sort === "price-desc") {
    nextProducts.sort((left, right) => Number(right.price || 0) - Number(left.price || 0));
  } else if (filters.sort === "rating") {
    nextProducts.sort((left, right) => getProductAverageRating(right) - getProductAverageRating(left));
  } else if (filters.sort === "newest") {
    nextProducts.sort((left, right) =>
      new Date(String(right.createdAt || "")).getTime() - new Date(String(left.createdAt || "")).getTime(),
    );
  } else if (featuredCollection.value === "best-sellers") {
    nextProducts.sort((left, right) => getProductPopularityScore(right) - getProductPopularityScore(left));
  } else {
    nextProducts.sort((left, right) => getProductPopularityScore(right) - getProductPopularityScore(left));
  }

  return nextProducts;
});

const searchTitle = computed(() =>
  featuredCollection.value === "best-sellers" && !activeQuery.value
    ? "Produktet me te shitura"
    : "Kerko produktet",
);

const searchIntro = computed(() => {
  if (featuredCollection.value === "best-sellers" && !activeQuery.value) {
    return "Po shfaqen produktet qe po levizin me shpejt ne marketplace sipas shitjeve, reviews dhe interesit real.";
  }

  return "Shkruaj p.sh. `me trego maica te kuqe`, `dua pantallona te gjera` ose fotografo produktin me kamerë.";
});

const resultsLabel = computed(() => {
  if (visualSearchActive.value) {
    const visibleVisualProducts = filteredProducts.value.length;
    if (!products.value.length) {
      return "Nuk u gjet asnje produkt i ngjashem sipas fotos.";
    }

    return totalProductsCount.value > visibleVisualProducts
      ? `Po shfaqen ${visibleVisualProducts} nga ${totalProductsCount.value} produkte te ngjashme sipas fotos.`
      : `Po shfaqen ${visibleVisualProducts} produkte te ngjashme sipas fotos.`;
  }

  if (!products.value.length) {
    if (featuredCollection.value === "best-sellers" && !activeQuery.value) {
      return "Nuk ka produkte te shitura ende ne kete liste.";
    }

    return "Nuk u gjet asnje produkt per kete kerkim.";
  }

  const scopeParts = [];
  if (activeQuery.value) {
    scopeParts.push(`kerkimin "${activeQuery.value}"`);
  }

  if (filters.category) {
    scopeParts.push(
      getFacetOptionLabel(
        availableCategoryOptions.value,
        filters.category,
        formatCategoryLabel(filters.category),
      ),
    );
  } else if (filters.pageSection) {
    scopeParts.push(
      getFacetOptionLabel(
        availablePageSectionOptions.value,
        filters.pageSection,
        filters.pageSection,
      ),
    );
  }

  if (filters.productType) {
    scopeParts.push(
      getFacetOptionLabel(
        availableProductTypeOptions.value,
        filters.productType,
        filters.productType,
      ),
    );
  }

  if (filters.size) {
    scopeParts.push(`madhesia ${filters.size}`);
  }

  if (filters.color) {
    scopeParts.push(
      getFacetOptionLabel(
        availableColorOptions.value,
        filters.color,
        filters.color,
      ),
    );
  }

  const scopeLabel = scopeParts.length ? ` per ${scopeParts.join(" • ")}` : "";
  return totalProductsCount.value > products.value.length
    ? `Po shfaqen ${products.value.length} nga ${totalProductsCount.value} produkte${scopeLabel}.`
    : `Po shfaqen ${products.value.length} produkte${scopeLabel}.`;
});
function getProductAverageRating(product) {
  const rawValue = Number(product?.averageRating ?? product?.ratingAverage ?? 0);
  if (!Number.isFinite(rawValue) || rawValue <= 0) {
    return 0;
  }

  return Math.max(0, Math.min(5, rawValue));
}

function getProductFilledStars(product) {
  return Math.max(0, Math.min(5, Math.round(getProductAverageRating(product))));
}

function getProductRatingSummary(product) {
  const averageRating = getProductAverageRating(product);
  return averageRating > 0 ? averageRating.toFixed(1) : "0.0";
}

function getProductReviewCount(product) {
  const rawValue = Number(product?.reviewCount || 0);
  if (!Number.isFinite(rawValue) || rawValue <= 0) {
    return 0;
  }

  return Math.max(0, Math.trunc(rawValue));
}

function getProductUnitLabel(product) {
  const unit = String(product?.packageAmountUnit || "").trim();
  if (!unit) {
    return "";
  }

  return `/ ${unit}`;
}

function getProductMetaLine(product) {
  const productType = String(product?.productType || "").trim();
  const category = formatCategoryLabel(product?.category || "");
  return [productType, category].filter(Boolean).join(" • ");
}

function getProductBrandLabel(product) {
  return String(product?.businessName || "").trim() || "Marketplace";
}

function normalizePriceInputValue(value) {
  const parsedValue = Number(String(value || "").replace(/[^\d.]/g, ""));
  if (!Number.isFinite(parsedValue) || parsedValue < 0) {
    return null;
  }

  return parsedValue;
}

function formatPriceInputDisplay(value) {
  if (!Number.isFinite(value)) {
    return "";
  }

  return Number.isInteger(value) ? String(value) : String(Math.round(value * 100) / 100);
}

function getPriceRangeBounds(value) {
  switch (value) {
    case "under-20":
      return { minPrice: 0, maxPrice: 20 };
    case "25-100":
      return { minPrice: 25, maxPrice: 100 };
    case "100-300":
      return { minPrice: 100, maxPrice: 300 };
    case "300-500":
      return { minPrice: 300, maxPrice: 500 };
    case "500-1000":
      return { minPrice: 500, maxPrice: 1000 };
    case "1000-10000":
      return { minPrice: 1000, maxPrice: 10000 };
    default:
      return { minPrice: null, maxPrice: null };
  }
}

function normalizeResolvedPriceBounds(minPrice, maxPrice) {
  const { min, max } = priceSliderBounds.value;
  let normalizedMin = Number.isFinite(minPrice) ? Math.max(min, Math.min(max, minPrice)) : null;
  let normalizedMax = Number.isFinite(maxPrice) ? Math.max(min, Math.min(max, maxPrice)) : null;

  if (Number.isFinite(normalizedMin) && Number.isFinite(normalizedMax) && normalizedMin > normalizedMax) {
    [normalizedMin, normalizedMax] = [normalizedMax, normalizedMin];
  }

  return {
    minPrice: normalizedMin,
    maxPrice: normalizedMax,
  };
}

function resolveActivePriceBounds() {
  if (selectedPriceRange.value) {
    const presetBounds = getPriceRangeBounds(selectedPriceRange.value);
    return normalizeResolvedPriceBounds(presetBounds.minPrice, presetBounds.maxPrice);
  }

  return normalizeResolvedPriceBounds(
    normalizePriceInputValue(minPriceInput.value),
    normalizePriceInputValue(maxPriceInput.value),
  );
}

function getPriceRangeLabel(value) {
  switch (value) {
    case "under-20":
      return "Under $20";
    case "25-100":
      return "$25 to $100";
    case "100-300":
      return "$100 to $300";
    case "300-500":
      return "$300 to $500";
    case "500-1000":
      return "$500 to $1,000";
    case "1000-10000":
      return "$1,000 to $10,000";
    default:
      return "All Price";
  }
}

function handleSidebarCategorySelect(option) {
  if (!option) {
    return;
  }

  currentGridPage.value = 1;

  if (option.kind === "clear") {
    filters.pageSection = "";
    filters.category = "";
    filters.productType = "";
    updateSearchRouteFromFilters();
    return;
  }

  if (option.kind === "category") {
    filters.pageSection = String(option.pageSection || filters.pageSection || "").trim().toLowerCase();
    filters.category = String(option.value || "").trim().toLowerCase();
    filters.productType = "";
    updateSearchRouteFromFilters();
    return;
  }

  filters.pageSection = String(option.value || "").trim().toLowerCase();
  filters.category = "";
  filters.productType = "";
  updateSearchRouteFromFilters();
}

function applyPriceInputs() {
  selectedPriceRange.value = "";
  const { min, max } = priceSliderBounds.value;
  const { minPrice, maxPrice } = normalizeResolvedPriceBounds(
    normalizePriceInputValue(minPriceInput.value),
    normalizePriceInputValue(maxPriceInput.value),
  );
  minPriceInput.value = Number.isFinite(minPrice) && minPrice > min ? formatPriceInputDisplay(minPrice) : "";
  maxPriceInput.value = Number.isFinite(maxPrice) && maxPrice < max ? formatPriceInputDisplay(maxPrice) : "";
  currentGridPage.value = 1;
  if (!visualSearchActive.value) {
    void loadProducts();
  }
}

function setPriceRange(value) {
  selectedPriceRange.value = value;
  minPriceInput.value = "";
  maxPriceInput.value = "";
  currentGridPage.value = 1;
  if (!visualSearchActive.value) {
    void loadProducts();
  }
}

function handlePriceSliderInput(which, event) {
  const { min, max } = priceSliderBounds.value;
  const rawValue = Number(event?.target?.value ?? min);
  if (!Number.isFinite(rawValue)) {
    return;
  }

  let nextMin = priceSliderValues.value.minValue;
  let nextMax = priceSliderValues.value.maxValue;

  if (which === "min") {
    nextMin = Math.min(Math.max(min, rawValue), nextMax);
  } else {
    nextMax = Math.max(Math.min(max, rawValue), nextMin);
  }

  selectedPriceRange.value = "";
  minPriceInput.value = nextMin > min ? formatPriceInputDisplay(nextMin) : "";
  maxPriceInput.value = nextMax < max ? formatPriceInputDisplay(nextMax) : "";
}

function toggleBrandFilter(brandLabel) {
  if (!brandLabel) {
    return;
  }

  if (selectedBrands.value.includes(brandLabel)) {
    selectedBrands.value = selectedBrands.value.filter((entry) => entry !== brandLabel);
  } else {
    selectedBrands.value = [...selectedBrands.value, brandLabel];
  }

  currentGridPage.value = 1;
  if (!visualSearchActive.value) {
    void loadProducts();
  }
}

function clearClientFilters(options = {}) {
  const { reload = true } = options;
  selectedPriceRange.value = "";
  selectedBrands.value = [];
  minPriceInput.value = "";
  maxPriceInput.value = "";
  currentGridPage.value = 1;
  if (reload && !visualSearchActive.value) {
    void loadProducts();
  }
}

function removeFilterChip(chip) {
  if (!chip) {
    return;
  }

  if (chip.type === "category") {
    filters.pageSection = "";
    filters.category = "";
    filters.productType = "";
    updateSearchRouteFromFilters();
    return;
  }

  if (chip.type === "price-range" || chip.type === "price-custom") {
    selectedPriceRange.value = "";
    minPriceInput.value = "";
    maxPriceInput.value = "";
    currentGridPage.value = 1;
    if (!visualSearchActive.value) {
      void loadProducts();
    }
    return;
  }

  if (chip.type === "brand" && chip.value) {
    selectedBrands.value = selectedBrands.value.filter((entry) => entry !== chip.value);
    currentGridPage.value = 1;
    if (!visualSearchActive.value) {
      void loadProducts();
    }
  }
}

function goToGridPage(page) {
  if (!Number.isFinite(page)) {
    return;
  }

  const nextPage = Math.min(Math.max(1, page), totalGridPageCount.value);
  if (nextPage === currentGridPage.value) {
    return;
  }

  currentGridPage.value = nextPage;
  if (!visualSearchActive.value) {
    void loadProducts();
  }
}

function goToPreviousGridPage() {
  goToGridPage(currentGridPage.value - 1);
}

function goToNextGridPage() {
  goToGridPage(currentGridPage.value + 1);
}

function getSearchResultBadge(product) {
  const compareAt = Number(product?.compareAtPrice ?? product?.originalPrice ?? 0);
  const price = Number(product?.price ?? 0);
  if (Number.isFinite(compareAt) && compareAt > price && price > 0) {
    return "Sale";
  }

  if (String(product?.createdAt || "").trim()) {
    return "New";
  }

  return "";
}

function isComparedProduct(product) {
  return comparedProductIds.value.includes(Number(product?.id || 0));
}

watch(
  () => route.fullPath,
  async () => {
    draftQuery.value = activeQuery.value;
    syncFiltersFromRoute();
    clearVisualSearchState();
    selectedBrands.value = [];
    selectedPriceRange.value = "";
    minPriceInput.value = "";
    maxPriceInput.value = "";
    currentGridPage.value = 1;
    await bootstrap();
  },
);

watch(draftQuery, (nextValue) => {
  window.clearTimeout(searchDebounceTimeoutId);
  const normalizedDraft = String(nextValue || "").trim();
  if (normalizedDraft === activeQuery.value) {
    return;
  }

  if (looksLikeNaturalLanguageSearch(normalizedDraft)) {
    return;
  }

  searchDebounceTimeoutId = window.setTimeout(() => {
    submitSearch();
  }, SEARCH_INPUT_DEBOUNCE_MS);
});

onMounted(async () => {
  ensureCompareItemsLoaded();
  recentSearches.value = readRecentSearches();
  draftQuery.value = activeQuery.value;
  syncFiltersFromRoute();
  await bootstrap();
});

onBeforeUnmount(() => {
  window.clearTimeout(searchDebounceTimeoutId);
  clearVisualSearchState();
});

watch(
  () => totalGridPageCount.value,
  (nextPageCount) => {
    if (currentGridPage.value > nextPageCount) {
      currentGridPage.value = nextPageCount;
    }
  },
);

watch(
  () => filters.sort,
  () => {
    currentGridPage.value = 1;
    if (!visualSearchActive.value) {
      void loadProducts();
    }
  },
);

watch(
  () => appState.catalogRevision,
  async (nextRevision, previousRevision) => {
    if (nextRevision === previousRevision) {
      return;
    }

    if (visualSearchActive.value && visualSearchFile.value) {
      await runVisualSearch();
      return;
    }

    await loadProducts();
  },
);

async function bootstrap() {
  try {
    const sessionPromise = ensureSessionLoaded()
      .then(() => refreshCollectionState())
      .catch((error) => {
        console.error(error);
      });
    const didApplyPendingVisualSearch = await applyPendingVisualSearch();

    if (!didApplyPendingVisualSearch) {
      await loadProducts();
    }

    markRouteReady();
    void sessionPromise;
  } catch (error) {
    ui.message = "Produktet nuk u ngarkuan. Provoje perseri.";
    ui.type = "error";
    console.error(error);
  } finally {
    if (!products.value.length) {
      markRouteReady();
    }
  }
}

async function refreshCollectionState() {
  if (!appState.user) {
    wishlistIds.value = [];
    cartIds.value = [];
    return;
  }

  const [wishlistItems, cartItems] = await Promise.all([
    fetchProtectedCollection("/api/wishlist"),
    fetchProtectedCollection("/api/cart"),
  ]);

  wishlistIds.value = wishlistItems.map((item) => item.id);
  cartIds.value = cartItems.map((item) => item.productId || item.id);
  setCartItems(cartItems);
}

function createEmptyProductFacets() {
  return {
    pageSections: [],
    categories: [],
    productTypes: [],
    sizes: [],
    colors: [],
    brands: [],
  };
}

function normalizeProductFacets(rawFacets) {
  return {
    pageSections: Array.isArray(rawFacets?.pageSections) ? rawFacets.pageSections : [],
    categories: Array.isArray(rawFacets?.categories) ? rawFacets.categories : [],
    productTypes: Array.isArray(rawFacets?.productTypes) ? rawFacets.productTypes : [],
    sizes: Array.isArray(rawFacets?.sizes) ? rawFacets.sizes : [],
    colors: Array.isArray(rawFacets?.colors) ? rawFacets.colors : [],
    brands: Array.isArray(rawFacets?.brands) ? rawFacets.brands : [],
  };
}

function getFacetOptionLabel(options, value, fallback = "") {
  return options.find((option) => option.value === value)?.label || fallback || value;
}

function syncFiltersFromRoute() {
  const pageSectionFromRoute = String(route.query.pageSection || "").trim().toLowerCase();
  const categoryFromRoute = String(route.query.category || "").trim().toLowerCase();
  const categoryGroupFromRoute = String(route.query.categoryGroup || "").trim().toLowerCase();
  const productTypeFromRoute = String(route.query.productType || "").trim().toLowerCase();

  if (categoryFromRoute) {
    filters.pageSection = deriveSectionFromCategory(categoryFromRoute);
    filters.category = categoryFromRoute;
  } else if (pageSectionFromRoute) {
    filters.pageSection = pageSectionFromRoute;
    filters.category = "";
  } else if (categoryGroupFromRoute) {
    filters.pageSection = categoryGroupFromRoute;
    filters.category = "";
  } else {
    filters.pageSection = "";
    filters.category = "";
  }

  filters.productType = productTypeFromRoute;
}

function applyServerActiveFilters(activeFilters = {}) {
  filters.pageSection = String(activeFilters.pageSection || filters.pageSection || "").trim().toLowerCase();
  filters.category = String(activeFilters.category || "").trim().toLowerCase();
  filters.productType = String(activeFilters.productType || "").trim().toLowerCase();
  filters.size = String(activeFilters.size || "").trim().toUpperCase();
  filters.color = String(activeFilters.color || "").trim().toLowerCase();
  filters.sort = String(activeFilters.sort || filters.sort || "popular").trim().toLowerCase() || "popular";
}

function buildSearchRouteQuery(nextQueryValue = draftQuery.value) {
  const normalizedQuery = String(nextQueryValue || "").trim();
  const nextQuery = {};

  if (normalizedQuery) {
    nextQuery.q = normalizedQuery;
  }

  if (filters.pageSection) {
    nextQuery.pageSection = filters.pageSection;
  }

  if (filters.category) {
    nextQuery.category = filters.category;
  }

  if (filters.productType) {
    nextQuery.productType = filters.productType;
  }

  if (featuredCollection.value) {
    nextQuery.featured = featuredCollection.value;
  }

  return nextQuery;
}

function routeQueryMatches(nextQuery) {
  const currentQuery = {
    q: String(route.query.q || "").trim(),
    pageSection: String(route.query.pageSection || "").trim().toLowerCase(),
    category: String(route.query.category || "").trim().toLowerCase(),
    productType: String(route.query.productType || "").trim().toLowerCase(),
    featured: String(route.query.featured || "").trim().toLowerCase(),
  };
  const normalizedNextQuery = {
    q: String(nextQuery.q || "").trim(),
    pageSection: String(nextQuery.pageSection || "").trim().toLowerCase(),
    category: String(nextQuery.category || "").trim().toLowerCase(),
    productType: String(nextQuery.productType || "").trim().toLowerCase(),
    featured: String(nextQuery.featured || "").trim().toLowerCase(),
  };

  return JSON.stringify(currentQuery) === JSON.stringify(normalizedNextQuery);
}

function updateSearchRouteFromFilters(nextQueryValue = draftQuery.value) {
  const nextQuery = buildSearchRouteQuery(nextQueryValue);
  if (routeQueryMatches(nextQuery)) {
    void loadProducts();
    return;
  }

  router.replace({
    path: "/kerko",
    query: nextQuery,
  });
}

function buildVisualSearchScope() {
  const nextPageSection = String(filters.pageSection || "").trim().toLowerCase();
  const nextCategory = String(filters.category || "").trim().toLowerCase();

  return {
    pageSection: nextPageSection,
    category: nextCategory,
    categoryGroup: !nextCategory && GROUPED_PAGE_SECTIONS.has(nextPageSection) ? nextPageSection : "",
  };
}

async function loadProducts(options = {}) {
  const { forceFacets = false } = options;
  const requestId = ++catalogRequestId;
  const includeFacets = forceFacets || shouldRequestFacets.value;
  const params = new URLSearchParams();
  params.set("limit", String(SEARCH_SERVER_PAGE_SIZE));
  params.set("offset", String(Math.max(0, (currentGridPage.value - 1) * SEARCH_SERVER_PAGE_SIZE)));
  if (includeFacets) {
    params.set("includeFacets", "1");
  }

  if (activeQuery.value) {
    params.set("q", activeQuery.value);
  }

  if (filters.pageSection) {
    params.set("pageSection", filters.pageSection);
  }

  if (filters.category) {
    params.set("category", filters.category);
  }

  if (filters.productType) {
    params.set("productType", filters.productType);
  }

  if (filters.size) {
    params.set("size", filters.size);
  }

  if (filters.color) {
    params.set("color", filters.color);
  }

  if (filters.sort) {
    params.set("sort", filters.sort);
  }

  selectedBrands.value.forEach((brand) => {
    const normalizedBrand = String(brand || "").trim();
    if (normalizedBrand) {
      params.append("brand", normalizedBrand);
    }
  });

  const { minPrice, maxPrice } = resolveActivePriceBounds();
  if (Number.isFinite(minPrice)) {
    params.set("minPrice", String(minPrice));
  }
  if (Number.isFinite(maxPrice)) {
    params.set("maxPrice", String(maxPrice));
  }

  const requestUrl = activeQuery.value
    ? `/api/products/search?${params.toString()}`
    : `/api/products?${params.toString()}`;

  const { response, data } = await requestJson(
    requestUrl,
    {},
    { cacheTtlMs: 10000 },
  );
  if (requestId !== catalogRequestId) {
    return;
  }
  if (!response.ok || !data?.ok) {
    ui.message = resolveApiMessage(data, "Produktet nuk u ngarkuan.");
    ui.type = "error";
    return;
  }

  const nextProducts = Array.isArray(data.products) ? data.products : [];
  const visibleProducts = nextProducts.filter((product) => hasProductAvailableStock(product));
  const nextTotal = Number(data.total || visibleProducts.length || 0);
  const nextPageCount = Math.max(1, Math.ceil(nextTotal / SEARCH_GRID_PAGE_SIZE));
  if (!visualSearchActive.value && currentGridPage.value > nextPageCount) {
    currentGridPage.value = nextPageCount;
    void loadProducts(options);
    return;
  }

  products.value = visibleProducts;
  totalProductsCount.value = nextTotal;
  if (data.facets) {
    availableFilters.value = normalizeProductFacets(data.facets);
  }
  applyServerActiveFilters(data.activeFilters);
  ui.message = "";
  ui.type = "";
}

function submitSearch() {
  window.clearTimeout(searchDebounceTimeoutId);
  clearVisualSearchState();
  currentGridPage.value = 1;
  if (String(draftQuery.value || "").trim()) {
    recentSearches.value = rememberRecentSearch(draftQuery.value);
  }
  updateSearchRouteFromFilters(draftQuery.value);
}

function getProductPopularityScore(product) {
  const buyersCount = Number(product?.buyersCount ?? product?.unitsSold ?? 0) || 0;
  const reviewCount = Number(product?.reviewCount ?? 0) || 0;
  const ratingAverage = Number(product?.averageRating ?? product?.ratingAverage ?? 0) || 0;
  return (buyersCount * 4) + (reviewCount * 2) + ratingAverage;
}

function applyRecentSearch(term) {
  draftQuery.value = String(term || "").trim();
  submitSearch();
}

function clearSearchHistory() {
  recentSearches.value = clearRecentSearches();
}

function removeRecentSearchEntry(term) {
  recentSearches.value = removeRecentSearch(term);
}

function looksLikeNaturalLanguageSearch(value) {
  const normalizedValue = String(value || "").trim().toLowerCase();
  if (!normalizedValue) {
    return false;
  }

  const tokens = normalizedValue.split(/\s+/).filter(Boolean);
  if (tokens.length >= 4) {
    return true;
  }

  return tokens.some((token) => SMART_SEARCH_MARKERS.has(token)) && tokens.length >= 2;
}

function openVisualSearchPicker() {
  visualSearchInputElement.value?.click();
}

function clearVisualSearchState() {
  visualSearchActive.value = false;
  visualSearchFile.value = null;
  visualSearchFileName.value = "";
  if (visualSearchPreviewUrl.value) {
    URL.revokeObjectURL(visualSearchPreviewUrl.value);
    visualSearchPreviewUrl.value = "";
  }
}

async function clearVisualSearchAndReload() {
  clearVisualSearchState();
  currentGridPage.value = 1;
  await loadProducts();
}

async function handleVisualSearchSelection(event) {
  const nextFile = event.target?.files?.[0] || null;
  if (!nextFile) {
    return;
  }

  clearVisualSearchState();
  visualSearchFile.value = nextFile;
  visualSearchFileName.value = String(nextFile.name || "").trim();
  visualSearchPreviewUrl.value = URL.createObjectURL(nextFile);
  currentGridPage.value = 1;
  await runVisualSearch();

  if (event.target) {
    event.target.value = "";
  }
}

async function runVisualSearch(options = {}) {
  if (!visualSearchFile.value) {
    return;
  }

  const { forceFacets = false } = options;
  const requestId = ++catalogRequestId;
  visualSearchBusy.value = true;
  const visualScope = buildVisualSearchScope();
  const includeFacets = forceFacets || shouldRequestFacets.value;

  const result = await searchProductsByImage(visualSearchFile.value, {
    pageSection: visualScope.pageSection,
    category: visualScope.category,
    categoryGroup: visualScope.categoryGroup,
    productType: filters.productType,
    size: filters.size,
    color: filters.color,
    limit: SEARCH_VISUAL_FETCH_LIMIT,
    offset: 0,
    includeFacets,
  });

  visualSearchBusy.value = false;
  if (requestId !== catalogRequestId) {
    return;
  }

  if (!result.ok) {
    ui.message = result.message;
    ui.type = "error";
    return;
  }

  visualSearchActive.value = true;
  const nextProducts = Array.isArray(result.products) ? result.products : [];
  products.value = nextProducts.filter((product) => hasProductAvailableStock(product));
  totalProductsCount.value = Number(result.total || products.value.length || 0);
  if (result.facets) {
    availableFilters.value = normalizeProductFacets(result.facets);
  }
  applyServerActiveFilters(result.activeFilters);
  ui.message = result.message || "U gjeten produkte te ngjashme sipas fotos.";
  ui.type = "success";
}

async function applyPendingVisualSearch() {
  const pendingVisualSearch = consumePendingVisualSearchFile();
  if (!pendingVisualSearch?.file) {
    return false;
  }

  clearVisualSearchState();
  visualSearchFile.value = pendingVisualSearch.file;
  visualSearchFileName.value = String(
    pendingVisualSearch.name || pendingVisualSearch.file.name || "",
  ).trim();
  visualSearchPreviewUrl.value = URL.createObjectURL(pendingVisualSearch.file);
  currentGridPage.value = 1;
  await runVisualSearch();
  return true;
}

function handlePageSectionChange() {
  filters.category = "";
  filters.productType = "";
  currentGridPage.value = 1;
  if (visualSearchActive.value && visualSearchFile.value) {
    void runVisualSearch();
    return;
  }
  updateSearchRouteFromFilters();
}

function handleCategoryChange() {
  filters.productType = "";
  currentGridPage.value = 1;
  if (visualSearchActive.value && visualSearchFile.value) {
    void runVisualSearch();
    return;
  }
  updateSearchRouteFromFilters();
}

function handleProductTypeChange() {
  currentGridPage.value = 1;
  if (visualSearchActive.value && visualSearchFile.value) {
    void runVisualSearch();
    return;
  }
  updateSearchRouteFromFilters();
}

function handleCatalogFilterChange() {
  currentGridPage.value = 1;
  if (visualSearchActive.value && visualSearchFile.value) {
    void runVisualSearch();
    return;
  }
  void loadProducts();
}

function toggleFiltersPanel() {
  filtersVisible.value = !filtersVisible.value;
  if (!filtersVisible.value || availablePageSectionOptions.value.length > 0) {
    return;
  }

  if (visualSearchActive.value && visualSearchFile.value) {
    void runVisualSearch({ forceFacets: true });
    return;
  }

  void loadProducts({ forceFacets: true });
}

function resetFilters() {
  filters.pageSection = "";
  filters.category = "";
  filters.productType = "";
  filters.size = "";
  filters.color = "";
  filters.sort = "popular";
  clearClientFilters({ reload: false });
  currentGridPage.value = 1;

  if (visualSearchActive.value && visualSearchFile.value) {
    void runVisualSearch();
    return;
  }

  const nextQuery = activeQuery.value ? { q: activeQuery.value } : {};
  if (featuredCollection.value) {
    nextQuery.featured = featuredCollection.value;
  }
  if (routeQueryMatches(nextQuery)) {
    void loadProducts();
    return;
  }

  router.replace({
    path: "/kerko",
    query: nextQuery,
  });
}

async function handleWishlist(productId) {
  if (!appState.user) {
    ui.message = "Duhet te kyçesh ose te krijosh llogari para se te perdoresh wishlist ose cart.";
    ui.type = "error";
    return;
  }

  busyWishlistIds.value = [...busyWishlistIds.value, productId];
  const currentHas = wishlistIds.value.includes(productId);
  wishlistIds.value = currentHas
    ? wishlistIds.value.filter((id) => id !== productId)
    : [...wishlistIds.value, productId];

  const { response, data } = await requestJson("/api/wishlist/toggle", {
    method: "POST",
    body: JSON.stringify({ productId }),
  });

  busyWishlistIds.value = busyWishlistIds.value.filter((id) => id !== productId);

  if (!response.ok || !data?.ok) {
    wishlistIds.value = currentHas
      ? [...wishlistIds.value, productId]
      : wishlistIds.value.filter((id) => id !== productId);
    ui.message = resolveApiMessage(data, "Wishlist nuk u perditesua.");
    ui.type = "error";
    return;
  }

  wishlistIds.value = Array.isArray(data.items) ? data.items.map((item) => item.id) : [];
  ui.message = data.message || "Wishlist u perditesua.";
  ui.type = "success";
  if (!currentHas) {
    window.dispatchEvent(new CustomEvent("trego:toast", {
      detail: { message: "Artikulli eshte shtuar ne wishlist." },
    }));
  }
}

async function handleCart(productId) {
  if (!appState.user) {
    ui.message = "Duhet te kyçesh ose te krijosh llogari para se te perdoresh wishlist ose cart.";
    ui.type = "error";
    return;
  }

  const product = products.value.find((entry) => Number(entry.id) === Number(productId));
  if (product?.requiresVariantSelection) {
    router.push(getProductDetailUrl(productId, route.fullPath));
    return;
  }

  busyCartIds.value = [...busyCartIds.value, productId];
  if (!cartIds.value.includes(productId)) {
    cartIds.value = [...cartIds.value, productId];
  }

  const { response, data } = await requestJson("/api/cart/add", {
    method: "POST",
    body: JSON.stringify({ productId }),
  });

  busyCartIds.value = busyCartIds.value.filter((id) => id !== productId);

  if (!response.ok || !data?.ok) {
    cartIds.value = cartIds.value.filter((id) => id !== productId);
    ui.message = resolveApiMessage(data, "Shporta nuk u perditesua.");
    ui.type = "error";
    return;
  }

  const items = Array.isArray(data.items) ? data.items : [];
  cartIds.value = items.map((item) => item.productId || item.id);
  setCartItems(items);
  ui.message = data.message || "Produkti u shtua ne shporte.";
  ui.type = "success";
}

function handleCompare(product) {
  toggleComparedProduct(product);
}
</script>

<template>
  <section class="search-reference-page" aria-label="Kerko produkte">
    <div class="search-reference-breadcrumb">
      <RouterLink class="search-breadcrumb-link" to="/">Home</RouterLink>
      <span class="search-breadcrumb-separator">›</span>
      <span class="search-breadcrumb-link">Shop</span>
      <span class="search-breadcrumb-separator">›</span>
      <span class="search-breadcrumb-link">Shop Grid</span>
      <span class="search-breadcrumb-separator">›</span>
      <strong class="search-breadcrumb-current">{{ breadcrumbTail }}</strong>
    </div>

    <div class="search-reference-shell">
      <aside class="search-reference-sidebar" :class="{ 'is-open': filtersVisible }" aria-label="Filtro produktet">
        <div class="search-sidebar-mobile-head">
          <strong>Filters</strong>
          <button class="search-sidebar-close" type="button" @click="filtersVisible = false">Close</button>
        </div>

        <section class="search-filter-block">
          <h2 class="search-filter-block-title">CATEGORY</h2>
          <div class="search-filter-list">
            <button
              v-for="option in sidebarCategoryOptions"
              :key="`${option.kind}-${option.value || 'all'}`"
              class="search-filter-radio"
              :class="{ 'is-active': activeSidebarCategoryValue === option.value }"
              type="button"
              @click="handleSidebarCategorySelect(option)"
            >
              <span class="search-filter-radio-mark"></span>
              <span>{{ option.label }}</span>
            </button>
          </div>
        </section>

        <section class="search-filter-block">
          <h2 class="search-filter-block-title">PRICE RANGE</h2>
          <div class="search-price-track" :style="priceTrackStyle">
            <span class="search-price-track-base" aria-hidden="true"></span>
            <span class="search-price-track-fill" aria-hidden="true"></span>
            <span class="search-price-track-thumb search-price-track-thumb--start" aria-hidden="true"></span>
            <span class="search-price-track-thumb search-price-track-thumb--end" aria-hidden="true"></span>
            <input
              class="search-price-range search-price-range--start"
              type="range"
              :min="priceSliderBounds.min"
              :max="priceSliderValues.maxValue"
              :value="priceSliderValues.minValue"
              step="1"
              aria-label="Minimum price"
              @input="handlePriceSliderInput('min', $event)"
              @change="applyPriceInputs"
            >
            <input
              class="search-price-range search-price-range--end"
              type="range"
              :min="priceSliderValues.minValue"
              :max="priceSliderBounds.max"
              :value="priceSliderValues.maxValue"
              step="1"
              aria-label="Maximum price"
              @input="handlePriceSliderInput('max', $event)"
              @change="applyPriceInputs"
            >
          </div>

          <div class="search-price-inputs">
            <input
              v-model="minPriceInput"
              class="search-price-input"
              type="text"
              inputmode="decimal"
              placeholder="Min price"
              @blur="applyPriceInputs"
              @keyup.enter="applyPriceInputs"
            >
            <input
              v-model="maxPriceInput"
              class="search-price-input"
              type="text"
              inputmode="decimal"
              placeholder="Max price"
              @blur="applyPriceInputs"
              @keyup.enter="applyPriceInputs"
            >
          </div>

          <div class="search-filter-list search-filter-list--spacious">
            <button
              class="search-filter-radio"
              :class="{ 'is-active': selectedPriceRange === '' && !minPriceInput && !maxPriceInput }"
              type="button"
              @click="setPriceRange('')"
            >
              <span class="search-filter-radio-mark"></span>
              <span>All Price</span>
            </button>
            <button class="search-filter-radio" :class="{ 'is-active': selectedPriceRange === 'under-20' }" type="button" @click="setPriceRange('under-20')">
              <span class="search-filter-radio-mark"></span>
              <span>Under $20</span>
            </button>
            <button class="search-filter-radio" :class="{ 'is-active': selectedPriceRange === '25-100' }" type="button" @click="setPriceRange('25-100')">
              <span class="search-filter-radio-mark"></span>
              <span>$25 to $100</span>
            </button>
            <button class="search-filter-radio" :class="{ 'is-active': selectedPriceRange === '100-300' }" type="button" @click="setPriceRange('100-300')">
              <span class="search-filter-radio-mark"></span>
              <span>$100 to $300</span>
            </button>
            <button class="search-filter-radio" :class="{ 'is-active': selectedPriceRange === '300-500' }" type="button" @click="setPriceRange('300-500')">
              <span class="search-filter-radio-mark"></span>
              <span>$300 to $500</span>
            </button>
            <button class="search-filter-radio" :class="{ 'is-active': selectedPriceRange === '500-1000' }" type="button" @click="setPriceRange('500-1000')">
              <span class="search-filter-radio-mark"></span>
              <span>$500 to $1,000</span>
            </button>
            <button class="search-filter-radio" :class="{ 'is-active': selectedPriceRange === '1000-10000' }" type="button" @click="setPriceRange('1000-10000')">
              <span class="search-filter-radio-mark"></span>
              <span>$1,000 to $10,000</span>
            </button>
          </div>
        </section>

        <section v-if="popularBrandOptions.length > 0" class="search-filter-block">
          <h2 class="search-filter-block-title">POPULAR BRANDS</h2>
          <div class="search-brand-grid">
            <button
              v-for="brand in popularBrandOptions"
              :key="brand.label"
              class="search-brand-option"
              :class="{ 'is-active': selectedBrands.includes(brand.label) }"
              type="button"
              @click="toggleBrandFilter(brand.label)"
            >
              <span class="search-brand-check"></span>
              <span>{{ brand.label }}</span>
            </button>
          </div>
        </section>

        <section
          v-if="shouldShowProductTypeFilter || availableSizeOptions.length > 0 || availableColorOptions.length > 0"
          class="search-filter-block"
        >
          <h2 class="search-filter-block-title">MORE FILTERS</h2>
          <div class="search-advanced-filters">
            <label v-if="shouldShowProductTypeFilter" class="search-select-field">
              <span>Product type</span>
              <select v-model="filters.productType" @change="handleProductTypeChange">
                <option value="">All types</option>
                <option
                  v-for="option in availableProductTypeOptions"
                  :key="`${option.category}-${option.value}`"
                  :value="option.value"
                >
                  {{ option.label }}
                </option>
              </select>
            </label>

            <label v-if="availableSizeOptions.length > 0" class="search-select-field">
              <span>Size</span>
              <select v-model="filters.size" @change="handleCatalogFilterChange">
                <option value="">All sizes</option>
                <option v-for="option in availableSizeOptions" :key="option.value" :value="option.value">
                  {{ option.label }}
                </option>
              </select>
            </label>

            <label v-if="availableColorOptions.length > 0" class="search-select-field">
              <span>Color</span>
              <select v-model="filters.color" @change="handleCatalogFilterChange">
                <option value="">All colors</option>
                <option v-for="option in availableColorOptions" :key="option.value" :value="option.value">
                  {{ option.label }}
                </option>
              </select>
            </label>
          </div>
        </section>

        <div class="search-sidebar-actions">
          <button class="search-sidebar-action search-sidebar-action--ghost" type="button" @click="clearClientFilters">
            Clear Price & Brand
          </button>
          <button class="search-sidebar-action" type="button" @click="resetFilters">
            Reset All
          </button>
        </div>
      </aside>

      <div class="search-reference-content">
        <div class="search-toolbar-row">
          <button
            class="search-mobile-filter-toggle"
            type="button"
            :aria-expanded="filtersVisible ? 'true' : 'false'"
            @click="toggleFiltersPanel"
          >
            Filters
          </button>

          <form class="search-toolbar-search" role="search" @submit.prevent="submitSearch">
            <input
              v-model="draftQuery"
              class="search-toolbar-input"
              name="q"
              type="search"
              placeholder="Search for anything..."
              autocomplete="off"
            >
            <button class="search-toolbar-submit" type="submit" aria-label="Search products">
              <svg viewBox="0 0 24 24" aria-hidden="true">
                <path d="M21 21l-4.35-4.35"></path>
                <circle cx="11" cy="11" r="6.5"></circle>
              </svg>
            </button>
          </form>

          <label class="search-sort-control">
            <span>Sort by:</span>
            <select v-model="filters.sort">
              <option value="popular">Most Popular</option>
              <option value="rating">Top Rated</option>
              <option value="newest">Newest</option>
              <option value="price-asc">Price Low to High</option>
              <option value="price-desc">Price High to Low</option>
            </select>
          </label>
        </div>

        <div class="search-meta-row">
          <div class="search-meta-filters">
            <span class="search-meta-label">Active Filters:</span>
            <div v-if="activeFilterChips.length > 0" class="search-chip-list">
              <button
                v-for="chip in activeFilterChips"
                :key="chip.key"
                class="search-chip"
                type="button"
                @click="removeFilterChip(chip)"
              >
                <span>{{ chip.label }}</span>
                <span class="search-chip-x">×</span>
              </button>
            </div>
            <span v-else class="search-meta-empty">All Products</span>
          </div>
          <p class="search-results-count">{{ formattedResultsCount }} Results found.</p>
        </div>

        <div v-if="visualSearchFileName" class="search-visual-banner" aria-label="Kerkimi me foto">
          <div class="search-visual-banner-copy">
            <strong>Visual search active</strong>
            <span>{{ visualSearchFileName }}</span>
          </div>
          <button class="search-visual-banner-action" type="button" @click="clearVisualSearchAndReload">
            Clear
          </button>
        </div>

        <div v-if="ui.message" class="form-message" :class="ui.type" role="status" aria-live="polite">
          {{ ui.message }}
        </div>

        <section v-if="paginatedProducts.length > 0" class="search-reference-grid" aria-label="Rezultatet e kerkimit">
          <article
            v-for="product in paginatedProducts"
            :key="product.id"
            class="search-grid-card"
          >
            <RouterLink class="search-grid-card-media" :to="getProductDetailUrl(product.id, route.fullPath)">
              <img
                class="search-grid-card-image"
                :src="product.imagePath"
                :alt="product.title"
                width="240"
                height="240"
                loading="lazy"
                decoding="async"
              >
            </RouterLink>

            <div class="search-grid-card-copy">
              <div class="search-grid-card-rating" :aria-label="`Vleresimi ${getProductRatingSummary(product)}`">
                <div class="search-grid-card-stars">
                  <svg
                    v-for="index in 5"
                    :key="`grid-star-${product.id}-${index}`"
                    class="search-grid-card-star"
                    :class="{ 'is-filled': index <= getProductFilledStars(product) }"
                    viewBox="0 0 24 24"
                    aria-hidden="true"
                  >
                    <path d="M12 3.8 14.6 9l5.7.8-4.1 4 1 5.7-5.2-2.7-5.2 2.7 1-5.7-4.1-4 5.7-.8Z"></path>
                  </svg>
                </div>
                <span class="search-grid-card-review-count">({{ getProductReviewCount(product) }})</span>
              </div>

              <h3 class="search-grid-card-title">
                <RouterLink class="search-grid-card-title-link" :to="getProductDetailUrl(product.id, route.fullPath)">
                  {{ product.title }}
                </RouterLink>
              </h3>

              <p class="search-grid-card-business">{{ getProductBrandLabel(product) }}</p>

              <div class="search-grid-card-price-row">
                <strong class="search-grid-card-price">{{ formatPrice(product.price || 0) }}</strong>
                <span
                  v-if="Number(product.compareAtPrice || product.originalPrice || 0) > Number(product.price || 0)"
                  class="search-grid-card-price-old"
                >
                  {{ formatPrice(product.compareAtPrice || product.originalPrice || 0) }}
                </span>
              </div>
            </div>
          </article>
        </section>

        <div v-else class="collection-empty-state">
          {{ visualSearchActive ? "Nuk u gjet asnje produkt i ngjashem sipas fotos." : "Nuk u gjet asnje produkt per kete kerkim." }}
        </div>

        <nav v-if="totalGridPageCount > 1" class="search-pagination" aria-label="Pagination">
          <button
            class="search-pagination-arrow"
            type="button"
            :disabled="currentGridPage === 1"
            @click="goToPreviousGridPage"
          >
            ←
          </button>
          <button
            v-for="page in visibleGridPages"
            :key="page"
            class="search-pagination-page"
            :class="{ 'is-active': page === currentGridPage }"
            type="button"
            @click="goToGridPage(page)"
          >
            {{ String(page).padStart(2, "0") }}
          </button>
          <button
            class="search-pagination-arrow"
            type="button"
            :disabled="currentGridPage === totalGridPageCount"
            @click="goToNextGridPage"
          >
            →
          </button>
        </nav>
      </div>
    </div>

    <input
      ref="visualSearchInputElement"
      class="sr-only"
      type="file"
      accept="image/*"
      capture="environment"
      @change="handleVisualSearchSelection"
    >
  </section>
</template>

<style scoped>
.search-reference-page {
  display: grid;
  gap: 24px;
  padding: 0 0 32px;
  color: #191c1f;
}

.search-reference-breadcrumb {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 10px;
  min-height: 64px;
  padding: 0 24px;
  border-top: 1px solid #eaedf0;
  border-bottom: 1px solid #eaedf0;
  background: #f2f4f5;
  font-size: 0.84rem;
}

.search-breadcrumb-link {
  color: #5f6c72;
  text-decoration: none;
}

.search-breadcrumb-current {
  color: #2da5f3;
  font-weight: 700;
}

.search-breadcrumb-separator {
  color: #9aa5ad;
}

.search-reference-shell {
  display: grid;
  grid-template-columns: minmax(220px, 260px) minmax(0, 1fr);
  gap: 28px;
  align-items: start;
}

.search-reference-sidebar {
  display: grid;
  gap: 18px;
}

.search-sidebar-mobile-head {
  display: none;
}

.search-filter-block {
  display: grid;
  gap: 14px;
  padding-bottom: 18px;
  border-bottom: 1px solid #e4e7e9;
}

.search-filter-block-title {
  margin: 0;
  color: #191c1f;
  font-size: 0.92rem;
  font-weight: 700;
  letter-spacing: 0.02em;
}

.search-filter-list {
  display: grid;
  gap: 10px;
}

.search-filter-list--spacious {
  gap: 9px;
}

.search-filter-radio {
  display: inline-flex;
  align-items: center;
  gap: 10px;
  padding: 0;
  border: 0;
  background: transparent;
  color: #5f6c72;
  font-size: 0.87rem;
  text-align: left;
  cursor: pointer;
}

.search-filter-radio-mark {
  width: 15px;
  height: 15px;
  border: 1px solid #c9cfd2;
  border-radius: 999px;
  background: #fff;
  box-shadow: inset 0 0 0 3px #fff;
  transition: border-color 0.18s ease, background 0.18s ease, box-shadow 0.18s ease;
}

.search-filter-radio.is-active {
  color: #191c1f;
  font-weight: 600;
}

.search-filter-radio.is-active .search-filter-radio-mark {
  border-color: #fa8232;
  background: #fa8232;
  box-shadow: inset 0 0 0 3px #fff;
}

.search-price-track {
  position: relative;
  height: 22px;
}

.search-price-track-base,
.search-price-track-fill {
  position: absolute;
  top: 50%;
  height: 4px;
  border-radius: 999px;
  transform: translateY(-50%);
}

.search-price-track-base {
  inset-inline: 0;
  background: #e4e7e9;
}

.search-price-track-fill {
  left: var(--track-start);
  right: calc(100% - var(--track-end));
  background: #fa8232;
}

.search-price-track-thumb {
  position: absolute;
  top: 50%;
  width: 12px;
  height: 12px;
  border-radius: 999px;
  background: #fa8232;
  transform: translate(-50%, -50%);
  box-shadow: 0 0 0 3px #fff;
}

.search-price-track-thumb--start {
  left: var(--track-start);
}

.search-price-track-thumb--end {
  left: var(--track-end);
}

.search-price-range {
  position: absolute;
  inset: 0;
  width: 100%;
  margin: 0;
  background: transparent;
  pointer-events: none;
  -webkit-appearance: none;
  appearance: none;
}

.search-price-range::-webkit-slider-runnable-track {
  height: 22px;
  background: transparent;
}

.search-price-range::-webkit-slider-thumb {
  width: 18px;
  height: 18px;
  border: 0;
  border-radius: 999px;
  background: transparent;
  cursor: pointer;
  pointer-events: auto;
  -webkit-appearance: none;
  appearance: none;
}

.search-price-range::-moz-range-track {
  height: 22px;
  background: transparent;
}

.search-price-range::-moz-range-thumb {
  width: 18px;
  height: 18px;
  border: 0;
  border-radius: 999px;
  background: transparent;
  cursor: pointer;
  pointer-events: auto;
}

.search-price-inputs {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 10px;
}

.search-price-input,
.search-select-field select,
.search-sort-control select,
.search-toolbar-input {
  width: 100%;
  min-height: 42px;
  border: 1px solid #e4e7e9;
  border-radius: 2px;
  background: #fff;
  color: #475156;
  font: inherit;
}

.search-price-input {
  padding: 0 12px;
  font-size: 0.85rem;
}

.search-brand-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 12px 16px;
}

.search-brand-option {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  padding: 0;
  border: 0;
  background: transparent;
  color: #5f6c72;
  font-size: 0.84rem;
  text-align: left;
  cursor: pointer;
}

.search-brand-check {
  width: 14px;
  height: 14px;
  border: 1px solid #ced4d7;
  border-radius: 3px;
  background: #fff;
}

.search-brand-option.is-active {
  color: #191c1f;
  font-weight: 600;
}

.search-brand-option.is-active .search-brand-check {
  border-color: #fa8232;
  background: #fa8232;
  box-shadow: inset 0 0 0 2px #fff;
}

.search-advanced-filters {
  display: grid;
  gap: 12px;
}

.search-select-field {
  display: grid;
  gap: 8px;
  color: #5f6c72;
  font-size: 0.82rem;
  font-weight: 600;
}

.search-select-field select,
.search-sort-control select {
  padding: 0 12px;
}

.search-sidebar-actions {
  display: grid;
  gap: 10px;
}

.search-sidebar-action {
  min-height: 40px;
  border: 1px solid #fa8232;
  background: #fa8232;
  color: #fff;
  font-size: 0.82rem;
  font-weight: 700;
  cursor: pointer;
}

.search-sidebar-action--ghost {
  background: #fff;
  color: #fa8232;
}

.search-reference-content {
  display: grid;
  gap: 16px;
  min-width: 0;
}

.search-toolbar-row {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto;
  gap: 16px;
  align-items: center;
}

.search-toolbar-search {
  position: relative;
}

.search-toolbar-input {
  padding: 0 48px 0 16px;
  font-size: 0.9rem;
}

.search-toolbar-submit {
  position: absolute;
  top: 50%;
  right: 14px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 24px;
  height: 24px;
  padding: 0;
  border: 0;
  background: transparent;
  color: #5f6c72;
  transform: translateY(-50%);
  cursor: pointer;
}

.search-toolbar-submit svg {
  width: 20px;
  height: 20px;
  fill: none;
  stroke: currentColor;
  stroke-width: 1.8;
  stroke-linecap: round;
  stroke-linejoin: round;
}

.search-sort-control {
  display: inline-flex;
  align-items: center;
  gap: 12px;
  color: #5f6c72;
  font-size: 0.84rem;
  font-weight: 600;
}

.search-sort-control select {
  min-width: 176px;
}

.search-mobile-filter-toggle {
  display: none;
}

.search-meta-row {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto;
  gap: 16px;
  align-items: center;
  min-height: 48px;
  padding: 0 16px;
  background: #f2f4f5;
  border: 1px solid #e4e7e9;
}

.search-meta-filters {
  display: inline-flex;
  align-items: center;
  gap: 10px;
  min-width: 0;
}

.search-meta-label,
.search-meta-empty,
.search-results-count {
  color: #5f6c72;
  font-size: 0.82rem;
}

.search-results-count {
  margin: 0;
  font-weight: 700;
  white-space: nowrap;
}

.search-chip-list {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.search-chip {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  min-height: 28px;
  padding: 0 10px;
  border: 1px solid #e4e7e9;
  background: #fff;
  color: #475156;
  font-size: 0.76rem;
  cursor: pointer;
}

.search-chip-x {
  color: #77878f;
  font-size: 0.92rem;
  line-height: 1;
}

.search-visual-banner {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  padding: 14px 16px;
  border: 1px solid #e4e7e9;
  background: #fff8f2;
}

.search-visual-banner-copy {
  display: grid;
  gap: 4px;
}

.search-visual-banner-copy strong {
  color: #191c1f;
  font-size: 0.88rem;
}

.search-visual-banner-copy span {
  color: #5f6c72;
  font-size: 0.8rem;
}

.search-visual-banner-action {
  min-height: 36px;
  padding: 0 14px;
  border: 1px solid #fa8232;
  background: #fff;
  color: #fa8232;
  font-size: 0.78rem;
  font-weight: 700;
  cursor: pointer;
}

.search-reference-grid {
  display: grid;
  grid-template-columns: repeat(5, minmax(0, 1fr));
  gap: 12px;
}

.search-grid-card {
  display: grid;
  gap: 12px;
  min-width: 0;
  padding: 16px 14px 14px;
  border: 1px solid #e4e7e9;
  background: #fff;
}

.search-grid-card-media {
  display: grid;
  place-items: center;
  min-height: 190px;
  padding: 10px;
  text-decoration: none;
}

.search-grid-card-image {
  width: 100%;
  height: 100%;
  max-height: 170px;
  object-fit: contain;
}

.search-grid-card-copy {
  display: grid;
  gap: 8px;
  min-width: 0;
}

.search-grid-card-rating {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  color: #77878f;
  font-size: 0.76rem;
}

.search-grid-card-stars {
  display: inline-flex;
  align-items: center;
  gap: 1px;
}

.search-grid-card-star {
  width: 14px;
  height: 14px;
  fill: none;
  stroke: #fa8232;
  stroke-width: 1.8;
}

.search-grid-card-star.is-filled {
  fill: #fa8232;
}

.search-grid-card-review-count {
  color: #adb7bc;
}

.search-grid-card-title {
  margin: 0;
  font-size: 0.92rem;
  font-weight: 600;
  line-height: 1.45;
}

.search-grid-card-title-link {
  color: #191c1f;
  text-decoration: none;
  display: -webkit-box;
  -webkit-line-clamp: 3;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.search-grid-card-business {
  margin: 0;
  color: #77878f;
  font-size: 0.78rem;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.search-grid-card-price-row {
  display: flex;
  flex-wrap: wrap;
  align-items: baseline;
  gap: 6px;
}

.search-grid-card-price {
  color: #2da5f3;
  font-size: 0.94rem;
  font-weight: 700;
}

.search-grid-card-price-old {
  color: #adb7bc;
  font-size: 0.78rem;
  font-weight: 600;
  text-decoration: line-through;
}

.search-pagination {
  display: flex;
  justify-content: center;
  align-items: center;
  gap: 8px;
  padding-top: 8px;
}

.search-pagination-arrow,
.search-pagination-page {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 36px;
  height: 36px;
  border-radius: 999px;
  border: 1px solid #e4e7e9;
  background: #fff;
  color: #5f6c72;
  font-size: 0.82rem;
  font-weight: 700;
  cursor: pointer;
}

.search-pagination-arrow {
  border-color: #fa8232;
  color: #fa8232;
}

.search-pagination-page.is-active {
  border-color: #fa8232;
  background: #fa8232;
  color: #fff;
}

.search-pagination-arrow:disabled,
.search-pagination-page:disabled {
  opacity: 0.45;
  cursor: default;
}

@media (max-width: 1100px) {
  .search-reference-shell {
    grid-template-columns: 220px minmax(0, 1fr);
    gap: 22px;
  }

  .search-reference-grid {
    grid-template-columns: repeat(4, minmax(0, 1fr));
  }
}

@media (max-width: 900px) {
  .search-reference-shell {
    grid-template-columns: 1fr;
  }

  .search-reference-sidebar {
    display: none;
    padding: 18px;
    border: 1px solid #e4e7e9;
    background: #fff;
  }

  .search-reference-sidebar.is-open {
    display: grid;
  }

  .search-sidebar-mobile-head {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }

  .search-sidebar-close {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    min-height: 32px;
    padding: 0 10px;
    border: 1px solid #fa8232;
    background: #fff;
    color: #fa8232;
    font-size: 0.76rem;
    font-weight: 700;
    cursor: pointer;
  }

  .search-toolbar-row {
    grid-template-columns: 1fr;
  }

  .search-mobile-filter-toggle {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    min-height: 40px;
    width: fit-content;
    padding: 0 16px;
    border: 1px solid #e4e7e9;
    background: #fff;
    color: #191c1f;
    font-size: 0.82rem;
    font-weight: 700;
    cursor: pointer;
  }

  .search-sort-control {
    justify-content: space-between;
  }

  .search-reference-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }

  .search-meta-row {
    grid-template-columns: 1fr;
    padding: 12px 14px;
  }

  .search-meta-filters {
    align-items: flex-start;
    flex-direction: column;
  }
}

@media (max-width: 560px) {
  .search-reference-breadcrumb {
    padding: 14px 16px;
  }

  .search-reference-grid {
    grid-template-columns: 1fr;
  }

  .search-grid-card {
    padding-inline: 12px;
  }

  .search-grid-card-media {
    min-height: 180px;
  }

  .search-brand-grid,
  .search-price-inputs {
    grid-template-columns: 1fr;
  }

  .search-visual-banner {
    align-items: flex-start;
    flex-direction: column;
  }
}
</style>
