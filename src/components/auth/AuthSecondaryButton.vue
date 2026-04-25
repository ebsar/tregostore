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
    default: "button",
  },
});
</script>

<template>
  <button class="auth-secondary-button" :type="type" :disabled="loading">
    <span v-if="loading">{{ loadingLabel }}</span>
    <slot v-else />
  </button>
</template>

<style scoped>
.auth-secondary-button {
  width: 100%;
  height: 44px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  border: 1px solid #dddddd;
  border-radius: 8px;
  background: #ffffff;
  color: #444444;
  font-size: 14px;
  font-weight: 600;
  line-height: 1;
  cursor: pointer;
  transition:
    border-color 160ms ease,
    background-color 160ms ease,
    color 160ms ease;
}

.auth-secondary-button:hover {
  border-color: #cfcfcf;
  background: #fafafa;
  color: #111111;
}

.auth-secondary-button:disabled {
  cursor: default;
  opacity: 0.72;
}

.auth-secondary-button:focus-visible {
  outline: 2px solid rgba(17, 17, 17, 0.12);
  outline-offset: 2px;
}
</style>
