<script setup lang="ts">
import { IonContent, IonIcon, IonPage, IonSpinner } from "@ionic/vue";
import { arrowForwardOutline, flameOutline, pricetagOutline, sparklesOutline } from "ionicons/icons";
import { computed, onMounted, ref } from "vue";
import { useRouter } from "vue-router";
import EmptyStatePanel from "../components/EmptyStatePanel.vue";
import ProductCardMobile from "../components/ProductCardMobile.vue";
import { addToCart, fetchMarketplaceProducts, toggleWishlist } from "../lib/api";
import type { ProductItem } from "../types/models";
import { ensureSession, refreshCounts } from "../stores/session";

type SpotlightKey = "all" | "trending" | "sale" | "for-you";

const router = useRouter();
const loading = ref(true);
const products = ref<ProductItem[]>([]);
const selectedSpotlight = ref<SpotlightKey>("all");
const selectedCategory = ref("all");

const spotlightCards = computed(() => [
  {
    key: "trending" as const,
    title: "Trending",
    subtitle: "Produktet me interesim me te madh",
    icon: flameOutline,
    tone: "trend",
  },
  {
    key: "sale" as const,
    title: "Sale",
    subtitle: "Cmimet me te mira te dites",
    icon: pricetagOutline,
    tone: "sale",
  },
  {
    key: "for-you" as const,
    title: "For You",
    subtitle: "Produkte te perzgjedhura per ty",
    icon: sparklesOutline,
    tone: "for-you",
  },
]);

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

const railSections = computed(() => [
  {
    key: "trending" as SpotlightKey,
    title: "Trending",
    subtitle: "Zgjedhje qe levizin me shpejt",
    products: trendingProducts.value,
  },
  {
    key: "sale" as SpotlightKey,
    title: "Sale",
    subtitle: "Oferta aktive nga marketplace",
    products: saleProducts.value,
  },
  {
    key: "for-you" as SpotlightKey,
    title: "For You",
    subtitle: "Me afer stilit qe po kerkon",
    products: forYouProducts.value,
  },
].filter((section) => section.products.length > 0));

const filteredProducts = computed(() => {
  let nextProducts = [...products.value];

  if (selectedSpotlight.value === "trending") {
    const ids = new Set(trendingProducts.value.map((product) => Number(product.id)));
    nextProducts = nextProducts.filter((product) => ids.has(Number(product.id)));
  } else if (selectedSpotlight.value === "sale") {
    nextProducts = nextProducts.filter((product) => Number(product.compareAtPrice || 0) > Number(product.price || 0));
  } else if (selectedSpotlight.value === "for-you") {
    const ids = new Set(forYouProducts.value.map((product) => Number(product.id)));
    nextProducts = nextProducts.filter((product) => ids.has(Number(product.id)));
  }

  if (selectedCategory.value !== "all") {
    nextProducts = nextProducts.filter((product) =>
      String(product.category || product.productType || "").trim() === selectedCategory.value,
    );
  }

  return nextProducts.slice(0, 18);
});

onMounted(async () => {
  void ensureSession();
  try {
    products.value = await fetchMarketplaceProducts(28, 0);
  } finally {
    loading.value = false;
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

function openSearch() {
  router.push("/tabs/search");
}

function setSpotlight(next: SpotlightKey) {
  selectedSpotlight.value = next;
}
</script>

<template>
  <IonPage>
    <IonContent class="app-gradient" :fullscreen="true">
      <div class="mobile-page mobile-page--tabbed mobile-page--edge mobile-page--home">
        <section class="home-spotlight-grid">
          <button
            v-for="card in spotlightCards"
            :key="card.key"
            class="home-spotlight-card"
            :class="[`tone-${card.tone}`, { 'is-active': selectedSpotlight === card.key }]"
            type="button"
            @click="setSpotlight(card.key)"
          >
            <span class="home-spotlight-icon">
              <IonIcon :icon="card.icon" />
            </span>

            <div class="home-spotlight-copy">
              <strong>{{ card.title }}</strong>
              <span>{{ card.subtitle }}</span>
            </div>

            <IonIcon class="home-spotlight-arrow" :icon="arrowForwardOutline" />
          </button>
        </section>

        <section v-if="railSections.length" class="stack-list home-rail-stack">
          <article
            v-for="section in railSections"
            :key="section.key"
            class="surface-card home-rail-shell"
          >
            <div class="section-head home-rail-head">
              <div>
                <p class="section-kicker">{{ section.title }}</p>
                <h2>{{ section.subtitle }}</h2>
              </div>
              <button class="home-rail-link" type="button" @click="setSpotlight(section.key)">
                Shiko
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

        <section class="surface-card home-filter-shell">
          <div class="chip-row home-filter-row">
            <button
              class="chip home-filter-chip"
              :class="{ 'is-active': selectedSpotlight === 'all' }"
              type="button"
              @click="setSpotlight('all')"
            >
              Te gjitha
            </button>
            <button
              v-for="card in spotlightCards"
              :key="`filter-${card.key}`"
              class="chip home-filter-chip"
              :class="{ 'is-active': selectedSpotlight === card.key }"
              type="button"
              @click="setSpotlight(card.key)"
            >
              {{ card.title }}
            </button>
          </div>

          <div class="chip-row home-category-row">
            <button
              v-for="category in categories"
              :key="category"
              class="chip home-category-chip"
              :class="{ 'is-active': selectedCategory === category }"
              type="button"
              @click="selectedCategory = category"
            >
              {{ category === "all" ? "Kategorite" : category }}
            </button>
          </div>
        </section>

        <section class="stack-list">
          <div class="home-grid-head">
            <button class="home-grid-search-button" type="button" @click="openSearch">
              Kerko ne marketplace
            </button>
            <span class="home-grid-title">Produktet</span>
          </div>

          <div v-if="loading" class="surface-card empty-panel">
            <IonSpinner name="crescent" />
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
        </section>
      </div>
    </IonContent>
  </IonPage>
</template>

<style scoped>
.mobile-page--home {
  gap: 14px;
}

.home-spotlight-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 10px;
}

.home-spotlight-card {
  display: grid;
  gap: 10px;
  min-height: 118px;
  padding: 14px;
  border: 1px solid rgba(255, 255, 255, 0.46);
  border-radius: 24px;
  color: #fffdf9;
  text-align: left;
  box-shadow: 0 18px 34px rgba(31, 41, 55, 0.14);
}

.home-spotlight-card.tone-trend {
  background: linear-gradient(155deg, rgba(198, 39, 54, 0.96), rgba(147, 22, 40, 0.88));
}

.home-spotlight-card.tone-sale {
  background: linear-gradient(155deg, rgba(255, 106, 43, 0.96), rgba(227, 78, 22, 0.88));
}

.home-spotlight-card.tone-for-you {
  background: linear-gradient(155deg, rgba(46, 152, 89, 0.96), rgba(24, 108, 59, 0.88));
}

.home-spotlight-card.is-active {
  transform: translateY(-1px);
  box-shadow: 0 22px 38px rgba(31, 41, 55, 0.18);
}

.home-spotlight-icon {
  display: inline-flex;
  width: 34px;
  height: 34px;
  align-items: center;
  justify-content: center;
  border-radius: 14px;
  background: rgba(255, 255, 255, 0.18);
  box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.22);
}

.home-spotlight-icon ion-icon {
  font-size: 1rem;
}

.home-spotlight-copy {
  display: grid;
  gap: 4px;
}

.home-spotlight-copy strong {
  font-size: 0.92rem;
  line-height: 1.08;
}

.home-spotlight-copy span {
  color: rgba(255, 253, 249, 0.76);
  font-size: 0.72rem;
  line-height: 1.36;
}

.home-spotlight-arrow {
  justify-self: flex-end;
  font-size: 0.92rem;
  opacity: 0.86;
}

.home-rail-stack {
  gap: 12px;
}

.home-rail-shell {
  display: grid;
  gap: 12px;
  padding: 14px 0 14px 14px;
}

.home-rail-head {
  padding-right: 14px;
}

.home-rail-head h2 {
  font-size: 1rem;
}

.home-rail-link {
  border: 0;
  padding: 0;
  background: transparent;
  color: var(--trego-accent);
  font-size: 0.78rem;
  font-weight: 800;
}

.home-rail-track {
  display: grid;
  grid-auto-flow: column;
  grid-auto-columns: minmax(0, 188px);
  gap: 12px;
  overflow-x: auto;
  padding-right: 14px;
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
  padding: 12px;
}

.home-filter-row,
.home-category-row {
  padding-bottom: 2px;
}

.home-filter-chip.is-active,
.home-category-chip.is-active {
  background:
    linear-gradient(135deg, rgba(255, 126, 64, 0.96), rgba(255, 106, 43, 0.88));
  color: #fffdf9;
  border-color: rgba(255, 140, 89, 0.42);
  box-shadow: 0 14px 24px rgba(255, 106, 43, 0.18);
}

.home-grid-head {
  display: grid;
  gap: 10px;
  justify-items: center;
}

.home-grid-search-button {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-height: 42px;
  padding: 0 18px;
  border: 1px solid rgba(255, 255, 255, 0.54);
  border-radius: 999px;
  background:
    linear-gradient(180deg, rgba(255, 255, 255, 0.22), rgba(255, 255, 255, 0.08));
  color: var(--trego-dark);
  font-size: 0.82rem;
  font-weight: 800;
  box-shadow:
    inset 0 1px 0 rgba(255, 255, 255, 0.72),
    0 12px 24px rgba(31, 41, 55, 0.08);
}

.home-grid-title {
  color: var(--trego-accent);
  font-size: 0.78rem;
  font-weight: 800;
  letter-spacing: 0.14em;
  text-transform: uppercase;
}

.home-product-grid {
  gap: 14px;
}

@media (max-width: 420px) {
  .home-spotlight-grid {
    grid-template-columns: 1fr;
  }
}
</style>
