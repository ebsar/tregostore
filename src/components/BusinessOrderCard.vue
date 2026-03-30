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
  busyOrderItemId: {
    type: Number,
    default: 0,
  },
});

const emit = defineEmits(["update-status"]);
const draftByItemId = reactive({});

function draftFor(item) {
  const itemId = Number(item?.id || 0);
  if (!draftByItemId[itemId]) {
    draftByItemId[itemId] = {
      fulfillmentStatus: String(item?.fulfillmentStatus || "pending_confirmation"),
      trackingCode: String(item?.trackingCode || ""),
      trackingUrl: String(item?.trackingUrl || ""),
    };
  }

  return draftByItemId[itemId];
}

function submitStatus(item, nextStatus = "") {
  const draft = draftFor(item);
  emit("update-status", {
    orderItemId: item.id,
    fulfillmentStatus: String(nextStatus || draft.fulfillmentStatus || "").trim() || "confirmed",
    trackingCode: draft.trackingCode,
    trackingUrl: draft.trackingUrl,
  });
}

function confirmPendingItem(item) {
  submitStatus(item, "confirmed");
}

function cancelPendingItem(item) {
  submitStatus(item, "cancelled");
}

function timelineFor(item) {
  return buildFulfillmentTimeline(item);
}

function terminalEventFor(item) {
  return getFulfillmentTerminalEvent(item);
}
</script>

<template>
  <article class="card order-card business-order-card">
      <div class="order-card-top">
        <div>
          <p class="section-label">Porosia #{{ order.id || "-" }}</p>
          <h2>{{ order.customerName || "Klient" }}</h2>
          <p class="section-text">{{ order.customerEmail || "-" }}</p>
          <div v-if="formatOrderStatusBadgeLabel(order.fulfillmentStatus || order.status)" class="order-status-badges">
            <span
              class="order-status-badge"
              :class="{
                'is-pending': (order.fulfillmentStatus || order.status) === 'pending_confirmation',
                'is-partial': (order.fulfillmentStatus || order.status) === 'partially_confirmed',
              }"
            >
              {{ formatOrderStatusBadgeLabel(order.fulfillmentStatus || order.status) }}
            </span>
          </div>
        </div>
        <div class="order-card-meta">
          <span>{{ formatPaymentMethodLabel(order.paymentMethod) }}</span>
          <strong>{{ formatDateLabel(order.createdAt || "") }}</strong>
          <a
            class="nav-action nav-action-secondary order-invoice-button"
            :href="`/api/orders/invoice?id=${order.id}`"
            target="_blank"
            rel="noreferrer"
          >
            Fatura PDF
          </a>
        </div>
      </div>

      <div class="order-card-body">
        <div class="order-items-list">
        <div v-for="item in order.items || []" :key="item.id" class="order-item-shell">
          <OrderItemCard
            :item="item"
            :show-business-name="false"
          />
          <div class="order-item-timeline" aria-label="Rrjedha e porosise">
            <div
              v-for="step in timelineFor(item)"
              :key="`${item.id}-${step.key}`"
              class="order-timeline-step"
              :class="{
                'is-completed': step.isCompleted || step.isDelivered,
                'is-current': step.isCurrent,
              }"
            >
              <span class="order-timeline-dot"></span>
              <span class="order-timeline-copy">
                <strong>{{ step.label }}</strong>
                <span v-if="step.meta">{{ step.meta }}</span>
              </span>
            </div>
          </div>
          <div
            v-if="terminalEventFor(item)"
            class="order-terminal-event"
            :class="`is-${terminalEventFor(item).tone}`"
          >
            <strong>{{ terminalEventFor(item).label }}</strong>
            <span v-if="terminalEventFor(item).meta">{{ terminalEventFor(item).meta }}</span>
          </div>
          <div class="order-item-marketplace-meta is-management">
            <span class="summary-chip">
              <span>Statusi</span>
              <strong>{{ formatFulfillmentStatusLabel(item.fulfillmentStatus) }}</strong>
            </span>
            <span v-if="item.fulfillmentStatus === 'pending_confirmation' && item.confirmationDueAt" class="summary-chip">
              <span>Afati</span>
              <strong>{{ formatDateLabel(item.confirmationDueAt) }}</strong>
            </span>
            <span v-if="showAdminFinance" class="summary-chip">
              <span>Komisioni</span>
              <strong>{{ formatPrice(item.commissionAmount || 0) }}</strong>
            </span>
            <span v-if="showAdminFinance" class="summary-chip">
              <span>Biznesi merr</span>
              <strong>{{ formatPrice(item.sellerEarningsAmount || 0) }}</strong>
            </span>
            <span class="summary-chip">
              <span>Payout</span>
              <strong>{{ item.payoutStatus || "pending" }}</strong>
            </span>
          </div>

          <div v-if="canManageStatus && item.fulfillmentStatus === 'pending_confirmation'" class="order-item-management-grid is-pending-confirmation">
            <div class="summary-chip">
              <span>Pret konfirmim</span>
              <strong>Porosia nuk vazhdon pa pranim nga biznesi</strong>
            </div>
            <button
              class="nav-action nav-action-primary"
              type="button"
              :disabled="busyOrderItemId === Number(item.id)"
              @click="confirmPendingItem(item)"
            >
              {{ busyOrderItemId === Number(item.id) ? "Duke konfirmuar..." : "Konfirmo porosine" }}
            </button>
            <button
              class="nav-action nav-action-secondary"
              type="button"
              :disabled="busyOrderItemId === Number(item.id)"
              @click="cancelPendingItem(item)"
            >
              {{ busyOrderItemId === Number(item.id) ? "Duke anuluar..." : "Anulo porosine" }}
            </button>
          </div>

          <div v-else-if="canManageStatus" class="order-item-management-grid">
            <label class="field">
              <span>Fulfillment</span>
              <select v-model="draftFor(item).fulfillmentStatus">
                <option value="confirmed">Confirmed</option>
                <option value="packed">Packed</option>
                <option value="shipped">Shipped</option>
                <option value="delivered">Delivered</option>
                <option value="cancelled">Cancelled</option>
                <option value="returned">Returned</option>
              </select>
            </label>

            <label class="field">
              <span>Tracking code</span>
              <input v-model="draftFor(item).trackingCode" type="text" placeholder="p.sh. TRK-2048">
            </label>

            <label class="field">
              <span>Tracking link</span>
              <input v-model="draftFor(item).trackingUrl" type="url" placeholder="https://...">
            </label>

            <button
              class="nav-action nav-action-primary"
              type="button"
              :disabled="busyOrderItemId === Number(item.id)"
              @click="submitStatus(item)"
            >
              {{ busyOrderItemId === Number(item.id) ? "Duke ruajtur..." : "Ruaje statusin" }}
            </button>
          </div>
        </div>
      </div>

      <aside class="order-address-card">
        <p class="section-label">Informacionet e pranimit</p>
        <div class="order-address-grid">
          <div class="summary-chip">
            <span>Adresa</span>
            <strong>{{ order.addressLine || "-" }}</strong>
          </div>
          <div class="summary-chip">
            <span>Qyteti</span>
            <strong>{{ order.city || "-" }}</strong>
          </div>
          <div class="summary-chip">
            <span>Shteti</span>
            <strong>{{ order.country || "-" }}</strong>
          </div>
          <div class="summary-chip">
            <span>Zip code</span>
            <strong>{{ order.zipCode || "-" }}</strong>
          </div>
          <div class="summary-chip">
            <span>Numri i telefonit</span>
            <strong>{{ order.phoneNumber || "-" }}</strong>
          </div>
          <div class="summary-chip">
            <span>Dergesa</span>
            <strong>{{ order.deliveryLabel || formatDeliveryMethodLabel(order.deliveryMethod) }}</strong>
          </div>
          <div class="summary-chip">
            <span>Afati</span>
            <strong>{{ formatEstimatedDeliveryLabel(order.deliveryMethod, order.estimatedDeliveryText) || "-" }}</strong>
          </div>
          <div class="summary-chip">
            <span>Transporti</span>
            <strong>{{ formatPrice(order.shippingAmount || 0) }}</strong>
          </div>
          <div class="summary-chip">
            <span>Shuma e porosise</span>
            <strong>{{ formatPrice(order.totalPrice || 0) }}</strong>
          </div>
        </div>
      </aside>
    </div>
  </article>
</template>
