<script setup lang="ts">
import ProductCardSkeleton from "./ProductCardSkeleton.vue";

withDefaults(defineProps<{
  title?: string;
}>(), {
  title: "Loading",
});
</script>

<template>
  <article>
    <div>
      <div>
        <span>{{ title }}</span>
        <span />
      </div>
      <span />
    </div>

    <div>
      <ProductCardSkeleton v-for="index in 3" :key="index" compact />
    </div>
  </article>
</template>

