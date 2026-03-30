<script setup>
import { onMounted, reactive, ref } from "vue";
import { requestJson, resolveApiMessage } from "../lib/api";
import { createEmptyAddress, normalizeAddress } from "../lib/shop";
import { ensureSessionLoaded, markRouteReady } from "../stores/app-state";

const savedAddress = ref(null);
const initialAddress = ref(createEmptyAddress());
const formState = reactive(createEmptyAddress());
const ui = reactive({
  message: "",
  type: "",
  guest: false,
});

onMounted(async () => {
  try {
    const user = await ensureSessionLoaded();
    if (!user) {
      ui.guest = true;
      ui.message = "Per te perdorur adresat duhet te kyçesh ose te krijosh llogari.";
      ui.type = "error";
      return;
    }

    await loadAddress();
  } finally {
    markRouteReady();
  }
});

async function loadAddress() {
  const { response, data } = await requestJson("/api/address");
  if (!response.ok || !data?.ok) {
    ui.message = resolveApiMessage(data, "Adresa nuk u ngarkua.");
    ui.type = "error";
    return;
  }

  savedAddress.value = data.address ? normalizeAddress(data.address) : null;
  const nextAddress = savedAddress.value || createEmptyAddress();
  initialAddress.value = { ...nextAddress };
  Object.assign(formState, nextAddress);
}

function cancelChanges() {
  Object.assign(formState, initialAddress.value || createEmptyAddress());
  ui.message = "";
  ui.type = "";
}

async function handleSave() {
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
  initialAddress.value = { ...savedAddress.value };
  Object.assign(formState, savedAddress.value);
  ui.message = data.message || "Adresa default u ruajt me sukses.";
  ui.type = "success";
}
</script>

<template>
  <section class="account-page profile-page" aria-label="Adresat">
    <header class="account-header profile-page-header">
      <div>
        <p class="section-label">Adresat</p>
        <h1>Adresa default e perdoruesit</h1>
        <p class="section-text">
          Ketu mund ta ruash adresen tende kryesore. Me vone kjo adrese mund te perdoret per dergesa dhe lidhje me bizneset tjera.
        </p>
      </div>
    </header>

    <section v-if="ui.guest" class="collection-empty-state collection-guest-gate">
      <h2>Per te perdorur adresat duhet te kyçesh.</h2>
      <p>Krijo llogari ose hyni ne llogarine tende per te ruajtur adresen default dhe per ta perdorur ne porosi.</p>
      <div class="collection-guest-gate-actions">
        <RouterLink class="nav-action nav-action-secondary" to="/login?redirect=%2Fadresat">
          Login
        </RouterLink>
        <RouterLink class="nav-action nav-action-primary" to="/signup?redirect=%2Fadresat">
          Sign Up
        </RouterLink>
      </div>
    </section>

    <section v-else class="card address-card">
      <div class="profile-card-header">
        <div>
          <p class="section-label">Adresa aktuale</p>
          <h2>Default address</h2>
        </div>
      </div>

      <div class="form-message" :class="ui.type" role="status" aria-live="polite">
        {{ ui.message }}
      </div>

      <div v-if="!savedAddress" class="collection-empty-state">
        Ende nuk ke ruajtur adrese default. Plotëso formën më poshtë dhe kliko ruaj.
      </div>

      <div v-else class="address-summary-grid">
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
          <strong>Default</strong>
        </div>
      </div>

      <form class="auth-form profile-form" @submit.prevent="handleSave">
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

        <div class="profile-form-actions">
          <button class="profile-save-button" type="submit">Ruaj</button>
          <button class="ghost-button profile-cancel-button" type="button" @click="cancelChanges">Cancel</button>
        </div>
      </form>
    </section>
  </section>
</template>
