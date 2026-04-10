<script setup>
import { computed, onMounted, reactive, ref } from "vue";
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
  } finally {
    markRouteReady();
  }
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

function updateCartView() {
  ui.message = "Shporta u perditesua.";
  ui.type = "success";
  void loadItems();
}

function lineSubtotal(item) {
  return (Math.max(1, Number(item?.quantity) || 1) * (Number(item?.price) || 0));
}

function productUnitPrice(item) {
  return formatPrice(item?.price || 0);
}

function productComparePrice(item) {
  const compareAt = Number(item?.compareAtPrice || item?.oldPrice || item?.originalPrice || 0);
  const current = Number(item?.price || 0);
  if (!Number.isFinite(compareAt) || compareAt <= current) {
    return "";
  }

  return formatPrice(compareAt);
}
</script>

<template>
  <section class="collection-page cart-page cart-page--reference" aria-label="Cart products">
    <div class="cart-breadcrumb-strip">
      <div class="cart-breadcrumb-inner">
        <nav class="cart-breadcrumbs" aria-label="Breadcrumb">
          <RouterLink to="/">Home</RouterLink>
          <span>›</span>
          <strong>Shopping Cart</strong>
        </nav>
      </div>
    </div>

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

    <div v-else class="cart-layout cart-layout--reference">
      <div class="cart-products-panel cart-products-panel--reference">
        <div v-if="unavailableItems.length > 0" class="cart-stock-warning" role="status" aria-live="polite">
          <strong>{{ unavailableItems.length }} produkte ne shporte nuk jane me ne stok.</strong>
          <p>Artikujt e prekur jane zbehur. Hiqi ose ruaji per me vone para se te vazhdosh me porosi.</p>
        </div>

        <section class="cart-card-shell">
          <div class="cart-card-head">
            <h1>Shopping Cart</h1>
          </div>

          <div v-if="items.length > 0" class="cart-table-wrap">
            <table class="cart-table">
              <thead>
                <tr>
                  <th>PRODUCTS</th>
                  <th>PRICE</th>
                  <th>QUANTITY</th>
                  <th>SUB-TOTAL</th>
                </tr>
              </thead>
              <tbody>
                <tr
                  v-for="item in items"
                  :key="item.id"
                  :class="{ 'is-unavailable': !hasProductAvailableStock(item) }"
                >
                  <td>
                    <div class="cart-table-product">
                      <button
                        class="cart-table-remove"
                        type="button"
                        aria-label="Hiqe nga cart"
                        @click="removeItem(item.id)"
                      >
                        ×
                      </button>

                      <div class="cart-table-image-wrap">
                        <img
                          class="cart-table-image"
                          :src="item.imagePath"
                          :alt="item.title"
                          width="640"
                          height="640"
                          loading="lazy"
                          decoding="async"
                        >
                      </div>

                      <div class="cart-table-copy">
                        <strong>{{ item.title }}</strong>
                        <p v-if="item.businessName">{{ item.businessName }}</p>
                        <p v-if="!hasProductAvailableStock(item)" class="cart-table-stock-warning">
                          {{ getProductStockMessage(item) }}
                        </p>
                      </div>
                    </div>
                  </td>
                  <td>
                    <div class="cart-table-price">
                      <span v-if="productComparePrice(item)" class="cart-table-price-old">
                        {{ productComparePrice(item) }}
                      </span>
                      <strong>{{ productUnitPrice(item) }}</strong>
                    </div>
                  </td>
                  <td>
                    <div class="cart-table-qty">
                      <button
                        type="button"
                        :disabled="Number(item.quantity) <= 1 || !hasProductAvailableStock(item)"
                        @click="decreaseQuantity(item.id)"
                      >
                        −
                      </button>
                      <span>{{ Math.max(1, Number(item.quantity) || 1) }}</span>
                      <button
                        type="button"
                        :disabled="!hasProductAvailableStock(item)"
                        @click="increaseQuantity(item.id)"
                      >
                        +
                      </button>
                    </div>
                  </td>
                  <td class="cart-table-subtotal">
                    {{ formatPrice(lineSubtotal(item)) }}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>

          <div v-else class="collection-empty-state cart-empty-state">
            Shporta jote eshte bosh. Shto produkte nga faqet e dyqanit dhe pastaj vazhdo me porosine.
          </div>

          <div v-if="items.length > 0" class="cart-card-footer">
            <RouterLink class="cart-page-secondary-action" to="/kerko">
              ← RETURN TO SHOP
            </RouterLink>
            <button class="cart-page-secondary-action" type="button" @click="updateCartView">
              UPDATE CART
            </button>
          </div>
        </section>
      </div>

      <aside class="cart-sidebar-stack" aria-label="Cart summary">
        <section class="cart-summary-card cart-summary-card--reference">
          <div class="cart-summary-title">Cart Totals</div>

          <div class="cart-summary-lines">
            <div class="cart-summary-line">
              <span>Sub-total</span>
              <strong>{{ formatPrice(totalPrice) }}</strong>
            </div>
            <div class="cart-summary-line">
              <span>Shipping</span>
              <strong>{{ deliveryCost > 0 ? formatPrice(deliveryCost) : "Free" }}</strong>
            </div>
            <div class="cart-summary-line cart-summary-line--discount">
              <span>Discount</span>
              <strong>{{ discountAmount > 0 ? formatPrice(discountAmount) : formatPrice(0) }}</strong>
            </div>
            <div class="cart-summary-line">
              <span>Tax</span>
              <strong>{{ formatPrice(taxAmount) }}</strong>
            </div>
          </div>

          <div class="cart-summary-total">
            <span>Total</span>
            <strong>{{ formatPrice(grandTotal) }}</strong>
          </div>

          <button
            class="cart-checkout-button"
            type="button"
            :disabled="selectedItems.length === 0 || selectedUnavailableItems.length > 0"
            @click="handleCheckout"
          >
            PROCEED TO CHECKOUT
          </button>
        </section>

        <section class="cart-summary-card cart-summary-card--coupon">
          <div class="cart-summary-title">Coupon Code</div>

          <form class="cart-summary-coupon" @submit.prevent="applyPromoCode">
            <input
              v-model="promoCode"
              class="cart-summary-coupon-input"
              type="text"
              placeholder="Email address"
              autocomplete="off"
            >
            <button class="cart-summary-coupon-button" type="submit">APPLY COUPON</button>
          </form>

          <div v-if="appliedPromoCode" class="cart-summary-applied">
            Kodi aktiv: <strong>{{ appliedPromoCode }}</strong>
          </div>
        </section>
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
.cart-page--reference {
  width: min(1300px, calc(100vw - 48px));
  margin: 0 auto;
  padding: 0 0 72px;
}

.cart-breadcrumb-strip {
  margin-inline: calc(50% - 50vw);
  border-top: 1px solid rgba(15, 23, 42, 0.06);
  border-bottom: 1px solid rgba(15, 23, 42, 0.06);
  background: #f5f6f8;
}

.cart-breadcrumb-inner {
  width: 100%;
  box-sizing: border-box;
  margin: 0 auto;
  padding: 28px 24px;
}

.cart-breadcrumbs {
  display: flex;
  align-items: center;
  gap: 10px;
  flex-wrap: wrap;
  color: #64748b;
  font-size: 1rem;
}

.cart-breadcrumbs a {
  color: inherit;
  text-decoration: none;
}

.cart-breadcrumbs strong {
  color: #2496f3;
}

.cart-layout {
  display: grid;
}

.cart-layout--reference {
  grid-template-columns: minmax(0, 1fr) 382px;
  gap: 24px;
  align-items: start;
  padding-top: 36px;
}

.cart-products-panel {
  display: grid;
  gap: 16px;
}

.cart-products-panel--reference {
  padding: 0;
  border: 0;
  background: transparent;
  box-shadow: none;
}

.cart-stock-warning {
  margin: 0;
  border-radius: 14px;
  border: 1px solid rgba(251, 191, 36, 0.34);
  background: #fffaf0;
}

.cart-card-shell {
  overflow: hidden;
  border: 1px solid rgba(15, 23, 42, 0.08);
  border-radius: 8px;
  background: #fff;
  box-shadow: 0 20px 48px rgba(15, 23, 42, 0.05);
}

.cart-card-head {
  padding: 22px 24px;
  border-bottom: 1px solid rgba(15, 23, 42, 0.08);
}

.cart-card-head h1 {
  margin: 0;
  color: #202833;
  font-size: 1.18rem;
  letter-spacing: -0.02em;
}

.cart-table-wrap {
  overflow-x: auto;
}

.cart-table {
  width: 100%;
  min-width: 760px;
  border-collapse: collapse;
}

.cart-table thead th {
  padding: 12px 24px;
  background: #f1f4f7;
  color: #4b5563;
  font-size: 0.9rem;
  font-weight: 700;
  text-align: left;
}

.cart-table tbody td {
  padding: 22px 24px;
  border-bottom: 1px solid rgba(15, 23, 42, 0.08);
  vertical-align: middle;
}

.cart-table tbody tr.is-unavailable {
  opacity: 0.72;
}

.cart-table-product {
  display: grid;
  grid-template-columns: 28px 74px minmax(0, 1fr);
  gap: 18px;
  align-items: center;
}

.cart-table-remove {
  width: 22px;
  height: 22px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  border: 1px solid #cbd5e1;
  border-radius: 999px;
  background: #fff;
  color: #64748b;
  font-size: 1rem;
  line-height: 1;
  cursor: pointer;
}

.cart-table-image-wrap {
  display: grid;
  width: 74px;
  height: 74px;
  place-items: center;
  border-radius: 8px;
  background: #f8fafc;
}

.cart-table-image {
  width: 62px;
  height: 62px;
  object-fit: contain;
}

.cart-table-copy {
  display: grid;
  gap: 4px;
}

.cart-table-copy strong {
  color: #202833;
  font-size: 0.98rem;
  line-height: 1.35;
}

.cart-table-copy p {
  margin: 0;
  color: #64748b;
  font-size: 0.86rem;
  line-height: 1.45;
}

.cart-table-stock-warning {
  color: #b91c1c;
}

.cart-table-price {
  display: grid;
  gap: 4px;
}

.cart-table-price-old {
  color: #94a3b8;
  text-decoration: line-through;
}

.cart-table-price strong,
.cart-table-subtotal {
  color: #202833;
  font-size: 0.98rem;
  font-weight: 700;
}

.cart-table-qty {
  display: inline-grid;
  grid-template-columns: 1fr auto 1fr;
  width: 142px;
  min-height: 48px;
  align-items: center;
  border: 1px solid #d8e0e8;
  border-radius: 2px;
  background: #fff;
}

.cart-table-qty button,
.cart-table-qty span {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-height: 48px;
}

.cart-table-qty button {
  border: 0;
  background: transparent;
  color: #475569;
  font-size: 1.7rem;
  cursor: pointer;
}

.cart-table-qty button:disabled {
  opacity: 0.35;
  cursor: default;
}

.cart-table-qty span {
  color: #111827;
  font-weight: 700;
}

.cart-card-footer {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  padding: 24px;
}

.cart-page-secondary-action {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-height: 48px;
  padding: 0 22px;
  border: 2px solid #39a0ea;
  border-radius: 2px;
  background: #fff;
  color: #2496f3;
  text-decoration: none;
  font-weight: 800;
  cursor: pointer;
}

.cart-empty-state {
  margin: 0;
  padding: 40px 24px;
}

.cart-sidebar-stack {
  display: grid;
  gap: 22px;
}

.cart-summary-card--reference {
  position: sticky;
  top: calc(var(--page-nav-clearance) - 20px);
  display: grid;
  gap: 18px;
  padding: 24px;
  border-radius: 8px;
  border: 1px solid rgba(15, 23, 42, 0.08);
  background: #fff;
  box-shadow: 0 20px 48px rgba(15, 23, 42, 0.05);
}

.cart-summary-card--coupon {
  position: static;
}

.cart-summary-coupon {
  display: grid;
  gap: 16px;
}

.cart-summary-coupon-input {
  min-height: 46px;
  padding: 0 12px;
  border-radius: 2px;
  border: 1px solid #dbe2ea;
  background: #fff;
  color: #0f172a;
  font: inherit;
  outline: none;
}

.cart-summary-coupon-button {
  width: fit-content;
  min-height: 46px;
  padding: 0 22px;
  border-radius: 2px;
  border: 0;
  background: #2f96df;
  color: #fff;
  font-weight: 800;
  cursor: pointer;
}

.cart-summary-title {
  color: #202833;
  font-size: 1.1rem;
  font-weight: 800;
}

.cart-summary-lines {
  display: grid;
  gap: 12px;
}

.cart-summary-line {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  color: #4b5563;
  font-size: 0.98rem;
}

.cart-summary-line strong {
  color: #202833;
  font-weight: 700;
}

.cart-summary-line--discount strong {
  color: #202833;
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
  padding-top: 14px;
  border-top: 1px solid #e2e8f0;
  color: #202833;
  font-size: 1rem;
  font-weight: 800;
}

.cart-summary-total strong {
  font-size: 1.2rem;
  line-height: 1;
}

.cart-checkout-button {
  min-height: 54px;
  border: 0;
  border-radius: 2px;
  color: #fff;
  font-weight: 800;
  background: #ff862f;
}

.cart-checkout-button::after {
  content: "→";
  margin-left: 8px;
}

@media (max-width: 980px) {
  .cart-layout--reference {
    grid-template-columns: 1fr;
  }

  .cart-summary-card--reference {
    position: static;
  }
}

@media (max-width: 720px) {
  .cart-page--reference {
    width: min(100vw - 24px, 1300px);
  }

  .cart-breadcrumb-inner {
    padding-inline: 16px;
  }

  .cart-page--reference {
    padding-bottom: 48px;
  }

  .cart-layout--reference {
    padding-top: 24px;
  }

  .cart-card-head,
  .cart-card-footer,
  .cart-summary-card--reference {
    padding-inline: 16px;
  }

  .cart-card-footer {
    flex-direction: column;
    align-items: stretch;
  }

  .cart-page-secondary-action {
    width: 100%;
  }

  .cart-table thead th,
  .cart-table tbody td {
    padding-inline: 16px;
  }
}
</style>
