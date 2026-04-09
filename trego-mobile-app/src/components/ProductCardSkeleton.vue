<script setup lang="ts">
withDefaults(defineProps<{
  compact?: boolean;
}>(), {
  compact: false,
});
</script>

<template>
  <article class="product-card-skeleton surface-card" :class="{ 'is-compact': compact }">
    <div class="product-card-skeleton-media mobile-shimmer" />
    <div class="product-card-skeleton-copy">
      <span class="product-card-skeleton-line short mobile-shimmer" />
      <span class="product-card-skeleton-line medium mobile-shimmer" />
      <span class="product-card-skeleton-line medium mobile-shimmer" />
      <span class="product-card-skeleton-line short mobile-shimmer" />
    </div>
  </article>
</template>

<style scoped>
.product-card-skeleton {
  display: grid;
  grid-template-rows: auto 1fr;
  gap: 10px;
  min-height: 286px;
  padding: 9px;
  border-radius: 24px;
}

.product-card-skeleton.is-compact {
  min-height: 252px;
}

.product-card-skeleton-media {
  aspect-ratio: 0.96;
  border-radius: 18px;
}

.product-card-skeleton-copy {
  display: grid;
  gap: 8px;
  align-content: start;
}

.product-card-skeleton-line {
  display: block;
  height: 12px;
  border-radius: 999px;
}

.product-card-skeleton-line.short {
  width: 42%;
}

.product-card-skeleton-line.medium {
  width: 78%;
}
</style>
