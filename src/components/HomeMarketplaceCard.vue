<script setup>
import { computed } from "vue";
import { RouterLink, useRoute } from "vue-router";
import { formatPrice, formatProductTypeLabel, getProductDetailUrl } from "../lib/shop";

const props = defineProps({
  product: {
    type: Object,
    required: true,
  },
  badge: {
    type: String,
    default: "",
  },
  badgeTone: {
    type: String,
    default: "neutral",
  },
  compact: {
    type: Boolean,
    default: false,
  },
  showBusiness: {
    type: Boolean,
    default: true,
  },
  cartBusy: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(["cart"]);
const route = useRoute();

const detailUrl = computed(() => getProductDetailUrl(props.product.id, route.fullPath));
const currentPrice = computed(() => Number(props.product.price || 0));
const compareAtPrice = computed(() => {
  const rawValue = Number(props.product.compareAtPrice ?? props.product.originalPrice ?? 0);
  if (!Number.isFinite(rawValue) || rawValue <= currentPrice.value) {
    return 0;
  }

  return rawValue;
});
const discountPercent = computed(() => {
  if (!compareAtPrice.value) {
    return 0;
  }

  return Math.max(0, Math.round(((compareAtPrice.value - currentPrice.value) / compareAtPrice.value) * 100));
});
const badgeLabel = computed(() => {
  if (props.badge) {
    return props.badge;
  }

  if (discountPercent.value > 0) {
    return `-${discountPercent.value}%`;
  }

  return "";
});
const ratingAverage = computed(() => {
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
const businessName = computed(() => String(props.product.businessName || "").trim());
const categoryLabel = computed(() => {
  const rawLabel = formatProductTypeLabel(props.product.productType || "");
  if (rawLabel) {
    return rawLabel;
  }

  return String(props.product.category || "").trim() || "Produkt";
});
const filledStars = computed(() => {
  if (ratingAverage.value <= 0) {
    return 0;
  }

  return Math.max(0, Math.min(5, Math.round(ratingAverage.value)));
});

function handleAddToCart() {
  emit("cart", props.product.id);
}
</script>

<template>
  <article class="marketplace-card" :class="[{ 'is-compact': compact }, `tone-${badgeTone}`]">
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
    </RouterLink>

    <div class="marketplace-card-body">
      <div class="marketplace-card-meta">
        <span>{{ categoryLabel }}</span>
        <span v-if="showBusiness && businessName">{{ businessName }}</span>
      </div>

      <h3 class="marketplace-card-title">
        <RouterLink :to="detailUrl">{{ product.title }}</RouterLink>
      </h3>

      <div class="marketplace-card-pricing">
        <strong>{{ formatPrice(currentPrice) }}</strong>
        <div class="marketplace-card-price-copy">
          <span v-if="compareAtPrice" class="marketplace-card-price-old">{{ formatPrice(compareAtPrice) }}</span>
          <span v-if="discountPercent > 0" class="marketplace-card-discount">{{ discountPercent }}% ulje</span>
        </div>
      </div>

      <div class="marketplace-card-rating">
        <div class="marketplace-card-stars" :aria-label="ratingAverage > 0 ? `Vleresimi ${ratingAverage.toFixed(1)}` : 'Pa vleresime'">
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
        <span>{{ reviewCount > 0 ? `${ratingAverage.toFixed(1)} · ${reviewCount} vleresime` : "Pa vleresime" }}</span>
      </div>

      <div class="marketplace-card-actions">
        <RouterLink class="marketplace-card-link" :to="detailUrl">Shiko</RouterLink>
        <button class="marketplace-card-button" type="button" :disabled="cartBusy" @click="handleAddToCart">
          Shto ne shporte
        </button>
      </div>
    </div>
  </article>
</template>

<style scoped>
.marketplace-card {
  display: grid;
  gap: 14px;
  height: 100%;
  padding: 14px;
  border-radius: 28px;
  background:
    linear-gradient(180deg, rgba(255, 255, 255, 0.9), rgba(255, 255, 255, 0.74)),
    radial-gradient(circle at top left, rgba(255, 255, 255, 0.52), transparent 28%),
    radial-gradient(circle at bottom right, rgba(255, 106, 43, 0.08), transparent 34%);
  backdrop-filter: blur(var(--glass-blur-medium));
  -webkit-backdrop-filter: blur(var(--glass-blur-medium));
  border: 1px solid rgba(255, 255, 255, 0.56);
  box-shadow:
    0 22px 42px rgba(31, 41, 55, 0.1),
    inset 0 1px 0 rgba(255, 255, 255, 0.84);
}

.marketplace-card.is-compact {
  gap: 10px;
  padding: 12px;
  border-radius: 24px;
}

.marketplace-card-media {
  position: relative;
  display: block;
  aspect-ratio: 1 / 1;
  overflow: hidden;
  border-radius: 22px;
  background: linear-gradient(180deg, rgba(255, 255, 255, 0.92), rgba(246, 243, 240, 0.94));
  box-shadow: 0 16px 28px rgba(31, 41, 55, 0.1);
}

.marketplace-card.is-compact .marketplace-card-media {
  border-radius: 18px;
}

.marketplace-card-image {
  display: block;
  width: 100%;
  height: 100%;
  object-fit: cover;
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
  color: var(--text);
  background: var(--glass-strong-bg);
  border: 1px solid var(--glass-border);
  box-shadow: var(--glass-shadow-soft);
  backdrop-filter: blur(var(--glass-blur-soft));
  -webkit-backdrop-filter: blur(var(--glass-blur-soft));
}

.tone-alert .marketplace-card-badge {
  color: #b54141;
  border-color: rgba(181, 71, 92, 0.24);
  background: rgba(181, 71, 92, 0.12);
}

.tone-premium .marketplace-card-badge {
  color: var(--accent-dark);
  border-color: rgba(47, 52, 70, 0.16);
  background: rgba(47, 52, 70, 0.1);
}

.marketplace-card-body {
  display: grid;
  gap: 9px;
}

.marketplace-card-meta {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 8px 10px;
  color: var(--muted);
  font-size: 0.7rem;
  letter-spacing: 0.06em;
  text-transform: uppercase;
}

.marketplace-card-meta span:last-child {
  color: var(--muted);
}

.marketplace-card-title {
  margin: 0;
  font-size: 1rem;
  line-height: 1.26;
  letter-spacing: -0.02em;
}

.marketplace-card-title a {
  color: var(--text);
  text-decoration: none;
}

.marketplace-card-pricing {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 12px;
}

.marketplace-card-pricing strong {
  color: var(--accent);
  font-size: 1.16rem;
  letter-spacing: -0.03em;
}

.marketplace-card-price-copy {
  display: grid;
  justify-items: end;
  gap: 3px;
}

.marketplace-card-price-old {
  color: var(--muted);
  font-size: 0.76rem;
  text-decoration: line-through;
}

.marketplace-card-discount {
  color: #b84d4d;
  font-size: 0.72rem;
  font-weight: 700;
}

.marketplace-card-rating {
  display: flex;
  align-items: center;
  gap: 8px;
  color: var(--muted);
  font-size: 0.75rem;
}

.marketplace-card-stars {
  display: flex;
  align-items: center;
  gap: 2px;
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

.marketplace-card-actions {
  display: grid;
  grid-template-columns: auto 1fr;
  gap: 10px;
  margin-top: auto;
}

.marketplace-card-link,
.marketplace-card-button {
  min-height: 42px;
  border-radius: 16px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  font-size: 0.82rem;
  font-weight: 700;
  text-decoration: none;
}

.marketplace-card-link {
  padding: 0 14px;
  color: var(--text);
  background:
    linear-gradient(180deg, rgba(255, 255, 255, 0.26), rgba(255, 255, 255, 0.12));
  border: 1px solid rgba(255, 255, 255, 0.56);
  backdrop-filter: blur(var(--glass-blur-soft));
  -webkit-backdrop-filter: blur(var(--glass-blur-soft));
}

.marketplace-card-button {
  border: 1px solid transparent;
  color: #fff;
  cursor: pointer;
  background: var(--accent);
  box-shadow: 0 14px 28px rgba(255, 106, 43, 0.22);
}

.marketplace-card-button:disabled {
  cursor: wait;
  opacity: 0.7;
}

.marketplace-card.is-compact .marketplace-card-title {
  font-size: 0.9rem;
}

.marketplace-card.is-compact .marketplace-card-pricing strong {
  font-size: 1.02rem;
}

.marketplace-card.is-compact .marketplace-card-actions {
  grid-template-columns: 1fr;
}

@media (max-width: 640px) {
  .marketplace-card {
    gap: 12px;
    padding: 12px;
    border-radius: 22px;
  }

  .marketplace-card-media {
    border-radius: 18px;
  }

  .marketplace-card-badge {
    top: 10px;
    left: 10px;
    min-height: 24px;
    padding: 0 10px;
    font-size: 0.62rem;
  }

  .marketplace-card-title {
    font-size: 0.92rem;
  }

  .marketplace-card-pricing strong {
    font-size: 1.02rem;
  }

  .marketplace-card-actions {
    grid-template-columns: 1fr;
  }

  .marketplace-card-link,
  .marketplace-card-button {
    min-height: 40px;
  }
}
</style>
