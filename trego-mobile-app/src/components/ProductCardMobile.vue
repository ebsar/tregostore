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
    :class="['trego-product-card', { 'trego-product-card--compact': compact, 'trego-product-card--analytics': analyticsMode }]"
  >
    <div class="trego-product-card__media">
      <SmartImageMobile :src="getProductImage(product)" :alt="product.title" />
      <button class="trego-product-card__open" type="button" @click="emit('open', product.id)">
        <span class="trego-sr-only">Hap produktin</span>
      </button>

      <span v-if="discount" class="trego-product-card__badge">Sale</span>

      <div v-if="!analyticsMode" class="trego-product-card__actions">
        <button
          class="trego-product-card__icon"
          type="button"
          @click.stop="emit('wishlist', product.id)"
        >
          <IonIcon :icon="heartOutline" />
        </button>

        <button
          class="trego-product-card__icon"
          type="button"
          @click.stop="emit('cart', product.id)"
        >
          <IonIcon :icon="bagAddOutline" />
        </button>
      </div>
    </div>

    <div class="trego-product-card__body">
      <p class="trego-product-card__business">{{ product.businessName || "TREGIO" }}</p>
      <button class="trego-product-card__title" type="button" @click="emit('open', product.id)">
        {{ product.title }}
      </button>

      <div class="trego-product-card__price-row">
        <div class="trego-product-card__price">
          <strong>{{ formatPrice(product.price) }}</strong>
          <span v-if="hasCompareAtPrice">
            {{ formatPrice(product.compareAtPrice) }}
          </span>
        </div>
      </div>

      <div v-if="analyticsMode" class="trego-product-card__analytics">
        <span
          v-for="item in engagementItems"
          :key="`${product.id}-${item.label}`"
          class="trego-product-card__metric"
        >
          <small>{{ item.label }}</small>
          <strong>{{ item.value }}</strong>
        </span>
      </div>

      <div v-else class="trego-product-card__meta">
        <span>{{ buyersValue }} shitje</span>
        <span class="trego-product-card__rating">
          <IonIcon :icon="star" />
          {{ ratingValue }}
        </span>
      </div>
    </div>
  </article>
</template>
