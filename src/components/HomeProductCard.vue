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
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 12px;
  padding: 12px;
  border: 1px solid var(--dashboard-border);
  border-radius: var(--dashboard-radius-lg);
  background: var(--dashboard-surface);
  box-shadow: var(--dashboard-shadow-sm);
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
}

.home-product-card:hover {
  transform: translateY(-4px);
  border-color: var(--dashboard-accent-border);
  box-shadow: var(--dashboard-shadow-md);
}

.home-product-card__media {
  position: relative;
  aspect-ratio: 1 / 1;
  overflow: hidden;
  border-radius: var(--dashboard-radius);
  background: var(--dashboard-bg);
}

.home-product-card__image {
  width: 100%;
  height: 100%;
  object-fit: cover;
  transition: transform 0.5s ease;
}

.home-product-card:hover .home-product-card__image {
  transform: scale(1.05);
}

.home-product-card__badge {
  position: absolute;
  top: 10px;
  left: 10px;
  z-index: 1;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  height: 24px;
  padding: 0 10px;
  border-radius: 6px;
  background: var(--dashboard-accent);
  color: #ffffff;
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.02em;
}

.home-product-card__wishlist {
  position: absolute;
  top: 10px;
  right: 10px;
  z-index: 2;
  width: 36px;
  height: 36px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  border: none;
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.9);
  color: var(--dashboard-text);
  cursor: pointer;
  transition: all 0.2s ease;
  box-shadow: var(--dashboard-shadow-sm);
}

.home-product-card__wishlist:hover {
  background: #ffffff;
  color: var(--dashboard-rose);
  transform: scale(1.1);
}

.home-product-card__title {
  margin: 0;
  font-size: 15px;
  font-weight: 600;
  line-height: 1.4;
  color: var(--dashboard-text);
}

.home-product-card__business {
  font-size: 13px;
  color: var(--dashboard-muted);
  margin-top: 2px;
}

.home-product-card__price {
  font-size: 18px;
  font-weight: 700;
  color: var(--dashboard-text);
}

.home-product-card__price--sale {
  color: var(--dashboard-rose);
}

.home-product-card__button {
  width: 100%;
  min-height: 40px;
  border-radius: var(--dashboard-radius);
  background: var(--dashboard-text);
  color: #ffffff;
  border: none;
  font-weight: 600;
  font-size: 14px;
  cursor: pointer;
  transition: all 0.2s ease;
  margin-top: auto;
}

.home-product-card__button:hover {
  background: var(--dashboard-accent);
  transform: translateY(-1px);
}

.home-product-card__copy {
  display: grid;
  gap: 2px;
  min-width: 0;
  overflow: hidden;
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
  overflow-wrap: anywhere;
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
  min-width: 0;
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
  min-width: 0;
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
  gap: 4px;
  padding: 5px 5px 7px;
}

.home-product-card--compact .home-product-card__media {
  aspect-ratio: 1 / 0.7;
}

.home-product-card--compact .home-product-card__badge {
  top: 5px;
  right: 5px;
  min-height: 16px;
  padding: 0 5px;
  background: #e34d17;
  color: #ffffff;
  font-size: 7px;
  font-weight: 800;
  letter-spacing: 0.02em;
}

.home-product-card--compact .home-product-card__wishlist {
  right: 5px;
  bottom: 5px;
  width: 22px;
  height: 22px;
}

.home-product-card--compact .home-product-card__body {
  gap: 3px;
}

.home-product-card--compact .home-product-card__summary {
  gap: 4px;
}

.home-product-card--compact .home-product-card__title,
.home-product-card--compact .home-product-card__price {
  font-size: 9px;
  line-height: 1.18;
}

.home-product-card--compact .home-product-card__business {
  font-size: 7px;
  line-height: 1.15;
}

.home-product-card--compact .home-product-card__compare-price,
.home-product-card--compact .home-product-card__discount,
.home-product-card--compact .home-product-card__rating,
.home-product-card--compact .home-product-card__sold {
  font-size: 6.5px;
}

.home-product-card--compact .home-product-card__price-meta {
  gap: 3px;
}

.home-product-card--compact .home-product-card__rating {
  gap: 4px;
  min-height: 10px;
}

.home-product-card--compact .home-product-card__stars svg {
  width: 8px;
  height: 8px;
}

.home-product-card--compact .home-product-card__button {
  height: 24px;
  min-height: 24px;
  padding: 0 6px;
  font-size: 8px;
}

@media (max-width: 640px) {
  .home-product-card {
    gap: 9px;
    padding: 8px 8px 12px;
    border-radius: 12px;
  }

  .home-product-card__media-shell {
    flex-shrink: 0;
  }

  .home-product-card__media {
    aspect-ratio: 1 / 1.08;
    border-radius: 10px;
  }

  .home-product-card__badge {
    top: 7px;
    right: 7px;
    min-height: 20px;
    padding: 0 7px;
    font-size: 8px;
  }

  .home-product-card__wishlist {
    right: 8px;
    bottom: 8px;
    width: 30px;
    height: 30px;
  }

  .home-product-card__body {
    gap: 7px;
  }

  .home-product-card__copy {
    gap: 3px;
  }

  .home-product-card__summary {
    grid-template-columns: 1fr;
    gap: 6px;
  }

  .home-product-card__price-stack {
    width: 100%;
    justify-items: start;
    gap: 3px;
  }

  .home-product-card__title {
    font-size: 12px;
    line-height: 1.32;
    min-height: calc(1.32em * 2);
  }

  .home-product-card__business {
    font-size: 10px;
    line-height: 1.3;
    min-height: 1.3em;
  }

  .home-product-card__price {
    font-size: 12px;
    line-height: 1.2;
  }

  .home-product-card__price-meta {
    justify-content: flex-start;
    gap: 5px;
  }

  .home-product-card__compare-price,
  .home-product-card__discount {
    font-size: 9px;
  }

  .home-product-card__rating {
    display: grid;
    grid-template-columns: minmax(0, 1fr) auto;
    align-items: center;
    gap: 6px;
    min-height: 22px;
    font-size: 9px;
  }

  .home-product-card__rating-main {
    gap: 4px;
    min-width: 0;
  }

  .home-product-card__rating-main > span {
    display: none;
  }

  .home-product-card__stars svg {
    width: 10px;
    height: 10px;
  }

  .home-product-card__sold {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    min-height: 18px;
    padding: 0 6px;
    border-radius: 999px;
    background: #f9f2ec;
    color: #b26031;
    font-size: 9px;
  }

  .home-product-card__button {
    min-height: 34px;
    height: 34px;
    padding: 0 10px;
    font-size: 11px;
    line-height: 1;
  }

  .home-product-card--compact {
    gap: 4px;
    padding: 5px 5px 7px;
    border-radius: 10px;
  }

  .home-product-card--compact .home-product-card__media {
    aspect-ratio: 1 / 0.72;
    border-radius: 8px;
  }

  .home-product-card--compact .home-product-card__badge {
    top: 4px;
    right: 4px;
    min-height: 15px;
    padding: 0 4px;
    font-size: 6px;
    max-width: calc(100% - 8px);
  }

  .home-product-card--compact .home-product-card__wishlist {
    right: 4px;
    bottom: 4px;
    width: 20px;
    height: 20px;
  }

  .home-product-card--compact .home-product-card__body {
    gap: 3px;
  }

  .home-product-card--compact .home-product-card__summary {
    gap: 4px;
  }

  .home-product-card--compact .home-product-card__title {
    font-size: 8.5px;
    line-height: 1.18;
    min-height: calc(1.18em * 2);
  }

  .home-product-card--compact .home-product-card__business {
    font-size: 7px;
    line-height: 1.15;
    min-height: 1.15em;
  }

  .home-product-card--compact .home-product-card__price {
    font-size: 8.5px;
  }

  .home-product-card--compact .home-product-card__compare-price,
  .home-product-card--compact .home-product-card__discount,
  .home-product-card--compact .home-product-card__rating,
  .home-product-card--compact .home-product-card__sold {
    font-size: 6px;
  }

  .home-product-card--compact .home-product-card__price-meta {
    gap: 2px;
  }

  .home-product-card--compact .home-product-card__rating {
    grid-template-columns: minmax(0, 1fr) auto;
    align-items: center;
    gap: 3px;
    min-height: 12px;
  }

  .home-product-card--compact .home-product-card__stars svg {
    width: 7px;
    height: 7px;
  }

  .home-product-card--compact .home-product-card__sold {
    min-height: 12px;
    padding: 0 4px;
  }

  .home-product-card--compact .home-product-card__button {
    min-height: 22px;
    height: 22px;
    padding: 0 5px;
    font-size: 7.5px;
  }
}

@media (max-width: 420px) {
  .home-product-card {
    gap: 8px;
    padding: 8px 8px 10px;
  }

  .home-product-card__media {
    aspect-ratio: 1 / 1.12;
  }

  .home-product-card__title {
    font-size: 11px;
    line-height: 1.3;
    min-height: calc(1.3em * 2);
  }

  .home-product-card__business {
    font-size: 9px;
  }

  .home-product-card__price {
    font-size: 11px;
  }

  .home-product-card__compare-price,
  .home-product-card__discount,
  .home-product-card__rating,
  .home-product-card__sold {
    font-size: 8px;
  }

  .home-product-card__button {
    min-height: 32px;
    height: 32px;
    font-size: 10px;
  }

  .home-product-card--compact {
    gap: 4px;
    padding: 5px 5px 7px;
  }

  .home-product-card--compact .home-product-card__media {
    aspect-ratio: 1 / 0.74;
  }

  .home-product-card--compact .home-product-card__title {
    font-size: 8px;
    min-height: calc(1.16em * 2);
  }

  .home-product-card--compact .home-product-card__business {
    font-size: 6.5px;
  }

  .home-product-card--compact .home-product-card__price {
    font-size: 8px;
  }

  .home-product-card--compact .home-product-card__compare-price,
  .home-product-card--compact .home-product-card__discount,
  .home-product-card--compact .home-product-card__rating,
  .home-product-card--compact .home-product-card__sold {
    font-size: 5.5px;
  }

  .home-product-card--compact .home-product-card__button {
    min-height: 20px;
    height: 20px;
    font-size: 7px;
  }
}

@media (max-width: 360px) {
  .home-product-card__badge {
    max-width: calc(100% - 14px);
  }

  .home-product-card__button {
    padding: 0 8px;
    font-size: 9.5px;
  }

  .home-product-card--compact .home-product-card__badge {
    font-size: 5.5px;
  }

  .home-product-card--compact .home-product-card__button {
    padding: 0 4px;
    font-size: 6.5px;
  }
}
</style>
