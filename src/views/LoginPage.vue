<script setup>
import { nextTick, onMounted, reactive, ref } from "vue";
import { useRoute, useRouter } from "vue-router";
import { requestJson, resolveApiMessage } from "../lib/api";
import { isGoogleWebAuthEnabled, renderGoogleAuthButton } from "../lib/google-auth";
import { persistLoginGreeting } from "../lib/shop";
import { ensureSessionLoaded, markRouteReady } from "../stores/app-state";

const route = useRoute();
const router = useRouter();
const form = reactive({
  identifier: "",
  password: "",
});
const ui = reactive({
  loading: false,
  message: "",
  type: "",
});
const googleButtonElement = ref(null);
const googleEnabled = isGoogleWebAuthEnabled();

function showSocialAuthMessage(provider) {
  ui.message = `${provider} login po behet gati. Duhet te lidhen credential-et server-side per ta aktivizuar plotesisht.`;
  ui.type = "success";
}

async function handleGoogleCredential(googleResponse) {
  const credential = String(googleResponse?.credential || "").trim();
  if (!credential) {
    ui.message = "Google login nuk ktheu credential valide.";
    ui.type = "error";
    return;
  }

  ui.loading = true;
  ui.message = "";
  ui.type = "";

  try {
    const { response, data } = await requestJson("/api/auth/google", {
      method: "POST",
      body: JSON.stringify({
        credential,
        intent: "login",
      }),
    });

    if (!response.ok || !data?.ok) {
      ui.message = resolveApiMessage(data, "Google login nuk funksionoi.");
      ui.type = "error";
      return;
    }

    ui.message = data.message || "U kyqe me sukses me Google.";
    ui.type = "success";
    persistLoginGreeting(data.user?.firstName || data.user?.fullName || "User");
    await ensureSessionLoaded({ force: true });
    window.setTimeout(() => {
      const redirectPath = String(route.query.redirect || "").trim();
      router.push(data.redirectTo || redirectPath || "/");
    }, 700);
  } catch (error) {
    ui.message = "Serveri nuk po pergjigjet. Provoje perseri.";
    ui.type = "error";
    console.error(error);
  } finally {
    ui.loading = false;
  }
}

onMounted(async () => {
  if (!googleEnabled) {
    return;
  }

  await nextTick();
  try {
    await renderGoogleAuthButton(googleButtonElement.value, handleGoogleCredential, {
      text: "continue_with",
      width: 320,
    });
  } catch (error) {
    console.error(error);
  }
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
        identifier: form.identifier.trim(),
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
      const redirectPath = String(route.query.redirect || "").trim();
      router.push(data.redirectTo || redirectPath || "/");
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
      <p class="section-label login-card-title">LOGIN</p>

      <form class="auth-form" @submit.prevent="submitForm">
        <label class="field">
          <span>Email ose telefoni</span>
          <input
            v-model="form.identifier"
            name="identifier"
            type="text"
            inputmode="email"
            placeholder="p.sh. emri@email.com ose +383 44 123 456"
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

      <div class="auth-social-stack" aria-label="Social login options">
        <p class="auth-social-label">Vazhdo me</p>
        <div class="auth-social-actions">
          <button type="button" class="auth-social-button auth-social-button--apple" @click="showSocialAuthMessage('Apple')">
            Continue with Apple
          </button>
          <div v-if="googleEnabled" ref="googleButtonElement" class="auth-social-google-render" />
          <button v-else type="button" class="auth-social-button auth-social-button--google" @click="showSocialAuthMessage('Google')">
            Continue with Google
          </button>
        </div>
      </div>

      <div class="form-message" :class="ui.type" role="status" aria-live="polite">
        {{ ui.message }}
      </div>

      <p class="form-footer">
        <RouterLink class="inline-link" to="/forgot-password">Kam harruar fjalekalimin?</RouterLink>
      </p>
      <p class="form-footer">
        Nuk ke llogari ende?
        <RouterLink class="inline-link" to="/signup">Krijoje me Sign Up</RouterLink>
      </p>
    </section>
  </section>
</template>

<style scoped>
.auth-social-stack {
  margin-top: 16px;
  display: grid;
  gap: 10px;
}

.auth-social-label {
  margin: 0;
  color: rgba(55, 65, 81, 0.72);
  font-size: 0.82rem;
  font-weight: 700;
  text-align: center;
}

.auth-social-actions {
  display: grid;
  gap: 10px;
}

.auth-social-google-render {
  display: flex;
  justify-content: center;
  min-height: 44px;
}

.auth-social-google-render :deep(div[role="button"]) {
  width: 100% !important;
  border-radius: 18px !important;
}

.auth-social-button {
  min-height: 48px;
  border: 1px solid rgba(255, 255, 255, 0.72);
  border-radius: 18px;
  background: linear-gradient(180deg, rgba(255,255,255,0.94), rgba(255,255,255,0.78));
  color: #1f2937;
  font-size: 0.95rem;
  font-weight: 700;
  box-shadow: 0 14px 28px rgba(15, 23, 42, 0.07);
}

.auth-social-button--apple {
  background: linear-gradient(180deg, rgba(24, 24, 27, 0.96), rgba(39, 39, 42, 0.92));
  color: #fff;
}

.auth-social-button--google {
  color: #173b84;
}
</style>
