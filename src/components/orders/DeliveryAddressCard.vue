<template>
  <article class="order-summary-card">
    <header>
      <span>Delivery Address</span>
      <strong>{{ order?.deliveryLabel || "Standard" }}</strong>
    </header>
    <address class="order-address-card">
      <strong>{{ order?.customerName || "Customer" }}</strong>
      <span>{{ addressLine }}</span>
      <span v-if="locationLine">{{ locationLine }}</span>
      <span v-if="order?.phoneNumber">Phone: {{ order.phoneNumber }}</span>
    </address>
  </article>
</template>

<script setup>
import { computed } from "vue";

const props = defineProps({
  order: {
    type: Object,
    required: true,
  },
});

const addressLine = computed(() => props.order?.addressLine || "No delivery address saved");
const locationLine = computed(() => [props.order?.city, props.order?.zipCode, props.order?.country].filter(Boolean).join(", "));
</script>
