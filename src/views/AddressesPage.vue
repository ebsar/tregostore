<script setup>
import { computed, nextTick, onMounted, reactive, ref } from "vue";
import { RouterLink } from "vue-router";
import AccountUtilityShell from "../components/account/AccountUtilityShell.vue";
import { requestJson, resolveApiMessage } from "../lib/api";
import { createEmptyAddress, normalizeAddress } from "../lib/shop";
import { appState, ensureSessionLoaded, markRouteReady } from "../stores/app-state";
const savedAddress = ref(null);
const initialAddress = ref(createEmptyAddress());
const formState = reactive(createEmptyAddress());
const activeAddressMode = ref("shipping");
const editorElement = ref(null);
const ui = reactive({
  message: "",
  type: "",
  guest: false,
});

const addressOwnerName = computed(() =>
  String(appState.user?.fullName || appState.user?.businessName || "Tregio User").trim(),
);

const addressLines = computed(() => {
  const address = savedAddress.value;
  if (!address) {
    return ["Nuk ke ruajtur ende një adresë kryesore."];
  }

  const lines = [
    String(address.addressLine || "").trim(),
    [String(address.city || "").trim(), String(address.country || "").trim()].filter(Boolean).join(", "),
    String(address.zipCode || "").trim() ? `ZIP: ${String(address.zipCode || "").trim()}` : "",
    String(address.phoneNumber || "").trim() ? `Phone Number: ${String(address.phoneNumber || "").trim()}` : "",
    String(appState.user?.email || "").trim() ? `Email: ${String(appState.user?.email || "").trim()}` : "",
  ].filter(Boolean);

  return lines.length > 0 ? lines : ["Nuk ke ruajtur ende një adresë kryesore."];
});

const editorTitle = computed(() =>
  activeAddressMode.value === "billing" ? "Edit Billing Address" : "Edit Shipping Address",
);

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
  ui.message = data.message || "Adresa u ruajt me sukses.";
  ui.type = "success";
}

async function openEditor(mode) {
  activeAddressMode.value = mode;
  await nextTick();
  editorElement.value?.scrollIntoView({ behavior: "smooth", block: "start" });
}
</script>

<template>
  <AccountUtilityShell
    v-if="!ui.guest"
    active-key="address"
    eyebrow="Customer account"
    title="Address book"
    description="Keep one clean billing and shipping profile ready so checkout stays fast on every order."
    :status-message="ui.message"
    :status-type="ui.type"
    search-placeholder="Search dashboard, orders, returns"
  >
    <div class="account-workspace">
      <section class="account-card">
        <div class="account-card__header">
          <div>
            <h2>Saved address details</h2>
            <p>Billing and shipping currently use the same stored profile for a faster checkout flow.</p>
          </div>
        </div>

        <div class="account-address-grid">
          <article class="account-card account-address-card">
            <div class="account-card__header">
              <div>
                <h2>Billing address</h2>
                <p>Used for invoices and payment details.</p>
              </div>
              <button class="market-button market-button--secondary" type="button" @click="openEditor('billing')">
                Edit
              </button>
            </div>

            <div class="account-address-card__lines">
              <strong>{{ addressOwnerName }}</strong>
              <p v-for="line in addressLines" :key="`billing-${line}`">{{ line }}</p>
            </div>
          </article>

          <article class="account-card account-address-card">
            <div class="account-card__header">
              <div>
                <h2>Shipping address</h2>
                <p>Used for deliveries and courier updates.</p>
              </div>
              <button class="market-button market-button--secondary" type="button" @click="openEditor('shipping')">
                Edit
              </button>
            </div>

            <div class="account-address-card__lines">
              <strong>{{ addressOwnerName }}</strong>
              <p v-for="line in addressLines" :key="`shipping-${line}`">{{ line }}</p>
            </div>
          </article>
        </div>
      </section>

      <section ref="editorElement" class="account-card">
        <div class="account-card__header">
          <div>
            <h2>{{ editorTitle }}</h2>
            <p>Update the address once and keep it ready for both billing and delivery.</p>
          </div>
          <div class="dashboard-utility-hero__meta">
            <button
              class="market-pill"
              :class="{ 'market-pill--accent': activeAddressMode === 'billing' }"
              type="button"
              @click="activeAddressMode = 'billing'"
            >
              Billing
            </button>
            <button
              class="market-pill"
              :class="{ 'market-pill--accent': activeAddressMode === 'shipping' }"
              type="button"
              @click="activeAddressMode = 'shipping'"
            >
              Shipping
            </button>
          </div>
        </div>

        <form class="account-form" @submit.prevent="handleSave">
          <div class="account-form__grid">
            <label>
              <span>Street address</span>
              <input v-model="formState.addressLine" type="text" placeholder="Street, building, apartment" required>
            </label>

            <div class="account-form__row">
              <label>
                <span>City</span>
                <input v-model="formState.city" type="text" placeholder="City" required>
              </label>

              <label>
                <span>Country</span>
                <input v-model="formState.country" type="text" placeholder="Country" required>
              </label>
            </div>

            <div class="account-form__row">
              <label>
                <span>ZIP code</span>
                <input v-model="formState.zipCode" type="text" placeholder="ZIP code" required>
              </label>

              <label>
                <span>Phone number</span>
                <input v-model="formState.phoneNumber" type="tel" placeholder="+383 44 123 456" required>
              </label>
            </div>
          </div>

          <div class="account-form__actions">
            <button class="market-button market-button--primary" type="submit">
              Save address
            </button>
            <button class="market-button market-button--secondary" type="button" @click="cancelChanges">
              Cancel
            </button>
          </div>
        </form>
      </section>
    </div>
  </AccountUtilityShell>

  <section v-else class="market-page market-page--wide dashboard-page" aria-label="Address">
    <div class="market-empty account-gate">
      <h2>Sign in to manage your addresses</h2>
      <p>Create an account or log in to keep a default billing and shipping address ready for checkout.</p>
      <div class="account-gate__actions">
        <RouterLink class="market-button market-button--primary" to="/login?redirect=%2Fadresat">
          Login
        </RouterLink>
        <RouterLink class="market-button market-button--secondary" to="/signup?redirect=%2Fadresat">
          Sign up
        </RouterLink>
      </div>
    </div>
  </section>
</template>
