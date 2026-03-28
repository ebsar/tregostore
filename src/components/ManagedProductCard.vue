<script setup>
import { computed } from "vue";
import { RouterLink, useRoute } from "vue-router";
import {
  formatCategoryLabel,
  formatPrice,
  formatProductColorLabel,
  formatProductTypeLabel,
  formatStockQuantity,
  getProductDetailUrl,
} from "../lib/shop";

const props = defineProps({
  product: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits([
  "edit",
  "delete",
  "toggle-visibility",
  "toggle-stock-public",
]);
const route = useRoute();
const detailUrl = computed(() => getProductDetailUrl(props.product.id, route.fullPath));

const visibilityLabel = computed(() =>
  props.product.isPublic ? "Mshehe nga userat" : "Shfaqe per userat",
);

const stockLabel = computed(() =>
  props.product.showStockPublic && Number(props.product.stockQuantity) > 0
    ? "Fshehe stokun"
    : "Shfaqe si ne stok",
);

const details = computed(() =>
  [
    formatProductTypeLabel(props.product.productType),
    props.product.size ? `Madhesia ${props.product.size}` : "",
    props.product.color ? `Ngjyra ${formatProductColorLabel(props.product.color)}` : "",
    `Stok ${formatStockQuantity(props.product.stockQuantity)}`,
    props.product.isPublic ? "Publik" : "I fshehur",
    props.product.showStockPublic && Number(props.product.stockQuantity) > 0
      ? "Stoku duket publikisht"
      : "Stoku eshte privat",
  ].filter(Boolean),
);
</script>

<template>
  <article class="admin-product-item" :class="{ 'is-hidden': !product.isPublic }">
    <RouterLink class="admin-product-link" :to="detailUrl">
      <div class="admin-product-thumb-wrap">
        <img
          class="admin-product-thumb"
          :src="product.imagePath"
          :alt="product.title"
          width="640"
          height="640"
          loading="lazy"
          decoding="async"
        >
      </div>
    </RouterLink>

    <div class="admin-product-copy">
      <div class="admin-product-head-meta">
        <p class="admin-product-meta">{{ formatCategoryLabel(product.category) }}</p>
        <p v-if="product.articleNumber" class="admin-product-article">Nr. {{ product.articleNumber }}</p>
      </div>
      <h3>
        <RouterLink class="admin-product-title-link" :to="detailUrl">
          {{ product.title }}
        </RouterLink>
      </h3>
      <p>{{ product.description }}</p>
      <div class="product-detail-tags product-detail-tags-admin">
        <span
          v-for="detail in details"
          :key="detail"
          class="product-detail-tag"
        >
          {{ detail }}
        </span>
      </div>
    </div>

    <div class="admin-product-side">
      <strong class="admin-product-price">{{ formatPrice(product.price) }}</strong>
      <div class="admin-product-controls">
        <button class="product-action-button admin-action-button" type="button" @click="$emit('edit', product)">
          <span>Edito artikullin</span>
        </button>

        <button class="product-action-button admin-action-button" type="button" @click="$emit('toggle-visibility', product)">
          <span>{{ visibilityLabel }}</span>
        </button>

        <button class="product-action-button admin-action-button" type="button" @click="$emit('toggle-stock-public', product)">
          <span>{{ stockLabel }}</span>
        </button>

        <button class="product-action-button admin-action-button admin-action-danger" type="button" @click="$emit('delete', product)">
          <span>Fshije produktin</span>
        </button>
      </div>
    </div>
  </article>
</template>
