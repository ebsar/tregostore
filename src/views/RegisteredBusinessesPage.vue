<script setup>
import { computed, onMounted, reactive, ref } from "vue";
import { useRouter } from "vue-router";
import RegisteredBusinessCard from "../components/RegisteredBusinessCard.vue";
import { requestJson, resolveApiMessage, uploadImages } from "../lib/api";
import { ensureSessionLoaded, markRouteReady } from "../stores/app-state";

const router = useRouter();
const businesses = ref([]);
const searchQuery = ref("");
const formState = reactive({
  fullName: "",
  email: "",
  password: "",
  businessName: "",
  businessNumber: "",
  phoneNumber: "",
  city: "",
  addressLine: "",
  businessDescription: "",
});
const ui = reactive({
  accessNote: "Po ngarkohen bizneset e regjistruara...",
  formMessage: "",
  formType: "",
  listMessage: "",
  listType: "",
});

const filteredBusinesses = computed(() => {
  const query = searchQuery.value.trim().toLowerCase();
  if (!query) {
    return businesses.value;
  }

  return businesses.value.filter((business) =>
    [business.ownerName, business.businessName, business.businessNumber]
      .join(" ")
      .toLowerCase()
      .includes(query),
  );
});

const searchStatus = computed(() => {
  if (businesses.value.length === 0) {
    return "";
  }

  if (!searchQuery.value.trim()) {
    return `Po shfaqen te gjitha ${businesses.value.length} bizneset aktive.`;
  }

  return `Po shfaqen ${filteredBusinesses.value.length} nga ${businesses.value.length} biznese per kerkimin "${searchQuery.value.trim()}".`;
});

function submitBusinessSearch() {
  searchQuery.value = String(searchQuery.value || "").trim();
}

onMounted(async () => {
  try {
    const user = await ensureSessionLoaded();
    if (!user) {
      router.replace("/login");
      return;
    }

    if (user.role !== "admin") {
      router.replace("/");
      return;
    }

    ui.accessNote = "Je kycur si admin. Ketu shfaqen bizneset e regjistruara ne TREGIO dhe statistikat baze te tyre.";
    await loadBusinesses();
  } finally {
    markRouteReady();
  }
});

async function loadBusinesses() {
  const { response, data } = await requestJson("/api/admin/businesses");
  if (!response.ok || !data?.ok) {
    ui.listMessage = resolveApiMessage(data, "Lista e bizneseve nuk u ngarkua.");
    ui.listType = "error";
    businesses.value = [];
    return;
  }

  businesses.value = Array.isArray(data.businesses) ? data.businesses : [];
  ui.listMessage = "";
  ui.listType = "";
}

async function handleCreateBusiness() {
  ui.formMessage = "";
  const { response, data } = await requestJson("/api/admin/businesses/create", {
    method: "POST",
    body: JSON.stringify(formState),
  });

  if (!response.ok || !data?.ok) {
    ui.formMessage = resolveApiMessage(data, "Llogaria e biznesit nuk u krijua.");
    ui.formType = "error";
    return;
  }

  Object.keys(formState).forEach((key) => {
    formState[key] = "";
  });
  ui.formMessage = data.message || "Llogaria e biznesit u krijua me sukses.";
  ui.formType = "success";
  await loadBusinesses();
}

async function handleUploadLogo({ businessId, file }) {
  const uploadResult = await uploadImages([file]);
  if (!uploadResult.ok) {
    ui.listMessage = uploadResult.message;
    ui.listType = "error";
    return;
  }

  const { response, data } = await requestJson("/api/admin/businesses/logo", {
    method: "POST",
    body: JSON.stringify({
      businessId,
      businessLogoPath: uploadResult.paths[0],
    }),
  });

  if (!response.ok || !data?.ok || !data.business) {
    ui.listMessage = resolveApiMessage(data, "Logoja e biznesit nuk u ruajt.");
    ui.listType = "error";
    return;
  }

  businesses.value = businesses.value.map((business) =>
    Number(business.id) === Number(businessId) ? data.business : business,
  );
  ui.listMessage = data.message || "Logoja e biznesit u ruajt me sukses.";
  ui.listType = "success";
}

async function handleSaveEdit({ businessId, payload, done }) {
  const { response, data } = await requestJson("/api/admin/businesses/update", {
    method: "POST",
    body: JSON.stringify({
      businessId,
      ...payload,
    }),
  });

  if (!response.ok || !data?.ok || !data.business) {
    ui.listMessage = resolveApiMessage(data, "Biznesi nuk u perditesua.");
    ui.listType = "error";
    return;
  }

  businesses.value = businesses.value.map((business) =>
    Number(business.id) === Number(businessId) ? data.business : business,
  );
  if (typeof done === "function") {
    done();
  }
  ui.listMessage = data.message || "Biznesi u perditesua me sukses.";
  ui.listType = "success";
}

async function handleVerificationUpdate({ businessId, verificationStatus }) {
  const { response, data } = await requestJson("/api/admin/businesses/verification", {
    method: "POST",
    body: JSON.stringify({
      businessId,
      verificationStatus,
    }),
  });

  if (!response.ok || !data?.ok || !data.business) {
    ui.listMessage = resolveApiMessage(data, "Verifikimi nuk u perditesua.");
    ui.listType = "error";
    return;
  }

  businesses.value = businesses.value.map((business) =>
    Number(business.id) === Number(businessId) ? data.business : business,
  );
  ui.listMessage = data.message || "Verifikimi u ruajt.";
  ui.listType = "success";
}

async function handleEditAccessUpdate({ businessId, editAccessStatus }) {
  const { response, data } = await requestJson("/api/admin/businesses/edit-access", {
    method: "POST",
    body: JSON.stringify({
      businessId,
      editAccessStatus,
    }),
  });

  if (!response.ok || !data?.ok || !data.business) {
    ui.listMessage = resolveApiMessage(data, "Leja per editim nuk u perditesua.");
    ui.listType = "error";
    return;
  }

  businesses.value = businesses.value.map((business) =>
    Number(business.id) === Number(businessId) ? data.business : business,
  );
  ui.listMessage = data.message || "Leja per editim u ruajt.";
  ui.listType = "success";
}
</script>

<template>
  <section class="registered-businesses-page" aria-label="Bizneset e regjistruara">
    <header class="admin-products-header">
      <div>
        <p class="section-label">Paneli admin</p>
        <h1>Bizneset e regjistruara</h1>
        <p class="admin-products-intro">
          Ketu shfaqen bizneset qe jane regjistruar ne platforme, bashke me te dhenat baze dhe numrin e produkteve qe kane shtuar deri tani.
        </p>
      </div>
      <div class="admin-user-chip">
        <span>Totali i bizneseve</span>
        <strong>{{ businesses.length }}</strong>
      </div>
    </header>

    <p class="admin-access-note">{{ ui.accessNote }}</p>

    <div class="admin-products-layout">
      <section class="card admin-form-card">
        <h2>Krijo llogari biznesi</h2>
        <p class="section-text">
          Nga kjo pjese mund te krijosh direkt nje llogari te re per biznesin dhe ai do te kycet me rolin `business`.
        </p>

        <form class="auth-form" @submit.prevent="handleCreateBusiness">
          <label class="field">
            <span>Emri dhe mbiemri i pronarit</span>
            <input v-model="formState.fullName" type="text" placeholder="p.sh. Arben Krasniqi" required>
          </label>

          <div class="field-row">
            <label class="field">
              <span>Email-i i biznesit</span>
              <input v-model="formState.email" type="email" placeholder="p.sh. biznesi@email.com" required>
            </label>

            <label class="field">
              <span>Fjalekalimi</span>
              <input v-model="formState.password" type="password" placeholder="Shkruaje fjalekalimin" required>
            </label>
          </div>

          <label class="field">
            <span>Emri i biznesit</span>
            <input v-model="formState.businessName" type="text" placeholder="p.sh. Market Rinia" required>
          </label>

          <div class="field-row">
            <label class="field">
              <span>Nr. i biznesit</span>
              <input v-model="formState.businessNumber" type="text" placeholder="p.sh. BR-204-55" required>
            </label>

            <label class="field">
              <span>Numri i telefonit</span>
              <input v-model="formState.phoneNumber" type="text" placeholder="p.sh. +383 44 123 456" required>
            </label>
          </div>

          <div class="field-row">
            <label class="field">
              <span>Qyteti</span>
              <input v-model="formState.city" type="text" placeholder="p.sh. Prishtine" required>
            </label>

            <label class="field">
              <span>Adresa e biznesit</span>
              <input v-model="formState.addressLine" type="text" placeholder="Shkruaje adresen e biznesit" required>
            </label>
          </div>

          <label class="field">
            <span>Pershkrimi i biznesit</span>
            <textarea v-model="formState.businessDescription" rows="4" placeholder="Shkruaje pershkrimin e biznesit" required></textarea>
          </label>

          <button type="submit">Krijo llogarine e biznesit</button>
        </form>

        <div class="form-message" :class="ui.formType" role="status" aria-live="polite">
          {{ ui.formMessage }}
        </div>
      </section>

      <section class="card admin-list-card">
        <div class="admin-list-header">
          <div>
            <p class="section-label">Lista e bizneseve</p>
            <h2>Bizneset aktive ne sistem</h2>
          </div>
        </div>

        <form class="search-form registered-businesses-search-form" @submit.prevent="submitBusinessSearch">
          <input
            v-model="searchQuery"
            class="search-input"
            type="search"
            placeholder="Kerko sipas emrit te biznesit, pronarit ose nr. te biznesit"
            aria-label="Kerko biznes"
          >
          <button class="search-submit-button" type="button" @click="submitBusinessSearch">Kerko</button>
          <button class="search-reset-button" type="button" @click="searchQuery = ''">Pastro</button>
        </form>

        <p class="search-results-label" aria-live="polite">{{ searchStatus }}</p>

        <div class="form-message" :class="ui.listType" role="status" aria-live="polite">
          {{ ui.listMessage }}
        </div>

        <div class="registered-businesses-list">
          <div v-if="businesses.length === 0" class="collection-empty-state">
            Ende nuk ka biznese te regjistruara.
          </div>

          <div v-else-if="filteredBusinesses.length === 0" class="collection-empty-state">
            Nuk u gjet asnje biznes per kerkimin qe bere.
          </div>

          <RegisteredBusinessCard
            v-for="business in filteredBusinesses"
            v-else
          :key="business.id"
          :business="business"
          @upload-logo="handleUploadLogo"
          @save-edit="handleSaveEdit"
          @update-verification="handleVerificationUpdate"
          @update-edit-access="handleEditAccessUpdate"
        />
      </div>
      </section>
    </div>
  </section>
</template>
