<script setup lang="ts">
import {
  IonContent,
  IonIcon,
  IonInfiniteScroll,
  IonInfiniteScrollContent,
  IonPage,
} from "@ionic/vue";
import {
  arrowForwardOutline,
  chatbubbleEllipsesOutline,
  colorWandOutline,
  flameOutline,
  pricetagOutline,
  sparklesOutline,
} from "ionicons/icons";
import { computed, onMounted, ref, watch } from "vue";
import { useRouter } from "vue-router";
import EmptyStatePanel from "../components/EmptyStatePanel.vue";
import ProductCardMobile from "../components/ProductCardMobile.vue";
import ProductCardSkeleton from "../components/ProductCardSkeleton.vue";
import RailSkeleton from "../components/RailSkeleton.vue";
import {
  addToCart,
  fetchHomeRecommendations,
  fetchMarketplaceProductsPage,
  toggleWishlist,
} from "../lib/api";
import type { ProductItem, RecommendationSection } from "../types/models";
import { activityBadgeCount, ensureSession, refreshCounts } from "../stores/session";

type SpotlightKey = "all" | "recommended-for-you" | "new-arrivals" | "best-sellers";
const PAGE_SIZE = 24;
const spotlightOptions: Array<{ key: SpotlightKey; label: string }> = [
  { key: "all", label: "All" },
  { key: "recommended-for-you", label: "For You" },
  { key: "new-arrivals", label: "New" },
  { key: "best-sellers", label: "Best sellers" },
];

const router = useRouter();
const loading = ref(true);
const loadingMore = ref(false);
const hasMore = ref(false);
const nextOffset = ref(0);
const products = ref<ProductItem[]>([]);
const recommendationSections = ref<RecommendationSection[]>([]);
const selectedSpotlight = ref<SpotlightKey>("all");
const selectedCategory = ref("all");

const trendingProducts = computed(() =>
  [...products.value]
    .sort((left, right) => {
      const leftScore = Number(left.buyersCount || 0) * 2 + Number(left.viewsCount || 0) + Number(left.wishlistCount || 0);
      const rightScore = Number(right.buyersCount || 0) * 2 + Number(right.viewsCount || 0) + Number(right.wishlistCount || 0);
      return rightScore - leftScore;
    })
    .slice(0, 10),
);

const saleProducts = computed(() =>
  products.value
    .filter((product) => Number(product.compareAtPrice || 0) > Number(product.price || 0))
    .slice(0, 10),
);

const newArrivalProducts = computed(() =>
  [...products.value]
    .sort((left, right) => String(right.createdAt || "").localeCompare(String(left.createdAt || "")))
    .slice(0, 10),
);

const forYouProducts = computed(() =>
  [...products.value]
    .sort((left, right) => {
      const leftScore = Number(left.averageRating || 0) * 10 + Number(left.reviewCount || 0);
      const rightScore = Number(right.averageRating || 0) * 10 + Number(right.reviewCount || 0);
      return rightScore - leftScore;
    })
    .slice(0, 10),
);

const categories = computed(() => {
  const unique = new Set<string>();
  for (const product of products.value) {
    const next = String(product.category || product.productType || "").trim();
    if (next) {
      unique.add(next);
    }
  }
  return ["all", ...Array.from(unique).sort((left, right) => left.localeCompare(right))];
});

const heroStory = computed(() =>
  saleProducts.value[0]
  || trendingProducts.value[0]
  || forYouProducts.value[0]
  || products.value[0]
  || null,
);

const heroStats = computed(() => ([
  {
    label: "produkte",
    value: String(products.value.length || 0),
  },
  {
    label: "sales",
    value: String(saleProducts.value.length || 0),
  },
  {
    label: "kategori",
    value: String(Math.max(0, categories.value.length - 1)),
  },
]));

const homeMessageBadge = computed(() => {
  const total = Math.max(0, Number(activityBadgeCount.value || 0));
  if (total <= 0) {
    return "";
  }
  return total > 99 ? "99+" : String(total);
});

const railSections = computed(() => (
  recommendationSections.value.length
    ? recommendationSections.value.map((section) => ({
        key: section.key as SpotlightKey,
        title: section.title,
        subtitle: section.subtitle || "",
        icon:
          section.key === "new-arrivals"
            ? colorWandOutline
            : section.key === "best-sellers"
              ? flameOutline
              : sparklesOutline,
        tone:
          section.key === "new-arrivals"
            ? "sale"
            : section.key === "best-sellers"
              ? "trending"
              : "for-you",
        products: section.products,
      }))
    : [
        {
          key: "recommended-for-you" as SpotlightKey,
          title: "For You",
          subtitle: "Me afer asaj qe po kerkoni",
          icon: sparklesOutline,
          tone: "for-you",
          products: forYouProducts.value,
        },
        {
          key: "new-arrivals" as SpotlightKey,
          title: "New arrivals",
          subtitle: "Produktet e shtuara se fundi",
          icon: colorWandOutline,
          tone: "sale",
          products: newArrivalProducts.value,
        },
        {
          key: "best-sellers" as SpotlightKey,
          title: "Best sellers",
          subtitle: "Produktet qe po levizin me shpejt",
          icon: flameOutline,
          tone: "trending",
          products: trendingProducts.value,
        },
      ]
).filter((section) => section.products.length > 0));

const filteredProducts = computed(() => {
  let nextProducts = [...products.value];

  if (selectedSpotlight.value !== "all") {
    const activeSection = railSections.value.find((section) => section.key === selectedSpotlight.value);
    const ids = new Set((activeSection?.products || []).map((product) => Number(product.id)));
    nextProducts = nextProducts.filter((product) => ids.has(Number(product.id)));
  }

  if (selectedCategory.value !== "all") {
    nextProducts = nextProducts.filter((product) =>
      String(product.category || product.productType || "").trim() === selectedCategory.value,
    );
  }

  return nextProducts;
});

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

async function loadProducts(reset = false) {
  if (reset) {
    loading.value = true;
  } else {
    loadingMore.value = true;
  }

  try {
    const result = await fetchMarketplaceProductsPage(PAGE_SIZE, reset ? 0 : nextOffset.value);
    products.value = reset
      ? result.items
      : mergeUniqueProducts(products.value, result.items);
    nextOffset.value = result.offset + result.items.length;
    hasMore.value = result.hasMore;
  } finally {
    if (reset) {
      loading.value = false;
    } else {
      loadingMore.value = false;
    }
  }
}

async function loadRecommendations() {
  recommendationSections.value = await fetchHomeRecommendations(10);
}

onMounted(async () => {
  void ensureSession();
  await Promise.all([loadProducts(true), loadRecommendations()]);
});

async function handleAddToCart(productId: number) {
  await addToCart(productId, 1);
  await refreshCounts();
  void loadRecommendations();
}

async function handleWishlist(productId: number) {
  await toggleWishlist(productId);
  await refreshCounts();
  void loadRecommendations();
}

function openSearch() {
  router.push("/tabs/search");
}

function openMessages() {
  router.push("/messages");
}

function setSpotlight(next: SpotlightKey) {
  selectedSpotlight.value = next;
}

async function handleLoadMore(event: CustomEvent) {
  if (!hasMore.value || loadingMore.value) {
    event.target.complete();
    return;
  }

  await loadProducts(false);
  event.target.complete();
  if (!hasMore.value) {
    event.target.disabled = true;
  }
}

watch([selectedSpotlight, selectedCategory], async () => {
  if (loading.value || loadingMore.value || filteredProducts.value.length || !hasMore.value) {
    return;
  }

  await loadProducts(false);
});
</script>

<template>
  <IonPage>
    <IonContent class="app-gradient" :fullscreen="true">
      <div class="mobile-page mobile-page--tabbed mobile-page--edge mobile-page--home">
        <section class="home-topbar">
          <button class="home-topbar-search" type="button" @click="openSearch">
            <span class="home-topbar-search-copy">
              <strong>Kerko produkte dhe biznese</strong>
              <span>Katalogu, kategorite dhe ofertat aktive</span>
            </span>
            <span class="home-topbar-search-arrow">
              <IonIcon :icon="arrowForwardOutline" />
            </span>
          </button>

          <div class="home-topbar-actions">
            <button class="home-topbar-visual home-topbar-action" type="button" aria-label="Visual search" @click="openSearch">
              <span class="home-topbar-visual-icon">
                <IonIcon :icon="colorWandOutline" />
              </span>
            </button>

            <button class="home-topbar-message home-topbar-action" type="button" aria-label="Mesazhet" @click="openMessages">
              <span v-if="homeMessageBadge" class="home-topbar-badge">{{ homeMessageBadge }}</span>
              <IonIcon :icon="chatbubbleEllipsesOutline" />
            </button>
          </div>
        </section>

        <section class="surface-card surface-card--strong home-editorial-shell">
          <div class="home-editorial-copy">
            <p class="section-kicker">TREGIO mobile</p>
            <h1>Me pak padding, me shume fokus te blerja.</h1>
            <p>
              {{
                heroStory
                  ? `${heroStory.businessName || "Marketplace"} po shtyn aktualisht produktet me me shume interes dhe stok real.`
                  : "Eksploro produktet, ofertat dhe bizneset lokale me nje home screen me te paster."
              }}
            </p>
          </div>

          <div class="home-editorial-stats">
            <article v-for="stat in heroStats" :key="stat.label" class="home-editorial-stat">
              <strong>{{ stat.value }}</strong>
              <span>{{ stat.label }}</span>
            </article>
          </div>

          <div class="chip-row home-spotlight-row">
            <button
              v-for="option in spotlightOptions"
              :key="option.key"
              class="chip home-spotlight-chip"
              :class="{ 'is-active': selectedSpotlight === option.key }"
              type="button"
              @click="setSpotlight(option.key)"
            >
              {{ option.label }}
            </button>
          </div>
        </section>

        <section v-if="loading" class="stack-list home-rail-stack">
          <RailSkeleton title="For You" />
          <RailSkeleton title="Trending" />
          <RailSkeleton title="Sales" />
        </section>

        <section v-else-if="railSections.length" class="stack-list home-rail-stack">
          <article
            v-for="section in railSections"
            :key="section.key"
            class="surface-card home-rail-shell"
            :class="`is-${section.tone}`"
          >
            <div class="section-head home-rail-head">
              <button class="home-rail-title" type="button" @click="setSpotlight(section.key)">
                <span class="home-rail-icon">
                  <IonIcon :icon="section.icon" />
                </span>
                <span class="home-rail-copy">
                  <p class="section-kicker">{{ section.title }}</p>
                  <h2>{{ section.subtitle }}</h2>
                </span>
              </button>
              <button class="home-rail-link" type="button" @click="setSpotlight(section.key)">
                <IonIcon :icon="arrowForwardOutline" />
              </button>
            </div>

            <div class="home-rail-track">
              <div
                v-for="product in section.products"
                :key="`${section.key}-${product.id}`"
                class="home-rail-card"
              >
                <ProductCardMobile
                  :product="product"
                  compact
                  @open="(id) => router.push(`/product/${id}`)"
                  @cart="handleAddToCart"
                  @wishlist="handleWishlist"
                />
              </div>
            </div>
          </article>
        </section>

        <section v-if="categories.length > 1" class="home-filter-shell">
          <span class="home-filter-divider" />
          <div class="chip-row home-category-row">
            <button
              v-for="category in categories"
              :key="category"
              class="chip home-category-chip"
              :class="{ 'is-active': selectedCategory === category }"
              type="button"
              @click="selectedCategory = category"
            >
              {{ category === "all" ? "Te gjitha" : category }}
            </button>
          </div>
          <span class="home-filter-divider" />
        </section>

        <section class="stack-list">
          <div class="home-grid-head">
            <span class="home-grid-title">Te gjitha</span>
            <button
              v-if="selectedSpotlight !== 'all' || selectedCategory !== 'all'"
              class="home-grid-reset-button"
              type="button"
              @click="() => { selectedSpotlight = 'all'; selectedCategory = 'all'; }"
            >
              Pastro
            </button>
          </div>

          <div v-if="loading" class="product-grid home-product-grid">
            <ProductCardSkeleton v-for="index in 6" :key="index" />
          </div>

          <div v-else-if="filteredProducts.length" class="product-grid home-product-grid">
            <ProductCardMobile
              v-for="product in filteredProducts"
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
            copy="Provo nje spotlight tjeter ose nderro kategorine qe po shikon."
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
      </div>
    </IonContent>
  </IonPage>
</template>

<style scoped>
.mobile-page--home {
  gap: 12px;
}

.home-topbar {
  position: sticky;
  top: calc(env(safe-area-inset-top, 0px) + 6px);
  z-index: 8;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
}

.home-topbar-search,
.home-topbar-visual,
.home-topbar-message {
  position: relative;
  display: inline-flex;
  align-items: center;
  border: 1px solid rgba(255, 255, 255, 0.56);
  background:
    linear-gradient(180deg, rgba(255, 255, 255, 0.26), rgba(255, 255, 255, 0.08)),
    radial-gradient(circle at top left, rgba(255, 255, 255, 0.24), transparent 28%);
  box-shadow:
    inset 0 1px 0 rgba(255, 255, 255, 0.72),
    0 12px 24px rgba(31, 41, 55, 0.08);
  color: var(--trego-dark);
}

.home-topbar-search {
  flex: 1 1 auto;
  min-height: 48px;
  justify-content: space-between;
  gap: 12px;
  padding: 0 14px 0 16px;
  border-radius: 18px;
  text-align: left;
}

.home-topbar-search-copy {
  display: grid;
  gap: 2px;
  min-width: 0;
}

.home-topbar-search-copy strong {
  color: var(--trego-dark);
  font-size: 0.84rem;
  font-weight: 800;
  line-height: 1.1;
}

.home-topbar-search-copy span {
  color: var(--trego-muted);
  font-size: 0.7rem;
  line-height: 1.3;
}

.home-topbar-search-arrow,
.home-topbar-actions {
  display: inline-flex;
  align-items: center;
}

.home-topbar-actions {
  gap: 8px;
}

.home-topbar-search-arrow {
  justify-content: center;
  width: 28px;
  height: 28px;
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.56);
  color: var(--trego-accent);
}

.home-topbar-action {
  justify-content: center;
  width: 46px;
  height: 46px;
  min-width: 46px;
  min-height: 46px;
  border-radius: 16px;
  padding: 0;
}

.home-topbar-visual {
  justify-content: center;
}

.home-topbar-visual-icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 28px;
  height: 28px;
  border-radius: 999px;
  background: linear-gradient(135deg, rgba(81, 192, 255, 0.2), rgba(120, 102, 255, 0.12));
  color: #4f7cff;
}

.home-topbar-message {
  font-size: 0.82rem;
  font-weight: 800;
}

.home-topbar-badge {
  position: absolute;
  top: -5px;
  right: -2px;
  min-width: 18px;
  height: 18px;
  padding: 0 5px;
  border-radius: 999px;
  background: #ff6a57;
  color: #fff;
  font-size: 0.62rem;
  font-weight: 800;
  line-height: 18px;
  text-align: center;
}

.home-topbar-message ion-icon,
.home-topbar-visual ion-icon,
.home-topbar-search-arrow ion-icon {
  font-size: 1rem;
}

.home-editorial-shell {
  display: grid;
  gap: 12px;
  padding: 16px;
}

.home-editorial-copy {
  display: grid;
  gap: 8px;
}

.home-editorial-copy h1 {
  margin: 0;
  color: var(--trego-dark);
  font-size: clamp(1.4rem, 6vw, 1.9rem);
  line-height: 0.98;
  letter-spacing: -0.04em;
}

.home-editorial-copy p:last-child {
  margin: 0;
  color: var(--trego-muted);
  font-size: 0.82rem;
  line-height: 1.5;
}

.home-editorial-stats {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 8px;
}

.home-editorial-stat {
  display: grid;
  gap: 3px;
  padding: 10px 12px;
  border-radius: 16px;
  background:
    linear-gradient(180deg, rgba(255, 255, 255, 0.82), rgba(255, 255, 255, 0.6)),
    linear-gradient(135deg, rgba(239, 107, 46, 0.08), rgba(36, 50, 74, 0.04));
  border: 1px solid rgba(255, 255, 255, 0.72);
}

.home-editorial-stat strong {
  color: var(--trego-dark);
  font-size: 1rem;
  line-height: 1;
}

.home-editorial-stat span {
  color: var(--trego-muted);
  font-size: 0.66rem;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.home-spotlight-row {
  gap: 8px;
}

.home-spotlight-chip.is-active,
.home-category-chip.is-active {
  background:
    linear-gradient(135deg, rgba(239, 107, 46, 0.96), rgba(205, 83, 23, 0.92));
  color: #fffdf9;
  border-color: rgba(239, 107, 46, 0.32);
  box-shadow: 0 10px 18px rgba(239, 107, 46, 0.16);
}

.home-rail-stack {
  gap: 10px;
}

.home-rail-shell {
  display: grid;
  gap: 10px;
  padding: 12px 0 12px 12px;
}

.home-rail-shell.is-for-you {
  background:
    linear-gradient(180deg, rgba(255, 255, 255, 0.94), rgba(255, 255, 255, 0.82)),
    radial-gradient(circle at top left, rgba(34, 197, 94, 0.12), transparent 30%);
}

.home-rail-shell.is-trending {
  background:
    linear-gradient(180deg, rgba(255, 255, 255, 0.94), rgba(255, 255, 255, 0.82)),
    radial-gradient(circle at top left, rgba(239, 68, 68, 0.12), transparent 30%);
}

.home-rail-shell.is-sale {
  background:
    linear-gradient(180deg, rgba(255, 255, 255, 0.94), rgba(255, 255, 255, 0.82)),
    radial-gradient(circle at top left, rgba(249, 115, 22, 0.14), transparent 30%);
}

.home-rail-head {
  padding-right: 12px;
}

.home-rail-title {
  min-width: 0;
  display: grid;
  grid-template-columns: auto minmax(0, 1fr);
  gap: 10px;
  align-items: center;
  border: 0;
  padding: 0;
  background: transparent;
  text-align: left;
}

.home-rail-copy {
  display: grid;
  gap: 4px;
}

.home-rail-icon {
  display: inline-flex;
  width: 34px;
  height: 34px;
  align-items: center;
  justify-content: center;
  border-radius: 14px;
  background: rgba(255, 255, 255, 0.54);
  color: var(--trego-accent);
  box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.78);
}

.home-rail-head h2 {
  font-size: 1rem;
}

.home-rail-link {
  display: inline-flex;
  width: 34px;
  height: 34px;
  align-items: center;
  justify-content: center;
  border: 0;
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.58);
  color: var(--trego-accent);
  box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.8);
}

.home-rail-track {
  display: grid;
  grid-auto-flow: column;
  grid-auto-columns: minmax(0, 180px);
  gap: 10px;
  overflow-x: auto;
  padding-right: 12px;
  scrollbar-width: none;
}

.home-rail-track::-webkit-scrollbar {
  display: none;
}

.home-rail-card {
  min-width: 0;
}

.home-filter-shell {
  display: grid;
  gap: 10px;
}

.home-filter-divider {
  display: block;
  width: 100%;
  height: 1px;
  background: linear-gradient(90deg, transparent, rgba(148, 163, 184, 0.38), transparent);
}

.home-grid-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
}

.home-grid-reset-button {
  border: 0;
  padding: 0;
  background: transparent;
  color: rgba(15, 23, 42, 0.62);
  font-size: 0.74rem;
  font-weight: 800;
  letter-spacing: 0.06em;
  text-transform: uppercase;
}

.home-grid-title {
  color: #1d4ed8;
  font-size: 0.74rem;
  font-weight: 800;
  letter-spacing: 0.14em;
  text-transform: uppercase;
}

.home-product-grid {
  gap: 12px;
}

body[data-theme="dark"] .home-topbar-visual,
body[data-theme="dark"] .home-topbar-message,
body[data-theme="dark"] .home-topbar-search,
body[data-theme="dark"] .home-rail-link,
body[data-theme="dark"] .home-rail-icon,
body[data-theme="dark"] .home-editorial-stat {
  border-color: rgba(198, 214, 242, 0.14);
  background: rgba(19, 27, 42, 0.78);
  color: rgba(241, 245, 249, 0.92);
  box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.08);
}

body[data-theme="dark"] .home-topbar-visual-icon {
  background: linear-gradient(135deg, rgba(81, 192, 255, 0.22), rgba(120, 102, 255, 0.18));
  color: #8ab4ff;
}

body[data-theme="dark"] .home-topbar-search-copy strong,
body[data-theme="dark"] .home-editorial-copy h1,
body[data-theme="dark"] .home-editorial-stat strong {
  color: rgba(241, 245, 249, 0.96);
}

body[data-theme="dark"] .home-topbar-search-copy span,
body[data-theme="dark"] .home-editorial-copy p:last-child,
body[data-theme="dark"] .home-editorial-stat span {
  color: rgba(203, 213, 225, 0.76);
}

body[data-theme="dark"] .home-rail-shell.is-for-you,
body[data-theme="dark"] .home-rail-shell.is-trending,
body[data-theme="dark"] .home-rail-shell.is-sale {
  background: rgba(7, 13, 24, 0.84);
}

@media (max-width: 420px) {
  .home-editorial-stats {
    grid-template-columns: 1fr;
  }
}
</style>
