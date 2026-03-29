<script setup>
import { onMounted, reactive, ref } from "vue";
import { useRouter } from "vue-router";
import { requestJson, resolveApiMessage } from "../lib/api";
import { formatDateLabel } from "../lib/shop";
import { ensureSessionLoaded, markRouteReady } from "../stores/app-state";

const router = useRouter();
const notifications = ref([]);
const ui = reactive({
  message: "",
  type: "",
});

onMounted(async () => {
  try {
    const user = await ensureSessionLoaded();
    if (!user) {
      router.replace("/login");
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

    <div v-if="notifications.length === 0" class="card account-section orders-empty-card">
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
