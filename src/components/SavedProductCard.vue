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
  "set-quantity",
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
const productColorLabel = computed(() =>
  props.product.color ? formatProductColorLabel(props.product.color) : "Standard",
);
const productSizeLabel = computed(() => String(props.product.size || "Standard").trim() || "Standard");
const quantityOptions = computed(() => {
  const currentQuantity = Math.max(1, Number(props.product.quantity) || 1);
  const stockQuantity = Math.max(0, Number(props.product.stockQuantity) || 0);
  const limit = Math.min(10, Math.max(currentQuantity, stockQuantity || currentQuantity));
  return Array.from({ length: limit }, (_, index) => index + 1);
});
const cartLineTotal = computed(() =>
  (Math.max(1, Number(props.product.quantity) || 1) * (Number(props.product.price) || 0)),
);

function handleQuantityChange(event) {
  const nextQuantity = Math.max(1, Number(event?.target?.value || props.product.quantity || 1));
  emit("set-quantity", { productId: props.product.id, quantity: nextQuantity });
}
</script>

<template>
  <article
    class="saved-product-card"
    :class="{
      selectable: selectionEnabled && mode !== 'cart',
      'is-selected': selected,
      'is-unavailable': isUnavailable,
      'saved-product-card--cart': mode === 'cart',
      'saved-product-card--later': mode === 'later',
      'saved-product-card--wishlist': mode === 'wishlist',
    }"
    :aria-label="product.title"
  >
    <template v-if="mode === 'cart'">
      <div class="saved-product-image-wrap saved-product-image-wrap--cart">
        <img
          class="saved-product-image saved-product-image--cart"
          :src="product.imagePath"
          :alt="product.title"
          width="640"
          height="640"
          loading="lazy"
          decoding="async"
        >
      </div>

      <div class="saved-product-copy saved-product-copy--cart">
        <h3 class="saved-product-title-cart">{{ product.title }}</h3>
        <p class="saved-product-spec-line">
          <span>Color:</span>
          <strong>{{ productColorLabel }}</strong>
        </p>
        <p class="saved-product-spec-line">
          <span>Size:</span>
          <strong>{{ productSizeLabel }}</strong>
        </p>
        <p class="saved-product-spec-line">
          <span>Price:</span>
          <strong>{{ formatPrice(product.price) }} / per item</strong>
        </p>
        <p v-if="isUnavailable" class="saved-product-stock-inline">{{ stockMessage }}</p>
      </div>

      <div class="saved-product-side saved-product-side--cart">
        <strong class="saved-product-price saved-product-price--cart">{{ formatPrice(cartLineTotal) }}</strong>

        <div class="saved-product-controls">
          <label class="saved-product-qty-select">
            <span>Qty:</span>
            <select
              class="saved-product-qty-input"
              :value="Math.max(1, Number(product.quantity) || 1)"
              :disabled="isUnavailable"
              @change="handleQuantityChange"
            >
              <option
                v-for="quantity in quantityOptions"
                :key="`qty-${product.id}-${quantity}`"
                :value="quantity"
              >
                {{ quantity }}
              </option>
            </select>
          </label>

          <button
            class="saved-product-icon-button"
            type="button"
            aria-label="Ruaj per me vone"
            @click="emit('save-for-later', product)"
          >
            <svg viewBox="0 0 24 24" aria-hidden="true">
              <path d="M7 4h10a1 1 0 0 1 1 1v15l-6-3-6 3V5a1 1 0 0 1 1-1Z"></path>
            </svg>
          </button>

          <button
            class="saved-product-icon-button saved-product-icon-button--danger"
            type="button"
            aria-label="Hiqe nga cart"
            @click="emit('remove', product.id)"
          >
            <svg viewBox="0 0 24 24" aria-hidden="true">
              <path d="M6.5 6.5 17.5 17.5M17.5 6.5 6.5 17.5"></path>
            </svg>
          </button>
        </div>
      </div>
    </template>

    <template v-else>
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
    </template>
  </article>
</template>

<style scoped>
.saved-product-card--cart {
  display: grid;
  grid-template-columns: 76px minmax(0, 1fr) auto;
  gap: 14px;
  align-items: center;
  padding: 10px;
  border: 0;
  border-radius: 0;
  background: transparent;
  box-shadow: none;
  backdrop-filter: none;
  -webkit-backdrop-filter: none;
}

.saved-product-image-wrap--cart {
  min-height: 76px;
  padding: 8px;
  border-radius: 10px;
  background: #f3f6fb;
  box-shadow: none;
}

.saved-product-image--cart {
  max-width: 58px;
}

.saved-product-copy--cart {
  gap: 2px;
  align-self: stretch;
  justify-content: center;
}

.saved-product-title-cart {
  margin: 0 0 4px;
  color: #111827;
  font-size: 0.95rem;
  line-height: 1.25;
  font-weight: 800;
}

.saved-product-spec-line {
  margin: 0;
  color: #6b7280;
  font-size: 0.75rem;
  line-height: 1.45;
}

.saved-product-spec-line span {
  color: #64748b;
}

.saved-product-spec-line strong {
  color: #64748b;
  font-weight: 500;
}

.saved-product-stock-inline {
  margin: 4px 0 0;
  color: #b91c1c;
  font-size: 0.73rem;
  line-height: 1.35;
}

.saved-product-side--cart {
  display: grid;
  justify-items: end;
  gap: 12px;
  min-width: 180px;
}

.saved-product-price--cart {
  color: #111827;
  font-size: 0.95rem;
  font-weight: 800;
}

.saved-product-controls {
  display: flex;
  align-items: center;
  gap: 8px;
}

.saved-product-qty-select {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  min-height: 34px;
  padding: 0 10px;
  border-radius: 8px;
  border: 1px solid #dbe2ea;
  background: #fff;
  color: #475569;
  font-size: 0.8rem;
  font-weight: 700;
}

.saved-product-qty-input {
  border: 0;
  background: transparent;
  color: inherit;
  font: inherit;
  outline: none;
  cursor: pointer;
}

.saved-product-icon-button {
  width: 34px;
  height: 34px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  border-radius: 8px;
  border: 1px solid #dbe2ea;
  background: #fff;
  color: #64748b;
  cursor: pointer;
  transition: transform 0.18s ease, border-color 0.18s ease, color 0.18s ease;
}

.saved-product-icon-button:hover {
  transform: translateY(-1px);
  border-color: #cbd5e1;
}

.saved-product-icon-button--danger:hover {
  color: #b91c1c;
}

.saved-product-icon-button svg {
  width: 18px;
  height: 18px;
  fill: none;
  stroke: currentColor;
  stroke-width: 1.8;
  stroke-linecap: round;
  stroke-linejoin: round;
}

@media (max-width: 760px) {
  .saved-product-card--cart {
    grid-template-columns: 64px minmax(0, 1fr);
    gap: 12px;
  }

  .saved-product-side--cart {
    grid-column: 1 / -1;
    grid-template-columns: 1fr;
    justify-items: stretch;
    min-width: 0;
  }

  .saved-product-price--cart {
    justify-self: end;
  }

  .saved-product-controls {
    flex-wrap: wrap;
    justify-content: flex-end;
  }
}
</style>
