<script setup>
import { computed, nextTick, onMounted, reactive, ref } from "vue";
import { RouterLink, useRouter } from "vue-router";
import { requestJson, resolveApiMessage } from "../lib/api";
import { getAccountDashboardMenuItems } from "../lib/account-navigation";
import { createEmptyAddress, normalizeAddress } from "../lib/shop";
import { appState, ensureSessionLoaded, logoutUser, markRouteReady } from "../stores/app-state";

const router = useRouter();
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

const dashboardMenuItems = computed(() => getAccountDashboardMenuItems(appState.user, "address"));

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

async function handleLogout() {
  const { response, data } = await logoutUser();
  if (!response.ok || !data?.ok) {
    ui.message = data?.message || "Dalja nga llogaria nuk funksionoi.";
    ui.type = "error";
    return;
  }

  await router.push("/");
}

function renderDashboardIcon(icon) {
  switch (icon) {
    case "dashboard":
      return "M4 5.5A1.5 1.5 0 0 1 5.5 4H11v6.5H4Zm9 0V4h5.5A1.5 1.5 0 0 1 20 5.5V11h-7ZM4 13h7v7H5.5A1.5 1.5 0 0 1 4 18.5Zm9 0h7v5.5A1.5 1.5 0 0 1 18.5 20H13Z";
    case "orders":
      return "M6 5h12a1 1 0 0 1 1 1v12H5V6a1 1 0 0 1 1-1Zm2 3h8M8 11h8M8 14h5";
    case "pin":
      return "M12 21s6-5.6 6-10.2A6 6 0 1 0 6 10.8C6 15.4 12 21 12 21Zm0-8a2 2 0 1 1 0-4 2 2 0 0 1 0 4Z";
    case "bag":
      return "M4 7h16l-1.4 11.2A2 2 0 0 1 16.6 20H7.4a2 2 0 0 1-2-1.8ZM9 9V6.8A3 3 0 0 1 12 4a3 3 0 0 1 3 2.8V9";
    case "heart":
      return "m12 20.4-1.2-1C5.4 14.6 2 11.5 2 7.8A4.8 4.8 0 0 1 6.8 3 5.3 5.3 0 0 1 12 5.9 5.3 5.3 0 0 1 17.2 3 4.8 4.8 0 0 1 22 7.8c0 3.7-3.4 6.8-8.8 11.6z";
    case "compare":
      return "M6.9 8.7a5.1 5.1 0 0 1 8.7-1.5l1.3-1.3v4.2h-4.2l1.5-1.5a3 3 0 1 0 .9 2.1h2.1a5.1 5.1 0 1 1-10.3 0c0-.3 0-.7.1-1zM17.1 15.3a5.1 5.1 0 0 1-8.7 1.5L7.1 18v-4.2h4.2l-1.5 1.5a3 3 0 1 0-.9-2.1H6.8a5.1 5.1 0 1 1 10.3 0c0 .3 0 .7-.1 1z";
    case "card":
      return "M3 7.5A2.5 2.5 0 0 1 5.5 5h13A2.5 2.5 0 0 1 21 7.5v9a2.5 2.5 0 0 1-2.5 2.5h-13A2.5 2.5 0 0 1 3 16.5Zm0 2.2h18M7 15h3";
    case "history":
      return "M12 6v6l4 2M4.9 7.8H2V3.9m.5 3.9A9 9 0 1 1 5 18";
    case "settings":
      return "M12 8.2a3.8 3.8 0 1 1 0 7.6 3.8 3.8 0 0 1 0-7.6Zm8 4-1.7.8c-.1.4-.3.8-.5 1.2l.7 1.8-1.7 1.7-1.8-.7c-.4.2-.8.4-1.2.5L12 20l-2.4-.7c-.4-.1-.8-.3-1.2-.5l-1.8.7-1.7-1.7.7-1.8c-.2-.4-.4-.8-.5-1.2L4 12.2l.8-2.2c.1-.4.3-.8.5-1.2l-.7-1.8L6.3 5l1.8.7c.4-.2.8-.4 1.2-.5L12 4l2.4.7c.4.1.8.3 1.2.5l1.8-.7 1.7 1.7-.7 1.8c.2.4.4.8.5 1.2Z";
    default:
      return "";
  }
}
</script>

<template>
  <section class="account-page addresses-dashboard-page" aria-label="Address">
    <div class="addresses-breadcrumb-strip">
      <div class="addresses-breadcrumb-inner">
        <nav class="addresses-breadcrumbs" aria-label="Breadcrumb">
          <RouterLink to="/">Home</RouterLink>
          <span>›</span>
          <RouterLink to="/llogaria">User Account</RouterLink>
          <span>›</span>
          <RouterLink to="/llogaria">Dashboard</RouterLink>
          <span>›</span>
          <strong>Address</strong>
        </nav>
      </div>
    </div>

    <div class="form-message" :class="ui.type" role="status" aria-live="polite">
      {{ ui.message }}
    </div>

    <section v-if="ui.guest" class="collection-empty-state collection-guest-gate">
      <h2>Per te perdorur adresat duhet te kyçesh.</h2>
      <p>Krijo llogari ose hyni ne llogarine tende per te ruajtur adresen kryesore dhe per ta perdorur ne porosi.</p>
      <div class="collection-guest-gate-actions">
        <RouterLink class="nav-action nav-action-secondary" to="/login?redirect=%2Fadresat">
          Login
        </RouterLink>
        <RouterLink class="nav-action nav-action-primary" to="/signup?redirect=%2Fadresat">
          Sign Up
        </RouterLink>
      </div>
    </section>

    <div v-else class="addresses-dashboard-layout">
      <aside class="addresses-dashboard-sidebar">
        <div class="addresses-dashboard-sidebar-card">
          <RouterLink
            v-for="item in dashboardMenuItems"
            :key="`${item.href}-${item.label}`"
            class="addresses-dashboard-nav-link"
            :class="{ 'is-active': item.active }"
            :to="item.href"
          >
            <svg viewBox="0 0 24 24" aria-hidden="true">
              <path :d="renderDashboardIcon(item.icon)" />
            </svg>
            <span>{{ item.label }}</span>
          </RouterLink>

          <button class="addresses-dashboard-nav-link addresses-dashboard-nav-button" type="button" @click="handleLogout">
            <svg viewBox="0 0 24 24" aria-hidden="true">
              <path d="M15 5h4v14h-4M10 8l4 4-4 4M14 12H4" />
            </svg>
            <span>Log-out</span>
          </button>
        </div>
      </aside>

      <div class="addresses-dashboard-main">
        <section class="addresses-book-card">
          <div class="addresses-book-head">
            <div>
              <h1>ADDRESS BOOK</h1>
              <p>Këtu ruhen vetëm adresat e faturimit dhe të dërgesës. Kartat nuk ruhen në profil.</p>
            </div>
          </div>

          <div class="addresses-book-grid">
            <article class="address-panel">
              <div class="address-panel-head">
                <h2>Billing Address</h2>
              </div>
              <div class="address-panel-body">
                <strong>{{ addressOwnerName }}</strong>
                <p v-for="line in addressLines" :key="`billing-${line}`">{{ line }}</p>
              </div>
              <button class="address-panel-action" type="button" @click="openEditor('billing')">
                EDIT ADDRESS
              </button>
            </article>

            <article class="address-panel">
              <div class="address-panel-head">
                <h2>Shipping Address</h2>
              </div>
              <div class="address-panel-body">
                <strong>{{ addressOwnerName }}</strong>
                <p v-for="line in addressLines" :key="`shipping-${line}`">{{ line }}</p>
              </div>
              <button class="address-panel-action" type="button" @click="openEditor('shipping')">
                EDIT ADDRESS
              </button>
            </article>
          </div>
        </section>

        <section ref="editorElement" class="addresses-editor-card">
          <div class="addresses-editor-head">
            <h2>{{ editorTitle }}</h2>
          </div>

          <form class="addresses-editor-form" @submit.prevent="handleSave">
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

            <div class="addresses-editor-actions">
              <button class="profile-save-button" type="submit">Ruaj adresen</button>
              <button class="ghost-button profile-cancel-button" type="button" @click="cancelChanges">Cancel</button>
            </div>
          </form>
        </section>
      </div>
    </div>
  </section>
</template>

<style scoped>
.addresses-dashboard-page {
  width: min(1300px, calc(100vw - 48px));
  margin: 0 auto;
  padding: 0 0 80px;
}

.addresses-breadcrumb-strip {
  margin-inline: calc(50% - 50vw);
  border-top: 1px solid rgba(15, 23, 42, 0.06);
  border-bottom: 1px solid rgba(15, 23, 42, 0.06);
  background: #f5f6f8;
}

.addresses-breadcrumb-inner {
  width: min(1300px, calc(100vw - 48px));
  margin: 0 auto;
  padding: 28px 0;
}

.addresses-breadcrumbs {
  display: flex;
  align-items: center;
  gap: 10px;
  flex-wrap: wrap;
  color: #64748b;
  font-size: 1rem;
}

.addresses-breadcrumbs a {
  color: inherit;
  text-decoration: none;
}

.addresses-breadcrumbs strong {
  color: #2496f3;
}

.addresses-dashboard-layout {
  display: grid;
  grid-template-columns: 260px minmax(0, 1fr);
  gap: 38px;
  align-items: start;
  padding-top: 36px;
}

.addresses-dashboard-sidebar-card {
  display: grid;
  background: #fff;
  border: 1px solid rgba(15, 23, 42, 0.08);
  border-radius: 8px;
  overflow: hidden;
  box-shadow: 0 24px 48px rgba(15, 23, 42, 0.06);
}

.addresses-dashboard-nav-link,
.addresses-dashboard-nav-button {
  display: flex;
  align-items: center;
  gap: 14px;
  min-height: 54px;
  padding: 0 22px;
  border: 0;
  border-bottom: 1px solid rgba(15, 23, 42, 0.06);
  background: #fff;
  color: #5b6775;
  text-decoration: none;
  font-size: 1rem;
  font-weight: 500;
  text-align: left;
  cursor: pointer;
}

.addresses-dashboard-nav-link svg,
.addresses-dashboard-nav-button svg {
  width: 20px;
  height: 20px;
  fill: none;
  stroke: currentColor;
  stroke-width: 1.9;
  stroke-linecap: round;
  stroke-linejoin: round;
}

.addresses-dashboard-nav-link.is-active {
  background: #ff7f32;
  color: #fff;
  font-weight: 700;
}

.addresses-dashboard-nav-button {
  border-bottom: 0;
}

.addresses-dashboard-main {
  display: grid;
  gap: 24px;
}

.addresses-book-card,
.addresses-editor-card {
  background: #fff;
  border: 1px solid rgba(15, 23, 42, 0.08);
  border-radius: 8px;
  overflow: hidden;
  box-shadow: 0 24px 48px rgba(15, 23, 42, 0.05);
}

.addresses-book-head,
.addresses-editor-head {
  padding: 18px 24px;
  border-bottom: 1px solid rgba(15, 23, 42, 0.08);
}

.addresses-book-head h1,
.addresses-editor-head h2 {
  margin: 0;
  color: #111827;
  font-size: 1.2rem;
  letter-spacing: -0.02em;
}

.addresses-book-head p {
  margin: 8px 0 0;
  color: #64748b;
  font-size: 0.98rem;
}

.addresses-book-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 24px;
  padding: 24px;
}

.address-panel {
  border: 1px solid rgba(15, 23, 42, 0.08);
}

.address-panel-head {
  padding: 18px 22px;
  border-bottom: 1px solid rgba(15, 23, 42, 0.08);
}

.address-panel-head h2 {
  margin: 0;
  color: #111827;
  font-size: 1.05rem;
}

.address-panel-body {
  display: grid;
  gap: 10px;
  padding: 22px;
}

.address-panel-body strong {
  color: #111827;
  font-size: 1.02rem;
}

.address-panel-body p {
  margin: 0;
  color: #4b5563;
  line-height: 1.55;
}

.address-panel-action {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-height: 44px;
  margin: 0 22px 22px;
  padding: 0 18px;
  border: 1px solid rgba(36, 150, 243, 0.28);
  background: #fff;
  color: #2496f3;
  font-weight: 800;
  cursor: pointer;
}

.addresses-editor-form {
  display: grid;
  gap: 18px;
  padding: 24px;
}

.addresses-editor-actions {
  display: flex;
  gap: 12px;
  flex-wrap: wrap;
}

@media (max-width: 1080px) {
  .addresses-dashboard-layout,
  .addresses-book-grid {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 720px) {
  .addresses-dashboard-page,
  .addresses-breadcrumb-inner {
    width: min(100vw - 24px, 1300px);
  }

  .addresses-dashboard-page {
    padding-bottom: 48px;
  }

  .addresses-dashboard-layout {
    gap: 24px;
    padding-top: 24px;
  }

  .addresses-dashboard-nav-link,
  .addresses-dashboard-nav-button {
    min-height: 50px;
    padding-inline: 16px;
    font-size: 0.95rem;
  }

  .addresses-book-head,
  .addresses-editor-head,
  .addresses-book-grid,
  .addresses-editor-form {
    padding-inline: 16px;
  }

  .address-panel-head,
  .address-panel-body {
    padding-inline: 16px;
  }

  .address-panel-action {
    margin-inline: 16px;
  }
}
</style>
