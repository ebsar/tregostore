<script setup>
import { reactive } from "vue";
import OrderItemCard from "./OrderItemCard.vue";
import {
  buildFulfillmentTimeline,
  formatOrderStatusBadgeLabel,
  formatDateLabel,
  formatDeliveryMethodLabel,
  formatEstimatedDeliveryLabel,
  formatFulfillmentStatusLabel,
  formatPaymentMethodLabel,
  formatPrice,
  getFulfillmentTerminalEvent,
} from "../lib/shop";

const props = defineProps({
  order: {
    type: Object,
    required: true,
  },
  canManageStatus: {
    type: Boolean,
    default: false,
  },
  showAdminFinance: {
    type: Boolean,
    default: false,
  },
  busyOrderId: {
    type: Number,
    default: 0,
  },
});

const emit = defineEmits(["update-order-status"]);
const draftByOrderId = reactive({});

function normalizeStatus(value) {
  return String(value || "").trim().toLowerCase();
}

function resolveDraftStatus(value) {
  const normalizedValue = normalizeStatus(value);
  if (["confirmed", "packed", "shipped", "delivered", "cancelled", "returned"].includes(normalizedValue)) {
    return normalizedValue;
  }
  if (normalizedValue === "canceled" || normalizedValue === "failed") {
    return "cancelled";
  }
  if (normalizedValue === "refunded") {
    return "returned";
  }

  return "confirmed";
}

function orderDraftFor(order) {
  const orderId = Number(order?.id || 0);
  if (!draftByOrderId[orderId]) {
    const items = Array.isArray(order?.items) ? order.items : [];
    const trackingSource = items.find((item) => item?.trackingCode || item?.trackingUrl) || items[0] || {};
    draftByOrderId[orderId] = {
      fulfillmentStatus: resolveDraftStatus(order?.fulfillmentStatus || order?.status || "confirmed"),
      trackingCode: String(trackingSource?.trackingCode || ""),
      trackingUrl: String(trackingSource?.trackingUrl || ""),
    };
  }

  return draftByOrderId[orderId];
}

function orderItemIdsForStatus(order, nextStatus) {
  const resolvedStatus = normalizeStatus(nextStatus);
  const items = Array.isArray(order?.items) ? order.items : [];

  return items
    .filter((item) => {
      const currentStatus = normalizeStatus(item?.fulfillmentStatus);
      if (resolvedStatus === "confirmed") {
        return currentStatus === "pending_confirmation" || currentStatus === "confirmed";
      }
      if (resolvedStatus === "packed") {
        return ["confirmed", "packed"].includes(currentStatus);
      }
      if (resolvedStatus === "shipped") {
        return ["confirmed", "packed", "shipped"].includes(currentStatus);
      }
      if (resolvedStatus === "delivered") {
        return ["confirmed", "packed", "shipped", "delivered"].includes(currentStatus);
      }
      if (resolvedStatus === "cancelled") {
        return ["pending_confirmation", "confirmed", "packed", "shipped"].includes(currentStatus);
      }
      if (resolvedStatus === "returned") {
        return ["delivered", "returned"].includes(currentStatus);
      }

      return false;
    })
    .map((item) => Number(item?.id || 0))
    .filter((itemId) => itemId > 0);
}

function pendingConfirmationItemIds(order) {
  const items = Array.isArray(order?.items) ? order.items : [];
  return items
    .filter((item) => normalizeStatus(item?.fulfillmentStatus) === "pending_confirmation")
    .map((item) => Number(item?.id || 0))
    .filter((itemId) => itemId > 0);
}

function activeOrderItemIds(order) {
  return orderItemIdsForStatus(order, "cancelled");
}

function submitOrderStatus(order, nextStatus = "") {
  const draft = orderDraftFor(order);
  const resolvedStatus = String(nextStatus || draft.fulfillmentStatus || "").trim().toLowerCase() || "confirmed";
  const orderItemIds = nextStatus === "cancelled"
    ? activeOrderItemIds(order)
    : orderItemIdsForStatus(order, resolvedStatus);

  if (!orderItemIds.length) {
    return;
  }

  draft.fulfillmentStatus = resolvedStatus;
  emit("update-order-status", {
    orderId: Number(order?.id || 0),
    orderItemIds,
    fulfillmentStatus: resolvedStatus,
    trackingCode: draft.trackingCode,
    trackingUrl: draft.trackingUrl,
  });
}

function confirmPendingOrder(order) {
  const pendingIds = pendingConfirmationItemIds(order);
  if (!pendingIds.length) {
    return;
  }

  const draft = orderDraftFor(order);
  draft.fulfillmentStatus = "confirmed";
  emit("update-order-status", {
    orderId: Number(order?.id || 0),
    orderItemIds: pendingIds,
    fulfillmentStatus: "confirmed",
    trackingCode: draft.trackingCode,
    trackingUrl: draft.trackingUrl,
  });
}

function cancelOrder(order) {
  submitOrderStatus(order, "cancelled");
}

function timelineFor(item) {
  return buildFulfillmentTimeline(item);
}

function terminalEventFor(item) {
  return getFulfillmentTerminalEvent(item);
}

function hasPendingConfirmation(order) {
  return pendingConfirmationItemIds(order).length > 0;
}

function affectedItemsLabel(order) {
  const draft = orderDraftFor(order);
  const count = orderItemIdsForStatus(order, draft.fulfillmentStatus).length;
  if (!count) {
    return "Nuk ka artikuj te vlefshem per kete status.";
  }

  return `Ky veprim do te perditesoje ${count} artikuj ne kete porosi.`;
}
</script>

<template>
  <article class="business-order-card">
      <div class="business-order-card__header">
        <div class="business-order-card__meta">
          <p>Porosia #{{ order.id || "-" }}</p>
          <h2>{{ order.customerName || "Klient" }}</h2>
          <p>{{ order.customerEmail || "-" }}</p>
          <div v-if="formatOrderStatusBadgeLabel(order.fulfillmentStatus || order.status)">
            <span class="dashboard-badge dashboard-badge--warning">
              {{ formatOrderStatusBadgeLabel(order.fulfillmentStatus || order.status) }}
            </span>
          </div>
        </div>
        <div class="business-order-card__meta">
          <span>{{ formatPaymentMethodLabel(order.paymentMethod) }}</span>
          <strong>{{ formatDateLabel(order.createdAt || "") }}</strong>
          <a
            class="market-button market-button--ghost"
            :href="`/api/orders/invoice?id=${order.id}`"
            target="_blank"
            rel="noreferrer"
          >
            Fatura PDF
          </a>
        </div>
      </div>

      <div class="business-order-card__body">
        <div v-if="canManageStatus && hasPendingConfirmation(order)" class="business-order-card__decision">
          <div class="business-order-card__decision-copy">
            <span>Pret konfirmim</span>
            <strong>Konfirmoje ose anuloje nje here per te gjithe artikujt e kesaj porosie.</strong>
          </div>
          <button
            class="market-button market-button--primary"
            type="button"
            :disabled="busyOrderId === Number(order.id)"
            @click="confirmPendingOrder(order)"
          >
            {{ busyOrderId === Number(order.id) ? "Duke konfirmuar..." : "Konfirmo porosine" }}
          </button>
          <button
            class="market-button market-button--ghost"
            type="button"
            :disabled="busyOrderId === Number(order.id)"
            @click="cancelOrder(order)"
          >
            {{ busyOrderId === Number(order.id) ? "Duke anuluar..." : "Anulo porosine" }}
          </button>
        </div>

        <div v-else-if="canManageStatus" class="business-order-card__controls">
          <label>
            <span>Fulfillment</span>
            <select v-model="orderDraftFor(order).fulfillmentStatus">
              <option value="confirmed">Confirmed</option>
              <option value="packed">Packed</option>
              <option value="shipped">Shipped</option>
              <option value="delivered">Delivered</option>
              <option value="cancelled">Cancelled</option>
              <option value="returned">Returned</option>
            </select>
          </label>

          <label>
            <span>Tracking code</span>
            <input v-model="orderDraftFor(order).trackingCode" type="text" placeholder="p.sh. TRK-2048">
          </label>

          <label>
            <span>Tracking link</span>
            <input v-model="orderDraftFor(order).trackingUrl" type="url" placeholder="https://...">
          </label>

          <p class="dashboard-note">{{ affectedItemsLabel(order) }}</p>

          <button
            class="market-button market-button--primary"
            type="button"
            :disabled="busyOrderId === Number(order.id) || !orderItemIdsForStatus(order, orderDraftFor(order).fulfillmentStatus).length"
            @click="submitOrderStatus(order)"
          >
            {{ busyOrderId === Number(order.id) ? "Duke ruajtur..." : "Ruaje statusin e porosise" }}
          </button>
        </div>

        <div class="business-order-card__items">
        <div v-for="item in order.items || []" :key="item.id" class="business-order-card__item">
          <OrderItemCard
            :item="item"
            :show-business-name="showAdminFinance"
          />
          <div class="business-order-card__timeline" aria-label="Rrjedha e porosise">
            <div
              v-for="step in timelineFor(item)"
              :key="`${item.id}-${step.key}`"
              class="business-order-card__timeline-step"
            >
              <span></span>
              <span>
                <strong>{{ step.label }}</strong>
                <span v-if="step.meta">{{ step.meta }}</span>
              </span>
            </div>
          </div>
          <div
            v-if="terminalEventFor(item)"
            class="business-order-card__terminal"
          >
            <strong>{{ terminalEventFor(item).label }}</strong>
            <span v-if="terminalEventFor(item).meta">{{ terminalEventFor(item).meta }}</span>
          </div>
          <div class="business-order-card__facts">
            <span class="business-order-card__fact">
              <span>Statusi</span>
              <strong>{{ formatFulfillmentStatusLabel(item.fulfillmentStatus) }}</strong>
            </span>
            <span v-if="item.fulfillmentStatus === 'pending_confirmation' && item.confirmationDueAt" class="business-order-card__fact">
              <span>Afati</span>
              <strong>{{ formatDateLabel(item.confirmationDueAt) }}</strong>
            </span>
            <span v-if="showAdminFinance" class="business-order-card__fact">
              <span>Komisioni</span>
              <strong>{{ formatPrice(item.commissionAmount || 0) }}</strong>
            </span>
            <span v-if="showAdminFinance" class="business-order-card__fact">
              <span>Biznesi merr</span>
              <strong>{{ formatPrice(item.sellerEarningsAmount || 0) }}</strong>
            </span>
            <span class="business-order-card__fact">
              <span>Payout</span>
              <strong>{{ item.payoutStatus || "pending" }}</strong>
            </span>
          </div>
        </div>
      </div>

      <aside class="business-order-card__aside">
        <p>Informacionet e pranimit</p>
        <div class="business-order-card__meta-grid">
          <div class="business-order-card__meta">
            <span>Adresa</span>
            <strong>{{ order.addressLine || "-" }}</strong>
          </div>
          <div class="business-order-card__meta">
            <span>Qyteti</span>
            <strong>{{ order.city || "-" }}</strong>
          </div>
          <div class="business-order-card__meta">
            <span>Shteti</span>
            <strong>{{ order.country || "-" }}</strong>
          </div>
          <div class="business-order-card__meta">
            <span>Zip code</span>
            <strong>{{ order.zipCode || "-" }}</strong>
          </div>
          <div class="business-order-card__meta">
            <span>Numri i telefonit</span>
            <strong>{{ order.phoneNumber || "-" }}</strong>
          </div>
          <div class="business-order-card__meta">
            <span>Dergesa</span>
            <strong>{{ order.deliveryLabel || formatDeliveryMethodLabel(order.deliveryMethod) }}</strong>
          </div>
          <div class="business-order-card__meta">
            <span>Afati</span>
            <strong>{{ formatEstimatedDeliveryLabel(order.deliveryMethod, order.estimatedDeliveryText) || "-" }}</strong>
          </div>
          <div class="business-order-card__meta">
            <span>Transporti</span>
            <strong>{{ formatPrice(order.shippingAmount || 0) }}</strong>
          </div>
          <div class="business-order-card__meta">
            <span>Shuma e porosise</span>
            <strong>{{ formatPrice(order.totalPrice || 0) }}</strong>
          </div>
        </div>
      </aside>
    </div>
  </article>
</template>
