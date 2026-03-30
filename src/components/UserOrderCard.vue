<script setup>
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
  formatReturnRequestStatusLabel,
  getAutomaticRefundNotice,
  getFulfillmentTerminalEvent,
} from "../lib/shop";

defineProps({
  order: {
    type: Object,
    required: true,
  },
  busyOrderItemId: {
    type: Number,
    default: 0,
  },
});

const emit = defineEmits(["request-return"]);

function timelineFor(item) {
  return buildFulfillmentTimeline(item);
}

function terminalEventFor(item) {
  return getFulfillmentTerminalEvent(item);
}
</script>

<template>
  <article class="card order-card">
    <div class="order-card-top">
      <div>
        <p class="section-label">Porosia #{{ order.id || "-" }}</p>
        <h2>{{ formatFulfillmentStatusLabel(order.fulfillmentStatus || order.status) }}</h2>
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
      </div>
    </div>

    <div class="order-summary-chips">
      <div class="summary-chip">
        <span>Produktet</span>
        <strong>{{ order.totalItems || 0 }}</strong>
      </div>
      <div class="summary-chip">
        <span>Transporti</span>
        <strong>{{ formatPrice(order.shippingAmount || 0) }}</strong>
      </div>
      <div class="summary-chip">
        <span>Shuma totale</span>
        <strong>{{ formatPrice(order.totalPrice || 0) }}</strong>
      </div>
    </div>

    <div class="order-card-body">
      <div class="order-items-list">
        <div v-for="item in order.items || []" :key="item.id" class="order-item-shell">
          <OrderItemCard :item="item" />
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
          <div class="order-item-marketplace-meta">
            <span class="summary-chip">
              <span>Statusi</span>
              <strong>{{ formatFulfillmentStatusLabel(item.fulfillmentStatus) }}</strong>
            </span>
            <span v-if="item.trackingCode" class="summary-chip">
              <span>Tracking</span>
              <strong>{{ item.trackingCode }}</strong>
            </span>
            <a
              v-if="item.trackingUrl"
              class="nav-action nav-action-secondary"
              :href="item.trackingUrl"
              target="_blank"
              rel="noreferrer"
            >
              Ndiqe dergesen
            </a>
            <button
              v-if="item.fulfillmentStatus === 'delivered' && !item.returnRequestStatus"
              class="nav-action nav-action-secondary"
              type="button"
              :disabled="busyOrderItemId === Number(item.id)"
              @click="emit('request-return', item)"
            >
              {{ busyOrderItemId === Number(item.id) ? "Duke derguar..." : "Kerko kthim" }}
            </button>
            <span v-else-if="item.returnRequestStatus" class="summary-chip">
              <span>Kthimi</span>
              <strong>{{ formatReturnRequestStatusLabel(item.returnRequestStatus) }}</strong>
            </span>
          </div>
          <div v-if="getAutomaticRefundNotice(item)" class="order-refund-notice">
            <strong>Refund automatik</strong>
            <span>{{ getAutomaticRefundNotice(item) }}</span>
          </div>
        </div>
      </div>

      <aside class="order-address-card">
        <p class="section-label">Adresa e dergeses</p>
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
          <a
            class="nav-action nav-action-secondary order-invoice-button"
            :href="`/api/orders/invoice?id=${order.id}`"
            target="_blank"
            rel="noreferrer"
          >
            Shkarko faturen PDF
          </a>
        </div>
      </aside>
    </div>
  </article>
</template>
