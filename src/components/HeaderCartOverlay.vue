<script setup>
import { computed, onBeforeUnmount, onMounted, reactive, ref, watch } from "vue";
import { useRouter } from "vue-router";
import { requestJson, resolveApiMessage } from "../lib/api";
import {
  formatPrice,
  getDeliveryMethodOption,
  persistCheckoutSelectedCartIds,
  hasProductAvailableStock,
} from "../lib/shop";
import { appState, setCartItems } from "../stores/app-state";

const emit = defineEmits(["close"]);

const router = useRouter();
const items = ref([]);
const ui = reactive({
  loading: false,
  message: "",
  type: "",
});
const previousBodyOverflow = ref("");

const isAuthenticated = computed(() => Boolean(appState.user));
const subtotal = computed(() =>
  items.value.reduce((total, item) => total + lineTotal(item), 0),
);
const shippingEstimate = computed(() => {
  if (items.value.length <= 0) {
    return 0;
  }

  return Number(getDeliveryMethodOption("standard")?.shippingAmount || 0);
});
const taxEstimate = computed(() => 0);
const orderTotal = computed(() =>
  Math.max(0, subtotal.value + shippingEstimate.value + taxEstimate.value),
);

watch(
  () => appState.cartCount,
  () => {
    if (!isAuthenticated.value || ui.loading) {
      return;
    }

    void loadItems({ preserveMessage: true });
  },
);

watch(
  () => isAuthenticated.value,
  (nextValue) => {
    if (!nextValue) {
      items.value = [];
      return;
    }

    void loadItems({ preserveMessage: true });
  },
);

onMounted(() => {
  previousBodyOverflow.value = document.body.style.overflow;
  document.body.style.overflow = "hidden";
  window.addEventListener("keydown", handleKeydown);

  if (isAuthenticated.value) {
    void loadItems();
  }
});

onBeforeUnmount(() => {
  document.body.style.overflow = previousBodyOverflow.value;
  window.removeEventListener("keydown", handleKeydown);
});

function handleKeydown(event) {
  if (event.key === "Escape") {
    emit("close");
  }
}

async function loadItems(options = {}) {
  const { preserveMessage = false } = options;
  ui.loading = true;
  if (!preserveMessage) {
    ui.message = "";
    ui.type = "";
  }

  try {
    const { response, data } = await requestJson("/api/cart");
    if (!response.ok || !data?.ok) {
      ui.message = resolveApiMessage(data, "Shopping cart could not be loaded.");
      ui.type = "error";
      items.value = [];
      setCartItems([]);
      return;
    }

    items.value = Array.isArray(data.items) ? data.items : [];
    setCartItems(items.value);
  } catch (error) {
    console.error(error);
    ui.message = "The cart is currently unavailable. Please try again.";
    ui.type = "error";
  } finally {
    ui.loading = false;
  }
}

function quantityOptionsFor(item) {
  const maxValue = Math.max(10, Number(item?.quantity || 1));
  return Array.from({ length: maxValue }, (_, index) => index + 1);
}

function lineTotal(item) {
  return (Math.max(1, Number(item?.quantity) || 1) * (Number(item?.price) || 0));
}

function formatVariantValue(value) {
  const normalized = String(value || "").trim();
  if (!normalized) {
    return "";
  }

  return normalized
    .split(/[\s_-]+/)
    .filter(Boolean)
    .map((chunk) => chunk.charAt(0).toUpperCase() + chunk.slice(1))
    .join(" ");
}

function itemVariantSummary(item) {
  const variantLabel = String(item?.variantLabel || "").trim();
  if (variantLabel) {
    return variantLabel;
  }

  const color = formatVariantValue(item?.selectedColor || item?.color);
  const size = formatVariantValue(item?.selectedSize || item?.size);
  return [color, size].filter(Boolean).join(" | ") || "Standard option";
}

async function changeQuantity(productId, nextQuantity) {
  const quantity = Math.max(1, Number(nextQuantity) || 1);
  const { response, data } = await requestJson("/api/cart/quantity", {
    method: "POST",
    body: JSON.stringify({ productId, quantity }),
  });

  if (!response.ok || !data?.ok) {
    ui.message = resolveApiMessage(data, "Quantity could not be updated.");
    ui.type = "error";
    return;
  }

  ui.message = data.message || "Quantity updated.";
  ui.type = "success";
  await loadItems({ preserveMessage: true });
}

async function removeItem(productId) {
  const { response, data } = await requestJson("/api/cart/remove", {
    method: "POST",
    body: JSON.stringify({ productId }),
  });

  if (!response.ok || !data?.ok) {
    ui.message = resolveApiMessage(data, "Item could not be removed.");
    ui.type = "error";
    return;
  }

  ui.message = data.message || "Item removed from cart.";
  ui.type = "success";
  await loadItems({ preserveMessage: true });
}

async function openFullCart() {
  emit("close");
  await router.push("/cart");
}

async function goToCheckout() {
  if (items.value.length <= 0) {
    return;
  }

  if (items.value.some((item) => !hasProductAvailableStock(item))) {
    ui.message = "Some items in your cart are no longer available.";
    ui.type = "error";
    return;
  }

  persistCheckoutSelectedCartIds(items.value.map((item) => item.id));
  emit("close");
  await router.push("/adresa-e-porosise");
}

async function handleLogin() {
  emit("close");
  await router.push("/login?redirect=%2Fcart");
}
</script>

<template>
  <div class="cart-drawer" role="dialog" aria-modal="true" aria-label="Shopping Cart" @click="emit('close')">
    <div class="cart-drawer__backdrop"></div>

    <aside class="cart-drawer__panel" @click.stop>
      <header class="cart-drawer__header">
        <h2>Shopping Cart</h2>
        <button type="button" class="cart-drawer__close" aria-label="Close shopping cart" @click="emit('close')">
          <svg viewBox="0 0 24 24" aria-hidden="true">
            <path d="M6 6 18 18M18 6 6 18" />
          </svg>
        </button>
      </header>

      <template v-if="!isAuthenticated">
        <div class="cart-drawer__content">
          <div class="market-empty cart-drawer__empty">
            <h3>Sign in to view your cart</h3>
            <p>Your saved items and checkout details will appear here once you are signed in.</p>
            <button class="market-button market-button--primary cart-drawer__auth-button" type="button" @click="handleLogin">
              Sign in
            </button>
          </div>
        </div>
      </template>

      <template v-else>
        <div class="cart-drawer__content">
          <div
            v-if="ui.message"
            class="market-status"
            :class="{ 'market-status--error': ui.type === 'error', 'market-status--success': ui.type === 'success' }"
            role="status"
            aria-live="polite"
          >
            {{ ui.message }}
          </div>

          <div v-if="ui.loading" class="market-status" role="status" aria-live="polite">
            Loading cart...
          </div>

          <div v-else-if="items.length === 0" class="market-empty cart-drawer__empty">
            <h3>Your cart is empty</h3>
            <p>Add products to your cart to review them here before checkout.</p>
          </div>

          <div v-else class="cart-drawer__items">
            <article
              v-for="item in items"
              :key="`${item.id}-${item.variantKey || item.selectedSize || 'default'}-${item.selectedColor || 'default'}`"
              class="cart-drawer__item"
            >
              <div class="cart-drawer__item-media">
                <img
                  :src="item.imagePath"
                  :alt="item.title"
                  width="320"
                  height="320"
                  loading="lazy"
                  decoding="async"
                >
              </div>

              <div class="cart-drawer__item-copy">
                <strong class="cart-drawer__item-title">{{ item.title }}</strong>
                <span class="cart-drawer__item-variant">{{ itemVariantSummary(item) }}</span>
                <span class="cart-drawer__item-price">{{ formatPrice(item.price) }}</span>
              </div>

              <div class="cart-drawer__item-controls">
                <label class="cart-drawer__quantity">
                  <span class="sr-only">Quantity</span>
                  <select
                    :value="Math.max(1, Number(item.quantity) || 1)"
                    @change="changeQuantity(item.id, $event?.target?.value || 1)"
                  >
                    <option v-for="quantity in quantityOptionsFor(item)" :key="`${item.id}-${quantity}`" :value="quantity">
                      {{ quantity }}
                    </option>
                  </select>
                </label>

                <button
                  type="button"
                  class="cart-drawer__remove"
                  aria-label="Remove item"
                  @click="removeItem(item.id)"
                >
                  <svg viewBox="0 0 24 24" aria-hidden="true">
                    <path d="M6 6 18 18M18 6 6 18" />
                  </svg>
                </button>

                <strong class="cart-drawer__line-total">{{ formatPrice(lineTotal(item)) }}</strong>
              </div>
            </article>
          </div>
        </div>

        <footer v-if="!ui.loading && items.length > 0" class="cart-drawer__footer">
          <div class="cart-drawer__summary">
            <div class="cart-drawer__summary-head">
              <h3>Order summary</h3>
              <button type="button" class="cart-drawer__view-cart" @click="openFullCart">
                View cart
              </button>
            </div>

            <div class="cart-drawer__summary-row">
              <span>Subtotal</span>
              <strong>{{ formatPrice(subtotal) }}</strong>
            </div>

            <div class="cart-drawer__summary-row">
              <span class="cart-drawer__summary-label">
                Shipping estimate
                <svg viewBox="0 0 24 24" aria-hidden="true">
                  <circle cx="12" cy="12" r="9"></circle>
                  <path d="M12 10.2v5.1M12 7.6h.01"></path>
                </svg>
              </span>
              <strong>{{ shippingEstimate > 0 ? formatPrice(shippingEstimate) : "Free" }}</strong>
            </div>

            <div class="cart-drawer__summary-row">
              <span>Tax estimate</span>
              <strong>{{ formatPrice(taxEstimate) }}</strong>
            </div>

            <div class="cart-drawer__summary-row cart-drawer__summary-row--total">
              <span>Order total</span>
              <strong>{{ formatPrice(orderTotal) }}</strong>
            </div>
          </div>

          <button class="market-button market-button--primary cart-drawer__checkout" type="button" @click="goToCheckout">
            Checkout
          </button>
        </footer>
      </template>
    </aside>
  </div>
</template>

<style scoped>
.sr-only {
  position: absolute;
  width: 1px;
  height: 1px;
  padding: 0;
  margin: -1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  white-space: nowrap;
  border: 0;
}

.cart-drawer {
  position: fixed;
  inset: 0;
  z-index: 1300;
  display: flex;
  justify-content: flex-end;
}

.cart-drawer__backdrop {
  position: absolute;
  inset: 0;
  background: rgba(17, 17, 17, 0.42);
  backdrop-filter: blur(4px);
}

.cart-drawer__panel {
  position: relative;
  width: min(100vw, 408px);
  height: 100%;
  display: flex;
  flex-direction: column;
  border-left: 1px solid #e5e5e5;
  background: #ffffff;
}

.cart-drawer__header {
  flex-shrink: 0;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  padding: 18px 20px;
  border-bottom: 1px solid #ececec;
}

.cart-drawer__header h2 {
  margin: 0;
  color: #111111;
  font-size: 22px;
  font-weight: 600;
  line-height: 1.2;
}

.cart-drawer__close {
  width: 36px;
  height: 36px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  border: 1px solid #e5e5e5;
  border-radius: 10px;
  background: #ffffff;
  color: #111111;
  cursor: pointer;
}

.cart-drawer__close svg,
.cart-drawer__summary-label svg,
.cart-drawer__remove svg {
  width: 16px;
  height: 16px;
  fill: none;
  stroke: currentColor;
  stroke-width: 1.8;
  stroke-linecap: round;
  stroke-linejoin: round;
}

.cart-drawer__content {
  flex: 1;
  min-height: 0;
  overflow-y: auto;
  padding: 16px 20px 20px;
  display: grid;
  align-content: start;
  gap: 14px;
}

.cart-drawer__items {
  display: grid;
}

.cart-drawer__item {
  display: grid;
  grid-template-columns: 72px minmax(0, 1fr) auto;
  gap: 12px;
  align-items: start;
  padding: 16px 0;
  border-bottom: 1px solid #f0f0f0;
}

.cart-drawer__item:first-child {
  padding-top: 0;
}

.cart-drawer__item:last-child {
  border-bottom: 0;
  padding-bottom: 0;
}

.cart-drawer__item-media {
  width: 72px;
  height: 72px;
  overflow: hidden;
  border-radius: 12px;
  background: #f3f3f3;
}

.cart-drawer__item-media img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.cart-drawer__item-copy {
  min-width: 0;
  display: grid;
  gap: 6px;
}

.cart-drawer__item-title {
  color: #111111;
  font-size: 14px;
  font-weight: 600;
  line-height: 1.45;
}

.cart-drawer__item-variant {
  color: #777777;
  font-size: 12px;
  line-height: 1.4;
}

.cart-drawer__item-price,
.cart-drawer__line-total {
  color: #111111;
  font-size: 13px;
  font-weight: 600;
  line-height: 1.4;
}

.cart-drawer__item-controls {
  display: grid;
  justify-items: end;
  align-content: start;
  gap: 10px;
}

.cart-drawer__quantity select {
  min-width: 64px;
  height: 36px;
  border: 1px solid #e5e5e5;
  border-radius: 10px;
  background: #ffffff;
  padding: 0 10px;
  color: #111111;
  font-size: 13px;
  outline: none;
}

.cart-drawer__remove {
  width: 32px;
  height: 32px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  border: 1px solid transparent;
  border-radius: 10px;
  background: transparent;
  color: #9a9a9a;
  cursor: pointer;
  transition: background-color 160ms ease, color 160ms ease;
}

.cart-drawer__remove:hover {
  background: #fff3f3;
  color: #d14848;
}

.cart-drawer__footer {
  flex-shrink: 0;
  padding: 18px 20px 20px;
  border-top: 1px solid #ececec;
  background: #ffffff;
}

.cart-drawer__summary {
  display: grid;
  gap: 12px;
}

.cart-drawer__summary-head,
.cart-drawer__summary-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
}

.cart-drawer__summary-head h3,
.cart-drawer__summary-row strong {
  margin: 0;
  color: #111111;
  font-size: 14px;
  font-weight: 600;
  line-height: 1.4;
}

.cart-drawer__summary-row span {
  color: #666666;
  font-size: 13px;
  line-height: 1.45;
}

.cart-drawer__summary-label {
  display: inline-flex;
  align-items: center;
  gap: 6px;
}

.cart-drawer__summary-label svg {
  width: 14px;
  height: 14px;
  color: #8a8a8a;
}

.cart-drawer__summary-row--total {
  margin-top: 2px;
  padding-top: 12px;
  border-top: 1px solid #ececec;
}

.cart-drawer__summary-row--total span,
.cart-drawer__summary-row--total strong {
  color: #111111;
  font-size: 15px;
}

.cart-drawer__checkout {
  width: 100%;
  margin-top: 16px;
  min-height: 46px;
}

.cart-drawer__view-cart {
  border: 0;
  background: transparent;
  padding: 0;
  color: #666666;
  font-size: 13px;
  font-weight: 500;
  cursor: pointer;
}

.cart-drawer__view-cart:hover {
  color: #111111;
}

.cart-drawer__empty {
  min-height: 220px;
  display: grid;
  place-items: center;
  align-content: center;
}

.cart-drawer__auth-button {
  width: 100%;
  margin-top: 8px;
}

.cart-drawer-enter-active,
.cart-drawer-leave-active {
  transition: opacity 180ms ease;
}

.cart-drawer-enter-active .cart-drawer__panel,
.cart-drawer-leave-active .cart-drawer__panel {
  transition: transform 220ms ease;
}

.cart-drawer-enter-from,
.cart-drawer-leave-to {
  opacity: 0;
}

.cart-drawer-enter-from .cart-drawer__panel,
.cart-drawer-leave-to .cart-drawer__panel {
  transform: translateX(100%);
}

@media (max-width: 720px) {
  .cart-drawer__panel {
    width: 100vw;
    border-left: 0;
  }

  .cart-drawer__item {
    grid-template-columns: 72px minmax(0, 1fr);
  }

  .cart-drawer__item-controls {
    grid-column: 2;
    width: 100%;
    grid-template-columns: minmax(0, 1fr) auto auto;
    align-items: center;
  }
}
</style>
