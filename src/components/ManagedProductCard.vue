<script setup>
import { computed, onBeforeUnmount, onMounted, ref } from "vue";
import { RouterLink, useRoute } from "vue-router";
import {
  formatCategoryLabel,
  formatCount,
  formatPrice,
  formatProductColorLabel,
  formatProductTypeLabel,
  formatStockQuantity,
  getProductDetailUrl,
} from "../lib/shop";

const props = defineProps({
  product: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits([
  "edit",
  "delete",
  "toggle-visibility",
  "toggle-stock-public",
]);
const route = useRoute();
const cardRef = ref(null);
const actionsOpen = ref(false);
const detailUrl = computed(() => getProductDetailUrl(props.product.id, route.fullPath));

const visibilityLabel = computed(() =>
  props.product.isPublic ? "Mshehe nga userat" : "Shfaqe per userat",
);

const stockLabel = computed(() =>
  props.product.showStockPublic && Number(props.product.stockQuantity) > 0
    ? "Fshehe stokun"
    : "Shfaqe si ne stok",
);
const stockStateLabel = computed(() => {
  const stockQuantity = Number(props.product.stockQuantity || 0);
  if (stockQuantity <= 0) {
    return "Stok i mbaruar";
  }

  if (stockQuantity <= 5) {
    return `Stok i ulet • ${formatStockQuantity(stockQuantity)}`;
  }

  return `Stok • ${formatStockQuantity(stockQuantity)}`;
});
const stockStateClass = computed(() => {
  const stockQuantity = Number(props.product.stockQuantity || 0);
  if (stockQuantity <= 0) {
    return "is-out-of-stock";
  }

  if (stockQuantity <= 5) {
    return "is-low-stock";
  }

  return "";
});

const details = computed(() =>
  [
    formatProductTypeLabel(props.product.productType),
    props.product.size ? `Madhesia ${props.product.size}` : "",
    props.product.color ? `Ngjyra ${formatProductColorLabel(props.product.color)}` : "",
    `Stok ${formatStockQuantity(props.product.stockQuantity)}`,
    props.product.isPublic ? "Publik" : "I fshehur",
    props.product.showStockPublic && Number(props.product.stockQuantity) > 0
      ? "Stoku duket publikisht"
      : "Stoku eshte privat",
  ].filter(Boolean),
);

const engagementItems = computed(() => ([
  { label: "Views", value: formatCount(props.product.viewsCount || 0) },
  { label: "Wishlist", value: formatCount(props.product.wishlistCount || 0) },
  { label: "Cart", value: formatCount(props.product.cartCount || 0) },
  { label: "Share", value: formatCount(props.product.shareCount || 0) },
]));

onMounted(() => {
  if (typeof window !== "undefined") {
    window.addEventListener("pointerdown", handlePointerDownOutside);
  }
});

onBeforeUnmount(() => {
  if (typeof window !== "undefined") {
    window.removeEventListener("pointerdown", handlePointerDownOutside);
  }
});

function handlePointerDownOutside(event) {
  if (!actionsOpen.value) {
    return;
  }

  if (cardRef.value?.contains?.(event.target)) {
    return;
  }

  actionsOpen.value = false;
}

function toggleActions() {
  actionsOpen.value = !actionsOpen.value;
}

function handleEdit() {
  actionsOpen.value = false;
  emit("edit", props.product);
}

function handleToggleVisibility() {
  actionsOpen.value = false;
  emit("toggle-visibility", props.product);
}

function handleToggleStockPublic() {
  actionsOpen.value = false;
  emit("toggle-stock-public", props.product);
}

function handleDelete() {
  actionsOpen.value = false;
  emit("delete", props.product);
}
</script>

<template>
  <article ref="cardRef" class="managed-product-card" :class="{ 'is-actions-open': actionsOpen }">
    <RouterLink :to="detailUrl">
      <div class="managed-product-card__media">
        <img
          :src="product.imagePath"
          :alt="product.title"
          width="640"
          height="640"
          loading="lazy"
          decoding="async"
        >
      </div>
    </RouterLink>

    <div class="managed-product-card__body">
      <div class="managed-product-card__top">
        <div>
          <p class="managed-product-card__eyebrow">{{ formatCategoryLabel(product.category) }}</p>
          <p v-if="product.articleNumber" class="managed-product-card__eyebrow">Nr. {{ product.articleNumber }}</p>
        </div>
        <div class="managed-product-card__top-actions">
          <strong>{{ formatPrice(product.price) }}</strong>
          <button
            type="button"
            class="managed-product-card__menu-toggle"
            :aria-expanded="actionsOpen ? 'true' : 'false'"
            aria-label="Open product actions"
            @click.stop="toggleActions"
          >
            {{ actionsOpen ? "−" : "+" }}
          </button>
        </div>
      </div>
      <h3>
        <RouterLink :to="detailUrl">
          {{ product.title }}
        </RouterLink>
      </h3>
      <p class="managed-product-card__stock">
        {{ stockStateLabel }}
      </p>
      <p class="managed-product-card__description">{{ product.description }}</p>
      <div class="managed-product-card__metrics" aria-label="Statistikat e produktit">
        <span
          v-for="item in engagementItems"
          :key="`${product.id}-${item.label}`"
          class="managed-product-card__metric"
        >
          <small>{{ item.label }}</small>
          <strong>{{ item.value }}</strong>
        </span>
      </div>
      <div class="managed-product-card__details">
        <span
          v-for="detail in details"
          :key="detail"
        >
          {{ detail }}
        </span>
      </div>
    </div>

    <div v-if="actionsOpen" class="managed-product-card__actions">
      <button class="market-button market-button--primary" type="button" @click="handleEdit">
        <span>Edit product</span>
      </button>

      <button class="market-button market-button--secondary" type="button" @click="handleToggleVisibility">
        <span>{{ visibilityLabel }}</span>
      </button>

      <button class="market-button market-button--ghost" type="button" @click="handleToggleStockPublic">
        <span>{{ stockLabel }}</span>
      </button>

      <button class="market-button market-button--ghost" type="button" @click="handleDelete">
        <span>Delete product</span>
      </button>
    </div>
  </article>
</template>
