<script setup>
import { computed } from "vue";

const props = defineProps({
  visible: {
    type: Boolean,
    default: false,
  },
});

defineEmits(["toggle"]);

const label = computed(() => (props.visible ? "Hide password" : "Show password"));
</script>

<template>
  <button
    type="button"
    class="market-icon-button password-toggle-button"
    :aria-label="label"
    @click="$emit('toggle')"
  >
    <svg v-if="!visible" viewBox="0 0 24 24" aria-hidden="true">
      <path d="M2 12s3.6-6 10-6 10 6 10 6-3.6 6-10 6-10-6-10-6Z" />
      <path d="M12 15.2A3.2 3.2 0 1 0 12 8.8a3.2 3.2 0 0 0 0 6.4Z" />
    </svg>

    <svg v-else viewBox="0 0 24 24" aria-hidden="true">
      <path d="M3 4.5 20.5 19.5" />
      <path d="M9.4 9.7A3.1 3.1 0 0 0 8.8 12a3.2 3.2 0 0 0 5.5 2.2" />
      <path d="M6.7 7.1C4.2 8.7 2.7 11.1 2 12c1.2 1.9 4.4 6 10 6 1.9 0 3.5-.5 4.9-1.2" />
      <path d="M10.9 6.1A9.7 9.7 0 0 1 12 6c5.6 0 8.8 4.1 10 6-.5.8-1.6 2.3-3.4 3.8" />
    </svg>
  </button>
</template>

<style scoped>
.password-toggle-button {
  flex-shrink: 0;
}
</style>
