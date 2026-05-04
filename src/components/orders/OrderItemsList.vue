<template>
  <section class="order-items-list" aria-label="Items in order">
    <article v-for="item in items" :key="item.id || item.productId || item.title" class="order-items-list__row">
      <img :src="item.imagePath || '/trego-logo.png'" :alt="item.title || 'Order item'" loading="lazy" />
      <div class="order-items-list__content">
        <div>
          <p>{{ item.title || "Marketplace product" }}</p>
          <span>{{ variantText(item) }}</span>
          <small>Sold by {{ item.businessName || "TREGIO seller" }}</small>
        </div>
        <div class="order-items-list__meta">
          <strong>{{ formatPrice(item.totalPrice || item.unitPrice || 0) }}</strong>
          <span>Qty {{ item.quantity || 1 }}</span>
        </div>
      </div>
      <div class="order-items-list__actions">
        <RouterLink
          v-if="item.productId"
          class="order-inline-button"
          :to="{ path: '/produkti', query: { id: item.productId } }"
        >
          View product
        </RouterLink>
        <button type="button" class="order-inline-button" @click="$emit('contact-seller', item)">
          Contact seller
        </button>
      </div>
    </article>
  </section>
</template>

<script setup>
import { RouterLink } from "vue-router";
import { formatPrice } from "../../lib/shop";

defineProps({
  items: {
    type: Array,
    default: () => [],
  },
});

defineEmits(["contact-seller"]);

function variantText(item) {
  const details = [item.variantLabel, item.color, item.size].filter(Boolean);
  return details.length ? details.join(" / ") : "Standard variant";
}
</script>
