<script setup>
import { reactive } from "vue";
import { useRouter } from "vue-router";
import { requestJson, resolveApiMessage } from "../lib/api";
import { persistLoginGreeting } from "../lib/shop";
import { ensureSessionLoaded, markRouteReady } from "../stores/app-state";

const router = useRouter();
const form = reactive({
  email: "",
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

  try {
    const { response, data } = await requestJson("/api/login", {
      method: "POST",
      body: JSON.stringify({
        email: form.email.trim(),
        password: form.password,
      }),
    });

    if (!response.ok || !data?.ok) {
      ui.message = resolveApiMessage(
        data,
        "Kerkojme falje, por llogaria nuk ekziston.",
      );
      ui.type = "error";
      if (data?.redirectTo) {
        window.setTimeout(() => {
          router.push(data.redirectTo);
        }, 1100);
      }
      return;
    }

    ui.message = data.message || "U kyqe me sukses.";
    ui.type = "success";
    persistLoginGreeting(data.user?.firstName || data.user?.fullName || "User");
    await ensureSessionLoaded({ force: true });
    window.setTimeout(() => {
      router.push(data.redirectTo || "/");
    }, 700);
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
  <section class="login-hero" aria-label="Login hero">
    <section class="card auth-card login-card">
      <p class="section-label">Login</p>
      <h1>Hyr ne llogarine tende</h1>
      <p class="section-text">
        Shkruaje email-in dhe fjalekalimin qe jane ruajtur ne databaze. Nese jane te sakta, do te kalosh ne faqen kryesore.
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
          <span>Fjalekalimi</span>
          <input
            v-model="form.password"
            name="password"
            type="password"
            placeholder="Shkruaje fjalekalimin"
            required
          >
        </label>

        <button id="login-submit-button" type="submit" :disabled="ui.loading">
          {{ ui.loading ? "Duke kontrolluar..." : "Kycu" }}
        </button>
      </form>

      <div class="form-message" :class="ui.type" role="status" aria-live="polite">
        {{ ui.message }}
      </div>

      <p class="form-footer">
        <RouterLink class="inline-link" to="/forgot-password">Kam harruar fjalekalimin?</RouterLink>
      </p>
      <p class="form-footer">
        Nuk e ke verifikuar ende email-in?
        <RouterLink class="inline-link" to="/verifiko-email">Verifikoje kodin</RouterLink>
      </p>
      <p class="form-footer">
        Nuk ke llogari ende?
        <RouterLink class="inline-link" to="/signup">Krijoje me Sign Up</RouterLink>
      </p>
    </section>
  </section>
</template>
