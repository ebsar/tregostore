<script setup>
import { onMounted } from "vue";
import { useRouter } from "vue-router";
import HeaderAccountDropdown from "../components/HeaderAccountDropdown.vue";
import { ensureSessionLoaded, markRouteReady } from "../stores/app-state";

const router = useRouter();

onMounted(async () => {
  try {
    const user = await ensureSessionLoaded();
    if (user) {
      await router.replace("/llogaria");
      return;
    }
  } finally {
    markRouteReady();
  }
});
</script>

<template>
  <section class="auth-page" aria-label="Sign up page">
    <div class="auth-page-breadcrumb-strip">
      <div class="auth-page-breadcrumb-inner">
        <nav class="auth-page-breadcrumbs" aria-label="Breadcrumb">
          <RouterLink to="/">Home</RouterLink>
          <span>›</span>
          <span>User Account</span>
          <span>›</span>
          <strong>Sign Up</strong>
        </nav>
      </div>
    </div>

    <div class="auth-page-shell">
      <HeaderAccountDropdown standalone sync-route-tabs initial-mode="signup" />
    </div>
  </section>
</template>

<style scoped>
.auth-page {
  width: 100%;
}

.auth-page-breadcrumb-strip {
  width: 100%;
  background: #f4f6f8;
  border-bottom: 1px solid rgba(15, 23, 42, 0.06);
}

.auth-page-breadcrumb-inner {
  width: min(1280px, calc(100vw - 48px));
  margin: 0 auto;
  padding: 20px 0;
}

.auth-page-breadcrumbs {
  display: flex;
  align-items: center;
  gap: 12px;
  flex-wrap: wrap;
  color: #64748b;
  font-size: 1rem;
}

.auth-page-breadcrumbs a {
  color: inherit;
  text-decoration: none;
}

.auth-page-breadcrumbs strong {
  color: #2f9cf3;
  font-weight: 700;
}

.auth-page-shell {
  display: flex;
  justify-content: center;
  padding: clamp(52px, 9vw, 96px) 20px 96px;
}

@media (max-width: 720px) {
  .auth-page-breadcrumb-inner {
    width: min(100vw - 24px, 1280px);
    padding: 16px 0;
  }

  .auth-page-shell {
    padding: 28px 12px 56px;
  }
}
</style>
