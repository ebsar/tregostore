<script setup>
import { computed } from "vue";

const props = defineProps({
  count: {
    type: Number,
    default: 10,
  },
  variant: {
    type: String,
    default: "catalog",
  },
});

const items = computed(() =>
  Array.from({ length: Math.max(1, Number(props.count || 10)) }, (_, index) => index + 1),
);
</script>

<template>
  <section
    v-if="variant === 'catalog'"
    class="pet-products-grid product-list-skeleton"
    aria-hidden="true"
  >
    <article
      v-for="item in items"
      :key="`catalog-${item}`"
      class="pet-product-card product-card-skeleton"
    >
      <div class="pet-product-image-wrap product-card-skeleton-image"></div>

      <div class="pet-product-content">
        <div class="product-card-skeleton-line product-card-skeleton-label"></div>
        <div class="product-card-skeleton-line product-card-skeleton-title"></div>
        <div class="product-card-skeleton-line product-card-skeleton-copy"></div>
        <div class="product-card-skeleton-line product-card-skeleton-copy is-short"></div>

        <div class="product-card-skeleton-tags">
          <span class="product-card-skeleton-tag"></span>
          <span class="product-card-skeleton-tag"></span>
        </div>

        <div class="pet-product-footer">
          <span class="product-card-skeleton-line product-card-skeleton-price"></span>
          <span class="product-card-skeleton-line product-card-skeleton-link"></span>
        </div>

        <div class="product-card-actions">
          <span class="product-card-skeleton-action"></span>
          <span class="product-card-skeleton-action"></span>
        </div>
      </div>
    </article>
  </section>

  <div
    v-else
    class="admin-products-list product-list-skeleton"
    aria-hidden="true"
  >
    <article
      v-for="item in items"
      :key="`managed-${item}`"
      class="admin-product-item managed-product-skeleton"
    >
      <div class="admin-product-thumb-wrap managed-product-skeleton-thumb"></div>

      <div class="admin-product-copy managed-product-skeleton-copy">
        <div class="product-card-skeleton-line managed-product-skeleton-label"></div>
        <div class="product-card-skeleton-line managed-product-skeleton-title"></div>
        <div class="product-card-skeleton-line managed-product-skeleton-copy-line"></div>
      </div>

      <div class="admin-product-side managed-product-skeleton-side">
        <span class="product-card-skeleton-line managed-product-skeleton-price"></span>
        <span class="product-card-skeleton-action managed-product-skeleton-button"></span>
        <span class="product-card-skeleton-action managed-product-skeleton-button"></span>
      </div>
    </article>
  </div>
</template>
