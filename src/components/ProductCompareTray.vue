<script setup>
import { computed, onMounted } from "vue";
import { RouterLink, useRoute } from "vue-router";
import {
  clearComparedProducts,
  compareState,
  ensureCompareItemsLoaded,
} from "../stores/product-compare";
import { getProductDetailUrl } from "../lib/shop";

const route = useRoute();

const showTray = computed(
  () => compareState.items.length > 0 && route.path !== "/krahaso-produkte",
);
const comparePreviewItems = computed(() => compareState.items.slice(0, 3));
const compareSummary = computed(() => {
  const count = compareState.items.length;
  return count === 1 ? "1 produkt i zgjedhur" : `${count} produkte te zgjedhura`;
});
const compareHint = computed(() =>
  compareState.items.length >= 2
    ? "Hape krahasimin dhe shiko dallimet krah per krah."
    : "Shto edhe nje produkt qe krahasimi te jete i plote.",
);

onMounted(() => {
  ensureCompareItemsLoaded();
});

function handleClearComparedProducts() {
  clearComparedProducts();
}
</script>

<template>
  <Transition name="compare-tray">
    <aside v-if="showTray" class="compare-tray" aria-label="Krahasimi i produkteve">
      <div class="compare-tray__head">
        <div>
        <p>Krahasim</p>
        <strong>{{ compareSummary }}</strong>
        <p>{{ compareHint }}</p>
        </div>
      </div>

      <div class="compare-tray__preview" aria-hidden="true">
        <RouterLink
          v-for="item in comparePreviewItems"
          :key="item.id"
          :to="getProductDetailUrl(item.id)"
        >
          <img :src="item.imagePath" :alt="item.title" width="80" height="80" loading="lazy" decoding="async">
        </RouterLink>
      </div>

      <div class="compare-tray__actions">
        <RouterLink class="market-button market-button--primary" to="/krahaso-produkte">
          Krahaso
        </RouterLink>
        <button class="market-button market-button--secondary" type="button" @click="handleClearComparedProducts">
          Pastro
        </button>
      </div>
    </aside>
  </Transition>
</template>
