<script setup lang="ts">
import {
  IonActionSheet,
  IonContent,
  IonIcon,
  IonInput,
  IonPage,
  IonRefresher,
  IonRefresherContent,
  IonSpinner,
} from "@ionic/vue";
import { cameraOutline, cameraSharp, closeOutline, imagesOutline, micOutline } from "ionicons/icons";
import { computed, onMounted, ref, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import EmptyStatePanel from "../components/EmptyStatePanel.vue";
import ProductCardMobile from "../components/ProductCardMobile.vue";
import { addToCart, fetchMarketplaceProducts, searchMarketplaceProducts, searchProductsByImage, toggleWishlist } from "../lib/api";
import { readRecentlyViewedProducts } from "../lib/recentlyViewed";
import { pushMobileRecentSearch, readMobileRecentSearches } from "../lib/searchHistory";
import type { ProductItem } from "../types/models";
import { refreshCounts } from "../stores/session";

const router = useRouter();
const route = useRoute();
const query = ref("");
const loading = ref(false);
const products = ref<ProductItem[]>([]);
const historyProducts = ref<ProductItem[]>([]);
const voiceListening = ref(false);
const cameraSheetOpen = ref(false);
const uploadInputRef = ref<HTMLInputElement | null>(null);
const cameraInputRef = ref<HTMLInputElement | null>(null);
let searchTimeout = 0;

const visibleProducts = computed(() => (query.value.trim() ? products.value : historyProducts.value));

async function loadSeedProducts() {
  loading.value = true;
  try {
    const defaultProducts = await fetchMarketplaceProducts(18, 0);
    const recent = readMobileRecentSearches();

    const seeded = recent[0]
      ? await searchMarketplaceProducts(recent[0]).catch(() => [])
      : [];

    const merged = [
      ...seeded,
      ...readRecentlyViewedProducts(),
      ...defaultProducts,
    ].filter((product, index, list) => {
      const id = Number(product?.id || 0);
      return id > 0 && list.findIndex((item) => Number(item?.id || 0) === id) === index;
    });

    historyProducts.value = merged.slice(0, 12);
    if (!query.value.trim()) {
      products.value = [];
    }
  } finally {
    loading.value = false;
  }
}

async function runSearch(nextQuery: string) {
  const normalized = nextQuery.trim();
  loading.value = true;
  try {
    if (!normalized) {
      router.replace({ path: "/tabs/search", query: {} });
      products.value = [];
      await loadSeedProducts();
      return;
    }

    products.value = await searchMarketplaceProducts(normalized);
    pushMobileRecentSearch(normalized);
    router.replace({ path: "/tabs/search", query: { q: normalized } });
  } finally {
    loading.value = false;
  }
}

function queueSearch(value: string) {
  window.clearTimeout(searchTimeout);
  searchTimeout = window.setTimeout(() => {
    void runSearch(value);
  }, 260);
}

watch(query, (value) => {
  queueSearch(value);
});

watch(
  () => route.query.q,
  (value) => {
    const next = String(value || "").trim();
    if (next && next !== query.value) {
      query.value = next;
      return;
    }
    if (!next && query.value) {
      query.value = "";
    }
  },
  { immediate: true },
);

onMounted(async () => {
  if (!query.value.trim()) {
    await loadSeedProducts();
  }
});

async function handleAddToCart(productId: number) {
  await addToCart(productId, 1);
  await refreshCounts();
}

async function handleWishlist(productId: number) {
  await toggleWishlist(productId);
  await refreshCounts();
}

async function handleRefresh(event: CustomEvent) {
  await (query.value.trim() ? runSearch(query.value) : loadSeedProducts())
    .finally(() => {
      event.detail.complete();
    });
}

async function handleVisualSearch(event: Event) {
  const file = ((event.target as HTMLInputElement | null)?.files || [])[0];
  if (!file) {
    return;
  }

  loading.value = true;
  try {
    const result = await searchProductsByImage(file, { limit: 16, includeFacets: 1 });
    if (result.ok) {
      products.value = result.products;
      query.value = "";
      router.replace({ path: "/tabs/search", query: {} });
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
      query.value = transcript;
      pushMobileRecentSearch(transcript);
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
      <IonRefresher slot="fixed" @ionRefresh="handleRefresh">
        <IonRefresherContent />
      </IonRefresher>

      <div class="mobile-page mobile-page--tabbed mobile-page--edge mobile-page--search">
        <section class="smart-search-hero">
          <form class="smart-search-shell" @submit.prevent="runSearch(query)">
            <IonInput
              v-model="query"
              class="smart-search-input"
              placeholder="Search"
            />
            <div class="smart-search-actions">
              <button
                v-if="query.trim()"
                class="smart-search-clear"
                type="button"
                @click="query = ''"
              >
                <IonIcon :icon="closeOutline" />
              </button>

              <button class="smart-search-camera" type="button" @click="cameraSheetOpen = true">
                <IonIcon :icon="cameraOutline" />
              </button>

              <button
                class="smart-search-voice"
                :class="{ active: voiceListening }"
                type="button"
                @click="startVoiceSearch"
              >
                <IonIcon :icon="micOutline" />
              </button>
            </div>
          </form>
        </section>

        <section class="stack-list">
          <div v-if="loading" class="surface-card empty-panel">
            <IonSpinner name="crescent" />
          </div>

          <div v-else-if="visibleProducts.length" class="product-grid">
            <ProductCardMobile
              v-for="product in visibleProducts"
              :key="product.id"
              :product="product"
              @open="(id) => router.push(`/product/${id}`)"
              @cart="handleAddToCart"
              @wishlist="handleWishlist"
            />
          </div>

          <EmptyStatePanel
            v-else
            title="Asnje rezultat"
            copy="Provo nje kerkese tjeter ose perdor camera search."
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
.mobile-page--search {
  gap: 12px;
}

.smart-search-hero {
  position: relative;
}

.smart-search-shell {
  display: flex;
  align-items: center;
  gap: 12px;
  min-height: 58px;
  padding: 0 18px;
  border-radius: 999px;
  border: 1px solid rgba(255, 255, 255, 0.64);
  background:
    linear-gradient(180deg, rgba(255, 255, 255, 0.24), rgba(255, 255, 255, 0.1)),
    radial-gradient(circle at 0% 50%, rgba(255, 255, 255, 0.24), transparent 22%);
  box-shadow:
    inset 0 1px 0 rgba(255, 255, 255, 0.78),
    0 14px 30px rgba(31, 41, 55, 0.08);
  backdrop-filter: blur(24px) saturate(170%);
  -webkit-backdrop-filter: blur(24px) saturate(170%);
}

.smart-search-actions {
  display: flex;
  align-items: center;
  gap: 10px;
  color: rgba(47, 52, 70, 0.62);
}

.smart-search-clear,
.smart-search-camera,
.smart-search-voice {
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

.smart-search-clear {
  background: rgba(255, 255, 255, 0.7);
  box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.8);
}

.smart-search-clear ion-icon {
  font-size: 0.88rem;
}

.smart-search-camera ion-icon,
.smart-search-voice ion-icon {
  font-size: 1.08rem;
}

.smart-search-voice.active {
  color: var(--trego-accent);
}

.smart-search-input {
  flex: 1 1 auto;
  --padding-start: 0;
  --padding-end: 0;
  --placeholder-color: rgba(47, 52, 70, 0.5);
  color: var(--trego-dark);
  font-size: 1rem;
  font-weight: 700;
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

body[data-theme="dark"] .smart-search-hero {
  border-color: rgba(255, 255, 255, 0.12);
  background:
    linear-gradient(180deg, rgba(18, 18, 20, 0.52), rgba(10, 10, 12, 0.28)),
    radial-gradient(circle at 14% 0%, rgba(255, 255, 255, 0.08), transparent 32%);
}

body[data-theme="dark"] .smart-search-shell {
  border-color: rgba(255, 255, 255, 0.12);
  background:
    linear-gradient(180deg, rgba(16, 16, 18, 0.62), rgba(8, 8, 10, 0.34)),
    radial-gradient(circle at 0% 50%, rgba(255, 255, 255, 0.05), transparent 20%);
}

body[data-theme="dark"] .smart-search-actions {
  color: var(--trego-text);
}

body[data-theme="dark"] .smart-search-clear {
  background: rgba(255, 255, 255, 0.1);
  box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.12);
}
</style>
