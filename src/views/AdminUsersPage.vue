<script setup>
import { computed, onMounted, reactive, ref, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import AdminUserCard from "../components/AdminUserCard.vue";
import DashboardShell from "../components/dashboard/DashboardShell.vue";
import { requestJson, resolveApiMessage } from "../lib/api";
import { getAdminDashboardNavItems } from "../lib/dashboard-ui";
import { formatCount, getBusinessInitials } from "../lib/shop";
import { appState, ensureSessionLoaded, markRouteReady } from "../stores/app-state";

const router = useRouter();
const route = useRoute();
const users = ref([]);
const searchQuery = ref(readRouteSearchQuery(route.query.q));
const ui = reactive({
  message: "",
  type: "",
});

const adminShellNavItems = computed(() => getAdminDashboardNavItems(appState.user));
const adminAvatarLabel = computed(() => getBusinessInitials(appState.user?.fullName || "Admin"));
const filteredUsers = computed(() => {
  const normalizedQuery = String(searchQuery.value || "").trim().toLowerCase();
  if (!normalizedQuery) {
    return users.value;
  }

  return users.value.filter((user) =>
    [
      user.fullName,
      user.email,
      user.role,
    ]
      .join(" ")
      .toLowerCase()
      .includes(normalizedQuery),
  );
});
const businessUsersCount = computed(() =>
  users.value.filter((user) => String(user.role || "").trim().toLowerCase() === "business").length,
);
const adminUsersCount = computed(() =>
  users.value.filter((user) => String(user.role || "").trim().toLowerCase() === "admin").length,
);
const customerUsersCount = computed(() =>
  users.value.filter((user) => {
    const role = String(user.role || "").trim().toLowerCase();
    return role === "client" || role === "user";
  }).length,
);
const summaryCards = computed(() => ([
  { label: "All users", value: formatCount(users.value.length), meta: "Marketplace accounts" },
  { label: "Customers", value: formatCount(customerUsersCount.value), meta: "Buyer accounts" },
  { label: "Businesses", value: formatCount(businessUsersCount.value), meta: "Vendor accounts" },
  { label: "Admins", value: formatCount(adminUsersCount.value), meta: "Platform access" },
]));

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

    await loadUsers();
  } finally {
    markRouteReady();
  }
});

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

async function loadUsers() {
  const { response, data } = await requestJson("/api/admin/users");
  if (!response.ok || !data?.ok) {
    ui.message = resolveApiMessage(data, "Users could not be loaded.");
    ui.type = "error";
    users.value = [];
    return;
  }

  users.value = Array.isArray(data.users) ? data.users : [];
  ui.message = "";
  ui.type = "";
}

async function handleSearchSubmit() {
  searchQuery.value = String(searchQuery.value || "").trim();
  await syncRouteSearchQuery(searchQuery.value);
}

async function submitUserAction(url, payload, fallbackMessage) {
  const { response, data } = await requestJson(url, {
    method: "POST",
    body: JSON.stringify(payload),
  });

  if (!response.ok || !data?.ok) {
    ui.message = resolveApiMessage(data, fallbackMessage);
    ui.type = "error";
    return { ok: false, data };
  }

  ui.message = data.message || fallbackMessage;
  ui.type = "success";
  return { ok: true, data };
}

async function handleRoleChange({ userId, role }) {
  const result = await submitUserAction("/api/admin/users/role", { userId, role }, "User role could not be updated.");
  if (!result.ok) {
    return;
  }

  users.value = users.value.map((user) =>
    Number(user.id) === Number(userId)
      ? { ...user, role }
      : user,
  );
}

async function handleDeleteUser(user) {
  if (!window.confirm(`Delete ${user.fullName}?`)) {
    return;
  }

  const result = await submitUserAction("/api/admin/users/delete", { userId: user.id }, "User could not be deleted.");
  if (!result.ok) {
    return;
  }

  users.value = users.value.filter((item) => Number(item.id) !== Number(user.id));
}

async function handleSetUserPassword({ userId, newPassword, reset }) {
  if (!String(newPassword || "").trim()) {
    ui.message = "Write a new password before saving.";
    ui.type = "error";
    return;
  }

  const result = await submitUserAction(
    "/api/admin/users/set-password",
    { userId, newPassword },
    "User password could not be changed.",
  );
  if (result.ok && typeof reset === "function") {
    reset();
  }
}
</script>

<template>
  <section class="market-page market-page--wide dashboard-page admin-users-page" aria-label="Admin users">
    <DashboardShell
      :nav-items="adminShellNavItems"
      active-key="users"
      :brand-initial="adminAvatarLabel"
      brand-title="Tregio Admin"
      brand-subtitle="Marketplace control"
      :brand-image-path="appState.user?.profileImagePath || ''"
      brand-fallback-icon="users"
      :profile-image-path="appState.user?.profileImagePath || ''"
      profile-fallback-icon="users"
      :profile-name="appState.user?.fullName || 'Admin'"
      profile-subtitle="User management"
      :search-query="searchQuery"
      search-placeholder="Search users"
      :notification-count="0"
      @update:search-query="searchQuery = $event"
      @submit-search="handleSearchSubmit"
    >
      <header class="dashboard-section dashboard-page__hero">
        <div class="market-page__header-copy">
          <p class="market-page__eyebrow">Admin users</p>
          <h1>User management</h1>
          <p>Promote roles, reset passwords, and remove accounts from one compact operational view.</p>
        </div>
      </header>

      <div
        v-if="ui.message"
        class="market-status"
        :class="{ 'market-status--error': ui.type === 'error', 'market-status--success': ui.type === 'success' }"
        role="status"
        aria-live="polite"
      >
        {{ ui.message }}
      </div>

      <section class="dashboard-section">
        <div class="metric-grid metric-grid--compact">
          <article v-for="item in summaryCards" :key="item.label" class="metric-card">
            <p class="metric-card__label">{{ item.label }}</p>
            <strong>{{ item.value }}</strong>
            <p>{{ item.meta }}</p>
          </article>
        </div>
      </section>

      <section class="dashboard-section">
        <div class="dashboard-section__head">
          <div>
            <p class="market-page__eyebrow">Directory</p>
            <h2>Users</h2>
            <p class="dashboard-note">{{ filteredUsers.length }} / {{ users.length }} visible</p>
          </div>
        </div>

        <div v-if="users.length === 0" class="market-empty">
          <h2>No users found</h2>
          <p>Accounts will appear here as soon as users start signing up.</p>
        </div>

        <div v-else-if="filteredUsers.length === 0" class="market-empty">
          <h2>No matching users</h2>
          <p>Try a different name, email, or role.</p>
        </div>

        <div v-else class="dashboard-card-list">
          <AdminUserCard
            v-for="user in filteredUsers"
            :key="user.id"
            :user="user"
            :current-user-id="Number(appState.user?.id || 0)"
            @change-role="handleRoleChange"
            @delete="handleDeleteUser"
            @set-password="handleSetUserPassword"
          />
        </div>
      </section>
    </DashboardShell>
  </section>
</template>
