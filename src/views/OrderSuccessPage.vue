<script setup>
import { computed, onMounted, reactive, ref } from "vue";
import { RouterLink, useRoute, useRouter } from "vue-router";
import { requestJson } from "../lib/api";
import {
  formatDateLabel,
  formatPaymentMethodLabel,
  formatPrice,
  formatProductColorLabel,
  formatProductTypeLabel,
  persistTrackedOrderLookup,
  readOrderSuccessSnapshot,
} from "../lib/shop";
import { ensureSessionLoaded, markRouteReady } from "../stores/app-state";

const route = useRoute();
const router = useRouter();
const snapshot = ref(readOrderSuccessSnapshot());
const order = ref(snapshot.value?.order || null);
const loading = ref(true);
const ui = reactive({
  message: String(snapshot.value?.message || "").trim(),
  error: "",
});

const orderIdFromQuery = computed(() => {
  const value = Math.max(0, Math.trunc(Number(route.query.order || route.query.id || 0) || 0));
  return value;
});

const orderItems = computed(() => (Array.isArray(order.value?.items) ? order.value.items : []));
const orderSubtotal = computed(() => {
  const snapshotValue = Number(order.value?.subtotalAmount || 0);
  if (snapshotValue > 0) {
    return snapshotValue;
  }

  return orderItems.value.reduce((total, item) => total + Number(item?.totalPrice || 0), 0);
});
const orderShipping = computed(() => Number(order.value?.shippingAmount || 0));
const orderDiscount = computed(() => Number(order.value?.discountAmount || 0));
const orderTax = computed(() => 0);
const orderTotal = computed(() => Number(order.value?.totalPrice || 0));

const summaryMeta = computed(() => ([
  {
    key: "date",
    label: "Date",
    value: order.value?.createdAt ? formatDateLabel(order.value.createdAt) : "-",
  },
  {
    key: "order-number",
    label: "Order Number",
    value: order.value?.id ? `#${order.value.id}` : "-",
  },
  {
    key: "payment-method",
    label: "Payment Method",
    value: formatPaymentMethodLabel(order.value?.paymentMethod || ""),
  },
]));

const billingRows = computed(() => {
  if (!order.value) {
    return [];
  }

  const addressParts = [
    String(order.value.addressLine || "").trim(),
    [order.value.city, order.value.country].map((entry) => String(entry || "").trim()).filter(Boolean).join(", "),
    String(order.value.zipCode || "").trim(),
  ].filter(Boolean);

  return [
    { key: "name", label: "Name", value: String(order.value.customerName || "-").trim() || "-" },
    { key: "address", label: "Address", value: addressParts.join(" - ") || "-" },
    { key: "phone", label: "Phone", value: String(order.value.phoneNumber || "-").trim() || "-" },
    { key: "email", label: "Email", value: String(order.value.customerEmail || "-").trim() || "-" },
  ];
});

function buildVariantSummary(item) {
  const parts = [];
  const packageAmountValue = Number(item?.packageAmountValue || 0);
  const packageAmountUnit = String(item?.packageAmountUnit || "").trim();
  if (packageAmountValue > 0 && packageAmountUnit) {
    const compactValue = Number.isInteger(packageAmountValue) ? String(packageAmountValue) : String(packageAmountValue);
    parts.push(`Pack: ${compactValue} ${packageAmountUnit}`);
  }

  if (item?.productType) {
    parts.push(formatProductTypeLabel(item.productType));
  }

  if (item?.size) {
    parts.push(`Size: ${String(item.size).trim().toUpperCase()}`);
  }

  if (item?.color) {
    parts.push(`Color: ${formatProductColorLabel(item.color)}`);
  }

  parts.push(`Qty: ${Math.max(1, Number(item?.quantity) || 1)}`);
  return parts.join(" / ");
}

async function loadOrder(orderId) {
  const normalizedOrderId = Math.max(0, Math.trunc(Number(orderId || 0) || 0));
  if (!normalizedOrderId) {
    return;
  }

  const { response, data } = await requestJson("/api/orders");
  if (!response.ok || !data?.ok) {
    ui.error = "We could not load your order details right now.";
    return;
  }

  const matchingOrder = (Array.isArray(data.orders) ? data.orders : []).find(
    (entry) => Number(entry?.id || 0) === normalizedOrderId,
  );
  if (!matchingOrder) {
    ui.error = "This order confirmation is no longer available.";
    return;
  }

  order.value = matchingOrder;
}

async function handleTrackOrder() {
  if (order.value?.id && order.value?.customerEmail) {
    persistTrackedOrderLookup({
      orderId: order.value.id,
      billingEmail: order.value.customerEmail,
      order: order.value,
    });
  }

  await router.push("/track-order");
}

onMounted(async () => {
  try {
    const user = await ensureSessionLoaded();
    if (!user) {
      await router.replace("/login");
      return;
    }

    if (!order.value || (orderIdFromQuery.value > 0 && Number(order.value?.id || 0) !== orderIdFromQuery.value)) {
      await loadOrder(orderIdFromQuery.value);
    }

    if (!ui.message) {
      ui.message = "Your order has been placed and will be processed soon.";
    }
  } finally {
    loading.value = false;
    markRouteReady();
  }
});
</script>

<template>
  <section class="order-success-page" aria-label="Order confirmation">
    <div class="order-success-page__container">
      <div v-if="loading" class="order-success-page__state">
        <p class="order-success-page__eyebrow">Order confirmation</p>
        <h1>Preparing your order details...</h1>
      </div>

      <div v-else-if="!order" class="order-success-page__state order-success-page__state--empty">
        <p class="order-success-page__eyebrow">Order confirmation</p>
        <h1>We couldn't load this order.</h1>
        <p>{{ ui.error || "Open your order history to review the latest order details." }}</p>
        <RouterLink class="order-success-page__secondary" to="/porosite">
          View your orders
        </RouterLink>
      </div>

      <div v-else class="order-success-page__layout">
        <div class="order-success-page__main">
          <section class="order-success-page__intro">
            <p class="order-success-page__eyebrow">Payment complete</p>
            <h1>Thank you for your purchase!</h1>
            <p class="order-success-page__message">
              {{ ui.message }}
            </p>
          </section>

          <section class="order-success-page__panel">
            <div class="order-success-page__panel-head">
              <h2>Billing address</h2>
            </div>

            <div class="order-success-page__rows">
              <div
                v-for="row in billingRows"
                :key="row.key"
                class="order-success-page__row"
              >
                <span>{{ row.label }}</span>
                <strong>{{ row.value }}</strong>
              </div>
            </div>
          </section>

          <button class="order-success-page__primary" type="button" @click="handleTrackOrder">
            Track Your Order
          </button>
        </div>

        <aside class="order-success-page__summary">
          <section class="order-success-page__summary-card">
            <h2>Order Summary</h2>

            <div class="order-success-page__meta">
              <article
                v-for="entry in summaryMeta"
                :key="entry.key"
                class="order-success-page__meta-item"
              >
                <span>{{ entry.label }}</span>
                <strong>{{ entry.value }}</strong>
              </article>
            </div>

            <div class="order-success-page__divider"></div>

            <div class="order-success-page__items">
              <article
                v-for="item in orderItems"
                :key="item.id"
                class="order-success-page__item"
              >
                <div class="order-success-page__item-media">
                  <img
                    v-if="item.imagePath"
                    :src="item.imagePath"
                    :alt="item.title || 'Product'"
                    width="96"
                    height="96"
                    loading="lazy"
                    decoding="async"
                  >
                  <div v-else class="order-success-page__item-placeholder">
                    {{ (item.title || "P").charAt(0).toUpperCase() }}
                  </div>
                </div>

                <div class="order-success-page__item-copy">
                  <strong>{{ item.title || "Product" }}</strong>
                  <span>{{ buildVariantSummary(item) }}</span>
                </div>

                <strong class="order-success-page__item-price">
                  {{ formatPrice(item.totalPrice || item.unitPrice || 0) }}
                </strong>
              </article>
            </div>

            <div class="order-success-page__divider"></div>

            <div class="order-success-page__totals">
              <div class="order-success-page__total-row">
                <span>Subtotal</span>
                <strong>{{ formatPrice(orderSubtotal) }}</strong>
              </div>
              <div v-if="orderDiscount > 0" class="order-success-page__total-row">
                <span>Discount</span>
                <strong class="order-success-page__total-row--discount">-{{ formatPrice(orderDiscount) }}</strong>
              </div>
              <div class="order-success-page__total-row">
                <span>Shipping</span>
                <strong>{{ orderShipping > 0 ? formatPrice(orderShipping) : "Free" }}</strong>
              </div>
              <div class="order-success-page__total-row">
                <span>Tax</span>
                <strong>{{ formatPrice(orderTax) }}</strong>
              </div>
              <div class="order-success-page__total-row order-success-page__total-row--final">
                <span>Order Total</span>
                <strong>{{ formatPrice(orderTotal) }}</strong>
              </div>
            </div>
          </section>
        </aside>
      </div>
    </div>
  </section>
</template>

<style scoped>
.order-success-page {
  background: #f6f6f6;
}

.order-success-page__container {
  width: min(1160px, calc(100% - 40px));
  margin: 0 auto;
  padding: 40px 0 72px;
}

.order-success-page__layout {
  display: grid;
  grid-template-columns: minmax(0, 1.08fr) minmax(320px, 420px);
  gap: 28px;
  align-items: start;
}

.order-success-page__main {
  display: grid;
  gap: 24px;
}

.order-success-page__intro h1,
.order-success-page__intro p,
.order-success-page__panel h2,
.order-success-page__summary-card h2,
.order-success-page__state h1,
.order-success-page__state p {
  margin: 0;
}

.order-success-page__eyebrow {
  margin: 0 0 12px;
  color: #6d6d6d;
  font-size: 12px;
  font-weight: 600;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.order-success-page__intro h1,
.order-success-page__state h1 {
  color: #111111;
  font-size: clamp(2rem, 4vw, 2.9rem);
  font-weight: 700;
  line-height: 1.08;
  letter-spacing: -0.03em;
}

.order-success-page__message,
.order-success-page__state p {
  max-width: 620px;
  margin-top: 14px;
  color: #666666;
  font-size: 15px;
  line-height: 1.65;
}

.order-success-page__panel,
.order-success-page__summary-card,
.order-success-page__state {
  border: 1px solid #e5e5e5;
  border-radius: 12px;
  background: #ffffff;
}

.order-success-page__panel {
  padding: 22px 24px;
}

.order-success-page__panel-head {
  padding-bottom: 14px;
  border-bottom: 1px solid #ececec;
}

.order-success-page__panel-head h2,
.order-success-page__summary-card h2 {
  color: #111111;
  font-size: 20px;
  font-weight: 600;
  line-height: 1.2;
}

.order-success-page__rows {
  display: grid;
  gap: 16px;
  padding-top: 18px;
}

.order-success-page__row {
  display: grid;
  grid-template-columns: minmax(110px, 140px) minmax(0, 1fr);
  gap: 16px;
  align-items: start;
}

.order-success-page__row span,
.order-success-page__meta-item span,
.order-success-page__item-copy span,
.order-success-page__total-row span {
  color: #6e6e6e;
  font-size: 13px;
  line-height: 1.5;
}

.order-success-page__row strong,
.order-success-page__meta-item strong,
.order-success-page__item-copy strong,
.order-success-page__item-price,
.order-success-page__total-row strong {
  color: #111111;
  font-size: 14px;
  font-weight: 600;
  line-height: 1.5;
}

.order-success-page__primary,
.order-success-page__secondary {
  width: fit-content;
  min-height: 46px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  padding: 0 18px;
  border-radius: 10px;
  font-size: 14px;
  font-weight: 600;
  text-decoration: none;
  transition: background-color 160ms ease, border-color 160ms ease, opacity 160ms ease;
  cursor: pointer;
}

.order-success-page__primary {
  border: 0;
  background: linear-gradient(180deg, #1d1d1d 0%, #111111 100%);
  color: #ffffff;
}

.order-success-page__primary:hover {
  background: linear-gradient(180deg, #2a2a2a 0%, #181818 100%);
}

.order-success-page__secondary {
  border: 1px solid #e0e0e0;
  background: #ffffff;
  color: #222222;
}

.order-success-page__secondary:hover {
  border-color: #d2d2d2;
}

.order-success-page__summary-card {
  padding: 22px 24px;
  display: grid;
  gap: 18px;
}

.order-success-page__meta {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 12px;
}

.order-success-page__meta-item {
  display: grid;
  gap: 6px;
}

.order-success-page__divider {
  height: 1px;
  background: #ececec;
}

.order-success-page__items {
  display: grid;
}

.order-success-page__item {
  display: grid;
  grid-template-columns: 68px minmax(0, 1fr) auto;
  gap: 14px;
  align-items: center;
  padding: 14px 0;
  border-bottom: 1px solid #f0f0f0;
}

.order-success-page__item:first-child {
  padding-top: 0;
}

.order-success-page__item:last-child {
  padding-bottom: 0;
  border-bottom: 0;
}

.order-success-page__item-media {
  width: 68px;
  height: 68px;
  overflow: hidden;
  border-radius: 10px;
  background: #f2f2f2;
}

.order-success-page__item-media img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.order-success-page__item-placeholder {
  width: 100%;
  height: 100%;
  display: grid;
  place-items: center;
  color: #888888;
  font-size: 18px;
  font-weight: 700;
}

.order-success-page__item-copy {
  display: grid;
  gap: 4px;
  min-width: 0;
}

.order-success-page__item-copy strong,
.order-success-page__item-copy span {
  display: -webkit-box;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.order-success-page__item-copy strong {
  -webkit-line-clamp: 2;
}

.order-success-page__item-copy span {
  -webkit-line-clamp: 2;
}

.order-success-page__item-price {
  white-space: nowrap;
  align-self: start;
}

.order-success-page__totals {
  display: grid;
  gap: 10px;
}

.order-success-page__total-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
}

.order-success-page__total-row--discount {
  color: #d14343;
}

.order-success-page__total-row--final {
  margin-top: 4px;
  padding-top: 12px;
  border-top: 1px solid #ececec;
}

.order-success-page__total-row--final span,
.order-success-page__total-row--final strong {
  font-size: 15px;
  font-weight: 700;
}

.order-success-page__state {
  padding: 28px 24px;
}

@media (max-width: 960px) {
  .order-success-page__container {
    width: min(100% - 32px, 1160px);
    padding: 28px 0 56px;
  }

  .order-success-page__layout {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 720px) {
  .order-success-page__meta {
    grid-template-columns: 1fr;
  }

  .order-success-page__row,
  .order-success-page__item {
    grid-template-columns: 1fr;
  }

  .order-success-page__item {
    gap: 10px;
  }

  .order-success-page__item-media {
    width: 76px;
    height: 76px;
  }
}

@media (max-width: 560px) {
  .order-success-page__container {
    width: min(100% - 24px, 1160px);
  }

  .order-success-page__panel,
  .order-success-page__summary-card,
  .order-success-page__state {
    padding: 18px;
  }

  .order-success-page__primary,
  .order-success-page__secondary {
    width: 100%;
  }
}
</style>
