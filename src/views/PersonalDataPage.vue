<script setup>
import { computed, onBeforeUnmount, onMounted, reactive, ref } from "vue";
import { RouterLink, useRouter } from "vue-router";
import AccountUtilityShell from "../components/account/AccountUtilityShell.vue";
import PasswordToggleButton from "../components/PasswordToggleButton.vue";
import { requestJson, resolveApiMessage, uploadProfilePhoto } from "../lib/api";
import { createEmptyAddress, getBusinessInitials, getProfileValuesFromUser, normalizeAddress } from "../lib/shop";
import { appState, ensureSessionLoaded, markRouteReady, refreshSession } from "../stores/app-state";

const router = useRouter();
const profileImageInput = ref(null);
const avatarMenuRef = ref(null);
const previewUrl = ref("");
const fileName = ref("Nuk eshte zgjedhur asnje foto.");
const avatarMenuOpen = ref(false);
const avatarMarkedForRemoval = ref(false);
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
const deletePasswordVisible = ref(false);

const previewImage = computed(() => previewUrl.value || formState.profileImagePath || "");
const placeholderInitials = computed(() => getBusinessInitials(formState.fullName || formState.displayName || "User"));

onMounted(async () => {
  window.addEventListener("click", handleAvatarOutsideClick);
  window.addEventListener("keydown", handleAvatarKeydown);

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
  window.removeEventListener("click", handleAvatarOutsideClick);
  window.removeEventListener("keydown", handleAvatarKeydown);

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
  avatarMarkedForRemoval.value = false;
  avatarMenuOpen.value = false;
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

function toggleAvatarMenu() {
  avatarMenuOpen.value = !avatarMenuOpen.value;
}

function closeAvatarMenu() {
  avatarMenuOpen.value = false;
}

function handleAvatarOutsideClick(event) {
  if (!avatarMenuOpen.value) {
    return;
  }

  if (avatarMenuRef.value?.contains(event.target)) {
    return;
  }

  closeAvatarMenu();
}

function handleAvatarKeydown(event) {
  if (event.key === "Escape") {
    closeAvatarMenu();
  }
}

function openProfileImagePicker() {
  closeAvatarMenu();
  profileImageInput.value?.click();
}

function clearProfilePhoto() {
  clearPickedFile();
  formState.profileImagePath = "";
  avatarMarkedForRemoval.value = true;
  fileName.value = "Foto do te hiqet pas ruajtjes.";
  closeAvatarMenu();
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
  avatarMarkedForRemoval.value = false;
  closeAvatarMenu();
}

function cancelChanges() {
  if (!initialProfile.value) {
    return;
  }

  Object.assign(formState, initialProfile.value);
  clearPickedFile();
  avatarMarkedForRemoval.value = false;
  closeAvatarMenu();
  ui.message = "";
  ui.type = "";
}

async function handleSave() {
  ui.message = "";
  ui.type = "";

  let profileImagePath = avatarMarkedForRemoval.value ? "" : initialProfile.value?.profileImagePath || "";
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
</script>

<template>
  <AccountUtilityShell
    v-if="appState.user"
    active-key="settings"
    eyebrow="Account settings"
    title="Personal details"
    description="Keep your public profile, contact details, and delivery information accurate so the marketplace stays personalized and checkout-ready."
    :status-message="ui.message"
    :status-type="ui.type"
    search-placeholder="Search settings, addresses, notifications"
  >
    <div class="account-workspace account-workspace--split">
      <section class="account-card">
        <div class="account-card__header">
          <div>
            <h2>Profile information</h2>
            <p>Everything here stays connected to your account, saved orders, and delivery details.</p>
          </div>
        </div>

        <form class="account-form" @submit.prevent="handleSave">
          <div class="account-profile-head">
            <div class="account-avatar-field">
              <div ref="avatarMenuRef" class="account-avatar-field__shell">
                <button
                  class="account-avatar-field__preview-button"
                  type="button"
                  aria-label="Open profile photo menu"
                  @click.stop="toggleAvatarMenu"
                >
                  <span class="account-avatar-field__preview">
                    <img v-if="previewImage" :src="previewImage" alt="Profile preview">
                    <span v-else>{{ placeholderInitials }}</span>
                  </span>
                </button>

                <button
                  class="account-avatar-field__menu-button"
                  type="button"
                  aria-label="Profile photo options"
                  :aria-expanded="avatarMenuOpen"
                  @click.stop="toggleAvatarMenu"
                >
                  <span aria-hidden="true"></span>
                </button>

                <div v-if="avatarMenuOpen" class="account-avatar-field__menu" role="menu">
                  <button class="account-avatar-field__menu-item" type="button" role="menuitem" @click="openProfileImagePicker">
                    Change photo
                  </button>
                  <button class="account-avatar-field__menu-item" type="button" role="menuitem" @click="clearProfilePhoto">
                    Clear photo
                  </button>
                </div>

                <input
                  id="settings-profile-image"
                  ref="profileImageInput"
                  class="account-avatar-field__file"
                  name="profileImage"
                  type="file"
                  accept="image/*"
                  @change="handleImageChange"
                >
              </div>
            </div>

            <div class="account-profile-head__fields">
              <label>
                <span>First name</span>
                <input v-model="formState.displayName" type="text" placeholder="First name" required>
              </label>

              <label>
                <span>Last name</span>
                <input v-model="formState.fullName" type="text" placeholder="Last name" required>
              </label>
            </div>
          </div>

          <div class="account-form__grid">
            <div class="account-form__row">
              <label>
                <span>Email</span>
                <input v-model="formState.email" type="email" readonly>
              </label>

              <label>
                <span>Phone number</span>
                <input v-model="formState.phoneNumber" type="tel" placeholder="+383 44 123 456">
              </label>
            </div>

            <div class="account-form__row">
              <label>
                <span>Birth date</span>
                <input v-model="formState.birthDate" type="date">
              </label>

              <label>
                <span>Gender</span>
                <select v-model="formState.gender">
                  <option value="">Select gender</option>
                  <option value="mashkull">Male</option>
                  <option value="femer">Female</option>
                  <option value="tjeter">Other</option>
                </select>
              </label>
            </div>

            <div class="account-form__row--triple">
              <label>
                <span>Country / Region</span>
                <input v-model="formState.country" type="text" placeholder="Kosovo">
              </label>

              <label>
                <span>City</span>
                <input v-model="formState.city" type="text" placeholder="Prishtine">
              </label>

              <label>
                <span>ZIP code</span>
                <input v-model="formState.zipCode" type="text" placeholder="10000">
              </label>
            </div>

            <label>
              <span>Street address</span>
              <input v-model="formState.addressLine" type="text" placeholder="Street, building, apartment">
            </label>
          </div>

          <div class="account-form__actions">
            <button class="market-button market-button--primary" type="submit">
              Save changes
            </button>
            <button class="market-button market-button--secondary" type="button" @click="cancelChanges">
              Cancel
            </button>
          </div>
        </form>
      </section>

      <div class="account-stack">
        <section class="account-card">
          <div class="account-card__header">
            <div>
              <h2>Quick actions</h2>
              <p>Existing account tools that were already supported are now easier to reach from settings.</p>
            </div>
          </div>

          <div class="account-action-list">
            <RouterLink class="market-button market-button--secondary" to="/ndrysho-fjalekalimin">
              Change password
            </RouterLink>
            <RouterLink class="market-button market-button--secondary" to="/adresat">
              Manage addresses
            </RouterLink>
            <RouterLink class="market-button market-button--secondary" to="/njoftimet">
              View notifications
            </RouterLink>
            <RouterLink class="market-button market-button--secondary" to="/refund-returne">
              Refunds & returns
            </RouterLink>
          </div>
        </section>

        <section class="account-card account-card--danger">
          <div class="account-card__header">
            <div>
              <h2>Danger zone</h2>
              <p>If you confirm your password below, the account will be deleted permanently from the system.</p>
            </div>
          </div>

          <form class="account-form" @submit.prevent="handleDelete">
            <label>
              <span>Password</span>
              <div class="password-control">
                <input
                  v-model="deletePassword"
                  :type="deletePasswordVisible ? 'text' : 'password'"
                  placeholder="Enter your password to delete the account"
                  required
                >
                <PasswordToggleButton
                  :visible="deletePasswordVisible"
                  @toggle="deletePasswordVisible = !deletePasswordVisible"
                />
              </div>
            </label>

            <div class="account-form__actions">
              <button class="market-button market-button--primary" type="submit">
                Delete account
              </button>
            </div>
          </form>

          <div
            v-if="ui.deleteMessage"
            class="market-status"
            :class="{ 'market-status--error': ui.deleteType === 'error', 'market-status--success': ui.deleteType === 'success' }"
            role="status"
            aria-live="polite"
          >
            {{ ui.deleteMessage }}
          </div>
        </section>
      </div>
    </div>
  </AccountUtilityShell>
</template>
