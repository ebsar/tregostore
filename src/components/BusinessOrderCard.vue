<script setup>
import { reactive } from "vue";
import OrderItemCard from "./OrderItemCard.vue";
import {
  buildFulfillmentTimeline,
  formatDateLabel,
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
      fulfillmentStatus: String(item?.fulfillmentStatus || "confirmed"),
      trackingCode: String(item?.trackingCode || ""),
      trackingUrl: String(item?.trackingUrl || ""),
    };
  }

  return draftByItemId[itemId];
}

function submitStatus(item) {
  const draft = draftFor(item);
  emit("update-status", {
    orderItemId: item.id,
    fulfillmentStatus: draft.fulfillmentStatus,
    trackingCode: draft.trackingCode,
    trackingUrl: draft.trackingUrl,
  });
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
        </div>
        <div class="order-card-meta">
          <span>{{ formatPaymentMethodLabel(order.paymentMethod) }}</span>
          <strong>{{ formatDateLabel(order.createdAt || "") }}</strong>
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

          <div v-if="canManageStatus" class="order-item-management-grid">
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
            <span>Shuma e porosise</span>
            <strong>{{ formatPrice(order.totalPrice || 0) }}</strong>
          </div>
        </div>
      </aside>
    </div>
  </article>
</template>
