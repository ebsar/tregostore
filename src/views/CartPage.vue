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
  <section class="market-page market-page--wide cart-page" aria-label="Cart products">
    <nav class="market-page__crumbs" aria-label="Breadcrumb">
      <RouterLink to="/">Home</RouterLink>
      <span aria-hidden="true">/</span>
      <strong>Shopping Cart</strong>
    </nav>

    <div
      v-if="ui.message"
      class="market-status"
      :class="{ 'market-status--error': ui.type === 'error', 'market-status--success': ui.type === 'success' }"
      role="status"
      aria-live="polite"
    >
      {{ ui.message }}
    </div>

    <div v-if="ui.guest" class="market-empty">
      <h2>Per te perdorur shporten duhet te kyçesh</h2>
      <p>Krijo llogari ose hyni ne llogarine tende per te ruajtur produktet dhe per te vazhduar me porosite.</p>
      <div class="market-empty__actions">
        <RouterLink class="market-button market-button--primary" to="/login?redirect=%2Fcart">
          Login
        </RouterLink>
        <RouterLink class="market-button market-button--secondary" to="/signup?redirect=%2Fcart">
          Sign up
        </RouterLink>
      </div>
    </div>

    <div v-else class="cart-page__shell">
      <div v-if="unavailableItems.length > 0" class="market-status market-status--error" role="status" aria-live="polite">
        <span>{{ unavailableItems.length }} products in cart are no longer in stock. Remove them or save them for later before checkout.</span>
      </div>

      <div class="cart-page__layout">
        <section class="market-card cart-section">
          <div class="market-page__header">
            <div class="market-page__header-copy">
              <p class="market-page__eyebrow">Cart</p>
              <h1>Shopping cart</h1>
              <p>{{ cartSubtitle }} • {{ estimatedDeliveryText }}</p>
            </div>
          </div>

          <div v-if="items.length > 0">
            <table class="cart-table">
              <thead>
                <tr>
                  <th>Product</th>
                  <th>Price</th>
                  <th>Quantity</th>
                  <th>Subtotal</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="item in items" :key="item.id">
                  <td>
                    <div class="cart-item__product">
                      <img
                        :src="item.imagePath"
                        :alt="item.title"
                        width="640"
                        height="640"
                        loading="lazy"
                        decoding="async"
                      >

                      <div class="cart-item">
                        <div class="search-toolbar">
                          <strong>{{ item.title }}</strong>
                          <button
                            class="market-icon-button"
                            type="button"
                            aria-label="Hiqe nga cart"
                            @click="removeItem(item.id)"
                          >
                            x
                          </button>
                        </div>
                        <span v-if="item.businessName" class="section-heading__copy">{{ item.businessName }}</span>
                        <span v-if="!hasProductAvailableStock(item)" class="section-heading__copy">
                          {{ getProductStockMessage(item) }}
                        </span>
                      </div>
                    </div>
                  </td>
                  <td>
                    <div class="cart-item">
                      <span v-if="productComparePrice(item)" class="product-card__price-compare">
                        {{ productComparePrice(item) }}
                      </span>
                      <strong>{{ productUnitPrice(item) }}</strong>
                    </div>
                  </td>
                  <td>
                    <div class="cart-quantity">
                      <button
                        type="button"
                        :disabled="Number(item.quantity) <= 1 || !hasProductAvailableStock(item)"
                        @click="decreaseQuantity(item.id)"
                      >
                        -
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
                  <td>
                    <strong>{{ formatPrice(lineSubtotal(item)) }}</strong>
                  </td>
                </tr>
              </tbody>
            </table>

            <div class="market-empty__actions">
              <RouterLink class="market-button market-button--ghost" to="/kerko">
                Return to shop
              </RouterLink>
              <button class="market-button market-button--secondary" type="button" @click="updateCartView">
                Update cart
              </button>
            </div>
          </div>

          <div v-else class="market-empty">
            <h2>Your cart is empty</h2>
            <p>Shto produkte nga faqet e dyqanit dhe pastaj vazhdo me porosine.</p>
            <div class="market-empty__actions">
              <RouterLink class="market-button market-button--secondary" to="/kerko">
                Browse products
              </RouterLink>
            </div>
          </div>
        </section>

        <aside class="market-card cart-summary" aria-label="Cart summary">
          <section class="cart-section">
            <p class="market-page__eyebrow">Summary</p>
            <h2>Cart totals</h2>

            <div class="cart-summary__line">
              <span>Subtotal</span>
              <strong>{{ formatPrice(totalPrice) }}</strong>
            </div>
            <div class="cart-summary__line">
              <span>Shipping</span>
              <strong>{{ deliveryCost > 0 ? formatPrice(deliveryCost) : "Free" }}</strong>
            </div>
            <div class="cart-summary__line">
              <span>Discount</span>
              <strong>{{ discountAmount > 0 ? formatPrice(discountAmount) : formatPrice(0) }}</strong>
            </div>
            <div class="cart-summary__line">
              <span>Tax</span>
              <strong>{{ formatPrice(taxAmount) }}</strong>
            </div>
            <div class="cart-summary__line cart-summary__line--total">
              <span>Total</span>
              <strong>{{ formatPrice(grandTotal) }}</strong>
            </div>

            <div class="checkout-actions">
              <button
                class="market-button market-button--primary"
                type="button"
                :disabled="selectedItems.length === 0 || selectedUnavailableItems.length > 0"
                @click="handleCheckout"
              >
                Proceed to checkout
              </button>
            </div>
          </section>

          <section class="cart-section">
            <p class="market-page__eyebrow">Coupon</p>
            <h3>Apply coupon code</h3>

            <form class="checkout-form" @submit.prevent="applyPromoCode">
              <input
                v-model="promoCode"
                type="text"
                placeholder="Enter coupon code"
                autocomplete="off"
              >
              <button class="market-button market-button--secondary" type="submit">
                Apply coupon
              </button>
            </form>

            <div v-if="appliedPromoCode" class="market-status market-status--success market-status--compact">
              Active code: <strong>{{ appliedPromoCode }}</strong>
            </div>
          </section>
        </aside>
      </div>

      <section v-if="savedLaterItems.length > 0" class="market-card market-card--padded" aria-label="Saved for later">
        <div class="market-page__header">
          <div class="market-page__header-copy">
            <p class="market-page__eyebrow">Saved for later</p>
            <h2>Keep these for later</h2>
            <p>{{ savedLaterCount }} products saved for a future purchase.</p>
          </div>
          <button class="market-button market-button--ghost" type="button" @click="clearSavedLater">
            Clear all
          </button>
        </div>

        <section class="product-collection__grid" aria-label="Saved for later grid">
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
    </div>
  </section>
</template>
