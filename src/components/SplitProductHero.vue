<script setup>
import { computed } from "vue";
import { RouterLink } from "vue-router";
import { getProductDetailUrl } from "../lib/shop";

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
});

const GRID_SLOT_CLASSES = [
  "hero-split__item--lead",
  "hero-split__item--wide",
  "hero-split__item--square",
  "hero-split__item--small-one",
  "hero-split__item--small-two",
];

const gridItems = computed(() => {
  const availableProducts = Array.isArray(props.products)
    ? props.products.filter((product) => Boolean(product?.imagePath))
    : [];

  if (!availableProducts.length) {
    return [];
  }

  return GRID_SLOT_CLASSES.map((slotClass, index) => ({
    slotClass,
    product: availableProducts[index % availableProducts.length],
    index,
  }));
});

const leadProductLink = computed(() => {
  if (!props.leadProduct?.id) {
    return props.ctaTo;
  }

  return getProductDetailUrl(props.leadProduct.id, "/");
});
</script>

<template>
  <section v-if="leadProduct && gridItems.length" class="hero-split" aria-label="Featured collection">
    <div class="hero-split__content">
      <h1>{{ headline }}</h1>
      <p>{{ description }}</p>

      <RouterLink class="hero-split__cta" :to="ctaTo">
        <span>{{ ctaLabel }}</span>
        <svg viewBox="0 0 24 24" aria-hidden="true">
          <path d="M5 12h14M13 5l6 7-6 7" />
        </svg>
      </RouterLink>
    </div>

    <div class="hero-split__visual">
      <div class="hero-split__grid" aria-label="Product image grid">
        <RouterLink
          v-for="item in gridItems"
          :key="`${item.slotClass}-${item.product.id}-${item.index}`"
          class="hero-split__item"
          :class="item.slotClass"
          :to="getProductDetailUrl(item.product.id, '/')"
          :aria-label="`View ${item.product.title}`"
        >
          <img
            :src="item.product.imagePath"
            :alt="item.product.title"
            :loading="item.index === 0 ? 'eager' : 'lazy'"
            :fetchpriority="item.index === 0 ? 'high' : 'auto'"
            decoding="async"
            width="800"
            height="1000"
          >
          <span class="hero-split__item-fade" aria-hidden="true"></span>
        </RouterLink>
      </div>

      <RouterLink class="hero-split__caption" :to="leadProductLink">
        <strong>{{ leadProduct.title }}</strong>
        <span>{{ leadProduct.businessName || "Live collection" }}</span>
      </RouterLink>
    </div>
  </section>
</template>

<style scoped>
.hero-split {
  display: grid;
  grid-template-columns: minmax(0, 1fr) minmax(280px, 0.72fr);
  align-items: center;
  justify-items: stretch;
  gap: clamp(20px, 4vw, 52px);
  padding: clamp(1rem, 2vw, 1.8rem) 0;
}

.hero-split__content {
  max-width: 620px;
  display: grid;
  gap: 16px;
  z-index: 1;
}

.hero-split__content h1 {
  margin: 0;
  color: #111111;
  font-family: "Inter", "Segoe UI", "Helvetica Neue", Arial, sans-serif;
  font-size: clamp(2.6rem, 5vw, 4.6rem);
  font-weight: 700;
  line-height: 0.98;
  letter-spacing: -0.05em;
  text-wrap: balance;
}

.hero-split__content p {
  margin: 0;
  max-width: 460px;
  color: #6f6f6f;
  font-family: "Inter", "Segoe UI", "Helvetica Neue", Arial, sans-serif;
  font-size: 1rem;
  line-height: 1.7;
}

.hero-split__cta {
  width: fit-content;
  min-height: 46px;
  display: inline-flex;
  align-items: center;
  gap: 10px;
  padding: 0 18px;
  border-radius: 10px;
  background: linear-gradient(180deg, #f47a2c 0%, #f36a20 100%);
  color: #ffffff;
  text-decoration: none;
  font-family: "Inter", "Segoe UI", "Helvetica Neue", Arial, sans-serif;
  font-size: 14px;
  font-weight: 600;
  transition:
    filter 160ms ease,
    transform 160ms ease;
}

.hero-split__cta:hover {
  filter: brightness(0.96);
}

.hero-split__cta svg {
  width: 16px;
  height: 16px;
  stroke: currentColor;
  stroke-width: 1.8;
  fill: none;
}

.hero-split__visual {
  justify-self: end;
  width: min(100%, 420px);
  display: grid;
  gap: 8px;
}

.hero-split__grid {
  display: grid;
  grid-template-columns: 1.1fr 0.92fr 0.92fr;
  grid-template-rows: 1.08fr 0.92fr 0.8fr;
  gap: 7px;
  min-height: 92px;
}

.hero-split__item {
  position: relative;
  overflow: hidden;
  border-radius: 9px;
  background: #ececec;
  text-decoration: none;
}

.hero-split__item img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  transition:
    transform 180ms ease,
    filter 180ms ease;
}

.hero-split__item:hover img {
  transform: scale(1.02);
  filter: brightness(1.03);
}

.hero-split__item-fade {
  position: absolute;
  inset: auto 0 0;
  height: 24%;
  background: linear-gradient(180deg, rgba(255, 255, 255, 0) 0%, rgba(17, 17, 17, 0.08) 100%);
  pointer-events: none;
}

.hero-split__item--lead {
  grid-column: 1;
  grid-row: 1 / span 3;
}

.hero-split__item--wide {
  grid-column: 2 / span 2;
  grid-row: 1;
}

.hero-split__item--square {
  grid-column: 2;
  grid-row: 2;
}

.hero-split__item--small-one {
  grid-column: 3;
  grid-row: 2;
}

.hero-split__item--small-two {
  grid-column: 2 / span 2;
  grid-row: 3;
}

.hero-split__caption {
  width: fit-content;
  display: grid;
  gap: 4px;
  color: #111111;
  text-decoration: none;
  font-family: "Inter", "Segoe UI", "Helvetica Neue", Arial, sans-serif;
}

.hero-split__caption strong {
  font-size: 12px;
  font-weight: 600;
  line-height: 1.4;
}

.hero-split__caption span {
  color: #7b7b7b;
  font-size: 11px;
  line-height: 1.4;
}

@media (max-width: 1024px) {
  .hero-split {
    grid-template-columns: minmax(0, 1fr) minmax(240px, 360px);
    gap: 24px;
  }

  .hero-split__visual {
    justify-self: end;
    width: min(100%, 360px);
    max-width: none;
  }

  .hero-split__grid {
    min-height: 92px;
  }
}

@media (max-width: 720px) {
  .hero-split {
    grid-template-columns: 1fr;
    padding: 1.5rem 0 1rem;
  }

  .hero-split__visual {
    justify-self: stretch;
    width: min(100%, 360px);
  }

  .hero-split__content {
    gap: 16px;
  }

  .hero-split__content h1 {
    font-size: clamp(2rem, 11vw, 3rem);
  }

  .hero-split__grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
    grid-template-rows: 1.2fr 1fr 1fr;
    gap: 8px;
    min-height: 140px;
  }

  .hero-split__item--lead {
    grid-column: 1;
    grid-row: 1 / span 2;
  }

  .hero-split__item--wide {
    grid-column: 2;
    grid-row: 1;
  }

  .hero-split__item--square {
    grid-column: 2;
    grid-row: 2;
  }

  .hero-split__item--small-one {
    grid-column: 1;
    grid-row: 3;
  }

  .hero-split__item--small-two {
    grid-column: 2;
    grid-row: 3;
  }
}
</style>
