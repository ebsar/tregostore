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
    <IonContent :fullscreen="true">
      <IonRefresher slot="fixed" @ionRefresh="handleRefresh">
        <IonRefresherContent />
      </IonRefresher>

      <div>
        <section>
          <form @submit.prevent="runSearch(query)">
            <IonInput
              v-model="query"
             
              placeholder="Search"
            />
            <div>
              <button
                v-if="query.trim()"
               
                type="button"
                @click="query = ''"
              >
                <IonIcon :icon="closeOutline" />
              </button>

              <button type="button" @click="cameraSheetOpen = true">
                <IonIcon :icon="cameraOutline" />
              </button>

              <button
               
               
                type="button"
                @click="startVoiceSearch"
              >
                <IonIcon :icon="micOutline" />
              </button>
            </div>
          </form>
        </section>

        <section>
          <div v-if="loading">
            <ProductCardSkeleton v-for="index in 6" :key="index" />
          </div>

          <div v-else-if="visibleProducts.length">
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
         
          type="file"
          accept="image/*"
          capture="environment"
          @change="handleVisualSearch"
        >
        <input
          ref="uploadInputRef"
         
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

