<script setup>
import { onMounted, reactive, ref } from "vue";
import { requestJson, resolveApiMessage } from "../lib/api";
import { formatDateLabel } from "../lib/shop";
import { ensureSessionLoaded, markRouteReady } from "../stores/app-state";

const notifications = ref([]);
const ui = reactive({
  message: "",
  type: "",
  guest: false,
});

onMounted(async () => {
  try {
    const user = await ensureSessionLoaded();
    if (!user) {
      ui.guest = true;
      ui.message = "Per te pare njoftimet duhet te kyçesh ose te krijosh llogari.";
      ui.type = "error";
      return;
    }

    await loadNotifications();
    await requestJson("/api/notifications/read", { method: "POST" });
  } finally {
    markRouteReady();
  }
});

async function loadNotifications() {
  const { response, data } = await requestJson("/api/notifications");
  if (!response.ok || !data?.ok) {
    ui.message = resolveApiMessage(data, "Njoftimet nuk u ngarkuan.");
    ui.type = "error";
    notifications.value = [];
    return;
  }

  notifications.value = Array.isArray(data.notifications) ? data.notifications : [];
  ui.message = "";
  ui.type = "";
}
</script>

<template>
  <section class="account-page notifications-page" aria-label="Njoftimet">
    <header class="account-header profile-page-header">
      <div>
        <p class="section-label">Marketplace</p>
        <h1>Njoftimet</h1>
        <p class="section-text">
          Ketu i gjen perditesimet per porosite, verifikimet, review-t dhe kthimet.
        </p>
      </div>
    </header>

    <div class="form-message" :class="ui.type" role="status" aria-live="polite">
      {{ ui.message }}
    </div>

    <section v-if="ui.guest" class="collection-empty-state collection-guest-gate">
      <h2>Per te pare njoftimet duhet te kyçesh.</h2>
      <p>Krijo llogari ose hyni ne llogarine tende per te marre perditesimet per porosite, verifikimet dhe mesazhet.</p>
      <div class="collection-guest-gate-actions">
        <RouterLink class="nav-action nav-action-secondary" to="/login?redirect=%2Fnjoftimet">
          Login
        </RouterLink>
        <RouterLink class="nav-action nav-action-primary" to="/signup?redirect=%2Fnjoftimet">
          Sign Up
        </RouterLink>
      </div>
    </section>

    <div v-else-if="notifications.length === 0" class="card account-section orders-empty-card">
      <h2>Ende nuk ka njoftime.</h2>
    </div>

    <div v-else class="notifications-list">
      <article
        v-for="notification in notifications"
        :key="notification.id"
        class="card account-section notification-card"
      >
        <div class="notification-card-head">
          <div>
            <p class="section-label">{{ formatDateLabel(notification.createdAt) }}</p>
            <h2>{{ notification.title || "Njoftim" }}</h2>
          </div>
          <RouterLink
            v-if="notification.href"
            class="nav-action nav-action-secondary"
            :to="notification.href"
          >
            Hape
          </RouterLink>
        </div>
        <p class="section-text">{{ notification.body }}</p>
      </article>
    </div>
  </section>
</template>
