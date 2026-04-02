<script setup lang="ts">
import {
  IonActionSheet,
  IonContent,
  IonIcon,
  IonInput,
  IonPage,
  IonSpinner,
} from "@ionic/vue";
import {
  closeOutline,
  cameraOutline,
  cameraSharp,
  imagesOutline,
  micOutline,
  pricetagOutline,
  pulseOutline,
} from "ionicons/icons";
import { computed, onBeforeUnmount, onMounted, ref, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import EmptyStatePanel from "../components/EmptyStatePanel.vue";
import ProductCardMobile from "../components/ProductCardMobile.vue";
import { addToCart, fetchMarketplaceProducts, searchProductsByImage, toggleWishlist } from "../lib/api";
import type { ProductItem } from "../types/models";
import { ensureSession, refreshCounts } from "../stores/session";

const router = useRouter();
const route = useRoute();
const loading = ref(true);
const searchQuery = ref("");
const voiceListening = ref(false);
const cameraSheetOpen = ref(false);
const uploadInputRef = ref<HTMLInputElement | null>(null);
const cameraInputRef = ref<HTMLInputElement | null>(null);
const products = ref<ProductItem[]>([]);
const imageSearchResults = ref<ProductItem[]>([]);

const primaryProducts = computed(() => (imageSearchResults.value.length ? imageSearchResults.value : products.value.slice(0, 10)));
const promoCards = computed(() => [
  {
    key: "trending",
    title: "Trending",
    subtitle: "Produktet me interesim",
    icon: pulseOutline,
  },
  {
    key: "sale",
    title: "Sale",
    subtitle: "Cmimet me te mira",
    icon: pricetagOutline,
  },
]);

function syncSearchQueryFromRoute() {
  const next = String(route.query.q || "").trim();
  if (next && next !== searchQuery.value) {
    searchQuery.value = next;
  }
}

onMounted(async () => {
  syncSearchQueryFromRoute();
  void ensureSession();
  try {
    products.value = await fetchMarketplaceProducts(20, 0);
  } finally {
    loading.value = false;
  }
});

watch(
  () => route.query.q,
  () => {
    syncSearchQueryFromRoute();
  },
);

onBeforeUnmount(() => {
  if (typeof imageSearchResults.value !== "undefined") {
    imageSearchResults.value = [];
  }
});

function openSearch() {
  const normalized = searchQuery.value.trim();
  router.push(normalized ? `/tabs/search?q=${encodeURIComponent(normalized)}` : "/tabs/search");
}

async function handleAddToCart(productId: number) {
  await addToCart(productId, 1);
  await refreshCounts();
}

async function handleWishlist(productId: number) {
  await toggleWishlist(productId);
  await refreshCounts();
}

async function handleVisualSearch(event: Event) {
  const file = ((event.target as HTMLInputElement | null)?.files || [])[0];
  if (!file) {
    return;
  }

  loading.value = true;
  try {
    const result = await searchProductsByImage(file, { limit: 12, includeFacets: 1 });
    if (result.ok) {
      imageSearchResults.value = result.products;
    }
  } finally {
    loading.value = false;
    if (event.target) {
      (event.target as HTMLInputElement).value = "";
    }
  }
}

function openUploadPicker() {
  cameraSheetOpen.value = false;
  uploadInputRef.value?.click();
}

function openCameraCapture() {
  cameraSheetOpen.value = false;
  cameraInputRef.value?.click();
}

function startVoiceSearch() {
  const Recognition = (globalThis as any)?.webkitSpeechRecognition || (globalThis as any)?.SpeechRecognition;
  if (!Recognition) {
    return;
  }

  const recognition = new Recognition();
  recognition.lang = "sq-AL";
  recognition.interimResults = false;
  recognition.maxAlternatives = 1;
  voiceListening.value = true;

  recognition.onresult = (event: any) => {
    const transcript = String(event?.results?.[0]?.[0]?.transcript || "").trim();
    if (transcript) {
      searchQuery.value = transcript;
      openSearch();
    }
  };
  recognition.onerror = () => {
    voiceListening.value = false;
  };
  recognition.onend = () => {
    voiceListening.value = false;
  };
  recognition.start();
}
</script>

<template>
  <IonPage>
    <IonContent class="app-gradient" :fullscreen="true">
      <div class="mobile-page mobile-page--tabbed mobile-page--edge mobile-page--home">
        <section class="home-search-hero">
          <form class="home-search-shell" @submit.prevent="openSearch">
            <IonInput
              v-model="searchQuery"
              class="home-search-input"
              placeholder="Search"
              @keydown.enter.prevent="openSearch"
            />

            <div class="home-search-actions">
              <button
                v-if="searchQuery.trim()"
                class="home-search-clear"
                type="button"
                @click="searchQuery = ''"
              >
                <IonIcon :icon="closeOutline" />
              </button>
              <button class="home-search-camera" type="button" @click="cameraSheetOpen = true">
                <IonIcon :icon="cameraOutline" />
              </button>
              <button
                class="home-search-voice"
                :class="{ active: voiceListening }"
                type="button"
                @click="startVoiceSearch"
              >
                <IonIcon :icon="micOutline" />
              </button>
            </div>
          </form>
        </section>

        <section class="home-promo-rail">
          <article
            v-for="item in promoCards"
            :key="item.key"
            class="home-promo-card"
          >
            <IonIcon :icon="item.icon" />
            <strong>{{ item.title }}</strong>
            <span>{{ item.subtitle }}</span>
          </article>
        </section>

        <section class="stack-list">
          <div class="section-head">
            <h2>{{ imageSearchResults.length ? "Results" : "Products" }}</h2>
          </div>

          <div v-if="loading" class="surface-card empty-panel">
            <IonSpinner name="crescent" />
          </div>

          <div v-else-if="primaryProducts.length" class="product-grid">
            <ProductCardMobile
              v-for="product in primaryProducts"
              :key="product.id"
              :product="product"
              @open="(id) => router.push(`/product/${id}`)"
              @cart="handleAddToCart"
              @wishlist="handleWishlist"
            />
          </div>

          <EmptyStatePanel
            v-else
            title="Nuk ka produkte"
            copy="Produktet do te dalin ketu sapo backend-i t'i ktheje."
          />
        </section>

        <input
          ref="cameraInputRef"
          class="sr-only"
          type="file"
          accept="image/*"
          capture="environment"
          @change="handleVisualSearch"
        >
        <input
          ref="uploadInputRef"
          class="sr-only"
          type="file"
          accept="image/*"
          @change="handleVisualSearch"
        >

        <IonActionSheet
          :is-open="cameraSheetOpen"
          header="Camera search"
          :buttons="[
            { text: 'Fotografo tani', icon: cameraSharp, handler: openCameraCapture },
            { text: 'Ngarko imazh', icon: imagesOutline, handler: openUploadPicker },
            { text: 'Anulo', role: 'cancel' },
          ]"
          @didDismiss="cameraSheetOpen = false"
        />
      </div>
    </IonContent>
  </IonPage>
</template>

<style scoped>
.mobile-page--home {
  gap: 14px;
}

.home-search-hero {
  position: relative;
  z-index: 4;
}

.home-search-shell {
  position: relative;
  display: flex;
  align-items: center;
  gap: 12px;
  min-height: 58px;
  padding: 0 18px;
  border-radius: 999px;
  border: 1px solid rgba(255, 255, 255, 0.64);
  background:
    linear-gradient(180deg, rgba(255, 255, 255, 0.24), rgba(255, 255, 255, 0.1)),
    radial-gradient(circle at 8% 0%, rgba(255, 255, 255, 0.28), transparent 28%);
  box-shadow:
    0 14px 28px rgba(31, 41, 55, 0.08),
    inset 0 1px 0 rgba(255, 255, 255, 0.78);
  backdrop-filter: blur(24px) saturate(165%);
  -webkit-backdrop-filter: blur(24px) saturate(165%);
}

.home-search-shell::after {
  content: "";
  position: absolute;
  inset: 1px;
  border-radius: inherit;
  background: linear-gradient(180deg, rgba(255, 255, 255, 0.16), transparent 24%);
  pointer-events: none;
}

.home-search-input {
  flex: 1 1 auto;
  --padding-start: 0;
  --padding-end: 0;
  --placeholder-color: rgba(47, 52, 70, 0.5);
  color: var(--trego-dark);
  font-size: 1rem;
  font-weight: 700;
}

.home-search-actions {
  display: flex;
  align-items: center;
  gap: 10px;
  color: rgba(47, 52, 70, 0.62);
}

.home-search-clear,
.home-search-camera,
.home-search-voice {
  display: inline-flex;
  width: 30px;
  height: 30px;
  align-items: center;
  justify-content: center;
  border: 0;
  border-radius: 999px;
  background: transparent;
  color: inherit;
}

.home-search-clear {
  background: rgba(255, 255, 255, 0.7);
  box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.8);
}

.home-search-clear ion-icon {
  font-size: 0.88rem;
}

.home-search-camera ion-icon,
.home-search-voice ion-icon {
  font-size: 1.08rem;
}

.home-search-voice.active {
  color: var(--trego-accent);
}

.home-promo-rail {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 12px;
}

.home-promo-card {
  display: grid;
  gap: 7px;
  min-height: 104px;
  padding: 16px;
  border: 1px solid rgba(255, 255, 255, 0.07);
  border-radius: 24px;
  background:
    radial-gradient(circle at top right, rgba(255, 255, 255, 0.08), transparent 28%),
    linear-gradient(180deg, rgba(27, 31, 41, 0.98), rgba(13, 16, 23, 0.98));
  color: #ffffff;
  box-shadow:
    0 12px 26px rgba(0, 0, 0, 0.18),
    inset 0 1px 0 rgba(255, 255, 255, 0.04);
  min-width: 0;
}

.home-product-grid :deep(.product-card-mobile) {
  gap: 8px;
  padding: 8px;
}

.home-product-grid :deep(.product-card-mobile-media) {
  border-radius: 16px;
}

.home-product-grid :deep(.product-card-mobile-title) {
  font-size: 0.84rem;
  min-height: 2.2em;
}

.home-product-grid :deep(.product-card-mobile-desc) {
  font-size: 0.72rem;
  min-height: 1.95em;
}

.home-product-grid :deep(.product-card-mobile-pricing strong) {
  font-size: 0.88rem;
}

.home-product-grid :deep(.product-card-mobile-add) {
  min-height: 36px;
  font-size: 0.74rem;
}

.home-promo-card:nth-child(1) {
  background:
    radial-gradient(circle at top right, rgba(118, 184, 255, 0.12), transparent 28%),
    linear-gradient(180deg, rgba(38, 45, 66, 0.98), rgba(19, 23, 35, 0.98));
}

.home-promo-card:nth-child(2) {
  background:
    radial-gradient(circle at top right, rgba(255, 154, 90, 0.12), transparent 28%),
    linear-gradient(180deg, rgba(70, 40, 26, 0.98), rgba(38, 20, 12, 0.98));
}

.home-promo-card ion-icon {
  font-size: 1rem;
  color: rgba(255, 176, 122, 0.92);
}

.home-promo-card strong {
  font-size: 1.12rem;
  line-height: 1.05;
}

.home-promo-card span {
  font-size: 0.76rem;
  line-height: 1.35;
  color: rgba(232, 236, 244, 0.72);
}

.recent-product-rail {
  padding-bottom: 4px;
}

.recent-product-rail-card {
  flex: 0 0 min(74vw, 244px);
}

.section-head h2 {
  font-size: 1.05rem;
}

.sr-only {
  position: absolute;
  width: 1px;
  height: 1px;
  padding: 0;
  margin: -1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  border: 0;
}

body[data-theme="dark"] .home-search-shell {
  border-color: rgba(255, 255, 255, 0.12);
  background:
    linear-gradient(180deg, rgba(18, 18, 20, 0.62), rgba(10, 10, 12, 0.34)),
    radial-gradient(circle at 8% 0%, rgba(255, 255, 255, 0.08), transparent 30%);
}

body[data-theme="dark"] .home-search-actions {
  color: var(--trego-text);
}

body[data-theme="dark"] .home-search-clear {
  background: rgba(255, 255, 255, 0.1);
  box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.12);
}

</style>
