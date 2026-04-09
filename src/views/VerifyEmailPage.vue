<script setup>
import { onMounted, reactive, ref } from "vue";
import { useRoute, useRouter } from "vue-router";
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
    document.body.classList.add("dialog-open");
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
  <section class="login-hero" aria-label="Verify email hero">
    <section class="card auth-card login-card verify-email-card">
      <p class="section-label">Verifiko emailin</p>
      <h1>Verifiko emailin</h1>
      <div class="verify-email-brand">
        <img src="/trego-logo.webp" alt="TREGIO logo" class="verify-email-logo" />
        <span>TREGIO</span>
      </div>
      <p class="section-text">
        Pasi e krijon llogarine, kodi 6-shifror vjen ne email. Kodi vlen 30 minuta. Nese skadon, kerkoje kodin e ri dhe kodi i vjeter nuk vlen me.
      </p>

      <form class="auth-form" @submit.prevent="submitForm">
        <label class="field">
          <span>Email</span>
          <input
            v-model="form.email"
            name="email"
            type="email"
            placeholder="p.sh. emri@email.com"
            required
          >
        </label>

        <label class="field">
          <span>Kodi i verifikimit</span>
          <input
            v-model="form.code"
            name="code"
            type="text"
            inputmode="numeric"
            maxlength="6"
            placeholder="p.sh. 123456"
            required
          >
        </label>

        <div class="auth-form-actions">
          <button id="verify-email-submit-button" type="submit" :disabled="ui.loading">
            {{ ui.loading ? "Duke verifikuar..." : "Verifiko emailin" }}
          </button>
          <button
            id="verify-email-resend-button"
            class="button-secondary"
            type="button"
            :disabled="ui.resendLoading"
            @click="resendCode"
          >
            {{ ui.resendLoading ? "Duke derguar..." : "Dergoje kodin perseri" }}
          </button>
        </div>
      </form>

      <div class="form-message" :class="ui.type" role="status" aria-live="polite">
        {{ ui.message }}
      </div>
      <p class="form-footer">
        E ke tashme kodin dhe do te kyçesh?
        <RouterLink class="inline-link" to="/login">Vazhdo te Login</RouterLink>
      </p>
    </section>
  </section>

  <div
    v-if="showSuccessDialog"
    id="verify-email-success-dialog"
    class="verify-email-dialog is-visible"
  >
    <div class="verify-email-dialog-backdrop"></div>
    <div
      class="verify-email-dialog-card"
      role="dialog"
      aria-modal="true"
      aria-labelledby="verify-email-success-title"
    >
      <div class="verify-email-dialog-icon" aria-hidden="true">✓</div>
      <p class="section-label">Verifikimi perfundoi</p>
      <h2 id="verify-email-success-title">Email-i u verifikua me sukses</h2>
      <p class="section-text verify-email-success-copy">
        Llogaria jote tani eshte aktive dhe e sigurt. Shtyp “Vazhdo te Login” për të hyrë në personalizimin e ofertave.
      </p>
      <button id="verify-email-success-continue" type="button" @click="goToSuccessRedirect">
        Vazhdo te Login
      </button>
    </div>
  </div>
</template>
