<script setup>
import {
  formatCategoryLabel,
  formatPrice,
  formatProductColorLabel,
  formatProductTypeLabel,
} from "../lib/shop";

defineProps({
  item: {
    type: Object,
    required: true,
  },
  showBusinessName: {
    type: Boolean,
    default: true,
  },
});
</script>

<template>
  <article class="order-item-card">
    <div class="order-item-card__media">
      <img
        v-if="item.imagePath"
        :src="item.imagePath"
        :alt="item.title || 'Produkt'"
        width="320"
        height="320"
        loading="lazy"
        decoding="async"
      >
      <div v-else class="order-item-card__placeholder">
        {{ (item.title || "P").charAt(0).toUpperCase() }}
      </div>
    </div>

    <div class="order-item-card__body">
      <p>{{ formatCategoryLabel(item.category) }}</p>
      <h3>{{ item.title || "Produkt" }}</h3>
      <p v-if="item.description">{{ item.description }}</p>
      <p v-if="showBusinessName && item.businessName">
        Biznesi: <strong>{{ item.businessName }}</strong>
      </p>
      <div class="order-item-card__tags">
        <span v-if="item.productType">
          {{ formatProductTypeLabel(item.productType) }}
        </span>
        <span v-if="item.size">
          Madhesia: {{ item.size }}
        </span>
        <span v-if="item.color">
          Ngjyra: {{ formatProductColorLabel(item.color) }}
        </span>
      </div>
    </div>

    <div class="order-item-card__summary">
      <span>{{ formatPrice(item.unitPrice || 0) }}</span>
      <strong>Sasia: {{ Math.max(1, Number(item.quantity) || 1) }}</strong>
      <strong>{{ formatPrice(item.totalPrice || 0) }}</strong>
    </div>
  </article>
</template>
