<script setup>
import { computed, onMounted, reactive } from "vue";
import { RouterLink } from "vue-router";
import AccountUtilityShell from "../components/account/AccountUtilityShell.vue";
import { readCheckoutPaymentMethod } from "../lib/shop";
import { ensureSessionLoaded, markRouteReady } from "../stores/app-state";

const ui = reactive({
  guest: false,
});

const activeMethod = computed(() => String(readCheckoutPaymentMethod() || "").trim());
const activeMethodLabel = computed(() => {
  if (activeMethod.value === "stripe") {
    return "Card payment via Stripe";
  }
  if (activeMethod.value === "cash-on-delivery") {
    return "Cash on delivery";
  }
  if (activeMethod.value === "bank-transfer") {
    return "Bank transfer";
  }
  return "";
});

onMounted(async () => {
  try {
    const user = await ensureSessionLoaded();
    if (!user) {
      ui.guest = true;
    }
  } finally {
    markRouteReady();
  }
});
</script>

<template>
  <AccountUtilityShell
    v-if="!ui.guest"
    active-key="payments"
    eyebrow="Customer account"
    title="Payment methods"
    description="Review the payment method used most recently in checkout. Saved wallet and card management can plug in here once a dedicated backend is added."
    search-placeholder="Search payments or checkout help"
  >
    <section class="account-card">
      <div class="account-card__header">
        <div>
          <h2>Saved payment area</h2>
          <p>Right now the marketplace keeps the last checkout selection, not a stored card vault.</p>
        </div>
        <span class="market-pill market-pill--accent">
          {{ activeMethodLabel ? "Last used method" : "No saved method" }}
        </span>
      </div>

      <div v-if="activeMethodLabel" class="account-workspace">
        <div class="account-key-value">
          <strong>Current payment method</strong>
          <span>{{ activeMethodLabel }}</span>
        </div>
        <div class="account-key-value">
          <strong>Marketplace status</strong>
          <span>Reusable saved cards are not connected yet. Checkout payment still works normally.</span>
        </div>
      </div>

      <div v-else class="market-empty">
        <h2>No payment method saved yet</h2>
        <p>Finish one checkout and the last chosen method will appear here for quick reference.</p>
      </div>

      <div class="account-form__actions">
        <RouterLink class="market-button market-button--primary" to="/cart">
          Go to cart
        </RouterLink>
        <RouterLink class="market-button market-button--secondary" to="/menyra-e-pageses">
          Checkout payment step
        </RouterLink>
      </div>
    </section>
  </AccountUtilityShell>

  <section v-else class="market-page market-page--wide dashboard-page" aria-label="Payment Methods">
    <div class="market-empty account-gate">
      <h2>Sign in to manage payment methods</h2>
      <p>Login first to view your payment area and continue with checkout faster.</p>
      <div class="account-gate__actions">
        <RouterLink class="market-button market-button--primary" to="/login?redirect=%2Fpayments">
          Login
        </RouterLink>
        <RouterLink class="market-button market-button--secondary" to="/signup?redirect=%2Fpayments">
          Sign up
        </RouterLink>
      </div>
    </div>
  </section>
</template>
