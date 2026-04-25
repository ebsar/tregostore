<script setup>
import { computed, onBeforeUnmount, onMounted, reactive, ref, watch } from "vue";
import { RouterLink, useRoute, useRouter } from "vue-router";
import ProductCard from "../components/ProductCard.vue";
import { useInfiniteScrollSentinel } from "../composables/useInfiniteScrollSentinel";
import { fetchProtectedCollection, requestJson, resolveApiMessage } from "../lib/api";
import { getProductsPageSize, subscribeProductsPageSize } from "../lib/product-pagination";
import { applyDocumentSeo, buildAbsoluteUrl, buildBreadcrumbJsonLd } from "../lib/seo";
import { appState, ensureSessionLoaded, markRouteReady, setCartItems } from "../stores/app-state";
import {
  formatVerificationStatusLabel,
  getBusinessInitials,
  getBusinessProfileUrl,
  getProductDetailUrl,
  hasProductAvailableStock,
} from "../lib/shop";
import {
  compareState,
  ensureCompareItemsLoaded,
  toggleComparedProduct,
} from "../stores/product-compare";

const route = useRoute();
const router = useRouter();
const business = ref(null);
const products = ref([]);
const wishlistIds = ref([]);
const cartIds = ref([]);
const openingChat = ref(false);
const totalProductsCount = ref(0);
const hasMoreProducts = ref(false);
const loadingMoreProducts = ref(false);
const productsPageSize = ref(getProductsPageSize());
const ui = reactive({
  message: "",
  type: "",
});
let stopProductsPageSizeSubscription = () => {};
let businessRequestId = 0;
let businessProductsRequestId = 0;
const { target: loadMoreSentinel, supportsAutoLoad } = useInfiniteScrollSentinel({
  hasMore: hasMoreProducts,
  loading: loadingMoreProducts,
  onLoadMore: loadMoreProducts,
});

watch(
  () => route.fullPath,
  async () => {
    await bootstrap();
  },
);

onMounted(async () => {
  ensureCompareItemsLoaded();
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

watch(
  () => appState.catalogRevision,
  async (nextRevision, previousRevision) => {
    if (nextRevision === previousRevision) {
      return;
    }

    await loadProducts();
  },
);

const canFollow = computed(() => {
  if (!business.value) {
    return false;
  }

  if (!appState.user) {
    return true;
  }

  return !(appState.user.role === "business" && Number(appState.user.id) === Number(business.value.userId));
});

const canUseMessageAction = computed(() => {
  if (!business.value) {
    return false;
  }

  if (!appState.user) {
    return true;
  }

  if (appState.user.role === "client") {
    return true;
  }

  if (appState.user.role === "admin") {
    return true;
  }

  if (appState.user.role === "business") {
    return Number(appState.user.id) === Number(business.value.userId);
  }

  return false;
});

const messageActionLabel = computed(() => {
  if (
    appState.user?.role === "business"
    && business.value
    && Number(appState.user.id) === Number(business.value.userId)
  ) {
    return "Mesazhet";
  }

  return "Message";
});
const businessShippingSettings = computed(() => normalizeBusinessShippingSettings(business.value?.shippingSettings));
const businessContactSummary = computed(() => ([
  { label: "Website", value: business.value?.websiteUrl || "" },
  { label: "Support email", value: business.value?.supportEmail || "" },
  { label: "Support hours", value: business.value?.supportHours || "" },
  { label: "Return policy", value: business.value?.returnPolicySummary || "" },
].filter((item) => String(item.value || "").trim())));
const businessShippingSummary = computed(() => {
  const settings = businessShippingSettings.value;
  if (!settings) {
    return [];
  }

  const items = [];
  if (settings.standardEnabled) {
    items.push({
      label: "Standard shipping",
      value: buildBusinessShippingSummaryLine("Standard", settings.standardFee, settings.standardEta),
    });
  }
  if (settings.expressEnabled) {
    items.push({
      label: "Express shipping",
      value: buildBusinessShippingSummaryLine("Express", settings.expressFee, settings.expressEta),
    });
  }
  if (settings.pickupEnabled) {
    items.push({
      label: "Pickup",
      value: [
        settings.pickupEta || "Ready for pickup after confirmation",
        settings.pickupAddress || business.value?.addressLine || "",
        settings.pickupHours || business.value?.supportHours || "",
      ].filter(Boolean).join(" • "),
    });
  }
  if (settings.freeShippingThreshold > 0) {
    items.push({
      label: "Free shipping",
      value: `From ${settings.freeShippingThreshold} EUR subtotal.`,
    });
  }
  return items;
});

const comparedProductIds = computed(() =>
  compareState.items
    .map((item) => Number(item.id || item.productId || 0))
    .filter((id) => Number.isFinite(id) && id > 0),
);

function updateBusinessSeo() {
  if (!business.value) {
    applyDocumentSeo({
      title: "TREGIO | Profili i biznesit",
      description: "Shfleto profilet publike te bizneseve dhe produktet e tyre aktive ne TREGIO.",
      canonicalPath: "/profili-biznesit",
      image: "/trego-logo.webp?v=20260410",
      jsonLd: [],
    });
    return;
  }

  const businessPath = getBusinessProfileUrl(business.value.id);
  const breadcrumbJsonLd = buildBreadcrumbJsonLd([
    { name: "Home", item: "/" },
    { name: "Bizneset", item: "/kerko" },
    { name: business.value.businessName || "Profili i biznesit", item: businessPath },
  ]);
  const businessJsonLd = {
    "@context": "https://schema.org",
    "@type": "Store",
    name: String(business.value.businessName || "").trim(),
    description: String(business.value.businessDescription || "").trim(),
    url: buildAbsoluteUrl(business.value.websiteUrl || businessPath),
    image: buildAbsoluteUrl(business.value.logoPath || "/trego-logo.webp?v=20260410"),
    telephone: String(business.value.phoneNumber || "").trim(),
    ...(business.value.supportEmail ? { email: String(business.value.supportEmail).trim() } : {}),
    address: {
      "@type": "PostalAddress",
      streetAddress: String(business.value.addressLine || "").trim(),
      addressLocality: String(business.value.city || "").trim(),
    },
    ...(business.value.supportEmail || business.value.phoneNumber
      ? {
          contactPoint: {
            "@type": "ContactPoint",
            contactType: "customer support",
            ...(business.value.phoneNumber ? { telephone: String(business.value.phoneNumber).trim() } : {}),
            ...(business.value.supportEmail ? { email: String(business.value.supportEmail).trim() } : {}),
          },
        }
      : {}),
    ...(business.value.returnPolicySummary
      ? {
          hasMerchantReturnPolicy: {
            "@type": "MerchantReturnPolicy",
            description: String(business.value.returnPolicySummary).trim(),
          },
        }
      : {}),
    ...(Number(business.value.sellerReviewCount || 0) > 0 && Number(business.value.sellerRating || 0) > 0
      ? {
          aggregateRating: {
            "@type": "AggregateRating",
            ratingValue: Number(business.value.sellerRating || 0).toFixed(1),
            reviewCount: Math.max(1, Number(business.value.sellerReviewCount || 0)),
          },
        }
      : {}),
  };
  const itemListJsonLd = products.value.length > 0
    ? {
        "@context": "https://schema.org",
        "@type": "ItemList",
        name: `${business.value.businessName || "Business"} public products`,
        itemListElement: products.value.slice(0, 10).map((product, index) => ({
          "@type": "ListItem",
          position: index + 1,
          name: String(product.title || "").trim() || `Product ${product.id}`,
          url: buildAbsoluteUrl(getProductDetailUrl(product.id)),
        })),
      }
    : null;

  applyDocumentSeo({
    title: `${business.value.businessName || "Biznes"} | TREGIO`,
    description: [
      String(business.value.businessDescription || "").trim(),
      business.value.city ? `Qyteti: ${business.value.city}.` : "",
      business.value.supportHours ? `Support: ${business.value.supportHours}.` : "",
      business.value.returnPolicySummary ? `${business.value.returnPolicySummary}` : "",
      Number(totalProductsCount.value || business.value.productsCount || 0) > 0
        ? `${Number(totalProductsCount.value || business.value.productsCount || 0)} produkte publike aktive.`
        : "Profili publik i biznesit ne TREGIO.",
    ].filter(Boolean).join(" "),
    canonicalPath: businessPath,
    image: business.value.logoPath || "/trego-logo.webp?v=20260410",
    jsonLd: [businessJsonLd, breadcrumbJsonLd, itemListJsonLd].filter(Boolean),
  });
}

watch([business, products, totalProductsCount], () => {
  updateBusinessSeo();
}, { immediate: true });

async function bootstrap() {
  try {
    await Promise.all([
      ensureSessionLoaded().then(() => refreshCollectionState()),
      loadBusiness(),
      loadProducts(),
    ]);
    await maybeOpenChatFromRoute();
  } finally {
    markRouteReady();
  }
}

async function clearOpenChatQuery() {
  if (String(route.query.openChat || "").trim() !== "1") {
    return;
  }

  const nextQuery = { ...route.query };
  delete nextQuery.openChat;
  await router.replace({
    path: route.path,
    query: nextQuery,
  });
}

async function maybeOpenChatFromRoute() {
  if (String(route.query.openChat || "").trim() !== "1") {
    return;
  }

  if (!business.value || !appState.user) {
    return;
  }

  if (!["client", "admin"].includes(String(appState.user.role || "").trim())) {
    await clearOpenChatQuery();
    return;
  }

  await handleOpenChat({ fromAutoOpen: true });
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

async function loadBusiness() {
  const requestId = ++businessRequestId;
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
  if (requestId !== businessRequestId) {
    return;
  }
  if (!response.ok || !data?.ok || !data.business) {
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
  const requestId = ++businessProductsRequestId;
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
  );
  if (requestId !== businessProductsRequestId) {
    return;
  }
  if (!response.ok || !data?.ok) {
    ui.message = resolveApiMessage(data, "Produktet e biznesit nuk u ngarkuan.");
    ui.type = "error";
    return;
  }

  const nextProducts = Array.isArray(data.products) ? data.products : [];
  const availableProducts = nextProducts.filter((product) => hasProductAvailableStock(product));
  products.value = append ? [...products.value, ...availableProducts] : availableProducts;
  totalProductsCount.value = Number(data.total || products.value.length || 0);
  hasMoreProducts.value = Boolean(data.hasMore);
  ui.message = "";
  ui.type = "";
}

function handleCompare(product) {
  toggleComparedProduct(product);
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

async function handleOpenChat(options = {}) {
  const { fromAutoOpen = false } = options;
  if (!business.value || openingChat.value) {
    return;
  }

  if (!appState.user) {
    await router.push({
      path: "/login",
      query: {
        redirect: `/profili-biznesit?id=${business.value.id}&openChat=1`,
      },
    });
    return;
  }

  if (
    appState.user.role === "business"
    && Number(appState.user.id) === Number(business.value.userId)
  ) {
    await router.push("/mesazhet");
    return;
  }

  if (!["client", "admin"].includes(String(appState.user.role || "").trim())) {
    ui.message = "Vetem klientet ose admini mund ta hapin kete bisede.";
    ui.type = "error";
    if (fromAutoOpen) {
      await clearOpenChatQuery();
    }
    return;
  }

  openingChat.value = true;

  try {
    const { response, data } = await requestJson("/api/chat/open", {
      method: "POST",
      body: JSON.stringify({ businessId: business.value.id }),
    });

    if (!response.ok || !data?.ok || !data.conversation?.id) {
      ui.message = resolveApiMessage(data, "Biseda nuk u hap.");
      ui.type = "error";
      if (fromAutoOpen) {
        await clearOpenChatQuery();
      }
      return;
    }

    await router.push(data.redirectTo || `/mesazhet?conversationId=${data.conversation.id}`);
  } catch (error) {
    console.error(error);
    ui.message = "Biseda nuk u hap. Provoje perseri.";
    ui.type = "error";
    if (fromAutoOpen) {
      await clearOpenChatQuery();
    }
  } finally {
    openingChat.value = false;
  }
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
  if (!hadItem) {
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
  if (product && !hasProductAvailableStock(product)) {
    ui.message = "Na vjen keq, ky produkt nuk eshte me ne stok.";
    ui.type = "error";
    return;
  }

  if (product?.requiresVariantSelection) {
    router.push(getProductDetailUrl(productId, route.fullPath));
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
  cartIds.value = items.map((item) => item.productId || item.id);
  setCartItems(items);
  ui.message = data.message || "Produkti u shtua ne shporte.";
  ui.type = "success";
}

async function handleReportBusiness() {
  if (!business.value) {
    return;
  }

  if (!appState.user) {
    ui.message = "Duhet te kyçesh per te raportuar biznesin.";
    ui.type = "error";
    return;
  }

  const reason = window.prompt("Shkruaje shkurt arsyen e raportimit per kete biznes:");
  if (!reason || !String(reason).trim()) {
    return;
  }

  const { response, data } = await requestJson("/api/reports", {
    method: "POST",
    body: JSON.stringify({
      targetType: "business",
      targetId: business.value.id,
      targetLabel: business.value.businessName,
      reportedUserId: business.value.userId,
      businessUserId: business.value.userId,
      reason,
    }),
  });

  if (!response.ok || !data?.ok) {
    ui.message = resolveApiMessage(data, "Raportimi nuk u dergua.");
    ui.type = "error";
    return;
  }

  ui.message = data.message || "Raportimi u dergua.";
  ui.type = "success";
}

function normalizeBusinessShippingSettings(rawValue) {
  if (!rawValue || typeof rawValue !== "object") {
    return null;
  }

  const toNumber = (value) => {
    const numericValue = Number(value);
    return Number.isFinite(numericValue) ? numericValue : 0;
  };

  return {
    standardEnabled: Boolean(rawValue.standardEnabled),
    standardFee: toNumber(rawValue.standardFee),
    standardEta: String(rawValue.standardEta || "").trim(),
    expressEnabled: Boolean(rawValue.expressEnabled),
    expressFee: toNumber(rawValue.expressFee),
    expressEta: String(rawValue.expressEta || "").trim(),
    pickupEnabled: Boolean(rawValue.pickupEnabled),
    pickupEta: String(rawValue.pickupEta || "").trim(),
    pickupAddress: String(rawValue.pickupAddress || "").trim(),
    pickupHours: String(rawValue.pickupHours || "").trim(),
    freeShippingThreshold: toNumber(rawValue.freeShippingThreshold),
  };
}

function buildBusinessShippingSummaryLine(label, fee, eta) {
  const feeValue = Number(fee);
  return [
    label,
    Number.isFinite(feeValue) ? (feeValue === 0 ? "free shipping" : `${feeValue.toFixed(2)} EUR shipping`) : "",
    String(eta || "").trim(),
  ].filter(Boolean).join(" • ");
}
</script>

<template>
  <section class="market-page market-page--wide business-profile-page" aria-label="Profili publik i biznesit">
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

    <section v-if="business" class="business-profile-page__shell">
      <nav class="market-page__crumbs" aria-label="Breadcrumb">
        <RouterLink to="/">Home</RouterLink>
        <span aria-hidden="true">/</span>
        <RouterLink to="/kerko">Marketplace</RouterLink>
        <span aria-hidden="true">/</span>
        <strong>{{ business.businessName }}</strong>
      </nav>

      <header class="market-card market-card--padded business-hero">
        <div class="business-hero__main">
          <div class="business-hero__identity">
            <div class="business-hero__logo">
              <img
                v-if="business.logoPath"
                :src="business.logoPath"
                :alt="business.businessName"
                width="240"
                height="240"
                loading="lazy"
                decoding="async"
              >
              <span v-else class="business-hero__logo-mark">
                {{ getBusinessInitials(business.businessName) }}
              </span>
            </div>

            <div class="business-hero__summary">
              <p class="business-hero__label">Marketplace seller</p>
              <h1>{{ business.businessName }}</h1>
              <p class="section-heading__copy">
                {{ business.businessDescription || "Ky biznes ende nuk ka shtuar pershkrim." }}
              </p>
            </div>
          </div>

          <div class="business-hero__meta">
            <span>{{ formatVerificationStatusLabel(business.verificationStatus) }}</span>
            <span v-if="Number(business.sellerReviewCount || 0) > 0">
              {{ Number(business.sellerRating || 0).toFixed(1) }} / 5 • {{ business.sellerReviewCount }} reviews
            </span>
            <span>{{ business.city || "Kosove" }}</span>
            <span>{{ business.supportEmail || business.phoneNumber || "Marketplace support" }}</span>
          </div>
        </div>

        <div class="business-hero__actions">
          <button
            class="market-button market-button--primary"
            type="button"
            :disabled="!canFollow"
            @click="toggleFollow"
          >
            {{ business.isFollowed ? "Following" : "Follow store" }}
          </button>

          <button
            class="market-button market-button--secondary"
            type="button"
            :disabled="!canUseMessageAction || openingChat"
            @click="handleOpenChat"
          >
            {{ openingChat ? "Opening..." : messageActionLabel }}
          </button>

          <a
            v-if="business.websiteUrl"
            class="market-button market-button--ghost"
            :href="business.websiteUrl"
            target="_blank"
            rel="noreferrer"
          >
            Website
          </a>

          <button class="market-button market-button--ghost" type="button" @click="handleReportBusiness">
            Report
          </button>
        </div>
      </header>

      <section class="metric-grid">
        <article class="metric-card">
          <p class="metric-card__label">Public products</p>
          <strong>{{ business.productsCount || 0 }}</strong>
        </article>
        <article class="metric-card">
          <p class="metric-card__label">Followers</p>
          <strong>{{ business.followersCount || 0 }}</strong>
        </article>
        <article class="metric-card">
          <p class="metric-card__label">City</p>
          <strong>{{ business.city || "-" }}</strong>
        </article>
        <article class="metric-card">
          <p class="metric-card__label">Phone</p>
          <strong>{{ business.phoneNumber || "-" }}</strong>
        </article>
        <article class="metric-card">
          <p class="metric-card__label">Address</p>
          <strong>{{ business.addressLine || "-" }}</strong>
        </article>
        <article class="metric-card">
          <p class="metric-card__label">Support</p>
          <strong>{{ business.supportEmail || business.phoneNumber || "Mesazho biznesin ne TREGIO" }}</strong>
        </article>
      </section>

      <section class="market-card market-card--padded">
        <div class="market-page__header">
          <div class="market-page__header-copy">
            <p class="market-page__eyebrow">Store details</p>
            <h2>Contact and delivery information</h2>
            <p>
              Website, support, return policy, and delivery methods are grouped in one clear section to improve trust before purchase.
            </p>
          </div>
        </div>

        <div class="business-contact-grid">
          <div v-for="item in businessContactSummary" :key="`contact-${item.label}`">
            <span>{{ item.label }}</span>
            <strong>{{ item.value }}</strong>
          </div>
          <div v-for="item in businessShippingSummary" :key="`shipping-${item.label}`">
            <span>{{ item.label }}</span>
            <strong>{{ item.value }}</strong>
          </div>
        </div>
      </section>

      <section class="market-card market-card--padded">
        <div class="market-page__header">
          <div class="market-page__header-copy">
            <p class="market-page__eyebrow">Catalog</p>
            <h2>Products from this seller</h2>
            <p>Shfleto artikujt qe ky biznes i ka publikuar ne TREGIO.</p>
          </div>
        </div>

        <div v-if="products.length > 0" class="product-collection__grid" aria-label="Produktet e biznesit">
          <ProductCard
            v-for="product in products"
            :key="product.id"
            :product="product"
            :is-wishlisted="wishlistIds.includes(product.id)"
            :is-in-cart="cartIds.includes(product.id)"
            :is-compared="comparedProductIds.includes(product.id)"
            @wishlist="handleWishlist"
            @cart="handleCart"
            @compare="handleCompare"
          />
        </div>

        <div v-else class="market-empty">
          <h3>No public products yet</h3>
          <p>This seller has not published products to the marketplace yet.</p>
        </div>

        <div v-if="products.length > 0 && hasMoreProducts" class="business-profile__products-footer">
          <div
            v-if="supportsAutoLoad"
            ref="loadMoreSentinel"
            aria-hidden="true"
          ></div>
          <span v-if="loadingMoreProducts" class="section-heading__copy">Loading more products...</span>
          <button
            v-else-if="!supportsAutoLoad"
            class="market-button market-button--secondary"
            type="button"
            :disabled="loadingMoreProducts"
            @click="loadMoreProducts"
          >
            {{ loadingMoreProducts ? "Loading..." : "Show more" }}
          </button>
        </div>
      </section>
    </section>

    <div v-else class="market-empty">
      <h2>Biznesi nuk u gjet</h2>
      <p>This seller page may have been removed or is no longer public.</p>
      <div class="market-empty__actions">
        <RouterLink class="market-button market-button--secondary" to="/kerko">
          Browse marketplace
        </RouterLink>
      </div>
    </div>
  </section>
</template>
