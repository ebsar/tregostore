<script setup>
import { onBeforeUnmount, reactive } from "vue";
import { useRouter } from "vue-router";
import AuthField from "../components/auth/AuthField.vue";
import AuthPrimaryButton from "../components/auth/AuthPrimaryButton.vue";
import AuthShell from "../components/auth/AuthShell.vue";
import { requestJson, resolveApiMessage } from "../lib/api";
import { markRouteReady } from "../stores/app-state";

const router = useRouter();
const form = reactive({
  email: "",
});
const ui = reactive({
  loading: false,
  message: "",
  type: "",
});
let redirectTimeoutId = 0;

markRouteReady();

onBeforeUnmount(() => {
  if (redirectTimeoutId) {
    window.clearTimeout(redirectTimeoutId);
    redirectTimeoutId = 0;
  }
});

async function submitForm() {
  if (redirectTimeoutId) {
    window.clearTimeout(redirectTimeoutId);
    redirectTimeoutId = 0;
  }

  ui.loading = true;
  ui.message = "";
  ui.type = "";

  try {
    const { response, data } = await requestJson("/api/forgot-password", {
      method: "POST",
      body: JSON.stringify({ email: form.email.trim() }),
    });

    if (!response.ok || !data?.ok) {
      ui.message = resolveApiMessage(data, "Kerkesa nuk u dergua.");
      ui.type = "error";
      return;
    }

    ui.message = data.message || "Kodi u dergua me sukses.";
    ui.type = "success";
    if (data.redirectTo) {
      redirectTimeoutId = window.setTimeout(() => {
        router.push(data.redirectTo);
        redirectTimeoutId = 0;
      }, 900);
    }
  } catch (error) {
    ui.message = "Serveri nuk po pergjigjet. Provoje perseri.";
    ui.type = "error";
    console.error(error);
  } finally {
    ui.loading = false;
  }
}
</script>

<template>
  <AuthShell
    title="Forgot your password?"
    description="Enter your email and we'll send you a reset link."
    :message="ui.message"
    :message-type="ui.type"
  >
    <form class="auth-form" @submit.prevent="submitForm">
      <AuthField
        id="forgot-email"
        v-model="form.email"
        label="Email"
        name="email"
        type="email"
        autocomplete="email"
        inputmode="email"
        required
      />

      <AuthPrimaryButton :loading="ui.loading" loading-label="Sending reset link...">
        Send reset link
      </AuthPrimaryButton>
    </form>

    <template #footer>
      <p class="auth-helper">
        <RouterLink class="auth-link" to="/login">
          Back to sign in
        </RouterLink>
      </p>
    </template>
  </AuthShell>
</template>
