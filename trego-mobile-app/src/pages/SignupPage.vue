<script setup lang="ts">
import { IonButton, IonContent, IonInput, IonPage } from "@ionic/vue";
import { reactive } from "vue";
import { RouterLink, useRouter } from "vue-router";
import AppBackButton from "../components/AppBackButton.vue";
import { registerUser } from "../lib/api";

const router = useRouter();
const form = reactive({
  fullName: "",
  email: "",
  phoneNumber: "",
  password: "",
  birthDate: "",
  gender: "female",
  message: "",
  type: "",
  busy: false,
});

function showSocialAuthMessage(provider: string) {
  form.message = `${provider} sign up po behet gati. Duhet te lidhen credential-et server-side per ta aktivizuar plotesisht.`;
  form.type = "success";
}

async function submit() {
  if (form.busy) {
    return;
  }

  form.busy = true;
  form.message = "";
  try {
    const { response, data } = await registerUser({
      fullName: form.fullName.trim(),
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
      router.replace("/login");
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
          <div class="auth-intro">
            <h1>Krijoni llogarinë</h1>
          </div>
        </section>

        <section class="surface-card surface-card--strong auth-form-card">
          <p class="auth-form-lead">Krijoni llogarinë tuaj.</p>

          <label>
            <span>Emri i plotë</span>
            <IonInput v-model="form.fullName" class="auth-input" type="text" placeholder="Emri Mbiemri" />
          </label>

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

            <label class="auth-gender-field">
              <span>Gjinia</span>
              <div class="gender-choice-row">
                <button
                  type="button"
                  class="gender-choice-button"
                  :class="{ active: form.gender === 'female' }"
                  @click="form.gender = 'female'"
                >
                  Female
                </button>
                <button
                  type="button"
                  class="gender-choice-button"
                  :class="{ active: form.gender === 'male' }"
                  @click="form.gender = 'male'"
                >
                  Male
                </button>
                <button
                  type="button"
                  class="gender-choice-button"
                  :class="{ active: form.gender === 'other' }"
                  @click="form.gender = 'other'"
                >
                  Other
                </button>
              </div>
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

.auth-intro {
  text-align: center;
  padding: 0 8px;
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

.auth-form-card {
  display: flex;
  flex-direction: column;
  gap: 15px;
  padding: 22px 18px 20px;
}

.auth-form-lead {
  margin: 0;
  color: var(--trego-dark);
  font-size: 0.96rem;
  font-weight: 700;
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

.auth-gender-field {
  justify-content: flex-end;
}

.gender-choice-row {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.gender-choice-button {
  display: inline-flex;
  min-height: 40px;
  align-items: center;
  justify-content: center;
  padding: 0 12px;
  border: 1px solid rgba(255, 255, 255, 0.74);
  border-radius: 14px;
  background:
    linear-gradient(180deg, rgba(255, 255, 255, 0.92), rgba(255, 255, 255, 0.76));
  color: var(--trego-dark);
  font-size: 0.78rem;
  font-weight: 700;
  box-shadow:
    inset 0 1px 0 rgba(255, 255, 255, 0.74),
    0 10px 20px rgba(31, 41, 55, 0.05);
}

.gender-choice-button.active {
  border-color: rgba(255, 106, 43, 0.34);
  background:
    linear-gradient(180deg, rgba(255, 123, 61, 0.16), rgba(255, 106, 43, 0.12));
  color: #c24d17;
  box-shadow:
    inset 0 1px 0 rgba(255, 255, 255, 0.48),
    0 12px 22px rgba(255, 106, 43, 0.12);
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
</style>
