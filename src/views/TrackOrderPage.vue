<script setup>
import { computed, onBeforeUnmount, onMounted, reactive, ref } from "vue";
import { RouterLink, useRoute } from "vue-router";
import { requestJson, resolveApiMessage } from "../lib/api";
import {
  clearTrackedOrderLookup,
  formatPrice,
  persistTrackedOrderLookup,
  readTrackedOrderLookup,
} from "../lib/shop";
import { markRouteReady } from "../stores/app-state";

const route = useRoute();

const trackedSnapshot = ref(readTrackedOrderLookup());
const order = ref(trackedSnapshot.value?.order || null);

const ui = reactive({
  loading: false,
  message: "",
  type: "",
});
const trackForm = reactive({
  orderId: "",
  billingEmail: "",
});

const progressStages = [
  { key: "placed", label: "Order Placed", icon: "receipt" },
  { key: "packaging", label: "Packaging", icon: "box" },
  { key: "road", label: "On The Road", icon: "truck" },
  { key: "delivered", label: "Delivered", icon: "hand" },
];

const currentStageIndex = computed(() => {
  const status = String(order.value?.fulfillmentStatus || order.value?.status || "")
    .trim()
    .toLowerCase();

  if (["delivered", "returned"].includes(status)) {
    return 3;
  }

  if (status === "shipped") {
    return 2;
  }

  if (["confirmed", "packed", "partially_confirmed"].includes(status)) {
    return 1;
  }

  return 0;
});

const progressFillWidth = computed(() => `${(currentStageIndex.value / (progressStages.length - 1)) * 100}%`);

const orderSummaryLine = computed(() => {
  if (!order.value) {
    return "";
  }

  const itemCount = Number(order.value.totalItems || order.value.items?.length || 0);
  const itemLabel = itemCount === 1 ? "Product" : "Products";
  const createdAt = formatLongDateTime(order.value.createdAt);
  return `${itemCount} ${itemLabel} • Order Placed in ${createdAt}`;
});

const arrivalLine = computed(() => {
  if (!order.value) {
    return "";
  }

  const deliveredAt = latestOrderTimestamp(order.value, "deliveredAt");
  if (deliveredAt) {
    return `Order delivered ${formatShortDate(deliveredAt)}`;
  }

  const cancelledAt = latestOrderTimestamp(order.value, "cancelledAt");
  if (cancelledAt) {
    return `Order cancelled ${formatShortDate(cancelledAt)}`;
  }

  return `Order expected arrival ${formatShortDate(resolveExpectedArrival(order.value))}`;
});

const trackingDetails = computed(() => {
  if (!order.value) {
    return [];
  }

  const entries = [];
  const trackingCode = String(order.value.trackingCode || "").trim();
  const trackingUrl = String(order.value.trackingUrl || "").trim();

  if (trackingCode) {
    entries.push({
      key: "code",
      label: "Tracking code",
      value: trackingCode,
      href: "",
    });
  }

  if (trackingUrl) {
    entries.push({
      key: "url",
      label: "Tracking link",
      value: "Open shipment link",
      href: trackingUrl,
    });
  }

  return entries;
});

const activityEntries = computed(() => buildOrderActivity(order.value));

onMounted(async () => {
  window.addEventListener("tregio:track-order-updated", handleTrackedOrderUpdated);

  try {
    const requestedOrderId = Math.max(0, Math.trunc(Number(route.query.id || 0) || 0));
    const snapshot = readTrackedOrderLookup();
    trackedSnapshot.value = snapshot;
    order.value = snapshot?.order || null;
    trackForm.orderId = snapshot?.orderId ? String(snapshot.orderId) : "";
    trackForm.billingEmail = String(snapshot?.billingEmail || "").trim();

    if (snapshot?.orderId && snapshot?.billingEmail && (!order.value || (requestedOrderId && requestedOrderId !== snapshot.orderId))) {
      await loadTrackedOrder(snapshot.orderId, snapshot.billingEmail);
    }
  } finally {
    markRouteReady();
  }
});

onBeforeUnmount(() => {
  window.removeEventListener("tregio:track-order-updated", handleTrackedOrderUpdated);
});

function handleTrackedOrderUpdated(event) {
  const snapshot = event?.detail || readTrackedOrderLookup();
  trackedSnapshot.value = snapshot;
  order.value = snapshot?.order || null;
  ui.message = "";
  ui.type = "";
}

async function loadTrackedOrder(orderId, billingEmail) {
  ui.loading = true;
  ui.message = "";
  ui.type = "";

  try {
    const { response, data } = await requestJson("/api/orders/track", {
      method: "POST",
      body: JSON.stringify({
        orderId,
        billingEmail,
      }),
    });

    if (!response.ok || !data?.ok || !data.order) {
      order.value = null;
      ui.message = resolveApiMessage(data, "We could not load the latest tracking details.");
      ui.type = "error";
      return;
    }

    const nextSnapshot = persistTrackedOrderLookup({
      orderId: Math.max(0, Math.trunc(Number(orderId || data.order.id || 0) || 0)),
      billingEmail: String(billingEmail || "").trim().toLowerCase(),
      order: data.order,
    });

    if (!nextSnapshot) {
      order.value = null;
      ui.message = "The order was found, but the browser could not store the tracking details.";
      ui.type = "error";
      return;
    }

    trackedSnapshot.value = nextSnapshot;
    order.value = data.order;
  } catch (error) {
    order.value = null;
    ui.message = "The tracking server is not responding. Please try again.";
    ui.type = "error";
    console.error(error);
  } finally {
    ui.loading = false;
  }
}

async function submitTrackOrderForm() {
  await loadTrackedOrder(trackForm.orderId.trim(), trackForm.billingEmail.trim());
}

function clearTrackedOrderDetails() {
  clearTrackedOrderLookup();
  trackedSnapshot.value = null;
  order.value = null;
  ui.message = "";
  ui.type = "";
}

function resolveExpectedArrival(orderPayload) {
  const createdAtValue = new Date(normalizeDateValue(orderPayload?.createdAt));
  if (Number.isNaN(createdAtValue.getTime())) {
    return orderPayload?.createdAt || "";
  }

  const deliveryMethod = String(orderPayload?.deliveryMethod || "").trim().toLowerCase();
  const nextDate = new Date(createdAtValue.getTime());

  if (deliveryMethod === "pickup") {
    nextDate.setDate(nextDate.getDate() + 1);
  } else if (deliveryMethod === "express") {
    nextDate.setDate(nextDate.getDate() + 2);
  } else {
    nextDate.setDate(nextDate.getDate() + 4);
  }

  return nextDate.toISOString();
}

function latestOrderTimestamp(orderPayload, fieldName) {
  if (!orderPayload?.items?.length) {
    return "";
  }

  const candidates = orderPayload.items
    .map((item) => String(item?.[fieldName] || "").trim())
    .filter(Boolean)
    .sort((left, right) => new Date(normalizeDateValue(right)).getTime() - new Date(normalizeDateValue(left)).getTime());

  return candidates[0] || "";
}

function earliestOrderTimestamp(orderPayload, fieldName) {
  if (!orderPayload?.items?.length) {
    return "";
  }

  const candidates = orderPayload.items
    .map((item) => String(item?.[fieldName] || "").trim())
    .filter(Boolean)
    .sort((left, right) => new Date(normalizeDateValue(left)).getTime() - new Date(normalizeDateValue(right)).getTime());

  return candidates[0] || "";
}

function buildOrderActivity(orderPayload) {
  if (!orderPayload) {
    return [];
  }

  const entries = [];
  const currentStatus = String(orderPayload.fulfillmentStatus || orderPayload.status || "").trim().toLowerCase();
  const createdAt = String(orderPayload.createdAt || "").trim();
  const confirmedAt = earliestOrderTimestamp(orderPayload, "confirmedAt");
  const shippedAt = earliestOrderTimestamp(orderPayload, "shippedAt");
  const deliveredAt = latestOrderTimestamp(orderPayload, "deliveredAt");
  const cancelledAt = latestOrderTimestamp(orderPayload, "cancelledAt");

  if (createdAt) {
    entries.push({
      key: "created",
      tone: "placed",
      icon: "receipt",
      title: "Your order has been placed and is now being reviewed.",
      date: createdAt,
    });
  }

  if (confirmedAt) {
    entries.push({
      key: "confirmed",
      tone: "progress",
      icon: "user",
      title: "The business confirmed your order and started preparing it.",
      date: confirmedAt,
    });
  }

  if (shippedAt) {
    entries.push({
      key: "shipped",
      tone: "road",
      icon: "map",
      title: "Your order is on the road and moving through delivery.",
      date: shippedAt,
    });
  }

  if (deliveredAt) {
    entries.push({
      key: "delivered",
      tone: "success",
      icon: "check",
      title: "Your order has been delivered. Thank you for shopping at TREGIO!",
      date: deliveredAt,
    });
  }

  if (cancelledAt) {
    entries.push({
      key: "cancelled",
      tone: "danger",
      icon: "calendar",
      title: "This order was cancelled before completion.",
      date: cancelledAt,
    });
  }

  if (entries.length === 1) {
    entries.push({
      key: "status",
      tone: "progress",
      icon: "box",
      title: `Current order status: ${humanizeStatus(currentStatus)}`,
      date: createdAt,
    });
  }

  return entries.sort(
    (left, right) => new Date(normalizeDateValue(right.date)).getTime() - new Date(normalizeDateValue(left.date)).getTime(),
  );
}

function humanizeStatus(status) {
  const labels = {
    pending_confirmation: "Awaiting confirmation",
    confirmed: "Confirmed",
    partially_confirmed: "Partially confirmed",
    packed: "Packaging",
    shipped: "On the road",
    delivered: "Delivered",
    cancelled: "Cancelled",
    returned: "Returned",
  };

  return labels[String(status || "").trim().toLowerCase()] || "In progress";
}

function normalizeDateValue(value) {
  return String(value || "").trim().replace(" ", "T");
}

function formatLongDateTime(value) {
  const parsedDate = new Date(normalizeDateValue(value));
  if (Number.isNaN(parsedDate.getTime())) {
    return String(value || "-");
  }

  return new Intl.DateTimeFormat("en-US", {
    day: "numeric",
    month: "short",
    year: "numeric",
    hour: "numeric",
    minute: "2-digit",
  }).format(parsedDate);
}

function formatShortDate(value) {
  const parsedDate = new Date(normalizeDateValue(value));
  if (Number.isNaN(parsedDate.getTime())) {
    return String(value || "-");
  }

  return new Intl.DateTimeFormat("en-US", {
    day: "numeric",
    month: "short",
    year: "numeric",
  }).format(parsedDate);
}

function renderActivityIcon(icon) {
  switch (icon) {
    case "receipt":
      return "M6 4h10l2 2v14l-2-1.4L14 20l-3-1.4L8 20l-2-1.4L4 20V6zM8 9h8M8 12h8";
    case "user":
      return "M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8Zm0 2c-3.4 0-6.2 2.1-7 5h14c-.8-2.9-3.6-5-7-5z";
    case "map":
      return "M6 4.5 11 3l7 2.5v14L13 21l-7-2.5Zm5-1.5v16m7-13.5-5 1.5-7-2";
    case "check":
      return "M5 12.5 9.2 17 19 7";
    case "calendar":
      return "M7 4v3M17 4v3M4 9h16M6 6h12a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2z";
    case "box":
      return "M12 3 19 7v10l-7 4-7-4V7l7-4Zm0 0v18M5 7l7 4 7-4";
    case "truck":
      return "M3 8h11v7H3zm11 2h3l2 2v3h-5zM7 18a1.5 1.5 0 1 1 0-3 1.5 1.5 0 0 1 0 3Zm9 0a1.5 1.5 0 1 1 0-3 1.5 1.5 0 0 1 0 3Z";
    case "hand":
      return "M6 12.5 8.5 10l2 2L13 8.5M14.5 7.5h2a2.5 2.5 0 0 1 0 5H14";
    default:
      return "";
  }
}
</script>

<template>
  <section class="track-order-page" aria-label="Track order details">
    <div class="track-order-breadcrumb-strip">
      <div class="track-order-breadcrumb-inner">
        <nav class="track-order-breadcrumbs" aria-label="Breadcrumb">
          <RouterLink to="/">Home</RouterLink>
          <span>›</span>
          <span>Pages</span>
          <span>›</span>
          <RouterLink to="/track-order">Track Order</RouterLink>
          <template v-if="order">
            <span>›</span>
            <strong>Details</strong>
          </template>
        </nav>
      </div>
    </div>

    <div class="form-message" :class="ui.type" role="status" aria-live="polite">
      {{ ui.message }}
    </div>

    <section v-if="!order" class="track-order-form-shell">
      <div class="track-order-form-card">
        <div class="track-order-form-copy">
          <h1>Track Order</h1>
          <p>
            To track your order please enter your order ID in the input field below and press the
            “Track Order” button. this was given to you on your receipt and in the confirmation
            email you should have received.
          </p>
        </div>

        <form class="track-order-inline-form" @submit.prevent="submitTrackOrderForm">
          <div class="track-order-inline-grid">
            <label class="track-order-inline-field">
              <span>Order ID</span>
              <input
                v-model="trackForm.orderId"
                type="text"
                placeholder="ID..."
                autocomplete="off"
                required
              >
            </label>

            <label class="track-order-inline-field">
              <span>Billing Email</span>
              <input
                v-model="trackForm.billingEmail"
                type="email"
                placeholder="Email address"
                autocomplete="email"
                required
              >
            </label>
          </div>

          <p class="track-order-inline-note">
            <span aria-hidden="true">ⓘ</span>
            Order ID that we sended to your in your email address.
          </p>

          <button class="track-order-primary-button" type="submit" :disabled="ui.loading">
            {{ ui.loading ? "TRACKING..." : "TRACK ORDER" }}
            <span aria-hidden="true">→</span>
          </button>
        </form>
      </div>
    </section>

    <section v-else class="track-order-detail-shell">
      <div class="track-order-detail-card">
        <div class="track-order-summary-banner">
          <div>
            <strong>#{{ order.id }}</strong>
            <p>{{ orderSummaryLine }}</p>
          </div>
          <span>{{ formatPrice(order.totalPrice || 0) }}</span>
        </div>

        <p class="track-order-arrival-line">{{ arrivalLine }}</p>

        <div v-if="trackingDetails.length > 0" class="track-order-meta-grid">
          <div v-for="entry in trackingDetails" :key="entry.key" class="track-order-meta-chip">
            <span>{{ entry.label }}</span>
            <a
              v-if="entry.href"
              :href="entry.href"
              target="_blank"
              rel="noreferrer"
            >
              {{ entry.value }}
            </a>
            <strong v-else>{{ entry.value }}</strong>
          </div>
        </div>

        <div class="track-order-progress">
          <div class="track-order-progress-line"></div>
          <div class="track-order-progress-line track-order-progress-line--active" :style="{ width: progressFillWidth }"></div>

          <div
            v-for="(stage, index) in progressStages"
            :key="stage.key"
            class="track-order-progress-step"
            :class="{
              'is-active': index <= currentStageIndex,
              'is-current': index === currentStageIndex,
            }"
          >
            <span class="track-order-progress-dot"></span>
            <span class="track-order-progress-icon">
              <svg viewBox="0 0 24 24" aria-hidden="true">
                <path :d="renderActivityIcon(stage.icon)" />
              </svg>
            </span>
            <strong>{{ stage.label }}</strong>
          </div>
        </div>

        <div class="track-order-activity">
          <div class="track-order-activity-head">
            <h2>Order Activity</h2>
            <div class="track-order-activity-actions">
              <button class="track-order-link-button" type="button" @click="clearTrackedOrderDetails">
                Track another order
              </button>
            </div>
          </div>

          <article
            v-for="entry in activityEntries"
            :key="entry.key"
            class="track-order-activity-item"
            :class="`is-${entry.tone}`"
          >
            <span class="track-order-activity-icon">
              <svg viewBox="0 0 24 24" aria-hidden="true">
                <path :d="renderActivityIcon(entry.icon)" />
              </svg>
            </span>
            <div>
              <p>{{ entry.title }}</p>
              <time>{{ formatLongDateTime(entry.date) }}</time>
            </div>
          </article>
        </div>
      </div>
    </section>
  </section>
</template>

<style scoped>
.track-order-page {
  width: min(1300px, calc(100vw - 48px));
  margin: 0 auto;
  padding: 0 0 80px;
}

.track-order-breadcrumb-strip {
  margin-inline: calc(50% - 50vw);
  border-top: 1px solid rgba(15, 23, 42, 0.06);
  border-bottom: 1px solid rgba(15, 23, 42, 0.06);
  background: #f5f6f8;
}

.track-order-breadcrumb-inner {
  width: 100%;
  box-sizing: border-box;
  margin: 0 auto;
  padding: 28px 24px;
}

.track-order-breadcrumbs {
  display: flex;
  align-items: center;
  gap: 10px;
  flex-wrap: wrap;
  color: #64748b;
  font-size: 1rem;
}

.track-order-breadcrumbs a {
  color: inherit;
  text-decoration: none;
}

.track-order-breadcrumbs strong,
.track-order-breadcrumbs :last-child {
  color: #2496f3;
}

.track-order-form-card,
.track-order-detail-card {
  display: grid;
  gap: 24px;
  margin: 56px auto 0;
  padding: 22px;
  border: 1px solid rgba(15, 23, 42, 0.08);
  border-radius: 8px;
  background: #fff;
  box-shadow: 0 22px 54px rgba(15, 23, 42, 0.05);
}

.track-order-form-shell {
  display: grid;
  place-items: start center;
  padding-top: 24px;
}

.track-order-form-card {
  width: min(980px, 100%);
  gap: 26px;
  padding: 34px 38px 36px;
  box-shadow: none;
}

.track-order-form-copy {
  display: grid;
  gap: 14px;
  max-width: 720px;
}

.track-order-form-copy h1 {
  margin: 0;
  color: #1f2937;
  font-size: clamp(2rem, 2.8vw, 3rem);
  line-height: 1.04;
  letter-spacing: -0.05em;
}

.track-order-form-copy p {
  margin: 0;
  color: #6b7280;
  font-size: 1rem;
  line-height: 1.6;
}

.track-order-inline-form {
  display: grid;
  gap: 18px;
}

.track-order-inline-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 18px;
}

.track-order-inline-field {
  display: grid;
  gap: 10px;
}

.track-order-inline-field span {
  color: #202833;
  font-size: 0.96rem;
  font-weight: 700;
}

.track-order-inline-field input {
  min-height: 54px;
  padding: 0 14px;
  border: 1px solid #dbe2ea;
  border-radius: 2px;
  background: #fff;
  color: #111827;
  font: inherit;
  outline: none;
}

.track-order-inline-field input:focus {
  border-color: rgba(255, 134, 47, 0.72);
  box-shadow: 0 0 0 4px rgba(255, 134, 47, 0.1);
}

.track-order-inline-note {
  display: inline-flex;
  align-items: center;
  gap: 10px;
  margin: 0;
  color: #6b7280;
  font-size: 0.95rem;
  line-height: 1.5;
}

.track-order-primary-button,
.track-order-link-button {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 10px;
  border: 0;
  cursor: pointer;
}

.track-order-primary-button {
  width: fit-content;
  min-height: 48px;
  padding: 0 18px;
  border-radius: 2px;
  background: #fa8232;
  color: #fff;
  font-weight: 800;
  letter-spacing: 0.02em;
}

.track-order-detail-shell {
  display: grid;
  place-items: start center;
  padding-top: 56px;
}

.track-order-detail-card {
  width: min(860px, 100%);
}

.track-order-summary-banner {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 16px;
  padding: 20px;
  border: 1px solid #f3df8f;
  border-radius: 4px;
  background: linear-gradient(180deg, #fff5c9 0%, #fff8de 100%);
}

.track-order-summary-banner strong {
  display: block;
  margin: 0 0 10px;
  color: #202833;
  font-size: 2rem;
  letter-spacing: -0.04em;
}

.track-order-summary-banner p {
  margin: 0;
  color: #4b5563;
  font-weight: 600;
}

.track-order-summary-banner span {
  color: #2496f3;
  font-size: clamp(2rem, 2.6vw, 2.6rem);
  font-weight: 900;
  line-height: 1;
}

.track-order-arrival-line {
  margin: 0;
  color: #4b5563;
  font-size: 1rem;
  font-weight: 600;
}

.track-order-meta-grid {
  display: flex;
  flex-wrap: wrap;
  gap: 12px;
}

.track-order-meta-chip {
  display: grid;
  gap: 6px;
  min-width: 180px;
  padding: 12px 14px;
  border: 1px solid rgba(15, 23, 42, 0.08);
  border-radius: 12px;
  background: #f8fafc;
}

.track-order-meta-chip span {
  color: #64748b;
  font-size: 0.78rem;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.track-order-meta-chip strong,
.track-order-meta-chip a {
  color: #111827;
  font-size: 0.95rem;
  font-weight: 700;
  text-decoration: none;
}

.track-order-meta-chip a {
  color: #f97316;
}

.track-order-progress {
  position: relative;
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 16px;
  align-items: start;
  padding-top: 18px;
}

.track-order-progress-line {
  position: absolute;
  top: 12px;
  left: calc(12.5% + 6px);
  right: calc(12.5% + 6px);
  height: 4px;
  border-radius: 999px;
  background: #fee7dc;
}

.track-order-progress-line--active {
  right: auto;
  background: #ff862f;
}

.track-order-progress-step {
  position: relative;
  display: grid;
  justify-items: center;
  gap: 12px;
  text-align: center;
  color: #d9dbe1;
}

.track-order-progress-dot {
  position: relative;
  z-index: 2;
  width: 20px;
  height: 20px;
  border: 3px solid currentColor;
  border-radius: 999px;
  background: #fff;
}

.track-order-progress-icon {
  display: inline-flex;
  width: 38px;
  height: 38px;
  align-items: center;
  justify-content: center;
  color: currentColor;
}

.track-order-progress-icon svg {
  width: 22px;
  height: 22px;
  fill: none;
  stroke: currentColor;
  stroke-width: 1.8;
  stroke-linecap: round;
  stroke-linejoin: round;
}

.track-order-progress-step strong {
  font-size: 0.96rem;
  font-weight: 700;
}

.track-order-progress-step.is-active {
  color: #ff862f;
}

.track-order-progress-step.is-current strong {
  color: #202833;
}

.track-order-activity {
  display: grid;
  gap: 16px;
  padding-top: 10px;
  border-top: 1px solid rgba(15, 23, 42, 0.08);
}

.track-order-activity-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
}

.track-order-activity-head h2 {
  margin: 0;
  color: #202833;
  font-size: 1.55rem;
  letter-spacing: -0.03em;
}

.track-order-activity-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 12px;
}

.track-order-link-button {
  padding: 0;
  background: transparent;
  color: #2496f3;
  font-weight: 700;
}

.track-order-activity-item {
  display: grid;
  grid-template-columns: 40px minmax(0, 1fr);
  gap: 14px;
  align-items: start;
}

.track-order-activity-icon {
  display: inline-flex;
  width: 40px;
  height: 40px;
  align-items: center;
  justify-content: center;
  border-radius: 4px;
}

.track-order-activity-item svg {
  width: 21px;
  height: 21px;
  fill: none;
  stroke: currentColor;
  stroke-width: 1.8;
  stroke-linecap: round;
  stroke-linejoin: round;
}

.track-order-activity-item.is-placed .track-order-activity-icon {
  background: #fff2dd;
  color: #ff862f;
}

.track-order-activity-item.is-progress .track-order-activity-icon,
.track-order-activity-item.is-road .track-order-activity-icon {
  background: #e8f4ff;
  color: #2496f3;
}

.track-order-activity-item.is-success .track-order-activity-icon {
  background: #e9f8ed;
  color: #22c55e;
}

.track-order-activity-item.is-danger .track-order-activity-icon {
  background: #ffefef;
  color: #ef4444;
}

.track-order-activity-item p {
  margin: 0 0 4px;
  color: #202833;
  font-weight: 600;
  line-height: 1.55;
}

.track-order-activity-item time {
  color: #64748b;
  font-size: 0.94rem;
}

@media (max-width: 860px) {
  .track-order-summary-banner,
  .track-order-activity-head {
    grid-template-columns: 1fr;
    display: grid;
  }
}

@media (max-width: 720px) {
  .track-order-page {
    width: min(100vw - 24px, 1300px);
    padding-bottom: 48px;
  }

  .track-order-breadcrumb-inner {
    padding-inline: 16px;
  }

  .track-order-form-card,
  .track-order-detail-card {
    margin-top: 28px;
    padding: 18px 16px;
  }

  .track-order-form-shell {
    padding-top: 0;
  }

  .track-order-inline-grid {
    grid-template-columns: 1fr;
  }

  .track-order-detail-shell {
    padding-top: 28px;
  }

  .track-order-progress {
    grid-template-columns: repeat(2, minmax(0, 1fr));
    row-gap: 20px;
  }

  .track-order-progress-line {
    display: none;
  }

  .track-order-primary-button {
    width: 100%;
  }
}
</style>
