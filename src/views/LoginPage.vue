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
