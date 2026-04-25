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
    <IonContent :fullscreen="true">
      <div>
        <section>
          <button type="button" @click="openSearch">
            <span>
              <strong>Kerko produkte dhe biznese</strong>
              <span>Katalogu, kategorite dhe ofertat aktive</span>
            </span>
            <span>
              <IonIcon :icon="arrowForwardOutline" />
            </span>
          </button>

          <div>
            <button type="button" aria-label="Visual search" @click="openSearch">
              <span>
                <IonIcon :icon="colorWandOutline" />
              </span>
            </button>

            <button type="button" aria-label="Mesazhet" @click="openMessages">
              <span v-if="homeMessageBadge">{{ homeMessageBadge }}</span>
              <IonIcon :icon="chatbubbleEllipsesOutline" />
            </button>
          </div>
        </section>

        <section>
          <div>
            <p>TREGIO mobile</p>
            <h1>Me pak padding, me shume fokus te blerja.</h1>
            <p>
              {{
                heroStory
                  ? `${heroStory.businessName || "Marketplace"} po shtyn aktualisht produktet me me shume interes dhe stok real.`
                  : "Eksploro produktet, ofertat dhe bizneset lokale me nje home screen me te paster."
              }}
            </p>
          </div>

          <div>
            <article v-for="stat in heroStats" :key="stat.label">
              <strong>{{ stat.value }}</strong>
              <span>{{ stat.label }}</span>
            </article>
          </div>

          <div>
            <button
              v-for="option in spotlightOptions"
              :key="option.key"
             
             
              type="button"
              @click="setSpotlight(option.key)"
            >
              {{ option.label }}
            </button>
          </div>
        </section>

        <section v-if="loading">
          <RailSkeleton title="For You" />
          <RailSkeleton title="Trending" />
          <RailSkeleton title="Sales" />
        </section>

        <section v-else-if="railSections.length">
          <article
            v-for="section in railSections"
            :key="section.key"
           
           
          >
            <div>
              <button type="button" @click="setSpotlight(section.key)">
                <span>
                  <IonIcon :icon="section.icon" />
                </span>
                <span>
                  <p>{{ section.title }}</p>
                  <h2>{{ section.subtitle }}</h2>
                </span>
              </button>
              <button type="button" @click="setSpotlight(section.key)">
                <IonIcon :icon="arrowForwardOutline" />
              </button>
            </div>

            <div>
              <div
                v-for="product in section.products"
                :key="`${section.key}-${product.id}`"
               
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

        <section v-if="categories.length > 1">
          <span />
          <div>
            <button
              v-for="category in categories"
              :key="category"
             
             
              type="button"
              @click="selectedCategory = category"
            >
              {{ category === "all" ? "Te gjitha" : category }}
            </button>
          </div>
          <span />
        </section>

        <section>
          <div>
            <span>Te gjitha</span>
            <button
              v-if="selectedSpotlight !== 'all' || selectedCategory !== 'all'"
             
              type="button"
              @click="() => { selectedSpotlight = 'all'; selectedCategory = 'all'; }"
            >
              Pastro
            </button>
          </div>

          <div v-if="loading">
            <ProductCardSkeleton v-for="index in 6" :key="index" />
          </div>

          <div v-else-if="filteredProducts.length">
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

