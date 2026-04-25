<script setup>
import { computed } from "vue";
import { useRoute } from "vue-router";
import { formatPrice, getProductDetailUrl } from "../lib/shop";

const props = defineProps({
  product: {
    type: Object,
    required: true,
  },
  isWishlisted: {
    type: Boolean,
    default: false,
  },
  isInCart: {
    type: Boolean,
    default: false,
  },
  wishlistBusy: {
    type: Boolean,
    default: false,
  },
  cartBusy: {
    type: Boolean,
    default: false,
  },
  isCompared: {
    type: Boolean,
    default: false,
  },
  showOverlayActions: {
    type: Boolean,
    default: true,
  },
  showBusinessName: {
    type: Boolean,
    default: true,
  },
  showDescription: {
    type: Boolean,
    default: false,
  },
  });

const emit = defineEmits(["wishlist", "cart", "compare"]);
const route = useRoute();

const detailUrl = computed(() => getProductDetailUrl(props.product.id, route.fullPath));
const businessName = computed(() => String(props.product.businessName || "").trim());
const wishlistLabel = computed(() => (props.isWishlisted ? "Hiqe nga wishlist" : "Shto ne wishlist"));
const cartLabel = computed(() => {
  if (props.isInCart) {
    return "Produkti eshte ne shporte";
  }

  if (props.product?.requiresVariantSelection) {
    return "Zgjidh variantin";
  }

  return "Shto ne shporte";
});
const compareLabel = computed(() => (props.isCompared ? "Hiqe nga krahasimi" : "Shto ne krahasim"));
const currentPrice = computed(() => Number(props.product.price || 0));
const compareAtPrice = computed(() => {
  const rawValue = Number(props.product.compareAtPrice ?? props.product.originalPrice ?? 0);
  if (!Number.isFinite(rawValue) || rawValue <= currentPrice.value) {
    return null;
  }

  return rawValue;
});
const discountPercent = computed(() => {
  if (!compareAtPrice.value || compareAtPrice.value <= 0) {
    return null;
  }

  return Math.max(0, Math.round(((compareAtPrice.value - currentPrice.value) / compareAtPrice.value) * 100));
});
const averageRating = computed(() => {
  const rawValue = Number(props.product.averageRating ?? props.product.ratingAverage ?? 0);
  if (!Number.isFinite(rawValue) || rawValue <= 0) {
    return 0;
  }

  return Math.max(0, Math.min(5, rawValue));
});
const buyersCount = computed(() => {
  const rawValue = Number(props.product.buyersCount ?? props.product.unitsSold ?? 0);
  if (!Number.isFinite(rawValue) || rawValue <= 0) {
    return 0;
  }

  return Math.max(0, Math.trunc(rawValue));
});
const filledStars = computed(() => {
  if (averageRating.value <= 0) {
    return 0;
  }

  return Math.max(0, Math.min(5, Math.round(averageRating.value)));
});
const ratingSummary = computed(() => {
  if (averageRating.value > 0) {
    return averageRating.value.toFixed(1);
  }

  return "0.0";
});
const ratingLabel = computed(() => {
  if (averageRating.value > 0) {
    return `${ratingSummary.value} vleresim`;
  }

  return "Pa vleresime";
});
const salesLabel = computed(() => `${buyersCount.value} shitje`);
const badgeLabel = computed(() => {
  if (!discountPercent.value) {
    return "";
  }

  return `-${discountPercent.value}%`;
});
</script>

<template>
  <article class="product-card" :aria-label="product.title">
    <RouterLink
      :to="detailUrl"
      class="product-card__media-link"
      :aria-label="`Hape produktin ${product.title}`"
    >
      <div class="product-card__media">
        <img
          class="product-card__image"
          :src="product.imagePath"
          :alt="product.title"
          width="720"
          height="720"
          loading="lazy"
          decoding="async"
        >
        <span v-if="badgeLabel" class="product-card__badge">{{ badgeLabel }}</span>
      </div>
    </RouterLink>

    <div v-if="showOverlayActions" class="product-card__actions">
      <button
        class="market-icon-button"
        type="button"
        :disabled="wishlistBusy"
        :aria-label="wishlistLabel"
        :aria-pressed="isWishlisted"
        @click.stop="emit('wishlist', product.id)"
      >
        <svg viewBox="0 0 24 24" aria-hidden="true">
          <path d="M12 20.4 4.9 13.8a4.8 4.8 0 0 1 6.8-6.8l.3.3.3-.3a4.8 4.8 0 1 1 6.8 6.8Z"></path>
        </svg>
      </button>

      <button
        class="market-icon-button"
        type="button"
        :aria-label="compareLabel"
        :aria-pressed="isCompared"
        @click.stop="emit('compare', product)"
      >
        <svg viewBox="0 0 24 24" aria-hidden="true">
          <path d="M7 7h10M7 17h10M6 12h12"></path>
        </svg>
      </button>

      <button
        class="market-icon-button"
        type="button"
        :disabled="cartBusy"
        :aria-label="cartLabel"
        :aria-pressed="isInCart"
        @click.stop="emit('cart', product.id)"
      >
        <svg viewBox="0 0 24 24" aria-hidden="true">
          <path d="M3 5h2l2.1 9.1a1 1 0 0 0 1 .8h8.8a1 1 0 0 0 1-.8L20 8H7.2"></path>
          <circle cx="10" cy="19" r="1.4"></circle>
          <circle cx="18" cy="19" r="1.4"></circle>
        </svg>
      </button>
    </div>

    <div class="product-card__body">
      <div class="product-card__meta">
        <p v-if="showBusinessName && businessName" class="product-card__brand">
          {{ businessName }}
        </p>
        <span v-if="buyersCount > 0">
          {{ salesLabel }}
        </span>
      </div>

      <h3 class="product-card__title">
        <RouterLink :to="detailUrl">
          {{ product.title }}
        </RouterLink>
      </h3>

      <p v-if="showDescription && product.description" class="product-card__description">
        {{ product.description }}
      </p>

      <div class="product-card__price">
        <strong>{{ formatPrice(currentPrice) }}</strong>
        <div>
          <span v-if="compareAtPrice" class="product-card__price-compare">{{ formatPrice(compareAtPrice) }}</span>
          <span v-else aria-hidden="true"></span>
        </div>
      </div>

      <div class="product-card__footer">
        <div class="product-card__rating">
          <div class="product-card__stars" :aria-label="`Vleresimi ${ratingSummary}`">
            <svg
              v-for="index in 5"
              :key="index"
              viewBox="0 0 24 24"
              aria-hidden="true"
            >
              <path d="M12 3.8 14.6 9l5.7.8-4.1 4 1 5.7-5.2-2.7-5.2 2.7 1-5.7-4.1-4 5.7-.8Z"></path>
            </svg>
          </div>
          <span>{{ ratingLabel }}</span>
        </div>
        <span class="product-card__footer-code">{{ product.sku || "Ready to ship" }}</span>
      </div>
    </div>
  </article>
</template>
