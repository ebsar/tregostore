<script setup lang="ts">
import { Browser } from "@capacitor/browser";
import { Capacitor } from "@capacitor/core";
import { IonButton, IonContent, IonPage } from "@ionic/vue";
import { computed, onMounted, reactive, ref } from "vue";
import { useRouter } from "vue-router";
import AppPageHeader from "../components/AppPageHeader.vue";
import {
  clearCheckoutFlowState,
  DELIVERY_METHOD_OPTIONS,
  formatDeliveryMethodLabel,
  persistCheckoutDeliveryMethod,
  persistCheckoutPaymentMethod,
  persistOrderConfirmationMessage,
  readCheckoutAddressDraft,
  readCheckoutDeliveryMethod,
  readCheckoutSelectedCartIds,
} from "../lib/checkout";
import { requestJson, resolveApiMessage } from "../lib/api";
import { formatDateLabel, formatPrice } from "../lib/format";
import { ensureSession, refreshCounts, sessionState } from "../stores/session";

const router = useRouter();
const selectedPaymentMethod = ref("cash-on-delivery");
const selectedDeliveryMethod = ref(readCheckoutDeliveryMethod());
const promoCode = ref("");
const reservedUntil = ref("");
const pricing = ref<any | null>(null);
const ui = reactive({
  message: "",
  type: "",
  busy: false,
});
const platform = Capacitor.getPlatform();
const digitalWalletLabel = computed(() => (platform === "ios" ? "Apple Pay" : "Google Pay"));
const digitalWalletCopy = computed(() =>
  platform === "ios"
    ? "Vazhdo me secure checkout brenda app-it dhe perdor Apple Pay nese eshte aktiv ne pajisjen tende."
    : "Vazhdo me secure checkout brenda app-it dhe perdor Google Pay nese eshte aktiv ne pajisjen tende.",
);

onMounted(async () => {
  await ensureSession();
  if (!sessionState.user) {
    router.replace("/login?redirect=/checkout/payment");
    return;
  }

  if (!readCheckoutAddressDraft()?.addressLine) {
    router.replace("/checkout/address");
    return;
  }

  if (readCheckoutSelectedCartIds().length === 0) {
    router.replace("/tabs/cart");
    return;
  }

  await reserveCheckoutStock();
  await refreshPricingSummary();
});

async function reserveCheckoutStock() {
  const selectedCartIds = readCheckoutSelectedCartIds();
  const { response, data } = await requestJson<any>("/api/checkout/reserve", {
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

async function refreshPricingSummary() {
  const selectedCartIds = readCheckoutSelectedCartIds();
  const checkoutAddress = readCheckoutAddressDraft() || {};
  const { response, data } = await requestJson<any>("/api/promotions/apply", {
    method: "POST",
    body: JSON.stringify({
      cartItemIds: selectedCartIds,
      promoCode: promoCode.value,
      deliveryMethod: selectedDeliveryMethod.value,
      ...checkoutAddress,
    }),
  });

  if (!response.ok || !data?.ok) {
    ui.message = resolveApiMessage(data, "Kuponi nuk u aplikua.");
    ui.type = "error";
    return;
  }

  pricing.value = data.pricing || null;
  ui.message = data.message || "";
  ui.type = ui.message ? "info" : "";
}

async function applyPromo() {
  await refreshPricingSummary();
}

async function submitCashOrder() {
  const selectedCartIds = readCheckoutSelectedCartIds();
  const checkoutAddress = readCheckoutAddressDraft() || {};
  ui.busy = true;
  try {
    const { response, data } = await requestJson<any>("/api/orders/create", {
      method: "POST",
      body: JSON.stringify({
        cartItemIds: selectedCartIds,
        paymentMethod: "cash-on-delivery",
        deliveryMethod: selectedDeliveryMethod.value,
        promoCode: promoCode.value,
        ...checkoutAddress,
      }),
    });

    if (!response.ok || !data?.ok) {
      ui.message = resolveApiMessage(data, "Porosia nuk u konfirmua.");
      ui.type = "error";
      return;
    }

    persistCheckoutPaymentMethod("cash-on-delivery");
    persistOrderConfirmationMessage(String(data.message || "Porosia u dergua per konfirmim."));
    clearCheckoutFlowState();
    await refreshCounts();
    router.replace("/orders");
  } finally {
    ui.busy = false;
  }
}

async function openStripeCheckout() {
  const selectedCartIds = readCheckoutSelectedCartIds();
  const checkoutAddress = readCheckoutAddressDraft() || {};
  ui.busy = true;
  try {
    const { response, data } = await requestJson<any>("/api/payments/stripe/checkout", {
      method: "POST",
      body: JSON.stringify({
        cartItemIds: selectedCartIds,
        paymentMethod: "card-online",
        deliveryMethod: selectedDeliveryMethod.value,
        promoCode: promoCode.value,
        ...checkoutAddress,
      }),
    });

    if (!response.ok || !data?.ok || !data.checkoutUrl) {
      ui.message = resolveApiMessage(data, "Stripe checkout nuk u hap.");
      ui.type = "error";
      return;
    }

    persistCheckoutPaymentMethod("card-online");
    const checkoutUrl = String(data.checkoutUrl).trim();
    if (!checkoutUrl) {
      ui.message = "Stripe checkout nuk u hap.";
      ui.type = "error";
      return;
    }

    if (Capacitor.isNativePlatform()) {
      await Browser.open({
        url: checkoutUrl,
        presentationStyle: "fullscreen",
        windowName: "_self",
      });
      ui.message = "Checkout u hap brenda app-it.";
      ui.type = "info";
      return;
    }

    window.location.href = checkoutUrl;
  } finally {
    ui.busy = false;
  }
}

function selectDelivery(method: string) {
  selectedDeliveryMethod.value = method;
  persistCheckoutDeliveryMethod(method);
  void refreshPricingSummary();
}
</script>

<template>
  <IonPage>
    <IonContent :fullscreen="true">
      <div>
        <AppPageHeader
          kicker="Checkout"
          title="Zgjedhe dergesen dhe pagesen."
          subtitle="Ky hap llogarit subtotalin, transportin dhe vazhdon me te njejtat endpoint-e si ne web."
          back-to="/checkout/address"
        />

        <section>
          <div>
            <p>Rezervimi</p>
            <h2>{{ reservedUntil ? `Rezervuar deri ${formatDateLabel(reservedUntil)}` : "Po pergatitet checkout" }}</h2>
            <p>Stoku mbahet perkohesisht i rezervuar qe te mos humbesh porosine gjate procesit.</p>
          </div>

          <label>
            <span>Kodi promocional</span>
            <div>
              <input v-model="promoCode" type="text" placeholder="p.sh. TREGO10" />
              <IonButton @click="applyPromo">Apliko</IonButton>
            </div>
          </label>
        </section>

        <section>
          <div>
            <p>Dergesa</p>
            <h2>{{ formatDeliveryMethodLabel(selectedDeliveryMethod) }}</h2>
          </div>

          <button
            v-for="option in DELIVERY_METHOD_OPTIONS"
            :key="option.value"
           
           
            type="button"
            @click="selectDelivery(option.value)"
          >
            <strong>{{ option.label }}</strong>
            <span>{{ option.description }}</span>
          </button>
        </section>

        <section v-if="pricing">
          <div>
            <div>
              <span>Nentotali</span>
              <strong>{{ formatPrice(pricing.subtotal) }}</strong>
            </div>
            <div>
              <span>Zbritja</span>
              <strong>{{ formatPrice(pricing.discountAmount) }}</strong>
            </div>
            <div>
              <span>Transporti</span>
              <strong>{{ formatPrice(pricing.shippingAmount) }}</strong>
            </div>
            <div>
              <span>Totali</span>
              <strong>{{ formatPrice(pricing.total) }}</strong>
            </div>
          </div>
        </section>

        <section>
          <div>
            <p>Pagesa</p>
            <h2>Zgjedhja finale</h2>
          </div>

          <button
           
           
            type="button"
            @click="selectedPaymentMethod = 'cash-on-delivery'"
          >
            <strong>Pagese cash</strong>
            <span>Vazhdo direkt me porosine dhe pagesa kryhet ne pranimin e saj.</span>
          </button>

          <button
           
           
            type="button"
            @click="selectedPaymentMethod = 'card-online'"
          >
            <strong>{{ digitalWalletLabel }} / Karte</strong>
            <span>{{ digitalWalletCopy }}</span>
          </button>

          <div>
            <span>Adresa e ruajtur</span>
            <span>Invoice pas porosise</span>
            <span>Promo code aktiv</span>
            <span>Secure checkout ne app</span>
          </div>

          <p v-if="ui.message">{{ ui.message }}</p>

          <IonButton
           
            data-testid="checkout-payment-submit"
            :disabled="ui.busy"
            @click="selectedPaymentMethod === 'card-online' ? openStripeCheckout() : submitCashOrder()"
          >
            {{ ui.busy ? "Po procedohet..." : (selectedPaymentMethod === "card-online" ? "Vazhdo me Stripe" : "Konfirmo porosine") }}
          </IonButton>
        </section>
      </div>
    </IonContent>
  </IonPage>
</template>

