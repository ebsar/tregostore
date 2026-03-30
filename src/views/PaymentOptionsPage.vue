<script setup>
import { onMounted, reactive, ref } from "vue";
import { useRoute, useRouter } from "vue-router";
import { requestJson, resolveApiMessage } from "../lib/api";
import {
  clearCheckoutFlowState,
  DELIVERY_METHOD_OPTIONS,
  formatDeliveryMethodLabel,
  formatDateLabel,
  formatPrice,
  persistCheckoutDeliveryMethod,
  persistCheckoutPaymentMethod,
  persistOrderConfirmationMessage,
  readCheckoutAddressDraft,
  readCheckoutDeliveryMethod,
  readCheckoutPaymentMethod,
  readCheckoutSelectedCartIds,
} from "../lib/shop";
import { bumpCatalogRevision, ensureSessionLoaded, markRouteReady } from "../stores/app-state";

const route = useRoute();
const router = useRouter();
const selectedMethod = ref(readCheckoutPaymentMethod());
const selectedDeliveryMethod = ref(readCheckoutDeliveryMethod());
const submitting = ref(false);
const promoCode = ref("");
const pricing = ref(null);
const reservedUntil = ref("");
const deliveryOptions = ref([...DELIVERY_METHOD_OPTIONS]);
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

    await reserveCheckoutStock();
    await refreshPricingSummary();

  } finally {
    markRouteReady();
  }
});

async function handleDeliverySelection(method) {
  const nextMethod = String(method || "").trim().toLowerCase() || "standard";
  selectedDeliveryMethod.value = nextMethod;
  persistCheckoutDeliveryMethod(nextMethod);
  await refreshPricingSummary();
}

function syncDeliveryOptions(pricingPayload) {
  const nextOptions = Array.isArray(pricingPayload?.availableDeliveryMethods)
    && pricingPayload.availableDeliveryMethods.length > 0
    ? pricingPayload.availableDeliveryMethods
    : DELIVERY_METHOD_OPTIONS;

  deliveryOptions.value = nextOptions;
  const normalizedSelected = String(pricingPayload?.deliveryMethod || selectedDeliveryMethod.value || "standard")
    .trim()
    .toLowerCase() || "standard";
  if (normalizedSelected !== selectedDeliveryMethod.value) {
    selectedDeliveryMethod.value = normalizedSelected;
    persistCheckoutDeliveryMethod(normalizedSelected);
  }
}

async function handlePaymentSelection(method) {
  if (submitting.value) {
    return;
  }

  selectedMethod.value = method;
  ui.message = "";

  if (method === "card-online") {
    await startStripeCheckout();
    return;
  }

  await submitCashOrder();
}

async function reserveCheckoutStock() {
  const selectedCartIds = readCheckoutSelectedCartIds();
  if (selectedCartIds.length === 0) {
    return;
  }

  const { response, data } = await requestJson("/api/checkout/reserve", {
    method: "POST",
    body: JSON.stringify({ cartItemIds: selectedCartIds }),
  });

  if (!response.ok || !data?.ok) {
    ui.message = resolveApiMessage(data, "Stoku nuk u rezervua.");
    ui.type = "error";
    return;
  }

  reservedUntil.value = String(data.reservedUntil || "").trim();
}

async function refreshPricingSummary({ announceSuccess = false } = {}) {
  const selectedCartIds = readCheckoutSelectedCartIds();
  const checkoutAddress = readCheckoutAddressDraft() || {};
  const { response, data } = await requestJson("/api/promotions/apply", {
    method: "POST",
    body: JSON.stringify({
      cartItemIds: selectedCartIds,
      promoCode: promoCode.value,
      deliveryMethod: selectedDeliveryMethod.value,
      ...checkoutAddress,
    }),
  });

  if (!response.ok || !data?.ok) {
    if (String(promoCode.value || "").trim()) {
      pricing.value = null;
    }
    ui.message = resolveApiMessage(data, "Kuponi nuk u aplikua.");
    ui.type = "error";
    return;
  }

  pricing.value = data.pricing || null;
  syncDeliveryOptions(pricing.value);
  promoCode.value = String(pricing.value?.promoCode || promoCode.value || "").trim().toUpperCase();
  if (String(pricing.value?.deliveryNotice || "").trim()) {
    ui.message = String(pricing.value.deliveryNotice).trim();
    ui.type = "info";
  } else if (announceSuccess) {
    ui.message = data.message || "Kuponi u aplikua.";
    ui.type = "success";
  } else if (!String(promoCode.value || "").trim()) {
    ui.message = "";
    ui.type = "";
  }
}

async function applyPromotion() {
  await refreshPricingSummary({ announceSuccess: true });
}

async function submitCashOrder() {
  const checkoutAddress = readCheckoutAddressDraft();
  const selectedCartIds = readCheckoutSelectedCartIds();
  await reserveCheckoutStock();
  const payload = {
    cartItemIds: selectedCartIds,
    paymentMethod: selectedMethod.value,
    deliveryMethod: selectedDeliveryMethod.value,
    promoCode: promoCode.value,
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
  await reserveCheckoutStock();
  const payload = {
    cartItemIds: selectedCartIds,
    paymentMethod: "card-online",
    deliveryMethod: selectedDeliveryMethod.value,
    promoCode: promoCode.value,
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

    pricing.value = data.pricing || pricing.value;
    syncDeliveryOptions(pricing.value);
    reservedUntil.value = String(data.reservedUntil || reservedUntil.value || "").trim();
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
          <p class="section-label">Checkout</p>
          <h2>Dergesa dhe pagesa</h2>
        </div>
      </div>

      <div class="form-message" :class="ui.type" role="status" aria-live="polite">
        {{ ui.message }}
      </div>

      <div class="marketplace-status-card">
        <div class="field">
          <span>Kodi promocional</span>
          <div class="field-row">
            <input v-model="promoCode" type="text" placeholder="p.sh. TREGO10" autocomplete="off">
            <button class="button-secondary" type="button" @click="applyPromotion">Apliko</button>
          </div>
        </div>
        <div>
          <p class="section-label">Rezervimi i stokut</p>
          <strong>{{ reservedUntil ? `Rezervuar deri ${formatDateLabel(reservedUntil)}` : "Do te rezervohet ne checkout" }}</strong>
          <p class="section-text">
            Stoku i artikujve te zgjedhur mbahet i rezervuar per pak minuta qe checkout-i te mos humbe.
          </p>
        </div>
      </div>

      <div v-if="pricing" class="cart-summary-grid">
        <div class="summary-chip">
          <span>Nentotali</span>
          <strong>{{ formatPrice(pricing.subtotal) }}</strong>
        </div>
        <div class="summary-chip">
          <span>Zbritja</span>
          <strong>{{ formatPrice(pricing.discountAmount) }}</strong>
        </div>
        <div class="summary-chip">
          <span>Transporti</span>
          <strong>{{ formatPrice(pricing.shippingAmount) }}</strong>
        </div>
        <div class="summary-chip">
          <span>Totali i ri</span>
          <strong>{{ formatPrice(pricing.total) }}</strong>
        </div>
      </div>

      <div v-if="pricing?.shippingRuleMessage" class="marketplace-status-card checkout-shipping-note">
        <div>
          <p class="section-label">Transporti dinamik</p>
          <strong>{{ pricing.shippingRuleMessage }}</strong>
          <p class="section-text">
            Qyteti / zona: {{ pricing.cityZoneLabel || "Qyteti i zgjedhur" }}
            <span v-if="pricing.shippingCitySurcharge > 0">
              · Shtese qyteti {{ formatPrice(pricing.shippingCitySurcharge) }}
            </span>
            <span v-if="pricing.shippingSubtotalDiscount > 0">
              · Zbritje shporte {{ formatPrice(pricing.shippingSubtotalDiscount) }}
            </span>
          </p>
        </div>
      </div>

      <div
        v-if="Array.isArray(pricing?.shippingBreakdown) && pricing.shippingBreakdown.length > 0"
        class="checkout-shipping-breakdown"
      >
        <article
          v-for="entry in pricing.shippingBreakdown"
          :key="`${entry.businessUserId}-${entry.deliveryMethod}`"
          class="summary-chip"
        >
          <span>{{ entry.businessName || "Marketplace" }}</span>
          <strong>{{ formatPrice(entry.shippingAmount) }}</strong>
          <small>
            {{ entry.deliveryLabel }}
            <span v-if="entry.estimatedDeliveryText"> · {{ entry.estimatedDeliveryText }}</span>
          </small>
          <small v-if="entry.cityZoneLabel || entry.citySurcharge > 0">
            <span>{{ entry.cityZoneLabel || "Qyteti i zgjedhur" }}</span>
            <span v-if="entry.citySurcharge > 0"> · Shtese {{ formatPrice(entry.citySurcharge) }}</span>
          </small>
          <small v-if="entry.pickupAddress || entry.pickupHours">
            <span v-if="entry.pickupAddress">{{ entry.pickupAddress }}</span>
            <span v-if="entry.pickupAddress && entry.pickupHours"> · </span>
            <span v-if="entry.pickupHours">{{ entry.pickupHours }}</span>
          </small>
        </article>
      </div>

      <div class="payment-options-card">
        <div class="profile-card-header">
          <div>
            <p class="section-label">Dergesa</p>
            <h2>Zgjidh menyren e dergeses</h2>
          </div>
        </div>

        <div class="payment-options-grid">
          <button
            v-for="(option, index) in deliveryOptions"
            :key="option.value"
            class="payment-option-card delivery-option-card"
            :class="{ active: selectedDeliveryMethod === option.value }"
            type="button"
            @click="handleDeliverySelection(option.value)"
          >
            <div class="payment-option-card-header">
              <span class="checkout-choice-label">{{ option.badge || `Opsioni ${String(index + 1).padStart(2, '0')}` }}</span>
              <strong class="checkout-choice-title">{{ option.label }}</strong>
            </div>
            <p class="payment-option-copy">
              {{ option.description }}
            </p>
            <div class="payment-option-cta">
              <span class="payment-option-chip">{{ option.estimatedDeliveryText }}</span>
              <span class="payment-option-status">{{ formatPrice(option.shippingAmount) }}</span>
            </div>
          </button>
        </div>
      </div>

      <div class="payment-options-grid">
        <button
          class="payment-option-card"
          :class="{ active: selectedMethod === 'cash' }"
          type="button"
          aria-pressed="false"
          @click="handlePaymentSelection('cash')"
        >
          <div class="payment-option-card-header">
            <span class="checkout-choice-label">Opsioni 01</span>
            <strong class="checkout-choice-title">Pagesë cash</strong>
          </div>
          <p class="payment-option-copy">
            Paguani kur porosia të arrijë te ju dhe ruani fleksibilitetin e biznesit tuaj.
          </p>
          <div class="payment-option-cta">
            <span class="payment-option-chip">{{ formatDeliveryMethodLabel(selectedDeliveryMethod) }}</span>
            <span class="payment-option-status">Paguan ne pranim</span>
          </div>
        </button>

        <button
          class="payment-option-card"
          :class="{ active: selectedMethod === 'card-online' }"
          type="button"
          aria-pressed="false"
          @click="handlePaymentSelection('card-online')"
        >
          <div class="payment-option-card-header">
            <span class="checkout-choice-label">Opsioni 02</span>
            <strong class="checkout-choice-title">Pagesë me kartë</strong>
          </div>
          <p class="payment-option-copy">
            Drejtojeni pagesën drejt Stripe dhe përfundoni transaksionin me imazh profesional.
          </p>
          <div class="payment-option-logos">
            <span class="payment-option-logo-badge">Stripe</span>
            <span class="payment-option-logo-label">{{ pricing?.estimatedDeliveryText || "Test mode" }}</span>
          </div>
        </button>
      </div>

      <div class="profile-form-actions subtle-actions">
        <button class="ghost-button profile-cancel-button" type="button" @click="router.push('/adresa-e-porosise')">
          Kthehu te adresa
        </button>
      </div>
    </section>
  </section>
</template>
