<script setup>
import { computed, onMounted, reactive, ref } from "vue";
import { RouterLink } from "vue-router";
import AccountUtilityShell from "../components/account/AccountUtilityShell.vue";
import { requestJson, resolveApiMessage } from "../lib/api";
import {
  formatDateLabel,
  formatReturnRequestStatusLabel,
  getAutomaticRefundNotice,
  isAutomaticRefundRequest,
} from "../lib/shop";
import { appState, ensureSessionLoaded, markRouteReady } from "../stores/app-state";

const requests = ref([]);
const ui = reactive({
  message: "",
  type: "",
  guest: false,
});
const canManageReturns = computed(() => ["business", "admin"].includes(String(appState.user?.role || "").trim()));

onMounted(async () => {
  try {
    const user = await ensureSessionLoaded();
    if (!user) {
      ui.guest = true;
      ui.message = "Per te pare refund / returne duhet te kyçesh ose te krijosh llogari.";
      ui.type = "error";
      return;
    }

    await loadRequests();
  } finally {
    markRouteReady();
  }
});

async function loadRequests() {
  const { response, data } = await requestJson("/api/returns");
  if (!response.ok || !data?.ok) {
    ui.message = resolveApiMessage(data, "Kerkesat e kthimit nuk u ngarkuan.");
    ui.type = "error";
    requests.value = [];
    return;
  }

  requests.value = Array.isArray(data.requests) ? data.requests : [];
  ui.message = "";
  ui.type = "";
}

async function updateReturnStatus(request, status) {
  const { response, data } = await requestJson("/api/returns/status", {
    method: "POST",
    body: JSON.stringify({
      returnRequestId: request.id,
      status,
    }),
  });

  if (!response.ok || !data?.ok) {
    ui.message = resolveApiMessage(data, "Kerkesa nuk u perditesua.");
    ui.type = "error";
    return;
  }

  ui.message = data.message || "Kerkesa u perditesua.";
  ui.type = "success";
  await loadRequests();
}
</script>

<template>
  <AccountUtilityShell
    v-if="!ui.guest"
    active-key="returns"
    eyebrow="Marketplace support"
    title="Refunds & returns"
    description="Review return requests, keep track of automated refunds, and update the request status when your role allows it."
    :status-message="ui.message"
    :status-type="ui.type"
    :notification-count="requests.length"
    search-placeholder="Search returns, products, orders"
  >
    <section class="account-card">
      <div class="account-card__header">
        <div>
          <h2>Request history</h2>
          <p>Every refund and return request stays here with its status, reason, and resolution notes.</p>
        </div>
      </div>

      <div v-if="requests.length === 0" class="market-empty">
        <h2>No return requests yet</h2>
        <p>When you request a refund or return, the full history will appear here.</p>
      </div>

      <div v-else class="returns-list">
        <article
          v-for="request in requests"
          :key="request.id"
          class="returns-card"
        >
          <div class="returns-card__header">
            <div>
              <h2>{{ request.productTitle || "Product" }}</h2>
              <p>Request #{{ request.id }}</p>
            </div>

            <div class="returns-card__meta">
              <span class="dashboard-badge" :class="{
                'dashboard-badge--success': ['approved', 'received', 'refunded'].includes(String(request.status || '').trim().toLowerCase()),
                'dashboard-badge--warning': ['pending', 'requested'].includes(String(request.status || '').trim().toLowerCase()),
                'dashboard-badge--error': ['rejected'].includes(String(request.status || '').trim().toLowerCase()),
              }">
                {{ formatReturnRequestStatusLabel(request.status) }}
              </span>
              <strong>{{ formatDateLabel(request.createdAt) }}</strong>
              <span v-if="isAutomaticRefundRequest(request)">Automatic refund</span>
            </div>
          </div>

          <div class="returns-card__body">
            <div class="account-key-value">
              <strong>Reason</strong>
              <span>{{ request.reason || "-" }}</span>
            </div>

            <div v-if="request.details" class="account-key-value">
              <strong>Details</strong>
              <span>{{ request.details }}</span>
            </div>

            <div v-if="request.resolutionNotes" class="account-key-value">
              <strong>Resolution</strong>
              <span>{{ request.resolutionNotes }}</span>
            </div>

            <div v-if="getAutomaticRefundNotice(request)" class="account-key-value">
              <strong>Automatic refund note</strong>
              <span>{{ getAutomaticRefundNotice(request) }}</span>
            </div>
          </div>

          <div v-if="canManageReturns" class="returns-card__actions">
            <button class="market-button market-button--secondary" type="button" @click="updateReturnStatus(request, 'approved')">
              Approve
            </button>
            <button class="market-button market-button--secondary" type="button" @click="updateReturnStatus(request, 'received')">
              Received
            </button>
            <button class="market-button market-button--primary" type="button" @click="updateReturnStatus(request, 'refunded')">
              Refund
            </button>
            <button class="market-button market-button--secondary" type="button" @click="updateReturnStatus(request, 'rejected')">
              Reject
            </button>
          </div>
        </article>
      </div>
    </section>
  </AccountUtilityShell>

  <section v-else class="market-page market-page--wide dashboard-page" aria-label="Refund / Returne">
    <div class="market-empty account-gate">
      <h2>Sign in to track refunds and returns</h2>
      <p>Create an account or log in to follow each return request and refund review from one page.</p>
      <div class="account-gate__actions">
        <RouterLink class="market-button market-button--primary" to="/login?redirect=%2Frefund-returne">
          Login
        </RouterLink>
        <RouterLink class="market-button market-button--secondary" to="/signup?redirect=%2Frefund-returne">
          Sign up
        </RouterLink>
      </div>
    </div>
  </section>
</template>
