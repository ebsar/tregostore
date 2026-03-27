<script setup>
import { computed } from "vue";
import { formatCategoryLabel, formatPrice, formatProductColorLabel, formatProductTypeLabel } from "../lib/shop";

const props = defineProps({
  product: {
    type: Object,
    required: true,
  },
  mode: {
    type: String,
    default: "wishlist",
  },
  selectionEnabled: {
    type: Boolean,
    default: false,
  },
  selected: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(["toggle-select", "remove", "add-to-cart", "increase-quantity", "decrease-quantity"]);

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
  <article
    class="saved-product-card"
    :class="{ selectable: selectionEnabled, 'is-selected': selected }"
    :aria-label="product.title"
  >
    <div v-if="selectionEnabled" class="saved-product-selector-row">
      <label class="saved-product-selector">
        <input
          type="checkbox"
          :checked="selected"
          @change="emit('toggle-select', product.id)"
        >
        <span>{{ mode === "cart" ? "Perfshije ne porosi" : "Zgjidhe per blerje" }}</span>
      </label>
    </div>

    <div class="saved-product-image-wrap">
      <img
        class="saved-product-image"
        :src="product.imagePath"
        :alt="product.title"
        width="640"
        height="640"
        loading="lazy"
        decoding="async"
      >
    </div>

    <div class="saved-product-copy">
      <p class="saved-product-meta">{{ formatCategoryLabel(product.category) }}</p>
      <h3>{{ product.title }}</h3>
      <p>{{ product.description }}</p>

      <div class="product-detail-tags product-detail-tags-saved">
        <span
          v-for="detail in details"
          :key="detail"
          class="product-detail-tag"
        >
          {{ detail }}
        </span>
      </div>

      <div v-if="mode === 'cart'" class="saved-product-summary">
        <strong class="saved-product-price">{{ formatPrice(product.price) }}</strong>
        <div class="cart-quantity-control" aria-label="Ndrysho sasine e produktit">
          <button
            class="cart-quantity-button"
            type="button"
            :disabled="Number(product.quantity) <= 1"
            aria-label="Ule sasine"
            @click="emit('decrease-quantity', product.id)"
          >
            -
          </button>
          <span class="saved-product-quantity">{{ product.quantity }}</span>
          <button
            class="cart-quantity-button"
            type="button"
            aria-label="Rrite sasine"
            @click="emit('increase-quantity', product.id)"
          >
            +
          </button>
        </div>
      </div>

      <strong v-else class="saved-product-price">{{ formatPrice(product.price) }}</strong>
    </div>

    <div class="saved-product-actions">
      <button
        v-if="mode === 'wishlist'"
        class="product-action-button wishlist-action active"
        type="button"
        @click="emit('remove', product.id)"
      >
        <svg class="nav-icon" viewBox="0 0 24 24" aria-hidden="true">
          <path d="M12 20.4 4.9 13.8a4.8 4.8 0 0 1 6.8-6.8l.3.3.3-.3a4.8 4.8 0 1 1 6.8 6.8Z"></path>
        </svg>
        <span>Hiqe</span>
      </button>

      <button
        v-if="mode === 'wishlist'"
        class="product-action-button cart-action"
        type="button"
        @click="emit('add-to-cart', product.id)"
      >
        <svg class="nav-icon" viewBox="0 0 24 24" aria-hidden="true">
          <path d="M3 5h2l2.1 9.1a1 1 0 0 0 1 .8h8.8a1 1 0 0 0 1-.8L20 8H7.2"></path>
          <circle cx="10" cy="19" r="1.4"></circle>
          <circle cx="18" cy="19" r="1.4"></circle>
        </svg>
        <span>Shto ne cart</span>
      </button>

      <button
        v-if="mode === 'cart'"
        class="product-action-button cart-action active"
        type="button"
        @click="emit('remove', product.id)"
      >
        <svg class="nav-icon" viewBox="0 0 24 24" aria-hidden="true">
          <path d="M3 5h2l2.1 9.1a1 1 0 0 0 1 .8h8.8a1 1 0 0 0 1-.8L20 8H7.2"></path>
          <circle cx="10" cy="19" r="1.4"></circle>
          <circle cx="18" cy="19" r="1.4"></circle>
        </svg>
        <span>Hiqe nga cart</span>
      </button>
    </div>
  </article>
</template>
