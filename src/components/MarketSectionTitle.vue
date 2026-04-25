<script setup>
import { RouterLink } from "vue-router";

defineProps({
  eyebrow: {
    type: String,
    default: "",
  },
  title: {
    type: String,
    required: true,
  },
  copy: {
    type: String,
    default: "",
  },
  actionLabel: {
    type: String,
    default: "",
  },
  actionTo: {
    type: String,
    default: "",
  },
});
</script>

<template>
  <header class="section-heading">
    <div class="section-heading__copy-wrap">
      <p v-if="eyebrow" class="section-heading__eyebrow">
        {{ eyebrow }}
      </p>
      <h2>
        {{ title }}
      </h2>
      <p v-if="copy" class="section-heading__copy">
        {{ copy }}
      </p>
    </div>

    <RouterLink
      v-if="actionLabel && actionTo"
      :to="actionTo"
      class="market-button market-button--secondary section-heading__action"
    >
      {{ actionLabel }}
    </RouterLink>
  </header>
</template>
