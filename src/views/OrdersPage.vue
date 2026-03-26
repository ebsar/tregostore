<script setup>
import { onMounted, reactive, ref } from "vue";
import { useRouter } from "vue-router";
import UserOrderCard from "../components/UserOrderCard.vue";
import { requestJson, resolveApiMessage } from "../lib/api";
import { consumeOrderConfirmationMessage } from "../lib/shop";
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
</script>

<template>
  <section class="account-page orders-page" aria-label="Porosite">
    <header class="account-header profile-page-header">
      <div>
        <p class="section-label">Porosite</p>
        <h1>Produktet e porositura</h1>
        <p class="section-text">
          Ketu shfaqen te gjitha porosite qe i ke konfirmuar nga checkout-i.
        </p>
      </div>
    </header>

    <div class="form-message" :class="ui.type" role="status" aria-live="polite">
      {{ ui.message }}
    </div>

    <div v-if="orders.length === 0" class="card account-section orders-empty-card">
      <h2>Ju nuk keni asnje porosi.</h2>
    </div>

    <div v-else class="orders-list" aria-live="polite">
      <UserOrderCard
        v-for="order in orders"
        :key="order.id"
        :order="order"
      />
    </div>
  </section>
</template>
