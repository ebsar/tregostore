<template>
  <article class="order-card" :class="{ 'order-card--selected': selected }">
    <button type="button" class="order-card__click-area" @click="$emit('select', order)">
      <span class="sr-only">Open order {{ order.id }}</span>
    </button>

    <header class="order-card__header">
      <div class="order-card__thumbs" aria-hidden="true">
        <img v-for="item in thumbnails" :key="item.id || item.productId || item.title" :src="item.imagePath || '/trego-logo.png'" alt="" loading="lazy" />
        <span v-if="remainingCount > 0">+{{ remainingCount }}</span>
      </div>
      <div class="order-card__identity">
        <span>Order #{{ order.id }}</span>
        <strong>{{ primarySeller }}</strong>
        <small>{{ formatDateLabel(order.createdAt) || "Recently" }} · {{ order.totalItems || itemCount }} item{{ itemCount === 1 ? "" : "s" }}</small>
      </div>
      <button type="button" class="order-card__menu-button" aria-label="Open order actions" @click.stop="$emit('toggle-menu', order)">
        <svg aria-hidden="true" viewBox="0 0 24 24">
          <path d="M12 8.2a1.8 1.8 0 1 0 0-3.6 1.8 1.8 0 0 0 0 3.6Zm0 5.6a1.8 1.8 0 1 0 0-3.6 1.8 1.8 0 0 0 0 3.6Zm0 5.6a1.8 1.8 0 1 0 0-3.6 1.8 1.8 0 0 0 0 3.6Z" fill="currentColor" />
        </svg>
      </button>
      <div v-if="menuOpen" class="order-card__menu" @click.stop>
        <button type="button" @click="$emit('menu-action', { action: 'download-invoice', order })">Download invoice</button>
        <button type="button" @click="$emit('menu-action', { action: 'request-return', order })">Return/refund</button>
        <button type="button" @click="$emit('menu-action', { action: 'contact-support', order })">Contact support</button>
      </div>
    </header>

    <section class="order-card__body">
      <OrderStatusBadge :order="order" />
      <div>
        <span>Total price</span>
        <strong>{{ formatPrice(order.totalPrice || 0) }}</strong>
      </div>
      <div>
        <span>{{ delivered ? "Delivered" : "Delivery estimate" }}</span>
        <strong>{{ deliveryText }}</strong>
      </div>
    </section>

    <footer class="order-card__footer">
      <button type="button" class="order-card__view-button" @click="$emit('view', order)">
        View order
      </button>
    </footer>
  </article>
</template>

<script setup>
import { computed } from "vue";
import { formatDateLabel, formatEstimatedDeliveryLabel, formatPrice } from "../../lib/shop";
import OrderStatusBadge from "./OrderStatusBadge.vue";

const props = defineProps({
  menuOpen: {
    type: Boolean,
    default: false,
  },
  order: {
    type: Object,
    required: true,
  },
  selected: {
    type: Boolean,
    default: false,
  },
});

defineEmits(["menu-action", "select", "toggle-menu", "view"]);

const items = computed(() => props.order?.items || []);
const thumbnails = computed(() => items.value.slice(0, 3));
const remainingCount = computed(() => Math.max(0, items.value.length - thumbnails.value.length));
const itemCount = computed(() => items.value.reduce((total, item) => total + Number(item.quantity || 1), 0));
const primarySeller = computed(() => items.value.find((item) => item.businessName)?.businessName || "Marketplace seller");
const delivered = computed(() => {
  const statuses = [props.order?.status, props.order?.fulfillmentStatus, ...items.value.map((item) => item.fulfillmentStatus)]
    .map((status) => String(status || "").toLowerCase());
  return statuses.includes("delivered");
});

const deliveryText = computed(() => {
  if (delivered.value) {
    const deliveredAt = items.value.find((item) => item.deliveredAt)?.deliveredAt;
    return formatDateLabel(deliveredAt) || "Delivered";
  }

  return props.order?.estimatedDeliveryText
    || formatEstimatedDeliveryLabel(props.order?.deliveryMethod, props.order?.estimatedDeliveryText)
    || "2-4 business days";
});
</script>
