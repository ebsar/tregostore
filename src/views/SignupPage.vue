<script setup>
import { reactive } from "vue";
import { useRouter } from "vue-router";
import { requestJson, resolveApiMessage } from "../lib/api";
import { getVerifyEmailUrl } from "../lib/shop";
import { markRouteReady } from "../stores/app-state";

const router = useRouter();
const form = reactive({
  fullName: "",
  email: "",
  birthDate: "",
  gender: "",
  password: "",
});
const ui = reactive({
  loading: false,
  message: "",
  type: "",
});

markRouteReady();

async function submitForm() {
  ui.loading = true;
  ui.message = "";
  ui.type = "";
  const submittedEmail = form.email.trim();

  try {
    const { response, data } = await requestJson("/api/register", {
      method: "POST",
      body: JSON.stringify({
        fullName: form.fullName.trim(),
        email: submittedEmail,
        birthDate: form.birthDate,
        gender: form.gender,
        password: form.password,
      }),
    });

    if (!response.ok || !data?.ok) {
      ui.message = resolveApiMessage(data, "Regjistrimi nuk funksionoi.");
      ui.type = "error";
      return;
    }

    ui.message = data.message || "Llogaria u ruajt me sukses. Po kalon te verifikimi i email-it...";
    ui.type = "success";

    form.fullName = "";
    form.email = "";
    form.birthDate = "";
    form.gender = "";
    form.password = "";

    window.setTimeout(() => {
      router.push(data.redirectTo || getVerifyEmailUrl(submittedEmail));
    }, 900);
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
  <section class="signup-hero" aria-label="Sign Up hero">
    <section class="card auth-card signup-card">
      <p class="section-label">Sign Up</p>
      <h1>Krijo nje llogari te re</h1>
      <p class="section-text">
        Plotesoje emrin e plote, email-in, daten e lindjes, gjinine dhe fjalekalimin. Pasi te ruhen ne databaze, do te marresh nje kod verifikimi ne email para se te kyçesh.
      </p>

      <form class="auth-form" @submit.prevent="submitForm">
        <label class="field">
          <span>Emri i plote</span>
          <input
            v-model="form.fullName"
            name="fullName"
            type="text"
            placeholder="p.sh. Arber Krasniqi"
            required
          >
        </label>

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

        <div class="field-row">
          <label class="field">
            <span>Data e lindjes</span>
            <input v-model="form.birthDate" name="birthDate" type="date" required>
          </label>

          <label class="field">
            <span>Gjinia</span>
            <select v-model="form.gender" name="gender" required>
              <option value="">Zgjedhe gjinine</option>
              <option value="mashkull">Mashkull</option>
              <option value="femer">Femer</option>
            </select>
          </label>
        </div>

        <label class="field">
          <span>Fjalekalimi</span>
          <input
            v-model="form.password"
            name="password"
            type="password"
            placeholder="Te pakten 8 karaktere"
            minlength="8"
            required
          >
        </label>

        <button id="signup-submit-button" type="submit" :disabled="ui.loading">
          {{ ui.loading ? "Duke ruajtur..." : "Ruaje llogarine" }}
        </button>
      </form>

      <div class="form-message" :class="ui.type" role="status" aria-live="polite">
        {{ ui.message }}
      </div>

      <p class="form-footer">
        E ke tashme nje llogari?
        <RouterLink class="inline-link" to="/login">Vazhdo te Login</RouterLink>
      </p>
    </section>
  </section>
</template>
