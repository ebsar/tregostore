<script setup>
import { onMounted, reactive, ref } from "vue";
import { RouterLink } from "vue-router";
import UserOrderCard from "../components/UserOrderCard.vue";
import { requestJson, resolveApiMessage } from "../lib/api";
import { consumeOrderConfirmationMessage } from "../lib/shop";
import { ensureSessionLoaded, markRouteReady } from "../stores/app-state";

const orders = ref([]);
const busyOrderItemId = ref(0);
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
      ui.message = "Per te pare porosite duhet te kyçesh ose te krijosh llogari.";
      ui.type = "error";
      return;
    }

    const confirmation = consumeOrderConfirmationMessage();
    if (confirmation) {
      ui.message = confirmation;
      ui.type = "success";
    }

    await loadOrders();
  } finally {
    markRouteReady();
  }
});

async function loadOrders() {
  const { response, data } = await requestJson("/api/orders");
  if (!response.ok || !data?.ok) {
    if (!ui.message) {
      ui.message = resolveApiMessage(data, "Porosite nuk u ngarkuan.");
      ui.type = "error";
    }
    orders.value = [];
    return;
  }

  orders.value = Array.isArray(data.orders) ? data.orders : [];
}

async function handleReturnRequest(item) {
  const reason = window.prompt("Shkruaj arsyen e kthimit:");
  if (!reason) {
    return;
  }

  busyOrderItemId.value = Number(item.id) || 0;
  try {
    const { response, data } = await requestJson("/api/returns/request", {
      method: "POST",
      body: JSON.stringify({
        orderItemId: item.id,
        reason,
        details: "",
      }),
    });

    if (!response.ok || !data?.ok) {
      ui.message = resolveApiMessage(data, "Kerkesa per kthim nuk u dergua.");
      ui.type = "error";
      return;
    }

    ui.message = data.message || "Kerkesa per kthim u dergua.";
    ui.type = "success";
    await loadOrders();
  } finally {
    busyOrderItemId.value = 0;
  }
}
</script>

<template>
  <section class="account-page orders-page" aria-label="Porosite">
    <header class="account-header profile-page-header">
      <div>
        <p class="section-label">Porosite</p>
        <h1>Produktet e porositura</h1>
        <p class="section-text">
          Ketu shfaqen porosite qe jane derguar per konfirmim nga checkout-i dhe statusi i tyre i fundit.
        </p>
      </div>
    </header>

    <div class="form-message" :class="ui.type" role="status" aria-live="polite">
      {{ ui.message }}
    </div>

    <section v-if="ui.guest" class="collection-empty-state collection-guest-gate">
      <h2>Per te pare porosite duhet te kyçesh.</h2>
      <p>Krijo llogari ose hyni ne llogarine tende per te ndjekur porosite dhe statusin e tyre.</p>
      <div class="collection-guest-gate-actions">
        <RouterLink class="nav-action nav-action-secondary" to="/login?redirect=%2Fporosite">
          Login
        </RouterLink>
        <RouterLink class="nav-action nav-action-primary" to="/signup?redirect=%2Fporosite">
          Sign Up
        </RouterLink>
      </div>
    </section>

    <div v-else-if="orders.length === 0" class="card account-section orders-empty-card">
      <h2>Ju nuk keni asnje porosi.</h2>
    </div>

    <div v-else class="orders-list" aria-live="polite">
      <UserOrderCard
        v-for="order in orders"
        :key="order.id"
        :order="order"
        :busy-order-item-id="busyOrderItemId"
        @request-return="handleReturnRequest"
      />
    </div>
  </section>
</template>
