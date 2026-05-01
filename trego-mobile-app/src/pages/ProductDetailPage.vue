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
  fetchProductRecommendations,
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
import type { ProductItem, ProductReview, ProductVariant, RecommendationSection } from "../types/models";
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
const recommendationSections = ref<RecommendationSection[]>([]);
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

const displayRecommendationSections = computed<RecommendationSection[]>(() => {
  if (recommendationSections.value.length) {
    return recommendationSections.value;
  }

  if (!recommendedProducts.value.length) {
    return [];
  }

  return [
    {
      key: "recommended-fallback",
      title: "Te rekomanduara per ty",
      subtitle: "Bazuar ne kerkimin dhe produktet e shikuara me heret.",
      products: recommendedProducts.value,
    },
  ];
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

async function handleRecommendationWishlist(productId: number) {
  await toggleWishlist(productId);
  await refreshCounts();
  showToast("Produkti u ruajt ne wishlist.");
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

      const [reviewPayload, productRecommendations, marketplaceProducts, sameStoreProducts] = await Promise.all([
        fetchProductReviews(nextProduct.id),
        fetchProductRecommendations(nextProduct.id, 6).catch(() => []),
        fetchMarketplaceProducts(24, 0).catch(() => []),
        nextProduct.businessProfileId
          ? fetchPublicBusinessProducts(nextProduct.businessProfileId, 12, 0).catch(() => [])
          : Promise.resolve([]),
      ]);

      reviews.value = reviewPayload.reviews;
      canSubmitReview.value = reviewPayload.canSubmitReview;
      recommendationSections.value = productRecommendations;
      relatedProductsPool.value = [
        ...sameStoreProducts,
        ...readRecentlyViewedProducts(),
        ...marketplaceProducts,
      ];
    } else {
      canSubmitReview.value = false;
      recommendationSections.value = [];
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
    <IonContent :fullscreen="true">
      <div class="trego-mobile-screen trego-product-screen">
        <section v-if="loading">
          <IonSpinner name="crescent" />
        </section>

        <template v-else-if="product">
          <transition name="cart-toast">
            <div v-if="toastVisible">
              <IonIcon :icon="checkmarkCircle" />
              <span>{{ toastMessage }}</span>
            </div>
          </transition>

          <div>
            <AppBackButton back-to="/tabs/home" />
          </div>

          <p v-if="inlineMessage">{{ inlineMessage }}</p>

          <section>
            <div>
              <img
                :src="activeImagePath ? getProductImage({ imagePath: activeImagePath }) : getProductImage(product)"
                :alt="product.title"
              />
              <span v-if="discount">-{{ discount }}%</span>
            </div>

            <div v-if="variantVisualOptions.length > 1">
              <button
                v-for="item in variantVisualOptions"
                :key="item.key"
               
               
                type="button"
                :disabled="!item.inStock"
                @click="chooseVariantVisual(item)"
              >
                <img :src="getProductImage({ imagePath: item.imagePath })" :alt="item.label" />
                <span>{{ item.label }}</span>
              </button>
            </div>
          </section>

          <section>
            <div>
              <div>
                <h1>{{ product.title }}</h1>
                <div>
                  <span>
                    <IonIcon
                      v-for="(isActive, index) in ratingStars"
                      :key="`star-${index}`"
                      :icon="star"
                     
                    />
                  </span>
                  <span>{{ ratingNumber }}</span>
                  <span>{{ soldCount }} shitje</span>
                </div>
              </div>

              <div>
                <button type="button" @click="handleWishlist">
                  <IonIcon :icon="heartOutline" />
                </button>
                <button type="button" @click="handleShare">
                  <IonIcon :icon="shareSocialOutline" />
                </button>
              </div>
            </div>

            <div>
              <span v-if="product.businessName">
                <IonIcon :icon="storefrontOutline" />
                {{ product.businessName }}
              </span>
              <span v-for="detail in detailChips" :key="detail">{{ detail }}</span>
            </div>

            <section>
              <div>
                <p>Çmimi aktual</p>
                <strong>{{ formatPrice(selectedVariantPrice) }}</strong>
                <small v-if="hasSale">{{ formatPrice(comparePrice) }}</small>
              </div>

              <div>
                <span v-if="selectedVariantLabel !== 'Standard'">{{ selectedVariantLabel }}</span>
                <span>
                  {{ hasStock ? `${selectedVariantStock || product.stockQuantity || 0} ne stok` : "Pa stok" }}
                </span>
                <span v-if="product.saleEndsAt">Zgjat deri {{ formatDateLabel(product.saleEndsAt) }}</span>
              </div>
            </section>

            <section>
              <div>
                <div>
                  <p>Transporti</p>
                  <h2>Si deshiron ta marresh?</h2>
                </div>
              </div>

              <div>
                <button
                  v-for="option in shippingOptions"
                  :key="option.value"
                 
                 
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

              <div>
                <span>
                  <IonIcon :icon="returnUpBackOutline" />
                  Free return within 3 days
                </span>

                <button type="button" @click="privacyOpen = true">
                  <span>Security &amp; Privacy</span>
                  <IonIcon :icon="informationCircleOutline" />
                </button>
              </div>
            </section>

            <section>
              <div>
                <div>
                  <p>Pershkrimi</p>
                  <h2>Detajet e produktit</h2>
                </div>
              </div>
              <p>
                {{ product.description || "Pershkrimi i produktit do te shfaqet ketu duke perdorur te njejten databaze si webfaqja." }}
              </p>
            </section>

            <section>
              <div>
                <div>
                  <strong>{{ product.businessName || "TREGIO Marketplace" }}</strong>
                  <IonIcon
                    v-if="String(product.businessVerificationStatus || '').trim().toLowerCase() === 'verified'"
                    :icon="checkmarkCircle"
                  />
                </div>
                <span>{{ selectedShippingOption.title }} · {{ selectedShippingOption.copy }}</span>
              </div>
              <button type="button" @click="openSellerStore">
                Hap dyqanin
                <IonIcon :icon="arrowForwardOutline" />
              </button>
            </section>
          </section>

          <section>
            <div>
              <div>
                <p>Reviews</p>
                <h2>Vleresimet e bleresve</h2>
              </div>
              <div>
                <strong>{{ ratingNumber }}</strong>
                <span>{{ reviewCount }}</span>
              </div>
            </div>

            <div v-if="reviewsLoading">
              <IonSpinner name="crescent" />
            </div>

            <div v-else-if="reviews.length">
              <article v-for="review in reviews" :key="review.id">
                <div>
                  <div>
                    <p>{{ review.authorName || "Klient" }}</p>
                    <h3>{{ review.title || `${review.rating || 0} yje` }}</h3>
                  </div>
                  <span>{{ Number(review.rating || 0).toFixed(1) }}</span>
                </div>
                <p>{{ review.body || "Pa pershkrim shtese." }}</p>
                <img v-if="review.photoPath" :src="getProductImage({ imagePath: review.photoPath })" :alt="review.title || 'Review photo'" />
                <small>{{ formatDateLabel(String(review.createdAt || "")) }}</small>
              </article>
            </div>

            <p v-else>Ende nuk ka reviews per kete produkt.</p>
            <p v-if="canSubmitReview">
              Pas pranimit te porosise, ky produkt lejon edhe review nga llogaria jote.
            </p>
          </section>

          <section v-if="displayRecommendationSections.length">
            <template v-for="section in displayRecommendationSections" :key="section.key">
              <div>
                <h2>{{ section.title }}</h2>
                <small v-if="section.subtitle">{{ section.subtitle }}</small>
              </div>

              <div v-if="relatedLoading">
                <IonSpinner name="crescent" />
              </div>

              <div v-else>
                <ProductCardMobile
                  v-for="item in section.products"
                  :key="`${section.key}-${item.id}`"
                  :product="item"
                  @open="(id) => router.push(`/product/${id}`)"
                  @cart="handleRecommendationCart"
                  @wishlist="handleRecommendationWishlist"
                />
              </div>
            </template>
          </section>

          <div />

          <section>
            <button type="button" @click="openSellerStore">
              <IonIcon :icon="storefrontOutline" />
              <span>Store</span>
            </button>

            <button type="button" :disabled="messageBusy" @click="handleMessageBusiness">
              <IonIcon :icon="chatbubbleEllipsesOutline" />
              <span>{{ messageBusy ? "..." : "Mesazh" }}</span>
            </button>

            <button type="button" :disabled="!hasStock" @click="openVariantSheet">
              <IonIcon :icon="bagHandleOutline" />
              <span>Add to cart</span>
            </button>
          </section>

          <transition name="sheet-fade">
            <div v-if="variantSheetOpen" @click.self="variantSheetOpen = false">
              <section>
                <div>
                  <div>
                    <p>Cart selection</p>
                    <h2>{{ product.title }}</h2>
                  </div>
                  <button type="button" @click="variantSheetOpen = false">
                    <IonIcon :icon="closeOutline" />
                  </button>
                </div>

                <div>
                  <img :src="activeImagePath ? getProductImage({ imagePath: activeImagePath }) : getProductImage(product)" :alt="product.title" />
                  <div>
                    <strong>{{ formatPrice(selectedVariantPrice) }}</strong>
                    <span>{{ selectedVariantLabel }}</span>
                    <small>{{ hasStock ? "Gati per shtim ne cart" : "Kontrollo variantin e stokun" }}</small>
                  </div>
                </div>

                <div v-if="colorOptions.length">
                  <p>Ngjyra</p>
                  <div>
                    <button
                      v-for="option in colorOptions"
                      :key="option.value"
                     
                     
                      type="button"
                      :disabled="!option.inStock"
                      @click="chooseColor(option.value)"
                    >
                      {{ option.label }}
                    </button>
                  </div>
                </div>

                <div v-if="sizeOptions.length">
                  <p>Madhesia</p>
                  <div>
                    <button
                      v-for="option in sizeOptions"
                      :key="option.value"
                     
                     
                      type="button"
                      :disabled="!option.inStock"
                      @click="chooseSize(option.value)"
                    >
                      {{ option.value }}
                    </button>
                  </div>
                </div>

                <div>
                  <div>
                    <p>Sasia</p>
                    <small>{{ selectedVariantStock || product.stockQuantity || 0 }} cope te lira</small>
                  </div>
                  <div>
                    <button type="button" :disabled="selectedQuantity <= 1" @click="decrementQuantity">-</button>
                    <span>{{ selectedQuantity }}</span>
                    <button type="button" :disabled="selectedQuantity >= quantityMax" @click="incrementQuantity">+</button>
                  </div>
                </div>

                <IonButton :disabled="cartBusy || !hasStock" @click="confirmAddToCart">
                  <IonIcon slot="start" :icon="addOutline" />
                  {{ cartBusy ? "Po shtohet..." : "Add to cart" }}
                </IonButton>
              </section>
            </div>
          </transition>

          <transition name="sheet-fade">
            <div v-if="privacyOpen" @click.self="privacyOpen = false">
              <section>
                <button type="button" @click="privacyOpen = false">
                  <IonIcon :icon="closeOutline" />
                </button>
                <div>
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
