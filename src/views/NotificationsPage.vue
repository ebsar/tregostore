<script setup>
import { onMounted, reactive, ref } from "vue";
import { RouterLink } from "vue-router";
import AccountUtilityShell from "../components/account/AccountUtilityShell.vue";
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
  <AccountUtilityShell
    v-if="!ui.guest"
    active-key="notifications"
    eyebrow="Marketplace inbox"
    title="Notifications"
    description="Keep up with order updates, verification changes, reviews, and marketplace alerts from one clean place."
    :status-message="ui.message"
    :status-type="ui.type"
    :notification-count="notifications.length"
    search-placeholder="Search notifications or dashboard"
  >
    <section class="account-card">
      <div class="account-card__header">
        <div>
          <h2>Recent updates</h2>
          <p>Notifications are marked as read automatically after they are loaded here.</p>
        </div>
      </div>

      <div v-if="notifications.length === 0" class="market-empty">
        <h2>No notifications yet</h2>
        <p>Order updates, verification changes, and review alerts will appear here.</p>
      </div>

      <div v-else class="notifications-list">
        <article
          v-for="notification in notifications"
          :key="notification.id"
          class="notification-card"
        >
          <div class="notification-card__header">
            <div>
              <h2>{{ notification.title || "Notification" }}</h2>
              <p>{{ notification.body }}</p>
            </div>

            <div class="notification-card__meta">
              <strong>{{ formatDateLabel(notification.createdAt) }}</strong>
            </div>
          </div>

          <div v-if="notification.href" class="account-form__actions">
            <RouterLink class="market-button market-button--secondary" :to="notification.href">
              Open update
            </RouterLink>
          </div>
        </article>
      </div>
    </section>
  </AccountUtilityShell>

  <section v-else class="market-page market-page--wide dashboard-page" aria-label="Notifications">
    <div class="market-empty account-gate">
      <h2>Sign in to see your notifications</h2>
      <p>Create an account or log in to receive order updates, verification alerts, and marketplace messages.</p>
      <div class="account-gate__actions">
        <RouterLink class="market-button market-button--primary" to="/login?redirect=%2Fnjoftimet">
          Login
        </RouterLink>
        <RouterLink class="market-button market-button--secondary" to="/signup?redirect=%2Fnjoftimet">
          Sign up
        </RouterLink>
      </div>
    </div>
  </section>
</template>
