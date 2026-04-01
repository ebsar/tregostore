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
  cameraOutline,
  cameraSharp,
  chatbubbleEllipsesOutline,
  flashOutline,
  heartOutline,
  imagesOutline,
  logInOutline,
  micOutline,
  personAddOutline,
  personCircleOutline,
  pricetagOutline,
  pulseOutline,
  receiptOutline,
  searchOutline,
  storefrontOutline,
} from "ionicons/icons";
import { computed, onBeforeUnmount, onMounted, ref, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import EmptyStatePanel from "../components/EmptyStatePanel.vue";
import ProductCardMobile from "../components/ProductCardMobile.vue";
import { addToCart, fetchMarketplaceProducts, openSupportConversation, searchProductsByImage, toggleWishlist } from "../lib/api";
import { readRecentlyViewedProducts } from "../lib/recentlyViewed";
import { readMobileRecentSearches } from "../lib/searchHistory";
import type { ProductItem } from "../types/models";
import { ensureSession, isBusinessUser, refreshCounts, sessionState } from "../stores/session";

const router = useRouter();
const route = useRoute();
const loading = ref(true);
const searchQuery = ref("");
const homeSearchCollapsed = ref(false);
const voiceListening = ref(false);
const cameraSheetOpen = ref(false);
const uploadInputRef = ref<HTMLInputElement | null>(null);
const cameraInputRef = ref<HTMLInputElement | null>(null);
const products = ref<ProductItem[]>([]);
const imageSearchResults = ref<ProductItem[]>([]);

const recommendedProducts = computed(() => {
  const recentTerms = readMobileRecentSearches().map((item) => item.toLowerCase());
  const recentViewedIds = new Set(readRecentlyViewedProducts().map((item) => Number(item.id || 0)));
  return products.value
    .filter((product) => {
      const title = String(product.title || "").toLowerCase();
      const category = String(product.category || "").toLowerCase();
      return recentViewedIds.has(Number(product.id || 0)) || recentTerms.some((term) => title.includes(term) || category.includes(term));
    })
    .slice(0, 8);
});

const discountProducts = computed(() =>
  products.value
    .filter((product) => Number(product.compareAtPrice || 0) > Number(product.price || 0))
    .slice(0, 8),
);

const trendingProducts = computed(() =>
  [...products.value]
    .sort((left, right) => {
      const leftScore = Number(left.viewsCount || 0) + Number(left.wishlistCount || 0) * 2 + Number(left.shareCount || 0) * 3;
      const rightScore = Number(right.viewsCount || 0) + Number(right.wishlistCount || 0) * 2 + Number(right.shareCount || 0) * 3;
      return rightScore - leftScore;
    })
    .slice(0, 8),
);

const primaryProducts = computed(() => (imageSearchResults.value.length ? imageSearchResults.value : products.value.slice(0, 10)));
const promoCards = computed(() => [
  {
    key: "discounts",
    title: "Zbritje",
    subtitle: "Oferta qe levizin shpejt",
    icon: pricetagOutline,
  },
  {
    key: "trending",
    title: "Trending",
    subtitle: "Produktet me interesim",
    icon: pulseOutline,
  },
  {
    key: "sales",
    title: "Sales",
    subtitle: "Cmimet me te mira",
    icon: flashOutline,
  },
]);
const homeShortcutItems = computed(() => {
  if (!sessionState.user) {
    return [
      { key: "login", label: "Login", meta: "Kyçu", icon: logInOutline, route: "/login?redirect=/tabs/home" },
      { key: "signup", label: "Sign up", meta: "Llogari e re", icon: personAddOutline, route: "/signup" },
      { key: "support", label: "Support", meta: "Ndihmë", icon: chatbubbleEllipsesOutline, action: "support" },
      { key: "search", label: "Kerko", meta: "Katalogu", icon: searchOutline, action: "search" },
    ];
  }

  if (isBusinessUser.value) {
    return [
      { key: "studio", label: "Biznesi", meta: "Studio", icon: storefrontOutline, route: "/business/studio" },
      { key: "orders", label: "Porosite", meta: "Menaxho", icon: receiptOutline, route: "/orders" },
      { key: "messages", label: "Mesazhet", meta: "Inbox", icon: chatbubbleEllipsesOutline, route: "/messages" },
      { key: "account", label: "Llogaria", meta: "Profili", icon: personCircleOutline, route: "/tabs/account" },
    ];
  }

  return [
    { key: "orders", label: "Porosite", meta: "Statusi", icon: receiptOutline, route: "/orders" },
    { key: "wishlist", label: "Wishlist", meta: "Ruajtur", icon: heartOutline, route: "/tabs/wishlist" },
    { key: "messages", label: "Mesazhet", meta: "Bisedat", icon: chatbubbleEllipsesOutline, route: "/messages" },
    { key: "account", label: "Llogaria", meta: "Profili", icon: personCircleOutline, route: "/tabs/account" },
  ];
});

function syncSearchQueryFromRoute() {
  const next = String(route.query.q || "").trim();
  if (next && next !== searchQuery.value) {
    searchQuery.value = next;
  }
}

function handleHomeScroll(event: CustomEvent<{ scrollTop?: number }>) {
  const scrollTop = Number(event?.detail?.scrollTop || 0);
  homeSearchCollapsed.value = scrollTop > 72;
}

onMounted(async () => {
  syncSearchQueryFromRoute();
  await ensureSession();
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

async function openSupport() {
  await ensureSession();
  if (!sessionState.user) {
    router.push("/login?redirect=/messages");
    return;
  }

  const { response, data } = await openSupportConversation();
  if (!response.ok || !data?.ok || !data?.conversation?.id) {
    return;
  }

  await refreshCounts();
  router.push(`/messages/${data.conversation.id}`);
}

async function handleHomeShortcut(item: { route?: string; action?: string }) {
  if (item.route) {
    router.push(item.route);
    return;
  }

  if (item.action === "search") {
    openSearch();
    return;
  }

  if (item.action === "support") {
    await openSupport();
  }
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
    <IonContent class="app-gradient" :fullscreen="true" :scroll-events="true" @ionScroll="handleHomeScroll">
      <div class="mobile-page mobile-page--tabbed mobile-page--edge mobile-page--home">
        <section class="home-search-hero" :class="{ 'is-collapsed': homeSearchCollapsed }">
          <button v-if="homeSearchCollapsed" class="home-search-mini-button" type="button" @click="openSearch">
            <IonIcon :icon="searchOutline" />
          </button>

          <div v-else class="home-search-shell">
            <button class="home-search-camera" type="button" @click="cameraSheetOpen = true">
              <IonIcon :icon="cameraOutline" />
            </button>
            <IonIcon class="home-search-leading" :icon="searchOutline" />
            <IonInput
              v-model="searchQuery"
              class="home-search-input"
              placeholder="Smart search"
              clear-input
              @keydown.enter.prevent="openSearch"
            />
            <button
              class="home-search-voice"
              :class="{ active: voiceListening }"
              type="button"
              @click="startVoiceSearch"
            >
              <IonIcon :icon="micOutline" />
            </button>
          </div>
        </section>

        <section class="home-quick-access" aria-label="Veprime te shpejta">
          <button
            v-for="item in homeShortcutItems"
            :key="item.key"
            class="home-quick-access-card"
            type="button"
            @click="handleHomeShortcut(item)"
          >
            <IonIcon :icon="item.icon" />
            <div class="home-quick-access-copy">
              <strong>{{ item.label }}</strong>
              <span>{{ item.meta }}</span>
            </div>
          </button>
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

        <section v-if="discountProducts.length" class="stack-list">
          <div class="section-head">
            <h2>Zbritje</h2>
          </div>
          <div class="product-grid home-product-grid">
            <ProductCardMobile
              v-for="product in discountProducts"
              :key="`discount-${product.id}`"
              :product="product"
              @open="(id) => router.push(`/product/${id}`)"
              @cart="handleAddToCart"
              @wishlist="handleWishlist"
            />
          </div>
        </section>

        <section v-if="trendingProducts.length" class="stack-list">
          <div class="section-head">
            <h2>Trending</h2>
          </div>
          <div class="product-grid home-product-grid">
            <ProductCardMobile
              v-for="product in trendingProducts"
              :key="`trend-${product.id}`"
              :product="product"
              @open="(id) => router.push(`/product/${id}`)"
              @cart="handleAddToCart"
              @wishlist="handleWishlist"
            />
          </div>
        </section>

        <section v-if="recommendedProducts.length" class="stack-list">
          <div class="section-head">
            <h2>Per ty</h2>
          </div>
          <div class="product-grid home-product-grid">
            <ProductCardMobile
              v-for="product in recommendedProducts"
              :key="`recommended-${product.id}`"
              :product="product"
              @open="(id) => router.push(`/product/${id}`)"
              @cart="handleAddToCart"
              @wishlist="handleWishlist"
            />
          </div>
        </section>

        <section class="stack-list">
          <div class="section-head">
            <h2>{{ imageSearchResults.length ? "Camera results" : "Produktet" }}</h2>
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
  gap: 12px;
}

.home-search-hero {
  position: sticky;
  top: calc(env(safe-area-inset-top, 0px) + 6px);
  z-index: 22;
  padding-top: 2px;
}

.home-search-hero.is-collapsed {
  display: flex;
  justify-content: flex-end;
}

.home-search-shell {
  display: grid;
  grid-template-columns: auto 20px minmax(0, 1fr) auto;
  align-items: center;
  gap: 10px;
  min-height: 68px;
  padding: 0 14px;
  border-radius: 999px;
  border: 1px solid rgba(255, 255, 255, 0.72);
  background:
    linear-gradient(180deg, rgba(255, 255, 255, 0.32), rgba(255, 255, 255, 0.12)),
    radial-gradient(circle at 8% 0%, rgba(255, 255, 255, 0.44), transparent 30%);
  box-shadow:
    0 20px 48px rgba(31, 41, 55, 0.1),
    inset 0 1px 0 rgba(255, 255, 255, 0.82),
    inset 0 -20px 30px rgba(255, 255, 255, 0.05);
  backdrop-filter: blur(26px) saturate(175%);
  -webkit-backdrop-filter: blur(26px) saturate(175%);
}

.home-search-mini-button {
  display: inline-flex;
  width: 58px;
  height: 58px;
  align-items: center;
  justify-content: center;
  margin-left: auto;
  border: 1px solid rgba(255, 255, 255, 0.72);
  border-radius: 999px;
  background:
    linear-gradient(180deg, rgba(255, 255, 255, 0.34), rgba(255, 255, 255, 0.12)),
    radial-gradient(circle at 18% 0%, rgba(255, 255, 255, 0.42), transparent 28%);
  box-shadow:
    0 16px 34px rgba(31, 41, 55, 0.1),
    inset 0 1px 0 rgba(255, 255, 255, 0.88),
    inset 0 -16px 22px rgba(255, 255, 255, 0.05);
  backdrop-filter: blur(26px) saturate(185%);
  -webkit-backdrop-filter: blur(26px) saturate(185%);
  color: var(--trego-dark);
}

.home-search-mini-button ion-icon {
  font-size: 1.22rem;
}

.home-search-camera,
.home-search-voice {
  display: inline-flex;
  width: 54px;
  height: 54px;
  align-items: center;
  justify-content: center;
  border: 0;
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.24);
  color: var(--trego-dark);
}

.home-search-camera ion-icon,
.home-search-voice ion-icon {
  font-size: 1.46rem;
}

.home-search-voice.active {
  background: rgba(255, 106, 43, 0.14);
  color: var(--trego-accent);
}

.home-search-leading {
  color: rgba(47, 52, 70, 0.74);
  font-size: 1.14rem;
}

.home-search-input {
  --padding-start: 0;
  --padding-end: 0;
  --placeholder-color: rgba(47, 52, 70, 0.6);
  color: var(--trego-dark);
  font-size: 1rem;
  font-weight: 700;
}

.home-promo-rail {
  display: flex;
  gap: 12px;
  overflow-x: auto;
  padding-bottom: 2px;
  scrollbar-width: none;
}

.home-quick-access {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 10px;
}

.home-quick-access-card {
  display: grid;
  justify-items: start;
  gap: 10px;
  min-height: 86px;
  padding: 14px 12px;
  border: 1px solid var(--trego-border);
  border-radius: 22px;
  background: var(--trego-surface);
  color: var(--trego-dark);
  text-align: left;
  box-shadow: var(--trego-shadow-soft);
}

.home-quick-access-card ion-icon {
  font-size: 1.22rem;
  color: var(--trego-accent);
}

.home-quick-access-copy {
  display: grid;
  gap: 2px;
}

.home-quick-access-copy strong {
  font-size: 0.8rem;
  line-height: 1.1;
}

.home-quick-access-copy span {
  color: var(--trego-muted);
  font-size: 0.7rem;
  line-height: 1.35;
}

.home-promo-rail::-webkit-scrollbar {
  display: none;
}

.home-promo-card {
  flex: 0 0 min(72vw, 240px);
  display: grid;
  gap: 8px;
  min-height: 112px;
  padding: 18px;
  border-radius: 26px;
  background:
    linear-gradient(135deg, rgba(255, 106, 43, 0.96), rgba(255, 138, 64, 0.82)),
    radial-gradient(circle at 100% 0%, rgba(255, 255, 255, 0.22), transparent 26%);
  color: #ffffff;
  box-shadow: 0 18px 36px rgba(255, 106, 43, 0.2);
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

.home-promo-card:nth-child(2) {
  background:
    linear-gradient(135deg, rgba(47, 52, 70, 0.96), rgba(69, 76, 99, 0.86)),
    radial-gradient(circle at 100% 0%, rgba(255, 255, 255, 0.18), transparent 26%);
  box-shadow: 0 18px 36px rgba(47, 52, 70, 0.18);
}

.home-promo-card:nth-child(3) {
  background:
    linear-gradient(135deg, rgba(255, 123, 0, 0.96), rgba(255, 173, 64, 0.86)),
    radial-gradient(circle at 100% 0%, rgba(255, 255, 255, 0.22), transparent 26%);
}

.home-promo-card ion-icon {
  font-size: 1.2rem;
}

.home-promo-card strong {
  font-size: 1.3rem;
  line-height: 1;
}

.home-promo-card span {
  font-size: 0.82rem;
  line-height: 1.35;
  color: rgba(255, 255, 255, 0.88);
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

@media (max-width: 620px) {
  .home-quick-access {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

body[data-theme="dark"] .home-search-shell {
  border-color: rgba(255, 255, 255, 0.12);
  background:
    linear-gradient(180deg, rgba(18, 18, 20, 0.54), rgba(10, 10, 12, 0.28)),
    radial-gradient(circle at 8% 0%, rgba(255, 255, 255, 0.08), transparent 30%);
}

body[data-theme="dark"] .home-search-mini-button {
  border-color: rgba(255, 255, 255, 0.12);
  background:
    linear-gradient(180deg, rgba(18, 18, 20, 0.76), rgba(10, 10, 12, 0.44)),
    radial-gradient(circle at 18% 0%, rgba(255, 255, 255, 0.08), transparent 28%);
  color: var(--trego-text);
}

body[data-theme="dark"] .home-search-camera,
body[data-theme="dark"] .home-search-voice {
  background: rgba(255, 255, 255, 0.08);
  color: var(--trego-text);
}
</style>
