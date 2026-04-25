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
   
   
  >
    <div>
      <SmartImageMobile :src="getProductImage(product)" :alt="product.title" />
      <button type="button" @click="emit('open', product.id)">
        <span>Hap produktin</span>
      </button>

      <span v-if="discount">Sale</span>

      <div v-if="!analyticsMode">
        <button
         
          type="button"
          @click.stop="emit('wishlist', product.id)"
        >
          <IonIcon :icon="heartOutline" />
        </button>

        <button
         
          type="button"
          @click.stop="emit('cart', product.id)"
        >
          <IonIcon :icon="bagAddOutline" />
        </button>
      </div>
    </div>

    <div>
      <p>{{ product.businessName || "TREGIO" }}</p>
      <button type="button" @click="emit('open', product.id)">
        {{ product.title }}
      </button>

      <div>
        <div>
          <strong>{{ formatPrice(product.price) }}</strong>
          <span v-if="hasCompareAtPrice">
            {{ formatPrice(product.compareAtPrice) }}
          </span>
        </div>
      </div>

      <div v-if="analyticsMode">
        <span
          v-for="item in engagementItems"
          :key="`${product.id}-${item.label}`"
         
        >
          <small>{{ item.label }}</small>
          <strong>{{ item.value }}</strong>
        </span>
      </div>

      <div v-else>
        <span>{{ buyersValue }} shitje</span>
        <span>
          <IonIcon :icon="star" />
          {{ ratingValue }}
        </span>
      </div>
    </div>
  </article>
</template>

