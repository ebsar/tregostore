<script setup>
import { computed, onBeforeUnmount, onMounted, reactive, ref, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import ProductCard from "../components/ProductCard.vue";
import { useInfiniteScrollSentinel } from "../composables/useInfiniteScrollSentinel";
import { fetchProtectedCollection, requestJson, resolveApiMessage, searchProductsByImage } from "../lib/api";
import { deriveSectionFromCategory } from "../lib/product-catalog";
import { getProductsPageSize, subscribeProductsPageSize } from "../lib/product-pagination";
import { clearRecentSearches, readRecentSearches, rememberRecentSearch, removeRecentSearch } from "../lib/search-history";
import { formatCategoryLabel, getProductDetailUrl } from "../lib/shop";
import { consumePendingVisualSearchFile } from "../lib/visual-search-transfer";
import { appState, ensureSessionLoaded, markRouteReady, setCartItems } from "../stores/app-state";

const route = useRoute();
const router = useRouter();
const SEARCH_INPUT_DEBOUNCE_MS = 320;
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
const hasMoreProducts = ref(false);
const loadingMoreProducts = ref(false);
const filtersVisible = ref(false);
const visualSearchInputElement = ref(null);
const visualSearchFile = ref(null);
const visualSearchPreviewUrl = ref("");
const visualSearchFileName = ref("");
const visualSearchActive = ref(false);
const visualSearchBusy = ref(false);
const productsPageSize = ref(getProductsPageSize());
const filters = reactive({
  pageSection: "",
  category: "",
  productType: "",
  size: "",
  color: "",
  sort: "",
});
const ui = reactive({
  message: "",
  type: "",
});
let searchDebounceTimeoutId = 0;
let stopProductsPageSizeSubscription = () => {};
const { target: loadMoreSentinel, supportsAutoLoad } = useInfiniteScrollSentinel({
  hasMore: hasMoreProducts,
  loading: loadingMoreProducts,
  onLoadMore: loadMoreProducts,
});

const activeQuery = computed(() => String(route.query.q || "").trim());
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
const shouldRequestFacets = computed(() =>
  filtersVisible.value
  || Boolean(filters.pageSection || filters.category || filters.productType || filters.size || filters.color),
);
const hasActiveCatalogFilters = computed(() =>
  Boolean(filters.pageSection || filters.category || filters.productType || filters.size || filters.color),
);

const filteredProducts = computed(() => {
  const nextProducts = [...products.value];

  if (filters.sort === "price-asc") {
    nextProducts.sort((left, right) => Number(left.price || 0) - Number(right.price || 0));
  } else if (filters.sort === "price-desc") {
    nextProducts.sort((left, right) => Number(right.price || 0) - Number(left.price || 0));
  }

  return nextProducts;
});

const resultsLabel = computed(() => {
  if (visualSearchActive.value) {
    if (!products.value.length) {
      return "Nuk u gjet asnje produkt i ngjashem sipas fotos.";
    }

    return totalProductsCount.value > products.value.length
      ? `Po shfaqen ${products.value.length} nga ${totalProductsCount.value} produkte te ngjashme sipas fotos.`
      : `Po shfaqen ${products.value.length} produkte te ngjashme sipas fotos.`;
  }

  if (!products.value.length) {
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

  if (!hasActiveCatalogFilters.value && !filters.sort) {
    return totalProductsCount.value > products.value.length
      ? `Po shfaqen ${products.value.length} nga ${totalProductsCount.value} produkte${scopeLabel}.`
      : `Po shfaqen ${products.value.length} produkte${scopeLabel}.`;
  }

  return totalProductsCount.value > 0
    ? `Po shfaqen ${filteredProducts.value.length} nga ${products.value.length} produkte te ngarkuara (${totalProductsCount.value} gjithsej)${scopeLabel}.`
    : `Po shfaqen ${filteredProducts.value.length} produkte${scopeLabel}.`;
});

watch(
  () => route.fullPath,
  async () => {
    draftQuery.value = activeQuery.value;
    syncFiltersFromRoute();
    clearVisualSearchState();
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
  recentSearches.value = readRecentSearches();
  stopProductsPageSizeSubscription = subscribeProductsPageSize((nextPageSize) => {
    if (nextPageSize === productsPageSize.value) {
      return;
    }

    productsPageSize.value = nextPageSize;
    if (visualSearchActive.value && visualSearchFile.value) {
      void runVisualSearch();
      return;
    }

    void loadProducts();
  });
  draftQuery.value = activeQuery.value;
  syncFiltersFromRoute();
  await bootstrap();
});

onBeforeUnmount(() => {
  window.clearTimeout(searchDebounceTimeoutId);
  stopProductsPageSizeSubscription();
  clearVisualSearchState();
});

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
  };
}

function normalizeProductFacets(rawFacets) {
  return {
    pageSections: Array.isArray(rawFacets?.pageSections) ? rawFacets.pageSections : [],
    categories: Array.isArray(rawFacets?.categories) ? rawFacets.categories : [],
    productTypes: Array.isArray(rawFacets?.productTypes) ? rawFacets.productTypes : [],
    sizes: Array.isArray(rawFacets?.sizes) ? rawFacets.sizes : [],
    colors: Array.isArray(rawFacets?.colors) ? rawFacets.colors : [],
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

  return nextQuery;
}

function routeQueryMatches(nextQuery) {
  const currentQuery = {
    q: String(route.query.q || "").trim(),
    pageSection: String(route.query.pageSection || "").trim().toLowerCase(),
    category: String(route.query.category || "").trim().toLowerCase(),
    productType: String(route.query.productType || "").trim().toLowerCase(),
  };
  const normalizedNextQuery = {
    q: String(nextQuery.q || "").trim(),
    pageSection: String(nextQuery.pageSection || "").trim().toLowerCase(),
    category: String(nextQuery.category || "").trim().toLowerCase(),
    productType: String(nextQuery.productType || "").trim().toLowerCase(),
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
  const { append = false, forceFacets = false } = options;
  const includeFacets = !append && (forceFacets || shouldRequestFacets.value);
  const params = new URLSearchParams();
  params.set("limit", String(productsPageSize.value));
  params.set("offset", String(append ? products.value.length : 0));
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

  const requestUrl = activeQuery.value
    ? `/api/products/search?${params.toString()}`
    : `/api/products?${params.toString()}`;

  const { response, data } = await requestJson(
    requestUrl,
    {},
    { cacheTtlMs: append ? 0 : 10000 },
  );
  if (!response.ok || !data?.ok) {
    ui.message = resolveApiMessage(data, "Produktet nuk u ngarkuan.");
    ui.type = "error";
    if (!append) {
      products.value = [];
      totalProductsCount.value = 0;
      hasMoreProducts.value = false;
      availableFilters.value = createEmptyProductFacets();
    }
    return;
  }

  const nextProducts = Array.isArray(data.products) ? data.products : [];
  products.value = append ? [...products.value, ...nextProducts] : nextProducts;
  totalProductsCount.value = Number(data.total || products.value.length || 0);
  hasMoreProducts.value = Boolean(data.hasMore);
  if (data.facets) {
    availableFilters.value = normalizeProductFacets(data.facets);
  }
  if (!append) {
    applyServerActiveFilters(data.activeFilters);
  }
  ui.message = "";
  ui.type = "";
}

async function loadMoreProducts() {
  if (loadingMoreProducts.value || !hasMoreProducts.value) {
    return;
  }

  loadingMoreProducts.value = true;
  try {
    if (visualSearchActive.value && visualSearchFile.value) {
      await runVisualSearch({ append: true });
    } else {
      await loadProducts({ append: true });
    }
  } finally {
    loadingMoreProducts.value = false;
  }
}

function submitSearch() {
  window.clearTimeout(searchDebounceTimeoutId);
  clearVisualSearchState();
  if (String(draftQuery.value || "").trim()) {
    recentSearches.value = rememberRecentSearch(draftQuery.value);
  }
  updateSearchRouteFromFilters(draftQuery.value);
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
  await runVisualSearch();

  if (event.target) {
    event.target.value = "";
  }
}

async function runVisualSearch(options = {}) {
  if (!visualSearchFile.value) {
    return;
  }

  const { append = false, forceFacets = false } = options;
  visualSearchBusy.value = true;
  const visualScope = buildVisualSearchScope();
  const includeFacets = !append && (forceFacets || shouldRequestFacets.value);

  const result = await searchProductsByImage(visualSearchFile.value, {
    pageSection: visualScope.pageSection,
    category: visualScope.category,
    categoryGroup: visualScope.categoryGroup,
    productType: filters.productType,
    size: filters.size,
    color: filters.color,
    limit: productsPageSize.value,
    offset: append ? products.value.length : 0,
    includeFacets,
  });

  visualSearchBusy.value = false;

  if (!result.ok) {
    if (!append) {
      products.value = [];
      totalProductsCount.value = 0;
      hasMoreProducts.value = false;
      availableFilters.value = createEmptyProductFacets();
    }
    ui.message = result.message;
    ui.type = "error";
    return;
  }

  visualSearchActive.value = true;
  const nextProducts = Array.isArray(result.products) ? result.products : [];
  products.value = append ? [...products.value, ...nextProducts] : nextProducts;
  totalProductsCount.value = Number(result.total || products.value.length || 0);
  hasMoreProducts.value = Boolean(result.hasMore);
  if (result.facets) {
    availableFilters.value = normalizeProductFacets(result.facets);
  }
  if (!append) {
    applyServerActiveFilters(result.activeFilters);
  }
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
  await runVisualSearch();
  return true;
}

function handlePageSectionChange() {
  filters.category = "";
  filters.productType = "";
  if (visualSearchActive.value && visualSearchFile.value) {
    void runVisualSearch();
    return;
  }
  updateSearchRouteFromFilters();
}

function handleCategoryChange() {
  filters.productType = "";
  if (visualSearchActive.value && visualSearchFile.value) {
    void runVisualSearch();
    return;
  }
  updateSearchRouteFromFilters();
}

function handleProductTypeChange() {
  if (visualSearchActive.value && visualSearchFile.value) {
    void runVisualSearch();
    return;
  }
  updateSearchRouteFromFilters();
}

function handleCatalogFilterChange() {
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
  filters.sort = "";

  if (visualSearchActive.value && visualSearchFile.value) {
    void runVisualSearch();
    return;
  }

  const nextQuery = activeQuery.value ? { q: activeQuery.value } : {};
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
</script>

<template>
  <section class="collection-page search-page" aria-label="Kerko produkte">
    <header class="collection-page-header">
      <p class="section-label">Kerko</p>
      <h1>Kerko produktet</h1>
      <p>
        Shkruaj p.sh. `me trego maica te kuqe`, `dua pantallona te gjera` ose fotografo produktin me kamerë.
      </p>
    </header>

    <form class="search-form" role="search" @submit.prevent="submitSearch">
      <input
        v-model="draftQuery"
        class="search-input"
        name="q"
        type="search"
        placeholder="p.sh. me trego maica te kuqe"
        autocomplete="off"
      >
      <button class="search-submit-button" type="submit">Kerko</button>
    </form>

    <section
      v-if="!draftQuery.trim()"
      class="search-assist-panel"
      aria-label="Kerkimet e fundit dhe sugjerimet"
    >
      <div v-if="recentSearches.length > 0" class="search-assist-group">
        <div class="search-assist-group-head">
          <p class="search-assist-title">Kerkuar se fundi</p>
          <button class="search-assist-clear" type="button" @click="clearSearchHistory">Pastro</button>
        </div>
        <div class="search-assist-chip-list">
          <div
            v-for="term in recentSearches"
            :key="term"
            class="search-assist-chip-wrap"
          >
            <button class="search-assist-chip" type="button" @click="applyRecentSearch(term)">
              {{ term }}
            </button>
            <button
              class="search-assist-chip-remove"
              type="button"
              :aria-label="`Hiq ${term} nga historiku`"
              @click.stop="removeRecentSearchEntry(term)"
            >
              <svg viewBox="0 0 24 24" aria-hidden="true">
                <path d="M6 6l12 12M18 6 6 18"></path>
              </svg>
            </button>
          </div>
        </div>
      </div>

      <div class="search-assist-group">
        <p class="search-assist-title">Provoje keto kerkime</p>
        <div class="search-assist-chip-list">
          <button
            v-for="prompt in SEARCH_PROMPT_SUGGESTIONS"
            :key="prompt"
            class="search-assist-chip"
            type="button"
            @click="applyRecentSearch(prompt)"
          >
            {{ prompt }}
          </button>
        </div>
      </div>
    </section>

    <div class="collection-toolbar">
      <div class="collection-toolbar-group">
        <button
          class="filter-toggle-button"
          type="button"
          :aria-expanded="filtersVisible ? 'true' : 'false'"
          @click="toggleFiltersPanel"
        >
          Filtro
        </button>

        <button
          class="filter-toggle-button"
          type="button"
          :disabled="visualSearchBusy"
          @click="openVisualSearchPicker"
        >
          {{ visualSearchBusy ? "Duke analizuar..." : "Kerko me foto" }}
        </button>

        <input
          ref="visualSearchInputElement"
          class="sr-only"
          type="file"
          accept="image/*"
          capture="environment"
          @change="handleVisualSearchSelection"
        >
      </div>
    </div>

    <section v-if="visualSearchFileName" class="visual-search-panel" aria-label="Kerkimi me foto">
      <div class="visual-search-chip">
        <img
          v-if="visualSearchPreviewUrl"
          class="visual-search-chip-image"
          :src="visualSearchPreviewUrl"
          alt="Fotoja e zgjedhur per kerkimin vizual"
          width="120"
          height="120"
        >
        <div class="visual-search-chip-copy">
          <strong>Po kerkohet sipas fotos</strong>
          <span>{{ visualSearchFileName }}</span>
        </div>
        <button class="search-reset-button" type="button" @click="clearVisualSearchAndReload">
          Hiqe foton
        </button>
      </div>
    </section>

    <section v-if="filtersVisible" class="search-filters-panel" aria-label="Filtro produktet">
      <div class="search-filters-grid">
        <label v-if="availablePageSectionOptions.length > 0" class="field">
          <span>Kategoria kryesore</span>
          <select v-model="filters.pageSection" class="search-filter-select" @change="handlePageSectionChange">
            <option value="">Te gjitha kategorite</option>
            <option
              v-for="option in availablePageSectionOptions"
              :key="option.value"
              :value="option.value"
            >
              {{ option.label }}
            </option>
          </select>
        </label>

        <label v-if="filters.pageSection && availableCategoryOptions.length > 0" class="field">
          <span>Nenkategoria</span>
          <select v-model="filters.category" class="search-filter-select" @change="handleCategoryChange">
            <option value="">Te gjitha nenkategorite</option>
            <option
              v-for="option in availableCategoryOptions"
              :key="option.value"
              :value="option.value"
            >
              {{ option.label }}
            </option>
          </select>
        </label>

        <label v-if="shouldShowProductTypeFilter" class="field">
          <span>Produkti</span>
          <select v-model="filters.productType" class="search-filter-select" @change="handleProductTypeChange">
            <option value="">Te gjitha llojet</option>
            <option
              v-for="option in availableProductTypeOptions"
              :key="`${option.category}-${option.value}`"
              :value="option.value"
            >
              {{ option.label }}
            </option>
          </select>
        </label>

        <label v-if="availableSizeOptions.length > 0" class="field">
          <span>Madhesia</span>
          <select v-model="filters.size" class="search-filter-select" @change="handleCatalogFilterChange">
            <option value="">Te gjitha madhesite</option>
            <option
              v-for="option in availableSizeOptions"
              :key="option.value"
              :value="option.value"
            >
              {{ option.label }}
            </option>
          </select>
        </label>

        <label v-if="availableColorOptions.length > 0" class="field">
          <span>Ngjyra</span>
          <select v-model="filters.color" class="search-filter-select" @change="handleCatalogFilterChange">
            <option value="">Te gjitha ngjyrat</option>
            <option
              v-for="option in availableColorOptions"
              :key="option.value"
              :value="option.value"
            >
              {{ option.label }}
            </option>
          </select>
        </label>

        <label class="field">
          <span>Cmimi</span>
          <select v-model="filters.sort" class="search-filter-select">
            <option value="">Renditja standarde</option>
            <option value="price-asc">Nga me i uleti</option>
            <option value="price-desc">Nga me i larti</option>
          </select>
        </label>
      </div>

      <div class="search-filter-actions">
        <button class="search-reset-button" type="button" @click="resetFilters">Pastro filtrat</button>
      </div>
    </section>

    <p class="search-results-label">{{ resultsLabel }}</p>
    <div class="form-message" :class="ui.type" role="status" aria-live="polite">
      {{ ui.message }}
    </div>

    <section v-if="filteredProducts.length > 0" class="pet-products-grid" aria-label="Rezultatet e kerkimit">
      <ProductCard
        v-for="product in filteredProducts"
        :key="product.id"
        :product="product"
        :is-wishlisted="wishlistIds.includes(product.id)"
        :is-in-cart="cartIds.includes(product.id)"
        :wishlist-busy="busyWishlistIds.includes(product.id)"
        :cart-busy="busyCartIds.includes(product.id)"
        @wishlist="handleWishlist"
        @cart="handleCart"
      />
    </section>

    <div v-if="products.length > 0 && hasMoreProducts" class="collection-load-more" :class="{ 'is-auto-loading': supportsAutoLoad }">
      <div
        v-if="supportsAutoLoad"
        ref="loadMoreSentinel"
        class="collection-load-more-sentinel"
        aria-hidden="true"
      ></div>
      <p v-if="loadingMoreProducts" class="collection-load-more-copy">
        Duke ngarkuar edhe 6 produkte...
      </p>
      <button v-else-if="!supportsAutoLoad" class="search-reset-button collection-load-more-button" type="button" :disabled="loadingMoreProducts" @click="loadMoreProducts">
        {{ loadingMoreProducts ? "Duke ngarkuar..." : "Shih me shume" }}
      </button>
    </div>

    <div v-if="products.length === 0" class="collection-empty-state">
      {{ visualSearchActive ? "Nuk u gjet asnje produkt i ngjashem sipas fotos." : "Nuk u gjet asnje produkt per kete kerkim." }}
    </div>
  </section>
</template>
