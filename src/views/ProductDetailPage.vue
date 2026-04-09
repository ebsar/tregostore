<script setup>
import { computed, onMounted, reactive, ref, watch } from "vue";
import { RouterLink, useRoute, useRouter } from "vue-router";
import ProductCard from "../components/ProductCard.vue";
import RecommendationSections from "../components/RecommendationSections.vue";
import {
  fetchProductRecommendations,
  fetchProtectedCollection,
  requestJson,
  resolveApiMessage,
  trackProductShare,
} from "../lib/api";
import { readRecentlyViewedProducts, rememberRecentlyViewedProduct } from "../lib/recently-viewed";
import { trackAddToCart, trackProductView } from "../lib/tracking";
import {
  formatCategoryLabel,
  formatCount,
  formatDateLabel,
  formatPrice,
  formatProductColorLabel,
  formatProductTypeLabel,
  getCategoryUrl,
  getProductDetailUrl,
  getProductImageGallery,
  getProductStockMessage,
  hasProductAvailableStock,
} from "../lib/shop";
import { compareState, ensureCompareItemsLoaded, toggleComparedProduct } from "../stores/product-compare";
import { appState, ensureSessionLoaded, markRouteReady, setCartItems } from "../stores/app-state";

const route = useRoute();
const router = useRouter();
const currentProduct = ref(null);
const currentImageIndex = ref(0);
const wishlistIds = ref([]);
const cartIds = ref([]);
const selectedColor = ref("");
const selectedSize = ref("");
const selectedQuantity = ref(1);
const productReviews = ref([]);
const productRecommendationSections = ref([]);
const recentlyViewedProducts = ref([]);
const canSubmitReview = ref(false);
const reviewBusy = ref(false);
const reviewForm = reactive({
  rating: 5,
  title: "",
  body: "",
});
const ui = reactive({
  message: "",
  type: "",
});
const isCompared = computed(() =>
  compareState.items.some((item) => Number(item.id || item.productId || 0) === Number(currentProduct.value?.id || 0)),
);
const canSeeProductEngagement = computed(() =>
  appState.user?.role === "business" || appState.user?.role === "admin",
);
const isProductAvailable = computed(() => hasProductAvailableStock(currentProduct.value || {}));
const outOfStockMessage = computed(() => getProductStockMessage(currentProduct.value || {}));
const businessName = computed(() => String(currentProduct.value?.businessName || "").trim());

const variantInventory = computed(() => {
  if (!Array.isArray(currentProduct.value?.variantInventory)) {
    return [];
  }

  return currentProduct.value.variantInventory;
});

const colorOptions = computed(() =>
  [...new Set(variantInventory.value.map((entry) => String(entry.color || "").trim().toLowerCase()).filter(Boolean))]
    .map((value) => ({
      value,
      label: formatProductColorLabel(value),
      inStock: variantInventory.value.some((entry) => entry.color === value && Number(entry.quantity || 0) > 0),
    })),
);

const sizeOptions = computed(() => {
  const activeEntries = variantInventory.value.filter((entry) => {
    if (!selectedColor.value) {
      return true;
    }

    return String(entry.color || "").trim().toLowerCase() === selectedColor.value;
  });

  return [...new Set(activeEntries.map((entry) => String(entry.size || "").trim().toUpperCase()).filter(Boolean))]
    .map((value) => ({
      value,
      inStock: activeEntries.some((entry) => entry.size === value && Number(entry.quantity || 0) > 0),
    }));
});

const selectedVariant = computed(() => {
  if (!variantInventory.value.length) {
    return null;
  }

  if (variantInventory.value.length === 1) {
    return variantInventory.value[0];
  }

  return variantInventory.value.find((entry) => {
    const colorMatches = !selectedColor.value || String(entry.color || "").trim().toLowerCase() === selectedColor.value;
    const sizeMatches = !selectedSize.value || String(entry.size || "").trim().toUpperCase() === selectedSize.value;
    if (selectedColor.value && selectedSize.value) {
      return colorMatches && sizeMatches;
    }
    if (selectedColor.value && !sizeOptions.value.length) {
      return colorMatches;
    }
    if (!selectedColor.value && selectedSize.value) {
      return sizeMatches;
    }
    return false;
  }) || null;
});

const details = computed(() => {
  if (!currentProduct.value) {
    return [];
  }

  return [
    formatCategoryLabel(currentProduct.value.category),
    formatProductTypeLabel(currentProduct.value.productType),
    currentProduct.value.size ? `Madhesia: ${currentProduct.value.size}` : "",
    currentProduct.value.color
      ? `Ngjyra: ${formatProductColorLabel(currentProduct.value.color)}`
      : "",
    currentProduct.value.packageAmountValue && currentProduct.value.packageAmountUnit
      ? `Permbajtja: ${currentProduct.value.packageAmountValue}${currentProduct.value.packageAmountUnit}`
      : "",
    currentProduct.value.showStockPublic && Number(currentProduct.value.stockQuantity) > 0
      ? "Ne stok"
      : "",
  ].filter(Boolean);
});

const imageGallery = computed(() => getProductImageGallery(currentProduct.value));
const currentImagePath = computed(
  () => imageGallery.value[currentImageIndex.value] || currentProduct.value?.imagePath || "",
);
const currentPrice = computed(() => Number(currentProduct.value?.price || 0));
const compareAtPrice = computed(() => {
  const rawValue = Number(currentProduct.value?.compareAtPrice ?? currentProduct.value?.originalPrice ?? 0);
  if (!Number.isFinite(rawValue) || rawValue <= currentPrice.value) {
    return null;
  }

  return rawValue;
});
const discountPercent = computed(() => {
  if (!compareAtPrice.value) {
    return 0;
  }

  return Math.max(0, Math.round(((compareAtPrice.value - currentPrice.value) / compareAtPrice.value) * 100));
});
const averageRating = computed(() => {
  const rawValue = Number(currentProduct.value?.averageRating ?? currentProduct.value?.ratingAverage ?? 0);
  if (!Number.isFinite(rawValue) || rawValue <= 0) {
    return 0;
  }

  return Math.max(0, Math.min(5, rawValue));
});
const reviewCount = computed(() => {
  const rawValue = Number(currentProduct.value?.reviewCount || productReviews.value.length || 0);
  if (!Number.isFinite(rawValue) || rawValue <= 0) {
    return 0;
  }

  return Math.max(0, Math.trunc(rawValue));
});
const buyersCount = computed(() => {
  const rawValue = Number(currentProduct.value?.buyersCount || 0);
  if (!Number.isFinite(rawValue) || rawValue <= 0) {
    return 0;
  }

  return Math.max(0, Math.trunc(rawValue));
});
const filledStars = computed(() => {
  if (averageRating.value <= 0) {
    return 0;
  }

  return Math.max(0, Math.min(5, Math.round(averageRating.value)));
});
const shortDescription = computed(() => {
  const rawValue = String(currentProduct.value?.description || "").trim();
  if (!rawValue) {
    return "Produkt i perzgjedhur me fokus te qarte ne cilesi, prezantim dhe blerje te shpejte.";
  }

  if (rawValue.length <= 180) {
    return rawValue;
  }

  return `${rawValue.slice(0, 177).trim()}...`;
});
const selectedVariantStock = computed(() => {
  if (selectedVariant.value) {
    return maxAvailableQuantityForSelection(selectedVariant.value);
  }

  if (currentProduct.value?.requiresVariantSelection) {
    return 0;
  }

  return maxAvailableQuantityForSelection(currentProduct.value || {});
});
const quantityMax = computed(() => Math.max(1, Math.min(12, selectedVariantStock.value || 1)));
const breadcrumbItems = computed(() => ([
  { label: "Home", to: "/" },
  { label: formatCategoryLabel(currentProduct.value?.category || ""), to: getCategoryUrl(currentProduct.value?.category) },
  { label: currentProduct.value?.title || "Produkt", to: "" },
]));
const specificationItems = computed(() => {
  if (!currentProduct.value) {
    return [];
  }

  return [
    { label: "Kategoria", value: formatCategoryLabel(currentProduct.value.category) || "Marketplace" },
    { label: "Lloji", value: formatProductTypeLabel(currentProduct.value.productType) || "Produkt" },
    { label: "Ngjyra", value: currentProduct.value.color ? formatProductColorLabel(currentProduct.value.color) : "" },
    { label: "Madhesia", value: currentProduct.value.size || "" },
    {
      label: "Permbajtja",
      value: currentProduct.value.packageAmountValue && currentProduct.value.packageAmountUnit
        ? `${currentProduct.value.packageAmountValue}${currentProduct.value.packageAmountUnit}`
        : "",
    },
    { label: "Disponueshmeria", value: isProductAvailable.value ? "Ne stok" : "Pa stok" },
  ].filter((item) => String(item.value || "").trim());
});
const trustHighlights = computed(() => ([
  {
    title: "Dergese e sigurt",
    description: "Porosite trajtohen vetem kur produkti konfirmohet ne stok nga biznesi.",
  },
  {
    title: "Kthime te qarta",
    description: "Proces i kontrolluar per refund dhe kthime kur porosia nuk permbushet si duhet.",
  },
  {
    title: "Pagese e sigurt",
    description: "Checkout i qarte me ruajtje te kontrolluar te stokut dhe gjurmim te porosise.",
  },
]));
const relatedViewedProducts = computed(() =>
  recentlyViewedProducts.value
    .filter((product) => Number(product?.id || 0) !== Number(currentProduct.value?.id || 0))
    .filter((product) => hasProductAvailableStock(product))
    .slice(0, 4),
);
const backTarget = computed(() => {
  const candidate = String(route.query.back || "").trim();
  if (candidate.startsWith("/")) {
    return candidate;
  }

  return getCategoryUrl(currentProduct.value?.category);
});
const shareUrl = computed(() => {
  if (!currentProduct.value) {
    return "";
  }

  const detailPath = getProductDetailUrl(currentProduct.value.id);
  if (typeof window === "undefined") {
    return detailPath;
  }

  return new URL(detailPath, window.location.origin).toString();
});
const publicEngagementItems = computed(() => ([
  { label: "Views", value: formatCount(currentProduct.value?.viewsCount || 0) },
  { label: "Wishlist", value: formatCount(currentProduct.value?.wishlistCount || 0) },
  { label: "Cart", value: formatCount(currentProduct.value?.cartCount || 0) },
  { label: "Share", value: formatCount(currentProduct.value?.shareCount || 0) },
]));
const comparedProductIds = computed(() =>
  compareState.items
    .map((item) => Number(item.id || item.productId || 0))
    .filter((id) => Number.isFinite(id) && id > 0),
);
let productRecommendationsRequestId = 0;

watch(
  () => route.fullPath,
  async () => {
    await bootstrap();
  },
);

onMounted(async () => {
  ensureCompareItemsLoaded();
  recentlyViewedProducts.value = readRecentlyViewedProducts();
  await bootstrap();
});

watch(selectedVariantStock, (nextValue) => {
  const maxAllowed = Math.max(1, Math.min(12, nextValue || 1));
  if (selectedQuantity.value > maxAllowed) {
    selectedQuantity.value = maxAllowed;
  }
});

watch(
  () => appState.catalogRevision,
  async (nextRevision, previousRevision) => {
    if (nextRevision === previousRevision) {
      return;
    }

    await loadProduct();
  },
);

async function bootstrap() {
  try {
    await loadProduct();
    markRouteReady();
    void ensureSessionLoaded()
      .then(() => refreshCollectionState())
      .catch((error) => {
        console.error(error);
      });
  } finally {
    if (!currentProduct.value) {
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

async function loadProduct() {
  const productId = Number(route.query.id || route.query.productId || "");
  if (!Number.isFinite(productId) || productId <= 0) {
    currentProduct.value = null;
    ui.message = "Produkti nuk u gjet.";
    ui.type = "error";
    return;
  }

  const { response, data } = await requestJson(
    `/api/product?id=${encodeURIComponent(productId)}`,
    {},
    { cacheTtlMs: 20000 },
  );
  if (!response.ok || !data?.ok || !data.product) {
    currentProduct.value = null;
    ui.message = resolveApiMessage(data, "Produkti nuk u gjet.");
    ui.type = "error";
    return;
  }

  currentProduct.value = data.product;
  recentlyViewedProducts.value = rememberRecentlyViewedProduct(currentProduct.value);
  trackProductView(currentProduct.value);
  currentImageIndex.value = 0;
  selectedQuantity.value = 1;
  initializeVariantSelection();
  productReviews.value = [];
  canSubmitReview.value = false;
  void loadProductRecommendations(productId);
  void loadProductReviews(productId);
  ui.message = "";
  ui.type = "";
}

async function loadProductRecommendations(productId) {
  const requestId = ++productRecommendationsRequestId;
  const payload = await fetchProductRecommendations(productId, 4);
  if (requestId !== productRecommendationsRequestId) {
    return;
  }

  productRecommendationSections.value = Array.isArray(payload.sections) ? payload.sections : [];
}

async function loadProductReviews(productId) {
  const { response, data } = await requestJson(
    `/api/product/reviews?id=${encodeURIComponent(productId)}`,
    {},
    { cacheTtlMs: 20000 },
  );
  if (!response.ok || !data?.ok) {
    productReviews.value = [];
    canSubmitReview.value = false;
    return;
  }

  productReviews.value = Array.isArray(data.reviews) ? data.reviews : [];
  canSubmitReview.value = Boolean(data.canSubmitReview);
}

function initializeVariantSelection() {
  selectedColor.value = "";
  selectedSize.value = "";

  if (!variantInventory.value.length) {
    return;
  }

  if (variantInventory.value.length === 1) {
    selectedColor.value = String(variantInventory.value[0].color || "").trim().toLowerCase();
    selectedSize.value = String(variantInventory.value[0].size || "").trim().toUpperCase();
    return;
  }

  if (colorOptions.value.length === 1) {
    selectedColor.value = colorOptions.value[0].value;
  }

  if (sizeOptions.value.length === 1) {
    selectedSize.value = sizeOptions.value[0].value;
  }
}

function handleCompareProduct() {
  if (!currentProduct.value) {
    return;
  }

  toggleComparedProduct(currentProduct.value);
}

function chooseColor(colorValue) {
  selectedColor.value = colorValue;

  if (
    selectedSize.value
    && !variantInventory.value.some(
      (entry) =>
        String(entry.color || "").trim().toLowerCase() === colorValue
        && String(entry.size || "").trim().toUpperCase() === selectedSize.value,
    )
  ) {
    selectedSize.value = "";
  }
}

function chooseSize(sizeValue) {
  selectedSize.value = sizeValue;
}

async function handleWishlist() {
  if (!currentProduct.value) {
    return;
  }

  if (!appState.user) {
    ui.message = "Duhet te kyçesh ose te krijosh llogari para se te perdoresh wishlist ose cart.";
    ui.type = "error";
    return;
  }

  const productId = currentProduct.value.id;
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

async function handleCart() {
  await addCurrentProductToCart();
}

function findRecommendationProduct(productId) {
  const productPools = [
    ...productRecommendationSections.value.flatMap((section) => section.products || []),
    ...relatedViewedProducts.value,
  ];
  return productPools.find((item) => Number(item?.id || 0) === Number(productId)) || null;
}

async function handleRecommendationWishlist(productId) {
  const targetProduct = findRecommendationProduct(productId);
  if (!targetProduct) {
    return;
  }

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

async function handleRecommendationCart(productId) {
  const targetProduct = findRecommendationProduct(productId);
  if (!targetProduct) {
    return;
  }

  if (!appState.user) {
    ui.message = "Duhet te kyçesh ose te krijosh llogari para se te perdoresh wishlist ose cart.";
    ui.type = "error";
    return;
  }

  if (targetProduct.requiresVariantSelection) {
    await router.push(getProductDetailUrl(productId, route.fullPath));
    return;
  }

  if (!cartIds.value.includes(productId)) {
    cartIds.value = [...cartIds.value, productId];
  }

  const { response, data } = await requestJson("/api/cart/add", {
    method: "POST",
    body: JSON.stringify({ productId, quantity: 1 }),
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

async function handleBuyNow() {
  const added = await addCurrentProductToCart({ goToCart: true });
  if (!added) {
    return;
  }
}

function setCurrentImage(index) {
  if (index < 0 || index >= imageGallery.value.length) {
    return;
  }

  currentImageIndex.value = index;
}

function maxAvailableQuantityForSelection(target) {
  const rawValue = Number(target?.quantity ?? target?.stockQuantity ?? 0);
  if (!Number.isFinite(rawValue) || rawValue <= 0) {
    return 0;
  }

  return Math.max(0, Math.trunc(rawValue));
}

function decrementQuantity() {
  selectedQuantity.value = Math.max(1, selectedQuantity.value - 1);
}

function incrementQuantity() {
  selectedQuantity.value = Math.min(quantityMax.value, selectedQuantity.value + 1);
}

async function addCurrentProductToCart(options = {}) {
  if (!currentProduct.value) {
    return false;
  }

  if (!appState.user) {
    ui.message = "Duhet te kyçesh ose te krijosh llogari para se te perdoresh wishlist ose cart.";
    ui.type = "error";
    return false;
  }

  if (!isProductAvailable.value) {
    ui.message = outOfStockMessage.value;
    ui.type = "error";
    return false;
  }

  const productId = currentProduct.value.id;
  if (currentProduct.value.requiresVariantSelection && !selectedVariant.value) {
    ui.message = "Zgjidh ngjyren dhe madhesine para se ta shtosh produktin ne cart.";
    ui.type = "error";
    return false;
  }

  if (selectedVariant.value && Number(selectedVariant.value.quantity || 0) <= 0) {
    ui.message = "Na vjen keq, varianti i zgjedhur nuk eshte me ne stok.";
    ui.type = "error";
    return false;
  }

  if (!cartIds.value.includes(productId)) {
    cartIds.value = [...cartIds.value, productId];
  }

  const { response, data } = await requestJson("/api/cart/add", {
    method: "POST",
    body: JSON.stringify({
      productId,
      variantKey: selectedVariant.value?.key || "",
      selectedSize: selectedVariant.value?.size || selectedSize.value,
      selectedColor: selectedVariant.value?.color || selectedColor.value,
      quantity: selectedQuantity.value,
    }),
  });

  if (!response.ok || !data?.ok) {
    cartIds.value = cartIds.value.filter((id) => id !== productId);
    ui.message = resolveApiMessage(data, "Shporta nuk u perditesua.");
    ui.type = "error";
    return false;
  }

  const items = Array.isArray(data.items) ? data.items : [];
  cartIds.value = items.map((item) => item.productId || item.id);
  setCartItems(items);
  trackAddToCart(currentProduct.value, { quantity: selectedQuantity.value });
  ui.message = data.message || "Produkti u shtua ne shporte.";
  ui.type = "success";
  if (options.goToCart) {
    await router.push("/cart");
  }
  return true;
}

async function handleSubmitReview() {
  if (!currentProduct.value || reviewBusy.value) {
    return;
  }

  if (!appState.user) {
    ui.message = "Duhet te kyçesh per te lene review.";
    ui.type = "error";
    return;
  }

  reviewBusy.value = true;
  try {
    const { response, data } = await requestJson("/api/product/reviews", {
      method: "POST",
      body: JSON.stringify({
        productId: currentProduct.value.id,
        rating: reviewForm.rating,
        title: reviewForm.title,
        body: reviewForm.body,
      }),
    });

    if (!response.ok || !data?.ok) {
      ui.message = resolveApiMessage(data, "Review nuk u ruajt.");
      ui.type = "error";
      return;
    }

    reviewForm.rating = 5;
    reviewForm.title = "";
    reviewForm.body = "";
    ui.message = data.message || "Review u ruajt.";
    ui.type = "success";
    await loadProduct();
  } finally {
    reviewBusy.value = false;
  }
}

async function handleReportProduct() {
  if (!currentProduct.value) {
    return;
  }

  if (!appState.user) {
    ui.message = "Duhet te kyçesh per te raportuar produktin.";
    ui.type = "error";
    return;
  }

  const reason = window.prompt("Shkruaje shkurt arsyen e raportimit:");
  if (!reason || !String(reason).trim()) {
    return;
  }

  const { response, data } = await requestJson("/api/reports", {
    method: "POST",
    body: JSON.stringify({
      targetType: "product",
      targetId: currentProduct.value.id,
      targetLabel: currentProduct.value.title,
      reportedUserId: currentProduct.value.createdByUserId,
      businessUserId: currentProduct.value.createdByUserId,
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

function syncCurrentProductMetrics(metrics = {}) {
  if (!currentProduct.value || !metrics || typeof metrics !== "object") {
    return;
  }

  currentProduct.value = {
    ...currentProduct.value,
    ...metrics,
  };
}

async function handleShareProduct() {
  if (!currentProduct.value || !shareUrl.value) {
    return;
  }

  const sharePayload = {
    title: currentProduct.value.title,
    text: `${currentProduct.value.title} • ${formatPrice(currentProduct.value.price)}`,
    url: shareUrl.value,
  };

  try {
    if (typeof navigator !== "undefined" && typeof navigator.share === "function") {
      await navigator.share(sharePayload);
      ui.message = "Produkti u nda me sukses.";
    } else if (typeof navigator !== "undefined" && navigator.clipboard?.writeText) {
      await navigator.clipboard.writeText(shareUrl.value);
      ui.message = "Linku i produktit u kopjua.";
    } else {
      window.prompt("Kopjo linkun e produktit:", shareUrl.value);
      ui.message = "Linku i produktit eshte gati per share.";
    }

    ui.type = "success";
    const { response, data } = await trackProductShare(currentProduct.value.id);
    if (response.ok && data?.ok && data.metrics) {
      syncCurrentProductMetrics(data.metrics);
    }
  } catch (error) {
    if (error?.name === "AbortError") {
      return;
    }

    console.error(error);
    ui.message = "Produkti nuk u nda. Provoje perseri.";
    ui.type = "error";
  }
}

function nextImage() {
  if (imageGallery.value.length <= 1) {
    return;
  }

  currentImageIndex.value = (currentImageIndex.value + 1) % imageGallery.value.length;
}
</script>

<template>
  <section class="product-detail-page" aria-label="Detajet e produktit">
    <div class="form-message" :class="ui.type" role="status" aria-live="polite">
      {{ ui.message }}
    </div>

    <section v-if="currentProduct" class="product-detail-container">
      <nav class="card glass-soft product-breadcrumbs" aria-label="Breadcrumb">
        <template v-for="(item, index) in breadcrumbItems" :key="`${item.label}-${index}`">
          <RouterLink
            v-if="item.to && index < breadcrumbItems.length - 1"
            class="product-breadcrumb-link"
            :to="item.to"
          >
            {{ item.label }}
          </RouterLink>
          <span v-else class="product-breadcrumb-current">{{ item.label }}</span>
          <span v-if="index < breadcrumbItems.length - 1" class="product-breadcrumb-separator" aria-hidden="true">/</span>
        </template>
      </nav>

      <article class="card product-detail-card" :aria-label="currentProduct.title">
        <div class="product-detail-media">
          <RouterLink class="product-detail-back-link" :to="backTarget">
            Kthehu te produktet
          </RouterLink>
          <div class="product-detail-image-shell">
            <img
              class="product-detail-image"
              :src="currentImagePath"
              :alt="currentProduct.title"
              width="1200"
              height="1200"
              decoding="async"
              fetchpriority="high"
            >
          </div>

          <div v-if="imageGallery.length > 1" class="product-gallery-controls">
            <span class="product-gallery-counter">{{ currentImageIndex + 1 }} / {{ imageGallery.length }}</span>
            <button class="product-gallery-next" type="button" @click="nextImage">
              Next
            </button>
          </div>

          <div v-if="imageGallery.length > 1" class="product-gallery-thumbnails" aria-label="Fotot e produktit">
            <button
              v-for="(imagePath, index) in imageGallery"
              :key="`${imagePath}-${index}`"
              class="product-gallery-thumbnail"
              :class="{ active: index === currentImageIndex }"
              type="button"
              @click="setCurrentImage(index)"
            >
              <img :src="imagePath" :alt="`${currentProduct.title} ${index + 1}`" loading="lazy" decoding="async">
            </button>
          </div>
        </div>

        <div class="product-detail-copy">
          <div class="product-detail-kicker-row">
            <p class="product-detail-category">{{ formatCategoryLabel(currentProduct.category) }}</p>
            <p v-if="businessName" class="product-detail-brand">{{ businessName }}</p>
          </div>
          <h1>{{ currentProduct.title }}</h1>
          <div class="product-detail-rating-row">
            <div class="product-detail-rating-stars" :aria-label="averageRating > 0 ? `Vleresimi ${averageRating.toFixed(1)}` : 'Pa vleresime'">
              <svg
                v-for="index in 5"
                :key="`star-${index}`"
                class="product-detail-rating-star"
                :class="{ 'is-filled': index <= filledStars }"
                viewBox="0 0 24 24"
                aria-hidden="true"
              >
                <path d="M12 3.8 14.6 9l5.7.8-4.1 4 1 5.7-5.2-2.7-5.2 2.7 1-5.7-4.1-4 5.7-.8Z"></path>
              </svg>
            </div>
            <strong>{{ averageRating > 0 ? averageRating.toFixed(1) : "Pa vleresime" }}</strong>
            <span>{{ reviewCount }} review</span>
            <span v-if="buyersCount > 0" class="product-detail-rating-dot" aria-hidden="true"></span>
            <span v-if="buyersCount > 0">{{ buyersCount }} blerje</span>
          </div>

          <div class="product-detail-price-block">
            <strong class="product-detail-price">{{ formatPrice(currentProduct.price) }}</strong>
            <div v-if="compareAtPrice || discountPercent > 0" class="product-detail-price-side">
              <span v-if="compareAtPrice" class="product-detail-price-compare">{{ formatPrice(compareAtPrice) }}</span>
              <span v-if="discountPercent > 0" class="product-detail-discount">-{{ discountPercent }}%</span>
            </div>
          </div>

          <p class="product-detail-description">{{ shortDescription }}</p>

          <div class="product-detail-tags">
            <span v-for="detail in details" :key="detail" class="product-detail-tag">
              {{ detail }}
            </span>
          </div>

          <div v-if="colorOptions.length > 0" class="product-detail-variant-group">
            <p class="product-detail-variant-label">Ngjyra</p>
            <div class="product-detail-variant-options">
              <button
                v-for="option in colorOptions"
                :key="option.value"
                class="product-detail-variant-option"
                :class="{ active: selectedColor === option.value, 'is-unavailable': !option.inStock }"
                type="button"
                :disabled="!option.inStock"
                @click="chooseColor(option.value)"
              >
                {{ option.label }}
              </button>
            </div>
          </div>

          <div v-if="sizeOptions.length > 0" class="product-detail-variant-group">
            <p class="product-detail-variant-label">Madhesia</p>
            <div class="product-detail-variant-options">
              <button
                v-for="option in sizeOptions"
                :key="option.value"
                class="product-detail-variant-option"
                :class="{ active: selectedSize === option.value, 'is-unavailable': !option.inStock }"
                type="button"
                :disabled="!option.inStock"
                @click="chooseSize(option.value)"
              >
                {{ option.value }}
              </button>
            </div>
          </div>

          <div class="product-detail-purchase-row">
            <div class="product-detail-quantity">
              <p class="product-detail-variant-label">Sasia</p>
              <div class="cart-quantity-control product-detail-quantity-control">
                <button class="cart-quantity-button" type="button" :disabled="selectedQuantity <= 1" @click="decrementQuantity">
                  -
                </button>
                <span class="product-detail-quantity-value">{{ selectedQuantity }}</span>
                <button class="cart-quantity-button" type="button" :disabled="selectedQuantity >= quantityMax" @click="incrementQuantity">
                  +
                </button>
              </div>
            </div>
            <div class="product-detail-availability-note">
              <span>{{ isProductAvailable ? "Gati per porosi" : "Pa stok" }}</span>
              <strong v-if="isProductAvailable && selectedVariantStock > 0">{{ selectedVariantStock }} cope te lira</strong>
            </div>
          </div>

          <div v-if="!isProductAvailable" class="product-detail-stock-state" role="status" aria-live="polite">
            <strong>Na vjen keq, ky produkt nuk eshte me ne stok.</strong>
            <p>Shfleto produkte te tjera ose kthehu me vone nese biznesi e rikthen ne stok.</p>
          </div>

          <div class="product-detail-actions">
            <button
              class="product-action-button cart-action"
              :class="{ active: cartIds.includes(currentProduct.id) }"
              type="button"
              :disabled="!isProductAvailable"
              @click="handleCart"
            >
              <svg class="nav-icon" viewBox="0 0 24 24" aria-hidden="true">
                <path d="M3 5h2l2.1 9.1a1 1 0 0 0 1 .8h8.8a1 1 0 0 0 1-.8L20 8H7.2"></path>
                <circle cx="10" cy="19" r="1.4"></circle>
                <circle cx="18" cy="19" r="1.4"></circle>
              </svg>
              <span>{{ isProductAvailable ? (cartIds.includes(currentProduct.id) ? "Ne cart" : "Shto ne cart") : "Nuk ka ne stok" }}</span>
            </button>

            <button
              class="product-action-button buy-now-action"
              type="button"
              :disabled="!isProductAvailable"
              @click="handleBuyNow"
            >
              <span>Bli tani</span>
            </button>

            <button
              class="product-action-button wishlist-action"
              :class="{ active: wishlistIds.includes(currentProduct.id) }"
              type="button"
              @click="handleWishlist"
            >
              <svg class="nav-icon" viewBox="0 0 24 24" aria-hidden="true">
                <path d="M12 20.4 4.9 13.8a4.8 4.8 0 0 1 6.8-6.8l.3.3.3-.3a4.8 4.8 0 1 1 6.8 6.8Z"></path>
              </svg>
              <span>{{ wishlistIds.includes(currentProduct.id) ? "Ne wishlist" : "Wishlist" }}</span>
            </button>

            <button
              class="product-action-button compare-action"
              :class="{ active: isCompared }"
              type="button"
              :aria-pressed="isCompared"
              @click="handleCompareProduct"
            >
              <svg class="nav-icon" viewBox="0 0 24 24" aria-hidden="true">
                <rect x="4.5" y="5.5" width="6.5" height="13" rx="1.8"></rect>
                <rect x="13" y="7.5" width="6.5" height="11" rx="1.8"></rect>
              </svg>
              <span>{{ isCompared ? "Ne krahasim" : "Krahaso" }}</span>
            </button>

            <button
              class="product-action-button share-action"
              type="button"
              @click="handleShareProduct"
            >
              <svg class="product-action-icon" viewBox="0 0 24 24" aria-hidden="true">
                <circle cx="18" cy="5" r="2.2"></circle>
                <circle cx="6" cy="12" r="2.2"></circle>
                <circle cx="18" cy="19" r="2.2"></circle>
                <path d="M8 11.2 15.9 6.7"></path>
                <path d="m8 12.8 7.9 4.5"></path>
              </svg>
              <span>Shperndaje</span>
            </button>

            <button
              class="product-action-button"
              type="button"
              @click="handleReportProduct"
            >
              Raporto
            </button>
          </div>

          <div v-if="canSeeProductEngagement" class="product-detail-engagement-row" aria-label="Interesimi per produktin">
            <span
              v-for="item in publicEngagementItems"
              :key="`${currentProduct.id}-${item.label}`"
              class="product-detail-engagement-chip"
            >
              <small>{{ item.label }}</small>
              <strong>{{ item.value }}</strong>
            </span>
          </div>

          <div class="product-detail-trust-grid" aria-label="Arsye per te blere me besim">
            <article v-for="highlight in trustHighlights" :key="highlight.title" class="product-detail-trust-card">
              <p class="section-label">{{ highlight.title }}</p>
              <p class="product-detail-trust-copy">{{ highlight.description }}</p>
            </article>
          </div>
        </div>
      </article>

      <section class="card glass-strong product-description-card" aria-label="Pershkrimi i produktit">
        <div class="product-description-layout">
          <div class="product-description-block">
            <div class="product-reviews-header product-description-header">
              <div>
                <p class="section-label">Detaje te produktit</p>
                <h2>Pershkrimi</h2>
              </div>
            </div>

            <p class="product-description-content">
              {{ currentProduct.description }}
            </p>
          </div>

          <div class="product-description-specs">
            <div class="product-reviews-header product-description-header">
              <div>
                <p class="section-label">Specifikime</p>
                <h2>Materiale dhe detaje</h2>
              </div>
            </div>

            <div class="product-spec-grid">
              <article v-for="item in specificationItems" :key="item.label" class="product-spec-item">
                <span>{{ item.label }}</span>
                <strong>{{ item.value }}</strong>
              </article>
            </div>
          </div>
        </div>
      </section>

      <section class="card glass-strong product-reviews-card" aria-label="Review-t e produktit">
        <div class="product-reviews-header">
          <div>
            <p class="section-label">Marketplace trust</p>
            <h2>Review-t e bleresve</h2>
          </div>
          <div class="product-reviews-summary">
            <div class="summary-chip">
              <span>Mesatarja</span>
              <strong>{{ averageRating > 0 ? averageRating.toFixed(1) : "0.0" }}</strong>
            </div>
            <div class="summary-chip">
              <span>Total review</span>
              <strong>{{ reviewCount }}</strong>
            </div>
          </div>
        </div>

        <form
          v-if="canSubmitReview"
          class="product-review-form"
          @submit.prevent="handleSubmitReview"
        >
          <label class="field">
            <span>Vleresimi</span>
            <select v-model.number="reviewForm.rating">
              <option v-for="star in 5" :key="star" :value="star">{{ star }} yje</option>
            </select>
          </label>

          <label class="field">
            <span>Titulli</span>
            <input v-model="reviewForm.title" type="text" placeholder="Si te eshte dukur produkti?">
          </label>

          <label class="field">
            <span>Pershtypja jote</span>
            <textarea v-model="reviewForm.body" rows="4" placeholder="Shkruaj si ishte produkti, dergesa dhe pervoja jote."></textarea>
          </label>

          <button type="submit" :disabled="reviewBusy">
            {{ reviewBusy ? "Duke ruajtur..." : "Ruaje review-n" }}
          </button>
        </form>

        <div v-else class="product-review-empty-note">
          Vetem bleresit qe e kane pranuar produktin mund te lene review.
        </div>

        <div v-if="productReviews.length > 0" class="product-reviews-list">
          <article v-for="review in productReviews" :key="review.id" class="product-review-item">
            <div class="product-review-top">
              <div>
                <p class="section-label">{{ review.authorName }}</p>
                <strong>{{ review.title || `${review.rating} yje` }}</strong>
              </div>
              <div class="product-review-rating">{{ review.rating }}/5</div>
            </div>
            <p class="section-text">{{ review.body }}</p>
            <p class="product-review-date">{{ formatDateLabel(review.createdAt) }}</p>
          </article>
        </div>
        <div v-else class="product-review-empty-note">
          Ende nuk ka review per kete produkt.
        </div>
      </section>

      <section
        v-if="relatedViewedProducts.length > 0"
        class="card product-recently-viewed-card"
        aria-label="Produktet e pare se fundi"
      >
        <header class="product-recently-viewed-header">
          <div>
            <p class="section-label">Pare se fundi</p>
            <h2>Vazhdo aty ku e le</h2>
          </div>
          <RouterLink class="nav-action nav-action-secondary" to="/kerko">
            Shih katalogun
          </RouterLink>
        </header>

        <section class="pet-products-grid product-recently-viewed-grid">
          <ProductCard
            v-for="product in relatedViewedProducts"
            :key="`recent-${product.id}`"
            :product="product"
            :show-overlay-actions="false"
            :show-description="true"
          />
        </section>
      </section>

      <RecommendationSections
        v-if="productRecommendationSections.length > 0"
        :sections="productRecommendationSections"
        :wishlist-ids="wishlistIds"
        :cart-ids="cartIds"
        :busy-wishlist-ids="[]"
        :busy-cart-ids="[]"
        :compared-product-ids="comparedProductIds"
        @wishlist="handleRecommendationWishlist"
        @cart="handleRecommendationCart"
      />
    </section>

    <div v-else class="pets-empty-state">
      Produkti nuk u gjet.
    </div>
  </section>
</template>
