<script setup>
import { onMounted, reactive, ref } from "vue";
import { RouterLink } from "vue-router";
import { useRoute, useRouter } from "vue-router";
import AuthField from "../components/auth/AuthField.vue";
import AuthPrimaryButton from "../components/auth/AuthPrimaryButton.vue";
import AuthSecondaryButton from "../components/auth/AuthSecondaryButton.vue";
import AuthShell from "../components/auth/AuthShell.vue";
import { requestJson, resolveApiMessage } from "../lib/api";
import { markRouteReady } from "../stores/app-state";

const route = useRoute();
const router = useRouter();
const form = reactive({
  email: "",
  code: "",
});
const ui = reactive({
  loading: false,
  resendLoading: false,
  message: "",
  type: "",
});
const showSuccessDialog = ref(false);
const successRedirectUrl = ref("/login");

onMounted(() => {
  form.email = String(route.query.email || "").trim();
  markRouteReady();
});

function goToSuccessRedirect() {
  router.push(successRedirectUrl.value || "/login");
}

async function submitForm() {
  ui.loading = true;
  ui.message = "";
  ui.type = "";

  try {
    const { response, data } = await requestJson("/api/email/verify", {
      method: "POST",
      body: JSON.stringify({
        email: form.email.trim(),
        code: form.code.trim(),
      }),
    });

    if (!response.ok || !data?.ok) {
      ui.message = resolveApiMessage(data, "Verifikimi i email-it nuk funksionoi.");
      ui.type = "error";
      return;
    }

    ui.message = data.message || "Email-i u verifikua me sukses.";
    ui.type = "success";
    form.code = "";
    successRedirectUrl.value = data.redirectTo || "/login";
    showSuccessDialog.value = true;
  } catch (error) {
    ui.message = "Serveri nuk po pergjigjet. Provoje perseri.";
    ui.type = "error";
    console.error(error);
  } finally {
    ui.loading = false;
  }
}

async function resendCode() {
  ui.resendLoading = true;
  ui.message = "";
  ui.type = "";

  try {
    const { response, data } = await requestJson("/api/email/resend", {
      method: "POST",
      body: JSON.stringify({ email: form.email.trim() }),
    });

    if (!response.ok || !data?.ok) {
      ui.message = resolveApiMessage(data, "Kodi nuk u dergua perseri.");
      ui.type = "error";
      return;
    }

    ui.message = data.message || "Kodi i verifikimit u dergua perseri.";
    ui.type = "success";
    if (data.redirectTo) {
      router.replace(data.redirectTo);
    }
  } catch (error) {
    ui.message = "Serveri nuk po pergjigjet. Provoje perseri.";
    ui.type = "error";
    console.error(error);
  } finally {
    ui.resendLoading = false;
  }
}
</script>

<template>
  <AuthShell
    title="Verify your email"
    description="Enter the 6 digit code we sent to your inbox. Codes stay valid for 30 minutes and older codes expire when a new one is requested."
    :message="ui.message"
    :message-type="ui.type"
  >
    <form class="auth-form" @submit.prevent="submitForm">
      <AuthField
        id="verify-email"
        v-model="form.email"
        label="Email"
        name="email"
        type="email"
        placeholder="name@email.com"
        required
      />

      <AuthField
        id="verify-code"
        v-model="form.code"
        label="Verification code"
        name="code"
        type="text"
        inputmode="numeric"
        maxlength="6"
        placeholder="123456"
        required
      />

      <div class="auth-inline-actions">
        <AuthPrimaryButton :loading="ui.loading" loading-label="Verifying...">
          Verify email
        </AuthPrimaryButton>

        <AuthSecondaryButton
          :loading="ui.resendLoading"
          loading-label="Sending..."
          @click="resendCode"
        >
          Resend code
        </AuthSecondaryButton>
      </div>
    </form>

    <template #footer>
      <p class="auth-helper">
        Already have the code and want to sign in?
        <RouterLink class="auth-link" to="/login">
          Continue to sign in
        </RouterLink>
      </p>
    </template>
  </AuthShell>

  <div
    v-if="showSuccessDialog"
    class="verify-email-overlay"
    role="presentation"
  >
    <div
      class="verify-email-success"
      role="dialog"
      aria-modal="true"
      aria-labelledby="verify-email-success-title"
    >
      <div class="verify-email-success__mark" aria-hidden="true">✓</div>
      <p>Email verified</p>
      <h2 id="verify-email-success-title">Your account is ready</h2>
      <p>Your email has been confirmed successfully. Continue to sign in and start using the marketplace.</p>
      <div class="verify-email-success__actions">
        <AuthPrimaryButton type="button" @click="goToSuccessRedirect">
          Continue to sign in
        </AuthPrimaryButton>
      </div>
    </div>
  </div>
</template>

<style scoped>
.verify-email-overlay {
  position: fixed;
  inset: 0;
  z-index: 80;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 16px;
  background: rgba(17, 17, 17, 0.18);
  backdrop-filter: blur(4px);
}
</style>
