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
  <div class="header-track-card">
    <button
      v-if="showClose"
      class="header-track-card-close"
      type="button"
      aria-label="Close track order"
      @click="emit('close')"
    >
      ×
    </button>

    <div class="header-track-card-head">
      <p class="header-track-card-badge">Track Order</p>
      <h3>Find your order instantly</h3>
      <p>
        Enter the Order ID from your receipt or confirmation email and the Billing Email used during checkout.
      </p>
    </div>

    <form class="header-track-form" @submit.prevent="submitLookup">
      <div class="header-track-form-grid">
        <label class="header-track-field">
          <span>Order ID</span>
          <input
            v-model="form.orderId"
            type="text"
            placeholder="ID..."
            autocomplete="off"
            required
          >
        </label>

        <label class="header-track-field">
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

      <p class="header-track-note">
        <span aria-hidden="true">ⓘ</span>
        Order ID is the code we sent to your email address when the order was placed.
      </p>

      <div class="form-message" :class="ui.type" role="status" aria-live="polite">
        {{ ui.message }}
      </div>

      <button class="header-track-submit" type="submit" :disabled="ui.loading">
        {{ ui.loading ? "TRACKING..." : "TRACK ORDER" }}
        <span aria-hidden="true">→</span>
      </button>
    </form>
  </div>
</template>

<style scoped>
.header-track-card {
  position: relative;
  display: grid;
  gap: 24px;
  padding: 34px 34px 32px;
  border-radius: 22px;
  background: #ffffff;
  box-shadow: 0 32px 80px rgba(15, 23, 42, 0.22);
}

.header-track-card-close {
  position: absolute;
  top: 16px;
  right: 16px;
  width: 40px;
  height: 40px;
  border: 0;
  border-radius: 999px;
  background: #f1f5f9;
  color: #475569;
  font-size: 1.5rem;
  line-height: 1;
  cursor: pointer;
}

.header-track-card-head {
  display: grid;
  gap: 10px;
  padding-right: 44px;
}

.header-track-card-badge {
  width: fit-content;
  margin: 0;
  padding: 6px 12px;
  border-radius: 999px;
  background: rgba(255, 134, 47, 0.12);
  color: #ff862f;
  font-size: 0.82rem;
  font-weight: 800;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.header-track-card-head h3 {
  margin: 0;
  color: #202833;
  font-size: clamp(1.85rem, 2.1vw, 2.35rem);
  line-height: 1.04;
  letter-spacing: -0.04em;
}

.header-track-card-head p {
  max-width: 680px;
  margin: 0;
  color: #64748b;
  font-size: 1rem;
  line-height: 1.65;
}

.header-track-form {
  display: grid;
  gap: 18px;
}

.header-track-form-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 20px;
}

.header-track-field {
  display: grid;
  gap: 10px;
}

.header-track-field span {
  color: #202833;
  font-size: 0.96rem;
  font-weight: 700;
}

.header-track-field input {
  min-height: 56px;
  padding: 0 16px;
  border: 1px solid #dbe2ea;
  border-radius: 12px;
  background: #ffffff;
  color: #0f172a;
  font: inherit;
  outline: none;
}

.header-track-field input:focus {
  border-color: rgba(255, 134, 47, 0.72);
  box-shadow: 0 0 0 4px rgba(255, 134, 47, 0.12);
}

.header-track-note {
  display: inline-flex;
  align-items: center;
  gap: 10px;
  margin: 0;
  color: #64748b;
  font-size: 0.95rem;
  line-height: 1.5;
}

.header-track-note span {
  color: #475569;
  font-weight: 700;
}

.header-track-submit {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 10px;
  min-width: 220px;
  min-height: 54px;
  padding: 0 22px;
  border: 0;
  border-radius: 12px;
  background: #ff862f;
  color: #fff;
  font-weight: 800;
  letter-spacing: 0.01em;
  cursor: pointer;
}

.header-track-submit:disabled {
  opacity: 0.64;
  cursor: default;
}

@media (max-width: 760px) {
  .header-track-card {
    gap: 20px;
    padding: 24px 18px 20px;
    border-radius: 18px;
  }

  .header-track-card-head {
    padding-right: 34px;
  }

  .header-track-form-grid {
    grid-template-columns: 1fr;
    gap: 16px;
  }

  .header-track-submit {
    width: 100%;
  }
}
</style>
