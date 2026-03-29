<script setup>
import { onBeforeUnmount, reactive } from "vue";
import { useRouter } from "vue-router";
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
  <section class="card auth-card">
    <p class="section-label">Forgot Password</p>
    <h1>Me dergo kodin per ndryshim te fjalekalimit</h1>
    <p class="section-text">
      Shkruaje email-in e llogarise. Kjo faqe sherben si hapi i pare per dergimin e kodit te ndryshimit te fjalekalimit.
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

      <button id="forgot-password-submit-button" type="submit" :disabled="ui.loading">
        {{ ui.loading ? "Duke derguar..." : "Me dergo kodin per ndryshim te fjalekalimit" }}
      </button>
    </form>

    <div class="form-message" :class="ui.type" role="status" aria-live="polite">
      {{ ui.message }}
    </div>
    <p class="form-footer">
      U kujtove per fjalekalimin?
      <RouterLink class="inline-link" to="/login">Kthehu te Login</RouterLink>
    </p>
  </section>
</template>
