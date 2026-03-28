<script setup>
import { computed, onBeforeUnmount, onMounted, reactive, ref, watch } from "vue";
import { useRoute } from "vue-router";
import ProductCard from "../components/ProductCard.vue";
import { fetchProtectedCollection, requestJson, resolveApiMessage } from "../lib/api";
import { getProductsPageSize, subscribeProductsPageSize } from "../lib/product-pagination";
import { appState, ensureSessionLoaded, markRouteReady, setCartItems } from "../stores/app-state";
import { getBusinessInitials, getBusinessProfileUrl } from "../lib/shop";

const route = useRoute();
const business = ref(null);
const products = ref([]);
const wishlistIds = ref([]);
const cartIds = ref([]);
const totalProductsCount = ref(0);
const hasMoreProducts = ref(false);
const loadingMoreProducts = ref(false);
const productsPageSize = ref(getProductsPageSize());
const ui = reactive({
  message: "",
  type: "",
});
let stopProductsPageSizeSubscription = () => {};

watch(
  () => route.fullPath,
  async () => {
    await bootstrap();
  },
);

onMounted(async () => {
  stopProductsPageSizeSubscription = subscribeProductsPageSize((nextPageSize) => {
    if (nextPageSize === productsPageSize.value) {
      return;
    }

    productsPageSize.value = nextPageSize;
    void loadProducts();
  });

  await bootstrap();
});

onBeforeUnmount(() => {
  stopProductsPageSizeSubscription();
});

const canFollow = computed(() => {
  if (!business.value) {
    return false;
  }

  if (!appState.user) {
    return true;
  }

  return !(appState.user.role === "business" && Number(appState.user.id) === Number(business.value.userId));
});

const messageHref = computed(() => {
  if (!business.value) {
    return "#";
  }

  if (business.value.ownerEmail) {
    return `mailto:${business.value.ownerEmail}?subject=${encodeURIComponent(`Pershendetje ${business.value.businessName}`)}`;
  }

  if (business.value.phoneNumber) {
    return `tel:${String(business.value.phoneNumber).replace(/\s+/g, "")}`;
  }

  return "#";
});

async function bootstrap() {
  try {
    await Promise.all([
      ensureSessionLoaded().then(() => refreshCollectionState()),
      loadBusiness(),
      loadProducts(),
    ]);
  } finally {
    markRouteReady();
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
  cartIds.value = cartItems.map((item) => item.id);
  setCartItems(cartItems);
}

async function loadBusiness() {
  const businessId = Number(route.query.id || "");
  if (!Number.isFinite(businessId) || businessId <= 0) {
    business.value = null;
    ui.message = "Biznesi nuk u gjet.";
    ui.type = "error";
    return;
  }

  const { response, data } = await requestJson(
    `/api/business/public?id=${encodeURIComponent(businessId)}`,
    {},
    { cacheTtlMs: 20000 },
  );
  if (!response.ok || !data?.ok || !data.business) {
    business.value = null;
    ui.message = resolveApiMessage(data, "Biznesi nuk u gjet.");
    ui.type = "error";
    return;
  }

  business.value = data.business;
  ui.message = "";
  ui.type = "";
}

async function loadProducts(options = {}) {
  const { append = false } = options;
  const businessId = Number(route.query.id || "");
  if (!Number.isFinite(businessId) || businessId <= 0) {
    products.value = [];
    totalProductsCount.value = 0;
    hasMoreProducts.value = false;
    return;
  }

  const offset = append ? products.value.length : 0;
  const { response, data } = await requestJson(
    `/api/business/public-products?id=${encodeURIComponent(businessId)}&limit=${productsPageSize.value}&offset=${offset}`,
    {},
    { cacheTtlMs: 15000 },
  );
  if (!response.ok || !data?.ok) {
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

async function toggleFollow() {
  if (!business.value) {
    return;
  }

  if (!appState.user) {
    ui.message = "Duhet te kyçesh per ta ndjekur biznesin.";
    ui.type = "error";
    return;
  }

  const { response, data } = await requestJson("/api/business/follow-toggle", {
    method: "POST",
    body: JSON.stringify({ businessId: business.value.id }),
  });

  if (!response.ok || !data?.ok) {
    ui.message = resolveApiMessage(data, "Biznesi nuk u perditesua.");
    ui.type = "error";
    return;
  }

  if (data.business) {
    business.value = data.business;
  }

  ui.message = data.message || "Biznesi u perditesua.";
  ui.type = "success";
}

async function handleWishlist(productId) {
  if (!appState.user) {
    ui.message = "Duhet te kyçesh ose te krijosh llogari para se te perdoresh wishlist ose cart.";
    ui.type = "error";
    return;
  }

  const hadItem = wishlistIds.value.includes(productId);
  wishlistIds.value = hadItem
    ? wishlistIds.value.filter((id) => id !== productId)
    : [...wishlistIds.value, productId];

  const { response, data } = await requestJson("/api/wishlist/toggle", {
    method: "POST",
    body: JSON.stringify({ productId }),
  });

  if (!response.ok || !data?.ok) {
    wishlistIds.value = hadItem
      ? [...wishlistIds.value, productId]
      : wishlistIds.value.filter((id) => id !== productId);
    ui.message = resolveApiMessage(data, "Wishlist nuk u perditesua.");
    ui.type = "error";
    return;
  }

  wishlistIds.value = Array.isArray(data.items) ? data.items.map((item) => item.id) : [];
  ui.message = data.message || "Wishlist u perditesua.";
  ui.type = "success";
}

async function handleCart(productId) {
  if (!appState.user) {
    ui.message = "Duhet te kyçesh ose te krijosh llogari para se te perdoresh wishlist ose cart.";
    ui.type = "error";
    return;
  }

  if (!cartIds.value.includes(productId)) {
    cartIds.value = [...cartIds.value, productId];
  }

  const { response, data } = await requestJson("/api/cart/add", {
    method: "POST",
    body: JSON.stringify({ productId }),
  });

  if (!response.ok || !data?.ok) {
    cartIds.value = cartIds.value.filter((id) => id !== productId);
    ui.message = resolveApiMessage(data, "Shporta nuk u perditesua.");
    ui.type = "error";
    return;
  }

  const items = Array.isArray(data.items) ? data.items : [];
  cartIds.value = items.map((item) => item.id);
  setCartItems(items);
  ui.message = data.message || "Produkti u shtua ne shporte.";
  ui.type = "success";
}
</script>

<template>
  <section class="business-public-page" aria-label="Profili publik i biznesit">
    <div class="form-message" :class="ui.type" role="status" aria-live="polite">
      {{ ui.message }}
    </div>

    <section v-if="business" class="card business-public-hero">
      <div class="business-public-hero-layout">
        <div class="business-public-branding">
          <div class="business-public-logo-shell">
            <img
              v-if="business.logoPath"
              class="business-public-logo"
              :src="business.logoPath"
              :alt="business.businessName"
              width="240"
              height="240"
              loading="lazy"
              decoding="async"
            >
            <span v-else class="business-public-logo-fallback">
              {{ getBusinessInitials(business.businessName) }}
            </span>
          </div>

          <div class="business-public-copy">
            <p class="section-label">Biznes partner</p>
            <h1>{{ business.businessName }}</h1>
            <p class="section-text">
              {{ business.businessDescription || "Ky biznes ende nuk ka shtuar pershkrim." }}
            </p>
          </div>
        </div>

        <div class="business-public-actions">
          <button
            class="nav-action business-follow-button"
            :class="business.isFollowed ? 'nav-action-secondary' : 'nav-action-primary'"
            type="button"
            :disabled="!canFollow"
            @click="toggleFollow"
          >
            {{ business.isFollowed ? "Following" : "Follow" }}
          </button>

          <a
            class="nav-action nav-action-secondary business-message-button"
            :class="{ 'is-disabled': messageHref === '#' }"
            :href="messageHref"
            :aria-disabled="messageHref === '#'"
          >
            Message
          </a>
        </div>

        <div class="business-public-stats">
          <div class="summary-chip">
            <span>Produktet publike</span>
            <strong>{{ business.productsCount || 0 }}</strong>
          </div>
          <div class="summary-chip">
            <span>Followers</span>
            <strong>{{ business.followersCount || 0 }}</strong>
          </div>
          <div class="summary-chip">
            <span>Qyteti</span>
            <strong>{{ business.city || "-" }}</strong>
          </div>
          <div class="summary-chip">
            <span>Telefoni</span>
            <strong>{{ business.phoneNumber || "-" }}</strong>
          </div>
          <div class="summary-chip">
            <span>Adresa</span>
            <strong>{{ business.addressLine || "-" }}</strong>
          </div>
          <div class="summary-chip">
            <span>Kontakti</span>
            <strong>{{ business.ownerEmail || "Kontakto me telefon" }}</strong>
          </div>
        </div>
      </div>
    </section>

    <div v-else class="business-public-empty-state">
      <h1>Biznesi nuk u gjet.</h1>
    </div>

    <section class="business-public-products-section">
      <div class="collection-page-header business-public-products-header">
        <p class="section-label">Artikujt e biznesit</p>
        <h2>Produktet publike</h2>
        <p>Shfleto artikujt qe ky biznes i ka publikuar ne TREGO.</p>
      </div>

      <section v-if="products.length > 0" class="pet-products-grid" aria-label="Produktet e biznesit">
        <ProductCard
          v-for="product in products"
          :key="product.id"
          :product="product"
          :is-wishlisted="wishlistIds.includes(product.id)"
          :is-in-cart="cartIds.includes(product.id)"
          @wishlist="handleWishlist"
          @cart="handleCart"
        />
      </section>

      <div v-if="products.length > 0 && hasMoreProducts" class="collection-load-more">
        <button class="search-reset-button collection-load-more-button" type="button" :disabled="loadingMoreProducts" @click="loadMoreProducts">
          {{ loadingMoreProducts ? "Duke ngarkuar..." : "Shih me shume" }}
        </button>
      </div>

      <div v-else class="pets-empty-state">
        Ky biznes ende nuk ka produkte publike.
      </div>
    </section>
  </section>
</template>
