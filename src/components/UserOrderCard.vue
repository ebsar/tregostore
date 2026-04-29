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

const orderItems = computed(() => (Array.isArray(props.order?.items) ? props.order.items : []));

const vendorGroups = computed(() => {
  const groupedItems = new Map();

  orderItems.value.forEach((item, index) => {
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

const orderProductCount = computed(() => {
  const explicitTotal = Number(props.order?.totalItems);
  if (Number.isFinite(explicitTotal) && explicitTotal > 0) {
    return explicitTotal;
  }

  return orderItems.value.reduce((total, item) => total + Math.max(1, Number(item?.quantity) || 1), 0);
});

const productsLabel = computed(() => `${orderProductCount.value} item${orderProductCount.value === 1 ? "" : "s"}`);

const sellersLabel = computed(() => {
  const totalSellers = vendorGroups.value.length;
  return `${totalSellers} seller${totalSellers === 1 ? "" : "s"}`;
});

const orderStatusValue = computed(() => props.order?.fulfillmentStatus || props.order?.status || orderItems.value[0]?.fulfillmentStatus || "pending_confirmation");

const orderStatusSourceItem = computed(() => {
  const normalizedOrderStatus = String(orderStatusValue.value || "").trim().toLowerCase();

  return (
    orderItems.value.find((item) => String(item?.fulfillmentStatus || "").trim().toLowerCase() === normalizedOrderStatus)
    || orderItems.value.find((item) => item?.trackingCode || item?.trackingUrl || item?.shippedAt || item?.deliveredAt)
    || orderItems.value[0]
    || {}
  );
});

const orderFulfillmentSnapshot = computed(() => {
  const sourceItem = orderStatusSourceItem.value || {};

  return {
    ...sourceItem,
    status: orderStatusValue.value,
    fulfillmentStatus: orderStatusValue.value,
    confirmationDueAt: props.order?.confirmationDueAt || sourceItem.confirmationDueAt,
    confirmedAt: props.order?.confirmedAt || sourceItem.confirmedAt || props.order?.createdAt,
    createdAt: props.order?.createdAt || sourceItem.createdAt,
    shippedAt: props.order?.shippedAt || sourceItem.shippedAt,
    deliveredAt: props.order?.deliveredAt || sourceItem.deliveredAt,
    cancelledAt: props.order?.cancelledAt || sourceItem.cancelledAt,
  };
});

const orderTimeline = computed(() => buildFulfillmentTimeline(orderFulfillmentSnapshot.value));

const orderTerminalEvent = computed(() => getFulfillmentTerminalEvent(orderFulfillmentSnapshot.value));

const trackingItems = computed(() => orderItems.value.filter((item) => item?.trackingCode || item?.trackingUrl));

const primaryTrackingItem = computed(() => trackingItems.value[0] || null);

const returnableItems = computed(() => orderItems.value.filter((item) => (
  String(item?.fulfillmentStatus || "").trim().toLowerCase() === "delivered"
  && !item?.returnRequestStatus
)));

const returnedItems = computed(() => orderItems.value.filter((item) => item?.returnRequestStatus));

const refundNoticeItems = computed(() => orderItems.value
  .map((item) => ({
    id: item?.id,
    title: item?.title || "Product",
    notice: getAutomaticRefundNotice(item),
  }))
  .filter((item) => item.notice));
</script>

<template>
  <article class="user-order-card">
    <header class="user-order-card__header">
      <div class="user-order-card__header-copy">
        <p>Order #{{ order.id || "-" }}</p>
        <h2>{{ formatFulfillmentStatusLabel(orderStatusValue) }}</h2>
        <span
          v-if="formatOrderStatusBadgeLabel(orderStatusValue)"
          class="dashboard-badge dashboard-badge--warning"
        >
          {{ formatOrderStatusBadgeLabel(orderStatusValue) }}
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
        <strong>{{ orderProductCount }}</strong>
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
        <section class="user-order-card__products">
          <header class="user-order-card__products-head">
            <div>
              <p>Products</p>
              <h3>{{ productsLabel }}</h3>
            </div>
            <strong>{{ sellersLabel }}</strong>
          </header>

          <div
            v-if="orderItems.length"
            class="user-order-card__product-slider"
            tabindex="0"
            aria-label="Products in this order"
          >
            <div
              v-for="(item, index) in orderItems"
              :key="item.id || `${item.title || 'product'}-${index}`"
              class="user-order-card__product-slide"
            >
              <OrderItemCard :item="item" />
            </div>
          </div>

          <p v-else class="dashboard-note">No products found for this order.</p>
        </section>

        <section class="user-order-card__order-status">
          <header class="user-order-card__order-status-head">
            <div>
              <p>Order status</p>
              <h3>{{ formatFulfillmentStatusLabel(orderStatusValue) }}</h3>
            </div>
            <strong>{{ formatOrderStatusBadgeLabel(orderStatusValue) || "Active" }}</strong>
          </header>

          <div class="user-order-card__timeline" aria-label="Order timeline">
            <div
              v-for="step in orderTimeline"
              :key="`order-${order.id || 'active'}-${step.key}`"
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
            v-if="orderTerminalEvent"
            class="user-order-card__terminal"
          >
            <strong>{{ orderTerminalEvent.label }}</strong>
            <span v-if="orderTerminalEvent.meta">{{ orderTerminalEvent.meta }}</span>
          </div>

          <div class="user-order-card__facts">
            <span class="user-order-card__fact">
              <span>Status</span>
              <strong>{{ formatFulfillmentStatusLabel(orderStatusValue) }}</strong>
            </span>
            <span v-if="primaryTrackingItem" class="user-order-card__fact">
              <span>Tracking</span>
              <strong>{{ primaryTrackingItem.trackingCode || "Available" }}</strong>
              <a
                v-if="primaryTrackingItem.trackingUrl"
                class="user-order-card__fact-link"
                :href="primaryTrackingItem.trackingUrl"
                target="_blank"
                rel="noreferrer"
              >
                Track shipment
              </a>
              <span v-if="trackingItems.length > 1">{{ trackingItems.length }} tracking numbers</span>
            </span>
            <button
              v-for="item in returnableItems"
              :key="`return-${item.id}`"
              class="market-button market-button--secondary"
              type="button"
              :disabled="busyOrderItemId === Number(item.id)"
              @click="emit('request-return', item)"
            >
              {{ busyOrderItemId === Number(item.id) ? "Sending..." : `Return ${item.title || "item"}` }}
            </button>
            <span
              v-for="item in returnedItems"
              :key="`returned-${item.id}`"
              class="user-order-card__fact"
            >
              <span>Return: {{ item.title || "Product" }}</span>
              <strong>{{ formatReturnRequestStatusLabel(item.returnRequestStatus) }}</strong>
            </span>
          </div>

          <div
            v-for="item in refundNoticeItems"
            :key="`refund-${item.id}`"
            class="user-order-card__refund-note"
          >
            <strong>Automatic refund: {{ item.title }}</strong>
            <span>{{ item.notice }}</span>
          </div>
        </section>
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
