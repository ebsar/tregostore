<script setup lang="ts">
import { IonButton, IonContent, IonIcon, IonPage, IonSpinner } from "@ionic/vue";
import {
  addOutline,
  arrowForwardOutline,
  bagHandleOutline,
  cameraOutline,
  chatbubbleEllipsesOutline,
  checkmarkCircle,
  closeOutline,
  heartOutline,
  informationCircleOutline,
  locateOutline,
  returnUpBackOutline,
  shareSocialOutline,
  shieldCheckmarkOutline,
  star,
  storefrontOutline,
  timeOutline,
} from "ionicons/icons";
import { computed, onMounted, onUnmounted, ref, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import AppBackButton from "../components/AppBackButton.vue";
import EmptyStatePanel from "../components/EmptyStatePanel.vue";
import ProductCardMobile from "../components/ProductCardMobile.vue";
import {
  addToCart,
  fetchMarketplaceProducts,
  fetchProductDetail,
  fetchProductReviews,
  fetchPublicBusinessProducts,
  openBusinessConversation,
  toggleWishlist,
  trackProductShare,
} from "../lib/api";
import { API_BASE_URL } from "../lib/config";
import { formatCount, formatDateLabel, formatPrice, getDiscountPercent, getProductImage } from "../lib/format";
import { rememberRecentlyViewedProduct, readRecentlyViewedProducts } from "../lib/recentlyViewed";
import { readMobileRecentSearches } from "../lib/searchHistory";
import type { ProductItem, ProductReview, ProductVariant } from "../types/models";
import { ensureSession, refreshCounts, sessionState } from "../stores/session";

const route = useRoute();
const router = useRouter();

const loading = ref(true);
const reviewsLoading = ref(false);
const relatedLoading = ref(false);
const cartBusy = ref(false);
const messageBusy = ref(false);
const product = ref<ProductItem | null>(null);
const reviews = ref<ProductReview[]>([]);
const relatedProductsPool = ref<ProductItem[]>([]);
const canSubmitReview = ref(false);
const selectedColor = ref("");
const selectedSize = ref("");
const selectedQuantity = ref(1);
const activeImagePath = ref("");
const selectedDeliveryMethod = ref("express");
const variantSheetOpen = ref(false);
const privacyOpen = ref(false);
const toastVisible = ref(false);
const toastMessage = ref("");
const inlineMessage = ref("");
const inlineTone = ref<"error" | "success">("error");
let toastTimer = 0;

const galleryImages = computed(() => {
  const gallery = Array.isArray(product.value?.imageGallery) ? [...(product.value?.imageGallery || [])] : [];
  const primary = String(product.value?.imagePath || "").trim();
  if (primary && !gallery.includes(primary)) {
    gallery.unshift(primary);
  }
  return gallery.filter(Boolean);
});

const comparePrice = computed(() => Number(product.value?.compareAtPrice || 0));
const discount = computed(() => getDiscountPercent(product.value || {}));
const hasSale = computed(() => comparePrice.value > selectedVariantPrice.value);
const reviewAverage = computed(() => {
  const value = Number(product.value?.averageRating || 0);
  return Number.isFinite(value) ? value : 0;
});
const reviewCount = computed(() => Math.max(0, Number(product.value?.reviewCount || reviews.value.length || 0)));
const soldCount = computed(() => formatCount(product.value?.buyersCount || 0));
const ratingNumber = computed(() => reviewAverage.value > 0 ? reviewAverage.value.toFixed(1) : "0.0");
const ratingStars = computed(() =>
  Array.from({ length: 5 }, (_, index) => index < Math.round(Math.min(5, Math.max(0, reviewAverage.value)))),
);

const variantInventory = computed<ProductVariant[]>(() =>
  Array.isArray(product.value?.variantInventory) ? product.value?.variantInventory || [] : [],
);

const colorOptions = computed(() =>
  [...new Set(variantInventory.value.map((entry) => String(entry.color || "").trim().toLowerCase()).filter(Boolean))]
    .map((value) => ({
      value,
      label: value.charAt(0).toUpperCase() + value.slice(1),
      inStock: variantInventory.value.some((entry) => String(entry.color || "").trim().toLowerCase() === value && Number(entry.quantity || 0) > 0),
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
      inStock: activeEntries.some((entry) => String(entry.size || "").trim().toUpperCase() === value && Number(entry.quantity || 0) > 0),
    }));
});

const selectedVariant = computed<ProductVariant | null>(() => {
  if (!variantInventory.value.length) {
    return null;
  }

  if (variantInventory.value.length === 1) {
    return variantInventory.value[0];
  }

  return variantInventory.value.find((entry) => {
    const entryColor = String(entry.color || "").trim().toLowerCase();
    const entrySize = String(entry.size || "").trim().toUpperCase();
    const colorMatches = !selectedColor.value || entryColor === selectedColor.value;
    const sizeMatches = !selectedSize.value || entrySize === selectedSize.value;
    if (selectedColor.value && selectedSize.value) {
      return colorMatches && sizeMatches;
    }
    if (selectedColor.value && !selectedSize.value) {
      return colorMatches;
    }
    if (!selectedColor.value && selectedSize.value) {
      return sizeMatches;
    }
    return false;
  }) || null;
});

const selectedVariantPrice = computed(() => {
  const variantPrice = Number(selectedVariant.value?.price || 0);
  if (variantPrice > 0) {
    return variantPrice;
  }
  return Number(product.value?.price || 0);
});

const selectedVariantLabel = computed(() => {
  if (selectedVariant.value?.label) {
    return String(selectedVariant.value.label);
  }

  const parts: string[] = [];
  if (selectedColor.value) {
    parts.push(selectedColor.value.charAt(0).toUpperCase() + selectedColor.value.slice(1));
  }
  if (selectedSize.value) {
    parts.push(selectedSize.value);
  }
  return parts.join(" · ") || "Standard";
});

const selectedVariantStock = computed(() => {
  if (selectedVariant.value) {
    return maxAvailableQuantityForSelection(selectedVariant.value);
  }
  if (product.value?.requiresVariantSelection) {
    return 0;
  }
  return maxAvailableQuantityForSelection(product.value || {});
});

const hasStock = computed(() =>
  selectedVariantStock.value > 0
  || (!product.value?.requiresVariantSelection && Number(product.value?.stockQuantity || 0) > 0),
);

const quantityMax = computed(() => Math.max(1, Math.min(12, selectedVariantStock.value || 1)));

const detailChips = computed(() =>
  [
    product.value?.category || "",
    product.value?.productType || "",
    product.value?.packageAmountValue && product.value?.packageAmountUnit
      ? `${product.value.packageAmountValue}${product.value.packageAmountUnit}`
      : "",
  ].filter(Boolean),
);

function resolveVariantImage(colorValue: string, index: number) {
  const directMatch = variantInventory.value.find((entry) => String(entry.color || "").trim().toLowerCase() === colorValue && String(entry.imagePath || "").trim());
  const galleryMatch = galleryImages.value[index] || galleryImages.value[0] || "";
  return String(directMatch?.imagePath || galleryMatch || product.value?.imagePath || "").trim();
}

const variantVisualOptions = computed(() => {
  if (colorOptions.value.length) {
    return colorOptions.value.map((option, index) => ({
      key: `color-${option.value}`,
      label: option.label,
      value: option.value,
      imagePath: resolveVariantImage(option.value, index),
      inStock: option.inStock,
      kind: "color" as const,
    }));
  }

  return galleryImages.value.map((image, index) => ({
    key: `image-${image}-${index}`,
    label: index === 0 ? "Kryesore" : `Foto ${index + 1}`,
    value: "",
    imagePath: image,
    inStock: true,
    kind: "image" as const,
  }));
});

const shippingOptions = computed(() => [
  {
    value: "express",
    icon: timeOutline,
    title: "Fast delivery",
    copy: "Posta e shpejte · 24-48 ore",
  },
  {
    value: "standard",
    icon: locateOutline,
    title: "Standard",
    copy: "Dergese normale · 2-4 dite",
  },
  {
    value: "pickup",
    icon: storefrontOutline,
    title: "Mere tek biznesi",
    copy: "Pa pagese shtese",
  },
]);

const selectedShippingOption = computed(() =>
  shippingOptions.value.find((item) => item.value === selectedDeliveryMethod.value) || shippingOptions.value[0],
);

const recommendedProducts = computed(() => {
  const recentTerms = readMobileRecentSearches().map((item) => item.toLowerCase());
  const recentViewedIds = new Set(readRecentlyViewedProducts().map((item) => Number(item.id || 0)));
  const currentProductId = Number(product.value?.id || 0);
  const currentCategory = String(product.value?.category || "").toLowerCase();
  const currentType = String(product.value?.productType || "").toLowerCase();

  return [...relatedProductsPool.value]
    .filter((entry, index, list) => {
      const id = Number(entry.id || 0);
      return id > 0 && id !== currentProductId && list.findIndex((item) => Number(item.id || 0) === id) === index;
    })
    .map((entry) => {
      let score = 0;
      if (recentViewedIds.has(Number(entry.id || 0))) score += 7;
      if (String(entry.category || "").toLowerCase() === currentCategory) score += 6;
      if (String(entry.productType || "").toLowerCase() === currentType) score += 4;

      const searchHaystack = `${String(entry.title || "").toLowerCase()} ${String(entry.category || "").toLowerCase()} ${String(entry.description || "").toLowerCase()}`;
      for (const term of recentTerms) {
        if (term && searchHaystack.includes(term)) {
          score += 3;
        }
      }

      score += Math.min(5, Number(entry.shareCount || 0));
      score += Math.min(5, Number(entry.wishlistCount || 0));
      return { entry, score };
    })
    .sort((left, right) => right.score - left.score)
    .map((item) => item.entry)
    .slice(0, 8);
});

function clearInlineMessage() {
  inlineMessage.value = "";
}

function setInlineMessage(message: string, tone: "error" | "success" = "error") {
  inlineMessage.value = message;
  inlineTone.value = tone;
}

function showToast(message: string) {
  toastMessage.value = message;
  toastVisible.value = true;
  window.clearTimeout(toastTimer);
  toastTimer = window.setTimeout(() => {
    toastVisible.value = false;
  }, 2200);
}

function maxAvailableQuantityForSelection(target: Partial<ProductVariant & ProductItem>) {
  const rawValue = Number((target as any)?.quantity ?? (target as any)?.stockQuantity ?? 0);
  if (!Number.isFinite(rawValue) || rawValue <= 0) {
    return 0;
  }
  return Math.max(0, Math.trunc(rawValue));
}

function initializeVariantSelection() {
  selectedColor.value = "";
  selectedSize.value = "";
  selectedQuantity.value = 1;

  if (!variantInventory.value.length) {
    activeImagePath.value = galleryImages.value[0] || "";
    return;
  }

  if (variantInventory.value.length === 1) {
    selectedColor.value = String(variantInventory.value[0].color || "").trim().toLowerCase();
    selectedSize.value = String(variantInventory.value[0].size || "").trim().toUpperCase();
  } else {
    if (colorOptions.value.length === 1) {
      selectedColor.value = colorOptions.value[0].value;
    }
    if (sizeOptions.value.length === 1) {
      selectedSize.value = sizeOptions.value[0].value;
    }
  }

  if (selectedColor.value) {
    const firstVariantVisual = variantVisualOptions.value.find((item) => item.kind === "color" && item.value === selectedColor.value);
    activeImagePath.value = firstVariantVisual?.imagePath || galleryImages.value[0] || "";
  } else {
    activeImagePath.value = galleryImages.value[0] || "";
  }
}

function setActiveImage(imagePath: string) {
  activeImagePath.value = imagePath;
}

function chooseColor(colorValue: string) {
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

  const variantVisual = variantVisualOptions.value.find((item) => item.kind === "color" && item.value === colorValue);
  if (variantVisual?.imagePath) {
    activeImagePath.value = variantVisual.imagePath;
  }
}

function chooseSize(sizeValue: string) {
  selectedSize.value = sizeValue;
}

function chooseVariantVisual(option: { kind: "color" | "image"; value: string; imagePath: string }) {
  if (option.kind === "color" && option.value) {
    chooseColor(option.value);
  }
  if (option.imagePath) {
    activeImagePath.value = option.imagePath;
  }
}

function decrementQuantity() {
  selectedQuantity.value = Math.max(1, selectedQuantity.value - 1);
}

function incrementQuantity() {
  selectedQuantity.value = Math.min(quantityMax.value, selectedQuantity.value + 1);
}

function openVariantSheet() {
  clearInlineMessage();
  variantSheetOpen.value = true;
}

async function confirmAddToCart() {
  if (!product.value || cartBusy.value) {
    return;
  }

  if (product.value.requiresVariantSelection && !selectedVariant.value) {
    setInlineMessage("Zgjidh ngjyren ose madhesine para se ta shtosh ne cart.", "error");
    return;
  }

  cartBusy.value = true;
  try {
    const { response, data } = await addToCart(product.value.id, selectedQuantity.value, {
      variantKey: String(selectedVariant.value?.key || "").trim(),
      selectedSize: String(selectedVariant.value?.size || selectedSize.value || "").trim().toUpperCase(),
      selectedColor: String(selectedVariant.value?.color || selectedColor.value || "").trim().toLowerCase(),
    });
    if (!response.ok || !data?.ok) {
      setInlineMessage(String(data?.message || data?.errors?.join?.(" ") || "Produkti nuk u shtua ne cart."), "error");
      return;
    }

    await refreshCounts();
    variantSheetOpen.value = false;
    setInlineMessage("", "success");
    showToast("U shtua ne cart me sukses.");
  } finally {
    cartBusy.value = false;
  }
}

async function handleWishlist() {
  if (!product.value) {
    return;
  }
  await toggleWishlist(product.value.id);
  await refreshCounts();
  showToast("Produkti u ruajt ne wishlist.");
}

function handleRecommendationCart(productId: number) {
  router.push(`/product/${productId}`);
}

async function handleShare() {
  if (!product.value) {
    return;
  }

  const shareUrl = `${API_BASE_URL}/produkti?id=${encodeURIComponent(String(product.value.id))}`;
  const sharePayload = {
    title: product.value.title,
    text: `${product.value.title} • ${formatPrice(selectedVariantPrice.value)}`,
    url: shareUrl,
  };

  try {
    if (typeof navigator !== "undefined" && typeof navigator.share === "function") {
      await navigator.share(sharePayload);
      showToast("Produkti u nda me sukses.");
    } else if (typeof navigator !== "undefined" && navigator.clipboard?.writeText) {
      await navigator.clipboard.writeText(shareUrl);
      showToast("Linku i produktit u kopjua.");
    } else {
      window.prompt("Kopjo linkun e produktit:", shareUrl);
      showToast("Linku i produktit eshte gati per share.");
    }

    const { response, data } = await trackProductShare(product.value.id);
    if (response.ok && data?.ok && data.metrics && product.value) {
      product.value = {
        ...product.value,
        ...data.metrics,
      };
    }
  } catch (error: any) {
    if (error?.name !== "AbortError") {
      console.error(error);
      setInlineMessage("Shperndarja nuk u krye. Provoje perseri.", "error");
    }
  }
}

async function handleMessageBusiness() {
  if (!product.value || messageBusy.value) {
    return;
  }

  await ensureSession();
  if (!sessionState.user) {
    router.push({ path: "/login", query: { redirect: route.fullPath } });
    return;
  }

  const businessProfileId = Number(product.value.businessProfileId || 0);
  if (businessProfileId <= 0) {
    router.push("/messages");
    return;
  }

  messageBusy.value = true;
  try {
    const { response, data } = await openBusinessConversation(businessProfileId);
    if (!response.ok || !data?.ok || !data?.conversation?.id) {
      setInlineMessage(String(data?.message || "Biseda nuk u hap."), "error");
      return;
    }

    const prefill = `Pershendetje, jam i interesuar per produktin "${product.value.title}".`;
    router.push({
      path: `/messages/${data.conversation.id}`,
      query: { prefill },
    });
  } finally {
    messageBusy.value = false;
  }
}

function openSellerStore() {
  if (!product.value) {
    return;
  }

  const businessProfileId = Number(product.value.businessProfileId || 0);
  if (businessProfileId > 0) {
    router.push(`/business/public/${businessProfileId}`);
    return;
  }

  const fallbackQuery = String(product.value.businessName || "").trim();
  router.push(fallbackQuery ? `/tabs/search?q=${encodeURIComponent(fallbackQuery)}` : "/tabs/search");
}

async function loadProduct() {
  loading.value = true;
  clearInlineMessage();
  try {
    const nextProduct = await fetchProductDetail(String(route.params.id || ""));
    product.value = nextProduct;
    reviews.value = [];
    relatedProductsPool.value = [];
    initializeVariantSelection();

    if (nextProduct?.id) {
      rememberRecentlyViewedProduct(nextProduct);

      reviewsLoading.value = true;
      relatedLoading.value = true;

      const [reviewPayload, marketplaceProducts, sameStoreProducts] = await Promise.all([
        fetchProductReviews(nextProduct.id),
        fetchMarketplaceProducts(24, 0).catch(() => []),
        nextProduct.businessProfileId
          ? fetchPublicBusinessProducts(nextProduct.businessProfileId, 12, 0).catch(() => [])
          : Promise.resolve([]),
      ]);

      reviews.value = reviewPayload.reviews;
      canSubmitReview.value = reviewPayload.canSubmitReview;
      relatedProductsPool.value = [
        ...sameStoreProducts,
        ...readRecentlyViewedProducts(),
        ...marketplaceProducts,
      ];
    } else {
      canSubmitReview.value = false;
    }
  } finally {
    reviewsLoading.value = false;
    relatedLoading.value = false;
    loading.value = false;
  }
}

onMounted(() => {
  void loadProduct();
});

watch(
  () => String(route.params.id || ""),
  (nextValue, previousValue) => {
    if (!nextValue || nextValue === previousValue) {
      return;
    }
    void loadProduct();
  },
);

watch(selectedVariantStock, (nextValue) => {
  const maxAllowed = Math.max(1, Math.min(12, nextValue || 1));
  if (selectedQuantity.value > maxAllowed) {
    selectedQuantity.value = maxAllowed;
  }
});

watch(selectedVariant, (nextVariant) => {
  const nextImagePath = String(nextVariant?.imagePath || "").trim();
  if (nextImagePath) {
    activeImagePath.value = nextImagePath;
  }
});

onUnmounted(() => {
  window.clearTimeout(toastTimer);
});
</script>

<template>
  <IonPage>
    <IonContent class="app-gradient" :fullscreen="true">
      <div class="mobile-page product-detail-page">
        <section v-if="loading" class="surface-card empty-panel">
          <IonSpinner name="crescent" />
        </section>

        <template v-else-if="product">
          <transition name="cart-toast">
            <div v-if="toastVisible" class="product-detail-toast">
              <IonIcon :icon="checkmarkCircle" />
              <span>{{ toastMessage }}</span>
            </div>
          </transition>

          <div class="page-back-anchor">
            <AppBackButton back-to="/tabs/home" />
          </div>

          <p v-if="inlineMessage" class="product-inline-message" :class="inlineTone">{{ inlineMessage }}</p>

          <section class="product-hero">
            <div class="product-media-frame">
              <img
                :src="activeImagePath ? getProductImage({ imagePath: activeImagePath }) : getProductImage(product)"
                :alt="product.title"
              />
              <span v-if="discount" class="product-detail-badge">-{{ discount }}%</span>
            </div>

            <div v-if="variantVisualOptions.length > 1" class="product-variant-rail">
              <button
                v-for="item in variantVisualOptions"
                :key="item.key"
                class="variant-visual-chip"
                :class="{
                  active: (item.kind === 'color' && selectedColor === item.value) || (!selectedColor && activeImagePath === item.imagePath),
                  unavailable: !item.inStock,
                }"
                type="button"
                :disabled="!item.inStock"
                @click="chooseVariantVisual(item)"
              >
                <img :src="getProductImage({ imagePath: item.imagePath })" :alt="item.label" />
                <span>{{ item.label }}</span>
              </button>
            </div>
          </section>

          <section class="product-copy-stack">
            <div class="product-title-row">
              <div>
                <h1>{{ product.title }}</h1>
                <div class="product-rating-row">
                  <span class="product-star-row">
                    <IonIcon
                      v-for="(isActive, index) in ratingStars"
                      :key="`star-${index}`"
                      :icon="star"
                      :class="{ active: isActive }"
                    />
                  </span>
                  <span class="product-rating-number">{{ ratingNumber }}</span>
                  <span class="product-sold-count">{{ soldCount }} shitje</span>
                </div>
              </div>

              <div class="product-meta-actions">
                <button class="product-meta-action" type="button" @click="handleWishlist">
                  <IonIcon :icon="heartOutline" />
                </button>
                <button class="product-meta-action" type="button" @click="handleShare">
                  <IonIcon :icon="shareSocialOutline" />
                </button>
              </div>
            </div>

            <div class="meta-pill-row">
              <span v-if="product.businessName" class="meta-pill meta-pill--brand">
                <IonIcon :icon="storefrontOutline" />
                {{ product.businessName }}
              </span>
              <span v-for="detail in detailChips" :key="detail" class="meta-pill">{{ detail }}</span>
            </div>

            <section class="price-focus-card" :class="{ 'is-sale': hasSale }">
              <div class="price-focus-copy">
                <p>Çmimi aktual</p>
                <strong>{{ formatPrice(selectedVariantPrice) }}</strong>
                <small v-if="hasSale">{{ formatPrice(comparePrice) }}</small>
              </div>

              <div class="price-focus-meta">
                <span v-if="selectedVariantLabel !== 'Standard'" class="price-focus-pill">{{ selectedVariantLabel }}</span>
                <span class="price-focus-stock" :class="{ 'is-out': !hasStock }">
                  {{ hasStock ? `${selectedVariantStock || product.stockQuantity || 0} ne stok` : "Pa stok" }}
                </span>
                <span v-if="product.saleEndsAt" class="price-focus-note">Zgjat deri {{ formatDateLabel(product.saleEndsAt) }}</span>
              </div>
            </section>

            <section class="delivery-section">
              <div class="section-head-inline section-head-inline--tight">
                <div>
                  <p class="section-kicker">Transporti</p>
                  <h2>Si deshiron ta marresh?</h2>
                </div>
              </div>

              <div class="delivery-options">
                <button
                  v-for="option in shippingOptions"
                  :key="option.value"
                  class="delivery-option"
                  :class="{ active: selectedDeliveryMethod === option.value }"
                  type="button"
                  @click="selectedDeliveryMethod = option.value"
                >
                  <IonIcon :icon="option.icon" />
                  <div>
                    <strong>{{ option.title }}</strong>
                    <span>{{ option.copy }}</span>
                  </div>
                </button>
              </div>

              <div class="tiny-info-stack">
                <span class="tiny-info-pill">
                  <IonIcon :icon="returnUpBackOutline" />
                  Free return within 3 days
                </span>

                <button class="tiny-privacy-button" type="button" @click="privacyOpen = true">
                  <span>Security &amp; Privacy</span>
                  <IonIcon :icon="informationCircleOutline" />
                </button>
              </div>
            </section>

            <section class="product-description">
              <div class="section-head-inline section-head-inline--tight">
                <div>
                  <p class="section-kicker">Pershkrimi</p>
                  <h2>Detajet e produktit</h2>
                </div>
              </div>
              <p class="section-copy section-copy--body">
                {{ product.description || "Pershkrimi i produktit do te shfaqet ketu duke perdorur te njejten databaze si webfaqja." }}
              </p>
            </section>

            <section class="seller-mini-panel">
              <div class="seller-mini-copy">
                <div class="seller-mini-title">
                  <strong>{{ product.businessName || "TREGO Marketplace" }}</strong>
                  <IonIcon
                    v-if="String(product.businessVerificationStatus || '').trim().toLowerCase() === 'verified'"
                    :icon="checkmarkCircle"
                  />
                </div>
                <span>{{ selectedShippingOption.title }} · {{ selectedShippingOption.copy }}</span>
              </div>
              <button class="seller-mini-link" type="button" @click="openSellerStore">
                Hap dyqanin
                <IonIcon :icon="arrowForwardOutline" />
              </button>
            </section>
          </section>

          <section class="surface-card section-card stack-list">
            <div class="section-head-inline reviews-head">
              <div>
                <p class="section-kicker">Reviews</p>
                <h2>Vleresimet e bleresve</h2>
              </div>
              <div class="reviews-summary">
                <strong>{{ ratingNumber }}</strong>
                <span>{{ reviewCount }}</span>
              </div>
            </div>

            <div v-if="reviewsLoading" class="surface-card empty-panel">
              <IonSpinner name="crescent" />
            </div>

            <div v-else-if="reviews.length" class="stack-list review-list">
              <article v-for="review in reviews" :key="review.id" class="review-card">
                <div class="review-card-top">
                  <div>
                    <p class="section-kicker review-author">{{ review.authorName || "Klient" }}</p>
                    <h3>{{ review.title || `${review.rating || 0} yje` }}</h3>
                  </div>
                  <span class="review-rating">{{ Number(review.rating || 0).toFixed(1) }}</span>
                </div>
                <p class="section-copy section-copy--body">{{ review.body || "Pa pershkrim shtese." }}</p>
                <img v-if="review.photoPath" :src="getProductImage({ imagePath: review.photoPath })" :alt="review.title || 'Review photo'" class="review-photo" />
                <small class="review-date">{{ formatDateLabel(String(review.createdAt || "")) }}</small>
              </article>
            </div>

            <p v-else class="section-copy">Ende nuk ka reviews per kete produkt.</p>
            <p v-if="canSubmitReview" class="section-copy review-note">
              Pas pranimit te porosise, ky produkt lejon edhe review nga llogaria jote.
            </p>
          </section>

          <section v-if="recommendedProducts.length" class="stack-list product-recommendations">
            <div class="section-head">
              <h2>Te rekomanduara per ty</h2>
              <small class="section-copy">Bazuar ne kerkimin dhe produktet e shikuara me heret.</small>
            </div>

            <div v-if="relatedLoading" class="surface-card empty-panel">
              <IonSpinner name="crescent" />
            </div>

            <div v-else class="product-grid product-grid--recommended">
              <ProductCardMobile
                v-for="item in recommendedProducts"
                :key="`recommended-${item.id}`"
                :product="item"
                @open="(id) => router.push(`/product/${id}`)"
                @cart="handleRecommendationCart"
                @wishlist="handleWishlist"
              />
            </div>
          </section>

          <div class="product-bottom-spacer" />

          <section class="product-bottom-pill">
            <button class="pill-side-button" type="button" @click="openSellerStore">
              <IonIcon :icon="storefrontOutline" />
              <span>Store</span>
            </button>

            <button class="pill-side-button" type="button" :disabled="messageBusy" @click="handleMessageBusiness">
              <IonIcon :icon="chatbubbleEllipsesOutline" />
              <span>{{ messageBusy ? "..." : "Mesazh" }}</span>
            </button>

            <button class="pill-cta-button" type="button" :disabled="!hasStock" @click="openVariantSheet">
              <IonIcon :icon="bagHandleOutline" />
              <span>Add to cart</span>
            </button>
          </section>

          <transition name="sheet-fade">
            <div v-if="variantSheetOpen" class="sheet-overlay" @click.self="variantSheetOpen = false">
              <section class="variant-sheet">
                <div class="variant-sheet-head">
                  <div>
                    <p class="section-kicker">Cart selection</p>
                    <h2>{{ product.title }}</h2>
                  </div>
                  <button class="sheet-close" type="button" @click="variantSheetOpen = false">
                    <IonIcon :icon="closeOutline" />
                  </button>
                </div>

                <div class="variant-sheet-summary">
                  <img :src="activeImagePath ? getProductImage({ imagePath: activeImagePath }) : getProductImage(product)" :alt="product.title" />
                  <div>
                    <strong>{{ formatPrice(selectedVariantPrice) }}</strong>
                    <span>{{ selectedVariantLabel }}</span>
                    <small>{{ hasStock ? "Gati per shtim ne cart" : "Kontrollo variantin e stokun" }}</small>
                  </div>
                </div>

                <div v-if="colorOptions.length" class="product-option-group">
                  <p class="product-option-label">Ngjyra</p>
                  <div class="product-option-row">
                    <button
                      v-for="option in colorOptions"
                      :key="option.value"
                      class="product-option-chip"
                      :class="{ active: selectedColor === option.value, unavailable: !option.inStock }"
                      type="button"
                      :disabled="!option.inStock"
                      @click="chooseColor(option.value)"
                    >
                      {{ option.label }}
                    </button>
                  </div>
                </div>

                <div v-if="sizeOptions.length" class="product-option-group">
                  <p class="product-option-label">Madhesia</p>
                  <div class="product-option-row">
                    <button
                      v-for="option in sizeOptions"
                      :key="option.value"
                      class="product-option-chip"
                      :class="{ active: selectedSize === option.value, unavailable: !option.inStock }"
                      type="button"
                      :disabled="!option.inStock"
                      @click="chooseSize(option.value)"
                    >
                      {{ option.value }}
                    </button>
                  </div>
                </div>

                <div class="sheet-quantity-row">
                  <div>
                    <p class="product-option-label">Sasia</p>
                    <small>{{ selectedVariantStock || product.stockQuantity || 0 }} cope te lira</small>
                  </div>
                  <div class="product-quantity-control">
                    <button type="button" :disabled="selectedQuantity <= 1" @click="decrementQuantity">-</button>
                    <span>{{ selectedQuantity }}</span>
                    <button type="button" :disabled="selectedQuantity >= quantityMax" @click="incrementQuantity">+</button>
                  </div>
                </div>

                <IonButton class="cta-button sheet-add-button" :disabled="cartBusy || !hasStock" @click="confirmAddToCart">
                  <IonIcon slot="start" :icon="addOutline" />
                  {{ cartBusy ? "Po shtohet..." : "Add to cart" }}
                </IonButton>
              </section>
            </div>
          </transition>

          <transition name="sheet-fade">
            <div v-if="privacyOpen" class="sheet-overlay sheet-overlay--privacy" @click.self="privacyOpen = false">
              <section class="privacy-popover">
                <button class="sheet-close privacy-close" type="button" @click="privacyOpen = false">
                  <IonIcon :icon="closeOutline" />
                </button>
                <div class="privacy-copy">
                  <strong>Security &amp; Privacy</strong>
                  <p>We protect your privacy and keep your personal details safe and secure.</p>
                </div>
              </section>
            </div>
          </transition>
        </template>

        <EmptyStatePanel
          v-else
          title="Produkti nuk u gjet"
          copy="Kontrollo lidhjen me backend-in ose provo nje produkt tjeter."
        />
      </div>
    </IonContent>
  </IonPage>
</template>

<style scoped>
.product-detail-page {
  gap: 18px;
  padding-bottom: calc(env(safe-area-inset-bottom, 0px) + 120px);
}

.product-grid--recommended {
  align-items: start;
}

.product-inline-message {
  margin: 0;
  padding: 10px 12px;
  border-radius: 18px;
  font-size: 0.82rem;
  font-weight: 700;
}

.product-inline-message.error {
  background: rgba(220, 38, 38, 0.12);
  color: #b91c1c;
}

.product-inline-message.success {
  background: rgba(34, 197, 94, 0.12);
  color: #15803d;
}

.product-detail-toast {
  position: fixed;
  top: calc(env(safe-area-inset-top, 0px) + 10px);
  left: 16px;
  right: 16px;
  z-index: 120;
  display: flex;
  align-items: center;
  gap: 10px;
  min-height: 42px;
  padding: 0 14px;
  border-radius: 999px;
  background: rgba(22, 163, 74, 0.96);
  color: #fff;
  box-shadow: 0 18px 36px rgba(22, 163, 74, 0.22);
}

.product-detail-toast ion-icon {
  font-size: 1rem;
}

.product-hero {
  display: grid;
  gap: 12px;
}

.product-media-frame {
  position: relative;
  overflow: hidden;
  border-radius: 30px;
  aspect-ratio: 1;
  background: rgba(255, 255, 255, 0.6);
}

.product-media-frame img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
}

.product-detail-badge {
  position: absolute;
  top: 14px;
  left: 14px;
  display: inline-flex;
  min-height: 28px;
  align-items: center;
  padding: 0 12px;
  border-radius: 999px;
  background: rgba(220, 38, 38, 0.92);
  color: #fff7f7;
  font-size: 0.78rem;
  font-weight: 800;
}

.product-variant-rail {
  display: flex;
  gap: 10px;
  overflow-x: auto;
  padding-bottom: 2px;
}

.variant-visual-chip {
  flex: 0 0 84px;
  display: grid;
  gap: 6px;
  padding: 6px;
  border: 1px solid var(--trego-input-border);
  border-radius: 20px;
  background: var(--trego-surface);
}

.variant-visual-chip.active {
  border-color: rgba(255, 106, 43, 0.52);
  box-shadow: 0 12px 22px rgba(255, 106, 43, 0.12);
}

.variant-visual-chip.unavailable {
  opacity: 0.42;
}

.variant-visual-chip img {
  width: 100%;
  height: 68px;
  border-radius: 14px;
  object-fit: cover;
}

.variant-visual-chip span {
  color: var(--trego-dark);
  font-size: 0.68rem;
  font-weight: 700;
  line-height: 1.2;
}

.product-copy-stack {
  display: grid;
  gap: 16px;
}

.product-title-row {
  display: flex;
  justify-content: space-between;
  gap: 12px;
}

.product-title-row h1 {
  margin: 0;
  color: var(--trego-dark);
  font-size: clamp(1.3rem, 6vw, 1.72rem);
  line-height: 1.02;
  letter-spacing: -0.03em;
}

.product-rating-row {
  display: flex;
  align-items: center;
  gap: 7px;
  margin-top: 8px;
  color: var(--trego-muted);
  font-size: 0.78rem;
  font-weight: 700;
}

.product-star-row {
  display: inline-flex;
  gap: 2px;
}

.product-star-row ion-icon {
  font-size: 0.72rem;
  color: rgba(31, 41, 55, 0.22);
}

.product-star-row ion-icon.active {
  color: #f59e0b;
}

.product-rating-number,
.product-sold-count {
  line-height: 1;
}

.product-meta-actions {
  display: flex;
  gap: 8px;
}

.product-meta-action {
  width: 40px;
  height: 40px;
  border: 1px solid var(--trego-input-border);
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.72);
  color: var(--trego-dark);
  box-shadow: 0 10px 20px rgba(31, 41, 55, 0.08);
}

.meta-pill--brand {
  color: var(--trego-accent);
}

.price-focus-card {
  display: flex;
  justify-content: space-between;
  gap: 14px;
  padding: 16px;
  border-radius: 26px;
  background: rgba(255, 255, 255, 0.88);
  border: 1px solid rgba(255, 255, 255, 0.94);
  box-shadow: 0 18px 36px rgba(31, 41, 55, 0.08);
}

.price-focus-card.is-sale {
  background: linear-gradient(180deg, rgba(254, 242, 242, 0.96), rgba(254, 226, 226, 0.92));
  border-color: rgba(248, 113, 113, 0.24);
}

.price-focus-copy {
  display: grid;
  gap: 6px;
}

.price-focus-copy p {
  margin: 0;
  color: var(--trego-muted);
  font-size: 0.78rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.08em;
}

.price-focus-copy strong {
  color: var(--trego-dark);
  font-size: 1.5rem;
  line-height: 1;
}

.price-focus-copy small {
  color: rgba(185, 28, 28, 0.8);
  font-size: 0.82rem;
  font-weight: 800;
  text-decoration: line-through;
}

.price-focus-meta {
  display: grid;
  justify-items: end;
  gap: 6px;
  text-align: right;
}

.price-focus-pill,
.price-focus-stock {
  display: inline-flex;
  min-height: 28px;
  align-items: center;
  padding: 0 10px;
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.86);
  color: var(--trego-dark);
  font-size: 0.72rem;
  font-weight: 800;
}

.price-focus-stock.is-out {
  color: #b91c1c;
}

.price-focus-note {
  color: var(--trego-muted);
  font-size: 0.7rem;
  line-height: 1.35;
  max-width: 12ch;
}

.delivery-section {
  display: grid;
  gap: 12px;
}

.section-head-inline--tight h2 {
  margin: 2px 0 0;
  font-size: 1.06rem;
}

.delivery-options {
  display: grid;
  gap: 10px;
}

.delivery-option {
  display: grid;
  grid-template-columns: auto minmax(0, 1fr);
  gap: 12px;
  align-items: start;
  padding: 14px;
  border: 1px solid var(--trego-input-border);
  border-radius: 22px;
  background: var(--trego-surface);
}

.delivery-option.active {
  border-color: rgba(255, 106, 43, 0.45);
  box-shadow: 0 14px 28px rgba(255, 106, 43, 0.12);
}

.delivery-option ion-icon {
  margin-top: 2px;
  color: var(--trego-accent);
  font-size: 1.05rem;
}

.delivery-option strong {
  display: block;
  color: var(--trego-dark);
  font-size: 0.88rem;
}

.delivery-option span {
  display: block;
  margin-top: 3px;
  color: var(--trego-muted);
  font-size: 0.74rem;
}

.tiny-info-stack {
  display: grid;
  gap: 8px;
}

.tiny-info-pill,
.tiny-privacy-button {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  width: fit-content;
  min-height: 30px;
  padding: 0 10px;
  border-radius: 999px;
  border: 1px solid var(--trego-input-border);
  background: rgba(255, 255, 255, 0.7);
  color: var(--trego-muted);
  font-size: 0.72rem;
  font-weight: 700;
}

.tiny-privacy-button {
  justify-content: center;
}

.product-description,
.seller-mini-panel {
  padding: 16px;
  border-radius: 24px;
  background: rgba(255, 255, 255, 0.7);
  border: 1px solid var(--trego-border);
}

.seller-mini-panel {
  display: flex;
  justify-content: space-between;
  gap: 10px;
  align-items: center;
}

.seller-mini-copy {
  display: grid;
  gap: 4px;
}

.seller-mini-title {
  display: flex;
  align-items: center;
  gap: 7px;
}

.seller-mini-title strong {
  color: var(--trego-dark);
  font-size: 0.95rem;
}

.seller-mini-title ion-icon {
  color: #22c55e;
  font-size: 0.95rem;
}

.seller-mini-copy span {
  color: var(--trego-muted);
  font-size: 0.74rem;
}

.seller-mini-link {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  border: 0;
  background: transparent;
  color: var(--trego-accent);
  font-size: 0.8rem;
  font-weight: 800;
}

.reviews-head {
  align-items: center;
}

.reviews-summary {
  display: grid;
  justify-items: end;
  gap: 2px;
}

.reviews-summary strong {
  color: var(--trego-dark);
  font-size: 1.18rem;
}

.reviews-summary span {
  color: var(--trego-muted);
  font-size: 0.74rem;
  font-weight: 700;
}

.review-list {
  gap: 12px;
}

.review-card {
  display: grid;
  gap: 8px;
  padding: 14px;
  border-radius: 22px;
  background: rgba(255, 255, 255, 0.68);
  border: 1px solid var(--trego-border);
}

.review-card-top {
  display: flex;
  justify-content: space-between;
  gap: 10px;
}

.review-card-top h3 {
  margin: 2px 0 0;
  color: var(--trego-dark);
  font-size: 0.95rem;
}

.review-author {
  margin: 0;
}

.review-rating {
  color: var(--trego-accent);
  font-size: 0.8rem;
  font-weight: 800;
}

.review-photo {
  width: 88px;
  height: 88px;
  border-radius: 18px;
  object-fit: cover;
}

.review-date,
.review-note {
  color: var(--trego-muted);
  font-size: 0.72rem;
}

.product-recommendations {
  padding-bottom: 8px;
}

.product-bottom-spacer {
  height: 12px;
}

.product-bottom-pill {
  position: fixed;
  left: 12px;
  right: 12px;
  bottom: calc(env(safe-area-inset-bottom, 0px) + 10px);
  z-index: 70;
  display: grid;
  grid-template-columns: auto auto minmax(0, 1fr);
  gap: 8px;
  align-items: center;
  padding: 8px;
  border-radius: 999px;
  border: 1px solid rgba(255, 255, 255, 0.72);
  background: rgba(255, 255, 255, 0.34);
  box-shadow:
    0 18px 40px rgba(31, 41, 55, 0.16),
    inset 0 1px 0 rgba(255, 255, 255, 0.78);
  backdrop-filter: blur(18px) saturate(145%);
  -webkit-backdrop-filter: blur(18px) saturate(145%);
}

.pill-side-button,
.pill-cta-button {
  min-height: 48px;
  border: 0;
  border-radius: 999px;
  font-size: 0.84rem;
  font-weight: 800;
}

.pill-side-button {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  padding: 0 14px;
  background: rgba(255, 255, 255, 0.68);
  color: var(--trego-dark);
}

.pill-cta-button {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  padding: 0 16px;
  background: linear-gradient(180deg, rgba(255, 106, 43, 0.98), rgba(240, 94, 35, 0.92));
  color: #fff;
  box-shadow: 0 16px 28px rgba(255, 106, 43, 0.28);
}

.sheet-overlay {
  position: fixed;
  inset: 0;
  z-index: 90;
  display: grid;
  align-items: end;
  padding: 18px 14px calc(env(safe-area-inset-bottom, 0px) + 14px);
  background: rgba(15, 23, 42, 0.24);
}

.sheet-overlay--privacy {
  align-items: center;
}

.variant-sheet,
.privacy-popover {
  border-radius: 28px;
  border: 1px solid rgba(255, 255, 255, 0.88);
  background: rgba(251, 249, 247, 0.98);
  box-shadow: 0 24px 56px rgba(31, 41, 55, 0.18);
}

.variant-sheet {
  padding: 18px 16px;
  display: grid;
  gap: 14px;
}

.variant-sheet-head {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 10px;
}

.variant-sheet-head h2 {
  margin: 2px 0 0;
  color: var(--trego-dark);
  font-size: 1.08rem;
  line-height: 1.16;
}

.sheet-close {
  width: 38px;
  height: 38px;
  border: 0;
  border-radius: 999px;
  background: rgba(31, 41, 55, 0.08);
  color: var(--trego-dark);
}

.variant-sheet-summary {
  display: grid;
  grid-template-columns: 72px minmax(0, 1fr);
  gap: 12px;
  align-items: center;
}

.variant-sheet-summary img {
  width: 72px;
  height: 72px;
  object-fit: cover;
  border-radius: 20px;
}

.variant-sheet-summary strong {
  display: block;
  color: var(--trego-dark);
  font-size: 1.06rem;
}

.variant-sheet-summary span,
.variant-sheet-summary small {
  display: block;
  color: var(--trego-muted);
  font-size: 0.74rem;
  margin-top: 3px;
}

.product-option-group {
  display: grid;
  gap: 10px;
}

.product-option-label {
  margin: 0;
  color: var(--trego-dark);
  font-size: 0.78rem;
  font-weight: 800;
}

.product-option-row {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.product-option-chip {
  min-height: 38px;
  padding: 0 14px;
  border: 1px solid var(--trego-input-border);
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.78);
  color: var(--trego-dark);
  font-size: 0.8rem;
  font-weight: 700;
}

.product-option-chip.active {
  border-color: rgba(255, 106, 43, 0.5);
  background: rgba(255, 106, 43, 0.12);
  color: var(--trego-accent);
}

.product-option-chip.unavailable {
  opacity: 0.42;
}

.sheet-quantity-row {
  display: flex;
  justify-content: space-between;
  gap: 12px;
  align-items: center;
}

.sheet-quantity-row small {
  color: var(--trego-muted);
  font-size: 0.72rem;
}

.product-quantity-control {
  display: inline-flex;
  align-items: center;
  gap: 10px;
  min-height: 42px;
  padding: 0 10px;
  border-radius: 999px;
  border: 1px solid var(--trego-input-border);
  background: rgba(255, 255, 255, 0.74);
}

.product-quantity-control button {
  width: 30px;
  height: 30px;
  border: 0;
  border-radius: 999px;
  background: rgba(31, 41, 55, 0.08);
  color: var(--trego-dark);
  font-size: 1rem;
  font-weight: 800;
}

.product-quantity-control span {
  min-width: 18px;
  text-align: center;
  color: var(--trego-dark);
  font-size: 0.86rem;
  font-weight: 800;
}

.sheet-add-button {
  margin-top: 4px;
}

.privacy-popover {
  position: relative;
  width: min(100%, 320px);
  padding: 16px;
}

.privacy-close {
  position: absolute;
  top: 10px;
  right: 10px;
}

.privacy-copy {
  display: grid;
  gap: 6px;
  max-width: 26ch;
}

.privacy-copy strong {
  color: var(--trego-dark);
  font-size: 0.86rem;
}

.privacy-copy p {
  margin: 0;
  color: var(--trego-muted);
  font-size: 0.72rem;
  line-height: 1.45;
}

.cart-toast-enter-active,
.cart-toast-leave-active,
.sheet-fade-enter-active,
.sheet-fade-leave-active {
  transition: opacity 180ms ease, transform 180ms ease;
}

.cart-toast-enter-from,
.cart-toast-leave-to,
.sheet-fade-enter-from,
.sheet-fade-leave-to {
  opacity: 0;
  transform: translateY(8px);
}
</style>
