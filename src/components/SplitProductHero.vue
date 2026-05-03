<script setup>
import { computed } from "vue";
import { RouterLink } from "vue-router";
import { formatPrice, getProductDetailUrl } from "../lib/shop";

const props = defineProps({
  leadProduct: {
    type: Object,
    default: null,
  },
  products: {
    type: Array,
    default: () => [],
  },
  headline: {
    type: String,
    default: "Summer styles are finally here",
  },
  description: {
    type: String,
    default: "Discover fresh product drops from your live catalog, arranged in a lighter grid that keeps the focus on what shoppers can browse right now.",
  },
  ctaLabel: {
    type: String,
    default: "Shop Collection",
  },
  ctaTo: {
    type: String,
    default: "/kerko",
  },
  slides: {
    type: Array,
    default: () => [],
  },
  activeIndex: {
    type: Number,
    default: 0,
  },
});

const launchSlides = computed(() => {
  const explicitSlides = Array.isArray(props.slides) ? props.slides : [];
  const fallbackSlides = Array.isArray(props.products) ? props.products : [];
  const mergedSlides = explicitSlides.length > 0 ? explicitSlides : fallbackSlides;

  return mergedSlides
    .filter((product) => Boolean(product?.id && product?.imagePath))
    .slice(0, 5);
});

const activeSlideIndex = computed(() => {
  const total = launchSlides.value.length;
  if (total <= 0) {
    return 0;
  }

  const index = Number(props.activeIndex || 0);
  return ((index % total) + total) % total;
});

const activeSlide = computed(() =>
  launchSlides.value[activeSlideIndex.value] || props.leadProduct || null,
);

const activeSlideLink = computed(() => {
  if (!activeSlide.value?.id) {
    return props.ctaTo;
  }

  return getProductDetailUrl(activeSlide.value.id, "/");
});

const activeSlideImage = computed(() => String(activeSlide.value?.imagePath || "").trim());
const activeSlideTitle = computed(() =>
  String(activeSlide.value?.title || props.headline || "Featured collection").trim(),
);
const activeSlideMeta = computed(() => {
  const business = String(activeSlide.value?.businessName || "").trim();
  const category = String(activeSlide.value?.category || activeSlide.value?.pageSection || "").trim();

  return [business, category].filter(Boolean).join(" • ") || props.description;
});
const activeSlidePrice = computed(() => {
  const price = Number(activeSlide.value?.price || 0);
  return Number.isFinite(price) && price > 0 ? formatPrice(price) : "";
});
</script>

<template>
  <section v-if="activeSlide && activeSlideImage" class="hero-split hero-split--ads" aria-label="Featured collection">
    <div class="hero-split__ad-copy">
      <span class="hero-split__ad-label">Launch ad</span>
      <h1>{{ activeSlideTitle }}</h1>
      <p>{{ activeSlideMeta }}</p>

      <div class="hero-split__ad-actions">
        <RouterLink class="hero-split__cta" :to="activeSlideLink">
          <span>{{ ctaLabel }}</span>
          <svg viewBox="0 0 24 24" aria-hidden="true">
            <path d="M5 12h14M13 5l6 7-6 7" />
          </svg>
        </RouterLink>
        <strong v-if="activeSlidePrice" class="hero-split__ad-price">{{ activeSlidePrice }}</strong>
      </div>
    </div>

    <RouterLink
      class="hero-split__ad-media"
      :to="activeSlideLink"
      :aria-label="`View ${activeSlideTitle}`"
    >
      <img
        :src="activeSlideImage"
        :alt="activeSlideTitle"
        loading="eager"
        fetchpriority="high"
        decoding="async"
        width="1200"
        height="720"
      >
    </RouterLink>
  </section>
</template>

<style scoped>
.hero-split {
  position: relative;
  min-height: clamp(380px, 52vw, 560px);
  display: grid;
  grid-template-columns: minmax(0, 0.86fr) minmax(320px, 0.92fr);
  align-items: center;
  gap: clamp(24px, 4vw, 64px);
  padding: clamp(28px, 5vw, 72px);
  border: 1px solid #e8e8e8;
  border-radius: 28px;
  background:
    radial-gradient(circle at 18% 20%, rgba(255, 106, 0, 0.12), transparent 30%),
    linear-gradient(135deg, #ffffff 0%, #f7f7f7 100%);
  overflow: hidden;
}

.hero-split::after {
  content: "";
  position: absolute;
  inset: auto -8% -42% 45%;
  height: 70%;
  border-radius: 999px;
  background: rgba(255, 106, 0, 0.08);
  filter: blur(24px);
  pointer-events: none;
}

.hero-split__ad-copy {
  position: relative;
  z-index: 1;
  max-width: 560px;
  display: grid;
  gap: 16px;
}

.hero-split__ad-label {
  width: fit-content;
  display: inline-flex;
  align-items: center;
  min-height: 28px;
  padding: 0 12px;
  border-radius: 999px;
  background: rgba(255, 106, 0, 0.1);
  color: #ff6a00;
  font-size: 11px;
  font-weight: 850;
  line-height: 1;
  text-transform: uppercase;
  letter-spacing: 0.08em;
}

.hero-split__ad-copy h1 {
  margin: 0;
  max-width: 640px;
  color: #111111;
  font-size: clamp(2.6rem, 5vw, 4.9rem);
  font-weight: 850;
  line-height: 0.95;
  letter-spacing: -0.06em;
  text-wrap: balance;
}

.hero-split__ad-copy p {
  margin: 0;
  max-width: 480px;
  color: #666666;
  font-size: 1rem;
  line-height: 1.65;
}

.hero-split__ad-actions {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 14px;
  margin-top: 8px;
}

.hero-split__cta {
  min-height: 48px;
  display: inline-flex;
  align-items: center;
  gap: 10px;
  padding: 0 20px;
  border-radius: 12px;
  background: linear-gradient(180deg, #ff7a1a 0%, #ff5a00 100%);
  color: #ffffff;
  text-decoration: none;
  font-size: 14px;
  font-weight: 800;
  transition: transform 160ms ease, filter 160ms ease;
}

.hero-split__cta:hover {
  transform: translateY(-1px);
  filter: brightness(1.03);
}

.hero-split__cta svg {
  width: 16px;
  height: 16px;
  fill: none;
  stroke: currentColor;
  stroke-width: 2;
  stroke-linecap: round;
  stroke-linejoin: round;
}

.hero-split__ad-price {
  color: #ff6a00;
  font-size: 20px;
  line-height: 1;
}

.hero-split__ad-media {
  position: relative;
  z-index: 1;
  height: clamp(280px, 32vw, 420px);
  min-height: 0;
  display: block;
  border-radius: 24px;
  overflow: hidden;
  background: #ffffff;
  text-decoration: none;
}

.hero-split__ad-media::after {
  content: "";
  position: absolute;
  inset: auto 0 0;
  height: 36%;
  background: linear-gradient(180deg, transparent, rgba(0, 0, 0, 0.18));
  pointer-events: none;
}

.hero-split__ad-media img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
  transition: transform 260ms ease;
}

.hero-split__ad-media:hover img {
  transform: scale(1.025);
}

@media (max-width: 900px) {
  .hero-split {
    grid-template-columns: 1fr;
    min-height: 0;
    padding: 24px;
  }

  .hero-split__ad-media {
    height: 260px;
  }
}

@media (max-width: 640px) {
  .hero-split {
    border-radius: 20px;
    padding: 18px;
    gap: 18px;
  }

  .hero-split__ad-copy h1 {
    font-size: clamp(2.1rem, 12vw, 3.2rem);
  }

  .hero-split__ad-copy p {
    font-size: 0.92rem;
  }

  .hero-split__ad-media {
    height: 220px;
    border-radius: 18px;
  }
}
</style>
