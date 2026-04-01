<script setup lang="ts">
defineProps<{
  title: string;
  copy: string;
}>();
</script>

<template>
  <section class="surface-card empty-panel">
    <h3>{{ title }}</h3>
    <p>{{ copy }}</p>
    <slot />
  </section>
</template>
