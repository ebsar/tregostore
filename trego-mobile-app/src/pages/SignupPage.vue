<script setup lang="ts">
import { IonButton, IonContent, IonIcon, IonInput, IonPage } from "@ionic/vue";
import { headsetOutline, logoFacebook } from "ionicons/icons";
import { reactive } from "vue";
import { RouterLink, useRoute, useRouter } from "vue-router";
import AppBackButton from "../components/AppBackButton.vue";
import { registerUser } from "../lib/api";

const router = useRouter();
const route = useRoute();
const form = reactive({
  firstName: "",
  lastName: "",
  email: "",
  phoneNumber: "",
  password: "",
  birthDate: "",
  gender: "",
  message: "",
  type: "",
  busy: false,
});

function showSocialAuthMessage(provider: string) {
  form.message = `${provider} sign up po behet gati. Duhet te lidhen credential-et server-side per ta aktivizuar plotesisht.`;
  form.type = "success";
}

function showSupportMessage() {
  form.message = "Customer Support po behet gati ne app. Se shpejti do lidhet direkt me mesazhet.";
  form.type = "success";
}

async function submit() {
  if (form.busy) {
    return;
  }

  form.busy = true;
    form.message = "";
  try {
    const fullName = [form.firstName.trim(), form.lastName.trim()].filter(Boolean).join(" ");
    const { response, data } = await registerUser({
      fullName,
      email: form.email.trim(),
      phoneNumber: form.phoneNumber.trim(),
      password: form.password,
      birthDate: form.birthDate,
      gender: form.gender,
    });

    if (!response.ok || !data?.ok) {
      form.message = String(data?.errors?.join?.(" ") || data?.message || "Regjistrimi deshtoi.");
      form.type = "error";
      return;
    }

    form.message = "Llogaria u krijua. Kontrollo email-in per verifikim dhe vazhdo me login.";
    form.type = "success";
    window.setTimeout(() => {
      const redirect = String(route.query.redirect || "").trim();
      router.replace(redirect ? `/login?redirect=${encodeURIComponent(redirect)}` : "/login");
    }, 1200);
  } finally {
    form.busy = false;
  }
}
</script>

<template>
  <IonPage>
    <IonContent class="app-gradient" :fullscreen="true">
      <div class="mobile-page auth-page">
        <section class="page-shell-with-back auth-shell">
          <div class="page-back-anchor">
            <AppBackButton back-to="/tabs/account" />
          </div>
          <div class="auth-top-tools">
            <button class="auth-support-button" type="button" @click="showSupportMessage">
              <IonIcon :icon="headsetOutline" />
            </button>
          </div>
          <div class="auth-intro">
            <h1>Regjistrohuni</h1>
            <span class="auth-intro-divider" />
          </div>
        </section>

        <section class="surface-card surface-card--strong auth-form-card">
          <div class="auth-form-grid">
            <label>
              <span>Emri</span>
              <IonInput v-model="form.firstName" class="auth-input" type="text" placeholder="Emri" />
            </label>

            <label>
              <span>Mbiemri</span>
              <IonInput v-model="form.lastName" class="auth-input" type="text" placeholder="Mbiemri" />
            </label>
          </div>

          <label>
            <span>Email</span>
            <IonInput v-model="form.email" class="auth-input" type="email" placeholder="email@domain.com" />
          </label>

          <label>
            <span>Numri i telefonit</span>
            <IonInput v-model="form.phoneNumber" class="auth-input" type="tel" placeholder="+383 44 123 456" />
          </label>

          <label>
            <span>Password</span>
            <IonInput v-model="form.password" class="auth-input" type="password" placeholder="Password" />
          </label>

          <div class="auth-form-grid">
            <label>
              <span>Data e lindjes</span>
              <input v-model="form.birthDate" class="promo-input auth-native-input" type="date" />
            </label>

            <label>
              <span>Gjinia</span>
              <select v-model="form.gender" class="promo-input auth-native-input auth-select-input">
                <option value="">Zgjedhe gjinine</option>
                <option value="femer">Femër</option>
                <option value="mashkull">Mashkull</option>
              </select>
            </label>
          </div>

          <p v-if="form.message" class="auth-form-message" :class="form.type">{{ form.message }}</p>

          <IonButton class="cta-button" :disabled="form.busy" @click="submit">
            {{ form.busy ? "Duke krijuar llogarine..." : "Sign up" }}
          </IonButton>

          <p class="auth-switch-copy">
            Keni llogari tashmë?
            <RouterLink class="auth-inline-link auth-inline-link--inline" to="/login">Log in</RouterLink>
          </p>

          <div class="auth-social-stack">
            <p class="auth-social-label">Vazhdo me</p>
            <button type="button" class="auth-social-button auth-social-button--apple" @click="showSocialAuthMessage('Apple')">
              Sign up with Apple
            </button>
            <button type="button" class="auth-social-button auth-social-button--google" @click="showSocialAuthMessage('Google')">
              Sign up with Google
            </button>
            <button type="button" class="auth-social-button auth-social-button--facebook" @click="showSocialAuthMessage('Facebook')">
              <IonIcon :icon="logoFacebook" />
              <span>Sign up with Facebook</span>
            </button>
          </div>
        </section>
      </div>
    </IonContent>
  </IonPage>
</template>

<style scoped>
.auth-page {
  justify-content: center;
  min-height: 100%;
}

.auth-shell {
  gap: 8px;
}

.auth-top-tools {
  display: flex;
  justify-content: flex-end;
}

.auth-support-button {
  display: inline-flex;
  width: 38px;
  height: 38px;
  align-items: center;
  justify-content: center;
  border: 1px solid rgba(255, 255, 255, 0.58);
  border-radius: 999px;
  background:
    linear-gradient(180deg, rgba(255,255,255,0.24), rgba(255,255,255,0.08));
  color: var(--trego-dark);
  box-shadow:
    inset 0 1px 0 rgba(255,255,255,0.72),
    0 12px 24px rgba(15, 23, 42, 0.06);
}

.auth-intro {
  text-align: center;
  padding: 0 8px;
  display: grid;
  gap: 10px;
}

.auth-intro h1,
.auth-intro p {
  margin: 0;
}

.auth-intro h1 {
  color: var(--trego-dark);
  font-size: clamp(1.72rem, 7vw, 2.08rem);
  line-height: 1.02;
}

.auth-intro-divider {
  display: block;
  width: 100%;
  height: 1px;
  background: linear-gradient(90deg, transparent, rgba(148, 163, 184, 0.44), transparent);
}

.auth-form-card {
  display: flex;
  flex-direction: column;
  gap: 15px;
  padding: 22px 18px 20px;
}

.auth-form-card label {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.auth-form-card span {
  color: var(--trego-dark);
  font-size: 0.84rem;
  font-weight: 700;
}

.auth-form-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 12px;
}

.auth-native-input {
  width: 100%;
}

.auth-select-input {
  appearance: none;
  padding-right: 32px;
}

.auth-form-message {
  margin: 0;
  font-size: 0.84rem;
}

.auth-form-message.error {
  color: var(--trego-danger);
}

.auth-form-message.success {
  color: #15803d;
}

.auth-switch-copy {
  margin: -2px 0 0;
  color: rgba(15, 23, 42, 0.72);
  font-size: 0.85rem;
  font-weight: 600;
  text-align: center;
}

.auth-inline-link {
  color: var(--trego-accent);
  font-weight: 700;
  text-decoration: none;
}

.auth-inline-link--inline {
  margin-left: 4px;
}

.auth-social-stack {
  display: grid;
  gap: 10px;
  margin-top: 2px;
}

.auth-social-label {
  margin: 0;
  color: rgba(15, 23, 42, 0.58);
  font-size: 0.78rem;
  font-weight: 800;
  text-align: center;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.auth-social-button {
  min-height: 50px;
  border: 1px solid rgba(255, 255, 255, 0.68);
  border-radius: 18px;
  background: linear-gradient(180deg, rgba(255,255,255,0.94), rgba(255,255,255,0.8));
  color: var(--trego-dark);
  font-size: 0.95rem;
  font-weight: 800;
  box-shadow: 0 16px 28px rgba(15, 23, 42, 0.06);
}

.auth-social-button--apple {
  background: linear-gradient(180deg, rgba(24,24,27,0.98), rgba(39,39,42,0.94));
  color: #fff;
}

.auth-social-button--google {
  color: #1d4ed8;
}

.auth-social-button--facebook {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 10px;
  color: #ffffff;
  background: linear-gradient(180deg, rgba(24,119,242,0.98), rgba(18,92,208,0.94));
}

.auth-social-button--facebook ion-icon {
  font-size: 1rem;
}
</style>
