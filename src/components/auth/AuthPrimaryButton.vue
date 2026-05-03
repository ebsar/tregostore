<script setup>
defineProps({
  loading: {
    type: Boolean,
    default: false,
  },
  loadingLabel: {
    type: String,
    default: "Loading...",
  },
  type: {
    type: String,
    default: "submit",
  },
});
</script>

<template>
  <button class="auth-primary-button" :type="type" :disabled="loading">
    <span v-if="loading">{{ loadingLabel }}</span>
    <slot v-else />
  </button>
</template>

<style scoped>
.auth-primary-button {
  width: 100%;
  min-height: var(--touch-target);
  height: var(--touch-target);
  display: inline-flex;
  align-items: center;
  justify-content: center;
  border: 0;
  border-radius: var(--radius-control);
  background: linear-gradient(180deg, var(--color-primary) 0%, var(--color-primary-hover) 100%);
  color: #ffffff;
  font-size: 14px;
  font-weight: 600;
  line-height: 1;
  cursor: pointer;
  transition:
    filter 160ms ease,
    transform 160ms ease;
}

.auth-primary-button:hover {
  filter: brightness(1.04);
}

.auth-primary-button:disabled {
  cursor: default;
  opacity: 0.76;
  filter: none;
}

.auth-primary-button:focus-visible {
  outline: 2px solid rgba(255, 106, 0, 0.22);
  outline-offset: 2px;
}
</style>
