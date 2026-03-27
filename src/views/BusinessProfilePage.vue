<script setup>
import { computed, onMounted, reactive, ref, watch } from "vue";
import { useRoute } from "vue-router";
import ProductCard from "../components/ProductCard.vue";
import ProductListSkeleton from "../components/ProductListSkeleton.vue";
import { fetchProtectedCollection, requestJson, resolveApiMessage } from "../lib/api";
import { fetchBusinessPublicProductsPage, usePaginatedProductsQuery } from "../lib/paginated-products";
import { appState, ensureSessionLoaded, markRouteReady, setCartItems } from "../stores/app-state";
import { getBusinessInitials, getBusinessProfileUrl } from "../lib/shop";

const route = useRoute();
const business = ref(null);
const wishlistIds = ref([]);
const cartIds = ref([]);
const routeReadyMarked = ref(false);
const businessLoadComplete = ref(false);
const ui = reactive({
  message: "",
  type: "",
});
const businessId = computed(() => {
  const nextBusinessId = Number(route.query.id || "");
  return Number.isFinite(nextBusinessId) && nextBusinessId > 0 ? nextBusinessId : 0;
});
const productsQuery = usePaginatedProductsQuery({
  queryKey: computed(() => ["business", "public-products", businessId.value]),
  enabled: computed(() => businessId.value > 0),
  fetchPage: ({ offset, limit }) =>
    fetchBusinessPublicProductsPage({
      businessId: businessId.value,
      offset,
      limit,
    }),
  errorMessage: "Produktet e biznesit nuk u ngarkuan.",
  loadMoreErrorMessage: "Produktet e tjera te biznesit nuk u ngarkuan.",
});
const products = productsQuery.products;

watch(
  () => route.fullPath,
  async () => {
    routeReadyMarked.value = false;
    await bootstrap();
  },
);

onMounted(async () => {
  await bootstrap();
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
  businessLoadComplete.value = false;

  try {
    void syncCollectionStateInBackground();
    await loadBusiness();
  } catch (error) {
    console.error(error);
  } finally {
    businessLoadComplete.value = true;
  }
}

watch(
  () => [
    businessLoadComplete.value,
    businessId.value > 0 ? productsQuery.isInitialLoading.value : false,
  ],
  ([businessReady, isInitialLoading]) => {
    if (!businessReady || isInitialLoading || routeReadyMarked.value) {
      return;
    }

    routeReadyMarked.value = true;
    markRouteReady();
  },
  { immediate: true },
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
  cartIds.value = cartItems.map((item) => item.id);
  setCartItems(cartItems);
}

async function loadBusiness() {
  if (!businessId.value) {
    business.value = null;
    ui.message = "Biznesi nuk u gjet.";
    ui.type = "error";
    return;
  }

  const { response, data } = await requestJson(
    `/api/business/public?id=${encodeURIComponent(businessId.value)}`,
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

async function syncCollectionStateInBackground() {
  try {
    await ensureSessionLoaded();
    await refreshCollectionState();
  } catch (error) {
    console.error(error);
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

async function loadMoreProducts() {
  await productsQuery.loadMore();
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

      <ProductListSkeleton
        v-if="productsQuery.isInitialLoading"
        :count="10"
        variant="catalog"
      />

      <section v-else-if="products.length > 0" class="pet-products-grid" aria-label="Produktet e biznesit">
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

      <div v-if="products.length > 0 && productsQuery.hasMore" class="collection-load-more">
        <button
          class="search-reset-button collection-load-more-button"
          type="button"
          :disabled="productsQuery.isLoadingMore"
          @click="loadMoreProducts"
        >
          <span class="collection-load-more-button-content">
            <span
              v-if="productsQuery.isLoadingMore"
              class="collection-load-more-spinner"
              aria-hidden="true"
            ></span>
            <span>{{ productsQuery.isLoadingMore ? "Duke ngarkuar..." : "Shfaq me shume" }}</span>
          </span>
        </button>
      </div>

      <p v-else-if="products.length > 0" class="collection-load-more-note">
        Po shfaqen te gjitha produktet e disponueshme.
      </p>

      <div
        v-if="productsQuery.loadMoreErrorMessage"
        class="form-message error collection-inline-error"
        role="status"
        aria-live="polite"
      >
        {{ productsQuery.loadMoreErrorMessage }}
      </div>

      <div v-if="!productsQuery.isInitialLoading && products.length === 0" class="pets-empty-state">
        {{ productsQuery.errorMessage || "Ky biznes ende nuk ka produkte publike." }}
      </div>
    </section>
  </section>
</template>
