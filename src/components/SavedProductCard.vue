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
    :class="[
      `saved-product-card--${mode}`,
      {
        'is-selected': selected,
        'is-unavailable': isUnavailable,
      },
    ]"
    :aria-label="product.title"
  >
    <template v-if="mode === 'cart'">
      <div class="saved-product-card__media">
        <img
          class="saved-product-card__image"
          :src="product.imagePath"
          :alt="product.title"
          width="640"
          height="640"
          loading="lazy"
          decoding="async"
        >
      </div>

      <div class="saved-product-card__body">
        <div class="saved-product-card__head">
          <h3>{{ product.title }}</h3>
          <p v-if="isUnavailable" class="saved-product-card__stock saved-product-card__stock--error">{{ stockMessage }}</p>
        </div>

        <div class="saved-product-card__facts">
          <p>
            <span>Color</span>
            <strong>{{ productColorLabel }}</strong>
          </p>
          <p>
            <span>Size</span>
            <strong>{{ productSizeLabel }}</strong>
          </p>
          <p>
            <span>Price</span>
            <strong>{{ formatPrice(product.price) }} / item</strong>
          </p>
        </div>
      </div>

      <div class="saved-product-card__summary">
        <strong>{{ formatPrice(cartLineTotal) }}</strong>

        <div class="saved-product-card__quantity">
          <label>
            <span>Qty</span>
            <select
              class="saved-product-card__quantity-select"
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
            class="saved-product-card__icon-button"
            type="button"
            aria-label="Ruaj per me vone"
            @click="emit('save-for-later', product)"
          >
            <svg viewBox="0 0 24 24" aria-hidden="true">
              <path d="M7 4h10a1 1 0 0 1 1 1v15l-6-3-6 3V5a1 1 0 0 1 1-1Z"></path>
            </svg>
          </button>

          <button
            class="saved-product-card__icon-button"
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
      <div v-if="selectionEnabled" class="saved-product-card__selector">
        <label>
          <input
            type="checkbox"
            :checked="selected"
            @change="emit('toggle-select', product.id)"
          >
          <span>{{ mode === "cart" ? "Perfshije ne porosi" : "Zgjidhe per blerje" }}</span>
        </label>
      </div>

      <div class="saved-product-card__media">
        <img
          class="saved-product-card__image"
          :src="product.imagePath"
          :alt="product.title"
          width="640"
          height="640"
          loading="lazy"
          decoding="async"
        >
      </div>

      <div class="saved-product-card__body">
        <div class="saved-product-card__head">
          <p class="saved-product-card__eyebrow">{{ formatCategoryLabel(product.category) }}</p>
          <p v-if="mode === 'later'" class="saved-product-card__eyebrow">Ruajtur per me vone</p>
          <p v-if="isUnavailable" class="saved-product-card__stock saved-product-card__stock--error">
            {{ stockMessage }}
          </p>
          <h3>{{ product.title }}</h3>
          <p class="saved-product-card__description">{{ product.description }}</p>
        </div>

        <div class="saved-product-card__chips">
          <span
            v-for="detail in details"
            :key="detail"
            class="saved-product-card__chip"
          >
            {{ detail }}
          </span>
        </div>

        <div v-if="mode === 'later'" class="saved-product-card__price-row">
          <strong>{{ formatPrice(product.price) }}</strong>
          <span>Sasia: {{ product.quantity }}</span>
        </div>

        <strong v-else class="saved-product-card__price">{{ formatPrice(product.price) }}</strong>
      </div>

      <div class="saved-product-card__actions">
        <button
          v-if="mode === 'wishlist'"
          class="market-button market-button--secondary"
          type="button"
          @click="emit('remove', product.id)"
        >
          <svg viewBox="0 0 24 24" aria-hidden="true">
            <path d="M12 20.4 4.9 13.8a4.8 4.8 0 0 1 6.8-6.8l.3.3.3-.3a4.8 4.8 0 1 1 6.8 6.8Z"></path>
          </svg>
          <span>Hiqe</span>
        </button>

        <button
          v-if="mode === 'wishlist'"
          class="market-button market-button--primary"
          type="button"
          :disabled="isUnavailable"
          @click="emit('add-to-cart', product.id)"
        >
          <svg viewBox="0 0 24 24" aria-hidden="true">
            <path d="M3 5h2l2.1 9.1a1 1 0 0 0 1 .8h8.8a1 1 0 0 0 1-.8L20 8H7.2"></path>
            <circle cx="10" cy="19" r="1.4"></circle>
            <circle cx="18" cy="19" r="1.4"></circle>
          </svg>
          <span>Shto ne cart</span>
        </button>

        <button
          v-if="mode === 'later'"
          class="market-button market-button--primary"
          type="button"
          :disabled="isUnavailable"
          @click="emit('add-to-cart', product)"
        >
          <svg viewBox="0 0 24 24" aria-hidden="true">
            <path d="M3 5h2l2.1 9.1a1 1 0 0 0 1 .8h8.8a1 1 0 0 0 1-.8L20 8H7.2"></path>
            <circle cx="10" cy="19" r="1.4"></circle>
            <circle cx="18" cy="19" r="1.4"></circle>
          </svg>
          <span>Ktheje ne cart</span>
        </button>

        <button
          v-if="mode === 'later'"
          class="market-button market-button--secondary"
          type="button"
          @click="emit('remove', product)"
        >
          <svg viewBox="0 0 24 24" aria-hidden="true">
            <path d="M6.5 6.5 17.5 17.5M17.5 6.5 6.5 17.5"></path>
          </svg>
          <span>Hiqe</span>
        </button>
      </div>
    </template>
  </article>
</template>

<style scoped>
.saved-product-card {
  position: relative;
  min-width: 0;
  height: 100%;
  display: grid;
  gap: 14px;
  padding: 14px;
  border: 1px solid var(--dashboard-border);
  border-radius: var(--dashboard-radius);
  background: #ffffff;
  box-shadow: 0 12px 28px rgba(17, 17, 17, 0.04);
}

.saved-product-card.is-selected {
  border-color: var(--dashboard-accent-border);
  background: linear-gradient(180deg, var(--dashboard-accent-soft) 0%, #ffffff 62%);
}

.saved-product-card.is-unavailable {
  opacity: 0.72;
}

.saved-product-card--cart {
  grid-template-columns: 96px minmax(0, 1fr) minmax(180px, auto);
  align-items: start;
}

.saved-product-card__media {
  aspect-ratio: 1 / 1;
  overflow: hidden;
  border-radius: 10px;
  background: #f2f2f2;
}

.saved-product-card__image {
  width: 100%;
  height: 100%;
  display: block;
  object-fit: cover;
}

.saved-product-card__body,
.saved-product-card__head {
  min-width: 0;
  display: grid;
  gap: 8px;
}

.saved-product-card__eyebrow,
.saved-product-card__description,
.saved-product-card__stock,
.saved-product-card__facts span,
.saved-product-card__price-row span {
  margin: 0;
  color: var(--dashboard-muted);
  font-size: 12px;
  line-height: 1.45;
}

.saved-product-card__eyebrow {
  color: var(--dashboard-accent);
  font-weight: 700;
  letter-spacing: 0.04em;
  text-transform: uppercase;
}

.saved-product-card__stock--error {
  color: var(--dashboard-danger);
  font-weight: 650;
}

.saved-product-card h3 {
  margin: 0;
  color: var(--dashboard-text);
  font-size: 15px;
  font-weight: 700;
  line-height: 1.35;
}

.saved-product-card__description {
  display: -webkit-box;
  overflow: hidden;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
}

.saved-product-card__chips {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}

.saved-product-card__chip {
  display: inline-flex;
  align-items: center;
  min-height: 26px;
  padding: 0 9px;
  border: 1px solid #ececec;
  border-radius: 999px;
  background: #fafafa;
  color: var(--dashboard-muted);
  font-size: 11px;
  font-weight: 650;
}

.saved-product-card__price,
.saved-product-card__price-row strong,
.saved-product-card__summary > strong {
  color: var(--dashboard-text);
  font-size: 17px;
  font-weight: 800;
}

.saved-product-card__price-row,
.saved-product-card__facts {
  display: grid;
  gap: 8px;
}

.saved-product-card__facts p {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  margin: 0;
}

.saved-product-card__facts strong {
  color: var(--dashboard-text);
  font-size: 13px;
}

.saved-product-card__summary {
  display: grid;
  justify-items: end;
  gap: 14px;
}

.saved-product-card__quantity {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  flex-wrap: wrap;
  gap: 8px;
}

.saved-product-card__quantity label,
.saved-product-card__selector label {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  color: var(--dashboard-muted);
  font-size: 12px;
  font-weight: 650;
}

.saved-product-card__quantity-select {
  min-height: 34px;
  border: 1px solid var(--dashboard-border);
  border-radius: 10px;
  background: #ffffff;
  color: var(--dashboard-text);
}

.saved-product-card__selector {
  position: absolute;
  top: 12px;
  left: 12px;
  z-index: 2;
  padding: 7px 9px;
  border: 1px solid rgba(17, 17, 17, 0.08);
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.94);
}

.saved-product-card__actions {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 8px;
}

.saved-product-card__actions .market-button {
  width: 100%;
  min-height: 38px;
  justify-content: center;
  padding: 0 10px;
}

.saved-product-card__actions svg,
.saved-product-card__icon-button svg {
  width: 16px;
  height: 16px;
  fill: none;
  stroke: currentColor;
  stroke-width: 1.8;
  stroke-linecap: round;
  stroke-linejoin: round;
}

.saved-product-card__icon-button {
  width: 34px;
  height: 34px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  border: 1px solid var(--dashboard-border);
  border-radius: 10px;
  background: #ffffff;
  color: var(--dashboard-text);
  cursor: pointer;
}

@media (max-width: 720px) {
  .saved-product-card--cart {
    grid-template-columns: 82px minmax(0, 1fr);
  }

  .saved-product-card--cart .saved-product-card__summary {
    grid-column: 1 / -1;
    justify-items: stretch;
  }

  .saved-product-card__quantity {
    justify-content: space-between;
  }
}

@media (max-width: 520px) {
  .saved-product-card__actions {
    grid-template-columns: 1fr;
  }
}
</style>
