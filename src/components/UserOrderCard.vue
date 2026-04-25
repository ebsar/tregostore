<script setup>
import { computed } from "vue";
import OrderItemCard from "./OrderItemCard.vue";
import {
  buildFulfillmentTimeline,
  formatDateLabel,
  formatDeliveryMethodLabel,
  formatEstimatedDeliveryLabel,
  formatFulfillmentStatusLabel,
  formatOrderStatusBadgeLabel,
  formatPaymentMethodLabel,
  formatPrice,
  formatReturnRequestStatusLabel,
  getAutomaticRefundNotice,
  getFulfillmentTerminalEvent,
} from "../lib/shop";

const props = defineProps({
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

const vendorGroups = computed(() => {
  const groupedItems = new Map();

  (Array.isArray(props.order?.items) ? props.order.items : []).forEach((item, index) => {
    const businessName = String(item?.businessName || "").trim() || "Marketplace seller";
    const key = `${businessName.toLowerCase()}-${index}`;
    const existingEntry = Array.from(groupedItems.values()).find((entry) => entry.businessName === businessName);
    if (existingEntry) {
      existingEntry.items.push(item);
      existingEntry.total += Number(item?.totalPrice || 0);
      return;
    }

    groupedItems.set(key, {
      key,
      businessName,
      items: [item],
      total: Number(item?.totalPrice || 0),
    });
  });

  return Array.from(groupedItems.values());
});

function timelineFor(item) {
  return buildFulfillmentTimeline(item);
}

function terminalEventFor(item) {
  return getFulfillmentTerminalEvent(item);
}
</script>

<template>
  <article class="user-order-card">
    <header class="user-order-card__header">
      <div class="user-order-card__header-copy">
        <p>Order #{{ order.id || "-" }}</p>
        <h2>{{ formatFulfillmentStatusLabel(order.fulfillmentStatus || order.status) }}</h2>
        <span
          v-if="formatOrderStatusBadgeLabel(order.fulfillmentStatus || order.status)"
          class="dashboard-badge dashboard-badge--warning"
        >
          {{ formatOrderStatusBadgeLabel(order.fulfillmentStatus || order.status) }}
        </span>
      </div>

      <div class="user-order-card__header-meta">
        <span>{{ formatPaymentMethodLabel(order.paymentMethod) }}</span>
        <strong>{{ formatDateLabel(order.createdAt || "") }}</strong>
      </div>
    </header>

    <div class="user-order-card__summary">
      <div class="user-order-card__summary-item">
        <span>Items</span>
        <strong>{{ order.totalItems || 0 }}</strong>
      </div>
      <div class="user-order-card__summary-item">
        <span>Shipping</span>
        <strong>{{ formatPrice(order.shippingAmount || 0) }}</strong>
      </div>
      <div class="user-order-card__summary-item">
        <span>Total</span>
        <strong>{{ formatPrice(order.totalPrice || 0) }}</strong>
      </div>
      <div class="user-order-card__summary-item">
        <span>Payment status</span>
        <strong>{{ String(order.paymentStatus || "paid").trim() || "paid" }}</strong>
      </div>
    </div>

    <div class="user-order-card__body">
      <div class="user-order-card__items">
        <article
          v-for="vendor in vendorGroups"
          :key="vendor.key"
          class="user-order-card__vendor"
        >
          <header class="user-order-card__vendor-header">
            <div>
              <p>Seller</p>
              <h3>{{ vendor.businessName }}</h3>
            </div>
            <strong>{{ formatPrice(vendor.total) }}</strong>
          </header>

          <div class="user-order-card__vendor-items">
            <div
              v-for="item in vendor.items"
              :key="item.id"
              class="user-order-card__vendor-item"
            >
              <OrderItemCard :item="item" :show-business-name="false" />

              <div class="user-order-card__timeline" aria-label="Order timeline">
                <div
                  v-for="step in timelineFor(item)"
                  :key="`${item.id}-${step.key}`"
                  class="user-order-card__timeline-step"
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
                class="user-order-card__terminal"
              >
                <strong>{{ terminalEventFor(item).label }}</strong>
                <span v-if="terminalEventFor(item).meta">{{ terminalEventFor(item).meta }}</span>
              </div>

              <div class="user-order-card__facts">
                <span class="user-order-card__fact">
                  <span>Status</span>
                  <strong>{{ formatFulfillmentStatusLabel(item.fulfillmentStatus) }}</strong>
                </span>
                <span v-if="item.trackingCode" class="user-order-card__fact">
                  <span>Tracking</span>
                  <strong>{{ item.trackingCode }}</strong>
                </span>
                <a
                  v-if="item.trackingUrl"
                  class="market-button market-button--ghost"
                  :href="item.trackingUrl"
                  target="_blank"
                  rel="noreferrer"
                >
                  Track shipment
                </a>
                <button
                  v-if="item.fulfillmentStatus === 'delivered' && !item.returnRequestStatus"
                  class="market-button market-button--secondary"
                  type="button"
                  :disabled="busyOrderItemId === Number(item.id)"
                  @click="emit('request-return', item)"
                >
                  {{ busyOrderItemId === Number(item.id) ? "Sending..." : "Request return" }}
                </button>
                <span v-else-if="item.returnRequestStatus" class="user-order-card__fact">
                  <span>Return</span>
                  <strong>{{ formatReturnRequestStatusLabel(item.returnRequestStatus) }}</strong>
                </span>
              </div>

              <div v-if="getAutomaticRefundNotice(item)" class="user-order-card__refund-note">
                <strong>Automatic refund</strong>
                <span>{{ getAutomaticRefundNotice(item) }}</span>
              </div>
            </div>
          </div>
        </article>
      </div>

      <aside class="user-order-card__aside">
        <p>Shipping details</p>
        <div class="user-order-card__meta-grid">
          <div class="user-order-card__meta">
            <span>Address</span>
            <strong>{{ order.addressLine || "-" }}</strong>
          </div>
          <div class="user-order-card__meta">
            <span>City</span>
            <strong>{{ order.city || "-" }}</strong>
          </div>
          <div class="user-order-card__meta">
            <span>Country</span>
            <strong>{{ order.country || "-" }}</strong>
          </div>
          <div class="user-order-card__meta">
            <span>Zip code</span>
            <strong>{{ order.zipCode || "-" }}</strong>
          </div>
          <div class="user-order-card__meta">
            <span>Phone</span>
            <strong>{{ order.phoneNumber || "-" }}</strong>
          </div>
          <div class="user-order-card__meta">
            <span>Delivery</span>
            <strong>{{ order.deliveryLabel || formatDeliveryMethodLabel(order.deliveryMethod) }}</strong>
          </div>
          <div class="user-order-card__meta">
            <span>ETA</span>
            <strong>{{ formatEstimatedDeliveryLabel(order.deliveryMethod, order.estimatedDeliveryText) || "-" }}</strong>
          </div>
          <div class="user-order-card__meta">
            <span>Payment</span>
            <strong>{{ formatPaymentMethodLabel(order.paymentMethod) }}</strong>
          </div>
        </div>

        <a
          class="market-button market-button--secondary"
          :href="`/api/orders/invoice?id=${order.id}`"
          target="_blank"
          rel="noreferrer"
        >
          Download invoice
        </a>
      </aside>
    </div>
  </article>
</template>
