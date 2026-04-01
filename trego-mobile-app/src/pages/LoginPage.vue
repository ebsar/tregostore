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
  email: "",
  password: "",
  message: "",
  type: "",
  busy: false,
});

async function submit() {
  if (!form.email.trim() || !form.password.trim()) {
    form.message = "Ploteso email dhe password.";
    form.type = "error";
    return;
  }

  form.busy = true;
  try {
    const { response, data } = await loginUser(form.email.trim(), form.password);
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
        <section class="auth-intro">
          <AppBackButton back-to="/tabs/account" />
          <h1>LOG IN</h1>
        </section>

        <section class="surface-card surface-card--strong auth-form-card">
          <label>
            <span>Email</span>
            <IonInput v-model="form.email" type="email" placeholder="email@domain.com" />
          </label>

          <label>
            <span>Password</span>
            <IonInput v-model="form.password" type="password" placeholder="Password" />
          </label>

          <RouterLink class="auth-inline-link" to="/forgot-password">Keni harruar fjalekalimin?</RouterLink>

          <p v-if="form.message" class="auth-form-message" :class="form.type">{{ form.message }}</p>

          <IonButton class="cta-button" :disabled="form.busy" @click="submit">
            {{ form.busy ? "Duke u kyçur..." : "Login" }}
          </IonButton>
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

.auth-intro {
  text-align: center;
  padding: 10px 8px 0;
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
  gap: 14px;
  padding: 20px 18px;
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

.auth-inline-link {
  align-self: flex-end;
  color: var(--trego-dark);
  font-size: 0.82rem;
  font-weight: 700;
  text-decoration: none;
}
</style>
