<script setup lang="ts">
import { IonButton, IonContent, IonInput, IonPage } from "@ionic/vue";
import { onMounted, reactive, ref } from "vue";
import { useRouter } from "vue-router";
import AppPageHeader from "../components/AppPageHeader.vue";
import {
  createEmptyAddress,
  normalizeAddress,
  persistCheckoutAddressDraft,
  readCheckoutAddressDraft,
  readCheckoutSelectedCartIds,
} from "../lib/checkout";
import { requestJson, resolveApiMessage } from "../lib/api";
import { ensureSession, sessionState } from "../stores/session";

const router = useRouter();
const savedAddress = ref<ReturnType<typeof normalizeAddress> | null>(null);
const form = reactive(createEmptyAddress());
const saveForLater = ref(false);
const ui = reactive({
  message: "",
  type: "",
  busy: false,
});

onMounted(async () => {
  await ensureSession();
  if (!sessionState.user) {
    router.replace("/login?redirect=/checkout/address");
    return;
  }

  if (readCheckoutSelectedCartIds().length === 0) {
    router.replace("/tabs/cart");
    return;
  }

  Object.assign(form, readCheckoutAddressDraft() || createEmptyAddress());
  await loadSavedAddress();
});

async function loadSavedAddress() {
  const { response, data } = await requestJson<any>("/api/address");
  if (!response.ok || !data?.ok) {
    return;
  }

  savedAddress.value = data.address ? normalizeAddress(data.address) : null;
}

function continueWithSavedAddress() {
  if (!savedAddress.value) {
    return;
  }

  persistCheckoutAddressDraft(savedAddress.value);
  router.push("/checkout/payment");
}

async function handleSubmit() {
  ui.message = "";
  ui.type = "";

  if (!form.addressLine.trim() || !form.city.trim() || !form.country.trim() || !form.zipCode.trim() || !form.phoneNumber.trim()) {
    ui.message = "Ploteso te gjitha fushat e adreses.";
    ui.type = "error";
    return;
  }

  const normalized = normalizeAddress(form);
  persistCheckoutAddressDraft(normalized);

  if (!saveForLater.value) {
    router.push("/checkout/payment");
    return;
  }

  ui.busy = true;
  try {
    const { response, data } = await requestJson<any>("/api/address", {
      method: "POST",
      body: JSON.stringify(normalized),
    });

    if (!response.ok || !data?.ok || !data.address) {
      ui.message = resolveApiMessage(data, "Ruajtja e adreses nuk funksionoi.");
      ui.type = "error";
      return;
    }

    savedAddress.value = normalizeAddress(data.address);
    persistCheckoutAddressDraft(savedAddress.value);
    router.push("/checkout/payment");
  } finally {
    ui.busy = false;
  }
}
</script>

<template>
  <IonPage>
    <IonContent :fullscreen="true">
      <div class="trego-mobile-screen trego-checkout-screen">
        <AppPageHeader
          kicker="Checkout"
          title="Vendos adresen e porosise."
          subtitle="Adresa ruhet perkohesisht ne app dhe vazhdon me te njejtin checkout flow te backend-it."
          back-to="/tabs/cart"
        />

        <section v-if="savedAddress">
          <div>
            <p>Adresa e ruajtur</p>
            <h2>{{ savedAddress.addressLine }}</h2>
            <p>{{ savedAddress.city }}, {{ savedAddress.country }} · {{ savedAddress.zipCode }}</p>
            <p>{{ savedAddress.phoneNumber }}</p>
          </div>
          <IonButton data-testid="checkout-saved-address-button" @click="continueWithSavedAddress">Vazhdo me kete adrese</IonButton>
        </section>

        <section>
          <div>
            <p>Adresa e re</p>
            <h2>Ploteso detajet</h2>
          </div>

          <label>
            <span>Adresa e vendbanimit</span>
            <IonInput v-model="form.addressLine" placeholder="Rruga, hyrja, numri" />
          </label>

          <div class="trego-checkout-row">
            <label>
              <span>Qyteti</span>
              <IonInput v-model="form.city" placeholder="Qyteti" />
            </label>
            <label>
              <span>Shteti</span>
              <IonInput v-model="form.country" placeholder="Kosove" />
            </label>
          </div>

          <div class="trego-checkout-row">
            <label>
              <span>Zip code</span>
              <IonInput v-model="form.zipCode" placeholder="10000" />
            </label>
            <label>
              <span>Numri i telefonit</span>
              <IonInput v-model="form.phoneNumber" placeholder="+383..." />
            </label>
          </div>

          <label>
            <input v-model="saveForLater" type="checkbox" />
            <span>Ruaje kete adrese per porosite tjera</span>
          </label>

          <p v-if="ui.message">{{ ui.message }}</p>

          <IonButton data-testid="checkout-address-submit" :disabled="ui.busy" @click="handleSubmit">
            {{ ui.busy ? "Po ruhet..." : "Vazhdo te pagesa" }}
          </IonButton>
        </section>
      </div>
    </IonContent>
  </IonPage>
</template>
