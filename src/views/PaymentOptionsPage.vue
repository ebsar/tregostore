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
  persistOrderSuccessSnapshot,
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
    if (!stripeStatus && !stripeSessionId) {
      router.replace("/adresa-e-porosise");
      return;
    }

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
      ? `${data.message || "Porosia u dergua per konfirmim."} ${notificationWarnings.join(" ")}`
      : (data.message || "Porosia u dergua per konfirmim.");
    persistOrderSuccessSnapshot({
      order: data.order,
      message: confirmationMessage,
    });
    clearCheckoutFlowState();
    await router.push({
      path: "/porosia-u-konfirmua",
      query: data?.order?.id ? { order: String(data.order.id) } : {},
    });
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
      ? `${data.message || "Pagesa u konfirmua me sukses, porosia u dergua per konfirmim."} ${notificationWarnings.join(" ")}`
      : (data.message || "Pagesa u konfirmua me sukses, porosia u dergua per konfirmim.");
    persistOrderSuccessSnapshot({
      order: data.order,
      message: confirmationMessage,
      paymentStatus: data.paymentStatus,
      stripeStatus: data.stripeStatus,
    });
    clearCheckoutFlowState();
    await router.replace({ path: route.path, query: {} });
    await router.push({
      path: "/porosia-u-konfirmua",
      query: data?.order?.id ? { order: String(data.order.id) } : {},
    });
  } finally {
    submitting.value = false;
  }
}
</script>

<template>
  <section class="market-page market-page--wide checkout-page" aria-label="Menyra e pageses">
    <header class="market-page__header">
      <div class="market-page__header-copy">
        <p class="market-page__eyebrow">Checkout</p>
        <h1>Zgjedhe menyren e pageses</h1>
        <p>Zgjidhe formen e pageses per ta perfunduar porosine.</p>
      </div>
      <div class="checkout-progress" aria-label="Checkout steps">
        <span class="is-active">Address</span>
        <span class="is-active">Shipping</span>
        <span class="is-active">Payment</span>
      </div>
    </header>

    <div
      v-if="ui.message"
      class="market-status"
      :class="{ 'market-status--error': ui.type === 'error', 'market-status--success': ui.type === 'success' }"
      role="status"
      aria-live="polite"
    >
      {{ ui.message }}
    </div>

    <div class="checkout-page__shell">
      <section class="market-card checkout-section">
        <div class="market-page__header">
          <div class="market-page__header-copy">
            <p class="market-page__eyebrow">Order controls</p>
            <h2>Dergesa dhe pagesa</h2>
          </div>
        </div>

        <div class="checkout-form__row">
          <div class="market-card market-card--padded">
            <p class="market-page__eyebrow">Kodi promocional</p>
            <div class="checkout-form">
              <input v-model="promoCode" type="text" placeholder="p.sh. TREGO10" autocomplete="off">
              <button class="market-button market-button--secondary" type="button" @click="applyPromotion">
                Apliko
              </button>
            </div>
          </div>

          <div class="market-card market-card--padded">
            <p class="market-page__eyebrow">Rezervimi i stokut</p>
            <strong>{{ reservedUntil ? `Rezervuar deri ${formatDateLabel(reservedUntil)}` : "Do te rezervohet ne checkout" }}</strong>
            <p class="section-heading__copy">
              Stoku i artikujve te zgjedhur mbahet i rezervuar per pak minuta qe checkout-i te mos humbe.
            </p>
          </div>
        </div>

        <div v-if="pricing" class="metric-grid">
          <article class="metric-card">
            <p class="metric-card__label">Nentotali</p>
            <strong>{{ formatPrice(pricing.subtotal) }}</strong>
          </article>
          <article class="metric-card">
            <p class="metric-card__label">Zbritja</p>
            <strong>{{ formatPrice(pricing.discountAmount) }}</strong>
          </article>
          <article class="metric-card">
            <p class="metric-card__label">Transporti</p>
            <strong>{{ formatPrice(pricing.shippingAmount) }}</strong>
          </article>
          <article class="metric-card">
            <p class="metric-card__label">Totali i ri</p>
            <strong>{{ formatPrice(pricing.total) }}</strong>
          </article>
        </div>

        <div v-if="pricing?.shippingRuleMessage" class="market-status market-status--compact">
          <span>
            {{ pricing.shippingRuleMessage }}
            {{
              pricing.cityZoneLabel || pricing.shippingCitySurcharge > 0 || pricing.shippingSubtotalDiscount > 0
                ? ` • ${pricing.cityZoneLabel || "Qyteti i zgjedhur"}`
                : ""
            }}
          </span>
        </div>
      </section>

      <section
        v-if="Array.isArray(pricing?.shippingBreakdown) && pricing.shippingBreakdown.length > 0"
        class="market-card checkout-section"
      >
        <div class="market-page__header">
          <div class="market-page__header-copy">
            <p class="market-page__eyebrow">Shipping breakdown</p>
            <h2>Marketplace delivery by seller</h2>
          </div>
        </div>

        <div class="dashboard-stat-grid">
          <article
            v-for="entry in pricing.shippingBreakdown"
            :key="`${entry.businessUserId}-${entry.deliveryMethod}`"
            class="dashboard-stat-card market-card"
          >
            <div class="search-toolbar">
              <span>{{ entry.businessName || "Marketplace" }}</span>
              <strong>{{ formatPrice(entry.shippingAmount) }}</strong>
            </div>
            <p class="section-heading__copy">
              {{ entry.deliveryLabel }}<span v-if="entry.estimatedDeliveryText"> • {{ entry.estimatedDeliveryText }}</span>
            </p>
            <p v-if="entry.cityZoneLabel || entry.citySurcharge > 0" class="section-heading__copy">
              {{ entry.cityZoneLabel || "Qyteti i zgjedhur" }}
              <span v-if="entry.citySurcharge > 0"> • Shtese {{ formatPrice(entry.citySurcharge) }}</span>
            </p>
            <p v-if="entry.pickupAddress || entry.pickupHours" class="section-heading__copy">
              <span v-if="entry.pickupAddress">{{ entry.pickupAddress }}</span>
              <span v-if="entry.pickupAddress && entry.pickupHours"> • </span>
              <span v-if="entry.pickupHours">{{ entry.pickupHours }}</span>
            </p>
            <a
              v-if="entry.pickupMapUrl"
              class="market-button market-button--ghost"
              :href="entry.pickupMapUrl"
              target="_blank"
              rel="noreferrer"
            >
              Hap lokacionin ne maps
            </a>
          </article>
        </div>
      </section>

      <section class="market-card checkout-section">
        <div class="market-page__header">
          <div class="market-page__header-copy">
            <p class="market-page__eyebrow">Delivery</p>
            <h2>Zgjidh menyren e dergeses</h2>
          </div>
        </div>

        <div class="checkout-options">
          <button
            v-for="(option, index) in deliveryOptions"
            :key="option.value"
            class="checkout-option"
            type="button"
            :aria-pressed="selectedDeliveryMethod === option.value"
            @click="handleDeliverySelection(option.value)"
          >
            <div class="search-toolbar">
              <div>
                <span>{{ option.badge || `Opsioni ${String(index + 1).padStart(2, '0')}` }}</span>
                <strong>{{ option.label }}</strong>
              </div>
              <strong>{{ formatPrice(option.shippingAmount) }}</strong>
            </div>
            <p class="section-heading__copy">{{ option.description }}</p>
            <div class="search-toolbar">
              <span>{{ option.estimatedDeliveryText }}</span>
              <span>{{ selectedDeliveryMethod === option.value ? "Selected" : "Available" }}</span>
            </div>
          </button>
        </div>
      </section>

      <section class="market-card checkout-section">
        <div class="market-page__header">
          <div class="market-page__header-copy">
            <p class="market-page__eyebrow">Payment</p>
            <h2>Zgjidh menyren e pageses</h2>
          </div>
        </div>

        <div class="payment-options">
          <button
            class="payment-option"
            type="button"
            :aria-pressed="selectedMethod === 'cash'"
            @click="handlePaymentSelection('cash')"
          >
            <div class="search-toolbar">
              <div>
                <span>Opsioni 01</span>
                <strong>Pagese cash</strong>
              </div>
              <span>Paguan ne pranim</span>
            </div>
            <p class="section-heading__copy">
              Paguani kur porosia te arrije te ju dhe ruani fleksibilitetin e biznesit tuaj.
            </p>
            <div class="search-toolbar">
              <span>{{ formatDeliveryMethodLabel(selectedDeliveryMethod) }}</span>
              <span>Cash on delivery</span>
            </div>
          </button>

          <button
            class="payment-option"
            type="button"
            :aria-pressed="selectedMethod === 'card-online'"
            @click="handlePaymentSelection('card-online')"
          >
            <div class="search-toolbar">
              <div>
                <span>Opsioni 02</span>
                <strong>Pagese me karte</strong>
              </div>
              <span>Stripe</span>
            </div>
            <p class="section-heading__copy">
              Drejtojeni pagesen drejt Stripe dhe perfundoni transaksionin me imazh profesional.
            </p>
            <div class="search-toolbar">
              <span>Online checkout</span>
              <span>{{ pricing?.estimatedDeliveryText || "Test mode" }}</span>
            </div>
          </button>
        </div>

        <div class="checkout-actions">
          <button class="market-button market-button--ghost" type="button" @click="router.push('/adresa-e-porosise')">
            Kthehu te adresa
          </button>
        </div>
      </section>
    </div>
  </section>
</template>
