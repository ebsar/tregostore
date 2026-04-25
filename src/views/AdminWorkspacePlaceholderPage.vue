<script setup>
import { computed, onMounted } from "vue";
import { useRoute, useRouter } from "vue-router";
import DashboardShell from "../components/dashboard/DashboardShell.vue";
import { getAdminDashboardNavItems } from "../lib/dashboard-ui";
import { getBusinessInitials } from "../lib/shop";
import { appState, ensureSessionLoaded, markRouteReady } from "../stores/app-state";

const route = useRoute();
const router = useRouter();

const pageConfig = computed(() => route.meta?.dashboardPlaceholder || {});
const adminShellNavItems = computed(() => getAdminDashboardNavItems(appState.user));
const adminAvatarLabel = computed(() => getBusinessInitials(appState.user?.fullName || "Admin"));

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
  } finally {
    markRouteReady();
  }
});
</script>

<template>
  <section class="market-page market-page--wide dashboard-page admin-placeholder-page">
    <DashboardShell
      :nav-items="adminShellNavItems"
      :active-key="pageConfig.activeKey || 'settings'"
      :brand-initial="adminAvatarLabel"
      brand-title="Tregio Admin"
      brand-subtitle="Marketplace control"
      :brand-image-path="appState.user?.profileImagePath || ''"
      brand-fallback-icon="users"
      :profile-image-path="appState.user?.profileImagePath || ''"
      profile-fallback-icon="users"
      :profile-name="appState.user?.fullName || 'Admin'"
      :profile-subtitle="pageConfig.title || 'Admin workspace'"
      search-placeholder="Search admin workspace"
      :notification-count="0"
    >
      <header class="dashboard-section dashboard-page__hero">
        <div class="market-page__header-copy">
          <p class="market-page__eyebrow">{{ pageConfig.eyebrow || "Admin workspace" }}</p>
          <h1>{{ pageConfig.title || "Admin workspace" }}</h1>
          <p>{{ pageConfig.description || "This area is prepared in the UI and ready for a dedicated backend integration." }}</p>
        </div>
      </header>

      <section class="account-card">
        <div class="account-card__header">
          <div>
            <h2>Integration status</h2>
            <p>{{ pageConfig.note || "The frontend structure is prepared. Add the backend endpoint when this section is ready to become operational." }}</p>
          </div>
        </div>

        <div class="account-key-value">
          <strong>Current state</strong>
          <span>UI placeholder only. No fake data or fake mutations were added.</span>
        </div>
      </section>
    </DashboardShell>
  </section>
</template>
