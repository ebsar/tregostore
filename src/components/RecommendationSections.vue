<script setup>
import { nextTick } from "vue";
import { RouterLink } from "vue-router";
import HomeProductCard from "./HomeProductCard.vue";

defineProps({
  sections: {
    type: Array,
    default: () => [],
  },
  wishlistIds: {
    type: Array,
    default: () => [],
  },
  cartIds: {
    type: Array,
    default: () => [],
  },
  busyWishlistIds: {
    type: Array,
    default: () => [],
  },
  busyCartIds: {
    type: Array,
    default: () => [],
  },
  comparedProductIds: {
    type: Array,
    default: () => [],
  },
  showOverlayActions: {
    type: Boolean,
    default: true,
  },
  showBusinessName: {
    type: Boolean,
    default: true,
  },
});

const emit = defineEmits(["wishlist", "cart", "compare"]);
const sliderTracks = new Map();

function normalizeSectionKey(sectionKey) {
  return String(sectionKey || "section").trim() || "section";
}

function setSliderTrack(sectionKey, element) {
  const normalizedKey = normalizeSectionKey(sectionKey);
  if (element) {
    sliderTracks.set(normalizedKey, element);
    return;
  }

  sliderTracks.delete(normalizedKey);
}

async function scrollRecommendationSection(sectionKey, direction) {
  await nextTick();
  const track = sliderTracks.get(normalizeSectionKey(sectionKey));
  if (!track) {
    return;
  }

  const firstCard = track.querySelector(".home-product-card");
  const cardWidth = firstCard?.getBoundingClientRect?.().width || 190;
  const trackStyles = window.getComputedStyle(track);
  const gap = Number.parseFloat(trackStyles.columnGap || trackStyles.gap || "16") || 16;
  const cardsPerStep = Math.max(2, Math.floor(track.clientWidth / Math.max(cardWidth + gap, 1)) - 1);
  track.scrollBy({
    left: direction * (cardWidth + gap) * cardsPerStep,
    behavior: "smooth",
  });
}

function getSectionActionTo(section) {
  const key = String(section?.key || "").trim().toLowerCase();

  if (key === "new-arrivals") {
    return {
      path: "/kerko",
      query: {
        sort: "newest",
      },
    };
  }

  if (key === "best-sellers") {
    return {
      path: "/kerko",
      query: {
        sort: "popular",
      },
    };
  }

  return "/kerko";
}
</script>

<template>
  <section
    v-for="section in sections"
    :key="section.key"
    class="product-collection"
    :aria-label="section.title"
  >
    <header class="recommendation-sections__header">
      <h2 class="recommendation-sections__title">
        {{ section.title }}
      </h2>

      <div class="recommendation-sections__actions">
        <div class="recommendation-sections__slider-actions" v-if="(section.products || []).length > 1">
          <button
            class="recommendation-sections__slider-button"
            type="button"
            :aria-label="`Scroll ${section.title} left`"
            @click="scrollRecommendationSection(section.key, -1)"
          >
            <svg viewBox="0 0 24 24" aria-hidden="true">
              <path d="m15 18-6-6 6-6" />
            </svg>
          </button>
          <button
            class="recommendation-sections__slider-button"
            type="button"
            :aria-label="`Scroll ${section.title} right`"
            @click="scrollRecommendationSection(section.key, 1)"
          >
            <svg viewBox="0 0 24 24" aria-hidden="true">
              <path d="m9 6 6 6-6 6" />
            </svg>
          </button>
        </div>

        <RouterLink
          :to="getSectionActionTo(section)"
          class="recommendation-sections__action"
        >
          View all
        </RouterLink>
      </div>
    </header>

    <section
      :ref="(element) => setSliderTrack(section.key, element)"
      class="home-product-grid recommendation-product-slider"
    >
      <HomeProductCard
        v-for="product in section.products"
        :key="`${section.key}-${product.id}`"
        :product="product"
        :is-wishlisted="wishlistIds.includes(product.id)"
        :is-in-cart="cartIds.includes(product.id)"
        :wishlist-busy="busyWishlistIds.includes(product.id)"
        :cart-busy="busyCartIds.includes(product.id)"
        @wishlist="emit('wishlist', $event)"
        @cart="emit('cart', $event)"
      />
    </section>
  </section>
</template>

<style scoped>
.recommendation-sections__header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  margin-bottom: 16px;
}

.recommendation-sections__title {
  margin: 0;
  color: #111111;
  font-size: 22px;
  font-weight: 700;
  line-height: 1.2;
}

.recommendation-sections__actions,
.recommendation-sections__slider-actions {
  display: flex;
  align-items: center;
}

.recommendation-sections__actions {
  flex-shrink: 0;
  gap: 12px;
  margin-left: auto;
}

.recommendation-sections__slider-actions {
  gap: 6px;
}

.recommendation-sections__slider-button {
  display: inline-grid;
  place-items: center;
  width: 30px;
  height: 30px;
  border: 1px solid rgba(17, 17, 17, 0.12);
  border-radius: 999px;
  background: #ffffff;
  color: #111111;
  cursor: pointer;
  transition:
    border-color 160ms ease,
    color 160ms ease,
    transform 160ms ease;
}

.recommendation-sections__slider-button:hover {
  border-color: rgba(255, 106, 26, 0.45);
  color: #ff6a1a;
  transform: translateY(-1px);
}

.recommendation-sections__slider-button svg {
  width: 16px;
  height: 16px;
  fill: none;
  stroke: currentColor;
  stroke-width: 2.2;
  stroke-linecap: round;
  stroke-linejoin: round;
}

.recommendation-sections__action {
  flex-shrink: 0;
  color: #111111;
  text-decoration: none;
  font-size: 13px;
  font-weight: 600;
  line-height: 1;
  transition: opacity 160ms ease;
}

.recommendation-sections__action:hover {
  opacity: 0.66;
}

.recommendation-product-slider {
  display: flex;
  gap: 24px;
  align-items: start;
  overflow-x: auto;
  overflow-y: hidden;
  padding: 2px 4px 14px;
  scroll-padding-inline: 4px;
  scroll-snap-type: x proximity;
  scroll-behavior: smooth;
  overscroll-behavior-inline: contain;
  -webkit-overflow-scrolling: touch;
  scrollbar-width: none;
}

.recommendation-product-slider::-webkit-scrollbar {
  display: none;
}

.recommendation-product-slider > * {
  flex: 0 0 190px;
  width: 190px;
  max-width: 190px;
  scroll-snap-align: start;
}

@media (max-width: 1180px) {
  .recommendation-product-slider {
    gap: 22px;
  }

  .recommendation-product-slider > * {
    flex-basis: 184px;
    width: 184px;
    max-width: 184px;
  }
}

@media (max-width: 880px) {
  .recommendation-product-slider {
    gap: 18px;
  }

  .recommendation-product-slider > * {
    flex-basis: 176px;
    width: 176px;
    max-width: 176px;
  }
}

@media (max-width: 640px) {
  .recommendation-sections__header {
    margin-bottom: 14px;
    gap: 10px;
  }

  .recommendation-sections__title {
    font-size: 18px;
  }

  .recommendation-sections__slider-button {
    width: 28px;
    height: 28px;
  }

  .recommendation-product-slider {
    gap: 14px;
    padding-inline: 2px;
    margin-inline: -2px;
  }

  .recommendation-product-slider > * {
    flex-basis: min(72vw, 178px);
    width: min(72vw, 178px);
    max-width: min(72vw, 178px);
  }
}

@media (max-width: 420px) {
  .recommendation-product-slider {
    gap: 12px;
  }

  .recommendation-product-slider > * {
    flex-basis: min(76vw, 168px);
    width: min(76vw, 168px);
    max-width: min(76vw, 168px);
  }
}
</style>
