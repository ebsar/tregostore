<script setup>
import { onMounted, reactive, ref } from "vue";
import { useRoute, useRouter } from "vue-router";
import { requestJson, resolveApiMessage } from "../lib/api";
import {
  clearCheckoutFlowState,
  persistCheckoutPaymentMethod,
  persistOrderConfirmationMessage,
  readCheckoutAddressDraft,
  readCheckoutPaymentMethod,
  readCheckoutSelectedCartIds,
} from "../lib/shop";
import { bumpCatalogRevision, ensureSessionLoaded, markRouteReady } from "../stores/app-state";

const route = useRoute();
const router = useRouter();
const selectedMethod = ref(readCheckoutPaymentMethod());
const submitting = ref(false);
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

    const stripeStatus = String(route.query.stripeStatus || "").trim().toLowerCase();
    const stripeSessionId = String(route.query.session_id || "").trim();
    if (stripeStatus === "cancelled") {
      ui.message = "Pagesa online u anulua. Mund te provosh perseri kur te jesh gati.";
      ui.type = "error";
      await router.replace({ path: route.path, query: {} });
      return;
    }

    if (stripeStatus === "success" && stripeSessionId) {
      selectedMethod.value = "card-online";
      persistCheckoutPaymentMethod("card-online");
      await confirmStripePayment(stripeSessionId);
      return;
    }

    const checkoutAddress = readCheckoutAddressDraft();
    if (!checkoutAddress?.addressLine) {
      router.replace("/adresa-e-porosise");
      return;
    }

    if (readCheckoutSelectedCartIds().length === 0) {
      router.replace("/cart");
      return;
    }

  } finally {
    markRouteReady();
  }
});

async function handleConfirm() {
  if (submitting.value) {
    return;
  }

  ui.message = "";
  if (!selectedMethod.value) {
    ui.message = "Zgjedhe nje menyre pagese para se te vazhdosh.";
    ui.type = "error";
    return;
  }

  if (selectedMethod.value === "card-online") {
    await startStripeCheckout();
    return;
  }

  await submitCashOrder();
}

async function submitCashOrder() {
  const checkoutAddress = readCheckoutAddressDraft();
  const selectedCartIds = readCheckoutSelectedCartIds();
  const payload = {
    cartItemIds: selectedCartIds,
    paymentMethod: selectedMethod.value,
    ...checkoutAddress,
  };

  submitting.value = true;
  try {
    const { response, data } = await requestJson("/api/orders/create", {
      method: "POST",
      body: JSON.stringify(payload),
    });

    if (!response.ok || !data?.ok) {
      ui.message = resolveApiMessage(data, "Porosia nuk u konfirmua.");
      ui.type = "error";
      return;
    }

    persistCheckoutPaymentMethod(selectedMethod.value);
    bumpCatalogRevision();
    const notificationWarnings = Array.isArray(data.notificationWarnings)
      ? data.notificationWarnings.filter(Boolean)
      : [];
    const confirmationMessage = notificationWarnings.length > 0
      ? `${data.message || "Porosia u konfirmua me sukses."} ${notificationWarnings.join(" ")}`
      : (data.message || "Porosia u konfirmua me sukses.");
    persistOrderConfirmationMessage(confirmationMessage);
    clearCheckoutFlowState();
    router.push("/porosite");
  } finally {
    submitting.value = false;
  }
}

async function startStripeCheckout() {
  const checkoutAddress = readCheckoutAddressDraft();
  const selectedCartIds = readCheckoutSelectedCartIds();
  const payload = {
    cartItemIds: selectedCartIds,
    paymentMethod: "card-online",
    ...checkoutAddress,
  };

  submitting.value = true;
  ui.message = "";
  try {
    const { response, data } = await requestJson("/api/payments/stripe/checkout", {
      method: "POST",
      body: JSON.stringify(payload),
    });

    if (!response.ok || !data?.ok || !data.checkoutUrl) {
      ui.message = resolveApiMessage(data, "Stripe test checkout nuk u hap.");
      ui.type = "error";
      return;
    }

    persistCheckoutPaymentMethod("card-online");
    window.location.href = String(data.checkoutUrl).trim();
  } finally {
    submitting.value = false;
  }
}

async function confirmStripePayment(stripeSessionId) {
  submitting.value = true;
  ui.message = "Po verifikohet pagesa me Stripe...";
  ui.type = "";
  try {
    const { response, data } = await requestJson("/api/payments/stripe/confirm", {
      method: "POST",
      body: JSON.stringify({ stripeSessionId }),
    });

    if (!response.ok || !data?.ok) {
      ui.message = resolveApiMessage(data, "Pagesa nuk u konfirmua nga Stripe.");
      ui.type = "error";
      return;
    }

    persistCheckoutPaymentMethod("card-online");
    bumpCatalogRevision();
    const notificationWarnings = Array.isArray(data.notificationWarnings)
      ? data.notificationWarnings.filter(Boolean)
      : [];
    const confirmationMessage = notificationWarnings.length > 0
      ? `${data.message || "Pagesa u konfirmua me sukses."} ${notificationWarnings.join(" ")}`
      : (data.message || "Pagesa u konfirmua me sukses.");
    persistOrderConfirmationMessage(confirmationMessage);
    clearCheckoutFlowState();
    await router.replace({ path: route.path, query: {} });
    await router.push(data.redirectTo || "/porosite");
  } finally {
    submitting.value = false;
  }
}
</script>

<template>
  <section class="account-page checkout-address-page" aria-label="Menyra e pageses">
    <header class="account-header profile-page-header">
      <div>
        <p class="section-label">Checkout</p>
        <h1>Zgjedhe menyren e pageses</h1>
        <p class="section-text">
          Zgjidhe formen e pageses per ta perfunduar porosine.
        </p>
      </div>
    </header>

    <section class="card checkout-address-card">
      <div class="profile-card-header">
        <div>
          <p class="section-label">Pagesa</p>
          <h2>Opsionet e pageses</h2>
        </div>
      </div>

      <div class="form-message" :class="ui.type" role="status" aria-live="polite">
        {{ ui.message }}
      </div>

      <div class="payment-options-grid">
        <button
          class="payment-option-card"
          :class="{ active: selectedMethod === 'cash' }"
          type="button"
          @click="selectedMethod = 'cash'"
        >
          Pages cash
        </button>

        <button
          class="payment-option-card"
          :class="{ active: selectedMethod === 'card-online' }"
          type="button"
          @click="selectedMethod = 'card-online'"
        >
          Pages me kartel Online (Stripe test)
        </button>
      </div>

      <div class="profile-form-actions">
        <button class="profile-save-button" type="button" :disabled="submitting" @click="handleConfirm">
          {{
            submitting
              ? (selectedMethod === "card-online" ? "Po vazhdohet me Stripe..." : "Duke konfirmuar porosine...")
              : "Konfirmo menyren e pageses"
          }}
        </button>
        <button class="ghost-button profile-cancel-button" type="button" @click="router.push('/adresa-e-porosise')">
          Cancel
        </button>
      </div>
    </section>
  </section>
</template>
