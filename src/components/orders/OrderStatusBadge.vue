<template>
  <span class="order-status-badge" :class="badgeClass">
    <span class="order-status-badge__dot" aria-hidden="true"></span>
    {{ label }}
  </span>
</template>

<script setup>
import { computed } from "vue";

const props = defineProps({
  order: {
    type: Object,
    required: true,
  },
});

const normalizedStatus = computed(() => {
  const orderStatus = String(props.order?.status || "").toLowerCase();
  const fulfillmentStatus = String(props.order?.fulfillmentStatus || "").toLowerCase();
  const itemStatuses = Array.isArray(props.order?.items)
    ? props.order.items.map((item) => String(item?.fulfillmentStatus || "").toLowerCase())
    : [];
  const hasReturnActivity = Array.isArray(props.order?.items)
    ? props.order.items.some((item) => item?.returnRequestStatus || ["returned", "refunded"].includes(String(item?.fulfillmentStatus || "").toLowerCase()))
    : false;

  if (hasReturnActivity || ["refunded", "returned", "return_requested"].includes(orderStatus)) {
    return "refunded";
  }

  if ([orderStatus, fulfillmentStatus, ...itemStatuses].some((status) => ["cancelled", "canceled", "failed"].includes(status))) {
    return "cancelled";
  }

  if ([orderStatus, fulfillmentStatus, ...itemStatuses].includes("delivered")) {
    return "delivered";
  }

  if ([orderStatus, fulfillmentStatus, ...itemStatuses].some((status) => ["shipped", "in_transit", "out_for_delivery"].includes(status))) {
    return "shipped";
  }

  return "processing";
});

const labels = {
  cancelled: "Cancelled",
  delivered: "Delivered",
  processing: "Processing",
  refunded: "Refunded",
  shipped: "Shipped",
};

const label = computed(() => labels[normalizedStatus.value] || "Processing");
const badgeClass = computed(() => `order-status-badge--${normalizedStatus.value}`);
</script>
