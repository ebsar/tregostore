<script setup>
import { computed, onMounted, reactive, ref, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import DashboardShell from "../components/dashboard/DashboardShell.vue";
import { requestJson, resolveApiMessage } from "../lib/api";
import { getAdminDashboardNavItems } from "../lib/dashboard-ui";
import { formatDateLabel, formatCount, getBusinessInitials } from "../lib/shop";
import { appState, ensureSessionLoaded, markRouteReady } from "../stores/app-state";

const router = useRouter();
const route = useRoute();
const reports = ref([]);
const searchQuery = ref(readRouteSearchQuery(route.query.q));
const statusFilter = ref("all");
const ui = reactive({
  message: "",
  type: "",
});

const adminShellNavItems = computed(() => getAdminDashboardNavItems(appState.user));
const adminAvatarLabel = computed(() => getBusinessInitials(appState.user?.fullName || "Admin"));
const filteredReports = computed(() => {
  const normalizedQuery = String(searchQuery.value || "").trim().toLowerCase();
  return reports.value.filter((report) => {
    const matchesStatus = statusFilter.value === "all" || String(report.status || "").trim().toLowerCase() === statusFilter.value;
    if (!matchesStatus) {
      return false;
    }
    if (!normalizedQuery) {
      return true;
    }
    return [
      report.targetType,
      report.targetLabel,
      report.reason,
      report.details,
      report.reporterName,
      report.reportedName,
      report.status,
    ]
      .join(" ")
      .toLowerCase()
      .includes(normalizedQuery);
  });
});
const summaryCards = computed(() => ([
  {
    label: "Open",
    value: formatCount(reports.value.filter((report) => String(report.status || "").trim().toLowerCase() === "open").length),
    meta: "New disputes to review",
  },
  {
    label: "Reviewing",
    value: formatCount(reports.value.filter((report) => String(report.status || "").trim().toLowerCase() === "reviewing").length),
    meta: "Active moderation queue",
  },
  {
    label: "Resolved",
    value: formatCount(reports.value.filter((report) => String(report.status || "").trim().toLowerCase() === "resolved").length),
    meta: "Closed successfully",
  },
  {
    label: "Dismissed",
    value: formatCount(reports.value.filter((report) => String(report.status || "").trim().toLowerCase() === "dismissed").length),
    meta: "Rejected or closed",
  },
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
    await loadReports();
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

async function loadReports() {
  const { response, data } = await requestJson("/api/admin/reports");
  if (!response.ok || !data?.ok) {
    ui.message = resolveApiMessage(data, "Disputes could not be loaded.");
    ui.type = "error";
    reports.value = [];
    return;
  }

  reports.value = Array.isArray(data.reports) ? data.reports : [];
  ui.message = "";
  ui.type = "";
}

async function handleSearchSubmit() {
  searchQuery.value = String(searchQuery.value || "").trim();
  await syncRouteSearchQuery(searchQuery.value);
}

function formatStatusLabel(status) {
  const labels = {
    open: "Open",
    reviewing: "Reviewing",
    resolved: "Resolved",
    dismissed: "Dismissed",
  };
  return labels[String(status || "").trim().toLowerCase()] || "Open";
}

async function handleStatusUpdate(report, status) {
  const { response, data } = await requestJson("/api/admin/reports/status", {
    method: "POST",
    body: JSON.stringify({
      reportId: report.id,
      status,
    }),
  });

  if (!response.ok || !data?.ok) {
    ui.message = resolveApiMessage(data, "Dispute status could not be updated.");
    ui.type = "error";
    return;
  }

  reports.value = reports.value.map((item) =>
    Number(item.id) === Number(report.id)
      ? { ...item, status }
      : item,
  );
  ui.message = data.message || "Dispute status updated.";
  ui.type = "success";
}
</script>

<template>
  <section class="market-page market-page--wide dashboard-page admin-disputes-page" aria-label="Admin disputes">
    <DashboardShell
      :nav-items="adminShellNavItems"
      active-key="disputes"
      :brand-initial="adminAvatarLabel"
      brand-title="Tregio Admin"
      brand-subtitle="Marketplace control"
      :brand-image-path="appState.user?.profileImagePath || ''"
      brand-fallback-icon="users"
      :profile-image-path="appState.user?.profileImagePath || ''"
      profile-fallback-icon="users"
      :profile-name="appState.user?.fullName || 'Admin'"
      profile-subtitle="Dispute review"
      :search-query="searchQuery"
      search-placeholder="Search disputes"
      :notification-count="summaryCards[0]?.value ? Number(String(summaryCards[0].value).replace(/\D/g, '')) : 0"
      @update:search-query="searchQuery = $event"
      @submit-search="handleSearchSubmit"
    >
      <header class="dashboard-section dashboard-page__hero">
        <div class="market-page__header-copy">
          <p class="market-page__eyebrow">Admin disputes</p>
          <h1>Reports & moderation</h1>
          <p>Review marketplace reports, keep decisions compact, and move each dispute through a clear moderation state.</p>
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
            <p class="market-page__eyebrow">Moderation queue</p>
            <h2>Disputes</h2>
            <p class="dashboard-note">{{ filteredReports.length }} / {{ reports.length }} visible</p>
          </div>
          <label class="dashboard-toolbar__search dashboard-toolbar__search--compact">
            <select v-model="statusFilter" aria-label="Filter dispute status">
              <option value="all">All statuses</option>
              <option value="open">Open</option>
              <option value="reviewing">Reviewing</option>
              <option value="resolved">Resolved</option>
              <option value="dismissed">Dismissed</option>
            </select>
          </label>
        </div>

        <div v-if="reports.length === 0" class="market-empty">
          <h2>No disputes yet</h2>
          <p>Reports from buyers and businesses will appear here once moderation is needed.</p>
        </div>

        <div v-else-if="filteredReports.length === 0" class="market-empty">
          <h2>No matching disputes</h2>
          <p>Try a different search or status filter.</p>
        </div>

        <div v-else class="account-workspace">
          <article v-for="report in filteredReports" :key="report.id" class="account-card">
            <div class="account-card__header">
              <div>
                <h2>{{ report.targetLabel || "Marketplace report" }}</h2>
                <p>{{ report.targetType || "report" }} • Request #{{ report.id }}</p>
              </div>
              <div class="returns-card__meta">
                <span class="dashboard-badge" :class="{
                  'dashboard-badge--warning': ['open', 'reviewing'].includes(String(report.status || '').trim().toLowerCase()),
                  'dashboard-badge--success': String(report.status || '').trim().toLowerCase() === 'resolved',
                  'dashboard-badge--error': String(report.status || '').trim().toLowerCase() === 'dismissed',
                }">
                  {{ formatStatusLabel(report.status) }}
                </span>
                <strong>{{ formatDateLabel(report.createdAt) }}</strong>
              </div>
            </div>

            <div class="account-info-list">
              <div class="account-key-value">
                <strong>Reporter</strong>
                <span>{{ report.reporterName || "Unknown" }}</span>
              </div>
              <div v-if="report.reportedName" class="account-key-value">
                <strong>Reported user</strong>
                <span>{{ report.reportedName }}</span>
              </div>
              <div class="account-key-value">
                <strong>Reason</strong>
                <span>{{ report.reason || "-" }}</span>
              </div>
              <div v-if="report.details" class="account-key-value">
                <strong>Details</strong>
                <span>{{ report.details }}</span>
              </div>
            </div>

            <div class="account-form__actions">
              <button class="market-button market-button--secondary" type="button" @click="handleStatusUpdate(report, 'reviewing')">
                Mark reviewing
              </button>
              <button class="market-button market-button--primary" type="button" @click="handleStatusUpdate(report, 'resolved')">
                Resolve
              </button>
              <button class="market-button market-button--ghost" type="button" @click="handleStatusUpdate(report, 'dismissed')">
                Dismiss
              </button>
            </div>
          </article>
        </div>
      </section>
    </DashboardShell>
  </section>
</template>
