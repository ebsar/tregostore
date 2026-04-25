<script setup>
import { computed, ref } from "vue";
import { useRouter } from "vue-router";
import DashboardShell from "../dashboard/DashboardShell.vue";
import { getAccountDashboardMenuItems } from "../../lib/account-navigation";
import { formatDateLabel, getBusinessInitials } from "../../lib/shop";
import { appState, logoutUser } from "../../stores/app-state";

const props = defineProps({
  activeKey: {
    type: String,
    required: true,
  },
  title: {
    type: String,
    required: true,
  },
  eyebrow: {
    type: String,
    default: "",
  },
  description: {
    type: String,
    default: "",
  },
  statusMessage: {
    type: String,
    default: "",
  },
  statusType: {
    type: String,
    default: "",
  },
  searchPlaceholder: {
    type: String,
    default: "Search dashboard",
  },
  notificationCount: {
    type: Number,
    default: 0,
  },
});

const router = useRouter();
const searchQuery = ref("");

const normalizedRole = computed(() => String(appState.user?.role || "client").trim().toLowerCase());
const dashboardMenuItems = computed(() => getAccountDashboardMenuItems(appState.user, props.activeKey));
const accountShellNavItems = computed(() =>
  dashboardMenuItems.value.map((item) => ({
    key: item.key,
    label: item.label,
    icon: item.icon,
    to: item.href,
    badge: item.badge,
    group: item.group,
  })),
);
const dashboardRoleLabel = computed(() => {
  if (normalizedRole.value === "admin") {
    return "Admin workspace";
  }

  if (normalizedRole.value === "business") {
    return "Business workspace";
  }

  return "Customer account";
});
const userDisplayName = computed(() =>
  String(appState.user?.fullName || appState.user?.businessName || "Tregio User").trim() || "Tregio User",
);
const userAvatarLabel = computed(() => getBusinessInitials(userDisplayName.value || "Tregio"));
const dashboardIdentityImage = computed(() => {
  if (normalizedRole.value === "business") {
    return String(appState.user?.businessLogoPath || "").trim();
  }

  return String(appState.user?.profileImagePath || "").trim();
});
const dashboardIdentityIcon = computed(() => {
  if (normalizedRole.value === "business") {
    return "store";
  }

  return normalizedRole.value === "admin" ? "users" : "user";
});
const accountMetaLabel = computed(() => {
  const joinedAt = formatDateLabel(appState.user?.createdAt || "");
  if (joinedAt) {
    return `Member since ${joinedAt}`;
  }

  if (normalizedRole.value === "admin") {
    return "Platform access";
  }

  if (normalizedRole.value === "business") {
    return "Store workspace";
  }

  return "Active account";
});

async function handleLogout() {
  const { response, data } = await logoutUser();
  if (!response.ok || !data?.ok) {
    return;
  }

  await router.push("/");
}

async function handleDashboardSearch(query) {
  const nextQuery = String(query || searchQuery.value || "").trim();
  if (!nextQuery) {
    return;
  }

  await router.push({
    path: "/kerko",
    query: { q: nextQuery },
  });
}
</script>

<template>
  <section class="market-page market-page--wide dashboard-page">
    <div
      v-if="statusMessage"
      class="market-status"
      :class="{ 'market-status--error': statusType === 'error', 'market-status--success': statusType === 'success' }"
      role="status"
      aria-live="polite"
    >
      {{ statusMessage }}
    </div>

    <DashboardShell
      v-if="appState.user"
      :nav-items="accountShellNavItems"
      :active-key="activeKey"
      :brand-initial="userAvatarLabel"
      :brand-title="userDisplayName"
      :brand-subtitle="dashboardRoleLabel"
      :brand-image-path="dashboardIdentityImage"
      :brand-fallback-icon="dashboardIdentityIcon"
      :profile-image-path="dashboardIdentityImage"
      :profile-fallback-icon="dashboardIdentityIcon"
      :profile-name="userDisplayName"
      :profile-subtitle="dashboardRoleLabel"
      :notification-count="notificationCount"
      :search-query="searchQuery"
      :search-placeholder="searchPlaceholder"
      @update:search-query="searchQuery = $event"
      @submit-search="handleDashboardSearch"
    >
      <template #sidebar-footer>
        <button type="button" @click="handleLogout">
          <svg viewBox="0 0 24 24" aria-hidden="true">
            <path d="M15 5h4v14h-4M10 8l4 4-4 4M14 12H4" />
          </svg>
          <span>Log out</span>
        </button>
      </template>

      <header class="dashboard-section dashboard-page__hero dashboard-utility-hero">
        <div class="dashboard-section__head">
          <div class="market-page__header-copy">
            <p class="market-page__eyebrow">{{ eyebrow || dashboardRoleLabel }}</p>
            <h1>{{ title }}</h1>
            <p v-if="description">{{ description }}</p>
          </div>

          <div class="dashboard-utility-hero__meta">
            <span class="market-pill market-pill--accent">{{ accountMetaLabel }}</span>
            <slot name="hero-actions" />
          </div>
        </div>
      </header>

      <slot />
    </DashboardShell>

    <slot v-else name="fallback" />
  </section>
</template>
