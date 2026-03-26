<script setup>
import { onMounted, reactive, ref } from "vue";
import ProductCard from "../components/ProductCard.vue";
import PromoSlider from "../components/PromoSlider.vue";
import { fetchProtectedCollection, requestJson, resolveApiMessage } from "../lib/api";
import { HOME_PROMO_SLIDES, getBusinessInitials, getBusinessProfileUrl } from "../lib/shop";
import { appState, ensureSessionLoaded, markRouteReady, setCartItems } from "../stores/app-state";

const products = ref([]);
const businesses = ref([]);
const wishlistIds = ref([]);
const cartIds = ref([]);
const busyWishlistIds = ref([]);
const busyCartIds = ref([]);
const statusText = ref("Po ngarkohen produktet publike te TREGO.");
const ui = reactive({
  message: "",
  type: "",
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

async function loadProducts() {
  const { response, data } = await requestJson("/api/products");
  if (!response.ok || !data?.ok) {
    statusText.value = resolveApiMessage(data, "Produktet nuk u ngarkuan.");
    products.value = [];
    return;
  }

  products.value = Array.isArray(data.products) ? data.products : [];
  statusText.value =
    products.value.length > 0
      ? `Po shfaqen ${products.value.length} produkte publike te TREGO.`
      : "Nuk ka produkte publike ende.";
}

async function loadBusinesses() {
  const { response, data } = await requestJson("/api/businesses/public");
  if (!response.ok || !data?.ok) {
    return;
  }

  businesses.value = Array.isArray(data.businesses) ? data.businesses : [];
}

function setMessage(message, type = "") {
  ui.message = message;
  ui.type = type;
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
  setMessage(data.message || "Wishlist u perditesua.", "success");
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
      <p>{{ statusText }}</p>
    </header>

    <div class="form-message" :class="ui.type" role="status" aria-live="polite">
      {{ ui.message }}
    </div>

    <section v-if="products.length > 0" class="pet-products-grid" aria-label="Te gjitha produktet">
      <ProductCard
        v-for="product in products"
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
            <a class="home-business-badge" :href="business.profileUrl || getBusinessProfileUrl(business.id)">
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
            </a>
          </template>
        </div>
      </div>
    </section>
  </section>
</template>
