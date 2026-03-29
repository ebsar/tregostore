<script setup>
import { computed, onMounted, reactive } from "vue";
import { useRoute, useRouter } from "vue-router";
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

const labelText = computed(() => (resetMode.value ? "Rikthimi i qasjes" : "Siguria"));
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
  <section class="account-page change-password-page" aria-label="Ndryshimi i fjalekalimit">
    <section class="card account-section change-password-card">
      <p class="section-label">{{ labelText }}</p>
      <h3>{{ titleText }}</h3>
      <p class="section-text">{{ leadText }}</p>

      <form class="auth-form" @submit.prevent="submitForm">
        <label v-if="resetMode" class="field">
          <span>Email</span>
          <input
            v-model="form.email"
            name="email"
            type="email"
            placeholder="p.sh. emri@email.com"
            autocomplete="email"
            required
          >
        </label>

        <label v-if="resetMode" class="field">
          <span>Kodi i ndryshimit</span>
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

        <label v-if="!resetMode" class="field">
          <span>Fjalekalimi aktual</span>
          <input
            v-model="form.currentPassword"
            name="currentPassword"
            type="password"
            placeholder="Shkruaje fjalekalimin aktual"
            required
          >
        </label>

        <label class="field">
          <span>Fjalekalimi i ri</span>
          <input
            v-model="form.newPassword"
            name="newPassword"
            type="password"
            placeholder="Shkruaje fjalekalimin e ri"
            autocomplete="new-password"
            required
          >
        </label>

        <label class="field">
          <span>Konfirmo fjalekalimin e ri</span>
          <input
            v-model="form.confirmPassword"
            name="confirmPassword"
            type="password"
            placeholder="Perserite fjalekalimin e ri"
            autocomplete="new-password"
            required
          >
        </label>

        <div class="auth-form-actions">
          <button id="change-password-submit" type="submit" :disabled="ui.loading">
            {{ ui.loading ? (resetMode ? "Duke verifikuar kodin..." : "Duke ruajtur...") : (resetMode ? "Ndryshoje fjalekalimin" : "Ruaje fjalekalimin e ri") }}
          </button>

          <button
            v-if="resetMode"
            id="change-password-resend-button"
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
    </section>
  </section>
</template>
