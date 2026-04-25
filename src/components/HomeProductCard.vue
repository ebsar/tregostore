<script setup>
import { computed } from "vue";
import { RouterLink, useRoute, useRouter } from "vue-router";
import { formatCount, formatPrice, getProductDetailUrl } from "../lib/shop";

const props = defineProps({
  product: {
    type: Object,
    required: true,
  },
  compact: {
    type: Boolean,
    default: false,
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
});

const emit = defineEmits(["wishlist", "cart"]);
const route = useRoute();
const router = useRouter();

const detailUrl = computed(() => getProductDetailUrl(props.product.id, route.fullPath));
const productTitle = computed(() => String(props.product?.title || "Product").trim() || "Product");
const businessName = computed(() => String(props.product?.businessName || "").trim());
const productImage = computed(() =>
  String(props.product?.imagePath || props.product?.image || "").trim() || "/bujqesia.webp",
);
const currentPrice = computed(() => Number(props.product?.price || 0));
const compareAtPrice = computed(() => {
  const rawValue = Number(props.product?.compareAtPrice ?? props.product?.originalPrice ?? 0);
  if (Number.isFinite(rawValue) && rawValue > currentPrice.value) {
    return rawValue;
  }

  if (currentPrice.value > 0) {
    return Number((currentPrice.value / 0.8).toFixed(2));
  }

  return 0;
});
const discountPercent = computed(() => {
  if (!compareAtPrice.value || compareAtPrice.value <= currentPrice.value) {
    return 0;
  }

  return Math.max(0, Math.round(((compareAtPrice.value - currentPrice.value) / compareAtPrice.value) * 100));
});
const averageRating = computed(() => {
  const rawValue = Number(props.product?.averageRating ?? props.product?.ratingAverage ?? 0);
  if (!Number.isFinite(rawValue) || rawValue <= 0) {
    return 0;
  }

  return Math.max(0, Math.min(5, rawValue));
});
const filledStars = computed(() => Math.max(0, Math.min(5, Math.floor(averageRating.value))));
const soldCount = computed(() => {
  const rawValue = Number(props.product?.buyersCount ?? props.product?.unitsSold ?? 0);
  if (!Number.isFinite(rawValue) || rawValue <= 0) {
    return 0;
  }

  return Math.max(0, Math.trunc(rawValue));
});
const soldCountLabel = computed(() => `${formatCount(soldCount.value)} sold`);
const ratingText = computed(() => {
  if (averageRating.value > 0) {
    return `(${averageRating.value.toFixed(1)} out of 5)`;
  }

  return "(No reviews yet)";
});
const badgeLabel = computed(() => {
  const explicitLabel = String(props.product?.badgeLabel || props.product?.collectionLabel || "").trim();
  if (explicitLabel) {
    return explicitLabel;
  }

  if (props.product?.isNewSeason || props.product?.isNew) {
    return "New Season";
  }

  const rawDate = String(
    props.product?.createdAt
    || props.product?.created_at
    || props.product?.publishedAt
    || props.product?.published_at
    || "",
  ).trim();
  if (!rawDate) {
    return "";
  }

  const createdAt = new Date(rawDate);
  if (Number.isNaN(createdAt.getTime())) {
    return "";
  }

  const daysSinceCreated = (Date.now() - createdAt.getTime()) / (1000 * 60 * 60 * 24);
  return daysSinceCreated <= 75 ? "New Season" : "";
});
const primaryActionLabel = computed(() => {
  if (props.cartBusy) {
    return "Adding...";
  }

  if (props.product?.requiresVariantSelection) {
    return "Choose Options";
  }

  if (props.isInCart) {
    return "Added to Cart";
  }

  return "Add to Cart";
});
const wishlistLabel = computed(() => (
  props.isWishlisted ? "Remove from wishlist" : "Add to wishlist"
));

async function handlePrimaryAction() {
  if (props.cartBusy) {
    return;
  }

  if (props.product?.requiresVariantSelection) {
    await router.push(detailUrl.value);
    return;
  }

  emit("cart", props.product.id);
}

function handleWishlist() {
  if (props.wishlistBusy) {
    return;
  }

  emit("wishlist", props.product.id);
}
</script>

<template>
  <article
    class="home-product-card"
    :class="{ 'home-product-card--compact': compact }"
    :aria-label="productTitle"
  >
    <div class="home-product-card__media-shell">
      <RouterLink
        class="home-product-card__media-link"
        :to="detailUrl"
        :aria-label="`Open ${productTitle}`"
      >
        <div class="home-product-card__media">
          <img
            class="home-product-card__image"
            :src="productImage"
            :alt="productTitle"
            width="720"
            height="820"
            loading="lazy"
            decoding="async"
          >
          <span v-if="badgeLabel" class="home-product-card__badge">{{ badgeLabel }}</span>
        </div>
      </RouterLink>

      <button
        class="home-product-card__wishlist"
        type="button"
        :disabled="wishlistBusy"
        :aria-label="wishlistLabel"
        :aria-pressed="isWishlisted"
        @click.stop="handleWishlist"
      >
        <svg viewBox="0 0 24 24" aria-hidden="true">
          <path d="M12 20.4 4.9 13.8a4.8 4.8 0 0 1 6.8-6.8l.3.3.3-.3a4.8 4.8 0 1 1 6.8 6.8Z"></path>
        </svg>
      </button>
    </div>

    <div class="home-product-card__body">
      <div class="home-product-card__summary">
        <div class="home-product-card__copy">
          <h3 class="home-product-card__title">
            <RouterLink :to="detailUrl">
              {{ productTitle }}
            </RouterLink>
          </h3>
          <p v-if="businessName" class="home-product-card__business">{{ businessName }}</p>
        </div>

        <div class="home-product-card__price-stack">
          <p
            class="home-product-card__price"
            :class="{ 'home-product-card__price--sale': discountPercent > 0 }"
          >
            {{ formatPrice(currentPrice) }}
          </p>
          <div v-if="compareAtPrice" class="home-product-card__price-meta">
            <span class="home-product-card__compare-price">{{ formatPrice(compareAtPrice) }}</span>
            <span v-if="discountPercent > 0" class="home-product-card__discount">-{{ discountPercent }}%</span>
          </div>
        </div>
      </div>

      <div class="home-product-card__rating">
        <div class="home-product-card__rating-main">
          <div class="home-product-card__stars" :aria-label="averageRating > 0 ? `${averageRating.toFixed(1)} out of 5` : 'No reviews yet'">
            <svg
              v-for="index in 5"
              :key="index"
              :class="{ 'home-product-card__star--filled': index <= filledStars }"
              viewBox="0 0 24 24"
              aria-hidden="true"
            >
              <path d="M12 3.8 14.6 9l5.7.8-4.1 4 1 5.7-5.2-2.7-5.2 2.7 1-5.7-4.1-4 5.7-.8Z"></path>
            </svg>
          </div>
          <span>{{ ratingText }}</span>
        </div>
        <span class="home-product-card__sold">{{ soldCountLabel }}</span>
      </div>

      <button
        class="home-product-card__button"
        type="button"
        :disabled="cartBusy"
        @click.stop="handlePrimaryAction"
      >
        {{ primaryActionLabel }}
      </button>
    </div>
  </article>
</template>

<style scoped>
.home-product-card {
  height: 100%;
  display: flex;
  flex-direction: column;
  gap: 10px;
  padding: 10px 10px 15px;
  border: 1px solid #ececec;
  border-radius: 14px;
  background: #ffffff;
  transition:
    transform 180ms ease,
    border-color 180ms ease,
    box-shadow 180ms ease;
}

.home-product-card:hover {
  transform: translateY(-1px);
  border-color: #e1e1e1;
  box-shadow: 0 8px 18px rgba(17, 17, 17, 0.035);
}

.home-product-card__media-link {
  display: block;
  text-decoration: none;
  color: inherit;
}

.home-product-card__media-shell {
  position: relative;
}

.home-product-card__media {
  position: relative;
  aspect-ratio: 1 / 0.84;
  overflow: hidden;
  border-radius: 12px;
  background: #f3f3f3;
}

.home-product-card__media::after {
  content: "";
  position: absolute;
  inset: auto 0 0;
  height: 28%;
  background: linear-gradient(to top, rgba(17, 17, 17, 0.06), rgba(17, 17, 17, 0));
  pointer-events: none;
}

.home-product-card__image {
  width: 100%;
  height: 100%;
  object-fit: cover;
  object-position: center;
  transition:
    transform 220ms ease,
    filter 220ms ease;
}

.home-product-card:hover .home-product-card__image {
  transform: scale(1.02);
  filter: brightness(1.02);
}

.home-product-card__badge {
  position: absolute;
  top: 8px;
  right: 8px;
  z-index: 1;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-height: 22px;
  padding: 0 8px;
  border-radius: 999px;
  background: #f36a20;
  color: #ffffff;
  font-size: 9px;
  font-weight: 700;
  letter-spacing: 0.01em;
}

.home-product-card__wishlist {
  position: absolute;
  right: 10px;
  bottom: 10px;
  z-index: 2;
  width: 32px;
  height: 32px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  border: 0;
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.94);
  color: #202020;
  cursor: pointer;
  transition:
    background-color 160ms ease,
    color 160ms ease,
    transform 160ms ease;
}

.home-product-card__wishlist:hover {
  background: #ffffff;
  transform: translateY(-1px);
}

.home-product-card__wishlist:disabled {
  cursor: wait;
  opacity: 0.7;
}

.home-product-card__wishlist[aria-pressed="true"] {
  color: #c43c3c;
}

.home-product-card__wishlist svg {
  width: 15px;
  height: 15px;
  fill: none;
  stroke: currentColor;
  stroke-width: 1.9;
  stroke-linecap: round;
  stroke-linejoin: round;
}

.home-product-card__wishlist[aria-pressed="true"] svg {
  fill: currentColor;
}

.home-product-card__body {
  display: grid;
  gap: 6px;
  flex: 1;
}

.home-product-card__summary {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto;
  align-items: start;
  gap: 8px;
}

.home-product-card__copy {
  display: grid;
  gap: 2px;
  min-width: 0;
}

.home-product-card__title {
  margin: 0;
  font-size: 13px;
  font-weight: 700;
  line-height: 1.35;
  color: #111111;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.home-product-card__title a {
  color: inherit;
  text-decoration: none;
}

.home-product-card__title a:hover {
  color: #2b2b2b;
}

.home-product-card__business {
  margin: 0;
  color: #777777;
  font-size: 11px;
  line-height: 1.4;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.home-product-card__price-stack {
  display: grid;
  justify-items: end;
  gap: 2px;
}

.home-product-card__price {
  margin: 0;
  font-size: 13px;
  font-weight: 700;
  line-height: 1.2;
  color: #111111;
  white-space: nowrap;
}

.home-product-card__price--sale {
  color: #cf2f2f;
}

.home-product-card__price-meta {
  display: inline-flex;
  align-items: center;
  justify-content: flex-end;
  gap: 6px;
  flex-wrap: wrap;
}

.home-product-card__compare-price {
  color: #989898;
  font-size: 10px;
  line-height: 1.2;
  text-decoration: line-through;
  white-space: nowrap;
}

.home-product-card__discount {
  color: #cf2f2f;
  font-size: 10px;
  font-weight: 700;
  line-height: 1.2;
  white-space: nowrap;
}

.home-product-card__rating {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  min-height: 16px;
  color: #737373;
  font-size: 10px;
  line-height: 1.4;
}

.home-product-card__rating-main {
  min-width: 0;
  display: inline-flex;
  align-items: center;
  gap: 6px;
}

.home-product-card__stars {
  display: inline-flex;
  align-items: center;
  gap: 2px;
  color: #f2b01e;
  flex-shrink: 0;
}

.home-product-card__stars svg {
  width: 11px;
  height: 11px;
  fill: none;
  stroke: currentColor;
  stroke-width: 1.8;
  stroke-linecap: round;
  stroke-linejoin: round;
}

.home-product-card__stars .home-product-card__star--filled {
  fill: currentColor;
}

.home-product-card__sold {
  color: #767676;
  font-size: 10px;
  line-height: 1.2;
  white-space: nowrap;
  flex-shrink: 0;
}

.home-product-card__button {
  width: 100%;
  height: 36px;
  min-height: 36px;
  padding: 0 10px;
  border: 0;
  border-radius: 8px;
  background: #f36a20;
  color: #ffffff;
  font-size: 12px;
  font-weight: 600;
  line-height: 1;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  margin-top: auto;
  cursor: pointer;
  transition:
    background-color 180ms ease,
    color 180ms ease;
}

.home-product-card__button:hover {
  background: #df5e17;
}

.home-product-card__button:disabled {
  cursor: wait;
  opacity: 0.78;
}

.home-product-card--compact {
  gap: 7px;
  padding: 8px 8px 11px;
}

.home-product-card--compact .home-product-card__media {
  aspect-ratio: 1 / 0.58;
}

.home-product-card--compact .home-product-card__badge {
  top: 8px;
  right: 8px;
  min-height: 24px;
  padding: 0 10px;
  background: #e34d17;
  color: #ffffff;
  font-size: 10px;
  font-weight: 800;
  letter-spacing: 0.02em;
}

.home-product-card--compact .home-product-card__wishlist {
  right: 8px;
  bottom: 8px;
  width: 30px;
  height: 30px;
}

.home-product-card--compact .home-product-card__body {
  gap: 4px;
}

.home-product-card--compact .home-product-card__summary {
  gap: 6px;
}

.home-product-card--compact .home-product-card__title,
.home-product-card--compact .home-product-card__price {
  font-size: 12px;
  line-height: 1.28;
}

.home-product-card--compact .home-product-card__business {
  font-size: 10px;
  line-height: 1.25;
}

.home-product-card--compact .home-product-card__compare-price,
.home-product-card--compact .home-product-card__discount,
.home-product-card--compact .home-product-card__rating,
.home-product-card--compact .home-product-card__sold {
  font-size: 9px;
}

.home-product-card--compact .home-product-card__price-meta {
  gap: 4px;
}

.home-product-card--compact .home-product-card__rating {
  gap: 6px;
  min-height: 14px;
}

.home-product-card--compact .home-product-card__stars svg {
  width: 10px;
  height: 10px;
}

.home-product-card--compact .home-product-card__button {
  height: 33px;
  min-height: 33px;
  font-size: 11px;
}

@media (max-width: 640px) {
  .home-product-card {
    padding: 9px 9px 13px;
    border-radius: 13px;
  }

  .home-product-card__summary {
    gap: 8px;
  }

  .home-product-card__title,
  .home-product-card__price {
    font-size: 12px;
  }

  .home-product-card__rating {
    gap: 6px;
    font-size: 10px;
  }

  .home-product-card--compact {
    padding: 8px 8px 10px;
  }
}
</style>
