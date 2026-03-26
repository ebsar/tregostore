<script setup>
import OrderItemCard from "./OrderItemCard.vue";
import { formatDateLabel, formatOrderStatusLabel, formatPaymentMethodLabel, formatPrice } from "../lib/shop";

defineProps({
  order: {
    type: Object,
    required: true,
  },
});
</script>

<template>
  <article class="card order-card">
    <div class="order-card-top">
      <div>
        <p class="section-label">Porosia #{{ order.id || "-" }}</p>
        <h2>{{ formatOrderStatusLabel(order.status) }}</h2>
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
        <span>Shuma totale</span>
        <strong>{{ formatPrice(order.totalPrice || 0) }}</strong>
      </div>
    </div>

    <div class="order-card-body">
      <div class="order-items-list">
        <OrderItemCard
          v-for="item in order.items || []"
          :key="item.id"
          :item="item"
        />
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
        </div>
      </aside>
    </div>
  </article>
</template>
