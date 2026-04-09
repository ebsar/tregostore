<script setup lang="ts">
import { IonIcon } from "@ionic/vue";
import { bagAddOutline, heartOutline, star } from "ionicons/icons";
import { computed } from "vue";
import type { ProductItem } from "../types/models";
import { formatCount, formatPrice, getDiscountPercent, getProductImage } from "../lib/format";
import SmartImageMobile from "./SmartImageMobile.vue";

const props = withDefaults(defineProps<{
  product: ProductItem;
  analyticsMode?: boolean;
  compact?: boolean;
}>(), {
  analyticsMode: false,
  compact: false,
});

const emit = defineEmits<{
  (event: "open", productId: number): void;
  (event: "wishlist", productId: number): void;
  (event: "cart", productId: number): void;
}>();

const discount = computed(() => getDiscountPercent(props.product));
const hasCompareAtPrice = computed(() => Number(props.product.compareAtPrice || 0) > Number(props.product.price || 0));
const engagementItems = computed(() => ([
  { label: "Views", value: formatCount(props.product.viewsCount || 0) },
  { label: "Wishlist", value: formatCount(props.product.wishlistCount || 0) },
  { label: "Cart", value: formatCount(props.product.cartCount || 0) },
  { label: "Share", value: formatCount(props.product.shareCount || 0) },
]));
const ratingValue = computed(() => Number(props.product.averageRating || 0).toFixed(1));
const buyersValue = computed(() => formatCount(props.product.buyersCount || 0));
</script>

<template>
  <article
    class="product-card-mobile surface-card"
    :class="{
      'is-compact': compact,
      'is-analytics': analyticsMode,
    }"
  >
    <div class="product-card-mobile-media">
      <SmartImageMobile :src="getProductImage(product)" :alt="product.title" />
      <button class="product-card-mobile-open-hit" type="button" @click="emit('open', product.id)">
        <span class="sr-only">Hap produktin</span>
      </button>

      <span v-if="discount" class="product-card-mobile-badge">Sale</span>

      <div v-if="!analyticsMode" class="product-card-mobile-media-actions">
        <button
          class="product-card-mobile-action product-card-mobile-action--wish"
          type="button"
          @click.stop="emit('wishlist', product.id)"
        >
          <IonIcon :icon="heartOutline" />
        </button>

        <button
          class="product-card-mobile-action product-card-mobile-action--cart"
          type="button"
          @click.stop="emit('cart', product.id)"
        >
          <IonIcon :icon="bagAddOutline" />
        </button>
      </div>
    </div>

    <div class="product-card-mobile-copy">
      <p class="product-card-mobile-business">{{ product.businessName || "TREGIO" }}</p>
      <button class="product-card-mobile-title" type="button" @click="emit('open', product.id)">
        {{ product.title }}
      </button>

      <div class="product-card-mobile-price-row">
        <div class="product-card-mobile-pricing">
          <strong>{{ formatPrice(product.price) }}</strong>
          <span v-if="hasCompareAtPrice" class="product-card-mobile-compare">
            {{ formatPrice(product.compareAtPrice) }}
          </span>
        </div>
      </div>

      <div v-if="analyticsMode" class="product-card-mobile-engagement">
        <span
          v-for="item in engagementItems"
          :key="`${product.id}-${item.label}`"
          class="product-card-mobile-engagement-item"
        >
          <small>{{ item.label }}</small>
          <strong>{{ item.value }}</strong>
        </span>
      </div>

      <div v-else class="product-card-mobile-stats">
        <span>{{ buyersValue }} shitje</span>
        <span class="product-card-mobile-rating">
          <IonIcon :icon="star" />
          {{ ratingValue }}
        </span>
      </div>
    </div>
  </article>
</template>

<style scoped>
.product-card-mobile {
  position: relative;
  overflow: hidden;
  display: grid;
  grid-template-rows: auto 1fr;
  gap: 8px;
  min-height: 286px;
  padding: 9px;
  border-radius: 24px;
  background:
    linear-gradient(180deg, rgba(255, 255, 255, 0.95), rgba(255, 255, 255, 0.82)),
    radial-gradient(circle at top left, rgba(255, 255, 255, 0.5), transparent 30%),
    radial-gradient(circle at bottom right, rgba(37, 99, 235, 0.1), transparent 34%),
    radial-gradient(circle at top right, rgba(22, 163, 74, 0.08), transparent 30%);
  box-shadow:
    0 14px 28px rgba(31, 41, 55, 0.08),
    inset 0 1px 0 rgba(255, 255, 255, 0.84);
}

.product-card-mobile.is-compact {
  min-height: 252px;
}

.product-card-mobile.is-analytics {
  min-height: 338px;
}

.product-card-mobile::before {
  content: "";
  position: absolute;
  inset: 0;
  border-radius: inherit;
  background:
    linear-gradient(180deg, rgba(255, 255, 255, 0.12), transparent 40%),
    radial-gradient(circle at top right, rgba(255, 255, 255, 0.46), transparent 24%);
  pointer-events: none;
}

.product-card-mobile > * {
  position: relative;
  z-index: 1;
}

.product-card-mobile-media {
  position: relative;
  overflow: hidden;
  aspect-ratio: 0.96;
  border-radius: 18px;
  background: var(--trego-interactive-bg-strong);
  box-shadow:
    inset 0 1px 0 rgba(255, 255, 255, 0.42),
    0 12px 22px rgba(31, 41, 55, 0.1);
}

.product-card-mobile-media::after {
  content: "";
  position: absolute;
  inset: 0;
  background:
    linear-gradient(180deg, rgba(7, 11, 20, 0.02), rgba(7, 11, 20, 0.18)),
    radial-gradient(circle at top left, rgba(255, 255, 255, 0.32), transparent 28%);
  pointer-events: none;
}

.product-card-mobile-media img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
}

.product-card-mobile-open-hit {
  position: absolute;
  inset: 0;
  border: 0;
  background: transparent;
}

.product-card-mobile-badge {
  position: absolute;
  top: 9px;
  left: 9px;
  display: inline-flex;
  min-height: 23px;
  align-items: center;
  padding: 0 9px;
  border-radius: 999px;
  background: linear-gradient(135deg, rgba(255, 96, 96, 0.96), rgba(227, 54, 54, 0.92));
  color: #fff7f7;
  font-size: 0.68rem;
  font-weight: 800;
  letter-spacing: 0.03em;
  box-shadow: 0 12px 20px rgba(196, 44, 44, 0.22);
}

.product-card-mobile-media-actions {
  position: absolute;
  right: 9px;
  bottom: 9px;
  left: 9px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
}

.product-card-mobile-action {
  display: inline-flex;
  width: 34px;
  height: 34px;
  align-items: center;
  justify-content: center;
  border: 1px solid rgba(255, 255, 255, 0.6);
  border-radius: 999px;
  background:
    linear-gradient(180deg, rgba(255, 255, 255, 0.28), rgba(255, 255, 255, 0.12));
  color: #ffffff;
  box-shadow:
    inset 0 1px 0 rgba(255, 255, 255, 0.48),
    0 8px 16px rgba(17, 24, 39, 0.14);
}

.product-card-mobile-action ion-icon {
  font-size: 1rem;
}

.product-card-mobile-copy {
  display: flex;
  flex-direction: column;
  gap: 6px;
  min-height: 0;
}

.product-card-mobile-business {
  margin: 0;
  color: rgba(37, 99, 235, 0.86);
  font-size: 0.66rem;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.product-card-mobile-title {
  border: 0;
  padding: 0;
  background: transparent;
  color: var(--trego-dark);
  font-size: 0.9rem;
  font-weight: 800;
  line-height: 1.16;
  text-align: left;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
  min-height: 2.3em;
}

.product-card-mobile.is-compact .product-card-mobile-title {
  font-size: 0.84rem;
  min-height: 2em;
}

.product-card-mobile-price-row {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 8px;
  margin-top: auto;
}

.product-card-mobile-pricing {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.product-card-mobile-pricing strong {
  color: #1d4ed8;
  font-size: 0.96rem;
  line-height: 1;
}

.product-card-mobile.is-compact .product-card-mobile-pricing strong {
  font-size: 0.9rem;
}

.product-card-mobile-compare {
  color: var(--trego-muted);
  font-size: 0.72rem;
  text-decoration: line-through;
}

.product-card-mobile-stats {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  color: var(--trego-muted);
  font-size: 0.7rem;
  font-weight: 700;
}

.product-card-mobile-rating {
  display: inline-flex;
  align-items: center;
  gap: 5px;
}

.product-card-mobile-rating ion-icon {
  color: #f4b41a;
  font-size: 0.85rem;
}

.product-card-mobile-engagement {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 8px;
  margin-top: auto;
}

.product-card-mobile-engagement-item {
  display: grid;
  gap: 3px;
  padding: 8px 10px;
  border-radius: 16px;
  border: 1px solid var(--trego-input-border);
  background: rgba(255, 255, 255, 0.7);
}

.product-card-mobile-engagement-item small {
  color: var(--trego-muted);
  font-size: 0.68rem;
  font-weight: 700;
  letter-spacing: 0.04em;
  text-transform: uppercase;
}

.product-card-mobile-engagement-item strong {
  color: var(--trego-dark);
  font-size: 0.92rem;
  line-height: 1;
}
</style>
