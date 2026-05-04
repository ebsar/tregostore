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
  { key: "waiting_shipping", label: "Waiting Shipping", icon: "box" },
  { key: "shipped", label: "Shipped", icon: "truck" },
  { key: "for_review", label: "For Review", icon: "hand" },
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

const progressFillWidth = computed(() => `${(currentStageIndex.value / (progressStages.length - 1)) * 75}%`);

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
      title: "The business confirmed your order. It is waiting for shipping.",
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
      title: "Your order has been delivered and is ready for review or return/refund if needed.",
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
    pending_confirmation: "Waiting for seller approval",
    confirmed: "Waiting for shipping",
    partially_confirmed: "Partially waiting for shipping",
    packed: "Ready to ship",
    shipped: "Shipped",
    delivered: "For review",
    cancelled: "Cancelled",
    returned: "Return / Refund",
    refunded: "Refunded",
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
  <section class="market-page market-page--wide dashboard-page" aria-label="Track order details">
    <div
      v-if="ui.message"
      class="market-status"
      :class="{ 'market-status--error': ui.type === 'error', 'market-status--success': ui.type === 'success' }"
      role="status"
      aria-live="polite"
    >
      {{ ui.message }}
    </div>

    <div class="track-order-shell">
      <header class="dashboard-section dashboard-page__hero">
        <div class="dashboard-section__head">
          <div class="market-page__header-copy">
            <p class="market-page__eyebrow">Order tracking</p>
            <h1>{{ order ? `Order #${order.id}` : "Track your order" }}</h1>
            <p>
              {{
                order
                  ? "Stay on top of the latest delivery steps, shipment links, and the full activity history for this order."
                  : "Enter your order number and billing email to open the latest delivery timeline and shipment details."
              }}
            </p>
          </div>
        </div>
      </header>

      <section v-if="!order" class="account-card track-order-lookup">
        <div class="account-card__header">
          <div>
            <h2>Look up your order</h2>
            <p>Use the order ID from your receipt or confirmation email together with the billing email used at checkout.</p>
          </div>
        </div>

        <form class="account-form" @submit.prevent="submitTrackOrderForm">
          <div class="account-form__row">
            <label>
              <span>Order ID</span>
              <input
                v-model="trackForm.orderId"
                type="text"
                placeholder="Order number"
                autocomplete="off"
                required
              >
            </label>

            <label>
              <span>Billing email</span>
              <input
                v-model="trackForm.billingEmail"
                type="email"
                placeholder="Email address"
                autocomplete="email"
                required
              >
            </label>
          </div>

          <p class="account-avatar-field__hint">The order ID is included in your confirmation email and on the order receipt.</p>

          <div class="account-form__actions">
            <button class="market-button market-button--primary" type="submit" :disabled="ui.loading">
              {{ ui.loading ? "Tracking..." : "Track order" }}
            </button>
          </div>
        </form>
      </section>

      <div v-else class="track-order-shell--split">
        <section class="account-card">
          <div class="track-order-summary">
            <div>
              <strong>#{{ order.id }}</strong>
              <p>{{ orderSummaryLine }}</p>
            </div>
            <span class="track-order-price">{{ formatPrice(order.totalPrice || 0) }}</span>
          </div>

          <p class="track-order-arrival">{{ arrivalLine }}</p>

          <div v-if="trackingDetails.length > 0" class="track-order-meta">
            <div v-for="entry in trackingDetails" :key="entry.key" class="track-order-meta-row">
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

          <div class="track-order-progress" :style="{ '--track-progress-fill': progressFillWidth }">
            <div
              v-for="(stage, index) in progressStages"
              :key="stage.key"
              class="track-order-stage"
              :class="{
                'track-order-stage--active': index === currentStageIndex,
                'track-order-stage--done': index < currentStageIndex,
              }"
            >
              <span class="track-order-stage__icon">
                <svg viewBox="0 0 24 24" aria-hidden="true">
                  <path :d="renderActivityIcon(stage.icon)" />
                </svg>
              </span>
              <strong>{{ stage.label }}</strong>
              <span>{{ index <= currentStageIndex ? "Current flow" : "Waiting" }}</span>
            </div>
          </div>
        </section>

        <section class="account-card">
          <div class="account-card__header">
            <div>
              <h2>Order activity</h2>
              <p>Every important status change appears here with the latest timeline.</p>
            </div>
            <button class="market-button market-button--secondary" type="button" @click="clearTrackedOrderDetails">
              Track another order
            </button>
          </div>

          <div class="track-order-activity">
            <article
              v-for="entry in activityEntries"
              :key="entry.key"
            >
              <span class="track-order-activity__icon">
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
        </section>
      </div>
    </div>
  </section>
</template>
