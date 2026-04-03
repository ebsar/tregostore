<script setup>
import { nextTick, onMounted, reactive, ref } from "vue";
import { useRouter } from "vue-router";
import { requestJson, resolveApiMessage } from "../lib/api";
import { isGoogleWebAuthEnabled, renderGoogleAuthButton } from "../lib/google-auth";
import { getVerifyEmailUrl } from "../lib/shop";
import { ensureSessionLoaded, markRouteReady } from "../stores/app-state";

const router = useRouter();
const form = reactive({
  fullName: "",
  email: "",
  phoneNumber: "",
  birthDate: "",
  gender: "",
  password: "",
});
const ui = reactive({
  loading: false,
  message: "",
  type: "",
});
const googleButtonElement = ref(null);
const googleEnabled = isGoogleWebAuthEnabled();

markRouteReady();

function showSocialAuthMessage(provider) {
  ui.message = `${provider} sign up po behet gati. Duhet te lidhen credential-et server-side per ta aktivizuar plotesisht.`;
  ui.type = "success";
}

async function handleGoogleCredential(googleResponse) {
  const credential = String(googleResponse?.credential || "").trim();
  if (!credential) {
    ui.message = "Google sign up nuk ktheu credential valide.";
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
        intent: "signup",
      }),
    });

    if (!response.ok || !data?.ok) {
      ui.message = resolveApiMessage(data, "Google sign up nuk funksionoi.");
      ui.type = "error";
      return;
    }

    ui.message = data.message || "Llogaria u krijua me sukses me Google.";
    ui.type = "success";
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

onMounted(async () => {
  if (!googleEnabled) {
    return;
  }

  await nextTick();
  try {
    await renderGoogleAuthButton(googleButtonElement.value, handleGoogleCredential, {
      text: "signup_with",
      width: 320,
    });
  } catch (error) {
    console.error(error);
  }
});

function isStrongPassword(password) {
  return (
    password.length >= 8
    && /[A-Za-z]/.test(password)
    && /\d/.test(password)
    && /[^A-Za-z0-9]/.test(password)
  );
}

async function submitForm() {
  ui.loading = true;
  ui.message = "";
  ui.type = "";
  const submittedEmail = form.email.trim();

  if (!isStrongPassword(form.password)) {
    ui.message = "Fjalekalimi duhet te kete minimum 8 karaktere, te pakten nje shkronje, nje numer dhe nje simbol.";
    ui.type = "error";
    ui.loading = false;
    return;
  }

  try {
    const { response, data } = await requestJson("/api/register", {
      method: "POST",
      body: JSON.stringify({
        fullName: form.fullName.trim(),
        email: submittedEmail,
        phoneNumber: form.phoneNumber.trim(),
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

    const hasDeliveryWarnings = Array.isArray(data?.warnings) && data.warnings.length > 0;
    ui.message = data.message || "Llogaria u ruajt me sukses. Po kalon te verifikimi i email-it...";
    ui.type = hasDeliveryWarnings ? "error" : "success";

    if (hasDeliveryWarnings) {
      form.password = "";
      return;
    }

    form.fullName = "";
    form.email = "";
    form.phoneNumber = "";
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
      <h1>Krijo llogari</h1>

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

        <label class="field">
          <span>Numri i telefonit</span>
          <input
            v-model="form.phoneNumber"
            name="phoneNumber"
            type="tel"
            placeholder="p.sh. +383 44 123 456"
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
            placeholder="Minimum 8 karaktere, numer dhe simbol"
            minlength="8"
            pattern="(?=.*[A-Za-z])(?=.*\d)(?=.*[^A-Za-z0-9]).{8,}"
            title="Fjalekalimi duhet te kete minimum 8 karaktere, te pakten nje shkronje, nje numer dhe nje simbol."
            required
          >
          <small class="field-help">Duhet te kete te pakten 8 karaktere, nje shkronje, nje numer dhe nje simbol.</small>
        </label>

        <button id="signup-submit-button" type="submit" :disabled="ui.loading">
          {{ ui.loading ? "Duke ruajtur..." : "Ruaje llogarine" }}
        </button>
      </form>

      <div class="auth-social-stack" aria-label="Social signup options">
        <p class="auth-social-label">Vazhdo me</p>
        <div class="auth-social-actions">
          <button type="button" class="auth-social-button auth-social-button--apple" @click="showSocialAuthMessage('Apple')">
            Sign up with Apple
          </button>
          <div v-if="googleEnabled" ref="googleButtonElement" class="auth-social-google-render" />
          <button v-else type="button" class="auth-social-button auth-social-button--google" @click="showSocialAuthMessage('Google')">
            Sign up with Google
          </button>
        </div>
      </div>

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
