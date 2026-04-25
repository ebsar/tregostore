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
   
   
    :aria-label="product.title"
  >
    <template v-if="mode === 'cart'">
      <div>
        <img
         
          :src="product.imagePath"
          :alt="product.title"
          width="640"
          height="640"
          loading="lazy"
          decoding="async"
        >
      </div>

      <div>
        <h3>{{ product.title }}</h3>
        <p>
          <span>Color:</span>
          <strong>{{ productColorLabel }}</strong>
        </p>
        <p>
          <span>Size:</span>
          <strong>{{ productSizeLabel }}</strong>
        </p>
        <p>
          <span>Price:</span>
          <strong>{{ formatPrice(product.price) }} / per item</strong>
        </p>
        <p v-if="isUnavailable">{{ stockMessage }}</p>
      </div>

      <div>
        <strong>{{ formatPrice(cartLineTotal) }}</strong>

        <div>
          <label>
            <span>Qty:</span>
            <select
             
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
           
            type="button"
            aria-label="Ruaj per me vone"
            @click="emit('save-for-later', product)"
          >
            <svg viewBox="0 0 24 24" aria-hidden="true">
              <path d="M7 4h10a1 1 0 0 1 1 1v15l-6-3-6 3V5a1 1 0 0 1 1-1Z"></path>
            </svg>
          </button>

          <button
           
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
    <div v-if="selectionEnabled">
      <label>
        <input
          type="checkbox"
          :checked="selected"
          @change="emit('toggle-select', product.id)"
        >
        <span>{{ mode === "cart" ? "Perfshije ne porosi" : "Zgjidhe per blerje" }}</span>
      </label>
    </div>

    <div>
      <img
       
        :src="product.imagePath"
        :alt="product.title"
        width="640"
        height="640"
        loading="lazy"
        decoding="async"
      >
    </div>

    <div>
      <p>{{ formatCategoryLabel(product.category) }}</p>
      <p v-if="mode === 'later'">Ruajtur per me vone</p>
      <p v-if="isUnavailable">
        {{ stockMessage }}
      </p>
      <h3>{{ product.title }}</h3>
      <p>{{ product.description }}</p>

      <div>
        <span
          v-for="detail in details"
          :key="detail"
         
        >
          {{ detail }}
        </span>
      </div>

      <div v-if="mode === 'cart'">
        <strong>{{ formatPrice(product.price) }}</strong>
        <div aria-label="Ndrysho sasine e produktit">
          <button
           
            type="button"
            :disabled="Number(product.quantity) <= 1 || isUnavailable"
            aria-label="Ule sasine"
            @click="emit('decrease-quantity', product.id)"
          >
            -
          </button>
          <span>{{ product.quantity }}</span>
          <button
           
            type="button"
            :disabled="isUnavailable"
            aria-label="Rrite sasine"
            @click="emit('increase-quantity', product.id)"
          >
            +
          </button>
        </div>
      </div>

      <div v-else-if="mode === 'later'">
        <strong>{{ formatPrice(product.price) }}</strong>
        <span>Sasia: {{ product.quantity }}</span>
      </div>

      <strong v-else>{{ formatPrice(product.price) }}</strong>
    </div>

    <div
     
     
    >
      <button
        v-if="mode === 'cart'"
       
        type="button"
        @click="emit('save-for-later', product)"
      >
        <svg viewBox="0 0 24 24" aria-hidden="true">
          <path d="M7 4h10a1 1 0 0 1 1 1v15l-6-3-6 3V5a1 1 0 0 1 1-1Z"></path>
        </svg>
        <span>Ruaj per me vone</span>
      </button>

      <button
        v-if="mode === 'wishlist'"
       
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
        v-if="mode === 'cart'"
       
        type="button"
        @click="emit('remove', product.id)"
      >
        <svg viewBox="0 0 24 24" aria-hidden="true">
          <path d="M3 5h2l2.1 9.1a1 1 0 0 0 1 .8h8.8a1 1 0 0 0 1-.8L20 8H7.2"></path>
          <circle cx="10" cy="19" r="1.4"></circle>
          <circle cx="18" cy="19" r="1.4"></circle>
        </svg>
        <span>Hiqe nga cart</span>
      </button>

      <button
        v-if="mode === 'later'"
       
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

