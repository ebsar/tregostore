<script setup lang="ts">
import {
  IonActionSheet,
  IonButton,
  IonContent,
  IonIcon,
  IonInput,
  IonPage,
  IonRefresher,
  IonRefresherContent,
  IonSpinner,
} from "@ionic/vue";
import { cameraOutline, cameraSharp, filterOutline, imagesOutline, micOutline, searchOutline } from "ionicons/icons";
import { computed, onMounted, ref, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import EmptyStatePanel from "../components/EmptyStatePanel.vue";
import ProductCardMobile from "../components/ProductCardMobile.vue";
import { addToCart, fetchMarketplaceProducts, searchMarketplaceProducts, searchProductsByImage, toggleWishlist } from "../lib/api";
import { readRecentlyViewedProducts } from "../lib/recentlyViewed";
import { pushMobileRecentSearch, readMobileRecentSearches, writeMobileRecentSearches } from "../lib/searchHistory";
import type { ProductItem } from "../types/models";
import { refreshCounts } from "../stores/session";

const router = useRouter();
const route = useRoute();
const query = ref("");
const loading = ref(false);
const products = ref<ProductItem[]>([]);
const historyProducts = ref<ProductItem[]>([]);
const recentSearches = ref<string[]>([]);
const visualSearchFileName = ref("");
const visualSearchPreviewUrl = ref("");
const selectedCategory = ref("");
const filterMenuOpen = ref(false);
const voiceListening = ref(false);
const cameraSheetOpen = ref(false);
const uploadInputRef = ref<HTMLInputElement | null>(null);
const cameraInputRef = ref<HTMLInputElement | null>(null);
let searchTimeout = 0;

const currentPool = computed(() => (query.value.trim() ? products.value : historyProducts.value));
const categories = computed(() =>
  [...new Set(currentPool.value.map((product) => String(product.category || "").trim()).filter(Boolean))].slice(0, 6),
);
const visibleProducts = computed(() =>
  selectedCategory.value
    ? currentPool.value.filter((product) => String(product.category || "").trim() === selectedCategory.value)
    : currentPool.value,
);

function selectCategory(value: string) {
  selectedCategory.value = value;
  filterMenuOpen.value = false;
}

async function loadSeedProducts() {
  loading.value = true;
  try {
    const defaultProducts = await fetchMarketplaceProducts(18, 0);
    const recent = readMobileRecentSearches();
    recentSearches.value = recent;

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
  selectedCategory.value = "";
  loading.value = true;
  try {
    if (!normalized) {
      router.replace({ path: "/tabs/search", query: {} });
      products.value = [];
      await loadSeedProducts();
      return;
    }

    products.value = await searchMarketplaceProducts(normalized);
    recentSearches.value = pushMobileRecentSearch(normalized);
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

  visualSearchFileName.value = file.name;
  visualSearchPreviewUrl.value = URL.createObjectURL(file);
  loading.value = true;
  try {
    const result = await searchProductsByImage(file, { limit: 16, includeFacets: 1 });
    if (result.ok) {
      products.value = result.products;
      query.value = "";
      selectedCategory.value = "";
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
      recentSearches.value = pushMobileRecentSearch(transcript);
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

function clearRecentSearches() {
  recentSearches.value = writeMobileRecentSearches([]);
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
          <div class="smart-search-badge">SMART SEARCH</div>

          <form class="smart-search-shell" @submit.prevent="runSearch(query)">
            <button class="smart-search-camera" type="button" @click="cameraSheetOpen = true">
              <IonIcon :icon="cameraOutline" />
            </button>

            <IonIcon class="smart-search-leading" :icon="searchOutline" />
            <IonInput
              v-model="query"
              class="smart-search-input"
              placeholder="AI search ose kerko produktin..."
              clear-input
            />

            <button
              class="smart-search-voice"
              :class="{ active: voiceListening }"
              type="button"
              @click="startVoiceSearch"
            >
              <IonIcon :icon="micOutline" />
            </button>
          </form>

          <div v-if="recentSearches.length" class="smart-search-history">
            <button
              v-for="item in recentSearches.slice(0, 4)"
              :key="item"
              class="smart-history-chip"
              type="button"
              @click="query = item"
            >
              {{ item }}
            </button>
            <button class="smart-history-link" type="button" @click="clearRecentSearches">
              Pastro
            </button>
          </div>

          <div v-if="visualSearchFileName" class="visual-search-inline">
            <img v-if="visualSearchPreviewUrl" :src="visualSearchPreviewUrl" :alt="visualSearchFileName" class="visual-search-thumb" />
            <span>{{ visualSearchFileName }}</span>
          </div>
        </section>

        <div class="search-filter-wrap">
          <button class="search-filter-toggle" type="button" @click="filterMenuOpen = !filterMenuOpen">
            <IonIcon :icon="filterOutline" />
            Filtro
          </button>

          <transition name="sheet-fade">
            <section v-if="filterMenuOpen && categories.length" class="search-filter-dropdown">
              <div class="search-filter-dropdown-head">
                <strong>Kategorite</strong>
                <small>Zgjidh filtër të shpejtë</small>
              </div>

              <div class="chip-row">
                <button class="chip" :class="{ 'chip--active': !selectedCategory }" type="button" @click="selectCategory('')">
                  Te gjitha
                </button>
                <button
                  v-for="item in categories"
                  :key="item"
                  class="chip"
                  :class="{ 'chip--active': selectedCategory === item }"
                  type="button"
                  @click="selectCategory(selectedCategory === item ? '' : item)"
                >
                  {{ item }}
                </button>
              </div>
            </section>
          </transition>
        </div>

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
  padding: 14px;
  border-radius: 28px;
  border: 1px solid rgba(255, 255, 255, 0.72);
  background:
    linear-gradient(180deg, rgba(255, 255, 255, 0.28), rgba(255, 255, 255, 0.12)),
    radial-gradient(circle at 14% 0%, rgba(255, 255, 255, 0.46), transparent 32%),
    radial-gradient(circle at 100% 0%, rgba(255, 255, 255, 0.22), transparent 28%);
  box-shadow:
    0 20px 50px rgba(31, 41, 55, 0.12),
    inset 0 1px 0 rgba(255, 255, 255, 0.78),
    inset 0 -18px 26px rgba(255, 255, 255, 0.06);
  backdrop-filter: blur(24px) saturate(160%);
  -webkit-backdrop-filter: blur(24px) saturate(160%);
}

.smart-search-badge {
  display: inline-flex;
  min-height: 28px;
  align-items: center;
  padding: 0 12px;
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.22);
  color: rgba(31, 41, 55, 0.84);
  font-size: 0.68rem;
  font-weight: 900;
  letter-spacing: 0.14em;
}

.smart-search-shell {
  display: grid;
  grid-template-columns: auto 20px minmax(0, 1fr) auto;
  align-items: center;
  gap: 10px;
  min-height: 68px;
  margin-top: 12px;
  padding: 0 14px 0 12px;
  border-radius: 999px;
  border: 1px solid rgba(255, 255, 255, 0.68);
  background:
    linear-gradient(180deg, rgba(255, 255, 255, 0.28), rgba(255, 255, 255, 0.08)),
    radial-gradient(circle at 0% 50%, rgba(255, 255, 255, 0.3), transparent 22%);
  box-shadow:
    inset 0 1px 0 rgba(255, 255, 255, 0.78),
    0 14px 34px rgba(31, 41, 55, 0.08);
  backdrop-filter: blur(26px) saturate(180%);
  -webkit-backdrop-filter: blur(26px) saturate(180%);
}

.smart-search-camera,
.smart-search-voice {
  display: inline-flex;
  width: 56px;
  height: 56px;
  align-items: center;
  justify-content: center;
  border: 0;
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.26);
  color: var(--trego-dark);
}

.smart-search-camera ion-icon,
.smart-search-voice ion-icon {
  font-size: 1.48rem;
}

.smart-search-voice.active {
  color: var(--trego-accent);
  background: rgba(255, 106, 43, 0.14);
}

.smart-search-leading {
  color: rgba(47, 52, 70, 0.74);
  font-size: 1.08rem;
}

.smart-search-input {
  --padding-start: 0;
  --padding-end: 0;
  --placeholder-color: rgba(47, 52, 70, 0.58);
  color: var(--trego-dark);
  font-size: 1rem;
  font-weight: 700;
}

.smart-search-history {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-top: 12px;
}

.smart-history-chip,
.smart-history-link {
  border: 0;
  border-radius: 999px;
  min-height: 32px;
  padding: 0 12px;
  background: rgba(255, 255, 255, 0.22);
  color: var(--trego-dark);
  font-size: 0.74rem;
  font-weight: 700;
}

.smart-history-link {
  background: transparent;
  color: var(--trego-muted);
}

.visual-search-inline {
  display: inline-flex;
  align-items: center;
  gap: 10px;
  margin-top: 12px;
  padding: 8px 10px;
  border-radius: 18px;
  background: rgba(255, 255, 255, 0.2);
  color: var(--trego-dark);
  font-size: 0.76rem;
  font-weight: 700;
}

.visual-search-thumb {
  width: 38px;
  height: 38px;
  object-fit: cover;
  border-radius: 12px;
}

.search-filter-toggle {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  width: fit-content;
  min-height: 40px;
  padding: 0 14px;
  border: 1px solid var(--trego-input-border);
  border-radius: 999px;
  background: var(--trego-surface);
  color: var(--trego-dark);
  font-size: 0.76rem;
  font-weight: 800;
  box-shadow: var(--trego-shadow-soft);
}

.search-filter-wrap {
  position: relative;
  z-index: 4;
}

.search-filter-dropdown {
  position: absolute;
  top: calc(100% + 10px);
  left: 0;
  width: min(320px, calc(100vw - 20px));
  padding: 14px;
  border-radius: 24px;
  border: 1px solid rgba(255, 255, 255, 0.72);
  background:
    linear-gradient(180deg, rgba(255, 255, 255, 0.34), rgba(255, 255, 255, 0.12)),
    radial-gradient(circle at 14% 0%, rgba(255, 255, 255, 0.42), transparent 32%),
    radial-gradient(circle at 100% 0%, rgba(255, 255, 255, 0.24), transparent 28%);
  box-shadow:
    0 18px 40px rgba(31, 41, 55, 0.12),
    inset 0 1px 0 rgba(255, 255, 255, 0.82),
    inset 0 -16px 24px rgba(255, 255, 255, 0.05);
  backdrop-filter: blur(26px) saturate(185%);
  -webkit-backdrop-filter: blur(26px) saturate(185%);
}

.search-filter-dropdown-head {
  display: grid;
  gap: 2px;
  margin-bottom: 12px;
}

.search-filter-dropdown-head strong {
  color: var(--trego-dark);
  font-size: 0.84rem;
  font-weight: 800;
}

.search-filter-dropdown-head small {
  color: var(--trego-muted);
  font-size: 0.72rem;
}

.chip--active {
  background: rgba(255, 106, 43, 0.16);
  border-color: rgba(255, 106, 43, 0.28);
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
    linear-gradient(180deg, rgba(16, 16, 18, 0.54), rgba(8, 8, 10, 0.28)),
    radial-gradient(circle at 0% 50%, rgba(255, 255, 255, 0.05), transparent 20%);
}

body[data-theme="dark"] .search-filter-dropdown {
  border-color: rgba(255, 255, 255, 0.12);
  background:
    linear-gradient(180deg, rgba(18, 18, 20, 0.76), rgba(10, 10, 12, 0.46)),
    radial-gradient(circle at 14% 0%, rgba(255, 255, 255, 0.08), transparent 32%);
}

body[data-theme="dark"] .smart-search-camera,
body[data-theme="dark"] .smart-search-voice,
body[data-theme="dark"] .smart-history-chip,
body[data-theme="dark"] .visual-search-inline {
  background: rgba(255, 255, 255, 0.08);
  color: var(--trego-text);
}
</style>
