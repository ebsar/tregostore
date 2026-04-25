<script setup lang="ts">
import { IonButton, IonContent, IonIcon, IonInput, IonPage } from "@ionic/vue";
import { headsetOutline, logoFacebook } from "ionicons/icons";
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

function showSupportMessage() {
  form.message = "Customer Support po behet gati ne app. Se shpejti do lidhet direkt me mesazhet.";
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
    <IonContent :fullscreen="true">
      <div>
        <section>
          <div>
            <AppBackButton back-to="/tabs/account" />
          </div>
          <div>
            <button type="button" @click="showSupportMessage">
              <IonIcon :icon="headsetOutline" />
            </button>
          </div>
          <div>
            <h1>Kyçuni</h1>
            <span />
          </div>
        </section>

        <section>
          <label>
            <span>Email ose telefoni</span>
            <IonInput v-model="form.identifier" type="text" placeholder="email@domain.com ose +383..." data-testid="login-identifier" />
          </label>

          <label>
            <span>Password</span>
            <IonInput v-model="form.password" type="password" placeholder="Password" data-testid="login-password" />
          </label>

          <RouterLink to="/forgot-password">Keni harruar fjalekalimin?</RouterLink>

          <p v-if="form.message">{{ form.message }}</p>

          <IonButton data-testid="login-submit" :disabled="form.busy" @click="submit">
            {{ form.busy ? "Duke u kyçur..." : "Login" }}
          </IonButton>

          <p>
            Nuk keni llogari akoma?
            <RouterLink to="/signup">Sign up</RouterLink>
          </p>

          <div>
            <p>Vazhdo me</p>
            <button type="button" @click="showSocialAuthMessage('Apple')">
              Continue with Apple
            </button>
            <button type="button" @click="showSocialAuthMessage('Google')">
              Continue with Google
            </button>
            <button type="button" @click="showSocialAuthMessage('Facebook')">
              <IonIcon :icon="logoFacebook" />
              <span>Continue with Facebook</span>
            </button>
          </div>
        </section>
      </div>
    </IonContent>
  </IonPage>
</template>

