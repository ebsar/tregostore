<script setup>
import { computed, onMounted } from "vue";
import { RouterLink } from "vue-router";
import { clearComparedProducts, compareState, ensureCompareItemsLoaded, removeComparedProduct } from "../stores/product-compare";
import {
  formatCategoryLabel,
  formatPrice,
  formatProductColorLabel,
  formatProductTypeLabel,
  formatStockQuantity,
  getProductDetailUrl,
  hasProductAvailableStock,
} from "../lib/shop";
import { markRouteReady } from "../stores/app-state";

onMounted(() => {
  ensureCompareItemsLoaded();
  markRouteReady();
});

const compareItems = computed(() => compareState.items);
const compareCount = computed(() => compareItems.value.length);
const availableCount = computed(() =>
  compareItems.value.filter((item) => hasProductAvailableStock(item)).length,
);
const unavailableCount = computed(() => compareCount.value - availableCount.value);

const sortedByPrice = computed(() =>
  [...compareItems.value].sort((left, right) => Number(left.price || 0) - Number(right.price || 0)),
);
const cheapestProductId = computed(() => sortedByPrice.value[0]?.id || 0);
const priciestProductId = computed(() => sortedByPrice.value[sortedByPrice.value.length - 1]?.id || 0);

function handleRemove(productOrId) {
  removeComparedProduct(productOrId);
}

function handleClear() {
  clearComparedProducts();
}

function buildSpecs(product) {
  return [
    { label: "Kategoria", value: formatCategoryLabel(product.category) },
    { label: "Lloji", value: formatProductTypeLabel(product.productType) },
    { label: "Stoku", value: hasProductAvailableStock(product) ? formatStockQuantity(product.stockQuantity) : "Nuk ka ne stok" },
    { label: "Rating", value: Number(product.averageRating || 0) > 0 ? `${Number(product.averageRating || 0).toFixed(1)} / 5` : "Pa vleresime" },
    { label: "Blerje", value: `${Number(product.buyersCount || 0)} blerje` },
    {
      label: "Ngjyra / Madhesia",
      value: [product.color ? formatProductColorLabel(product.color) : "", product.size || ""]
        .filter(Boolean)
        .join(" / ") || "-",
    },
  ];
}
</script>

<template>
  <section class="market-page market-page--wide compare-page" aria-label="Krahasimi i produkteve">
    <nav class="market-page__crumbs" aria-label="Breadcrumb">
      <RouterLink to="/">Home</RouterLink>
      <span aria-hidden="true">/</span>
      <strong>Krahaso</strong>
    </nav>

    <header class="compare-hero">
      <div class="market-page__header-copy">
        <p class="market-page__eyebrow">Krahasim</p>
        <h1>Krahaso produktet</h1>
        <p>
          Shiko produktet krah per krah me stok, cmim, rating dhe detaje praktike per te zgjedhur me shpejt.
        </p>
      </div>

      <div v-if="compareCount > 0" class="compare-summary" aria-label="Permbledhje krahasimi">
        <article>
          <span>Ne krahasim</span>
          <strong>{{ compareCount }}</strong>
        </article>
        <article>
          <span>Ne stok</span>
          <strong>{{ availableCount }}</strong>
        </article>
        <article>
          <span>Pa stok</span>
          <strong>{{ unavailableCount }}</strong>
        </article>
      </div>
    </header>

    <section v-if="compareCount > 0" class="compare-toolbar" aria-label="Veprimet e krahasimit">
      <div>
        <strong>{{ compareCount }} produkte aktive</strong>
        <span>Hiq produktet qe nuk te duhen ose hape secilin produkt per detaje te plota.</span>
      </div>
      <button class="market-button market-button--secondary" type="button" @click="handleClear">
        Pastro krahasimin
      </button>
    </section>

    <div v-if="compareCount === 0" class="market-empty compare-empty">
      <h2>Nuk ke zgjedhur ende produkte per krahasim.</h2>
      <p>Shto te pakten dy produkte nga kartat ose faqja e produktit dhe krahasoji ketu.</p>
      <div class="market-empty__actions">
        <RouterLink class="market-button market-button--primary" to="/kerko">
          Shiko katalogun
        </RouterLink>
      </div>
    </div>

    <section v-else class="compare-grid" aria-label="Krahasimi i detajuar">
      <article
        v-for="product in compareItems"
        :key="product.id"
        class="compare-card"
        :class="{
          'compare-card--best-price': product.id === cheapestProductId,
          'compare-card--highest-price': product.id === priciestProductId && product.id !== cheapestProductId,
        }"
      >
        <div class="compare-card__media">
          <RouterLink :to="getProductDetailUrl(product.id)">
            <img :src="product.imagePath" :alt="product.title" width="640" height="640" loading="lazy" decoding="async">
          </RouterLink>
          <button class="compare-card__remove" type="button" @click="handleRemove(product)">
            Hiqe
          </button>
        </div>

        <div class="compare-card__body">
          <div class="compare-card__head">
            <p>{{ formatCategoryLabel(product.category) }}</p>
            <h2>{{ product.title }}</h2>
            <span>{{ product.businessName || "Biznesi" }}</span>
          </div>

          <div class="compare-card__price">
            <strong>{{ formatPrice(product.price) }}</strong>
            <span v-if="Number(product.compareAtPrice || 0) > Number(product.price || 0)">
              {{ formatPrice(product.compareAtPrice) }}
            </span>
          </div>

          <div class="compare-card__badges">
            <span :class="{ 'is-muted': !hasProductAvailableStock(product) }">
              {{ hasProductAvailableStock(product) ? formatStockQuantity(product.stockQuantity) : "Nuk ka ne stok" }}
            </span>
            <span>
              {{ Number(product.averageRating || 0) > 0 ? `${Number(product.averageRating || 0).toFixed(1)} / 5` : "Pa vleresime" }}
            </span>
            <span>
              {{ Number(product.buyersCount || 0) }} blerje
            </span>
          </div>

          <dl class="compare-card__specs">
            <div v-for="spec in buildSpecs(product)" :key="`${product.id}-${spec.label}`">
              <dt>{{ spec.label }}</dt>
              <dd>{{ spec.value }}</dd>
            </div>
          </dl>

          <RouterLink class="market-button market-button--primary" :to="getProductDetailUrl(product.id)">
            Hape produktin
          </RouterLink>
        </div>
      </article>
    </section>
  </section>
</template>

<style scoped>
.compare-page {
  display: grid;
  gap: 18px;
}

.compare-hero {
  display: grid;
  grid-template-columns: minmax(0, 1fr) minmax(300px, 440px);
  gap: 20px;
  align-items: stretch;
  padding: 22px;
  border: 1px solid var(--dashboard-border);
  border-radius: var(--dashboard-radius);
  background:
    linear-gradient(135deg, rgba(37, 99, 235, 0.08), transparent 44%),
    linear-gradient(315deg, rgba(183, 121, 31, 0.08), transparent 38%),
    #ffffff;
}

.compare-hero p {
  max-width: 700px;
  margin: 10px 0 0;
  color: var(--dashboard-muted);
  line-height: 1.55;
}

.compare-summary {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 10px;
  align-self: end;
}

.compare-summary article {
  min-height: 92px;
  display: grid;
  align-content: center;
  gap: 8px;
  padding: 14px;
  border: 1px solid #efe7d7;
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.82);
}

.compare-summary span,
.compare-toolbar span {
  color: var(--dashboard-muted);
  font-size: 12px;
  font-weight: 650;
  text-transform: uppercase;
}

.compare-summary strong {
  color: var(--dashboard-text);
  font-size: 28px;
  line-height: 1;
}

.compare-toolbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 14px;
  padding: 14px 16px;
  border: 1px solid var(--dashboard-border);
  border-radius: var(--dashboard-radius);
  background: #ffffff;
}

.compare-toolbar > div {
  display: grid;
  gap: 4px;
}

.compare-toolbar strong {
  color: var(--dashboard-text);
  font-size: 15px;
}

.compare-empty {
  background: #ffffff;
}

.compare-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 16px;
}

.compare-card {
  position: relative;
  min-width: 0;
  display: grid;
  gap: 14px;
  padding: 14px;
  border: 1px solid var(--dashboard-border);
  border-radius: var(--dashboard-radius);
  background: #ffffff;
  box-shadow: 0 12px 28px rgba(17, 17, 17, 0.04);
}

.compare-card--best-price {
  border-color: var(--dashboard-green-border);
}

.compare-card--highest-price {
  border-color: var(--dashboard-amber-border);
}

.compare-card__media {
  position: relative;
  aspect-ratio: 1 / 1;
  overflow: hidden;
  border-radius: 10px;
  background: #f2f2f2;
}

.compare-card__media img {
  width: 100%;
  height: 100%;
  display: block;
  object-fit: cover;
}

.compare-card__remove {
  position: absolute;
  top: 10px;
  right: 10px;
  min-height: 32px;
  padding: 0 10px;
  border: 1px solid rgba(17, 17, 17, 0.08);
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.94);
  color: var(--dashboard-text);
  font-size: 12px;
  font-weight: 700;
  cursor: pointer;
}

.compare-card__body,
.compare-card__head,
.compare-card__specs {
  min-width: 0;
  display: grid;
  gap: 10px;
}

.compare-card__head p,
.compare-card__head span,
.compare-card__price span,
.compare-card__badges span,
.compare-card__specs dt,
.compare-card__specs dd {
  margin: 0;
  color: var(--dashboard-muted);
  font-size: 12px;
  line-height: 1.45;
}

.compare-card__head p {
  color: var(--dashboard-accent);
  font-weight: 700;
  letter-spacing: 0.04em;
  text-transform: uppercase;
}

.compare-card__head h2 {
  margin: 0;
  color: var(--dashboard-text);
  font-size: 16px;
  font-weight: 750;
  line-height: 1.35;
}

.compare-card__price {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 12px;
}

.compare-card__price strong {
  color: var(--dashboard-text);
  font-size: 19px;
  font-weight: 850;
}

.compare-card__price span {
  text-decoration: line-through;
}

.compare-card__badges {
  display: flex;
  flex-wrap: wrap;
  gap: 7px;
}

.compare-card__badges span {
  display: inline-flex;
  align-items: center;
  min-height: 26px;
  padding: 0 9px;
  border: 1px solid #ececec;
  border-radius: 999px;
  background: #fafafa;
  font-weight: 650;
}

.compare-card__badges span:first-child {
  border-color: var(--dashboard-green-border);
  background: var(--dashboard-green-soft);
  color: var(--dashboard-green);
}

.compare-card__badges span.is-muted {
  border-color: #ead6d6;
  background: #fff7f7;
  color: var(--dashboard-danger);
}

.compare-card__specs {
  padding: 0;
  margin: 0;
}

.compare-card__specs div {
  display: flex;
  justify-content: space-between;
  gap: 12px;
  padding: 9px 0;
  border-top: 1px solid #f0f0f0;
}

.compare-card__specs dt {
  font-weight: 700;
}

.compare-card__specs dd {
  color: var(--dashboard-text);
  text-align: right;
}

@media (max-width: 1100px) {
  .compare-hero,
  .compare-grid {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 760px) {
  .compare-summary {
    grid-template-columns: 1fr;
  }

  .compare-toolbar {
    align-items: stretch;
    flex-direction: column;
  }
}
</style>
