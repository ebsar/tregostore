<script setup>
import { computed, onBeforeUnmount, onMounted, reactive, ref, watch } from "vue";
import { RouterLink, useRouter } from "vue-router";
import ProductCard from "../components/ProductCard.vue";
import PromoSlider from "../components/PromoSlider.vue";
import { fetchProtectedCollection, requestJson, resolveApiMessage } from "../lib/api";
import { getProductsPageSize, subscribeProductsPageSize } from "../lib/product-pagination";
import { HOME_PROMO_SLIDES, getBusinessInitials, getBusinessProfileUrl, getProductDetailUrl } from "../lib/shop";
import { appState, ensureSessionLoaded, markRouteReady, setCartItems } from "../stores/app-state";

const router = useRouter();
const products = ref([]);
const businesses = ref([]);
const businessProfile = ref(null);
const businessProducts = ref([]);
const wishlistIds = ref([]);
const cartIds = ref([]);
const busyWishlistIds = ref([]);
const busyCartIds = ref([]);
const totalProductsCount = ref(0);
const hasMoreProducts = ref(false);
const loadingMoreProducts = ref(false);
const filtersVisible = ref(false);
const statusText = ref("Po ngarkohen produktet publike te TREGO.");
const productsPageSize = ref(getProductsPageSize());
const availableFilters = ref(createEmptyProductFacets());
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
const businessUi = reactive({
  message: "",
  type: "",
});
let stopProductsPageSizeSubscription = () => {};
const isBusinessUser = computed(() => appState.user?.role === "business");

const businessDisplayName = computed(() =>
  String(
    businessProfile.value?.businessName
    || appState.user?.businessName
    || appState.user?.fullName
    || "Biznesi yt",
  ).trim(),
);

const businessDescription = computed(() =>
  String(businessProfile.value?.businessDescription || "").trim()
  || "Nga kjo faqe ke qasje direkte te profili yt, artikujt e biznesit dhe veprimet kryesore.",
);

const businessPublicProfileUrl = computed(() =>
  String(businessProfile.value?.publicProfileUrl || appState.user?.businessProfileUrl || "").trim(),
);

const businessFollowersCount = computed(() => Math.max(0, Number(businessProfile.value?.followersCount || 0)));
const businessOrdersCount = computed(() => Math.max(0, Number(businessProfile.value?.ordersCount || 0)));
const businessProductsCount = computed(() =>
  Math.max(
    0,
    businessProducts.value.length || Number(businessProfile.value?.productsCount || 0),
  ),
);

const availablePageSectionOptions = computed(() => availableFilters.value.pageSections);
const availableCategoryOptions = computed(() =>
  availableFilters.value.categories.filter((option) =>
    !filters.pageSection || String(option.pageSection || "") === filters.pageSection,
  ),
);
const availableProductTypeOptions = computed(() =>
  availableFilters.value.productTypes.filter((option) =>
    (!filters.pageSection || String(option.pageSection || "") === filters.pageSection)
    && (!filters.category || String(option.category || "") === filters.category),
  ),
);
const availableSizeOptions = computed(() => availableFilters.value.sizes);
const availableColorOptions = computed(() => availableFilters.value.colors);
const shouldRequestFacets = computed(() =>
  filtersVisible.value
  || Boolean(filters.pageSection || filters.category || filters.productType || filters.size || filters.color),
);

const filteredProducts = computed(() => {
  let nextProducts = [...products.value];

  if (filters.sort === "price-asc") {
    nextProducts.sort((left, right) => Number(left.price || 0) - Number(right.price || 0));
  } else if (filters.sort === "price-desc") {
    nextProducts.sort((left, right) => Number(right.price || 0) - Number(left.price || 0));
  }

  return nextProducts;
});

const collectionLabel = computed(() => {
  if (!products.value.length) {
    return "Nuk ka produkte publike ende.";
  }

  if (!filters.size && !filters.color && !filters.sort) {
    return totalProductsCount.value > products.value.length
      ? `Po shfaqen ${products.value.length} nga ${totalProductsCount.value} produkte publike te TREGO.`
      : statusText.value;
  }

  return totalProductsCount.value > 0
    ? `Po shfaqen ${filteredProducts.value.length} nga ${products.value.length} produkte te ngarkuara (${totalProductsCount.value} gjithsej) sipas filtrave te zgjedhur.`
    : `Po shfaqen ${filteredProducts.value.length} nga ${products.value.length} produkte sipas filtrave te zgjedhur.`;
});

onMounted(async () => {
  stopProductsPageSizeSubscription = subscribeProductsPageSize((nextPageSize) => {
    if (nextPageSize === productsPageSize.value) {
      return;
    }

    productsPageSize.value = nextPageSize;
    if (!isBusinessUser.value) {
      void loadProducts();
    }
  });

  try {
    const sessionPromise = ensureSessionLoaded();
    const publicProductsPromise = loadProducts();
    const user = await sessionPromise;
    if (user?.role === "business") {
      await Promise.all([loadBusinessProfile(), loadBusinessProducts()]);
      markRouteReady();
      return;
    }

    await publicProductsPromise;
    markRouteReady();
    void refreshCollectionState().catch((error) => {
      console.error(error);
    });
    void loadBusinesses();
  } catch (error) {
    statusText.value = "Produktet nuk u ngarkuan. Provoje perseri pas pak.";
    console.error(error);
    markRouteReady();
  }
});

onBeforeUnmount(() => {
  stopProductsPageSizeSubscription();
});

watch(
  () => appState.catalogRevision,
  async (nextRevision, previousRevision) => {
    if (nextRevision === previousRevision) {
      return;
    }

    if (isBusinessUser.value) {
      await Promise.all([loadBusinessProfile(), loadBusinessProducts()]);
      return;
    }

    await loadProducts();
  },
);

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

async function loadProducts(options = {}) {
  const { append = false, forceFacets = false } = options;
  const offset = append ? products.value.length : 0;
  const includeFacets = !append && (forceFacets || shouldRequestFacets.value);
  const params = new URLSearchParams();
  params.set("limit", String(productsPageSize.value));
  params.set("offset", String(offset));
  if (includeFacets) {
    params.set("includeFacets", "1");
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

  const { response, data } = await requestJson(
    `/api/products?${params.toString()}`,
    {},
    { cacheTtlMs: append ? 0 : 15000 },
  );
  if (!response.ok || !data?.ok) {
    statusText.value = resolveApiMessage(data, "Produktet nuk u ngarkuan.");
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
  statusText.value =
    totalProductsCount.value > 0
      ? `Po shfaqen ${products.value.length} nga ${totalProductsCount.value} produkte publike te TREGO.`
      : "Nuk ka produkte publike ende.";
}

async function loadMoreProducts() {
  if (loadingMoreProducts.value || !hasMoreProducts.value) {
    return;
  }

  loadingMoreProducts.value = true;
  try {
    await loadProducts({ append: true });
  } finally {
    loadingMoreProducts.value = false;
  }
}

async function loadBusinesses() {
  const { response, data } = await requestJson("/api/businesses/public", {}, { cacheTtlMs: 30000 });
  if (!response.ok || !data?.ok) {
    return;
  }

  businesses.value = Array.isArray(data.businesses) ? data.businesses : [];
}

async function loadBusinessProfile() {
  const { response, data } = await requestJson("/api/business-profile");
  if (!response.ok || !data?.ok) {
    businessProfile.value = null;
    businessUi.message = resolveApiMessage(data, "Profili i biznesit nuk u ngarkua.");
    businessUi.type = "error";
    return;
  }

  businessProfile.value = data.profile || null;
  if (!businessProfile.value) {
    businessUi.message = "Plotesoje profilin e biznesit per te filluar me publikimin e artikujve.";
    businessUi.type = "";
    return;
  }

  businessUi.message = "";
  businessUi.type = "";
}

async function loadBusinessProducts() {
  const { response, data } = await requestJson("/api/business/products");
  if (!response.ok || !data?.ok) {
    businessProducts.value = [];
    businessUi.message = resolveApiMessage(data, "Artikujt e biznesit nuk u ngarkuan.");
    businessUi.type = "error";
    return;
  }

  businessProducts.value = Array.isArray(data.products) ? data.products : [];
  if (businessProfile.value) {
    businessUi.message = "";
    businessUi.type = "";
  }
}

function setMessage(message, type = "") {
  ui.message = message;
  ui.type = type;
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

function handlePageSectionChange() {
  filters.category = "";
  filters.productType = "";
  void loadProducts();
}

function handleCategoryChange() {
  filters.productType = "";
  void loadProducts();
}

function handleCatalogFilterChange() {
  void loadProducts();
}

function toggleFiltersPanel() {
  filtersVisible.value = !filtersVisible.value;
  if (filtersVisible.value && availablePageSectionOptions.value.length === 0) {
    void loadProducts({ forceFacets: true });
  }
}

function resetFilters() {
  filters.pageSection = "";
  filters.category = "";
  filters.productType = "";
  filters.size = "";
  filters.color = "";
  filters.sort = "";
  void loadProducts();
}

async function handleWishlist(productId) {
  if (!appState.user) {
    setMessage(
      "Duhet te kyçesh ose te krijosh llogari para se te perdoresh wishlist ose cart.",
      "error",
    );
    return;
  }

  busyWishlistIds.value = [...busyWishlistIds.value, productId];
  const isWishlisted = wishlistIds.value.includes(productId);
  wishlistIds.value = isWishlisted
    ? wishlistIds.value.filter((id) => id !== productId)
    : [...wishlistIds.value, productId];

  const { response, data } = await requestJson("/api/wishlist/toggle", {
    method: "POST",
    body: JSON.stringify({ productId }),
  });

  busyWishlistIds.value = busyWishlistIds.value.filter((id) => id !== productId);

  if (!response.ok || !data?.ok) {
    wishlistIds.value = isWishlisted
      ? [...wishlistIds.value, productId]
      : wishlistIds.value.filter((id) => id !== productId);
    setMessage(resolveApiMessage(data, "Wishlist nuk u perditesua."), "error");
    return;
  }

  wishlistIds.value = Array.isArray(data.items) ? data.items.map((item) => item.id) : [];
  setMessage(data.message || "Produkti u shtua ne shporte.", "success");
  if (!isWishlisted) {
    window.dispatchEvent(new CustomEvent("trego:toast", {
      detail: { message: "Artikulli eshte shtuar ne wishlist." },
    }));
  }
}

async function handleCart(productId) {
  if (!appState.user) {
    setMessage(
      "Duhet te kyçesh ose te krijosh llogari para se te perdoresh wishlist ose cart.",
      "error",
    );
    return;
  }

  const product = products.value.find((entry) => Number(entry.id) === Number(productId));
  if (product?.requiresVariantSelection) {
    router.push(getProductDetailUrl(productId, "/"));
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
    setMessage(resolveApiMessage(data, "Shporta nuk u perditesua."), "error");
    return;
  }

  const items = Array.isArray(data.items) ? data.items : [];
  cartIds.value = items.map((item) => item.productId || item.id);
  setCartItems(items);
  setMessage(data.message || "Produkti u shtua ne shporte.", "success");
}
</script>

<template>
  <section v-if="isBusinessUser" class="collection-page business-home-page" aria-label="Faqja kryesore e biznesit">
    <section class="card business-home-hero">
      <div class="business-home-branding">
        <div class="business-home-logo-shell">
          <img
            v-if="businessProfile?.logoPath"
            class="business-home-logo"
            :src="businessProfile.logoPath"
            :alt="businessDisplayName"
            width="220"
            height="220"
          >
          <span v-else class="business-home-logo-fallback">
            {{ getBusinessInitials(businessDisplayName) }}
          </span>
        </div>

        <div class="business-home-copy">
          <p class="section-label">Business mode</p>
          <h1>{{ businessDisplayName }}</h1>
          <p class="section-text">{{ businessDescription }}</p>
        </div>
      </div>

      <div class="business-home-actions">
        <RouterLink class="nav-action nav-action-primary" to="/biznesi-juaj?view=add-product">
          Shto artikull
        </RouterLink>
        <RouterLink class="nav-action nav-action-secondary" to="/biznesi-juaj">
          Menaxho profilin
        </RouterLink>
        <RouterLink
          v-if="businessPublicProfileUrl"
          class="nav-action nav-action-secondary"
          :to="businessPublicProfileUrl"
        >
          Profili publik
        </RouterLink>
      </div>
    </section>

    <div class="business-home-summary-grid">
      <article class="card business-home-stat">
        <span class="business-home-stat-label">Ndjekesit</span>
        <strong>{{ businessFollowersCount }}</strong>
        <p>Shiko si po rritet interesi per biznesin tend.</p>
      </article>

      <article class="card business-home-stat">
        <span class="business-home-stat-label">Artikujt e tu</span>
        <strong>{{ businessProductsCount }}</strong>
        <p>Te gjitha produktet qe ke publikuar ose ruajtur ne panel.</p>
      </article>

      <article class="card business-home-stat">
        <span class="business-home-stat-label">Porosite</span>
        <strong>{{ businessOrdersCount }}</strong>
        <p>Numri i porosive ku jane perfshire produktet e biznesit tend.</p>
      </article>
    </div>

    <section class="card business-home-contact">
      <div>
        <p class="section-label">Kontaktet</p>
        <h2>Mesazhet dhe ndjekesit</h2>
        <p class="section-text">
          Ketu ke qasje te shpejte te inbox-it te mesazheve dhe profilit publik te biznesit.
        </p>
      </div>

      <div class="business-home-contact-actions">
        <RouterLink class="nav-action nav-action-secondary" to="/mesazhet">
          Hape mesazhet
        </RouterLink>
        <RouterLink
          v-if="businessPublicProfileUrl"
          class="nav-action nav-action-primary"
          :to="businessPublicProfileUrl"
        >
          Shiko ndjekesit
        </RouterLink>
      </div>
    </section>

    <div class="form-message" :class="businessUi.type" role="status" aria-live="polite">
      {{ businessUi.message }}
    </div>

    <section class="business-home-products" aria-label="Produktet e biznesit tend">
      <header class="collection-page-header business-home-products-header">
        <p class="section-label">Produktet e tua</p>
        <h2>Lista e artikujve</h2>
        <p>
          Ne homepage te biznesit shfaqen vetem profili yt, produktet e tua dhe qasja direkte per shtim artikujsh.
        </p>
      </header>

      <section v-if="businessProducts.length > 0" class="pet-products-grid business-home-products-grid">
        <ProductCard
          v-for="product in businessProducts"
          :key="product.id"
          :product="product"
          :show-overlay-actions="false"
          :show-business-name="false"
        />
      </section>

      <div v-else class="collection-empty-state business-home-empty-state">
        Nuk ke artikuj ende. Shto produktin e pare dhe ai do te shfaqet ketu.
      </div>
    </section>

    <section class="card business-home-bottom-cta">
      <div>
        <p class="section-label">Veprimi i shpejte</p>
        <h2>Shto produkte te reja</h2>
        <p class="section-text">
          Kalo direkt te forma e artikullit dhe vazhdo me publikimin e produkteve te biznesit tend.
        </p>
      </div>

      <RouterLink class="hero-cta" to="/biznesi-juaj?view=add-product">
        Shto artikull
      </RouterLink>
    </section>
  </section>

  <section v-else class="collection-page home-collection-page" aria-label="Faqja kryesore">
    <PromoSlider :slides="HOME_PROMO_SLIDES" />

    <header class="collection-page-header home-collection-header">
      <p class="section-label">Produktet</p>
    </header>

    <div class="collection-toolbar">
      <button
        class="filter-toggle-button"
        type="button"
        :aria-expanded="filtersVisible ? 'true' : 'false'"
        @click="toggleFiltersPanel"
      >
        Filtro
      </button>
    </div>

    <section v-if="filtersVisible" class="search-filters-panel" aria-label="Filtro produktet ne faqen kryesore">
      <div class="search-filters-grid">
        <label v-if="availablePageSectionOptions.length > 0" class="field">
          <span>Kategoria e faqes</span>
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

        <label v-if="availableCategoryOptions.length > 0" class="field">
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

        <label v-if="availableProductTypeOptions.length > 0" class="field">
          <span>Lloji i produktit</span>
          <select v-model="filters.productType" class="search-filter-select" @change="handleCatalogFilterChange">
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

    <div class="form-message" :class="ui.type" role="status" aria-live="polite">
      {{ ui.message }}
    </div>

    <section v-if="filteredProducts.length > 0" class="pet-products-grid" aria-label="Te gjitha produktet">
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

    <div v-if="products.length > 0 && hasMoreProducts" class="collection-load-more">
      <button class="search-reset-button collection-load-more-button" type="button" :disabled="loadingMoreProducts" @click="loadMoreProducts">
        {{ loadingMoreProducts ? "Duke ngarkuar..." : "Shih me shume" }}
      </button>
    </div>

    <div v-if="products.length === 0" class="collection-empty-state">
      Nuk ka produkte publike ende.
    </div>

    <section
      v-if="businesses.length > 0"
      class="home-businesses-section"
      aria-label="Bizneset me te cilat punojme"
    >
      <header class="collection-page-header home-businesses-header">
        <p class="section-label">Bizneset partnere</p>
      </header>

      <div class="home-businesses-marquee" aria-live="polite">
        <div class="home-businesses-track">
          <template v-for="(business, index) in [...businesses, ...businesses]" :key="`${business.id}-${index}`">
            <RouterLink class="home-business-badge" :to="business.profileUrl || getBusinessProfileUrl(business.id)">
              <div class="home-business-logo-shell">
                <img
                  v-if="business.logoPath"
                  class="home-business-logo"
                  :src="business.logoPath"
                  :alt="business.businessName"
                  width="160"
                  height="160"
                  loading="lazy"
                  decoding="async"
                >
                <span v-else class="home-business-logo-fallback">
                  {{ getBusinessInitials(business.businessName) }}
                </span>
              </div>
              <div class="home-business-copy">
                <strong>{{ business.businessName }}</strong>
                <span>{{ business.city || "Partner i TREGO" }}</span>
              </div>
            </RouterLink>
          </template>
        </div>
      </div>
    </section>
  </section>
</template>
