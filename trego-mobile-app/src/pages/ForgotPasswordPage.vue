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
    <IonContent :fullscreen="true">
      <div>
        <section>
          <div>
            <AppBackButton back-to="/login" />
          </div>
          <div>
            <h1>FORGOT PASSWORD</h1>
          </div>
        </section>

        <section>
          <label>
            <span>Email</span>
            <IonInput v-model="form.email" type="email" placeholder="email@domain.com" />
          </label>

          <p v-if="form.message">{{ form.message }}</p>

          <IonButton :disabled="form.busy" @click="submit">
            {{ form.busy ? "Duke derguar..." : "Me dergo kodin" }}
          </IonButton>
        </section>
      </div>
    </IonContent>
  </IonPage>
</template>

