<template>
  <section class="order-timeline" aria-label="Order tracking timeline">
    <article
      v-for="step in steps"
      :key="step.key"
      class="order-timeline__step"
      :class="{
        'order-timeline__step--complete': step.complete,
        'order-timeline__step--active': step.active,
      }"
    >
      <span class="order-timeline__marker" aria-hidden="true"></span>
      <div>
        <strong>{{ step.label }}</strong>
        <span>{{ step.meta }}</span>
      </div>
    </article>
  </section>
</template>

<script setup>
import { computed } from "vue";
import { formatDateLabel } from "../../lib/shop";

const props = defineProps({
  order: {
    type: Object,
    required: true,
  },
});

const statusRank = computed(() => {
  const statuses = [
    String(props.order?.status || "").toLowerCase(),
    String(props.order?.fulfillmentStatus || "").toLowerCase(),
    ...(Array.isArray(props.order?.items) ? props.order.items.map((item) => String(item?.fulfillmentStatus || "").toLowerCase()) : []),
  ];

  if (statuses.some((status) => ["delivered", "returned", "refunded"].includes(status))) return 5;
  if (statuses.some((status) => ["out_for_delivery"].includes(status))) return 4;
  if (statuses.some((status) => ["shipped", "in_transit"].includes(status))) return 3;
  if (statuses.some((status) => ["confirmed", "packed", "processing", "partially_confirmed"].includes(status))) return 2;
  return 1;
});

const firstItemDate = (field) => {
  const item = Array.isArray(props.order?.items)
    ? props.order.items.find((entry) => entry?.[field])
    : null;
  return item?.[field];
};

const steps = computed(() => {
  const placedDate = formatDateLabel(props.order?.createdAt);
  const shippedDate = formatDateLabel(firstItemDate("shippedAt"));
  const deliveredDate = formatDateLabel(firstItemDate("deliveredAt"));
  const estimate = props.order?.estimatedDeliveryText || "Estimated soon";

  return [
    {
      key: "placed",
      label: "Order Placed",
      meta: placedDate || "Order received",
      complete: statusRank.value >= 1,
      active: statusRank.value === 1,
    },
    {
      key: "payment",
      label: "Payment Confirmed",
      meta: props.order?.paymentMethod ? `Paid with ${props.order.paymentMethod}` : "Payment confirmed",
      complete: statusRank.value >= 1,
      active: false,
    },
    {
      key: "processing",
      label: "Processing",
      meta: "Seller is preparing your order",
      complete: statusRank.value >= 2,
      active: statusRank.value === 2,
    },
    {
      key: "shipped",
      label: "Shipped",
      meta: shippedDate || "Waiting for shipment",
      complete: statusRank.value >= 3,
      active: statusRank.value === 3,
    },
    {
      key: "out-for-delivery",
      label: "Out for Delivery",
      meta: statusRank.value >= 4 ? "Courier is delivering today" : estimate,
      complete: statusRank.value >= 4,
      active: statusRank.value === 4,
    },
    {
      key: "delivered",
      label: "Delivered",
      meta: deliveredDate || "Not delivered yet",
      complete: statusRank.value >= 5,
      active: statusRank.value === 5,
    },
  ];
});
</script>
