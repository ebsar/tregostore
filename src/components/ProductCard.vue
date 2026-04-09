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
  <article class="marketplace-card marketplace-card--catalog" :aria-label="product.title">
    <RouterLink class="marketplace-card-media" :to="detailUrl" :aria-label="`Hape produktin ${product.title}`">
      <img
        class="marketplace-card-image"
        :src="product.imagePath"
        :alt="product.title"
        width="720"
        height="720"
        loading="lazy"
        decoding="async"
      >
      <span v-if="badgeLabel" class="marketplace-card-badge">{{ badgeLabel }}</span>

      <template v-if="showOverlayActions">
        <button
          class="product-card-overlay-button product-card-wishlist-button wishlist-action"
          :class="{ active: isWishlisted }"
          type="button"
          :disabled="wishlistBusy"
          :aria-label="wishlistLabel"
          :aria-pressed="isWishlisted"
          @click.stop="emit('wishlist', product.id)"
        >
          <svg class="nav-icon" viewBox="0 0 24 24" aria-hidden="true">
            <path d="M12 20.4 4.9 13.8a4.8 4.8 0 0 1 6.8-6.8l.3.3.3-.3a4.8 4.8 0 1 1 6.8 6.8Z"></path>
          </svg>
        </button>

        <button
          class="product-card-overlay-button product-card-cart-button cart-action"
          :class="{ active: isInCart }"
          type="button"
          :disabled="cartBusy"
          :aria-label="cartLabel"
          :aria-pressed="isInCart"
          @click.stop="emit('cart', product.id)"
        >
          <svg class="nav-icon" viewBox="0 0 24 24" aria-hidden="true">
            <path d="M3 5h2l2.1 9.1a1 1 0 0 0 1 .8h8.8a1 1 0 0 0 1-.8L20 8H7.2"></path>
            <circle cx="10" cy="19" r="1.4"></circle>
            <circle cx="18" cy="19" r="1.4"></circle>
          </svg>
        </button>
      </template>
    </RouterLink>

    <div class="marketplace-card-body">
      <h3 class="marketplace-card-title">
        <RouterLink class="marketplace-card-title-link" :to="detailUrl">
          {{ product.title }}
        </RouterLink>
      </h3>

      <p v-if="showBusinessName && businessName" class="marketplace-card-business-name">
        {{ businessName }}
      </p>

      <div class="marketplace-card-pricing">
        <strong class="marketplace-card-price-current">{{ formatPrice(currentPrice) }}</strong>
        <div class="marketplace-card-price-copy">
          <span v-if="compareAtPrice" class="marketplace-card-price-old">{{ formatPrice(compareAtPrice) }}</span>
          <span v-else class="marketplace-card-price-old marketplace-card-price-old--empty" aria-hidden="true"></span>
        </div>
      </div>

      <div class="marketplace-card-rating">
        <div class="marketplace-card-rating-main">
          <div class="marketplace-card-stars" :aria-label="`Vleresimi ${ratingSummary}`">
            <svg
              v-for="index in 5"
              :key="index"
              class="marketplace-card-star"
              :class="{ 'is-filled': index <= filledStars }"
              viewBox="0 0 24 24"
              aria-hidden="true"
            >
              <path d="M12 3.8 14.6 9l5.7.8-4.1 4 1 5.7-5.2-2.7-5.2 2.7 1-5.7-4.1-4 5.7-.8Z"></path>
            </svg>
          </div>
          <span class="marketplace-card-rating-summary">{{ ratingLabel }}</span>
        </div>
        <span class="marketplace-card-buyers-count">{{ salesLabel }}</span>
      </div>
    </div>
  </article>
</template>

<style scoped>
.marketplace-card {
  position: relative;
  display: grid;
  grid-template-rows: auto 1fr;
  gap: 10px;
  height: 100%;
  width: 100%;
  max-width: 228px;
  min-width: 0;
  min-height: 392px;
  padding: 10px;
  border-radius: 22px;
  background:
    linear-gradient(180deg, rgba(255, 255, 255, 0.9), rgba(255, 255, 255, 0.74)),
    radial-gradient(circle at top left, rgba(255, 255, 255, 0.52), transparent 28%),
    radial-gradient(circle at bottom right, rgba(37, 99, 235, 0.08), transparent 34%);
  border: 1px solid rgba(255, 255, 255, 0.56);
  box-shadow:
    0 12px 24px rgba(31, 41, 55, 0.08),
    inset 0 1px 0 rgba(255, 255, 255, 0.84);
  justify-self: center;
  overflow: hidden;
}

.marketplace-card--catalog {
  position: relative;
}

.marketplace-card-media {
  position: relative;
  display: block;
  width: 100%;
  overflow: hidden;
  border-radius: 16px;
  aspect-ratio: 4 / 5;
  background: linear-gradient(180deg, rgba(255, 255, 255, 0.92), rgba(241, 245, 249, 0.94));
  box-shadow: 0 10px 18px rgba(31, 41, 55, 0.08);
}

.marketplace-card-image {
  display: block;
  width: 100%;
  height: 100%;
  max-width: none;
  object-fit: cover;
  object-position: center;
}

.marketplace-card-badge {
  position: absolute;
  top: 12px;
  left: 12px;
  display: inline-flex;
  align-items: center;
  min-height: 28px;
  padding: 0 11px;
  border-radius: 999px;
  font-size: 0.68rem;
  font-weight: 800;
  letter-spacing: 0.03em;
  color: #fff;
  background: linear-gradient(180deg, rgba(220, 38, 38, 0.96), rgba(185, 28, 28, 0.92));
  border: 1px solid rgba(220, 38, 38, 0.22);
  box-shadow: 0 12px 24px rgba(220, 38, 38, 0.16);
}

.product-card-overlay-button {
  position: absolute;
  bottom: 10px;
  display: inline-flex;
  width: 38px;
  height: 38px;
  align-items: center;
  justify-content: center;
  border-radius: 999px;
  border: 1px solid rgba(255, 255, 255, 0.58);
  background:
    linear-gradient(180deg, rgba(255, 255, 255, 0.32), rgba(255, 255, 255, 0.14));
  color: #ffffff;
  box-shadow:
    inset 0 1px 0 rgba(255, 255, 255, 0.48),
    0 8px 16px rgba(17, 24, 39, 0.11);
}

.product-card-overlay-button .nav-icon {
  width: 18px;
  height: 18px;
  stroke-width: 1.8;
}

.product-card-wishlist-button {
  left: 10px;
}

.product-card-cart-button {
  right: 10px;
}

.marketplace-card-body {
  display: grid;
  align-content: start;
  gap: 6px;
  min-width: 0;
}

.marketplace-card-title {
  margin: 0;
  font-size: 0.96rem;
  line-height: 1.22;
  letter-spacing: -0.02em;
  min-width: 0;
}

.marketplace-card-title-link {
  color: var(--text);
  text-decoration: none;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.marketplace-card-business-name {
  margin: 0;
  color: var(--muted);
  font-size: 0.75rem;
  line-height: 1.3;
  font-weight: 700;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.marketplace-card-pricing {
  display: grid;
  gap: 2px;
  min-width: 0;
}

.marketplace-card-price-current {
  color: var(--accent);
  font-size: 1.08rem;
  font-weight: 800;
  letter-spacing: -0.03em;
  line-height: 1.08;
}

.marketplace-card-price-copy {
  display: flex;
  align-items: center;
  justify-content: flex-start;
  gap: 6px;
  min-height: 18px;
}

.marketplace-card-price-old--empty {
  visibility: hidden;
}

.marketplace-card-price-old {
  color: var(--muted);
  font-size: 0.72rem;
  font-weight: 700;
  text-decoration: line-through;
}

.marketplace-card-rating {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  color: var(--muted);
  font-size: 0.72rem;
  border-top: 1px solid rgba(148, 163, 184, 0.14);
  padding-top: 7px;
  min-width: 0;
}

.marketplace-card-rating-main {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  min-width: 0;
}

.marketplace-card-stars {
  display: flex;
  align-items: center;
  gap: 2px;
  flex-shrink: 0;
}

.marketplace-card-star {
  width: 14px;
  height: 14px;
  fill: none;
  stroke: rgba(143, 133, 124, 0.42);
  stroke-width: 1.8;
}

.marketplace-card-star.is-filled {
  fill: #d8aa58;
  stroke: #d8aa58;
}

.marketplace-card-rating-summary {
  color: var(--text);
  font-size: 0.74rem;
  font-weight: 700;
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.marketplace-card-buyers-count {
  color: var(--muted);
  font-size: 0.72rem;
  font-weight: 700;
  white-space: nowrap;
}

@media (max-width: 820px) {
  .marketplace-card {
    max-width: none;
    padding: 8px;
    border-radius: 19px;
    width: 100%;
    min-height: 326px;
    justify-self: stretch;
    gap: 8px;
  }

  .marketplace-card-media {
    border-radius: 14px;
    aspect-ratio: 1 / 1.18;
  }

  .marketplace-card-badge {
    top: 8px;
    left: 8px;
    min-height: 22px;
    padding: 0 8px;
    font-size: 0.58rem;
  }

  .marketplace-card-title {
    font-size: 0.84rem;
    line-height: 1.18;
  }

  .marketplace-card-business-name {
    font-size: 0.68rem;
  }

  .marketplace-card-price-current {
    font-size: 0.94rem;
  }

  .marketplace-card-price-old {
    font-size: 0.64rem;
  }

  .marketplace-card-rating {
    display: grid;
    justify-content: stretch;
    gap: 4px;
    padding-top: 6px;
  }

  .marketplace-card-rating-main {
    gap: 5px;
  }

  .marketplace-card-star {
    width: 12px;
    height: 12px;
  }

  .marketplace-card-rating-summary,
  .marketplace-card-buyers-count {
    font-size: 0.65rem;
  }

  .product-card-overlay-button {
    width: 34px;
    height: 34px;
    bottom: 8px;
  }

  .product-card-overlay-button .nav-icon {
    width: 16px;
    height: 16px;
  }

  .product-card-wishlist-button {
    left: 8px;
  }

  .product-card-cart-button {
    right: 8px;
  }
}

@media (max-width: 480px) {
  .marketplace-card {
    min-height: 302px;
    padding: 7px;
    border-radius: 17px;
    gap: 7px;
  }

  .marketplace-card-media {
    border-radius: 12px;
    aspect-ratio: 1 / 1.12;
  }

  .marketplace-card-body {
    gap: 4px;
  }

  .marketplace-card-title {
    font-size: 0.8rem;
  }

  .marketplace-card-business-name {
    font-size: 0.64rem;
  }

  .marketplace-card-price-current {
    font-size: 0.88rem;
  }

  .marketplace-card-price-copy {
    min-height: 14px;
    gap: 4px;
  }

  .marketplace-card-price-old {
    font-size: 0.6rem;
  }

  .marketplace-card-rating {
    gap: 3px;
    padding-top: 5px;
  }

  .marketplace-card-star {
    width: 11px;
    height: 11px;
  }

  .marketplace-card-rating-summary,
  .marketplace-card-buyers-count {
    font-size: 0.62rem;
  }

  .product-card-overlay-button {
    width: 32px;
    height: 32px;
    bottom: 7px;
  }

  .product-card-overlay-button .nav-icon {
    width: 15px;
    height: 15px;
  }

  .product-card-wishlist-button {
    left: 7px;
  }

  .product-card-cart-button {
    right: 7px;
  }
}
</style>
