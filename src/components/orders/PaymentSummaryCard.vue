<template>
  <article class="order-summary-card">
    <header>
      <span>Payment Summary</span>
      <strong>{{ formatPrice(order?.totalPrice || 0) }}</strong>
    </header>
    <dl class="order-summary-card__rows">
      <div>
        <dt>Subtotal</dt>
        <dd>{{ formatPrice(order?.subtotalAmount || order?.totalPrice || 0) }}</dd>
      </div>
      <div>
        <dt>Discount</dt>
        <dd>-{{ formatPrice(order?.discountAmount || 0) }}</dd>
      </div>
      <div>
        <dt>Shipping</dt>
        <dd>{{ formatPrice(order?.shippingAmount || 0) }}</dd>
      </div>
      <div>
        <dt>Tax</dt>
        <dd>{{ formatPrice(order?.taxAmount || 0) }}</dd>
      </div>
      <div class="order-summary-card__total">
        <dt>Total Paid</dt>
        <dd>{{ formatPrice(order?.totalPrice || 0) }}</dd>
      </div>
    </dl>
  </article>
</template>

<script setup>
import { formatPrice } from "../../lib/shop";

defineProps({
  order: {
    type: Object,
    required: true,
  },
});
</script>
