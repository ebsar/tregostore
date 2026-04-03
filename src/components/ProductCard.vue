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
const reviewCount = computed(() => {
  const rawValue = Number(props.product.reviewCount ?? 0);
  if (!Number.isFinite(rawValue) || rawValue <= 0) {
    return 0;
  }

  return Math.max(0, Math.trunc(rawValue));
});
const buyersCount = computed(() => {
  const rawValue = Number(props.product.buyersCount ?? 0);
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
  if (reviewCount.value > 0 && averageRating.value > 0) {
    return averageRating.value.toFixed(1);
  }

  return "Pa vleresime";
});
const shortDescription = computed(() => {
  const rawValue = String(props.product?.description || "").trim();
  if (rawValue) {
    return rawValue;
  }

  return businessName.value ? `Nga ${businessName.value}` : "Produkt i perzgjedhur ne marketplace.";
});
</script>

<template>
  <article class="pet-product-card" :aria-label="product.title">
    <div class="pet-product-media">
      <RouterLink class="pet-product-link" :to="detailUrl" :aria-label="`Hape produktin ${product.title}`">
        <div class="pet-product-image-wrap">
          <img
            class="pet-product-image"
            :src="product.imagePath"
            :alt="product.title"
            width="640"
            height="640"
            loading="lazy"
            decoding="async"
          >
        </div>
      </RouterLink>

      <template v-if="showOverlayActions">
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

        <button
          class="product-card-overlay-button product-card-compare-button compare-action"
          :class="{ active: isCompared }"
          type="button"
          :aria-label="compareLabel"
          :aria-pressed="isCompared"
          @click.stop="emit('compare', product)"
        >
          <svg class="nav-icon" viewBox="0 0 24 24" aria-hidden="true">
            <rect x="4.5" y="5.5" width="6.5" height="13" rx="1.8"></rect>
            <rect x="13" y="7.5" width="6.5" height="11" rx="1.8"></rect>
          </svg>
        </button>

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
      </template>
    </div>

    <div class="pet-product-content-shell">
      <div class="pet-product-content">
        <h3 class="pet-product-title">
          <RouterLink class="pet-product-title-link" :to="detailUrl">
            {{ product.title }}
          </RouterLink>
        </h3>

        <p v-if="showBusinessName && businessName" class="pet-product-business-name">
          {{ businessName }}
        </p>

        <p v-if="showDescription" class="pet-product-description">
          {{ shortDescription }}
        </p>

        <div class="pet-product-price-row">
          <strong class="pet-product-price">{{ formatPrice(currentPrice) }}</strong>
          <div class="pet-product-price-meta">
            <template v-if="compareAtPrice">
              <span class="pet-product-price-compare">{{ formatPrice(compareAtPrice) }}</span>
              <span v-if="discountPercent !== null" class="pet-product-discount-chip">-{{ discountPercent }}%</span>
            </template>
            <span v-else class="pet-product-discount-empty">Pa zbritje</span>
          </div>
        </div>

        <div class="pet-product-rating-row">
          <div class="pet-product-rating-stars" :aria-label="`Vleresimi ${ratingSummary}`">
            <svg
              v-for="index in 5"
              :key="index"
              class="pet-product-rating-star"
              :class="{ 'is-filled': index <= filledStars }"
              viewBox="0 0 24 24"
              aria-hidden="true"
            >
              <path d="M12 3.8 14.6 9l5.7.8-4.1 4 1 5.7-5.2-2.7-5.2 2.7 1-5.7-4.1-4 5.7-.8Z"></path>
            </svg>
          </div>
          <span class="pet-product-rating-summary">{{ ratingSummary }}</span>
          <span class="pet-product-rating-divider" aria-hidden="true"></span>
          <span class="pet-product-buyers-count">{{ buyersCount }} blerje</span>
        </div>
      </div>
    </div>
  </article>
</template>

<style scoped>
.pet-product-card {
  position: relative;
  overflow: hidden;
  display: grid;
  gap: 14px;
  height: 100%;
  padding: 14px;
  border-radius: 30px;
  background:
    linear-gradient(180deg, rgba(255, 255, 255, 0.9), rgba(255, 255, 255, 0.74)),
    radial-gradient(circle at top left, rgba(255, 255, 255, 0.52), transparent 28%),
    radial-gradient(circle at bottom right, rgba(255, 106, 43, 0.08), transparent 34%);
  border: 1px solid rgba(255, 255, 255, 0.56);
  box-shadow:
    0 22px 42px rgba(31, 41, 55, 0.1),
    inset 0 1px 0 rgba(255, 255, 255, 0.84);
  backdrop-filter: blur(20px) saturate(145%);
  -webkit-backdrop-filter: blur(20px) saturate(145%);
}

.pet-product-media {
  position: relative;
}

.pet-product-image-wrap {
  overflow: hidden;
  border-radius: 24px;
  aspect-ratio: 1 / 1;
  background: linear-gradient(180deg, rgba(255, 255, 255, 0.88), rgba(246, 243, 240, 0.94));
}

.pet-product-image {
  display: block;
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.product-card-overlay-button {
  display: inline-flex;
  width: 40px;
  height: 40px;
  align-items: center;
  justify-content: center;
  border-radius: 999px;
  border: 1px solid rgba(255, 255, 255, 0.58);
  background:
    linear-gradient(180deg, rgba(255, 255, 255, 0.32), rgba(255, 255, 255, 0.14));
  color: #ffffff;
  box-shadow:
    inset 0 1px 0 rgba(255, 255, 255, 0.48),
    0 12px 24px rgba(17, 24, 39, 0.16);
  backdrop-filter: blur(16px) saturate(150%);
  -webkit-backdrop-filter: blur(16px) saturate(150%);
}

.product-card-overlay-button .nav-icon {
  width: 18px;
  height: 18px;
  stroke-width: 1.8;
}

.pet-product-content-shell {
  display: grid;
}

.pet-product-content {
  display: grid;
  gap: 8px;
}

.pet-product-title {
  margin: 0;
  font-size: 1.02rem;
  line-height: 1.22;
}

.pet-product-title-link {
  color: var(--text);
  text-decoration: none;
}

.pet-product-business-name {
  margin: 0;
  color: var(--muted);
  font-size: 0.72rem;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.pet-product-description {
  margin: 0;
  color: var(--muted);
  font-size: 0.8rem;
  line-height: 1.48;
}

.pet-product-price-row {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 12px;
}

.pet-product-price {
  color: var(--accent);
  font-size: 1.08rem;
  line-height: 1;
}

.pet-product-price-meta {
  display: flex;
  flex-wrap: wrap;
  justify-content: flex-end;
  gap: 6px;
}

.pet-product-price-compare,
.pet-product-discount-empty {
  color: var(--muted);
  font-size: 0.74rem;
}

.pet-product-discount-chip {
  display: inline-flex;
  min-height: 24px;
  align-items: center;
  padding: 0 10px;
  border-radius: 999px;
  background: rgba(214, 75, 75, 0.12);
  color: #c34747;
  font-size: 0.7rem;
  font-weight: 800;
}

.pet-product-rating-row {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 8px;
  color: var(--muted);
  font-size: 0.78rem;
}

.pet-product-rating-stars {
  display: inline-flex;
  gap: 2px;
}

.pet-product-rating-star {
  width: 14px;
  height: 14px;
  fill: rgba(244, 180, 26, 0.18);
}

.pet-product-rating-star.is-filled {
  fill: #f4b41a;
}

.pet-product-rating-divider {
  width: 4px;
  height: 4px;
  border-radius: 999px;
  background: rgba(107, 114, 128, 0.4);
}

@media (max-width: 640px) {
  .pet-product-card {
    padding: 12px;
    border-radius: 24px;
  }

  .pet-product-title {
    font-size: 0.96rem;
  }
}
</style>
