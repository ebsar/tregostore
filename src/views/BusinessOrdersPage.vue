<script setup>
import { onMounted, reactive, ref } from "vue";
import { useRouter } from "vue-router";
import BusinessOrderCard from "../components/BusinessOrderCard.vue";
import { requestJson, resolveApiMessage } from "../lib/api";
import { ensureSessionLoaded, markRouteReady } from "../stores/app-state";

const router = useRouter();
const orders = ref([]);
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

    if (user.role !== "business") {
      router.replace("/");
      return;
    }

    await loadOrders();
  } finally {
    markRouteReady();
  }
});

async function loadOrders() {
  const { response, data } = await requestJson("/api/business/orders");
  if (!response.ok || !data?.ok) {
    ui.message = resolveApiMessage(data, "Porosite e biznesit nuk u ngarkuan.");
    ui.type = "error";
    orders.value = [];
    return;
  }

  orders.value = Array.isArray(data.orders) ? data.orders : [];
}
</script>

<template>
  <section class="account-page business-orders-page" aria-label="Porosite e biznesit">
    <header class="account-header profile-page-header">
      <div>
        <p class="section-label">Biznesi juaj</p>
        <h1>Porosite e biznesit</h1>
        <p class="section-text">
          Ketu shfaqen produktet qe jane porositur nga klientet per biznesin tend, bashke me adresen dhe te dhenat e pranimit.
        </p>
      </div>
    </header>

    <div class="form-message" :class="ui.type" role="status" aria-live="polite">
      {{ ui.message }}
    </div>

    <div v-if="orders.length === 0" class="card account-section orders-empty-card">
      <h2>Ende nuk ka porosi per biznesin tend.</h2>
    </div>

    <div v-else class="orders-list business-orders-list" aria-live="polite">
      <BusinessOrderCard
        v-for="order in orders"
        :key="order.id"
        :order="order"
      />
    </div>
  </section>
</template>
