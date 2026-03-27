<script setup>
import { computed } from "vue";
import { useRoute } from "vue-router";
import { formatCategoryLabel, formatPrice, formatProductColorLabel, formatProductTypeLabel, getProductDetailUrl } from "../lib/shop";

const props = defineProps({
  product: {
    type: Object,
    required: true,
  },
  isWishlisted: {
    type: Boolean,
    default: false,
  },
  isInCart: {
    type: Boolean,
    default: false,
  },
  wishlistBusy: {
    type: Boolean,
    default: false,
  },
  cartBusy: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(["wishlist", "cart"]);
const route = useRoute();

const detailUrl = computed(() => getProductDetailUrl(props.product.id, route.fullPath));
const details = computed(() =>
  [
    formatProductTypeLabel(props.product.productType),
    props.product.size ? `Madhesia: ${props.product.size}` : "",
    props.product.color ? `Ngjyra: ${formatProductColorLabel(props.product.color)}` : "",
    props.product.showStockPublic && Number(props.product.stockQuantity) > 0 ? "Ne stok" : "",
  ].filter(Boolean),
);
</script>

<template>
  <article class="pet-product-card" :aria-label="product.title">
    <RouterLink class="pet-product-link" :to="detailUrl" :aria-label="`Hape produktin ${product.title}`">
      <div class="pet-product-image-wrap">
        <img
          class="pet-product-image"
          :src="product.imagePath"
          :alt="product.title"
          loading="lazy"
          decoding="async"
        >
      </div>
    </RouterLink>

    <div class="pet-product-content">
      <p class="pet-product-label">{{ formatCategoryLabel(product.category) }}</p>
      <h3>
        <RouterLink class="pet-product-title-link" :to="detailUrl">
          {{ product.title }}
        </RouterLink>
      </h3>
      <p class="pet-product-description">{{ product.description }}</p>

      <div class="product-detail-tags">
        <span
          v-for="detail in details"
          :key="detail"
          class="product-detail-tag"
        >
          {{ detail }}
        </span>
      </div>

      <div class="pet-product-footer">
        <strong class="pet-product-price">{{ formatPrice(product.price) }}</strong>
        <RouterLink class="pet-product-more" :to="detailUrl">
          Shiko produktin
        </RouterLink>
      </div>

      <div class="product-card-actions">
        <button
          class="product-action-button wishlist-action"
          :class="{ active: isWishlisted }"
          type="button"
          :disabled="wishlistBusy"
          aria-label="Wishlist"
          @click="emit('wishlist', product.id)"
        >
          <svg class="nav-icon" viewBox="0 0 24 24" aria-hidden="true">
            <path d="M12 20.4 4.9 13.8a4.8 4.8 0 0 1 6.8-6.8l.3.3.3-.3a4.8 4.8 0 1 1 6.8 6.8Z"></path>
          </svg>
          <span>Wishlist</span>
        </button>

        <button
          class="product-action-button cart-action"
          :class="{ active: isInCart }"
          type="button"
          :disabled="cartBusy"
          aria-label="Cart"
          @click="emit('cart', product.id)"
        >
          <svg class="nav-icon" viewBox="0 0 24 24" aria-hidden="true">
            <path d="M3 5h2l2.1 9.1a1 1 0 0 0 1 .8h8.8a1 1 0 0 0 1-.8L20 8H7.2"></path>
            <circle cx="10" cy="19" r="1.4"></circle>
            <circle cx="18" cy="19" r="1.4"></circle>
          </svg>
          <span>{{ isInCart ? "Ne cart" : "Shto ne cart" }}</span>
        </button>
      </div>
    </div>
  </article>
</template>
