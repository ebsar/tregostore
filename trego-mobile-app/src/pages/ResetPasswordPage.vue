<script setup lang="ts">
import { IonButton, IonContent, IonInput, IonPage } from "@ionic/vue";
import { reactive } from "vue";
import { useRoute, useRouter } from "vue-router";
import AppBackButton from "../components/AppBackButton.vue";
import { confirmPasswordReset, forgotPassword, resolveApiMessage } from "../lib/api";

const route = useRoute();
const router = useRouter();
const form = reactive({
  email: String(route.query.email || "").trim(),
  code: "",
  newPassword: "",
  confirmPassword: "",
  message: "",
  type: "",
  busy: false,
  resendBusy: false,
});

async function submit() {
  if (!form.email.trim() || !form.code.trim() || !form.newPassword || !form.confirmPassword) {
    form.message = "Ploteso te gjitha fushat.";
    form.type = "error";
    return;
  }

  form.busy = true;
  form.message = "";
  form.type = "";

  try {
    const { response, data } = await confirmPasswordReset({
      email: form.email.trim(),
      code: form.code.trim(),
      newPassword: form.newPassword,
      confirmPassword: form.confirmPassword,
    });

    if (!response.ok || !data?.ok) {
      form.message = resolveApiMessage(data, "Resetimi i fjalekalimit deshtoi.");
      form.type = "error";
      return;
    }

    form.message = String(data?.message || "Fjalekalimi u ndryshua me sukses.");
    form.type = "success";
    form.code = "";
    form.newPassword = "";
    form.confirmPassword = "";

    window.setTimeout(() => {
      router.replace(String(data?.redirectTo || "/login"));
    }, 900);
  } finally {
    form.busy = false;
  }
}

async function resendCode() {
  if (!form.email.trim()) {
    form.message = "Vendos email-in per ta riderguar kodin.";
    form.type = "error";
    return;
  }

  form.resendBusy = true;
  form.message = "";
  form.type = "";

  try {
    const { response, data } = await forgotPassword(form.email.trim());
    if (!response.ok || !data?.ok) {
      form.message = resolveApiMessage(data, "Kodi nuk u dergua perseri.");
      form.type = "error";
      return;
    }

    form.message = String(data?.message || "Kodi u dergua perseri.");
    form.type = "success";
  } finally {
    form.resendBusy = false;
  }
}
</script>

<template>
  <IonPage>
    <IonContent :fullscreen="true">
      <div>
        <section>
          <div>
            <AppBackButton back-to="/forgot-password" />
          </div>
          <div>
            <h1>RESET PASSWORD</h1>
          </div>
        </section>

        <section>
          <label>
            <span>Email</span>
            <IonInput v-model="form.email" type="email" placeholder="email@domain.com" />
          </label>

          <label>
            <span>Kodi</span>
            <IonInput
              v-model="form.code"
             
              type="text"
              inputmode="numeric"
              maxlength="6"
              placeholder="123456"
            />
          </label>

          <label>
            <span>Fjalekalimi i ri</span>
            <IonInput v-model="form.newPassword" type="password" placeholder="Fjalekalimi i ri" />
          </label>

          <label>
            <span>Konfirmo fjalekalimin</span>
            <IonInput
              v-model="form.confirmPassword"
             
              type="password"
              placeholder="Perserite fjalekalimin"
            />
          </label>

          <p v-if="form.message">{{ form.message }}</p>

          <div>
            <IonButton :disabled="form.busy" @click="submit">
              {{ form.busy ? "Duke ruajtur..." : "Ndrysho fjalekalimin" }}
            </IonButton>

            <IonButton fill="clear" :disabled="form.resendBusy" @click="resendCode">
              {{ form.resendBusy ? "Duke derguar..." : "Dergo kodin perseri" }}
            </IonButton>
          </div>
        </section>
      </div>
    </IonContent>
  </IonPage>
</template>

