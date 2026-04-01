<script setup lang="ts">
import AppBackButton from "./AppBackButton.vue";

const props = withDefaults(defineProps<{
  kicker?: string;
  title: string;
  subtitle?: string;
  backTo?: string;
}>(), {
  backTo: "/tabs/home",
});

</script>

<template>
  <section class="page-hero-stack">
    <AppBackButton :back-to="backTo" />
    <header class="page-hero surface-card surface-card--strong">
      <p v-if="kicker" class="section-kicker">{{ kicker }}</p>
      <h1>{{ title }}</h1>
      <p v-if="subtitle">{{ subtitle }}</p>
    </header>
  </section>
</template>

<style scoped>
.page-hero-stack {
  display: grid;
  gap: 10px;
}
</style>
