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
            <h1>Regjistrohuni</h1>
            <span />
          </div>
        </section>

        <section>
          <div>
            <label>
              <span>Emri</span>
              <IonInput v-model="form.firstName" type="text" placeholder="Emri" />
            </label>

            <label>
              <span>Mbiemri</span>
              <IonInput v-model="form.lastName" type="text" placeholder="Mbiemri" />
            </label>
          </div>

          <label>
            <span>Email</span>
            <IonInput v-model="form.email" type="email" placeholder="email@domain.com" />
          </label>

          <label>
            <span>Numri i telefonit</span>
            <IonInput v-model="form.phoneNumber" type="tel" placeholder="+383 44 123 456" />
          </label>

          <label>
            <span>Password</span>
            <IonInput v-model="form.password" type="password" placeholder="Password" />
          </label>

          <div>
            <label>
              <span>Data e lindjes</span>
              <input v-model="form.birthDate" type="date" />
            </label>

            <label>
              <span>Gjinia</span>
              <select v-model="form.gender">
                <option value="">Zgjedhe gjinine</option>
                <option value="femer">Femër</option>
                <option value="mashkull">Mashkull</option>
              </select>
            </label>
          </div>

          <p v-if="form.message">{{ form.message }}</p>

          <IonButton :disabled="form.busy" @click="submit">
            {{ form.busy ? "Duke krijuar llogarine..." : "Sign up" }}
          </IonButton>

          <p>
            Keni llogari tashmë?
            <RouterLink to="/login">Log in</RouterLink>
          </p>

          <div>
            <p>Vazhdo me</p>
            <button type="button" @click="showSocialAuthMessage('Apple')">
              Sign up with Apple
            </button>
            <button type="button" @click="showSocialAuthMessage('Google')">
              Sign up with Google
            </button>
            <button type="button" @click="showSocialAuthMessage('Facebook')">
              <IonIcon :icon="logoFacebook" />
              <span>Sign up with Facebook</span>
            </button>
          </div>
        </section>
      </div>
    </IonContent>
  </IonPage>
</template>

