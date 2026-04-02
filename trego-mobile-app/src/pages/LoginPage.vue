<script setup lang="ts">
import { IonButton, IonContent, IonInput, IonPage } from "@ionic/vue";
import { reactive } from "vue";
import { RouterLink, useRoute, useRouter } from "vue-router";
import AppBackButton from "../components/AppBackButton.vue";
import { loginUser } from "../lib/api";
import { refreshSession } from "../stores/session";

const router = useRouter();
const route = useRoute();
const form = reactive({
  identifier: "",
  password: "",
  message: "",
  type: "",
  busy: false,
});

function showSocialAuthMessage(provider: string) {
  form.message = `${provider} login po behet gati. Duhet te lidhen credential-et server-side per ta aktivizuar plotesisht.`;
  form.type = "success";
}

async function submit() {
  if (!form.identifier.trim() || !form.password.trim()) {
    form.message = "Ploteso email ose telefon dhe password.";
    form.type = "error";
    return;
  }

  form.busy = true;
  try {
    const { response, data } = await loginUser(form.identifier.trim(), form.password);
    if (!response.ok || !data?.ok) {
      form.message = String(data?.message || data?.errors?.join?.(" ") || "Login deshtoi.");
      form.type = "error";
      return;
    }

    await refreshSession();
    const redirect = String(route.query.redirect || "/tabs/account");
    router.replace(redirect);
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
            <h1>LOG IN</h1>
          </div>
        </section>

        <section class="surface-card surface-card--strong auth-form-card">
          <label>
            <span>Email ose telefoni</span>
            <IonInput v-model="form.identifier" class="auth-input" type="text" placeholder="email@domain.com ose +383..." />
          </label>

          <label>
            <span>Password</span>
            <IonInput v-model="form.password" class="auth-input" type="password" placeholder="Password" />
          </label>

          <RouterLink class="auth-inline-link" to="/forgot-password">Keni harruar fjalekalimin?</RouterLink>

          <p v-if="form.message" class="auth-form-message" :class="form.type">{{ form.message }}</p>

          <IonButton class="cta-button" :disabled="form.busy" @click="submit">
            {{ form.busy ? "Duke u kyçur..." : "Login" }}
          </IonButton>

          <p class="auth-switch-copy">
            Nuk keni llogari akoma?
            <RouterLink class="auth-inline-link auth-inline-link--inline" to="/signup">Sign up</RouterLink>
          </p>

          <div class="auth-social-stack">
            <p class="auth-social-label">Vazhdo me</p>
            <button type="button" class="auth-social-button auth-social-button--apple" @click="showSocialAuthMessage('Apple')">
              Continue with Apple
            </button>
            <button type="button" class="auth-social-button auth-social-button--google" @click="showSocialAuthMessage('Google')">
              Continue with Google
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

.auth-intro h1 {
  margin: 0;
  color: var(--trego-dark);
  font-size: clamp(2rem, 8vw, 2.5rem);
  font-weight: 800;
  line-height: 1.02;
  letter-spacing: 0.08em;
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

.auth-inline-link {
  align-self: flex-end;
  color: var(--trego-accent);
  font-size: 0.82rem;
  font-weight: 700;
  text-decoration: none;
  padding: 2px 2px 0;
}

.auth-inline-link--inline {
  align-self: auto;
  padding: 0;
}

.auth-switch-copy {
  margin: -2px 0 0;
  color: rgba(15, 23, 42, 0.72);
  font-size: 0.85rem;
  font-weight: 600;
  text-align: center;
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
