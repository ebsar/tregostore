<script setup>
import { RouterLink } from "vue-router";
import HomeProductCard from "./HomeProductCard.vue";

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

function getSectionActionTo(section) {
  const key = String(section?.key || "").trim().toLowerCase();

  if (key === "new-arrivals") {
    return {
      path: "/kerko",
      query: {
        sort: "newest",
      },
    };
  }

  if (key === "best-sellers") {
    return {
      path: "/kerko",
      query: {
        sort: "popular",
      },
    };
  }

  return "/kerko";
}
</script>

<template>
  <section
    v-for="section in sections"
    :key="section.key"
    class="product-collection"
    :aria-label="section.title"
  >
    <header class="recommendation-sections__header">
      <h2 class="recommendation-sections__title">
        {{ section.title }}
      </h2>

      <RouterLink
        :to="getSectionActionTo(section)"
        class="recommendation-sections__action"
      >
        View all
      </RouterLink>
    </header>

    <section class="home-product-grid">
      <HomeProductCard
        v-for="product in section.products"
        :key="`${section.key}-${product.id}`"
        :product="product"
        compact
        :is-wishlisted="wishlistIds.includes(product.id)"
        :is-in-cart="cartIds.includes(product.id)"
        :wishlist-busy="busyWishlistIds.includes(product.id)"
        :cart-busy="busyCartIds.includes(product.id)"
        @wishlist="emit('wishlist', $event)"
        @cart="emit('cart', $event)"
      />
    </section>
  </section>
</template>

<style scoped>
.recommendation-sections__header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  margin-bottom: 16px;
}

.recommendation-sections__title {
  margin: 0;
  color: #111111;
  font-size: 22px;
  font-weight: 700;
  line-height: 1.2;
}

.recommendation-sections__action {
  flex-shrink: 0;
  color: #111111;
  text-decoration: none;
  font-size: 13px;
  font-weight: 600;
  line-height: 1;
  transition: opacity 160ms ease;
}

.recommendation-sections__action:hover {
  opacity: 0.66;
}

.home-product-grid {
  display: grid;
  grid-auto-flow: column;
  grid-auto-columns: minmax(0, 232px);
  gap: 14px;
  align-items: start;
  overflow-x: auto;
  overflow-y: hidden;
  padding-bottom: 8px;
  scrollbar-width: none;
}

.home-product-grid::-webkit-scrollbar {
  display: none;
}

@media (max-width: 1180px) {
  .home-product-grid {
    grid-auto-columns: minmax(0, 224px);
  }
}

@media (max-width: 880px) {
  .home-product-grid {
    grid-auto-columns: minmax(0, 206px);
    gap: 12px;
  }
}

@media (max-width: 640px) {
  .recommendation-sections__header {
    margin-bottom: 14px;
  }

  .recommendation-sections__title {
    font-size: 18px;
  }

  .home-product-grid {
    grid-auto-columns: minmax(0, 194px);
  }
}
</style>
