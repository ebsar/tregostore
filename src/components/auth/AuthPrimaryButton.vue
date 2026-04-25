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
  height: 44px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  border: 0;
  border-radius: 8px;
  background: linear-gradient(180deg, #fb923c 0%, #f97316 100%);
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
  outline: 2px solid rgba(249, 115, 22, 0.22);
  outline-offset: 2px;
}
</style>
