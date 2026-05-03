<script setup>
import { RouterLink } from "vue-router";
import CommerceHeader from "../CommerceHeader.vue";
import SiteFooter from "../SiteFooter.vue";

defineProps({
  title: {
    type: String,
    required: true,
  },
  showBrand: {
    type: Boolean,
    default: true,
  },
  description: {
    type: String,
    default: "",
  },
  message: {
    type: String,
    default: "",
  },
  messageType: {
    type: String,
    default: "",
  },
});
</script>

<template>
  <div class="auth-shell-page">
    <CommerceHeader />

    <main class="auth-shell-page__content">
      <section class="auth-shell">
        <div class="auth-shell__inner">
          <RouterLink v-if="showBrand" class="auth-shell__brand" to="/" aria-label="TREGIO home">
            <img
              class="auth-shell__brand-icon"
              src="/trego-logo.png"
              alt="TREGIO"
              width="1024"
              height="1024"
            >
          </RouterLink>

          <header class="auth-shell__header">
            <h1>{{ title }}</h1>
            <p v-if="description">{{ description }}</p>
          </header>

          <p
            v-if="message"
            class="auth-shell__status"
            :class="{
              'auth-shell__status--error': messageType === 'error',
              'auth-shell__status--success': messageType === 'success',
            }"
            role="status"
            aria-live="polite"
          >
            {{ message }}
          </p>

          <slot />

          <div class="auth-shell__footer">
            <slot name="footer" />
          </div>
        </div>
      </section>
    </main>

    <SiteFooter />
  </div>
</template>

<style scoped>
:global(html, body, #app) {
  min-height: 100%;
}

:global(body) {
  margin: 0;
  background: var(--color-bg);
  color: var(--color-text);
  font-family: "Inter", "Segoe UI", "Helvetica Neue", Arial, sans-serif;
}

:global(*) {
  box-sizing: border-box;
}

.auth-shell-page {
  min-height: 100svh;
  display: flex;
  flex-direction: column;
  background: var(--color-bg);
}

.auth-shell-page__content {
  flex: 1 1 auto;
  display: flex;
}

.auth-shell {
  width: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: var(--space-12) var(--space-4);
  background: var(--color-bg);
}

.auth-shell__inner {
  width: min(100%, 408px);
  display: grid;
  gap: 20px;
}

.auth-shell__brand {
  display: inline-flex;
  align-items: center;
  justify-self: center;
  text-decoration: none;
}

.auth-shell__brand-icon {
  width: 54px;
  height: 54px;
  display: block;
  object-fit: contain;
}

.auth-shell__header {
  display: grid;
  gap: 8px;
  text-align: center;
}

.auth-shell__header h1 {
  margin: 0;
  color: var(--color-text);
  font-size: 24px;
  font-weight: 600;
  line-height: 1.25;
  letter-spacing: -0.02em;
}

.auth-shell__header p {
  margin: 0;
  color: var(--color-muted);
  font-size: 14px;
  line-height: 1.5;
}

.auth-shell__status {
  margin: 0;
  padding: 10px 12px;
  border: 1px solid var(--color-border);
  border-radius: var(--radius-control);
  background: #ffffff;
  color: var(--color-muted);
  font-size: 13px;
  line-height: 1.5;
  text-align: center;
}

.auth-shell__status--error {
  border-color: rgba(255, 59, 48, 0.25);
  background: #fff8f8;
  color: var(--color-error);
}

.auth-shell__status--success {
  border-color: #d8ded8;
  background: #fbfcfb;
  color: #3f5b45;
}

.auth-shell__footer {
  display: grid;
  gap: 8px;
}

.auth-shell :deep(.auth-form) {
  display: grid;
  gap: 16px;
}

.auth-shell :deep(.auth-helper) {
  margin: 0;
  text-align: center;
  color: var(--color-muted);
  font-size: 13px;
  line-height: 1.5;
}

.auth-shell :deep(.auth-link) {
  color: var(--color-muted);
  text-decoration: none;
  transition: color 160ms ease;
}

.auth-shell :deep(.auth-link:hover) {
  color: var(--color-primary);
}

.auth-shell :deep(.auth-link:focus-visible) {
  outline: 2px solid rgba(17, 17, 17, 0.18);
  outline-offset: 2px;
  border-radius: 4px;
}

@media (max-width: 640px) {
  .auth-shell {
    padding: 28px 16px;
  }

  .auth-shell__inner {
    width: 100%;
    gap: 18px;
  }

  .auth-shell__header h1 {
    font-size: 22px;
  }
}
</style>
