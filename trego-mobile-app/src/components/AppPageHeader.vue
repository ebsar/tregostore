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
  <section class="trego-page-header">
    <div class="trego-page-header__back">
      <AppBackButton :back-to="backTo" />
    </div>
    <header class="trego-page-header__body">
      <p v-if="kicker" class="trego-page-header__kicker">{{ kicker }}</p>
      <h1>{{ title }}</h1>
      <p v-if="subtitle">{{ subtitle }}</p>
    </header>
  </section>
</template>
