<template>
  <aside v-if="order" class="order-details-panel" aria-label="Order details">
    <header class="order-details-panel__header">
      <button type="button" class="order-details-panel__back" @click="$emit('close')">
        <svg aria-hidden="true" viewBox="0 0 24 24">
          <path d="m15 18-6-6 6-6" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
        </svg>
        Back
      </button>
      <OrderStatusBadge :order="order" />
    </header>

    <section class="order-details-panel__hero">
      <span>Order #{{ order.id }}</span>
      <h2>Order summary</h2>
      <div class="order-details-panel__stats">
        <div>
          <small>Order date</small>
          <strong>{{ formatDateLabel(order.createdAt) || "Recently" }}</strong>
        </div>
        <div>
          <small>Total paid</small>
          <strong>{{ formatPrice(order.totalPrice || 0) }}</strong>
        </div>
        <div>
          <small>Items</small>
          <strong>{{ order.totalItems || itemCount }}</strong>
        </div>
      </div>
    </section>

    <OrderTimeline :order="order" />

    <section class="order-details-panel__section">
      <div class="order-details-panel__section-head">
        <span>Items in Order</span>
        <small>{{ itemCount }} product{{ itemCount === 1 ? "" : "s" }}</small>
      </div>
      <OrderItemsList :items="order.items || []" @contact-seller="$emit('contact-seller', $event)" />
    </section>

    <section class="order-details-panel__summary-grid">
      <PaymentSummaryCard :order="order" />
      <DeliveryAddressCard :order="order" />
      <OrderSupportCard
        :order="order"
        :returnable-item="returnableItem"
        :busy="Boolean(returnableItem && busyOrderItemId === returnableItem.id)"
        @request-return="$emit('request-return', $event)"
        @report-problem="$emit('report-problem', order)"
        @contact-support="$emit('contact-support')"
      />
    </section>
  </aside>
</template>

<script setup>
import { computed } from "vue";
import { formatDateLabel, formatPrice } from "../../lib/shop";
import DeliveryAddressCard from "./DeliveryAddressCard.vue";
import OrderItemsList from "./OrderItemsList.vue";
import OrderStatusBadge from "./OrderStatusBadge.vue";
import OrderSupportCard from "./OrderSupportCard.vue";
import OrderTimeline from "./OrderTimeline.vue";
import PaymentSummaryCard from "./PaymentSummaryCard.vue";

const props = defineProps({
  busyOrderItemId: {
    type: [Number, String],
    default: null,
  },
  order: {
    type: Object,
    default: null,
  },
});

defineEmits(["close", "contact-seller", "contact-support", "report-problem", "request-return"]);

const itemCount = computed(() => (props.order?.items || []).reduce((total, item) => total + Number(item.quantity || 1), 0));

const returnableItem = computed(() => {
  const items = props.order?.items || [];
  return items.find((item) => {
    const status = String(item.fulfillmentStatus || props.order?.fulfillmentStatus || props.order?.status || "").toLowerCase();
    return ["delivered", "shipped"].includes(status) && !item.returnRequestStatus;
  }) || null;
});
</script>
