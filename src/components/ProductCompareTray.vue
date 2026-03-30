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
      <div class="compare-tray-copy">
        <p class="section-label">Krahasim</p>
        <strong>{{ compareSummary }}</strong>
        <p>{{ compareHint }}</p>
      </div>

      <div class="compare-tray-previews" aria-hidden="true">
        <RouterLink
          v-for="item in comparePreviewItems"
          :key="item.id"
          class="compare-tray-thumb"
          :to="getProductDetailUrl(item.id)"
        >
          <img :src="item.imagePath" :alt="item.title" width="80" height="80">
        </RouterLink>
      </div>

      <div class="compare-tray-actions">
        <RouterLink class="nav-action nav-action-secondary compare-tray-link" to="/krahaso-produkte">
          Krahaso
        </RouterLink>
        <button class="nav-action nav-action-primary compare-tray-clear" type="button" @click="handleClearComparedProducts">
          Pastro
        </button>
      </div>
    </aside>
  </Transition>
</template>
