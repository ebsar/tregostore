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
  <section class="page-shell-with-back page-hero-stack">
    <div class="page-back-anchor">
      <AppBackButton :back-to="backTo" />
    </div>
    <header class="page-hero surface-card surface-card--strong">
      <p v-if="kicker" class="section-kicker">{{ kicker }}</p>
      <h1>{{ title }}</h1>
      <p v-if="subtitle">{{ subtitle }}</p>
    </header>
  </section>
</template>

<style scoped>
.page-hero-stack {
  gap: 10px;
}
</style>
