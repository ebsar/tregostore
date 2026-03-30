<script setup>
import { computed } from "vue";
import {
  formatCategoryLabel,
  formatPrice,
  formatProductColorLabel,
  formatProductTypeLabel,
  getProductStockMessage,
  hasProductAvailableStock,
} from "../lib/shop";

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

const emit = defineEmits([
  "toggle-select",
  "remove",
  "add-to-cart",
  "increase-quantity",
  "decrease-quantity",
  "save-for-later",
]);

const details = computed(() =>
  [
    formatProductTypeLabel(props.product.productType),
    props.product.size ? `Madhesia: ${props.product.size}` : "",
    props.product.color ? `Ngjyra: ${formatProductColorLabel(props.product.color)}` : "",
    hasProductAvailableStock(props.product) ? "Ne stok" : "Nuk ka ne stok",
  ].filter(Boolean),
);
const isUnavailable = computed(() => !hasProductAvailableStock(props.product));
const stockMessage = computed(() => getProductStockMessage(props.product));
</script>

<template>
  <article
    class="saved-product-card"
    :class="{ selectable: selectionEnabled, 'is-selected': selected, 'is-unavailable': isUnavailable }"
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
      <p v-if="mode === 'later'" class="saved-product-state">Ruajtur per me vone</p>
      <p v-if="isUnavailable" class="saved-product-state saved-product-state-warning">
        {{ stockMessage }}
      </p>
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
            :disabled="Number(product.quantity) <= 1 || isUnavailable"
            aria-label="Ule sasine"
            @click="emit('decrease-quantity', product.id)"
          >
            -
          </button>
          <span class="saved-product-quantity">{{ product.quantity }}</span>
          <button
            class="cart-quantity-button"
            type="button"
            :disabled="isUnavailable"
            aria-label="Rrite sasine"
            @click="emit('increase-quantity', product.id)"
          >
            +
          </button>
        </div>
      </div>

      <div v-else-if="mode === 'later'" class="saved-product-summary saved-product-summary-later">
        <strong class="saved-product-price">{{ formatPrice(product.price) }}</strong>
        <span class="saved-product-later-quantity">Sasia: {{ product.quantity }}</span>
      </div>

      <strong v-else class="saved-product-price">{{ formatPrice(product.price) }}</strong>
    </div>

    <div
      class="saved-product-actions"
      :class="{
        'saved-product-actions-cart': mode === 'cart',
        'saved-product-actions-later': mode === 'later',
      }"
    >
      <button
        v-if="mode === 'cart'"
        class="product-action-button later-action"
        type="button"
        @click="emit('save-for-later', product)"
      >
        <svg class="nav-icon" viewBox="0 0 24 24" aria-hidden="true">
          <path d="M7 4h10a1 1 0 0 1 1 1v15l-6-3-6 3V5a1 1 0 0 1 1-1Z"></path>
        </svg>
        <span>Ruaj per me vone</span>
      </button>

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
        :disabled="isUnavailable"
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

      <button
        v-if="mode === 'later'"
        class="product-action-button cart-action active"
        type="button"
        :disabled="isUnavailable"
        @click="emit('add-to-cart', product)"
      >
        <svg class="nav-icon" viewBox="0 0 24 24" aria-hidden="true">
          <path d="M3 5h2l2.1 9.1a1 1 0 0 0 1 .8h8.8a1 1 0 0 0 1-.8L20 8H7.2"></path>
          <circle cx="10" cy="19" r="1.4"></circle>
          <circle cx="18" cy="19" r="1.4"></circle>
        </svg>
        <span>Ktheje ne cart</span>
      </button>

      <button
        v-if="mode === 'later'"
        class="product-action-button later-action later-action-remove"
        type="button"
        @click="emit('remove', product)"
      >
        <svg class="nav-icon" viewBox="0 0 24 24" aria-hidden="true">
          <path d="M6.5 6.5 17.5 17.5M17.5 6.5 6.5 17.5"></path>
        </svg>
        <span>Hiqe</span>
      </button>
    </div>
  </article>
</template>
