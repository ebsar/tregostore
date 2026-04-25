<script setup>
import { computed, onMounted, reactive, ref, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import DashboardBarChart from "../components/dashboard/DashboardBarChart.vue";
import DashboardDonutChart from "../components/dashboard/DashboardDonutChart.vue";
import DashboardShell from "../components/dashboard/DashboardShell.vue";
import PasswordToggleButton from "../components/PasswordToggleButton.vue";
import RegisteredBusinessCard from "../components/RegisteredBusinessCard.vue";
import { requestJson, resolveApiMessage, uploadImages } from "../lib/api";
import { getAdminDashboardNavItems } from "../lib/dashboard-ui";
import { getBusinessInitials } from "../lib/shop";
import { appState, ensureSessionLoaded, markRouteReady } from "../stores/app-state";

const router = useRouter();
const route = useRoute();
const businesses = ref([]);
const searchQuery = ref(readRouteSearchQuery(route.query.q));
const businessPasswordVisible = ref(false);
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
const adminShellNavItems = computed(() => getAdminDashboardNavItems(appState.user));
const adminBusinessesAvatar = computed(() => getBusinessInitials(appState.user?.fullName || "Admin"));

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
const verifiedBusinessesCount = computed(() =>
  businesses.value.filter((business) => String(business.verificationStatus || "").trim().toLowerCase() === "verified").length,
);
const pendingBusinessesCount = computed(() =>
  businesses.value.filter((business) => String(business.verificationStatus || "").trim().toLowerCase() === "pending").length,
);
const lockedBusinessesCount = computed(() =>
  businesses.value.filter((business) => String(business.profileEditAccessStatus || "").trim().toLowerCase() === "locked").length,
);
const totalProductsCount = computed(() =>
  businesses.value.reduce((total, business) => total + Number(business.productsCount || 0), 0),
);
const adminBusinessesSummary = computed(() => ([
  { label: "Businesses", value: businesses.value.length, meta: "Registered vendors" },
  { label: "Verified", value: verifiedBusinessesCount.value, meta: "Approved to sell" },
  { label: "Pending", value: pendingBusinessesCount.value, meta: "Need review" },
  { label: "Products", value: totalProductsCount.value, meta: "Across all stores" },
]));
const adminBusinessesChart = computed(() => ([
  { label: "Verified", value: verifiedBusinessesCount.value },
  { label: "Pending", value: pendingBusinessesCount.value },
  {
    label: "Rejected",
    value: businesses.value.filter((business) => String(business.verificationStatus || "").trim().toLowerCase() === "rejected").length,
  },
]));
const adminBusinessAccessChart = computed(() => ([
  { label: "Editable", value: businesses.value.filter((business) => String(business.profileEditAccessStatus || "").trim().toLowerCase() === "approved").length },
  { label: "Locked", value: lockedBusinessesCount.value },
  { label: "Pending", value: businesses.value.filter((business) => String(business.profileEditAccessStatus || "").trim().toLowerCase() === "pending").length },
]));

function submitBusinessSearch() {
  searchQuery.value = String(searchQuery.value || "").trim();
  syncRouteSearchQuery(searchQuery.value);
}

watch(
  () => route.query.q,
  (value) => {
    searchQuery.value = readRouteSearchQuery(value);
  },
);

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

function readRouteSearchQuery(value) {
  if (Array.isArray(value)) {
    return String(value[0] || "").trim();
  }

  return String(value || "").trim();
}

async function syncRouteSearchQuery(query) {
  const normalizedQuery = String(query || "").trim();
  if (readRouteSearchQuery(route.query.q) === normalizedQuery) {
    return;
  }

  await router.replace({
    path: route.path,
    query: {
      ...route.query,
      ...(normalizedQuery ? { q: normalizedQuery } : { q: undefined }),
    },
  });
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
  <section class="market-page market-page--wide dashboard-page admin-businesses-page" aria-label="Bizneset e regjistruara">
    <DashboardShell
      :nav-items="adminShellNavItems"
      active-key="businesses"
      :brand-initial="adminBusinessesAvatar"
      brand-title="Tregio Admin"
      brand-subtitle="Marketplace control"
      :brand-image-path="appState.user?.profileImagePath || ''"
      brand-fallback-icon="users"
      :profile-image-path="appState.user?.profileImagePath || ''"
      profile-fallback-icon="users"
      :profile-name="appState.user?.fullName || 'Admin'"
      profile-subtitle="Vendor operations"
      :search-query="searchQuery"
      search-placeholder="Search businesses"
      :notification-count="pendingBusinessesCount"
      @update:search-query="searchQuery = $event"
      @submit-search="submitBusinessSearch"
    >
      <header class="dashboard-section dashboard-page__hero">
        <div class="dashboard-section__head">
          <div class="market-page__header-copy">
            <p class="market-page__eyebrow">Admin workspace</p>
            <h1>Registered businesses</h1>
            <p>
              Review vendor onboarding, verification, and store details from one structured workspace.
            </p>
          </div>
          <span class="market-pill market-pill--accent">{{ businesses.length }} total businesses</span>
        </div>

        <p class="dashboard-note">{{ ui.accessNote }}</p>
      </header>

      <section class="metric-grid">
        <article v-for="item in adminBusinessesSummary" :key="item.label" class="metric-card">
          <p class="metric-card__label">{{ item.label }}</p>
          <strong>{{ item.value }}</strong>
          <span>{{ item.meta }}</span>
        </article>
      </section>

      <div class="dashboard-chart-grid">
        <section class="dashboard-section dashboard-chart-card">
          <div class="dashboard-section__head">
            <div>
              <p class="market-page__eyebrow">Verification</p>
              <h2>Approval flow</h2>
            </div>
          </div>

          <DashboardBarChart :items="adminBusinessesChart" />
        </section>

        <section class="dashboard-section dashboard-chart-card">
          <div class="dashboard-section__head">
            <div>
              <p class="market-page__eyebrow">Edit access</p>
              <h2>Profile control</h2>
            </div>
          </div>

          <DashboardDonutChart :items="adminBusinessAccessChart" />
        </section>
      </div>

      <div class="dashboard-admin-grid">
      <section class="dashboard-section">
        <h2>Krijo llogari biznesi</h2>
        <p>
          Nga kjo pjese mund te krijosh direkt nje llogari te re per biznesin dhe ai do te kycet me rolin `business`.
        </p>

        <form @submit.prevent="handleCreateBusiness">
          <label>
            <span>Emri dhe mbiemri i pronarit</span>
            <input v-model="formState.fullName" type="text" placeholder="p.sh. Arben Krasniqi" required>
          </label>

          <div>
            <label>
              <span>Email-i i biznesit</span>
              <input v-model="formState.email" type="email" placeholder="p.sh. biznesi@email.com" required>
            </label>

            <label>
              <span>Fjalekalimi</span>
              <div class="password-control">
                <input
                  v-model="formState.password"
                  :type="businessPasswordVisible ? 'text' : 'password'"
                  placeholder="Shkruaje fjalekalimin"
                  required
                >
                <PasswordToggleButton
                  :visible="businessPasswordVisible"
                  @toggle="businessPasswordVisible = !businessPasswordVisible"
                />
              </div>
            </label>
          </div>

          <label>
            <span>Emri i biznesit</span>
            <input v-model="formState.businessName" type="text" placeholder="p.sh. Market Rinia" required>
          </label>

          <div>
            <label>
              <span>Nr. i biznesit</span>
              <input v-model="formState.businessNumber" type="text" placeholder="p.sh. BR-204-55" required>
            </label>

            <label>
              <span>Numri i telefonit</span>
              <input v-model="formState.phoneNumber" type="text" placeholder="p.sh. +383 44 123 456" required>
            </label>
          </div>

          <div>
            <label>
              <span>Qyteti</span>
              <input v-model="formState.city" type="text" placeholder="p.sh. Prishtine" required>
            </label>

            <label>
              <span>Adresa e biznesit</span>
              <input v-model="formState.addressLine" type="text" placeholder="Shkruaje adresen e biznesit" required>
            </label>
          </div>

          <label>
            <span>Pershkrimi i biznesit</span>
            <textarea v-model="formState.businessDescription" rows="4" placeholder="Shkruaje pershkrimin e biznesit" required></textarea>
          </label>

          <button class="market-button market-button--primary" type="submit">Krijo llogarine e biznesit</button>
        </form>

        <div
          v-if="ui.formMessage"
          class="market-status"
          :class="{ 'market-status--error': ui.formType === 'error', 'market-status--success': ui.formType === 'success' }"
          role="status"
          aria-live="polite"
        >
          {{ ui.formMessage }}
        </div>
      </section>

      <section class="dashboard-section">
        <div>
          <div>
            <p>Lista e bizneseve</p>
            <h2>Bizneset aktive ne sistem</h2>
          </div>
        </div>

        <p class="dashboard-note" aria-live="polite">{{ searchStatus }}</p>

        <div
          v-if="ui.listMessage"
          class="market-status"
          :class="{ 'market-status--error': ui.listType === 'error', 'market-status--success': ui.listType === 'success' }"
          role="status"
          aria-live="polite"
        >
          {{ ui.listMessage }}
        </div>

        <div v-if="businesses.length === 0" class="market-empty">
          <h3>No businesses yet</h3>
          <p>Ende nuk ka biznese te regjistruara.</p>
        </div>

        <div v-else-if="filteredBusinesses.length === 0" class="market-empty">
          <h3>No matching businesses</h3>
          <p>Nuk u gjet asnje biznes per kerkimin qe bere.</p>
        </div>

        <div v-else class="dashboard-card-list">
          <RegisteredBusinessCard
            v-for="business in filteredBusinesses"
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
    </DashboardShell>
  </section>
</template>
