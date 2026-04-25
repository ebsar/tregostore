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

onMounted(() => {
  ensureCompareItemsLoaded();
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
        .join(" • ") || "-",
    },
  ];
}
</script>

<template>
  <section aria-label="Krahasimi i produkteve">
    <header>
      <p>Krahasim</p>
      <h1>Krahaso produktet</h1>
      <p>
        Shiko produktet krah per krah, me stok, cmim, rating dhe detaje te tjera qe te ndihmojne te zgjedhesh me shpejt.
      </p>
    </header>

    <div v-if="compareCount > 0">
      <div>
        <span>Ne krahasim</span>
        <strong>{{ compareCount }}</strong>
      </div>
      <div>
        <span>Ne stok</span>
        <strong>{{ availableCount }}</strong>
      </div>
      <div>
        <span>Pa stok</span>
        <strong>{{ unavailableCount }}</strong>
      </div>
      <button type="button" @click="handleClear">
        Pastro krahasimin
      </button>
    </div>

    <div v-if="compareCount === 0">
      <h2>Nuk ke zgjedhur ende produkte per krahasim.</h2>
      <p>Shto te pakten dy produkte nga kartat ose faqja e produktit dhe krahasoji ketu.</p>
      <RouterLink to="/kerko">
        Shiko katalogun
      </RouterLink>
    </div>

    <section v-else aria-label="Krahasimi i detajuar">
      <article
        v-for="product in compareItems"
        :key="product.id"
       
       
      >
        <div>
          <RouterLink :to="getProductDetailUrl(product.id)">
            <img :src="product.imagePath" :alt="product.title" width="640" height="640" loading="lazy" decoding="async">
          </RouterLink>
          <button type="button" @click="handleRemove(product)">
            Hiqe
          </button>
        </div>

        <div>
          <p>{{ formatCategoryLabel(product.category) }}</p>
          <h2>{{ product.title }}</h2>
          <p>{{ product.businessName || "Biznesi" }}</p>

          <div>
            <strong>{{ formatPrice(product.price) }}</strong>
            <span v-if="Number(product.compareAtPrice || 0) > Number(product.price || 0)">
              {{ formatPrice(product.compareAtPrice) }}
            </span>
          </div>

          <div>
            <span>
              {{ hasProductAvailableStock(product) ? formatStockQuantity(product.stockQuantity) : "Nuk ka ne stok" }}
            </span>
            <span>
              {{ Number(product.averageRating || 0) > 0 ? `${Number(product.averageRating || 0).toFixed(1)} / 5` : "Pa vleresime" }}
            </span>
            <span>
              {{ Number(product.buyersCount || 0) }} blerje
            </span>
          </div>

          <dl>
            <div v-for="spec in buildSpecs(product)" :key="`${product.id}-${spec.label}`">
              <dt>{{ spec.label }}</dt>
              <dd>{{ spec.value }}</dd>
            </div>
          </dl>

          <div>
            <RouterLink :to="getProductDetailUrl(product.id)">
              Hape produktin
            </RouterLink>
          </div>
        </div>
      </article>
    </section>
  </section>
</template>
