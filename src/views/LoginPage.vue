<script setup>
import { onMounted, reactive } from "vue";
import { useRoute, useRouter } from "vue-router";
import AuthField from "../components/auth/AuthField.vue";
import AuthPrimaryButton from "../components/auth/AuthPrimaryButton.vue";
import AuthShell from "../components/auth/AuthShell.vue";
import { requestJson, resolveApiMessage } from "../lib/api";
import { persistLoginGreeting } from "../lib/shop";
import { applyAuthenticatedSession, ensureSessionLoaded, markRouteReady } from "../stores/app-state";

const router = useRouter();
const route = useRoute();
const form = reactive({
  email: "",
  password: "",
});
const ui = reactive({
  loading: false,
  message: "",
  type: "",
});

onMounted(async () => {
  try {
    const user = await ensureSessionLoaded();
    if (user) {
      await router.replace("/");
      return;
    }
  } finally {
    markRouteReady();
  }
});

async function submitForm() {
  ui.loading = true;
  ui.message = "";
  ui.type = "";

  try {
    const { response, data } = await requestJson("/api/login", {
      method: "POST",
      body: JSON.stringify({
        identifier: form.email.trim(),
        password: form.password,
      }),
    });

    if (!response.ok || !data?.ok) {
      ui.message = resolveApiMessage(data, "We couldn't sign you in.");
      ui.type = "error";
      if (data?.redirectTo) {
        await router.push(data.redirectTo);
      }
      return;
    }

    ui.message = data.message || "Signed in successfully.";
    ui.type = "success";
    persistLoginGreeting(data.user?.firstName || data.user?.fullName || "User");
    await applyAuthenticatedSession(data.user || null);

    const redirectPath = String(route.query.redirect || "").trim();
    await router.push(redirectPath || data.redirectTo || "/");
  } catch (error) {
    ui.message = "The server is not responding. Please try again.";
    ui.type = "error";
    console.error(error);
  } finally {
    ui.loading = false;
  }
}

function handleSocialLogin(provider) {
  ui.message = `${provider} sign in will be connected when OAuth credentials are configured.`;
  ui.type = "success";
}
</script>

<template>
  <AuthShell
    title="Sign in to your account"
    :show-brand="false"
    :message="ui.message"
    :message-type="ui.type"
  >
    <form class="auth-form" @submit.prevent="submitForm">
      <AuthField
        id="login-email"
        v-model="form.email"
        label="Email"
        name="email"
        type="email"
        autocomplete="email"
        inputmode="email"
        required
      />

      <AuthField
        id="login-password"
        v-model="form.password"
        label="Password"
        name="password"
        type="password"
        autocomplete="current-password"
        required
      >
        <template #label-action>
          <RouterLink class="auth-link" to="/forgot-password">
            Forgot password?
          </RouterLink>
        </template>
      </AuthField>

      <AuthPrimaryButton :loading="ui.loading" loading-label="Signing in...">
        Sign in
      </AuthPrimaryButton>
    </form>

    <div class="auth-social-options" aria-label="Continue with social account">
      <button type="button" aria-label="Continue with Google account" @click="handleSocialLogin('Google')">
        <span>G</span>
        <strong>Google</strong>
      </button>
      <button type="button" aria-label="Continue with Apple account" @click="handleSocialLogin('Apple')">
        <span>A</span>
        <strong>Apple</strong>
      </button>
      <button type="button" aria-label="Continue with Facebook account" @click="handleSocialLogin('Facebook')">
        <span>f</span>
        <strong>Facebook</strong>
      </button>
    </div>

    <template #footer>
      <p class="auth-helper">
        Not a member?
        <RouterLink class="auth-link" to="/signup">
          Create an account
        </RouterLink>
      </p>
    </template>
  </AuthShell>
</template>

<style scoped>
.auth-social-options {
  display: flex;
  justify-content: center;
  gap: 14px;
}

.auth-social-options button {
  min-width: 78px;
  display: grid;
  justify-items: center;
  gap: 7px;
  border: 0;
  background: transparent;
  color: var(--color-muted);
  font: inherit;
  cursor: pointer;
}

.auth-social-options span {
  width: 46px;
  height: 46px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  border: 1px solid var(--color-border);
  border-radius: 999px;
  background: #ffffff;
  color: #111111;
  font-size: 17px;
  font-weight: 800;
  transition:
    border-color 160ms ease,
    background-color 160ms ease,
    color 160ms ease,
    transform 160ms ease;
}

.auth-social-options strong {
  color: var(--color-muted);
  font-size: 11px;
  font-weight: 700;
  line-height: 1;
}

.auth-social-options button:hover span,
.auth-social-options button:focus-visible span {
  border-color: var(--color-primary-border);
  background: var(--color-primary-soft);
  color: var(--color-primary);
  transform: translateY(-1px);
}
</style>
