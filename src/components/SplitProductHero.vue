<script setup>
import { computed } from "vue";
import { RouterLink } from "vue-router";
import { formatPrice, getProductDetailUrl } from "../lib/shop";

const emit = defineEmits(["select-slide"]);
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

    <div v-if="launchSlides.length > 1" class="hero-split__ad-thumbs" aria-label="Launch ads">
      <button
        v-for="(slide, index) in launchSlides"
        :key="`launch-slide-${slide.id}-${index}`"
        type="button"
        :aria-pressed="index === activeSlideIndex"
        @click="emit('select-slide', index)"
      >
        <img :src="slide.imagePath" :alt="slide.title" loading="lazy" decoding="async">
        <span>
          <small>Launch ad</small>
          <strong>{{ slide.title }}</strong>
        </span>
      </button>
    </div>
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
  min-height: clamp(260px, 34vw, 420px);
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
  min-height: inherit;
  object-fit: cover;
  display: block;
  transition: transform 260ms ease;
}

.hero-split__ad-media:hover img {
  transform: scale(1.025);
}

.hero-split__ad-thumbs {
  position: relative;
  z-index: 1;
  grid-column: 1 / -1;
  display: grid;
  grid-auto-flow: column;
  grid-auto-columns: minmax(164px, 1fr);
  gap: 10px;
  overflow-x: auto;
  padding: 4px 2px 2px;
  scrollbar-width: none;
}

.hero-split__ad-thumbs::-webkit-scrollbar {
  display: none;
}

.hero-split__ad-thumbs button {
  min-width: 0;
  display: grid;
  grid-template-columns: 44px minmax(0, 1fr);
  align-items: center;
  gap: 10px;
  padding: 8px;
  border: 1px solid #e8e8e8;
  border-radius: 16px;
  background: rgba(255, 255, 255, 0.78);
  color: #111111;
  text-align: left;
  cursor: pointer;
  transition: border-color 160ms ease, background-color 160ms ease, transform 160ms ease;
}

.hero-split__ad-thumbs button:hover,
.hero-split__ad-thumbs button[aria-pressed="true"] {
  border-color: rgba(255, 106, 0, 0.42);
  background: #ffffff;
  transform: translateY(-1px);
}

.hero-split__ad-thumbs img {
  width: 44px;
  height: 44px;
  border-radius: 12px;
  object-fit: cover;
  background: #f4f4f4;
}

.hero-split__ad-thumbs span {
  min-width: 0;
  display: grid;
  gap: 3px;
}

.hero-split__ad-thumbs small {
  color: #ff6a00;
  font-size: 10px;
  font-weight: 850;
  line-height: 1;
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

.hero-split__ad-thumbs strong {
  min-width: 0;
  color: #111111;
  font-size: 12px;
  font-weight: 800;
  line-height: 1.25;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

@media (max-width: 900px) {
  .hero-split {
    grid-template-columns: 1fr;
    min-height: 0;
    padding: 24px;
  }

  .hero-split__ad-media {
    min-height: 260px;
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
    min-height: 220px;
    border-radius: 18px;
  }

  .hero-split__ad-thumbs {
    grid-auto-columns: minmax(148px, 78vw);
  }
}
</style>
