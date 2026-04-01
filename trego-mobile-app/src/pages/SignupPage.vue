<script setup lang="ts">
import { IonButton, IonContent, IonInput, IonPage } from "@ionic/vue";
import { reactive } from "vue";
import { useRouter } from "vue-router";
import AppBackButton from "../components/AppBackButton.vue";
import { registerUser } from "../lib/api";

const router = useRouter();
const form = reactive({
  fullName: "",
  email: "",
  password: "",
  birthDate: "",
  gender: "female",
  message: "",
  type: "",
  busy: false,
});

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
        <section class="auth-intro">
          <AppBackButton back-to="/tabs/account" />
          <p class="section-kicker">Sign up</p>
          <h1>Krijoni llogarinë.</h1>
          <p class="section-copy">Përdor të njëjtin backend dhe të njëjtat të dhëna si platforma kryesore.</p>
        </section>

        <section class="surface-card surface-card--strong auth-form-card">
          <p class="auth-form-lead">Krijoni llogarinë tuaj.</p>

          <label>
            <span>Emri i plotë</span>
            <IonInput v-model="form.fullName" type="text" placeholder="Emri Mbiemri" />
          </label>

          <label>
            <span>Email</span>
            <IonInput v-model="form.email" type="email" placeholder="email@domain.com" />
          </label>

          <label>
            <span>Password</span>
            <IonInput v-model="form.password" type="password" placeholder="Password" />
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

.auth-intro h1,
.auth-intro p {
  margin: 0;
}

.auth-intro h1 {
  color: var(--trego-dark);
  font-size: clamp(1.6rem, 7vw, 2rem);
  line-height: 1.02;
}

.auth-intro .section-copy {
  margin-top: 10px;
}

.auth-form-card {
  display: flex;
  flex-direction: column;
  gap: 14px;
  padding: 20px 18px;
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
  border: 1px solid var(--trego-input-border);
  border-radius: 14px;
  background: var(--trego-surface);
  color: var(--trego-dark);
  font-size: 0.78rem;
  font-weight: 700;
  box-shadow: var(--trego-shadow-soft);
}

.gender-choice-button.active {
  border-color: rgba(255, 106, 43, 0.28);
  background: rgba(255, 106, 43, 0.14);
  color: var(--trego-accent);
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
</style>
