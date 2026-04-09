<script setup>
import { computed, onMounted, reactive, ref } from "vue";
import { useRouter } from "vue-router";
import { requestJson, resolveApiMessage } from "../lib/api";
import {
  DELIVERY_METHOD_OPTIONS,
  clearCheckoutFlowState,
  createEmptyAddress,
  formatPrice,
  normalizeAddress,
  persistCheckoutAddressDraft,
  persistCheckoutDeliveryMethod,
  persistCheckoutPaymentMethod,
  persistOrderConfirmationMessage,
  readCheckoutAddressDraft,
  readCheckoutDeliveryMethod,
  readCheckoutPaymentMethod,
  readCheckoutSelectedCartIds,
} from "../lib/shop";
import { bumpCatalogRevision, ensureSessionLoaded, markRouteReady } from "../stores/app-state";

const router = useRouter();
const COUNTRY_OPTIONS = [
  "Kosove",
  "Shqiperi",
  "Maqedoni e Veriut",
  "Mali i Zi",
  "Serbi",
];

const savedAddress = ref(null);
const summaryItems = ref([]);
const pricing = ref(null);
const promoCode = ref("");
const saveForLater = ref(false);
const selectedDeliveryMethod = ref(readCheckoutDeliveryMethod() || "");
const selectedMethod = ref(readCheckoutPaymentMethod() || "");
const deliveryOptions = ref([...DELIVERY_METHOD_OPTIONS]);
const checkoutSelectedIds = ref([]);
const submitting = ref(false);
const addressConfirmed = ref(false);
const shippingConfirmed = ref(false);
const confirmedAddressSignature = ref("");
const confirmedDeliveryMethod = ref("");
const formState = reactive(createEmptyAddress());
const contactState = reactive({
  fullName: "",
  email: "",
  receiveOffers: true,
  comment: "",
});
const ui = reactive({
  message: "",
  type: "",
  locationMessage: "",
  locationType: "",
  locationBusy: false,
});

const subtotalAmount = computed(() => {
  if (pricing.value) {
    return Number(pricing.value.subtotal || 0);
  }

  return summaryItems.value.reduce(
    (total, item) => total + ((Number(item.price) || 0) * Math.max(1, Number(item.quantity) || 1)),
    0,
  );
});

const discountAmount = computed(() => Number(pricing.value?.discountAmount || 0));
const shippingAmount = computed(() => {
  if (!shippingConfirmed.value) {
    return 0;
  }

  if (pricing.value) {
    return Number(pricing.value.shippingAmount || 0);
  }

  const matchedOption = deliveryOptions.value.find(
    (option) => String(option.value || "").trim().toLowerCase() === selectedDeliveryMethod.value,
  );
  return Number(matchedOption?.shippingAmount || 0);
});
const totalAmount = computed(() => Math.max(0, subtotalAmount.value - discountAmount.value + shippingAmount.value));
const totalItemsCount = computed(() =>
  summaryItems.value.reduce((total, item) => total + Math.max(1, Number(item.quantity) || 1), 0),
);
const addressReady = computed(() =>
  Boolean(
    String(formState.addressLine || "").trim()
    && String(formState.city || "").trim()
    && String(formState.country || "").trim()
    && String(formState.zipCode || "").trim()
    && String(formState.phoneNumber || "").trim(),
  ),
);
const showShippingOptions = computed(() => addressConfirmed.value);
const showPaymentOptions = computed(() => shippingConfirmed.value);
const availablePaymentMethods = computed(() => {
  if (selectedDeliveryMethod.value === "pickup") {
    return [
      {
        value: "card-online",
        title: "Paguaj me kartel",
        copy: "Per terheqje ne biznes, pagesa lejohet vetem online.",
        status: "Pagese online",
      },
    ];
  }

  return [
    {
      value: "cash",
      title: "Paguaj cash ne dorezim",
      copy: "Porosia konfirmohet dhe pagesa behet kur te arrije te ti.",
      status: "Cash on delivery",
    },
    {
      value: "card-online",
      title: "Paguaj me kartel",
      copy: "Vazhdo me Stripe per ta perfunduar pagesen online.",
      status: "Pagese online",
    },
  ];
});
const primaryCheckoutLabel = computed(() =>
  selectedMethod.value === "card-online" ? "Vazhdo me pagesen" : "Konfirmoje porosine",
);
const canSubmitCheckout = computed(() =>
  addressConfirmed.value
  && shippingConfirmed.value
  && Boolean(selectedMethod.value)
  && !submitting.value,
);

function syncPaymentMethodAvailability() {
  if (selectedDeliveryMethod.value === "pickup" && selectedMethod.value === "cash") {
    selectedMethod.value = "";
    persistCheckoutPaymentMethod("");
  }
}

function currentAddressSignature() {
  return JSON.stringify({
    addressLine: String(formState.addressLine || "").trim().toLowerCase(),
    city: String(formState.city || "").trim().toLowerCase(),
    country: String(formState.country || "").trim().toLowerCase(),
    zipCode: String(formState.zipCode || "").trim().toLowerCase(),
    phoneNumber: String(formState.phoneNumber || "").trim(),
  });
}

function invalidateCheckoutSteps({ preserveMessage = false } = {}) {
  addressConfirmed.value = false;
  shippingConfirmed.value = false;
  confirmedAddressSignature.value = "";
  confirmedDeliveryMethod.value = "";
  selectedDeliveryMethod.value = "";
  selectedMethod.value = "";
  persistCheckoutDeliveryMethod("");
  persistCheckoutPaymentMethod("");

  if (!preserveMessage) {
    ui.message = "";
    ui.type = "";
  }
}

function invalidateAddressConfirmationIfNeeded() {
  if (!addressConfirmed.value) {
    return;
  }

  if (currentAddressSignature() === confirmedAddressSignature.value) {
    return;
  }

  invalidateCheckoutSteps({ preserveMessage: true });
  ui.message = "Adresa u ndryshua. Konfirmoje perseri adresen per te vazhduar.";
  ui.type = "info";
}

onMounted(async () => {
  try {
    const user = await ensureSessionLoaded();
    if (!user) {
      router.replace("/login");
      return;
    }

    checkoutSelectedIds.value = readCheckoutSelectedCartIds();
    if (checkoutSelectedIds.value.length === 0) {
      router.replace("/cart");
      return;
    }

    contactState.fullName = String(
      user.fullName || [user.firstName, user.lastName].filter(Boolean).join(" "),
    ).trim();
    contactState.email = String(user.email || "").trim();

    await loadSavedAddress();
    await loadCheckoutPreview({ silent: true });
  } finally {
    markRouteReady();
  }
});

async function loadSavedAddress() {
  const draftAddress = readCheckoutAddressDraft();
  const fallbackAddress = draftAddress || createEmptyAddress();
  Object.assign(formState, fallbackAddress);
  if (!formState.country) {
    formState.country = "Kosove";
  }

  const { response, data } = await requestJson("/api/address");
  if (!response.ok || !data?.ok) {
    savedAddress.value = null;
    return;
  }

  savedAddress.value = data.address ? normalizeAddress(data.address) : null;
  if (!draftAddress && savedAddress.value) {
    Object.assign(formState, savedAddress.value);
  }
  if (!formState.country) {
    formState.country = savedAddress.value?.country || "Kosove";
  }
}

function syncDeliveryOptions(pricingPayload) {
  const nextOptions = Array.isArray(pricingPayload?.availableDeliveryMethods)
    && pricingPayload.availableDeliveryMethods.length > 0
    ? pricingPayload.availableDeliveryMethods
    : DELIVERY_METHOD_OPTIONS;

  deliveryOptions.value = nextOptions;
  const normalizedSelected = String(selectedDeliveryMethod.value || "").trim().toLowerCase();
  if (!normalizedSelected) {
    return;
  }

  const matchingOption = nextOptions.find(
    (option) => String(option.value || "").trim().toLowerCase() === normalizedSelected,
  );
  if (!matchingOption) {
    selectedDeliveryMethod.value = "";
    persistCheckoutDeliveryMethod("");
  }
}

async function loadCheckoutPreview({ silent = false, announceSuccess = false } = {}) {
  const selectedIds = checkoutSelectedIds.value.length > 0
    ? checkoutSelectedIds.value
    : readCheckoutSelectedCartIds();

  const [cartResult, pricingResult] = await Promise.all([
    requestJson("/api/cart"),
    requestJson("/api/promotions/apply", {
      method: "POST",
      body: JSON.stringify({
        cartItemIds: selectedIds,
        promoCode: promoCode.value,
        deliveryMethod: selectedDeliveryMethod.value || "standard",
        ...formState,
      }),
    }),
  ]);

  const { response: cartResponse, data: cartData } = cartResult;
  if (cartResponse.ok && cartData?.ok) {
    const allItems = Array.isArray(cartData.items) ? cartData.items : [];
    const selectedSet = new Set(selectedIds.map((id) => Number(id)));
    summaryItems.value = allItems.filter((item) => selectedSet.has(Number(item.id)));
  } else if (!silent) {
    ui.message = resolveApiMessage(cartData, "Produktet e checkout-it nuk u ngarkuan.");
    ui.type = "error";
  }

  const { response: pricingResponse, data: pricingData } = pricingResult;
  if (!pricingResponse.ok || !pricingData?.ok) {
    pricing.value = null;
    if (!silent) {
      ui.message = resolveApiMessage(pricingData, "Permbledhja e transportit nuk u ngarkua.");
      ui.type = "error";
    }
    return;
  }

  pricing.value = pricingData.pricing || null;
  syncDeliveryOptions(pricing.value);
  promoCode.value = String(pricing.value?.promoCode || promoCode.value || "").trim().toUpperCase();

  if (announceSuccess) {
    ui.message = pricingData.message || "Kuponi u aplikua.";
    ui.type = "success";
  } else if (!silent) {
    ui.message = "";
    ui.type = "";
  }
}

function applySavedAddress() {
  if (!savedAddress.value) {
    return;
  }

  invalidateCheckoutSteps({ preserveMessage: true });
  Object.assign(formState, savedAddress.value);
  persistCheckoutAddressDraft(formState);
  ui.message = "Adresa e ruajtur u vendos. Tani kliko konfirmo adresen.";
  ui.type = "success";
  void loadCheckoutPreview({ silent: true });
}

async function applyPromotion() {
  await loadCheckoutPreview({ announceSuccess: true });
}

function handleDeliverySelection(method) {
  const nextMethod = String(method || "").trim().toLowerCase() || "standard";
  if (selectedDeliveryMethod.value !== nextMethod) {
    shippingConfirmed.value = false;
    confirmedDeliveryMethod.value = "";
    selectedMethod.value = "";
    persistCheckoutPaymentMethod("");
  }
  selectedDeliveryMethod.value = nextMethod;
  persistCheckoutDeliveryMethod(nextMethod);
  syncPaymentMethodAvailability();
  void loadCheckoutPreview({ silent: true });
}

function handlePaymentSelection(method) {
  const nextMethod = String(method || "").trim().toLowerCase();
  if (!nextMethod) {
    return;
  }

  if (selectedDeliveryMethod.value === "pickup" && nextMethod === "cash") {
    return;
  }

  selectedMethod.value = nextMethod;
  persistCheckoutPaymentMethod(nextMethod);
}

function handleAddressContextBlur() {
  persistCheckoutAddressDraft(formState);
  invalidateAddressConfirmationIfNeeded();
  void loadCheckoutPreview({ silent: true });
}

function confirmAddressStep() {
  if (!addressReady.value) {
    ui.message = "Ploteso adresen dhe numrin e telefonit perpara se ta konfirmosh.";
    ui.type = "error";
    return;
  }

  addressConfirmed.value = true;
  confirmedAddressSignature.value = currentAddressSignature();
  shippingConfirmed.value = false;
  confirmedDeliveryMethod.value = "";
  selectedMethod.value = "";
  persistCheckoutPaymentMethod("");
  ui.message = "Adresa u konfirmua. Tani zgjidh menyren e transportit.";
  ui.type = "success";
}

function confirmShippingStep() {
  if (!addressConfirmed.value) {
    ui.message = "Konfirmo adresen fillimisht.";
    ui.type = "error";
    return;
  }

  if (!selectedDeliveryMethod.value) {
    ui.message = "Zgjidh menyren e transportit perpara se ta konfirmosh.";
    ui.type = "error";
    return;
  }

  shippingConfirmed.value = true;
  confirmedDeliveryMethod.value = selectedDeliveryMethod.value;
  syncPaymentMethodAvailability();
  ui.message = "Menyra e transportit u konfirmua. Tani zgjidh pagesen.";
  ui.type = "success";
}

async function continueToPayment() {
  ui.message = "";
  ui.type = "";

  persistCheckoutAddressDraft(formState);

  if (!saveForLater.value) {
    await handleCheckoutAction();
    return;
  }

  const { response, data } = await requestJson("/api/address", {
    method: "POST",
    body: JSON.stringify(formState),
  });

  if (!response.ok || !data?.ok || !data.address) {
    ui.message = resolveApiMessage(data, "Ruajtja e adreses nuk funksionoi.");
    ui.type = "error";
    return;
  }

  savedAddress.value = normalizeAddress(data.address);
  persistCheckoutAddressDraft(savedAddress.value);
  await handleCheckoutAction();
}

async function reserveCheckoutStock() {
  const selectedIds = checkoutSelectedIds.value.length > 0
    ? checkoutSelectedIds.value
    : readCheckoutSelectedCartIds();

  if (selectedIds.length === 0) {
    return;
  }

  const { response, data } = await requestJson("/api/checkout/reserve", {
    method: "POST",
    body: JSON.stringify({ cartItemIds: selectedIds }),
  });

  if (!response.ok || !data?.ok) {
    ui.message = resolveApiMessage(data, "Stoku nuk u rezervua.");
    ui.type = "error";
  }
}

async function submitCashOrder() {
  const payload = {
    cartItemIds: checkoutSelectedIds.value,
    paymentMethod: "cash",
    deliveryMethod: selectedDeliveryMethod.value,
    promoCode: promoCode.value,
    ...formState,
  };

  submitting.value = true;
  try {
    await reserveCheckoutStock();
    const { response, data } = await requestJson("/api/orders/create", {
      method: "POST",
      body: JSON.stringify(payload),
    });

    if (!response.ok || !data?.ok) {
      ui.message = resolveApiMessage(data, "Porosia nuk u konfirmua.");
      ui.type = "error";
      return;
    }

    persistCheckoutPaymentMethod("cash");
    bumpCatalogRevision();
    const notificationWarnings = Array.isArray(data.notificationWarnings)
      ? data.notificationWarnings.filter(Boolean)
      : [];
    const confirmationMessage = notificationWarnings.length > 0
      ? `${data.message || "Porosia u dergua per konfirmim."} ${notificationWarnings.join(" ")}`
      : (data.message || "Porosia u dergua per konfirmim.");
    persistOrderConfirmationMessage(confirmationMessage);
    clearCheckoutFlowState();
    router.push("/porosite");
  } finally {
    submitting.value = false;
  }
}

async function startStripeCheckout() {
  const payload = {
    cartItemIds: checkoutSelectedIds.value,
    paymentMethod: "card-online",
    deliveryMethod: selectedDeliveryMethod.value,
    promoCode: promoCode.value,
    ...formState,
  };

  submitting.value = true;
  try {
    await reserveCheckoutStock();
    const { response, data } = await requestJson("/api/payments/stripe/checkout", {
      method: "POST",
      body: JSON.stringify(payload),
    });

    if (!response.ok || !data?.ok || !data.checkoutUrl) {
      ui.message = resolveApiMessage(data, "Pagesa online nuk u hap.");
      ui.type = "error";
      return;
    }

    persistCheckoutPaymentMethod("card-online");
    window.location.href = String(data.checkoutUrl).trim();
  } finally {
    submitting.value = false;
  }
}

async function handleCheckoutAction() {
  if (!canSubmitCheckout.value) {
    ui.message = "Ploteso adresen, zgjidh transportin dhe menyrën e pageses.";
    ui.type = "error";
    return;
  }

  if (selectedMethod.value === "card-online") {
    await startStripeCheckout();
    return;
  }

  await submitCashOrder();
}

function backToCart() {
  persistCheckoutAddressDraft(formState);
  router.push("/cart");
}

function applyResolvedLocation(address) {
  const nextAddress = normalizeAddress(address);
  invalidateCheckoutSteps({ preserveMessage: true });
  Object.assign(formState, {
    ...nextAddress,
    country: nextAddress.country || formState.country || "Kosove",
    phoneNumber: formState.phoneNumber || "",
  });
  persistCheckoutAddressDraft(formState);
  ui.locationMessage = "Lokacioni u plotesua. Kontrolloje dhe konfirmoje adresen para se te vazhdosh.";
  ui.locationType = "success";
  void loadCheckoutPreview({ silent: true });
}

async function useDeviceLocation() {
  ui.locationMessage = "";
  ui.locationType = "";

  if (!navigator.geolocation) {
    ui.locationMessage = "Browser-i yt nuk e mbeshtet lokacionin automatik. Plotëso adresën manualisht.";
    ui.locationType = "info";
    return;
  }

  ui.locationBusy = true;
  ui.locationMessage = "Po kerkohet leja e lokacionit nga telefoni...";
  ui.locationType = "info";

  try {
    const position = await new Promise((resolve, reject) => {
      navigator.geolocation.getCurrentPosition(resolve, reject, {
        enableHighAccuracy: true,
        timeout: 12000,
        maximumAge: 30000,
      });
    });

    const { response, data } = await requestJson("/api/address/geocode", {
      method: "POST",
      body: JSON.stringify({
        latitude: position.coords.latitude,
        longitude: position.coords.longitude,
      }),
    });

    if (!response.ok || !data?.ok || !data.address) {
      ui.locationMessage = resolveApiMessage(data, "Lokacioni nuk u identifikua automatikisht. Plotëso adresën manualisht.");
      ui.locationType = "info";
      return;
    }

    applyResolvedLocation(data.address);
  } catch (error) {
    const errorCode = Number(error?.code || 0);
    if (errorCode === 1) {
      ui.locationMessage = "Leja per lokacion u refuzua. Plotëso adresën manualisht.";
      ui.locationType = "info";
      return;
    }

    ui.locationMessage = "Lokacioni nuk u mor. Plotëso adresën manualisht.";
    ui.locationType = "info";
  } finally {
    ui.locationBusy = false;
  }
}
</script>

<template>
  <section class="account-page checkout-address-page checkout-address-page--reference" aria-label="Adresa e porosise">
    <header class="account-header profile-page-header checkout-address-header">
      <div>
        <p class="section-label">Porosia</p>
        <h1>Te dhenat e kontaktit</h1>
        <p class="section-text">Ec hap pas hapi: konfirmo adresen, pastaj transportin, dhe ne fund menyren e pageses.</p>
      </div>
    </header>

    <div class="form-message" :class="ui.type" role="status" aria-live="polite">
      {{ ui.message }}
    </div>

    <div class="checkout-address-layout">
      <form class="checkout-address-main" @submit.prevent="continueToPayment">
        <div v-if="savedAddress" class="checkout-saved-address-banner">
          <div>
            <strong>Ke nje adrese te ruajtur.</strong>
            <span>Perdore per ta mbushur formen me nje klik.</span>
          </div>
          <button class="checkout-inline-button" type="button" @click="applySavedAddress">
            Përdor adresen e ruajtur
          </button>
        </div>

        <section class="checkout-block">
          <div class="checkout-block-head">
            <h2>Te dhenat e kontaktit</h2>
          </div>

          <label class="field checkout-field-full">
            <span>Emri dhe mbiemri</span>
            <input v-model="contactState.fullName" type="text" placeholder="Emri dhe mbiemri" autocomplete="name">
          </label>

          <div class="checkout-two-column">
            <label class="field">
              <span>Email adresa</span>
              <input v-model="contactState.email" type="email" placeholder="name@example.com" autocomplete="email">
            </label>

            <label class="field">
              <span>Numri i telefonit</span>
              <input
                v-model="formState.phoneNumber"
                type="tel"
                placeholder="+383 44 123 456"
                autocomplete="tel"
                required
                @blur="handleAddressContextBlur"
              >
            </label>
          </div>

          <label class="checkout-checkbox">
            <input v-model="contactState.receiveOffers" type="checkbox">
            <span>Me dergo ofertat javore</span>
          </label>
        </section>

        <section class="checkout-block">
          <div class="checkout-block-head">
            <h2>Adresa e transportit</h2>
          </div>

          <div class="checkout-two-column">
            <label class="field">
              <span>Shteti</span>
              <select v-model="formState.country" @change="handleAddressContextBlur">
                <option
                  v-for="country in COUNTRY_OPTIONS"
                  :key="country"
                  :value="country"
                >
                  {{ country }}
                </option>
              </select>
            </label>

            <label class="field">
              <span>Qyteti</span>
              <input
                v-model="formState.city"
                type="text"
                placeholder="Shkruaje qytetin"
                required
                @blur="handleAddressContextBlur"
              >
            </label>
          </div>

          <label class="field checkout-field-full">
            <span>Adresa</span>
            <input
              v-model="formState.addressLine"
              type="text"
              placeholder="Rruga, hyrja, apartamenti"
              required
              @blur="handleAddressContextBlur"
            >
          </label>

          <div class="checkout-two-column checkout-two-column--compact">
            <label class="field">
              <span>Kodi postar</span>
              <input
                v-model="formState.zipCode"
                type="text"
                placeholder="Shkruaje kodin postar"
                required
                @blur="handleAddressContextBlur"
              >
            </label>

            <div class="checkout-location-inline">
              <span class="checkout-inline-label">Mbushje e shpejte</span>
              <button
                class="ghost-button checkout-location-button"
                type="button"
                :disabled="ui.locationBusy"
                @click="useDeviceLocation"
              >
                {{ ui.locationBusy ? "Po merret lokacioni..." : "Perdor lokacionin tim" }}
              </button>
            </div>
          </div>

          <label class="field checkout-field-full">
            <span>Koment shtese</span>
            <textarea
              v-model="contactState.comment"
              rows="4"
              placeholder="Koment per porosine"
            ></textarea>
          </label>

          <div v-if="ui.locationMessage" class="form-message" :class="ui.locationType" role="status" aria-live="polite">
            {{ ui.locationMessage }}
          </div>

          <label class="checkout-checkbox">
            <input v-model="saveForLater" type="checkbox">
            <span>Ruaje kete adrese per heren tjeter</span>
          </label>

          <div class="checkout-step-actions">
            <p class="checkout-step-note">
              {{
                addressConfirmed
                  ? "Adresa u konfirmua. Mund te vazhdosh te menyra e transportit."
                  : "Kur adresa te jete gati, konfirmoje qe te hapet hapi tjeter."
              }}
            </p>
            <button
              class="checkout-confirm-button"
              type="button"
              :disabled="!addressReady"
              @click="confirmAddressStep"
            >
              {{ addressConfirmed ? "Adresa u konfirmua" : "Konfirmo adresen" }}
            </button>
          </div>
        </section>

        <section v-if="showShippingOptions" class="checkout-block">
          <div class="checkout-block-head">
            <h2>Menyra e transportit</h2>
          </div>

          <div class="checkout-methods-grid">
            <button
              v-for="option in deliveryOptions"
              :key="option.value"
              class="checkout-method-card"
              :class="{ active: selectedDeliveryMethod === option.value }"
              type="button"
              @click="handleDeliverySelection(option.value)"
            >
              <div class="checkout-method-copy">
                <strong>{{ option.label }}</strong>
                <span>{{ option.description || option.estimatedDeliveryText }}</span>
              </div>
              <div class="checkout-method-meta">
                <span>{{ option.estimatedDeliveryText }}</span>
                <span class="checkout-method-radio" aria-hidden="true"></span>
              </div>
            </button>
          </div>

          <div class="checkout-step-actions">
            <p class="checkout-step-note">
              {{
                shippingConfirmed
                  ? "Transporti u konfirmua. Tani mund te zgjedhesh menyren e pageses."
                  : "Zgjidh nje menyre transporti dhe konfirmoje qe te hapet pagesa."
              }}
            </p>
            <button
              class="checkout-confirm-button"
              type="button"
              :disabled="!selectedDeliveryMethod"
              @click="confirmShippingStep"
            >
              {{ shippingConfirmed ? "Transporti u konfirmua" : "Konfirmo menyren e transportit" }}
            </button>
          </div>
        </section>

        <section v-if="showPaymentOptions" class="checkout-block">
          <div class="checkout-block-head">
            <h2>Menyra e pageses</h2>
          </div>

          <div class="checkout-methods-grid checkout-methods-grid--payments">
            <button
              v-for="option in availablePaymentMethods"
              :key="option.value"
              class="checkout-method-card checkout-method-card--payment"
              :class="{ active: selectedMethod === option.value }"
              type="button"
              @click="handlePaymentSelection(option.value)"
            >
              <div class="checkout-method-copy">
                <strong>{{ option.title }}</strong>
                <span>{{ option.copy }}</span>
              </div>
              <div class="checkout-method-meta">
                <span>{{ option.status }}</span>
                <span class="checkout-method-radio" aria-hidden="true"></span>
              </div>
            </button>
          </div>
        </section>

        <div class="checkout-actions">
          <button class="checkout-back-button" type="button" @click="backToCart">
            Kthehu te shporta
          </button>
          <button class="checkout-next-button" type="submit" :disabled="!canSubmitCheckout">
            {{ submitting ? "Duke vazhduar..." : primaryCheckoutLabel }}
          </button>
        </div>
      </form>

      <aside class="checkout-address-sidebar">
        <div class="checkout-sidebar-items">
          <article
            v-for="item in summaryItems"
            :key="item.id"
            class="checkout-sidebar-item"
          >
            <div class="checkout-sidebar-item-media">
              <img
                :src="item.imagePath"
                :alt="item.title"
                width="120"
                height="120"
                loading="lazy"
                decoding="async"
              >
            </div>
            <div class="checkout-sidebar-item-copy">
              <strong>{{ item.title }}</strong>
              <span v-if="item.size">Madhesia: {{ item.size }}</span>
              <span v-if="item.color">Ngjyra: {{ item.color }}</span>
              <span>Sasia: {{ item.quantity }}</span>
            </div>
            <strong class="checkout-sidebar-item-price">
              {{ formatPrice((Number(item.price) || 0) * Math.max(1, Number(item.quantity) || 1)) }}
            </strong>
          </article>
        </div>

        <form class="checkout-sidebar-coupon" @submit.prevent="applyPromotion">
          <input
            v-model="promoCode"
            class="checkout-sidebar-coupon-input"
            type="text"
            placeholder="Kupon"
            autocomplete="off"
          >
          <button class="checkout-sidebar-coupon-button" type="submit">Apliko</button>
        </form>

        <div class="checkout-sidebar-totals">
          <div class="checkout-sidebar-line">
            <span>Nentotali:</span>
            <strong>{{ formatPrice(subtotalAmount) }}</strong>
          </div>
          <div class="checkout-sidebar-line">
            <span>Zbritja:</span>
            <strong>{{ formatPrice(discountAmount) }}</strong>
          </div>
          <div class="checkout-sidebar-line">
            <span>Kostoja e transportit:</span>
            <strong>{{ formatPrice(shippingAmount) }}</strong>
          </div>
          <div class="checkout-sidebar-total">
            <span>Totali:</span>
            <strong>{{ formatPrice(totalAmount) }}</strong>
          </div>
          <div v-if="totalItemsCount > 0" class="checkout-sidebar-count">
            {{ totalItemsCount }} artikuj te zgjedhur
          </div>
        </div>
      </aside>
    </div>
  </section>
</template>

<style scoped>
.checkout-address-page--reference {
  width: min(100%, 1180px);
  display: grid;
  gap: 18px;
}

.checkout-address-header h1 {
  margin: 0;
  color: #101828;
}

.checkout-address-layout {
  display: grid;
  grid-template-columns: minmax(0, 1fr) 320px;
  gap: 24px;
  align-items: start;
}

.checkout-address-main,
.checkout-address-sidebar {
  border-radius: 16px;
  border: 1px solid #e5e7eb;
  background: rgba(255, 255, 255, 0.96);
  box-shadow: 0 18px 34px rgba(15, 23, 42, 0.04);
}

.checkout-address-main {
  display: grid;
  gap: 0;
  padding: 22px 22px 18px;
}

.checkout-saved-address-banner {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 14px;
  padding: 0 0 18px;
  border-bottom: 1px solid #edf2f7;
}

.checkout-saved-address-banner strong,
.checkout-block-head h2 {
  color: #111827;
}

.checkout-saved-address-banner span {
  display: block;
  margin-top: 4px;
  color: #64748b;
  font-size: 0.9rem;
}

.checkout-inline-button {
  min-height: 40px;
  padding: 0 14px;
  border-radius: 10px;
  border: 1px solid #dbe2ea;
  background: #fff;
  color: #111827;
  font-weight: 700;
  cursor: pointer;
}

.checkout-block {
  display: grid;
  gap: 16px;
  padding: 22px 0;
  border-bottom: 1px solid #edf2f7;
}

.checkout-block:last-of-type {
  border-bottom: 0;
}

.checkout-block-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

.checkout-block-head h2 {
  margin: 0;
  font-size: 1.3rem;
}

.checkout-two-column {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 16px;
}

.checkout-two-column--compact {
  align-items: end;
}

.checkout-field-full {
  grid-column: 1 / -1;
}

.checkout-address-main .field {
  display: grid;
  gap: 8px;
}

.checkout-address-main .field span,
.checkout-inline-label {
  color: #111827;
  font-size: 0.9rem;
  font-weight: 700;
}

.checkout-address-main input,
.checkout-address-main select,
.checkout-address-main textarea {
  width: 100%;
  min-height: 48px;
  padding: 0 14px;
  border-radius: 10px;
  border: 1px solid #dbe2ea;
  background: #fff;
  color: #111827;
  font: inherit;
  outline: none;
}

.checkout-address-main textarea {
  min-height: 116px;
  padding: 14px;
  resize: vertical;
}

.checkout-address-main input:focus,
.checkout-address-main select:focus,
.checkout-address-main textarea:focus {
  border-color: rgba(50, 80, 242, 0.4);
  box-shadow: 0 0 0 4px rgba(50, 80, 242, 0.08);
}

.checkout-checkbox {
  display: inline-flex;
  align-items: center;
  gap: 10px;
  color: #475569;
  font-size: 0.92rem;
  font-weight: 600;
}

.checkout-checkbox input {
  width: 16px;
  height: 16px;
  min-height: 16px;
  padding: 0;
  accent-color: #3250f2;
}

.checkout-location-inline {
  display: grid;
  gap: 8px;
}

.checkout-location-button {
  width: fit-content;
  min-height: 42px;
  padding: 0 14px;
}

.checkout-methods-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 12px;
}

.checkout-methods-grid--payments {
  grid-template-columns: repeat(2, minmax(0, 1fr));
}

.checkout-method-card {
  display: grid;
  gap: 10px;
  min-height: 96px;
  padding: 16px;
  border-radius: 12px;
  border: 1px solid #e2e8f0;
  background: #fff;
  color: #111827;
  text-align: left;
  cursor: pointer;
  transition: border-color 0.18s ease, box-shadow 0.18s ease, transform 0.18s ease;
}

.checkout-method-card:hover {
  transform: translateY(-1px);
}

.checkout-method-card.active {
  border-color: rgba(50, 80, 242, 0.45);
  box-shadow: 0 0 0 3px rgba(50, 80, 242, 0.08);
}

.checkout-method-copy {
  display: grid;
  gap: 6px;
}

.checkout-method-copy strong {
  font-size: 0.96rem;
}

.checkout-method-copy span,
.checkout-method-meta span {
  color: #64748b;
  font-size: 0.82rem;
  line-height: 1.45;
}

.checkout-method-meta {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
}

.checkout-method-radio {
  width: 18px;
  height: 18px;
  border-radius: 999px;
  border: 2px solid #cbd5e1;
  position: relative;
}

.checkout-method-card.active .checkout-method-radio {
  border-color: #3250f2;
}

.checkout-method-card.active .checkout-method-radio::after {
  content: "";
  position: absolute;
  inset: 3px;
  border-radius: 999px;
  background: #3250f2;
}

.checkout-step-hint {
  margin: 0;
  color: #64748b;
  font-size: 0.92rem;
  line-height: 1.6;
}

.checkout-step-actions {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 14px;
  flex-wrap: wrap;
}

.checkout-step-note {
  margin: 0;
  color: #64748b;
  font-size: 0.92rem;
  line-height: 1.6;
}

.checkout-confirm-button {
  min-height: 44px;
  padding: 0 18px;
  border: 1px solid rgba(50, 80, 242, 0.14);
  border-radius: 12px;
  background: rgba(50, 80, 242, 0.08);
  color: #2340da;
  font-weight: 800;
  cursor: pointer;
  transition: transform 0.18s ease, box-shadow 0.18s ease, opacity 0.18s ease;
}

.checkout-confirm-button:hover:not(:disabled) {
  transform: translateY(-1px);
  box-shadow: 0 12px 24px rgba(50, 80, 242, 0.12);
}

.checkout-confirm-button:disabled {
  opacity: 0.48;
  cursor: not-allowed;
  box-shadow: none;
}

.checkout-actions {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 14px;
  padding-top: 18px;
}

.checkout-back-button,
.checkout-next-button {
  min-height: 46px;
  padding: 0 18px;
  border-radius: 10px;
  font-weight: 700;
  cursor: pointer;
}

.checkout-back-button {
  border: 1px solid #dbe2ea;
  background: #fff;
  color: #334155;
}

.checkout-next-button {
  border: 0;
  background: linear-gradient(180deg, #4f5fff, #3250f2);
  color: #fff;
  box-shadow: 0 16px 28px rgba(50, 80, 242, 0.18);
}

.checkout-next-button:disabled {
  opacity: 0.55;
  cursor: not-allowed;
  box-shadow: none;
}

.checkout-address-sidebar {
  position: sticky;
  top: calc(var(--page-nav-clearance) - 20px);
  display: grid;
  gap: 16px;
  padding: 16px;
}

.checkout-sidebar-items {
  display: grid;
  gap: 12px;
}

.checkout-sidebar-item {
  display: grid;
  grid-template-columns: 56px minmax(0, 1fr) auto;
  gap: 12px;
  align-items: start;
}

.checkout-sidebar-item-media {
  display: grid;
  place-items: center;
  width: 56px;
  height: 56px;
  border-radius: 10px;
  background: #f8fafc;
  border: 1px solid #e2e8f0;
}

.checkout-sidebar-item-media img {
  width: 42px;
  height: 42px;
  object-fit: contain;
}

.checkout-sidebar-item-copy {
  display: grid;
  gap: 2px;
}

.checkout-sidebar-item-copy strong {
  color: #111827;
  font-size: 0.84rem;
  line-height: 1.35;
}

.checkout-sidebar-item-copy span,
.checkout-sidebar-item-price {
  color: #64748b;
  font-size: 0.78rem;
  line-height: 1.4;
}

.checkout-sidebar-item-price {
  color: #111827;
  font-weight: 700;
}

.checkout-sidebar-coupon {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto;
  gap: 8px;
  padding-top: 8px;
  border-top: 1px solid #edf2f7;
}

.checkout-sidebar-coupon-input,
.checkout-sidebar-coupon-button {
  min-height: 40px;
  border-radius: 8px;
}

.checkout-sidebar-coupon-input {
  padding: 0 12px;
  border: 1px solid #dbe2ea;
  background: #fff;
  color: #111827;
  font: inherit;
  outline: none;
}

.checkout-sidebar-coupon-button {
  padding: 0 14px;
  border: 1px solid #dbe2ea;
  background: #fff;
  color: #111827;
  font-weight: 700;
  cursor: pointer;
}

.checkout-sidebar-totals {
  display: grid;
  gap: 10px;
}

.checkout-sidebar-line,
.checkout-sidebar-total {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

.checkout-sidebar-line {
  color: #64748b;
  font-size: 0.9rem;
}

.checkout-sidebar-line strong {
  color: #111827;
}

.checkout-sidebar-total {
  padding-top: 10px;
  border-top: 1px solid #edf2f7;
  color: #111827;
  font-size: 1rem;
  font-weight: 800;
}

.checkout-sidebar-total strong {
  font-size: 1.5rem;
  line-height: 1;
}

.checkout-sidebar-count {
  color: #64748b;
  font-size: 0.8rem;
}

@media (max-width: 1100px) {
  .checkout-address-layout {
    grid-template-columns: 1fr;
  }

  .checkout-address-sidebar {
    position: static;
  }
}

@media (max-width: 760px) {
  .checkout-address-main {
    padding: 18px 16px 16px;
  }

  .checkout-saved-address-banner,
  .checkout-actions,
  .checkout-step-actions {
    flex-direction: column;
    align-items: stretch;
  }

  .checkout-two-column,
  .checkout-methods-grid {
    grid-template-columns: 1fr;
  }

  .checkout-back-button,
  .checkout-next-button {
    width: 100%;
  }

  .checkout-sidebar-item {
    grid-template-columns: 48px minmax(0, 1fr);
  }

  .checkout-sidebar-item-price {
    grid-column: 2;
    justify-self: end;
  }
}
</style>
