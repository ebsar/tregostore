<script setup>
import { computed, onBeforeUnmount, onMounted, reactive, ref, watch } from "vue";
import { RouterLink, useRoute, useRouter } from "vue-router";
import ProductCard from "../components/ProductCard.vue";
import { fetchProtectedCollection, requestJson, resolveApiMessage, searchProductsByImage } from "../lib/api";
import { deriveSectionFromCategory } from "../lib/product-catalog";
import { clearRecentSearches, readRecentSearches, rememberRecentSearch, removeRecentSearch } from "../lib/search-history";
import {
  formatCategoryLabel,
  formatPrice,
  formatProductColorLabel,
  formatProductTypeLabel,
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
const smartSearchFilters = ref(null);
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
const smartSearchChips = computed(() => {
  const filtersPayload = smartSearchFilters.value && typeof smartSearchFilters.value === "object"
    ? smartSearchFilters.value
    : {};
  const appliedFilters = filtersPayload.applied && typeof filtersPayload.applied === "object"
    ? filtersPayload.applied
    : {};
  const nextChips = [];

  if (appliedFilters.productType) {
    nextChips.push(formatProductTypeLabel(appliedFilters.productType));
  } else if (appliedFilters.category || appliedFilters.categoryGroup) {
    nextChips.push(formatCategoryLabel(appliedFilters.category || appliedFilters.categoryGroup));
  } else if (filtersPayload.category) {
    nextChips.push(filtersPayload.category);
  }

  if (appliedFilters.color) {
    nextChips.push(formatProductColorLabel(appliedFilters.color));
  } else if (filtersPayload.color) {
    nextChips.push(filtersPayload.color);
  }

  if (Number.isFinite(Number(appliedFilters.minPrice))) {
    nextChips.push(`From ${formatPrice(Number(appliedFilters.minPrice))}`);
  }
  if (Number.isFinite(Number(appliedFilters.maxPrice))) {
    nextChips.push(`Under ${formatPrice(Number(appliedFilters.maxPrice))}`);
  }

  return nextChips.filter(Boolean);
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
const canUseProductPhotoSearch = computed(() => {
  const role = String(appState.user?.role || "").toLowerCase();
  return role !== "admin" && role !== "business";
});

const searchIntro = computed(() => {
  if (!canUseProductPhotoSearch.value && !(featuredCollection.value === "best-sellers" && !activeQuery.value)) {
    return "Shkruaj p.sh. `me trego maica te kuqe`, `dua pantallona te gjera` ose perdor filtrat per te gjetur produktin.";
  }

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
    const cartItems = await fetchProtectedCollection("/api/cart");
    cartIds.value = cartItems.map((item) => item.productId || item.id);
    setCartItems(cartItems);
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
  if (Object.prototype.hasOwnProperty.call(activeFilters, "minPrice")) {
    const nextMinPrice = Number(activeFilters.minPrice);
    minPriceInput.value = Number.isFinite(nextMinPrice) ? formatPriceInputDisplay(nextMinPrice) : "";
    selectedPriceRange.value = "";
  }
  if (Object.prototype.hasOwnProperty.call(activeFilters, "maxPrice")) {
    const nextMaxPrice = Number(activeFilters.maxPrice);
    maxPriceInput.value = Number.isFinite(nextMaxPrice) ? formatPriceInputDisplay(nextMaxPrice) : "";
    selectedPriceRange.value = "";
  }
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
  smartSearchFilters.value = data.smartFilters && Object.keys(data.smartFilters).length > 0
    ? data.smartFilters
    : null;
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
  smartSearchFilters.value = null;
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
    ui.message = "Duhet te kyçesh ose te krijosh llogari para se te perdoresh wishlist.";
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
  <section class="market-page market-page--wide search-page" aria-label="Kerko produkte">
    <nav class="market-page__crumbs" aria-label="Breadcrumb">
      <RouterLink to="/">Home</RouterLink>
      <span aria-hidden="true">/</span>
      <span>Shop</span>
      <span aria-hidden="true">/</span>
      <strong>{{ breadcrumbTail }}</strong>
    </nav>

    <div class="search-page__shell">
      <header class="market-card market-card--padded search-hero">
        <p class="search-hero__label">Marketplace search</p>
        <div class="market-page__header">
          <div class="market-page__header-copy">
            <h1>{{ searchTitle }}</h1>
            <p class="search-hero__copy">{{ searchIntro }}</p>
          </div>
          <div class="market-status market-status--compact">
            <span>{{ formattedResultsCount }} active results</span>
          </div>
        </div>

        <form
          class="search-hero__form"
          :class="{ 'search-hero__form--photo': canUseProductPhotoSearch }"
          role="search"
          @submit.prevent="submitSearch"
        >
          <input
            v-model="draftQuery"
            name="q"
            type="search"
            placeholder="Search products, brands, categories, or describe what you need"
            autocomplete="off"
          >
          <button
            v-if="canUseProductPhotoSearch"
            class="search-hero__camera-button"
            type="button"
            :disabled="visualSearchBusy"
            :aria-label="visualSearchBusy ? 'Scanning product photo' : 'Search products by photo'"
            :title="visualSearchBusy ? 'Scanning product photo' : 'Search products by photo'"
            @click="openVisualSearchPicker"
          >
            <svg viewBox="0 0 24 24" aria-hidden="true">
              <rect x="4" y="7" width="16" height="11" rx="3"></rect>
              <circle cx="12" cy="12.5" r="3"></circle>
              <path d="M8 7l1.4-2h5.2L16 7"></path>
            </svg>
          </button>
          <button class="market-button market-button--primary" type="submit" aria-label="Search products">
            <svg viewBox="0 0 24 24" aria-hidden="true">
              <path d="M21 21l-4.35-4.35"></path>
              <circle cx="11" cy="11" r="6.5"></circle>
            </svg>
          </button>
        </form>

        <div class="search-hero__suggestions" aria-label="Quick search suggestions">
          <button
            v-for="suggestion in SEARCH_PROMPT_SUGGESTIONS"
            :key="suggestion"
            type="button"
            @click="applyRecentSearch(suggestion)"
          >
            {{ suggestion }}
          </button>
        </div>

        <div v-if="smartSearchChips.length > 0" class="search-smart-summary" aria-label="Smart search filters">
          <span>Smart filters</span>
          <strong v-for="chip in smartSearchChips" :key="chip">{{ chip }}</strong>
        </div>
      </header>

      <div
        v-if="ui.message"
        class="market-status"
        :class="{
          'market-status--error': ui.type === 'error',
          'market-status--success': ui.type === 'success',
        }"
        role="status"
        aria-live="polite"
      >
        {{ ui.message }}
      </div>

      <section
        v-if="visualSearchFileName"
        class="market-card market-card--padded search-visual"
        aria-label="Kerkimi me foto"
      >
        <img v-if="visualSearchPreviewUrl" :src="visualSearchPreviewUrl" :alt="visualSearchFileName">
        <div>
          <p class="market-page__eyebrow">Visual search</p>
          <h2>{{ visualSearchFileName }}</h2>
          <p class="section-heading__copy">
            We matched the uploaded image against live marketplace inventory and kept the same refinement tools.
          </p>
        </div>
        <button class="market-button market-button--ghost" type="button" @click="clearVisualSearchAndReload">
          Clear
        </button>
      </section>

      <section
        v-if="recentSearches.length > 0"
        class="market-card market-card--padded search-history"
        aria-label="Recent searches"
      >
        <div class="search-sidebar__header">
          <div>
            <p class="search-sidebar__label">Recent</p>
            <strong>Continue where you left off</strong>
          </div>
          <button class="market-button market-button--ghost" type="button" @click="clearSearchHistory">
            Clear history
          </button>
        </div>

        <div class="search-history__list">
          <div v-for="term in recentSearches" :key="term" class="search-history__item">
            <button type="button" @click="applyRecentSearch(term)">
              {{ term }}
            </button>
            <button class="market-icon-button" type="button" :aria-label="`Remove ${term}`" @click="removeRecentSearchEntry(term)">
              x
            </button>
          </div>
        </div>
      </section>

      <div class="search-page__layout">
        <aside
          class="market-card search-sidebar"
          :class="{ 'is-hidden-mobile': !filtersVisible }"
          aria-label="Filtro produktet"
        >
          <div class="search-sidebar__header">
            <div>
              <p class="search-sidebar__label">Filters</p>
              <strong>Refine your results</strong>
            </div>
            <button class="market-button market-button--ghost" type="button" @click="filtersVisible = false">
              Close
            </button>
          </div>

          <section class="search-sidebar__section">
            <p class="search-sidebar__label">Category</p>
            <div class="search-sidebar__options">
              <button
                v-for="option in sidebarCategoryOptions"
                :key="`${option.kind}-${option.value || 'all'}`"
                type="button"
                :aria-pressed="activeSidebarCategoryValue === option.value || (!activeSidebarCategoryValue && !option.value)"
                @click="handleSidebarCategorySelect(option)"
              >
                {{ option.label }}
              </button>
            </div>
          </section>

          <section class="search-sidebar__section">
            <p class="search-sidebar__label">Price range</p>
            <div class="search-price">
              <div class="search-price__sliders">
                <input
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

              <div class="search-price__inputs">
                <input
                  v-model="minPriceInput"
                  type="text"
                  inputmode="decimal"
                  placeholder="Min price"
                  @blur="applyPriceInputs"
                  @keyup.enter="applyPriceInputs"
                >
                <input
                  v-model="maxPriceInput"
                  type="text"
                  inputmode="decimal"
                  placeholder="Max price"
                  @blur="applyPriceInputs"
                  @keyup.enter="applyPriceInputs"
                >
              </div>

              <div class="search-sidebar__options">
                <button type="button" :aria-pressed="selectedPriceRange === ''" @click="setPriceRange('')">
                  All price
                </button>
                <button type="button" :aria-pressed="selectedPriceRange === 'under-20'" @click="setPriceRange('under-20')">
                  Under $20
                </button>
                <button type="button" :aria-pressed="selectedPriceRange === '25-100'" @click="setPriceRange('25-100')">
                  $25 to $100
                </button>
                <button type="button" :aria-pressed="selectedPriceRange === '100-300'" @click="setPriceRange('100-300')">
                  $100 to $300
                </button>
                <button type="button" :aria-pressed="selectedPriceRange === '300-500'" @click="setPriceRange('300-500')">
                  $300 to $500
                </button>
                <button type="button" :aria-pressed="selectedPriceRange === '500-1000'" @click="setPriceRange('500-1000')">
                  $500 to $1,000
                </button>
                <button type="button" :aria-pressed="selectedPriceRange === '1000-10000'" @click="setPriceRange('1000-10000')">
                  $1,000+
                </button>
              </div>
            </div>
          </section>

          <section v-if="popularBrandOptions.length > 0" class="search-sidebar__section">
            <p class="search-sidebar__label">Popular brands</p>
            <div class="search-sidebar__options">
              <button
                v-for="brand in popularBrandOptions"
                :key="brand.label"
                type="button"
                :aria-pressed="selectedBrands.includes(brand.label)"
                @click="toggleBrandFilter(brand.label)"
              >
                {{ brand.label }} ({{ brand.count }})
              </button>
            </div>
          </section>

          <section
            v-if="shouldShowProductTypeFilter || availableSizeOptions.length > 0 || availableColorOptions.length > 0"
            class="search-sidebar__section"
          >
            <p class="search-sidebar__label">More filters</p>

            <label v-if="shouldShowProductTypeFilter">
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

            <label v-if="availableSizeOptions.length > 0">
              <span>Size</span>
              <select v-model="filters.size" @change="handleCatalogFilterChange">
                <option value="">All sizes</option>
                <option v-for="option in availableSizeOptions" :key="option.value" :value="option.value">
                  {{ option.label }}
                </option>
              </select>
            </label>

            <label v-if="availableColorOptions.length > 0">
              <span>Color</span>
              <select v-model="filters.color" @change="handleCatalogFilterChange">
                <option value="">All colors</option>
                <option v-for="option in availableColorOptions" :key="option.value" :value="option.value">
                  {{ option.label }}
                </option>
              </select>
            </label>
          </section>

          <div class="search-sidebar__footer">
            <button class="market-button market-button--secondary" type="button" @click="clearClientFilters">
              Clear price and brand
            </button>
            <button class="market-button market-button--ghost" type="button" @click="resetFilters">
              Reset all filters
            </button>
          </div>
        </aside>

        <div class="search-results">
          <section class="market-card market-card--padded search-toolbar">
            <div>
              <p class="market-page__eyebrow">Results</p>
              <strong>{{ activeQuery || breadcrumbTail }}</strong>
              <p class="section-heading__copy">{{ resultsLabel }}</p>
            </div>

            <div class="search-toolbar">
              <button
                class="market-button market-button--secondary"
                type="button"
                :aria-expanded="filtersVisible ? 'true' : 'false'"
                @click="toggleFiltersPanel"
              >
                Filters
              </button>

              <label>
                <span>Sort by</span>
                <select v-model="filters.sort">
                  <option value="popular">Most popular</option>
                  <option value="rating">Top rated</option>
                  <option value="newest">Newest</option>
                  <option value="price-asc">Price low to high</option>
                  <option value="price-desc">Price high to low</option>
                </select>
              </label>
            </div>
          </section>

          <section v-if="activeFilterChips.length > 0" class="market-card market-card--padded">
            <div class="search-sidebar__header">
              <div>
                <p class="search-sidebar__label">Active filters</p>
                <strong>{{ activeFilterChips.length }} refinements applied</strong>
              </div>
              <button class="market-button market-button--ghost" type="button" @click="resetFilters">
                Clear all
              </button>
            </div>

            <div class="search-page__chips">
              <button
                v-for="chip in activeFilterChips"
                :key="chip.key"
                type="button"
                @click="removeFilterChip(chip)"
              >
                {{ chip.label }} x
              </button>
            </div>
          </section>

          <section v-if="paginatedProducts.length > 0" class="search-results__grid" aria-label="Rezultatet e kerkimit">
            <ProductCard
              v-for="product in paginatedProducts"
              :key="product.id"
              :product="product"
              :is-wishlisted="wishlistIds.includes(product.id)"
              :is-in-cart="cartIds.includes(product.id)"
              :wishlist-busy="busyWishlistIds.includes(product.id)"
              :cart-busy="busyCartIds.includes(product.id)"
              :is-compared="isComparedProduct(product)"
              @wishlist="handleWishlist"
              @cart="handleCart"
              @compare="handleCompare"
            />
          </section>

          <div v-else class="market-empty">
            <h2>No matching products</h2>
            <p>
              {{
                visualSearchActive
                  ? "No close visual matches were found for the uploaded image."
                  : "We could not find products for this search yet."
              }}
            </p>
            <div class="market-empty__actions">
              <button class="market-button market-button--secondary" type="button" @click="resetFilters">
                Reset filters
              </button>
              <button
                v-if="canUseProductPhotoSearch"
                class="market-button market-button--ghost"
                type="button"
                @click="openVisualSearchPicker"
              >
                Try visual search
              </button>
            </div>
          </div>

          <nav v-if="totalGridPageCount > 1" class="search-results__pager" aria-label="Pagination">
            <button
              class="market-button market-button--ghost"
              type="button"
              :disabled="currentGridPage === 1"
              @click="goToPreviousGridPage"
            >
              Prev
            </button>
            <button
              v-for="page in visibleGridPages"
              :key="page"
              class="market-button market-button--secondary"
              :aria-current="page === currentGridPage ? 'page' : undefined"
              type="button"
              @click="goToGridPage(page)"
            >
              {{ String(page).padStart(2, "0") }}
            </button>
            <button
              class="market-button market-button--ghost"
              type="button"
              :disabled="currentGridPage === totalGridPageCount"
              @click="goToNextGridPage"
            >
              Next
            </button>
          </nav>
        </div>
      </div>

      <input
        v-if="canUseProductPhotoSearch"
        ref="visualSearchInputElement"
        class="visually-hidden"
        type="file"
        accept="image/*"
        capture="environment"
        @change="handleVisualSearchSelection"
      >
    </div>
  </section>
</template>

<style scoped>
.search-page {
  display: grid;
  gap: 16px;
}

.search-page__shell {
  display: grid;
  gap: 16px;
}

.search-hero {
  display: grid;
  gap: 14px;
  padding: 18px;
}

.search-hero__label {
  margin: 0;
  color: var(--dashboard-accent);
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.04em;
  text-transform: uppercase;
}

.search-hero__copy {
  margin: 8px 0 0;
  color: var(--dashboard-muted);
  font-size: 14px;
  line-height: 1.6;
}

.search-hero :deep(.market-status--compact) {
  justify-self: end;
}

.search-hero__suggestions,
.search-page__chips,
.search-results__pager {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.search-hero__suggestions button,
.search-page__chips button {
  min-height: 34px;
  padding: 0 12px;
  border: 1px solid var(--dashboard-border);
  border-radius: 999px;
  background: #ffffff;
  color: var(--dashboard-text);
  font-size: 12px;
  font-weight: 600;
  cursor: pointer;
}

.search-visual {
  display: grid;
  grid-template-columns: 88px minmax(0, 1fr) auto;
  align-items: center;
  gap: 14px;
}

.search-visual img {
  width: 88px;
  height: 88px;
  display: block;
  object-fit: cover;
  border-radius: 12px;
}

.search-visual h2 {
  margin: 0;
  color: var(--dashboard-text);
  font-size: 18px;
  font-weight: 700;
  line-height: 1.3;
}

.search-history {
  display: grid;
  gap: 14px;
}

.search-history__list {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.search-history__item {
  max-width: 100%;
  flex: 1 1 220px;
  display: inline-flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  padding: 6px 8px 6px 12px;
  border: 1px solid var(--dashboard-border);
  border-radius: 999px;
  background: #ffffff;
}

.search-history__item > button:first-child {
  min-width: 0;
  padding: 0;
  border: 0;
  background: transparent;
  color: var(--dashboard-text);
  font-size: 12px;
  font-weight: 600;
  text-align: left;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  cursor: pointer;
}

.search-page__layout {
  display: grid;
  grid-template-columns: 280px minmax(0, 1fr);
  gap: 16px;
  align-items: start;
}

.search-sidebar {
  position: sticky;
  top: calc(var(--dashboard-sticky-offset) + 84px);
  display: grid;
  gap: 16px;
  padding: 18px;
}

.search-sidebar__header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 12px;
}

.search-sidebar__header > div {
  min-width: 0;
}

.search-sidebar__header strong,
section.search-toolbar strong {
  color: var(--dashboard-text);
  font-size: 16px;
  font-weight: 700;
  line-height: 1.3;
}

.search-page__layout .search-sidebar__header > .market-button {
  display: none;
}

.search-sidebar__label,
section.search-toolbar label span {
  margin: 0 0 4px;
  color: var(--dashboard-muted-2);
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.04em;
  text-transform: uppercase;
}

.search-sidebar__section {
  display: grid;
  gap: 12px;
  padding-top: 16px;
  border-top: 1px solid #f0f0f0;
}

.search-sidebar__options {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.search-sidebar__options button {
  min-height: 34px;
  padding: 0 12px;
  border: 1px solid var(--dashboard-border);
  border-radius: 999px;
  background: #ffffff;
  color: var(--dashboard-text);
  font-size: 12px;
  font-weight: 600;
  cursor: pointer;
  transition: border-color 160ms ease, background-color 160ms ease, color 160ms ease;
}

.search-sidebar__options button[aria-pressed="true"] {
  border-color: var(--dashboard-accent-border);
  background: var(--dashboard-accent-soft);
  color: var(--dashboard-accent);
}

.search-price,
.search-sidebar label,
.search-results {
  display: grid;
  gap: 12px;
}

.search-price__sliders {
  display: grid;
  gap: 10px;
}

.search-price__sliders input[type="range"] {
  width: 100%;
}

.search-price__inputs {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 8px;
}

.search-sidebar__footer {
  display: grid;
  gap: 10px;
  padding-top: 16px;
  border-top: 1px solid #f0f0f0;
}

section.search-toolbar {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 12px;
  flex-wrap: wrap;
}

section.search-toolbar > div:first-child {
  min-width: 0;
}

section.search-toolbar > div:first-child p:last-child {
  margin: 6px 0 0;
}

section.search-toolbar > div:last-child {
  display: flex;
  align-items: flex-end;
  justify-content: flex-end;
  gap: 10px;
  flex-wrap: wrap;
  margin-left: auto;
}

section.search-toolbar > div:last-child > button:first-child {
  display: none;
}

section.search-toolbar label {
  min-width: 190px;
  display: grid;
  gap: 8px;
}

.search-results__grid {
  grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
}

.search-results__pager {
  justify-content: center;
}

.search-results__pager :deep(.market-button[aria-current="page"]) {
  border-color: var(--dashboard-accent-border);
  background: var(--dashboard-accent-soft);
  color: var(--dashboard-accent);
}

@media (max-width: 1100px) {
  .search-page__layout {
    grid-template-columns: 244px minmax(0, 1fr);
  }
}

@media (max-width: 980px) {
  .search-visual {
    grid-template-columns: 72px minmax(0, 1fr);
  }

  .search-visual img {
    width: 72px;
    height: 72px;
  }

  .search-visual > .market-button {
    grid-column: 1 / -1;
    width: 100%;
  }

  .search-page__layout {
    grid-template-columns: 1fr;
  }

  .search-sidebar {
    position: fixed;
    top: 96px;
    right: 12px;
    bottom: 12px;
    z-index: 1200;
    width: min(388px, calc(100vw - 24px));
    overflow-y: auto;
    box-shadow: 0 24px 48px rgba(17, 17, 17, 0.16);
  }

  .search-sidebar.is-hidden-mobile {
    display: none;
  }

  .search-page__layout .search-sidebar__header > .market-button,
  section.search-toolbar > div:last-child > button:first-child {
    display: inline-flex;
  }
}

@media (max-width: 640px) {
  .search-page,
  .search-page__shell {
    gap: 14px;
  }

  .search-hero,
  .search-sidebar {
    padding: 14px;
  }

  .search-hero :deep(.market-status--compact) {
    justify-self: stretch;
  }

  .search-visual {
    grid-template-columns: 1fr;
    justify-items: start;
  }

  .search-history__list {
    display: grid;
  }

  .search-history__item {
    width: 100%;
  }

  section.search-toolbar > div:last-child,
  .search-price__inputs {
    grid-template-columns: 1fr;
  }

  section.search-toolbar > div:last-child {
    display: grid;
    width: 100%;
    margin-left: 0;
  }

  section.search-toolbar label {
    min-width: 0;
  }

  .search-results__grid {
    grid-template-columns: 1fr;
  }
}
</style>
