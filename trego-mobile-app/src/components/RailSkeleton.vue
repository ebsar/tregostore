<script setup lang="ts">
import ProductCardSkeleton from "./ProductCardSkeleton.vue";

withDefaults(defineProps<{
  title?: string;
}>(), {
  title: "Loading",
});
</script>

<template>
  <article class="surface-card rail-skeleton-shell">
    <div class="rail-skeleton-head">
      <div class="rail-skeleton-copy">
        <span class="rail-skeleton-kicker">{{ title }}</span>
        <span class="rail-skeleton-title mobile-shimmer" />
      </div>
      <span class="rail-skeleton-link mobile-shimmer" />
    </div>

    <div class="rail-skeleton-track">
      <ProductCardSkeleton v-for="index in 3" :key="index" compact />
    </div>
  </article>
</template>

<style scoped>
.rail-skeleton-shell {
  display: grid;
  gap: 12px;
  padding: 12px;
}

.rail-skeleton-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

.rail-skeleton-copy {
  display: grid;
  gap: 6px;
}

.rail-skeleton-kicker {
  color: rgba(37, 99, 235, 0.82);
  font-size: 0.76rem;
  font-weight: 800;
}

.rail-skeleton-title,
.rail-skeleton-link {
  display: block;
  border-radius: 999px;
}

.rail-skeleton-title {
  width: 180px;
  height: 14px;
}

.rail-skeleton-link {
  width: 38px;
  height: 38px;
}

.rail-skeleton-track {
  display: grid;
  grid-auto-flow: column;
  grid-auto-columns: minmax(0, 172px);
  gap: 12px;
  overflow: hidden;
}
</style>
