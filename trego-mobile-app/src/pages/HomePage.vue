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
import { useQuery, useMutation } from "@tanstack/vue-query";
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
import { queryKeys } from "../lib/query-keys";
import { queryClient } from "../lib/query-client";
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
const loadingMore = ref(false);
const nextOffset = ref(0);
const selectedSpotlight = ref<SpotlightKey>("all");
const selectedCategory = ref("all");

// Query for products
const { data: productsData, isLoading: productsLoading } = useQuery({
  queryKey: queryKeys.products.list({ limit: 100 }), // Fetch a good chunk for filtering
  queryFn: () => fetchMarketplaceProductsPage(100, 0),
  staleTime: 1000 * 60 * 5,
});

const products = computed(() => productsData.value?.items || []);

// Query for recommendations
const { data: recommendationSections, isLoading: recommendationsLoading } = useQuery({
  queryKey: queryKeys.products.recommendations("home"),
  queryFn: () => fetchHomeRecommendations(10),
  staleTime: 1000 * 60 * 10,
});

const loading = computed(() => productsLoading.value || recommendationsLoading.value);
const hasMore = computed(() => Boolean(productsData.value?.hasMore));

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
  recommendationSections.value?.length
    ? (recommendationSections.value || []).map((section) => ({
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

onMounted(async () => {
  void ensureSession();
});

const addToCartMutation = useMutation({
  mutationFn: (productId: number) => addToCart(productId, 1),
  onSuccess: () => {
    queryClient.invalidateQueries({ queryKey: queryKeys.cart.main() });
    queryClient.invalidateQueries({ queryKey: queryKeys.products.recommendations("home") });
  },
});

const wishlistMutation = useMutation({
  mutationFn: (productId: number) => toggleWishlist(productId),
  onSuccess: () => {
    queryClient.invalidateQueries({ queryKey: queryKeys.wishlist.main() });
    queryClient.invalidateQueries({ queryKey: queryKeys.products.recommendations("home") });
  },
});

async function handleAddToCart(productId: number) {
  await addToCartMutation.mutateAsync(productId);
}

async function handleWishlist(productId: number) {
  await wishlistMutation.mutateAsync(productId);
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
  // Logic simplified: we fetch 100 products at once now for instant feel
  event.target.complete();
  event.target.disabled = true;
}

watch([selectedSpotlight, selectedCategory], () => {
  // Logic simplified: we fetch a larger chunk upfront
});
</script>

<template>
  <IonPage>
    <IonContent :fullscreen="true">
      <div class="trego-mobile-screen trego-home-screen">
        <section class="trego-top-actions">
          <button class="trego-search-button" type="button" @click="openSearch">
            <span>
              <strong>Kerko produkte dhe biznese</strong>
              <span>Katalogu, kategorite dhe ofertat aktive</span>
            </span>
            <span>
              <IonIcon :icon="arrowForwardOutline" />
            </span>
          </button>

          <div class="trego-top-actions__icons">
            <button class="trego-icon-button" type="button" aria-label="Visual search" @click="openSearch">
              <span>
                <IonIcon :icon="colorWandOutline" />
              </span>
            </button>

            <button class="trego-icon-button" type="button" aria-label="Mesazhet" @click="openMessages">
              <span v-if="homeMessageBadge" class="trego-tab-shell__badge">{{ homeMessageBadge }}</span>
              <IonIcon :icon="chatbubbleEllipsesOutline" />
            </button>
          </div>
        </section>

        <section class="trego-home-hero">
          <div>
            <p class="trego-kicker">TREGIO mobile</p>
            <h1>Bli me shpejt dhe gjej produkte me lehte.</h1>
            <p>
              {{
                heroStory
                  ? `${heroStory.businessName || "Marketplace"} po sjell produktet me te kerkuara dhe me stok aktiv tani.`
                  : "Shfleto ofertat, kategorite dhe bizneset lokale ne nje home screen me te qarte."
              }}
            </p>
          </div>

          <div class="trego-stats-row">
            <article v-for="stat in heroStats" :key="stat.label">
              <strong>{{ stat.value }}</strong>
              <span>{{ stat.label }}</span>
            </article>
          </div>

          <div class="trego-chip-row">
            <button
              v-for="option in spotlightOptions"
              :key="option.key"
              :class="['trego-chip', { 'is-active': selectedSpotlight === option.key }]"
              type="button"
              @click="setSpotlight(option.key)"
            >
              {{ option.label }}
            </button>
          </div>
        </section>

        <section v-if="loading" class="trego-list-stack">
          <RailSkeleton title="For You" />
          <RailSkeleton title="Trending" />
          <RailSkeleton title="Sales" />
        </section>

        <section v-else-if="railSections.length" class="trego-list-stack">
          <article
            v-for="section in railSections"
            :key="section.key"
            class="trego-rail-section"
          >
            <div class="trego-rail-header">
              <button class="trego-rail-title" type="button" @click="setSpotlight(section.key)">
                <span>
                  <IonIcon :icon="section.icon" />
                </span>
                <span>
                  <p>{{ section.title }}</p>
                  <h2>{{ section.subtitle }}</h2>
                </span>
              </button>
              <button class="trego-icon-button" type="button" @click="setSpotlight(section.key)">
                <IonIcon :icon="arrowForwardOutline" />
              </button>
            </div>

            <div class="trego-product-rail">
              <div
                v-for="product in section.products"
                :key="`${section.key}-${product.id}`"
                class="trego-product-rail__item"
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

        <section v-if="categories.length > 1" class="trego-filter-row">
          <span />
          <div class="trego-chip-row">
            <button
              v-for="category in categories"
              :key="category"
              :class="['trego-chip', { 'is-active': selectedCategory === category }]"
              type="button"
              @click="selectedCategory = category"
            >
              {{ category === "all" ? "Te gjitha" : category }}
            </button>
          </div>
          <span />
        </section>

        <section>
          <div class="trego-section-toolbar">
            <span>Te gjitha</span>
            <button
              v-if="selectedSpotlight !== 'all' || selectedCategory !== 'all'"
              class="trego-reset-button"
              type="button"
              @click="() => { selectedSpotlight = 'all'; selectedCategory = 'all'; }"
            >
              Pastro
            </button>
          </div>

          <div v-if="loading" class="trego-product-grid">
            <ProductCardSkeleton v-for="index in 6" :key="index" />
          </div>

          <div v-else-if="filteredProducts.length" class="trego-product-grid">
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
