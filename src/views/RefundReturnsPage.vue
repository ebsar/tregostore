<script setup>
import { computed, onMounted, reactive, ref } from "vue";
import { RouterLink } from "vue-router";
import { requestJson, resolveApiMessage } from "../lib/api";
import { formatDateLabel, formatReturnRequestStatusLabel } from "../lib/shop";
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
  <section class="account-page orders-page" aria-label="Refund / Returne">
    <header class="account-header profile-page-header">
      <div>
        <p class="section-label">Marketplace</p>
        <h1>Refund / Returne</h1>
        <p class="section-text">
          Ketu i sheh te gjitha kerkesat e tua per kthim dhe statusin e shqyrtimit te tyre.
        </p>
      </div>
    </header>

    <div class="form-message" :class="ui.type" role="status" aria-live="polite">
      {{ ui.message }}
    </div>

    <section v-if="ui.guest" class="collection-empty-state collection-guest-gate">
      <h2>Per te pare refund / returne duhet te kyçesh.</h2>
      <p>Krijo llogari ose hyni ne llogarine tende per te ndjekur kthimet, refund-et dhe shqyrtimin e tyre.</p>
      <div class="collection-guest-gate-actions">
        <RouterLink class="nav-action nav-action-secondary" to="/login?redirect=%2Frefund-returne">
          Login
        </RouterLink>
        <RouterLink class="nav-action nav-action-primary" to="/signup?redirect=%2Frefund-returne">
          Sign Up
        </RouterLink>
      </div>
    </section>

    <div v-else-if="requests.length === 0" class="card account-section orders-empty-card">
      <h2>Ende nuk ke asnje kerkese per kthim.</h2>
    </div>

    <div v-else class="orders-list">
      <article
        v-for="request in requests"
        :key="request.id"
        class="card order-card return-request-card"
      >
        <div class="order-card-top">
          <div>
            <p class="section-label">Kerkesa #{{ request.id }}</p>
            <h2>{{ formatReturnRequestStatusLabel(request.status) }}</h2>
          </div>
          <div class="order-card-meta">
            <span>{{ request.productTitle || "Produkt" }}</span>
            <strong>{{ formatDateLabel(request.createdAt) }}</strong>
          </div>
        </div>

        <div class="order-card-body">
          <div class="order-item-shell">
            <div class="summary-chip">
              <span>Arsyeja</span>
              <strong>{{ request.reason || "-" }}</strong>
            </div>
            <div class="summary-chip" v-if="request.details">
              <span>Detajet</span>
              <strong>{{ request.details }}</strong>
            </div>
            <div class="summary-chip" v-if="request.resolutionNotes">
              <span>Vendimi</span>
              <strong>{{ request.resolutionNotes }}</strong>
            </div>
          </div>

          <div v-if="canManageReturns" class="auth-form-actions">
            <button class="button-secondary" type="button" @click="updateReturnStatus(request, 'approved')">Aprovo</button>
            <button class="button-secondary" type="button" @click="updateReturnStatus(request, 'received')">Pranuar</button>
            <button type="button" @click="updateReturnStatus(request, 'refunded')">Rimburso</button>
            <button class="button-secondary" type="button" @click="updateReturnStatus(request, 'rejected')">Refuzo</button>
          </div>
        </div>
      </article>
    </div>
  </section>
</template>
