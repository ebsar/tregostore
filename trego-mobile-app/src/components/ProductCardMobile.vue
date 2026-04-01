<script setup lang="ts">
import { IonButton, IonIcon } from "@ionic/vue";
import { addOutline, heartOutline, star } from "ionicons/icons";
import { computed, withDefaults } from "vue";
import type { ProductItem } from "../types/models";
import { formatCount, formatPrice, getDiscountPercent, getProductImage } from "../lib/format";

const props = withDefaults(defineProps<{
  product: ProductItem;
  analyticsMode?: boolean;
}>(), {
  analyticsMode: false,
});

const emit = defineEmits<{
  (event: "open", productId: number): void;
  (event: "wishlist", productId: number): void;
  (event: "cart", productId: number): void;
}>();

const discount = computed(() => getDiscountPercent(props.product));
const hasCompareAtPrice = computed(() => Number(props.product.compareAtPrice || 0) > Number(props.product.price || 0));
const variantSummary = computed(() => {
  const sizeCount = new Set(
    [
      ...(Array.isArray(props.product.availableSizes) ? props.product.availableSizes : []),
      ...((props.product.variantInventory || []).map((entry) => String(entry.size || "").trim().toUpperCase()).filter(Boolean)),
    ],
  ).size;
  const colorCount = new Set(
    [
      ...(Array.isArray(props.product.availableColors) ? props.product.availableColors : []),
      ...((props.product.variantInventory || []).map((entry) => String(entry.color || "").trim().toLowerCase()).filter(Boolean)),
    ],
  ).size;

  const parts: string[] = [];
  if (sizeCount) {
    parts.push(`${sizeCount} masa`);
  }
  if (colorCount) {
    parts.push(`${colorCount} ngjyra`);
  }
  if (!parts.length && props.product.requiresVariantSelection) {
    parts.push("Variantet zgjidhen ne faqe");
  }

  return parts.join(" · ");
});
const engagementItems = computed(() => ([
  { label: "Views", value: formatCount(props.product.viewsCount || 0) },
  { label: "Wishlist", value: formatCount(props.product.wishlistCount || 0) },
  { label: "Cart", value: formatCount(props.product.cartCount || 0) },
  { label: "Share", value: formatCount(props.product.shareCount || 0) },
]));
</script>

<template>
  <article class="product-card-mobile surface-card">
    <div class="product-card-mobile-media">
      <img :src="getProductImage(product)" :alt="product.title" />
      <span v-if="discount" class="product-card-mobile-badge">-{{ discount }}%</span>
      <button class="product-card-mobile-open-hit" type="button" @click="emit('open', product.id)">
        <span class="sr-only">Hap produktin</span>
      </button>
      <button
        v-if="!analyticsMode"
        class="product-card-mobile-save"
        type="button"
        @click.stop="emit('wishlist', product.id)"
      >
        <IonIcon :icon="heartOutline" />
      </button>
    </div>

    <div class="product-card-mobile-copy">
      <p class="product-card-mobile-business">{{ product.businessName || "TREGO" }}</p>
      <button class="product-card-mobile-title" type="button" @click="emit('open', product.id)">
        {{ product.title }}
      </button>
      <p class="product-card-mobile-desc">{{ product.description || "Produkt i kuruar per blerje te shpejte." }}</p>
      <p v-if="variantSummary" class="product-card-mobile-variant">{{ variantSummary }}</p>

      <div class="product-card-mobile-meta">
        <div class="product-card-mobile-pricing">
          <strong>{{ formatPrice(product.price) }}</strong>
          <span v-if="hasCompareAtPrice" class="product-card-mobile-compare">
            {{ formatPrice(product.compareAtPrice) }}
          </span>
        </div>
        <span class="product-card-mobile-rating">
          <IonIcon :icon="star" />
          {{ Number(product.averageRating || 0).toFixed(1) }}
        </span>
      </div>

      <div v-if="analyticsMode" class="product-card-mobile-engagement">
        <span
          v-for="item in engagementItems"
          :key="`${product.id}-${item.label}`"
          class="product-card-mobile-engagement-item"
        >
          <small>{{ item.label }}</small>
          <strong>{{ item.value }}</strong>
        </span>
      </div>

      <div v-else class="product-card-mobile-actions">
        <IonButton class="cta-button product-card-mobile-add" @click="emit('cart', product.id)">
          <IonIcon slot="start" :icon="addOutline" />
          Shto ne cart
        </IonButton>
      </div>
    </div>
  </article>
</template>

<style scoped>
.product-card-mobile {
  display: flex;
  flex-direction: column;
  gap: 12px;
  padding: 12px;
  height: 100%;
}

.product-card-mobile-media {
  position: relative;
  overflow: hidden;
  border: 0;
  border-radius: 22px;
  padding: 0;
  aspect-ratio: 0.84;
  background: var(--trego-interactive-bg-strong);
}

.product-card-mobile-open-hit {
  position: absolute;
  inset: 0;
  border: 0;
  background: transparent;
}

.product-card-mobile-save {
  position: absolute;
  top: 10px;
  right: 10px;
  display: inline-flex;
  width: 34px;
  height: 34px;
  align-items: center;
  justify-content: center;
  border: 1px solid var(--trego-input-border);
  border-radius: 999px;
  background: var(--trego-interactive-bg-strong);
  color: var(--trego-dark);
  box-shadow: 0 8px 18px rgba(31, 41, 55, 0.12);
  z-index: 1;
}

.product-card-mobile-media img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
}

.product-card-mobile-badge {
  position: absolute;
  top: 10px;
  left: 10px;
  display: inline-flex;
  min-height: 26px;
  align-items: center;
  padding: 0 10px;
  border-radius: 999px;
  background: rgba(255, 106, 43, 0.92);
  color: var(--trego-badge-text);
  font-size: 0.72rem;
  font-weight: 800;
}

.product-card-mobile-copy {
  display: flex;
  flex-direction: column;
  gap: 9px;
  flex: 1 1 auto;
  min-height: 0;
}

.product-card-mobile-business {
  margin: 0;
  font-size: 0.7rem;
  font-weight: 700;
  color: var(--trego-accent);
  text-transform: uppercase;
  letter-spacing: 0.09em;
}

.product-card-mobile-title {
  border: 0;
  background: transparent;
  padding: 0;
  text-align: left;
  font-size: 0.98rem;
  font-weight: 800;
  line-height: 1.2;
  color: var(--trego-dark);
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
  min-height: 2.35em;
}

.product-card-mobile-desc {
  margin: 0;
  color: var(--trego-muted);
  font-size: 0.8rem;
  line-height: 1.42;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
  min-height: 2.3em;
}

.product-card-mobile-variant {
  margin: -1px 0 0;
  color: var(--trego-accent);
  font-size: 0.72rem;
  font-weight: 700;
  line-height: 1.35;
}

.product-card-mobile-engagement {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 8px;
}

.product-card-mobile-engagement-item {
  display: grid;
  gap: 3px;
  padding: 8px 10px;
  border-radius: 16px;
  border: 1px solid var(--trego-input-border);
  background: var(--trego-interactive-bg);
}

.product-card-mobile-engagement-item small {
  color: var(--trego-muted);
  font-size: 0.68rem;
  font-weight: 700;
  letter-spacing: 0.04em;
  text-transform: uppercase;
}

.product-card-mobile-engagement-item strong {
  color: var(--trego-dark);
  font-size: 0.92rem;
  line-height: 1;
}

.product-card-mobile-meta {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

.product-card-mobile-pricing {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.product-card-mobile-pricing strong {
  color: var(--trego-dark);
  font-size: 1.02rem;
  line-height: 1;
}

.product-card-mobile-compare {
  color: var(--trego-muted);
  font-size: 0.76rem;
  text-decoration: line-through;
}

.product-card-mobile-rating {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  flex-shrink: 0;
  color: var(--trego-muted);
  font-size: 0.78rem;
  padding: 6px 8px;
  border-radius: 999px;
  background: var(--trego-interactive-bg);
}

.product-card-mobile-actions {
  display: flex;
  margin-top: auto;
}

.product-card-mobile-add {
  width: 100%;
  min-height: 42px;
  margin: 0;
  font-size: 0.82rem;
  --box-shadow: 0 14px 28px rgba(255, 106, 43, 0.18);
}

.sr-only {
  position: absolute;
  width: 1px;
  height: 1px;
  padding: 0;
  margin: -1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  border: 0;
}
</style>
