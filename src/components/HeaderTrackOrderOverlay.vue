<script setup>
import { reactive } from "vue";
import { requestJson, resolveApiMessage } from "../lib/api";
import { persistTrackedOrderLookup } from "../lib/shop";

const props = defineProps({
  showClose: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(["close", "tracked"]);

const form = reactive({
  orderId: "",
  billingEmail: "",
});

const ui = reactive({
  loading: false,
  message: "",
  type: "",
});

async function submitLookup() {
  ui.loading = true;
  ui.message = "";
  ui.type = "";

  try {
    const { response, data } = await requestJson("/api/orders/track", {
      method: "POST",
      body: JSON.stringify({
        orderId: form.orderId.trim(),
        billingEmail: form.billingEmail.trim(),
      }),
    });

    if (!response.ok || !data?.ok || !data.order) {
      ui.message = resolveApiMessage(data, "We could not find an order with those details.");
      ui.type = "error";
      return;
    }

    const snapshot = persistTrackedOrderLookup({
      orderId: form.orderId.trim(),
      billingEmail: form.billingEmail.trim(),
      order: data.order,
    });

    if (!snapshot) {
      ui.message = "The order was found, but the browser could not store the tracking details.";
      ui.type = "error";
      return;
    }

    window.dispatchEvent(new CustomEvent("tregio:track-order-updated", { detail: snapshot }));
    emit("tracked", snapshot);
  } catch (error) {
    ui.message = "The server is not responding right now. Please try again.";
    ui.type = "error";
    console.error(error);
  } finally {
    ui.loading = false;
  }
}
</script>

<template>
  <div class="overlay-panel" @click.stop>
    <button
      v-if="showClose"
      class="market-icon-button auth-panel__close"
      type="button"
      aria-label="Close track order"
      @click="emit('close')"
    >
      ×
    </button>

    <div class="auth-panel">
      <p>Track Order</p>
      <h3>Find your order instantly</h3>
      <p>
        Enter the Order ID from your receipt or confirmation email and the Billing Email used during checkout.
      </p>
    </div>

    <form class="auth-panel auth-panel__form" @submit.prevent="submitLookup">
      <div class="auth-panel__form-row">
        <label class="auth-panel__field">
          <span>Order ID</span>
          <input
            v-model="form.orderId"
            type="text"
            placeholder="ID..."
            autocomplete="off"
            required
          >
        </label>

        <label class="auth-panel__field">
          <span>Billing Email</span>
          <input
            v-model="form.billingEmail"
            type="email"
            placeholder="Email address"
            autocomplete="email"
            required
          >
        </label>
      </div>

      <p>
        <span aria-hidden="true">ⓘ</span>
        Order ID is the code we sent to your email address when the order was placed.
      </p>

      <div
        role="status"
        aria-live="polite"
        :class="['market-status', ui.type === 'error' ? 'market-status--error' : ui.type === 'success' ? 'market-status--success' : '']"
      >
        {{ ui.message }}
      </div>

      <button class="market-button market-button--primary" type="submit" :disabled="ui.loading">
        {{ ui.loading ? "TRACKING..." : "TRACK ORDER" }}
        <span aria-hidden="true">→</span>
      </button>
    </form>
  </div>
</template>
