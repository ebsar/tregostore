<script setup>
import { computed, onBeforeUnmount, onMounted, reactive, ref } from "vue";
import { RouterLink, useRouter } from "vue-router";
import { requestJson, resolveApiMessage, uploadProfilePhoto } from "../lib/api";
import { getAccountDashboardMenuItems } from "../lib/account-navigation";
import { createEmptyAddress, getBusinessInitials, getProfileValuesFromUser, normalizeAddress } from "../lib/shop";
import { appState, ensureSessionLoaded, logoutUser, markRouteReady, refreshSession } from "../stores/app-state";

const router = useRouter();
const profileImageInput = ref(null);
const previewUrl = ref("");
const fileName = ref("Nuk eshte zgjedhur asnje foto.");
const initialProfile = ref(null);
const savedAddress = ref(createEmptyAddress());
const formState = reactive({
  displayName: "",
  fullName: "",
  userName: "",
  email: "",
  secondaryEmail: "",
  phoneNumber: "",
  country: "",
  city: "",
  zipCode: "",
  addressLine: "",
  birthDate: "",
  gender: "",
  profileImagePath: "",
});
const ui = reactive({
  message: "",
  type: "",
  deleteMessage: "",
  deleteType: "",
});
const deletePassword = ref("");

const previewImage = computed(() => previewUrl.value || formState.profileImagePath || "");
const placeholderInitials = computed(() => getBusinessInitials(formState.fullName || formState.displayName || "User"));

const dashboardMenuItems = computed(() => getAccountDashboardMenuItems(appState.user, "settings"));

onMounted(async () => {
  try {
    const user = await ensureSessionLoaded();
    if (!user) {
      router.replace("/login");
      return;
    }

    await loadAddress();
    hydrateForm(user);
  } finally {
    markRouteReady();
  }
});

onBeforeUnmount(() => {
  if (previewUrl.value) {
    URL.revokeObjectURL(previewUrl.value);
  }
});

async function loadAddress() {
  const { response, data } = await requestJson("/api/address");
  if (!response.ok || !data?.ok) {
    savedAddress.value = createEmptyAddress();
    return;
  }

  savedAddress.value = data.address ? normalizeAddress(data.address) : createEmptyAddress();
}

function hydrateForm(user) {
  const values = getProfileValuesFromUser(user);
  const fullName = String(user?.fullName || `${values.firstName} ${values.lastName}` || "").trim();
  const displayName = values.firstName || fullName.split(/\s+/).filter(Boolean)[0] || "";
  const usernameFromEmail = String(user?.email || "").trim().split("@")[0] || displayName.toLowerCase().replace(/\s+/g, ".");

  formState.displayName = displayName;
  formState.fullName = fullName;
  formState.userName = usernameFromEmail;
  formState.email = String(user?.email || "").trim();
  formState.secondaryEmail = String(user?.secondaryEmail || user?.email || "").trim();
  formState.phoneNumber = String(savedAddress.value?.phoneNumber || user?.phoneNumber || "").trim();
  formState.country = String(savedAddress.value?.country || "").trim();
  formState.city = String(savedAddress.value?.city || "").trim();
  formState.zipCode = String(savedAddress.value?.zipCode || "").trim();
  formState.addressLine = String(savedAddress.value?.addressLine || "").trim();
  formState.birthDate = values.birthDate;
  formState.gender = values.gender;
  formState.profileImagePath = values.profileImagePath;

  initialProfile.value = {
    ...formState,
  };
  clearPickedFile();
}

function clearPickedFile() {
  if (previewUrl.value) {
    URL.revokeObjectURL(previewUrl.value);
    previewUrl.value = "";
  }
  fileName.value = "Nuk eshte zgjedhur asnje foto.";
  if (profileImageInput.value) {
    profileImageInput.value.value = "";
  }
}

function handleImageChange(event) {
  const file = event.target.files?.[0];
  if (!file) {
    clearPickedFile();
    return;
  }

  if (previewUrl.value) {
    URL.revokeObjectURL(previewUrl.value);
  }
  previewUrl.value = URL.createObjectURL(file);
  fileName.value = `Foto e zgjedhur: ${file.name}`;
}

function cancelChanges() {
  if (!initialProfile.value) {
    return;
  }

  Object.assign(formState, initialProfile.value);
  clearPickedFile();
  ui.message = "";
  ui.type = "";
}

async function handleSave() {
  ui.message = "";
  ui.type = "";

  let profileImagePath = initialProfile.value?.profileImagePath || "";
  const selectedFile = profileImageInput.value?.files?.[0];

  if (selectedFile) {
    const result = await uploadProfilePhoto(selectedFile);
    if (!result.ok) {
      ui.message = result.message;
      ui.type = "error";
      return;
    }
    profileImagePath = result.path;
  }

  const normalizedFullName = String(formState.fullName || formState.displayName || "").trim();
  const nameParts = normalizedFullName.split(/\s+/).filter(Boolean);
  const firstName = String(formState.displayName || nameParts[0] || "").trim();
  const lastName = nameParts.length > 1 ? nameParts.slice(1).join(" ") : "";

  const profilePayload = {
    firstName,
    lastName,
    birthDate: formState.birthDate || initialProfile.value?.birthDate || "",
    gender: formState.gender || initialProfile.value?.gender || "mashkull",
    profileImagePath,
  };

  const { response, data } = await requestJson("/api/profile", {
    method: "POST",
    body: JSON.stringify(profilePayload),
  });

  if (!response.ok || !data?.ok || !data.user) {
    ui.message = resolveApiMessage(data, "Ruajtja e te dhenave nuk funksionoi.");
    ui.type = "error";
    return;
  }

  const addressPayload = {
    addressLine: String(formState.addressLine || "").trim(),
    city: String(formState.city || "").trim(),
    country: String(formState.country || "").trim(),
    zipCode: String(formState.zipCode || "").trim(),
    phoneNumber: String(formState.phoneNumber || "").trim(),
  };

  const shouldSaveAddress = Object.values(addressPayload).some(Boolean);
  if (shouldSaveAddress) {
    const addressResult = await requestJson("/api/address", {
      method: "POST",
      body: JSON.stringify(addressPayload),
    });

    if (!addressResult.response.ok || !addressResult.data?.ok || !addressResult.data.address) {
      ui.message = "Profili u ruajt, por adresa nuk u ruajt. Plotëso edhe adresën e plotë.";
      ui.type = "error";
      await refreshSession();
      hydrateForm(data.user);
      return;
    }

    savedAddress.value = normalizeAddress(addressResult.data.address);
  }

  await refreshSession();
  hydrateForm(data.user);
  ui.message = data.message || "Te dhenat personale u ruajten me sukses.";
  ui.type = "success";
}

async function handleDelete() {
  ui.deleteMessage = "";
  const shouldDelete = window.confirm("A je i sigurt qe deshiron ta fshish komplet llogarine?");
  if (!shouldDelete) {
    return;
  }

  const { response, data } = await requestJson("/api/account/delete", {
    method: "POST",
    body: JSON.stringify({ password: deletePassword.value }),
  });

  if (!response.ok || !data?.ok) {
    ui.deleteMessage = resolveApiMessage(data, "Fshirja e llogarise nuk funksionoi.");
    ui.deleteType = "error";
    return;
  }

  ui.deleteMessage = data.message || "Llogaria u fshi me sukses.";
  ui.deleteType = "success";
  window.setTimeout(() => {
    router.push(data.redirectTo || "/signup");
  }, 800);
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
  <section class="account-page settings-dashboard-page" aria-label="Setting">
    <div class="settings-breadcrumb-strip">
      <div class="settings-breadcrumb-inner">
        <nav class="settings-breadcrumbs" aria-label="Breadcrumb">
          <RouterLink to="/">Home</RouterLink>
          <span>›</span>
          <RouterLink to="/llogaria">User Account</RouterLink>
          <span>›</span>
          <RouterLink to="/llogaria">Dashboard</RouterLink>
          <span>›</span>
          <strong>Setting</strong>
        </nav>
      </div>
    </div>

    <div class="form-message" :class="ui.type" role="status" aria-live="polite">
      {{ ui.message }}
    </div>

    <div v-if="appState.user" class="settings-dashboard-layout">
      <aside class="settings-dashboard-sidebar">
        <div class="settings-dashboard-sidebar-card">
          <RouterLink
            v-for="item in dashboardMenuItems"
            :key="`${item.href}-${item.label}`"
            class="settings-dashboard-nav-link"
            :class="{ 'is-active': item.active }"
            :to="item.href"
          >
            <svg viewBox="0 0 24 24" aria-hidden="true">
              <path :d="renderDashboardIcon(item.icon)" />
            </svg>
            <span>{{ item.label }}</span>
          </RouterLink>

          <button class="settings-dashboard-nav-link settings-dashboard-nav-button" type="button" @click="handleLogout">
            <svg viewBox="0 0 24 24" aria-hidden="true">
              <path d="M15 5h4v14h-4M10 8l4 4-4 4M14 12H4" />
            </svg>
            <span>Log-out</span>
          </button>
        </div>
      </aside>

      <div class="settings-dashboard-main">
        <section class="settings-card">
          <div class="settings-card-head">
            <h1>Account Setting</h1>
          </div>

          <form class="settings-form" @submit.prevent="handleSave">
            <div class="settings-profile-column">
              <div class="settings-avatar">
                <img v-if="previewImage" class="settings-avatar-image" :src="previewImage" alt="Foto e profilit">
                <div v-else class="settings-avatar-placeholder">{{ placeholderInitials }}</div>
              </div>

              <label class="settings-photo-button" for="settings-profile-image">
                Change photo
              </label>
              <input
                id="settings-profile-image"
                ref="profileImageInput"
                class="settings-photo-input"
                name="profileImage"
                type="file"
                accept="image/*"
                @change="handleImageChange"
              >
              <p class="settings-photo-file-name">{{ fileName }}</p>
            </div>

            <div class="settings-fields-column">
              <div class="field-row">
                <label class="field">
                  <span>Display name</span>
                  <input v-model="formState.displayName" type="text" placeholder="Display name" required>
                </label>

                <label class="field">
                  <span>Username</span>
                  <input v-model="formState.userName" type="text" readonly class="is-readonly">
                </label>
              </div>

              <div class="field-row">
                <label class="field">
                  <span>Full Name</span>
                  <input v-model="formState.fullName" type="text" placeholder="Full name" required>
                </label>

                <label class="field">
                  <span>Email</span>
                  <input v-model="formState.email" type="email" readonly class="is-readonly">
                </label>
              </div>

              <div class="field-row">
                <label class="field">
                  <span>Secondary Email</span>
                  <input v-model="formState.secondaryEmail" type="email" readonly class="is-readonly">
                </label>

                <label class="field">
                  <span>Phone Number</span>
                  <input v-model="formState.phoneNumber" type="tel" placeholder="+383 44 123 456">
                </label>
              </div>

              <div class="field-row field-row--three">
                <label class="field">
                  <span>Country/Region</span>
                  <input v-model="formState.country" type="text" placeholder="Kosove">
                </label>

                <label class="field">
                  <span>States</span>
                  <input v-model="formState.city" type="text" placeholder="Prishtine">
                </label>

                <label class="field">
                  <span>Zip Code</span>
                  <input v-model="formState.zipCode" type="text" placeholder="10000">
                </label>
              </div>

              <label class="field">
                <span>Street Address</span>
                <input v-model="formState.addressLine" type="text" placeholder="Rruga, objekti, apartamenti">
              </label>

              <div class="settings-actions">
                <button class="settings-save-button" type="submit">SAVE CHANGES</button>
                <button class="ghost-button profile-cancel-button" type="button" @click="cancelChanges">Cancel</button>
              </div>
            </div>
          </form>
        </section>

        <section class="settings-danger-card">
          <div class="settings-card-head">
            <h2>Danger Zone</h2>
          </div>

          <div class="settings-danger-body">
            <div>
              <p class="section-text">
                Nese e shkruan fjalekalimin dhe e konfirmon, llogaria do te fshihet komplet nga sistemi.
              </p>
            </div>

            <form class="settings-danger-form" @submit.prevent="handleDelete">
              <label class="field">
                <span>Fjalekalimi</span>
                <input v-model="deletePassword" type="password" placeholder="Shkruaje fjalekalimin per fshirje" required>
              </label>

              <button class="profile-delete-button" type="submit">Fshije llogarine</button>
            </form>

            <div class="form-message" :class="ui.deleteType" role="status" aria-live="polite">
              {{ ui.deleteMessage }}
            </div>
          </div>
        </section>
      </div>
    </div>
  </section>
</template>

<style scoped>
.settings-dashboard-page {
  width: min(1300px, calc(100vw - 48px));
  margin: 0 auto;
  padding: 0 0 80px;
}

.settings-breadcrumb-strip {
  margin-inline: calc(50% - 50vw);
  border-top: 1px solid rgba(15, 23, 42, 0.06);
  border-bottom: 1px solid rgba(15, 23, 42, 0.06);
  background: #f5f6f8;
}

.settings-breadcrumb-inner {
  width: min(1300px, calc(100vw - 48px));
  margin: 0 auto;
  padding: 28px 0;
}

.settings-breadcrumbs {
  display: flex;
  align-items: center;
  gap: 10px;
  flex-wrap: wrap;
  color: #64748b;
  font-size: 1rem;
}

.settings-breadcrumbs a {
  color: inherit;
  text-decoration: none;
}

.settings-breadcrumbs strong {
  color: #2496f3;
}

.settings-dashboard-layout {
  display: grid;
  grid-template-columns: 260px minmax(0, 1fr);
  gap: 38px;
  align-items: start;
  padding-top: 36px;
}

.settings-dashboard-sidebar-card {
  display: grid;
  background: #fff;
  border: 1px solid rgba(15, 23, 42, 0.08);
  border-radius: 8px;
  overflow: hidden;
  box-shadow: 0 24px 48px rgba(15, 23, 42, 0.06);
}

.settings-dashboard-nav-link,
.settings-dashboard-nav-button {
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

.settings-dashboard-nav-link svg,
.settings-dashboard-nav-button svg {
  width: 20px;
  height: 20px;
  fill: none;
  stroke: currentColor;
  stroke-width: 1.9;
  stroke-linecap: round;
  stroke-linejoin: round;
}

.settings-dashboard-nav-link.is-active {
  background: #ff7f32;
  color: #fff;
  font-weight: 700;
}

.settings-dashboard-nav-button {
  border-bottom: 0;
}

.settings-dashboard-main {
  display: grid;
  gap: 24px;
}

.settings-card,
.settings-danger-card {
  background: #fff;
  border: 1px solid rgba(15, 23, 42, 0.08);
  border-radius: 8px;
  overflow: hidden;
  box-shadow: 0 24px 48px rgba(15, 23, 42, 0.05);
}

.settings-card-head {
  padding: 18px 24px;
  border-bottom: 1px solid rgba(15, 23, 42, 0.08);
}

.settings-card-head h1,
.settings-card-head h2 {
  margin: 0;
  color: #202833;
  font-size: 1.15rem;
  letter-spacing: -0.02em;
}

.settings-form {
  display: grid;
  grid-template-columns: 180px minmax(0, 1fr);
  gap: 24px;
  padding: 24px;
}

.settings-profile-column {
  display: grid;
  justify-items: center;
  align-content: start;
  gap: 14px;
}

.settings-avatar {
  width: 176px;
  height: 176px;
  display: grid;
  place-items: center;
  overflow: hidden;
  border-radius: 999px;
  background: linear-gradient(135deg, #0d7ec8, #31a6ef);
}

.settings-avatar-image {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.settings-avatar-placeholder {
  color: #fff;
  font-size: 3rem;
  font-weight: 800;
}

.settings-photo-button {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-height: 42px;
  padding: 0 18px;
  border-radius: 999px;
  background: #f5f6f8;
  color: #202833;
  font-weight: 700;
  cursor: pointer;
}

.settings-photo-input {
  display: none;
}

.settings-photo-file-name {
  margin: 0;
  color: #64748b;
  font-size: 0.82rem;
  text-align: center;
}

.settings-fields-column {
  display: grid;
  gap: 18px;
}

.field.is-readonly input,
.is-readonly {
  background: #fbfcfd;
}

.field-row--three {
  grid-template-columns: minmax(0, 1.2fr) minmax(0, 1fr) 168px;
}

.settings-actions {
  display: flex;
  gap: 12px;
  flex-wrap: wrap;
}

.settings-save-button {
  min-height: 46px;
  padding: 0 24px;
  border: 0;
  border-radius: 2px;
  background: #ff7f32;
  color: #fff;
  font-weight: 800;
  cursor: pointer;
}

.settings-danger-body {
  display: grid;
  gap: 18px;
  padding: 24px;
}

.settings-danger-form {
  display: flex;
  align-items: end;
  gap: 12px;
  flex-wrap: wrap;
}

@media (max-width: 1080px) {
  .settings-dashboard-layout,
  .settings-form {
    grid-template-columns: 1fr;
  }

  .settings-profile-column {
    justify-items: start;
  }
}

@media (max-width: 720px) {
  .settings-dashboard-page,
  .settings-breadcrumb-inner {
    width: min(100vw - 24px, 1300px);
  }

  .settings-dashboard-page {
    padding-bottom: 48px;
  }

  .settings-dashboard-layout {
    gap: 24px;
    padding-top: 24px;
  }

  .settings-dashboard-nav-link,
  .settings-dashboard-nav-button {
    min-height: 50px;
    padding-inline: 16px;
    font-size: 0.95rem;
  }

  .settings-card-head,
  .settings-form,
  .settings-danger-body {
    padding-inline: 16px;
  }

  .field-row--three {
    grid-template-columns: 1fr;
  }

  .settings-actions,
  .settings-danger-form {
    display: grid;
  }

  .settings-save-button,
  .profile-delete-button,
  .profile-cancel-button {
    width: 100%;
  }

  .settings-avatar {
    width: 148px;
    height: 148px;
  }
}
</style>
