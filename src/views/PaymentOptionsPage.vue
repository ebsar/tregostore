<script setup>
import { onMounted, reactive, ref } from "vue";
import { useRouter } from "vue-router";
import { requestJson, resolveApiMessage } from "../lib/api";
import {
  clearCheckoutFlowState,
  persistCheckoutPaymentMethod,
  persistOrderConfirmationMessage,
  readCheckoutAddressDraft,
  readCheckoutPaymentMethod,
  readCheckoutSelectedCartIds,
} from "../lib/shop";
import { ensureSessionLoaded, markRouteReady } from "../stores/app-state";

const router = useRouter();
const selectedMethod = ref(readCheckoutPaymentMethod());
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
  ui.message = "";
  if (!selectedMethod.value) {
    ui.message = "Zgjedhe nje menyre pagese para se te vazhdosh.";
    ui.type = "error";
    return;
  }

  const checkoutAddress = readCheckoutAddressDraft();
  const selectedCartIds = readCheckoutSelectedCartIds();
  const payload = {
    productIds: selectedCartIds,
    paymentMethod: selectedMethod.value,
    ...checkoutAddress,
  };

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
  const notificationWarnings = Array.isArray(data.notificationWarnings)
    ? data.notificationWarnings.filter(Boolean)
    : [];
  const confirmationMessage = notificationWarnings.length > 0
    ? `${data.message || "Porosia u konfirmua me sukses."} ${notificationWarnings.join(" ")}`
    : (data.message || "Porosia u konfirmua me sukses.");
  persistOrderConfirmationMessage(confirmationMessage);
  clearCheckoutFlowState();
  router.push("/porosite");
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
          Pages me kartel Online
        </button>
      </div>

      <div class="profile-form-actions">
        <button class="profile-save-button" type="button" @click="handleConfirm">
          Konfirmo menyren e pageses
        </button>
        <button class="ghost-button profile-cancel-button" type="button" @click="router.push('/adresa-e-porosise')">
          Cancel
        </button>
      </div>
    </section>
  </section>
</template>
