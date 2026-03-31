<script setup>
import { computed, onBeforeUnmount, onMounted, reactive, ref } from "vue";
import { useRouter } from "vue-router";
import { requestJson, resolveApiMessage, uploadProfilePhoto } from "../lib/api";
import { formatDateLabel, getBusinessInitials, getProfileValuesFromUser } from "../lib/shop";
import { appState, ensureSessionLoaded, markRouteReady, refreshSession } from "../stores/app-state";

const router = useRouter();
const profileImageInput = ref(null);
const previewUrl = ref("");
const fileName = ref("Nuk eshte zgjedhur asnje foto.");
const initialProfile = ref(null);
const formState = reactive({
  firstName: "",
  lastName: "",
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
const placeholderInitials = computed(() => getBusinessInitials(`${formState.firstName} ${formState.lastName}`.trim() || "User"));

onMounted(async () => {
  try {
    const user = await ensureSessionLoaded();
    if (!user) {
      router.replace("/login");
      return;
    }

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

function hydrateForm(user) {
  const values = getProfileValuesFromUser(user);
  formState.firstName = values.firstName;
  formState.lastName = values.lastName;
  formState.birthDate = values.birthDate;
  formState.gender = values.gender;
  formState.profileImagePath = values.profileImagePath;
  initialProfile.value = { ...values };
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

  formState.firstName = initialProfile.value.firstName;
  formState.lastName = initialProfile.value.lastName;
  formState.birthDate = initialProfile.value.birthDate;
  formState.gender = initialProfile.value.gender;
  formState.profileImagePath = initialProfile.value.profileImagePath;
  clearPickedFile();
  ui.message = "";
  ui.type = "";
}

async function handleSave() {
  ui.message = "";
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

  const payload = {
    firstName: formState.firstName.trim(),
    lastName: formState.lastName.trim(),
    birthDate: formState.birthDate,
    gender: formState.gender,
    profileImagePath,
  };

  const { response, data } = await requestJson("/api/profile", {
    method: "POST",
    body: JSON.stringify(payload),
  });

  if (!response.ok || !data?.ok || !data.user) {
    ui.message = resolveApiMessage(data, "Ruajtja e te dhenave nuk funksionoi.");
    ui.type = "error";
    return;
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
  <section class="account-page profile-page" aria-label="Te dhenat personale">
    <header class="account-header profile-page-header">
      <div>
        <p class="section-label">Profili</p>
        <h1>Te dhenat personale</h1>
        <p class="section-text">
          Ndrysho emrin, mbiemrin, daten e lindjes dhe gjinine. Kur klikon ruaj, ndryshimet ruhen direkt ne databaze.
        </p>
      </div>
    </header>

    <section class="card profile-card" v-if="appState.user">
      <div class="profile-card-header">
        <div>
          <p class="section-label">Informacioni yt</p>
          <h2>Perditeso profilin</h2>
        </div>

        <div class="profile-card-header-actions">
          <div class="summary-chip profile-summary-chip">
            <span>Email</span>
            <strong>{{ appState.user.email || "-" }}</strong>
          </div>
          <a
            class="ghost-button profile-liquid-glass-link"
            href="/liquid-glass"
            target="_blank"
            rel="noopener"
          >
            Liquid glass
          </a>
        </div>
      </div>

      <div class="form-message" :class="ui.type" role="status" aria-live="polite">
        {{ ui.message }}
      </div>

      <form class="auth-form profile-form" @submit.prevent="handleSave">
        <section class="profile-photo-section" aria-label="Foto e profilit">
          <div class="profile-photo-preview">
            <img v-if="previewImage" class="profile-photo-image" :src="previewImage" alt="Foto e profilit">
            <div v-else class="profile-photo-placeholder">{{ placeholderInitials }}</div>
          </div>

          <div class="profile-photo-copy">
            <p class="section-label">Foto e profilit</p>
            <h3>Shto ose ndrysho foton tende</h3>
            <p class="section-text">
              Zgjidh nje foto nga pajisja dhe kliko `Ruaj` qe te ruhet ne databaze.
            </p>
            <label class="profile-photo-upload-button" for="personal-data-profile-image">
              Zgjidh foton
            </label>
            <input
              id="personal-data-profile-image"
              ref="profileImageInput"
              class="profile-photo-input"
              name="profileImage"
              type="file"
              accept="image/*"
              @change="handleImageChange"
            >
            <p class="profile-photo-file-name">{{ fileName }}</p>
          </div>
        </section>

        <div class="field-row">
          <label class="field">
            <span>Emri</span>
            <input v-model="formState.firstName" type="text" placeholder="Shkruaje emrin" required>
          </label>

          <label class="field">
            <span>Mbiemri</span>
            <input v-model="formState.lastName" type="text" placeholder="Shkruaje mbiemrin" required>
          </label>
        </div>

        <div class="field-row">
          <label class="field">
            <span>Data e lindjes</span>
            <input v-model="formState.birthDate" type="date" required>
          </label>

          <label class="field">
            <span>Gjinia</span>
            <select v-model="formState.gender" required>
              <option value="">Zgjedhe gjinine</option>
              <option value="mashkull">Mashkull</option>
              <option value="femer">Femer</option>
            </select>
          </label>
        </div>

        <div class="profile-form-actions">
          <button class="profile-save-button" type="submit">Ruaj</button>
          <button class="ghost-button profile-cancel-button" type="button" @click="cancelChanges">Anulo</button>
        </div>
      </form>

      <div class="profile-meta-grid">
        <div class="summary-chip">
          <span>Anetar qe nga</span>
          <strong>{{ formatDateLabel(appState.user.createdAt) }}</strong>
        </div>
      </div>

      <section class="profile-danger-zone">
        <div>
          <p class="section-label danger-label">Siguria e llogarise</p>
          <h2>Fshije llogarine</h2>
          <p class="section-text">
            Nese e shkruan fjalekalimin dhe e konfirmon, llogaria do te fshihet komplet nga sistemi.
          </p>
        </div>

        <form class="auth-form profile-delete-form" @submit.prevent="handleDelete">
          <label class="field">
            <span>Fjalekalimi</span>
            <input v-model="deletePassword" type="password" placeholder="Shkruaje fjalekalimin per fshirje" required>
          </label>

          <div class="profile-form-actions">
            <button class="profile-delete-button" type="submit">Fshije llogarine</button>
          </div>
        </form>

        <div class="form-message" :class="ui.deleteType" role="status" aria-live="polite">
          {{ ui.deleteMessage }}
        </div>
      </section>
    </section>
  </section>
</template>

<style scoped>
.profile-card-header-actions {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: flex-end;
  gap: 10px;
}

.profile-liquid-glass-link {
  min-height: 40px;
  padding: 0 12px;
  font-size: 0.82rem;
}
</style>
