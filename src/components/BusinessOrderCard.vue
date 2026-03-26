<script setup>
import OrderItemCard from "./OrderItemCard.vue";
import { formatDateLabel, formatPaymentMethodLabel, formatPrice } from "../lib/shop";

defineProps({
  order: {
    type: Object,
    required: true,
  },
});
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
        <OrderItemCard
          v-for="item in order.items || []"
          :key="item.id"
          :item="item"
          :show-business-name="false"
        />
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
