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
  <article>
    <RouterLink :to="detailUrl" :aria-label="`Hape produktin ${product.title}`">
      <img
       
        :src="product.imagePath"
        :alt="product.title"
        width="720"
        height="720"
        loading="lazy"
        decoding="async"
      >
      <span v-if="badgeLabel">{{ badgeLabel }}</span>
    </RouterLink>

    <div>
      <div>
        <span>{{ categoryLabel }}</span>
      </div>

      <h3>
        <RouterLink :to="detailUrl">{{ product.title }}</RouterLink>
      </h3>

      <p v-if="showBusiness && businessName">
        {{ businessName }}
      </p>

      <div>
        <strong>{{ formatPrice(currentPrice) }}</strong>
        <div>
          <span v-if="compareAtPrice">{{ formatPrice(compareAtPrice) }}</span>
          <span v-if="discountPercent > 0">{{ discountPercent }}% ulje</span>
        </div>
      </div>

      <div>
        <div :aria-label="ratingAverage > 0 ? `Vleresimi ${ratingAverage.toFixed(1)}` : 'Pa vleresime'">
          <svg
            v-for="index in 5"
            :key="index"
           
           
            viewBox="0 0 24 24"
            aria-hidden="true"
          >
            <path d="M12 3.8 14.6 9l5.7.8-4.1 4 1 5.7-5.2-2.7-5.2 2.7 1-5.7-4.1-4 5.7-.8Z"></path>
          </svg>
        </div>
        <span>{{ reviewCount > 0 ? `${ratingAverage.toFixed(1)} · ${reviewCount} vleresime` : "Pa vleresime" }}</span>
      </div>

      <div>
        <RouterLink :to="detailUrl">Shiko</RouterLink>
        <button type="button" :disabled="cartBusy" @click="handleAddToCart">
          Shto ne shporte
        </button>
      </div>
    </div>
  </article>
</template>

