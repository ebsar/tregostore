<script setup>
import ProductCard from "./ProductCard.vue";

defineProps({
  sections: {
    type: Array,
    default: () => [],
  },
  wishlistIds: {
    type: Array,
    default: () => [],
  },
  cartIds: {
    type: Array,
    default: () => [],
  },
  busyWishlistIds: {
    type: Array,
    default: () => [],
  },
  busyCartIds: {
    type: Array,
    default: () => [],
  },
  comparedProductIds: {
    type: Array,
    default: () => [],
  },
  showOverlayActions: {
    type: Boolean,
    default: true,
  },
  showBusinessName: {
    type: Boolean,
    default: true,
  },
});

const emit = defineEmits(["wishlist", "cart", "compare"]);
</script>

<template>
  <section
    v-for="section in sections"
    :key="section.key"
    class="card glass recommendation-section"
    :aria-label="section.title"
  >
    <header class="recommendation-section-head">
      <div>
        <p class="section-label">RECOMMENDATIONS</p>
        <h2>{{ section.title }}</h2>
      </div>
      <p v-if="section.subtitle" class="section-text recommendation-section-copy">
        {{ section.subtitle }}
      </p>
    </header>

    <section class="pet-products-grid recommendation-section-grid">
      <ProductCard
        v-for="product in section.products"
        :key="`${section.key}-${product.id}`"
        :product="product"
        :is-wishlisted="wishlistIds.includes(product.id)"
        :is-in-cart="cartIds.includes(product.id)"
        :wishlist-busy="busyWishlistIds.includes(product.id)"
        :cart-busy="busyCartIds.includes(product.id)"
        :is-compared="comparedProductIds.includes(product.id)"
        :show-overlay-actions="showOverlayActions"
        :show-business-name="showBusinessName"
        @wishlist="emit('wishlist', $event)"
        @cart="emit('cart', $event)"
        @compare="emit('compare', $event)"
      />
    </section>
  </section>
</template>

<style scoped>
.recommendation-section {
  display: grid;
  gap: 20px;
  padding: clamp(18px, 3vw, 28px);
}

.recommendation-section-head {
  display: grid;
  gap: 10px;
}

.recommendation-section-head h2 {
  margin: 0;
}

.recommendation-section-copy {
  margin: 0;
  max-width: 62ch;
}

.recommendation-section-grid {
  align-items: stretch;
}

@media (max-width: 720px) {
  .recommendation-section {
    gap: 16px;
    padding: 16px;
  }

  .recommendation-section-copy {
    font-size: 0.9rem;
  }
}
</style>
