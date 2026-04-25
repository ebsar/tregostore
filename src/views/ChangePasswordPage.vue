<script setup>
import { computed, onMounted, reactive } from "vue";
import { RouterLink } from "vue-router";
import { useRoute, useRouter } from "vue-router";
import AuthField from "../components/auth/AuthField.vue";
import AuthPrimaryButton from "../components/auth/AuthPrimaryButton.vue";
import AuthSecondaryButton from "../components/auth/AuthSecondaryButton.vue";
import AuthShell from "../components/auth/AuthShell.vue";
import { requestJson, resolveApiMessage } from "../lib/api";
import { ensureSessionLoaded, markRouteReady } from "../stores/app-state";

const route = useRoute();
const router = useRouter();

const form = reactive({
  email: "",
  code: "",
  currentPassword: "",
  newPassword: "",
  confirmPassword: "",
});

const ui = reactive({
  loading: false,
  resendLoading: false,
  message: "",
  type: "",
});

const resetMode = computed(
  () => String(route.query.mode || "").trim().toLowerCase() === "reset",
);
const titleText = computed(() =>
  resetMode.value
    ? "Shkruaje kodin dhe fjalekalimin e ri"
    : "Ndrysho fjalekalimin",
);
const leadText = computed(() =>
  resetMode.value
    ? "Kodi 6-shifror vjen ne email. Pasi ta vendosesh kodin e sakte, mund ta ndryshosh fjalekalimin menjehere."
    : "Shkruaje fjalekalimin aktual dhe vendos nje te ri. Pas ruajtjes do te duhet te kyçesh perseri.",
);

onMounted(async () => {
  form.email = String(route.query.email || "").trim();
  if (!resetMode.value) {
    const user = await ensureSessionLoaded();
    if (!user) {
      router.replace("/login");
      return;
    }
  }
  markRouteReady();
});

async function submitForm() {
  ui.loading = true;
  ui.message = "";
  ui.type = "";

  const endpoint = resetMode.value ? "/api/password-reset/confirm" : "/api/change-password";
  const payload = resetMode.value
    ? {
        email: form.email.trim(),
        code: form.code.trim(),
        newPassword: form.newPassword,
        confirmPassword: form.confirmPassword,
      }
    : {
        currentPassword: form.currentPassword,
        newPassword: form.newPassword,
        confirmPassword: form.confirmPassword,
      };

  try {
    const { response, data } = await requestJson(endpoint, {
      method: "POST",
      body: JSON.stringify(payload),
    });

    if (!response.ok || !data?.ok) {
      ui.message = resolveApiMessage(data, "Ndryshimi i fjalekalimit nuk funksionoi.");
      ui.type = "error";
      return;
    }

    ui.message = data.message || "Fjalekalimi u ndryshua.";
    ui.type = "success";
    form.code = "";
    form.currentPassword = "";
    form.newPassword = "";
    form.confirmPassword = "";

    window.setTimeout(() => {
      router.push(data.redirectTo || "/login");
    }, 900);
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
    const { response, data } = await requestJson("/api/forgot-password", {
      method: "POST",
      body: JSON.stringify({ email: form.email.trim() }),
    });

    if (!response.ok || !data?.ok) {
      ui.message = resolveApiMessage(data, "Kodi i ri nuk u dergua.");
      ui.type = "error";
      return;
    }

    ui.message = data.message || "Kodi i ri u dergua me sukses.";
    ui.type = "success";
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
    :title="titleText"
    :description="leadText"
    :message="ui.message"
    :message-type="ui.type"
  >
    <form class="auth-form" @submit.prevent="submitForm">
      <AuthField
        v-if="resetMode"
        id="change-password-email"
        v-model="form.email"
        label="Email"
        name="email"
        type="email"
        autocomplete="email"
        placeholder="name@email.com"
        required
      />

      <AuthField
        v-if="resetMode"
        id="change-password-code"
        v-model="form.code"
        label="Reset code"
        name="code"
        type="text"
        inputmode="numeric"
        maxlength="6"
        placeholder="123456"
        required
      />

      <AuthField
        v-if="!resetMode"
        id="change-password-current"
        v-model="form.currentPassword"
        label="Current password"
        name="currentPassword"
        type="password"
        placeholder="Enter your current password"
        required
      />

      <AuthField
        id="change-password-new"
        v-model="form.newPassword"
        label="New password"
        name="newPassword"
        type="password"
        autocomplete="new-password"
        placeholder="Enter a new password"
        required
      />

      <AuthField
        id="change-password-confirm"
        v-model="form.confirmPassword"
        label="Confirm new password"
        name="confirmPassword"
        type="password"
        autocomplete="new-password"
        placeholder="Repeat the new password"
        required
      />

      <div class="auth-inline-actions">
        <AuthPrimaryButton
          :loading="ui.loading"
          :loading-label="resetMode ? 'Verifying code...' : 'Saving password...'"
        >
          {{ resetMode ? "Change password" : "Save new password" }}
        </AuthPrimaryButton>

        <AuthSecondaryButton
          v-if="resetMode"
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
        <RouterLink class="auth-link" :to="resetMode ? '/login' : '/te-dhenat-personale'">
          {{ resetMode ? "Back to sign in" : "Back to settings" }}
        </RouterLink>
      </p>
    </template>
  </AuthShell>
</template>
