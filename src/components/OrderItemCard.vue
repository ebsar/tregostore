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
    <div class="order-item-image-shell">
      <img
        v-if="item.imagePath"
        class="order-item-image"
        :src="item.imagePath"
        :alt="item.title || 'Produkt'"
        loading="lazy"
        decoding="async"
      >
      <div v-else class="order-item-image-fallback">
        {{ (item.title || "P").charAt(0).toUpperCase() }}
      </div>
    </div>

    <div class="order-item-copy">
      <p class="order-item-label">{{ formatCategoryLabel(item.category) }}</p>
      <h3>{{ item.title || "Produkt" }}</h3>
      <p v-if="item.description" class="order-item-description">{{ item.description }}</p>
      <p v-if="showBusinessName && item.businessName" class="order-item-business">
        Biznesi: <strong>{{ item.businessName }}</strong>
      </p>
      <div class="product-detail-tags product-detail-tags-saved">
        <span v-if="item.productType" class="product-detail-tag">
          {{ formatProductTypeLabel(item.productType) }}
        </span>
        <span v-if="item.size" class="product-detail-tag">
          Madhesia: {{ item.size }}
        </span>
        <span v-if="item.color" class="product-detail-tag">
          Ngjyra: {{ formatProductColorLabel(item.color) }}
        </span>
      </div>
    </div>

    <div class="order-item-pricing">
      <span>{{ formatPrice(item.unitPrice || 0) }}</span>
      <strong>Sasia: {{ Math.max(1, Number(item.quantity) || 1) }}</strong>
      <strong>{{ formatPrice(item.totalPrice || 0) }}</strong>
    </div>
  </article>
</template>
