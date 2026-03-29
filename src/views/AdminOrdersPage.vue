<script setup>
import { onMounted, reactive, ref } from "vue";
import { useRouter } from "vue-router";
import BusinessOrderCard from "../components/BusinessOrderCard.vue";
import { requestJson, resolveApiMessage } from "../lib/api";
import { ensureSessionLoaded, markRouteReady } from "../stores/app-state";

const router = useRouter();
const orders = ref([]);
const busyOrderItemId = ref(0);
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

    if (user.role !== "admin") {
      router.replace("/");
      return;
    }

    await loadOrders();
  } finally {
    markRouteReady();
  }
});

async function loadOrders() {
  const { response, data } = await requestJson("/api/admin/orders");
  if (!response.ok || !data?.ok) {
    ui.message = resolveApiMessage(data, "Porosite e adminit nuk u ngarkuan.");
    ui.type = "error";
    orders.value = [];
    return;
  }

  orders.value = Array.isArray(data.orders) ? data.orders : [];
  ui.message = "";
  ui.type = "";
}

async function handleUpdateStatus(payload) {
  busyOrderItemId.value = Number(payload.orderItemId) || 0;
  try {
    const { response, data } = await requestJson("/api/orders/status", {
      method: "POST",
      body: JSON.stringify(payload),
    });
    if (!response.ok || !data?.ok) {
      ui.message = resolveApiMessage(data, "Statusi nuk u ruajt.");
      ui.type = "error";
      return;
    }

    ui.message = data.message || "Statusi u ruajt.";
    ui.type = "success";
    await loadOrders();
  } finally {
    busyOrderItemId.value = 0;
  }
}
</script>

<template>
  <section class="account-page orders-page" aria-label="Porosit e adminit">
    <header class="account-header profile-page-header">
      <div>
        <p class="section-label">Admin</p>
        <h1>Porosit</h1>
        <p class="section-text">
          Ketu do ta lidhim me vone pamjen e pergjithshme te porosive ne nivel administrimi.
        </p>
      </div>
    </header>

    <div v-if="orders.length === 0" class="card account-section orders-empty-card">
      <h2>Paneli i porosive per admin po pergatitet.</h2>
      <p class="section-text">
        Tani per tani porosite menaxhohen nga perdoruesit dhe bizneset ne faqet e tyre perkatese.
      </p>
    </div>

    <div class="form-message" :class="ui.type" role="status" aria-live="polite">
      {{ ui.message }}
    </div>

    <div v-if="orders.length > 0" class="orders-list business-orders-list" aria-live="polite">
      <BusinessOrderCard
        v-for="order in orders"
        :key="order.id"
        :order="order"
        can-manage-status
        show-admin-finance
        :busy-order-item-id="busyOrderItemId"
        @update-status="handleUpdateStatus"
      />
    </div>
  </section>
</template>
