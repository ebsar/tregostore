<script setup>
import { computed, onMounted, reactive, ref, watch } from "vue";
import { RouterLink, useRoute } from "vue-router";
import { fetchProtectedCollection, requestJson, resolveApiMessage } from "../lib/api";
import {
  formatCategoryLabel,
  formatPrice,
  formatProductColorLabel,
  formatProductTypeLabel,
  getCategoryUrl,
  getProductImageGallery,
} from "../lib/shop";
import { appState, ensureSessionLoaded, markRouteReady, setCartItems } from "../stores/app-state";

const route = useRoute();
const currentProduct = ref(null);
const currentImageIndex = ref(0);
const wishlistIds = ref([]);
const cartIds = ref([]);
const selectedColor = ref("");
const selectedSize = ref("");
const ui = reactive({
  message: "",
  type: "",
});

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
const backTarget = computed(() => {
  const candidate = String(route.query.back || "").trim();
  if (candidate.startsWith("/")) {
    return candidate;
  }

  return getCategoryUrl(currentProduct.value?.category);
});

watch(
  () => route.fullPath,
  async () => {
    await bootstrap();
  },
);

onMounted(async () => {
  await bootstrap();
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
    await Promise.all([
      ensureSessionLoaded().then(() => refreshCollectionState()),
      loadProduct(),
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
  );
  if (!response.ok || !data?.ok || !data.product) {
    currentProduct.value = null;
    ui.message = resolveApiMessage(data, "Produkti nuk u gjet.");
    ui.type = "error";
    return;
  }

  currentProduct.value = data.product;
  currentImageIndex.value = 0;
  initializeVariantSelection();
  ui.message = "";
  ui.type = "";
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
}

async function handleCart() {
  if (!currentProduct.value) {
    return;
  }

  if (!appState.user) {
    ui.message = "Duhet te kyçesh ose te krijosh llogari para se te perdoresh wishlist ose cart.";
    ui.type = "error";
    return;
  }

  const productId = currentProduct.value.id;
  if (currentProduct.value.requiresVariantSelection && !selectedVariant.value) {
    ui.message = "Zgjidh ngjyren dhe madhesine para se ta shtosh produktin ne cart.";
    ui.type = "error";
    return;
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
    }),
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
        </div>

        <div class="product-detail-copy">
          <p class="product-detail-category">{{ formatCategoryLabel(currentProduct.category) }}</p>
          <h1>{{ currentProduct.title }}</h1>
          <p class="product-detail-description">{{ currentProduct.description }}</p>

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

          <strong class="product-detail-price">{{ formatPrice(currentProduct.price) }}</strong>

          <div class="product-detail-actions">
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
              class="product-action-button cart-action"
              :class="{ active: cartIds.includes(currentProduct.id) }"
              type="button"
              @click="handleCart"
            >
              <svg class="nav-icon" viewBox="0 0 24 24" aria-hidden="true">
                <path d="M3 5h2l2.1 9.1a1 1 0 0 0 1 .8h8.8a1 1 0 0 0 1-.8L20 8H7.2"></path>
                <circle cx="10" cy="19" r="1.4"></circle>
                <circle cx="18" cy="19" r="1.4"></circle>
              </svg>
              <span>{{ cartIds.includes(currentProduct.id) ? "Ne cart" : "Shto ne cart" }}</span>
            </button>
          </div>
        </div>
      </article>
    </section>

    <div v-else class="pets-empty-state">
      Produkti nuk u gjet.
    </div>
  </section>
</template>
