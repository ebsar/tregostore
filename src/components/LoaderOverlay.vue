<template>
  <div class="loader-overlay" aria-hidden="true">
    <div class="loader-overlay__spinner"></div>
  </div>
</template>

<style scoped>
.loader-overlay {
  position: fixed;
  inset: 0;
  z-index: 9999;
  display: flex;
  align-items: center;
  justify-content: center;
  background: #ffffff;
}

.loader-overlay__spinner {
  width: 42px;
  height: 42px;
  border: 3px solid #e9e9e9;
  border-top-color: #f36a20;
  border-radius: 50%;
  animation: loader-spin 0.8s linear infinite;
}

@keyframes loader-spin {
  to {
    transform: rotate(360deg);
  }
}
</style>
