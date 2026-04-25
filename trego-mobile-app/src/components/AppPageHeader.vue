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
  <section>
    <div>
      <AppBackButton :back-to="backTo" />
    </div>
    <header>
      <p v-if="kicker">{{ kicker }}</p>
      <h1>{{ title }}</h1>
      <p v-if="subtitle">{{ subtitle }}</p>
    </header>
  </section>
</template>

