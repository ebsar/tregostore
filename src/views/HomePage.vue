<script setup>
import { computed, onMounted, reactive, ref } from "vue";
import { RouterLink } from "vue-router";
import ProductCard from "../components/ProductCard.vue";
import PromoSlider from "../components/PromoSlider.vue";
import { fetchProtectedCollection, requestJson, resolveApiMessage } from "../lib/api";
import { HOME_PROMO_SLIDES, getBusinessInitials, getBusinessProfileUrl } from "../lib/shop";
import { appState, ensureSessionLoaded, markRouteReady, setCartItems } from "../stores/app-state";

const PRODUCTS_PAGE_SIZE = 12;
const products = ref([]);
const businesses = ref([]);
const wishlistIds = ref([]);
const cartIds = ref([]);
const busyWishlistIds = ref([]);
const busyCartIds = ref([]);
const totalProductsCount = ref(0);
const hasMoreProducts = ref(false);
const loadingMoreProducts = ref(false);
const filtersVisible = ref(false);
const statusText = ref("Po ngarkohen produktet publike te TREGO.");
const filters = reactive({
  size: "",
  color: "",
  sort: "",
});
const ui = reactive({
  message: "",
  type: "",
});

const filteredProducts = computed(() => {
  let nextProducts = [...products.value];

  if (filters.size) {
    nextProducts = nextProducts.filter((product) => String(product.size || "") === filters.size);
  }

  if (filters.color) {
    nextProducts = nextProducts.filter((product) => String(product.color || "") === filters.color);
  }

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
  try {
    await ensureSessionLoaded();
    await refreshCollectionState();
    await loadProducts();
    markRouteReady();
    void loadBusinesses();
  } catch (error) {
    statusText.value = "Produktet nuk u ngarkuan. Provoje perseri pas pak.";
    console.error(error);
    markRouteReady();
  }
});

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
  cartIds.value = cartItems.map((item) => item.id);
  setCartItems(cartItems);
}

async function loadProducts(options = {}) {
  const { append = false } = options;
  const offset = append ? products.value.length : 0;
  const { response, data } = await requestJson(
    `/api/products?limit=${PRODUCTS_PAGE_SIZE}&offset=${offset}`,
    {},
    { cacheTtlMs: 10000 },
  );
  if (!response.ok || !data?.ok) {
    statusText.value = resolveApiMessage(data, "Produktet nuk u ngarkuan.");
    if (!append) {
      products.value = [];
      totalProductsCount.value = 0;
      hasMoreProducts.value = false;
    }
    return;
  }

  const nextProducts = Array.isArray(data.products) ? data.products : [];
  products.value = append ? [...products.value, ...nextProducts] : nextProducts;
  totalProductsCount.value = Number(data.total || products.value.length || 0);
  hasMoreProducts.value = Boolean(data.hasMore);
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

function setMessage(message, type = "") {
  ui.message = message;
  ui.type = type;
}

function resetFilters() {
  filters.size = "";
  filters.color = "";
  filters.sort = "";
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
}

async function handleCart(productId) {
  if (!appState.user) {
    setMessage(
      "Duhet te kyçesh ose te krijosh llogari para se te perdoresh wishlist ose cart.",
      "error",
    );
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
  cartIds.value = items.map((item) => item.id);
  setCartItems(items);
  setMessage(data.message || "Produkti u shtua ne shporte.", "success");
}
</script>

<template>
  <section class="collection-page home-collection-page" aria-label="Faqja kryesore">
    <PromoSlider :slides="HOME_PROMO_SLIDES" />

    <header class="collection-page-header home-collection-header">
      <p class="section-label">Produktet</p>
      <h1>Te gjitha produktet</h1>
      <p>{{ collectionLabel }}</p>
    </header>

    <div class="collection-toolbar">
      <button
        class="filter-toggle-button"
        type="button"
        :aria-expanded="filtersVisible ? 'true' : 'false'"
        @click="filtersVisible = !filtersVisible"
      >
        Filtro
      </button>
    </div>

    <section v-if="filtersVisible" class="search-filters-panel" aria-label="Filtro produktet ne faqen kryesore">
      <div class="search-filters-grid">
        <label class="field">
          <span>Madhesia</span>
          <select v-model="filters.size" class="search-filter-select">
            <option value="">Te gjitha madhesite</option>
            <option value="XS">XS</option>
            <option value="S">S</option>
            <option value="M">M</option>
            <option value="L">L</option>
            <option value="XL">XL</option>
          </select>
        </label>

        <label class="field">
          <span>Ngjyra</span>
          <select v-model="filters.color" class="search-filter-select">
            <option value="">Te gjitha ngjyrat</option>
            <option value="bardhe">Bardhe</option>
            <option value="zeze">Zeze</option>
            <option value="gri">Gri</option>
            <option value="beige">Beige</option>
            <option value="kafe">Kafe</option>
            <option value="kuqe">Kuqe</option>
            <option value="roze">Roze</option>
            <option value="vjollce">Vjollce</option>
            <option value="blu">Blu</option>
            <option value="gjelber">Gjelber</option>
            <option value="verdhe">Verdhe</option>
            <option value="portokalli">Portokalli</option>
            <option value="shume-ngjyra">Shume ngjyra</option>
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
        {{ loadingMoreProducts ? "Duke ngarkuar..." : "Shfaq me shume" }}
      </button>
    </div>

    <div v-else class="collection-empty-state">
      Nuk ka produkte publike ende.
    </div>

    <section
      v-if="businesses.length > 0"
      class="home-businesses-section"
      aria-label="Bizneset me te cilat punojme"
    >
      <header class="collection-page-header home-businesses-header">
        <p class="section-label">Bizneset partnere</p>
        <h2>Bizneset me te cilat punojme</h2>
        <p>
          Emrat dhe logot e bizneseve qe kane regjistruar profilin e tyre ne TREGO.
        </p>
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
