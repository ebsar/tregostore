<script setup lang="ts">
import {
  IonActionSheet,
  IonContent,
  IonIcon,
  IonInfiniteScroll,
  IonInfiniteScrollContent,
  IonInput,
  IonPage,
  IonRefresher,
  IonRefresherContent,
} from "@ionic/vue";
import { cameraOutline, cameraSharp, closeOutline, imagesOutline, micOutline } from "ionicons/icons";
import { computed, onMounted, ref, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import EmptyStatePanel from "../components/EmptyStatePanel.vue";
import ProductCardMobile from "../components/ProductCardMobile.vue";
import ProductCardSkeleton from "../components/ProductCardSkeleton.vue";
import {
  addToCart,
  fetchMarketplaceProductsPage,
  searchMarketplaceProductsPage,
  searchProductsByImage,
  toggleWishlist,
} from "../lib/api";
import { readRecentlyViewedProducts } from "../lib/recentlyViewed";
import { pushMobileRecentSearch } from "../lib/searchHistory";
import type { ProductItem } from "../types/models";
import { refreshCounts } from "../stores/session";

type SearchMode = "discover" | "query" | "visual";

const PAGE_SIZE = 18;
const router = useRouter();
const route = useRoute();
const query = ref("");
const loading = ref(false);
const loadingMore = ref(false);
const hasMore = ref(false);
const nextOffset = ref(0);
const mode = ref<SearchMode>("discover");
const products = ref<ProductItem[]>([]);
const historyProducts = ref<ProductItem[]>([]);
const voiceListening = ref(false);
const cameraSheetOpen = ref(false);
const uploadInputRef = ref<HTMLInputElement | null>(null);
const cameraInputRef = ref<HTMLInputElement | null>(null);
let searchTimeout = 0;
let activeSearchRequest = 0;

const visibleProducts = computed(() => (mode.value === "discover" ? historyProducts.value : products.value));

function mergeUniqueProducts(existing: ProductItem[], incoming: ProductItem[]) {
  const merged = [...existing];
  for (const nextItem of incoming) {
    const nextId = Number(nextItem?.id || 0);
    if (nextId <= 0 || merged.some((item) => Number(item?.id || 0) === nextId)) {
      continue;
    }
    merged.push(nextItem);
  }
  return merged;
}

function buildDiscoveryProducts(pageProducts: ProductItem[], existing: ProductItem[] = []) {
  return mergeUniqueProducts(
    existing,
    [...readRecentlyViewedProducts(), ...pageProducts],
  );
}

async function loadSeedProducts(reset = true) {
  if (reset) {
    loading.value = true;
  } else {
    loadingMore.value = true;
  }

  try {
    const page = await fetchMarketplaceProductsPage(PAGE_SIZE, reset ? 0 : nextOffset.value);
    mode.value = "discover";
    historyProducts.value = reset
      ? buildDiscoveryProducts(page.items)
      : buildDiscoveryProducts(page.items, historyProducts.value);
    nextOffset.value = page.offset + page.items.length;
    hasMore.value = page.hasMore;
    if (reset) {
      products.value = [];
    }
  } finally {
    if (reset) {
      loading.value = false;
    } else {
      loadingMore.value = false;
    }
  }
}

async function runSearch(nextQuery: string, append = false) {
  const normalized = nextQuery.trim();
  const requestId = ++activeSearchRequest;
  if (append) {
    loadingMore.value = true;
  } else {
    loading.value = true;
  }

  try {
    if (!normalized) {
      router.replace({ path: "/tabs/search", query: {} });
      products.value = [];
      nextOffset.value = 0;
      hasMore.value = false;
      await loadSeedProducts(true);
      return;
    }

    const page = await searchMarketplaceProductsPage(
      normalized,
      PAGE_SIZE,
      append ? nextOffset.value : 0,
    );

    if (requestId !== activeSearchRequest) {
      return;
    }

    mode.value = "query";
    products.value = append
      ? mergeUniqueProducts(products.value, page.items)
      : page.items;
    nextOffset.value = page.offset + page.items.length;
    hasMore.value = page.hasMore;
    if (!append) {
      pushMobileRecentSearch(normalized);
      router.replace({ path: "/tabs/search", query: { q: normalized } });
    }
  } finally {
    if (append) {
      loadingMore.value = false;
    } else {
      loading.value = false;
    }
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
    await loadSeedProducts(true);
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
  await (mode.value === "query" ? runSearch(query.value) : loadSeedProducts(true))
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
      mode.value = "visual";
      products.value = result.products;
      query.value = "";
      nextOffset.value = result.products.length;
      hasMore.value = false;
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

async function handleLoadMore(event: CustomEvent) {
  const infinite = event.target as HTMLIonInfiniteScrollElement & { complete: () => void; disabled: boolean };
  if (!hasMore.value || loadingMore.value) {
    infinite.complete();
    return;
  }

  if (mode.value === "query" && query.value.trim()) {
    await runSearch(query.value, true);
  } else if (mode.value === "discover") {
    await loadSeedProducts(false);
  } else {
    hasMore.value = false;
  }

  infinite.complete();
  if (!hasMore.value) {
    infinite.disabled = true;
  }
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
          <div v-if="loading" class="product-grid">
            <ProductCardSkeleton v-for="index in 6" :key="index" />
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

          <IonInfiniteScroll
            v-if="!loading && hasMore"
            threshold="160px"
            @ionInfinite="handleLoadMore"
          >
            <IonInfiniteScrollContent
              loading-spinner="crescent"
              loading-text="Po ngarkohen produkte te tjera..."
            />
          </IonInfiniteScroll>
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
