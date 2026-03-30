<script setup>
import { onMounted, reactive, ref } from "vue";
import { useRouter } from "vue-router";
import { requestJson, resolveApiMessage } from "../lib/api";
import {
  createEmptyAddress,
  normalizeAddress,
  persistCheckoutAddressDraft,
  readCheckoutAddressDraft,
  readCheckoutSelectedCartIds,
} from "../lib/shop";
import { ensureSessionLoaded, markRouteReady } from "../stores/app-state";

const router = useRouter();
const savedAddress = ref(null);
const formState = reactive(createEmptyAddress());
const saveForLater = ref(false);
const ui = reactive({
  message: "",
  type: "",
  locationMessage: "",
  locationType: "",
  locationBusy: false,
});

onMounted(async () => {
  try {
    const user = await ensureSessionLoaded();
    if (!user) {
      router.replace("/login");
      return;
    }

    if (readCheckoutSelectedCartIds().length === 0) {
      router.replace("/cart");
      return;
    }

    await loadSavedAddress();
  } finally {
    markRouteReady();
  }
});

async function loadSavedAddress() {
  const { response, data } = await requestJson("/api/address");
  if (!response.ok || !data?.ok) {
    ui.message = resolveApiMessage(data, "Adresa nuk u ngarkua.");
    ui.type = "error";
    return;
  }

  savedAddress.value = data.address ? normalizeAddress(data.address) : null;
  Object.assign(formState, readCheckoutAddressDraft() || createEmptyAddress());
}

function continueWithSavedAddress() {
  if (!savedAddress.value) {
    return;
  }

  persistCheckoutAddressDraft(savedAddress.value);
  router.push("/menyra-e-pageses");
}

async function continueWithNewAddress() {
  ui.message = "";

  if (!saveForLater.value) {
    persistCheckoutAddressDraft(formState);
    router.push("/menyra-e-pageses");
    return;
  }

  const { response, data } = await requestJson("/api/address", {
    method: "POST",
    body: JSON.stringify(formState),
  });

  if (!response.ok || !data?.ok || !data.address) {
    ui.message = resolveApiMessage(data, "Ruajtja e adreses nuk funksionoi.");
    ui.type = "error";
    return;
  }

  savedAddress.value = normalizeAddress(data.address);
  persistCheckoutAddressDraft(savedAddress.value);
  router.push("/menyra-e-pageses");
}

function applyResolvedLocation(address) {
  const nextAddress = normalizeAddress(address);
  Object.assign(formState, {
    ...nextAddress,
    country: nextAddress.country || formState.country || "Kosove",
    phoneNumber: formState.phoneNumber || "",
  });
  persistCheckoutAddressDraft(formState);
  ui.locationMessage = "Lokacioni u plotësua. Kontrolloje adresën para se të vazhdosh.";
  ui.locationType = "success";
}

async function useDeviceLocation() {
  ui.locationMessage = "";
  ui.locationType = "";

  if (!navigator.geolocation) {
    ui.locationMessage = "Browser-i yt nuk e mbështet lokacionin automatik. Plotëso adresën manualisht.";
    ui.locationType = "info";
    return;
  }

  ui.locationBusy = true;
  ui.locationMessage = "Po kërkohet leja e lokacionit nga telefoni...";
  ui.locationType = "info";

  try {
    const position = await new Promise((resolve, reject) => {
      navigator.geolocation.getCurrentPosition(resolve, reject, {
        enableHighAccuracy: true,
        timeout: 12000,
        maximumAge: 30000,
      });
    });

    const { response, data } = await requestJson("/api/address/geocode", {
      method: "POST",
      body: JSON.stringify({
        latitude: position.coords.latitude,
        longitude: position.coords.longitude,
      }),
    });

    if (!response.ok || !data?.ok || !data.address) {
      ui.locationMessage = resolveApiMessage(data, "Lokacioni nuk u identifikua automatikisht. Plotëso adresën manualisht.");
      ui.locationType = "info";
      return;
    }

    applyResolvedLocation(data.address);
  } catch (error) {
    const errorCode = Number(error?.code || 0);
    if (errorCode === 1) {
      ui.locationMessage = "Leja për lokacion u refuzua. Plotëso adresën manualisht.";
      ui.locationType = "info";
      return;
    }

    ui.locationMessage = "Lokacioni nuk u mor. Plotëso adresën manualisht.";
    ui.locationType = "info";
  } finally {
    ui.locationBusy = false;
  }
}

function cancelChanges() {
  Object.assign(formState, readCheckoutAddressDraft() || createEmptyAddress());
  ui.message = "";
  ui.type = "";
}
</script>

<template>
  <section class="account-page checkout-address-page" aria-label="Adresa e porosise">
    <header class="account-header profile-page-header">
      <div>
        <p class="section-label">Checkout</p>
        <h1>Vendos adresen e porosise</h1>
        <p class="section-text">
          Zgjedhe adresen per pranim te porosis.
        </p>
      </div>
    </header>

    <section class="card checkout-address-card">
      <div class="profile-card-header">
        <div>
          <p class="section-label">Dergesa</p>
          <h2>Zgjedhja e adreses</h2>
        </div>
      </div>

      <div class="form-message" :class="ui.type" role="status" aria-live="polite">
        {{ ui.message }}
      </div>

      <div v-if="savedAddress" class="checkout-saved-address-panel">
        <button class="cart-checkout-button checkout-use-saved-button" type="button" @click="continueWithSavedAddress">
          Vazhdo me adresen e regjistruar
        </button>
      </div>

      <div v-if="!savedAddress" class="collection-empty-state">
        Ende nuk ke adrese te ruajtur. Plotëso formën më poshtë dhe vazhdo me porosinë.
      </div>

      <div v-if="savedAddress" class="address-summary-grid">
        <div class="summary-chip">
          <span>Adresa e vendbanimit</span>
          <strong>{{ savedAddress.addressLine || "-" }}</strong>
        </div>
        <div class="summary-chip">
          <span>Qyteti</span>
          <strong>{{ savedAddress.city || "-" }}</strong>
        </div>
        <div class="summary-chip">
          <span>Shteti</span>
          <strong>{{ savedAddress.country || "-" }}</strong>
        </div>
        <div class="summary-chip">
          <span>Zip code</span>
          <strong>{{ savedAddress.zipCode || "-" }}</strong>
        </div>
        <div class="summary-chip">
          <span>Numri i telefonit</span>
          <strong>{{ savedAddress.phoneNumber || "-" }}</strong>
        </div>
        <div class="summary-chip">
          <span>Statusi</span>
          <strong>Adrese e regjistruar</strong>
        </div>
      </div>

      <p class="section-text checkout-address-lead">
        {{ savedAddress ? "Ose vazhdo me regjistrimin e nje adrese te re." : "Vazhdo me regjistrimin e adreses." }}
      </p>

      <div class="marketplace-status-card checkout-shipping-note">
        <div>
          <p class="section-label">Transporti</p>
          <strong>Kostoja e dergeses llogaritet sipas qytetit dhe rregullave te secilit biznes ne shporte.</strong>
          <p class="section-text">
            Bizneset e verifikuara vendosin cmimin baze, pickup-in dhe pragjet per zbritje ose transport falas.
          </p>
        </div>
      </div>

      <div class="checkout-location-panel">
        <button
          class="ghost-button checkout-location-button"
          type="button"
          :disabled="ui.locationBusy"
          @click="useDeviceLocation"
        >
          {{ ui.locationBusy ? "Po merret lokacioni..." : "Përdor lokacionin tim" }}
        </button>
        <p class="section-text checkout-location-copy">
          Kjo kërkon leje nga telefoni. Nëse s'e lejon, mund ta plotësosh adresën manualisht.
        </p>
      </div>

      <div v-if="ui.locationMessage" class="form-message" :class="ui.locationType" role="status" aria-live="polite">
        {{ ui.locationMessage }}
      </div>

      <form class="auth-form profile-form" @submit.prevent="continueWithNewAddress">
        <div class="field">
          <span>Adresa e vendbanimit</span>
          <input v-model="formState.addressLine" type="text" placeholder="Shkruaje adresen e vendbanimit" required>
        </div>

        <div class="field-row">
          <label class="field">
            <span>Qyteti</span>
            <input v-model="formState.city" type="text" placeholder="Shkruaje qytetin" required>
          </label>

          <label class="field">
            <span>Shteti</span>
            <input v-model="formState.country" type="text" placeholder="Shkruaje shtetin" required>
          </label>
        </div>

        <div class="field-row">
          <label class="field">
            <span>Zip code</span>
            <input v-model="formState.zipCode" type="text" placeholder="Shkruaje zip code" required>
          </label>

          <label class="field">
            <span>Numri i telefonit</span>
            <input v-model="formState.phoneNumber" type="tel" placeholder="Shkruaje numrin e telefonit" required>
          </label>
        </div>

        <label class="checkout-save-address-option">
          <input v-model="saveForLater" type="checkbox">
          <span>Ruaje kete adrese per raste tjera</span>
        </label>

        <div class="profile-form-actions">
          <button class="profile-save-button" type="submit">Vazhdo me regjistrimin e adreses</button>
          <button class="ghost-button profile-cancel-button" type="button" @click="cancelChanges">Cancel</button>
        </div>
      </form>
    </section>
  </section>
</template>
