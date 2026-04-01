<script setup lang="ts">
import { IonButton, IonContent, IonInput, IonPage } from "@ionic/vue";
import { reactive } from "vue";
import { useRouter } from "vue-router";
import AppBackButton from "../components/AppBackButton.vue";
import { forgotPassword, resolveApiMessage } from "../lib/api";

const router = useRouter();
const form = reactive({
  email: "",
  message: "",
  type: "",
  busy: false,
});

async function submit() {
  if (!form.email.trim()) {
    form.message = "Vendos email-in e llogarise.";
    form.type = "error";
    return;
  }

  form.busy = true;
  form.message = "";
  form.type = "";

  try {
    const { response, data } = await forgotPassword(form.email.trim());
    if (!response.ok || !data?.ok) {
      form.message = resolveApiMessage(data, "Kerkesa nuk u dergua.");
      form.type = "error";
      return;
    }

    form.message = String(data?.message || "Kodi u dergua me sukses.");
    form.type = "success";
    const nextRoute =
      typeof data?.redirectTo === "string" && data.redirectTo.trim()
        ? data.redirectTo.trim()
        : `/ndrysho-fjalekalimin?mode=reset&email=${encodeURIComponent(form.email.trim())}`;

    window.setTimeout(() => {
      router.push(nextRoute);
    }, 900);
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
          <AppBackButton back-to="/login" />
          <h1>FORGOT PASSWORD</h1>
        </section>

        <section class="surface-card surface-card--strong auth-form-card">
          <label>
            <span>Email</span>
            <IonInput v-model="form.email" type="email" placeholder="email@domain.com" />
          </label>

          <p v-if="form.message" class="auth-form-message" :class="form.type">{{ form.message }}</p>

          <IonButton class="cta-button" :disabled="form.busy" @click="submit">
            {{ form.busy ? "Duke derguar..." : "Me dergo kodin" }}
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
  font-size: clamp(1.9rem, 8vw, 2.4rem);
  font-weight: 800;
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

.auth-form-message.success {
  color: #15803d;
}
</style>
