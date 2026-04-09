<script setup>
import { computed, nextTick, onMounted, onUnmounted, reactive, ref } from "vue";
import { RouterLink } from "vue-router";
import { useRouter } from "vue-router";
import SavedProductCard from "../components/SavedProductCard.vue";
import { requestJson, resolveApiMessage } from "../lib/api";
import {
  clearSavedForLaterItems,
  formatEstimatedDeliveryLabel,
  formatPrice,
  getDeliveryMethodOption,
  persistCheckoutSelectedCartIds,
  readSavedForLaterItems,
  rememberSavedForLaterItem,
  removeSavedForLaterItem,
  getProductStockMessage,
  hasProductAvailableStock,
} from "../lib/shop";
import { appState, ensureSessionLoaded, markRouteReady, setCartItems } from "../stores/app-state";

const router = useRouter();
const productsPanel = ref(null);
const summaryCard = ref(null);
const items = ref([]);
const savedLaterItems = ref([]);
const selectedIds = ref([]);
const selectionInitialized = ref(false);
const promoCode = ref("");
const appliedPromoCode = ref("");
const appliedDiscountRate = ref(0);
const ui = reactive({
  message: "",
  type: "",
  guest: false,
});

let resizeObserver = null;
let resizeFrame = 0;

const selectionEnabled = computed(() => items.value.length > 2);
const selectedItems = computed(() => {
  if (!selectionEnabled.value) {
    return [...items.value];
  }

  return items.value.filter((item) => selectedIds.value.includes(item.id));
});
const unavailableItems = computed(() => items.value.filter((item) => !hasProductAvailableStock(item)));
const selectedUnavailableItems = computed(() =>
  selectedItems.value.filter((item) => !hasProductAvailableStock(item)),
);

const totalItems = computed(() =>
  selectedItems.value.reduce((total, item) => total + Math.max(0, Number(item.quantity) || 0), 0),
);

const totalPrice = computed(() =>
  selectedItems.value.reduce(
    (total, item) => total + (Math.max(0, Number(item.quantity) || 0) * (Number(item.price) || 0)),
    0,
  ),
);
const deliveryOption = computed(() => getDeliveryMethodOption("standard"));
const deliveryCost = computed(() => (selectedItems.value.length > 0 ? Number(deliveryOption.value.shippingAmount || 0) : 0));
const taxAmount = computed(() => 0);
const discountAmount = computed(() =>
  Number((Math.max(0, totalPrice.value) * Math.max(0, appliedDiscountRate.value || 0)).toFixed(2)),
);
const grandTotal = computed(() =>
  Math.max(0, totalPrice.value + deliveryCost.value + taxAmount.value - discountAmount.value),
);
const cartSubtitle = computed(() => {
  const count = items.value.length;
  if (count === 1) {
    return "1 produkt ne shporte";
  }

  return `${count} produkte ne shporte`;
});
const estimatedDeliveryText = computed(() =>
  formatEstimatedDeliveryLabel(deliveryOption.value.value, deliveryOption.value.estimatedDeliveryText),
);

const savedLaterCount = computed(() => savedLaterItems.value.length);

const allSelected = computed(() =>
  items.value.length > 0 && selectedItems.value.length === items.value.length,
);

const isIndeterminate = computed(
  () => selectedItems.value.length > 0 && selectedItems.value.length < items.value.length,
);

onMounted(async () => {
  try {
    const user = await ensureSessionLoaded();
    if (!user) {
      ui.guest = true;
      ui.message = "Per te perdorur shporten duhet te kyçesh ose te krijosh llogari.";
      ui.type = "error";
      return;
    }

    await loadItems();
    loadSavedLaterItems();
    setupHeightSync();
  } finally {
    markRouteReady();
  }
});

onUnmounted(() => {
  if (resizeObserver) {
    resizeObserver.disconnect();
  }
  if (resizeFrame) {
    window.cancelAnimationFrame(resizeFrame);
  }
  window.removeEventListener("resize", scheduleHeightSync);
});

async function loadItems() {
  const { response, data } = await requestJson("/api/cart");
  if (!response.ok || !data?.ok) {
    ui.message = resolveApiMessage(data, "Shporta nuk u ngarkua.");
    ui.type = "error";
    items.value = [];
    setCartItems([]);
    return;
  }

  items.value = Array.isArray(data.items) ? data.items : [];
  setCartItems(items.value);
  syncSelectionState();
  ui.message = "";
  ui.type = "";
  await nextTick();
  scheduleHeightSync();
}

function loadSavedLaterItems() {
  savedLaterItems.value = readSavedForLaterItems();
}

function syncSelectionState() {
  const availableIds = new Set(items.value.map((item) => item.id));

  if (!selectionEnabled.value) {
    selectedIds.value = items.value.map((item) => item.id);
    selectionInitialized.value = false;
    return;
  }

  if (!selectionInitialized.value) {
    selectedIds.value = items.value.map((item) => item.id);
    selectionInitialized.value = true;
    return;
  }

  selectedIds.value = selectedIds.value.filter((id) => availableIds.has(id));
}

function toggleItem(productId) {
  if (!selectionEnabled.value) {
    return;
  }

  selectedIds.value = selectedIds.value.includes(productId)
    ? selectedIds.value.filter((id) => id !== productId)
    : [...selectedIds.value, productId];
}

function toggleAll(event) {
  if (!selectionEnabled.value) {
    return;
  }

  selectedIds.value = event.target.checked ? items.value.map((item) => item.id) : [];
}

async function removeItem(productId) {
  const { response, data } = await requestJson("/api/cart/remove", {
    method: "POST",
    body: JSON.stringify({ productId }),
  });

  if (!response.ok || !data?.ok) {
    ui.message = resolveApiMessage(data, "Shporta nuk u perditesua.");
    ui.type = "error";
    return;
  }

  ui.message = data.message || "Shporta u perditesua.";
  ui.type = "success";
  await loadItems();
}

async function setQuantity({ productId, quantity }) {
  const nextQuantity = Math.max(1, Number(quantity) || 1);
  const { response, data } = await requestJson("/api/cart/quantity", {
    method: "POST",
    body: JSON.stringify({ productId, quantity: nextQuantity }),
  });

  if (!response.ok || !data?.ok) {
    ui.message = resolveApiMessage(data, "Shporta nuk u perditesua.");
    ui.type = "error";
    return;
  }

  ui.message = data.message || "Sasia u perditesua.";
  ui.type = "success";
  await loadItems();
}

async function saveForLater(cartLine) {
  const currentItem =
    cartLine && typeof cartLine === "object"
      ? cartLine
      : items.value.find((item) => item.id === Number(cartLine));
  if (!currentItem) {
    return;
  }

  const { response, data } = await requestJson("/api/cart/remove", {
    method: "POST",
    body: JSON.stringify({ productId: currentItem.id }),
  });

  if (!response.ok || !data?.ok) {
    ui.message = resolveApiMessage(data, "Shporta nuk u perditesua.");
    ui.type = "error";
    return;
  }

  savedLaterItems.value = rememberSavedForLaterItem(currentItem);
  ui.message = "Artikulli u ruajt per me vone.";
  ui.type = "success";
  await loadItems();
}

async function increaseQuantity(productId) {
  const { response, data } = await requestJson("/api/cart/add", {
    method: "POST",
    body: JSON.stringify({ productId }),
  });

  if (!response.ok || !data?.ok) {
    ui.message = resolveApiMessage(data, "Shporta nuk u perditesua.");
    ui.type = "error";
    return;
  }

  ui.message = data.message || "Sasia u perditesua.";
  ui.type = "success";
  await loadItems();
}

async function decreaseQuantity(productId) {
  const currentItem = items.value.find((item) => item.id === productId);
  const currentQuantity = Number(currentItem?.quantity || 0);
  const nextQuantity = currentQuantity - 1;
  if (nextQuantity < 1) {
    return;
  }

  const { response, data } = await requestJson("/api/cart/quantity", {
    method: "POST",
    body: JSON.stringify({ productId, quantity: nextQuantity }),
  });

  if (!response.ok || !data?.ok) {
    ui.message = resolveApiMessage(data, "Shporta nuk u perditesua.");
    ui.type = "error";
    return;
  }

  ui.message = data.message || "Sasia u perditesua.";
  ui.type = "success";
  await loadItems();
}

async function restoreSavedLaterItem(savedItem) {
  const item =
    savedItem && typeof savedItem === "object"
      ? savedItem
      : savedLaterItems.value.find((entry) => entry.id === Number(savedItem));

  if (!item) {
    return;
  }

  if (!hasProductAvailableStock(item)) {
    ui.message = getProductStockMessage(item);
    ui.type = "error";
    return;
  }

  const { response, data } = await requestJson("/api/cart/add", {
    method: "POST",
    body: JSON.stringify({
      productId: item.productId || item.id,
      quantity: Math.max(1, Number(item.quantity) || 1),
      variantKey: item.variantKey || "",
      selectedSize: item.selectedSize || "",
      selectedColor: item.selectedColor || "",
    }),
  });

  if (!response.ok || !data?.ok) {
    ui.message = resolveApiMessage(data, "Produkti nuk u rikthye ne shporte.");
    ui.type = "error";
    return;
  }

  savedLaterItems.value = removeSavedForLaterItem(item);
  ui.message = "Artikulli u rikthye ne shporte.";
  ui.type = "success";
  await loadItems();
}

function removeSavedLaterItem(savedItem) {
  savedLaterItems.value = removeSavedForLaterItem(savedItem);
  ui.message = "Artikulli u hoq nga te ruajturat per me vone.";
  ui.type = "success";
}

function clearSavedLater() {
  if (savedLaterCount.value <= 0) {
    return;
  }

  savedLaterItems.value = clearSavedForLaterItems();
  ui.message = "U pastruan artikujt e ruajtur per me vone.";
  ui.type = "success";
}

function applyPromoCode() {
  const normalizedCode = String(promoCode.value || "").trim().toUpperCase();

  if (!normalizedCode) {
    appliedPromoCode.value = "";
    appliedDiscountRate.value = 0;
    ui.message = "Shkruaj nje kod zbritjeje para se ta aplikosh.";
    ui.type = "error";
    return;
  }

  if (["TREGIO10", "WELCOME10"].includes(normalizedCode)) {
    appliedPromoCode.value = normalizedCode;
    appliedDiscountRate.value = 0.1;
    ui.message = `Kodi ${normalizedCode} u aplikua me sukses.`;
    ui.type = "success";
    return;
  }

  appliedPromoCode.value = "";
  appliedDiscountRate.value = 0;
  ui.message = "Kodi i zbritjes nuk u gjet.";
  ui.type = "error";
}

function handleCheckout() {
  if (selectedItems.value.length === 0) {
    ui.message = "Zgjidh te pakten nje produkt per te vazhduar me porosi.";
    ui.type = "error";
    return;
  }

  if (selectedUnavailableItems.value.length > 0) {
    const firstUnavailable = selectedUnavailableItems.value[0];
    ui.message =
      getProductStockMessage(firstUnavailable)
      || "Na vjen keq, disa produkte ne shporte nuk jane me ne stok. Hiqi ose ruaji per me vone.";
    ui.type = "error";
    return;
  }

  persistCheckoutSelectedCartIds(selectedItems.value.map((item) => item.id));
  router.push("/adresa-e-porosise");
}

function setupHeightSync() {
  scheduleHeightSync();
  window.addEventListener("resize", scheduleHeightSync);

  if (!("ResizeObserver" in window) || !summaryCard.value) {
    return;
  }

  resizeObserver = new window.ResizeObserver(() => {
    scheduleHeightSync();
  });
  resizeObserver.observe(summaryCard.value);
}

function scheduleHeightSync() {
  if (resizeFrame) {
    window.cancelAnimationFrame(resizeFrame);
  }

  resizeFrame = window.requestAnimationFrame(() => {
    resizeFrame = 0;
    syncHeight();
  });
}

function syncHeight() {
  if (!productsPanel.value) {
    return;
  }

  if (window.innerWidth <= 780 || !summaryCard.value) {
    productsPanel.value.style.removeProperty("--cart-panel-height");
    return;
  }

  const summaryHeight = Math.ceil(summaryCard.value.getBoundingClientRect().height);
  if (summaryHeight > 0) {
    productsPanel.value.style.setProperty("--cart-panel-height", `${summaryHeight}px`);
  }
}
</script>

<template>
  <section class="collection-page cart-page" aria-label="Cart products">
    <header class="collection-page-header cart-page-header">
      <h1>Your cart</h1>
      <p>{{ cartSubtitle }}</p>
    </header>

    <div class="form-message" :class="ui.type" role="status" aria-live="polite">
      {{ ui.message }}
    </div>

    <div v-if="ui.guest" class="collection-empty-state collection-guest-gate">
      <h2>Per te perdorur shporten duhet te kyçesh.</h2>
      <p>Krijo llogari ose hyni ne llogarine tende per te ruajtur produktet dhe per te vazhduar me porosite.</p>
      <div class="collection-guest-gate-actions">
        <RouterLink class="nav-action nav-action-secondary" to="/login?redirect=%2Fcart">
          Login
        </RouterLink>
        <RouterLink class="nav-action nav-action-primary" to="/signup?redirect=%2Fcart">
          Sign Up
        </RouterLink>
      </div>
    </div>

    <div v-else class="cart-layout">
      <div ref="productsPanel" class="cart-products-panel">
        <div v-if="unavailableItems.length > 0" class="cart-stock-warning" role="status" aria-live="polite">
          <strong>{{ unavailableItems.length }} produkte ne shporte nuk jane me ne stok.</strong>
          <p>Artikujt e prekur jane zbehur. Hiqi ose ruaji per me vone para se te vazhdosh me porosi.</p>
        </div>

        <section v-if="items.length > 0" id="cart-products-grid" class="saved-products-grid cart-products-grid" aria-label="Cart grid">
          <SavedProductCard
            v-for="item in items"
            :key="item.id"
            :product="item"
            mode="cart"
            @toggle-select="toggleItem"
            @remove="removeItem"
            @save-for-later="saveForLater"
            @set-quantity="setQuantity"
            @increase-quantity="increaseQuantity"
            @decrease-quantity="decreaseQuantity"
          />
        </section>

        <div v-else class="collection-empty-state">
          Shporta jote eshte bosh. Shto produkte nga faqet e dyqanit dhe pastaj vazhdo me porosine.
        </div>
      </div>

      <aside ref="summaryCard" class="card cart-summary-card cart-summary-card--reference" aria-label="Cart summary">
        <form class="cart-summary-coupon" @submit.prevent="applyPromoCode">
          <input
            v-model="promoCode"
            class="cart-summary-coupon-input"
            type="text"
            placeholder="Type here"
            autocomplete="off"
          >
          <button class="cart-summary-coupon-button" type="submit">Apply</button>
        </form>

        <div class="cart-summary-lines">
          <div class="cart-summary-line">
            <span>{{ totalItems }} items:</span>
            <strong>{{ formatPrice(totalPrice) }}</strong>
          </div>
          <div class="cart-summary-line">
            <span>Delivery cost:</span>
            <strong>{{ formatPrice(deliveryCost) }}</strong>
          </div>
          <div class="cart-summary-line">
            <span>Tax:</span>
            <strong>{{ formatPrice(taxAmount) }}</strong>
          </div>
          <div class="cart-summary-line cart-summary-line--discount">
            <span>Discount:</span>
            <strong>{{ discountAmount > 0 ? `-${formatPrice(discountAmount)}` : formatPrice(0) }}</strong>
          </div>
        </div>

        <div v-if="appliedPromoCode" class="cart-summary-applied">
          Kodi aktiv: <strong>{{ appliedPromoCode }}</strong>
        </div>

        <div class="cart-summary-total">
          <span>Total:</span>
          <strong>{{ formatPrice(grandTotal) }}</strong>
        </div>

        <button
          class="cart-checkout-button"
          type="button"
          :disabled="selectedItems.length === 0 || selectedUnavailableItems.length > 0"
          @click="handleCheckout"
        >
          Checkout
        </button>

        <div class="cart-summary-delivery">
          <div class="cart-summary-delivery-icon">
            <svg viewBox="0 0 24 24" aria-hidden="true">
              <path d="M4 7.5h11v8.7a1.3 1.3 0 0 1-1.3 1.3H5.3A1.3 1.3 0 0 1 4 16.2z"></path>
              <path d="M15 10h3.1l1.9 2.2v4h-1.7"></path>
              <path d="M8 18.1a1.9 1.9 0 1 1-3.8 0"></path>
              <path d="M18.1 18.1a1.9 1.9 0 1 1-3.8 0"></path>
            </svg>
          </div>
          <div class="cart-summary-delivery-copy">
            <strong>Delivered by</strong>
            <span>{{ estimatedDeliveryText }}</span>
          </div>
        </div>
      </aside>
    </div>

    <section v-if="savedLaterItems.length > 0" class="cart-saved-later-section" aria-label="Saved for later">
      <div class="saved-products-toolbar cart-saved-later-toolbar">
        <div class="saved-products-toolbar-left">
          <div>
            <p class="section-label">Ruajtur</p>
            <h2>Per me vone</h2>
          </div>
          <span class="saved-products-selected-count">
            {{ savedLaterCount }} produkte te ruajtura
          </span>
        </div>

        <button class="saved-products-toolbar-button cart-saved-later-clear" type="button" @click="clearSavedLater">
          Pastro te gjitha
        </button>
      </div>

      <section class="saved-products-grid cart-saved-later-grid" aria-label="Saved for later grid">
        <SavedProductCard
          v-for="item in savedLaterItems"
          :key="`${item.productId}-${item.variantKey || item.selectedSize || 'default'}-${item.selectedColor || 'default'}`"
          :product="item"
          mode="later"
          @add-to-cart="restoreSavedLaterItem"
          @remove="removeSavedLaterItem"
        />
      </section>
    </section>
  </section>
</template>

<style scoped>
.cart-page-header {
  gap: 4px;
}

.cart-page-header .section-label {
  display: none;
}

.cart-page-header h1 {
  margin: 0;
  color: #111827;
}

.cart-page-header p {
  margin: 0;
  color: #64748b;
  font-size: 0.92rem;
}

.cart-layout {
  grid-template-columns: minmax(0, 1fr) minmax(280px, 312px);
  gap: 16px;
  align-items: start;
}

.cart-products-panel {
  gap: 0;
  padding: 8px 0 0;
  border-radius: 12px;
  border: 1px solid #e2e8f0;
  background: rgba(255, 255, 255, 0.94);
  box-shadow: 0 10px 24px rgba(15, 23, 42, 0.04);
  height: auto;
}

.cart-stock-warning {
  margin: 0 14px 10px;
  border-radius: 10px;
  border: 1px solid rgba(251, 191, 36, 0.34);
  background: #fffaf0;
}

.cart-products-grid {
  gap: 0;
}

.cart-products-grid :deep(.saved-product-card--cart) {
  border-bottom: 1px solid #edf2f7;
}

.cart-products-grid :deep(.saved-product-card--cart:last-child) {
  border-bottom: 0;
}

.cart-summary-card--reference {
  position: sticky;
  top: calc(var(--page-nav-clearance) - 20px);
  gap: 14px;
  padding: 12px;
  border-radius: 12px;
  border: 1px solid #e2e8f0;
  background: rgba(248, 250, 252, 0.96);
  box-shadow: 0 10px 24px rgba(15, 23, 42, 0.05);
}

.cart-summary-coupon {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto;
  gap: 8px;
}

.cart-summary-coupon-input {
  min-height: 38px;
  padding: 0 12px;
  border-radius: 8px;
  border: 1px solid #dbe2ea;
  background: #fff;
  color: #0f172a;
  font: inherit;
  outline: none;
}

.cart-summary-coupon-button {
  min-height: 38px;
  padding: 0 14px;
  border-radius: 8px;
  border: 1px solid #dbe2ea;
  background: #fff;
  color: #111827;
  font-weight: 700;
  cursor: pointer;
}

.cart-summary-lines {
  display: grid;
  gap: 8px;
}

.cart-summary-line {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  color: #64748b;
  font-size: 0.9rem;
}

.cart-summary-line strong {
  color: #111827;
  font-weight: 700;
}

.cart-summary-line--discount strong {
  color: #16a34a;
}

.cart-summary-applied {
  color: #2356d8;
  font-size: 0.82rem;
  font-weight: 700;
}

.cart-summary-total {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding-top: 10px;
  border-top: 1px solid #e2e8f0;
  color: #111827;
  font-size: 1rem;
  font-weight: 800;
}

.cart-summary-total strong {
  font-size: 1.75rem;
  line-height: 1;
}

.cart-checkout-button {
  min-height: 48px;
  border: 0;
  border-radius: 10px;
  color: #fff;
  font-weight: 800;
  background: linear-gradient(180deg, #4f5fff, #3250f2);
  box-shadow: 0 16px 30px rgba(50, 80, 242, 0.18);
}

.cart-checkout-button::after {
  content: "→";
  margin-left: 8px;
}

.cart-summary-delivery {
  display: grid;
  grid-template-columns: 36px minmax(0, 1fr);
  gap: 10px;
  align-items: center;
  padding: 10px 12px;
  border-radius: 10px;
  border: 1px solid #e2e8f0;
  background: #fff;
}

.cart-summary-delivery-icon {
  width: 36px;
  height: 36px;
  display: grid;
  place-items: center;
  border-radius: 10px;
  background: #eef2ff;
  color: #3250f2;
}

.cart-summary-delivery-icon svg {
  width: 18px;
  height: 18px;
  fill: none;
  stroke: currentColor;
  stroke-width: 1.8;
  stroke-linecap: round;
  stroke-linejoin: round;
}

.cart-summary-delivery-copy {
  display: grid;
  gap: 2px;
}

.cart-summary-delivery-copy strong {
  color: #475569;
  font-size: 0.76rem;
}

.cart-summary-delivery-copy span {
  color: #64748b;
  font-size: 0.8rem;
}

@media (max-width: 980px) {
  .cart-layout {
    grid-template-columns: 1fr;
  }

  .cart-summary-card--reference {
    position: static;
  }
}

@media (max-width: 640px) {
  .cart-products-panel {
    padding-top: 4px;
  }

  .cart-summary-total strong {
    font-size: 1.4rem;
  }
}
</style>
