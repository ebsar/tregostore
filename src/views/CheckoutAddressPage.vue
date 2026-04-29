<script setup>
import { computed, onMounted, reactive, ref } from "vue";
import { RouterLink, useRouter } from "vue-router";
import { requestJson, resolveApiMessage } from "../lib/api";
import {
  DELIVERY_METHOD_OPTIONS,
  clearCheckoutFlowState,
  createEmptyAddress,
  formatPrice,
  normalizeAddress,
  persistCheckoutAddressDraft,
  persistCheckoutDeliveryMethod,
  persistCheckoutGuestContact,
  persistCheckoutGuestMode,
  persistCheckoutPaymentMethod,
  persistOrderSuccessSnapshot,
  readCheckoutAddressDraft,
  readCheckoutDeliveryMethod,
  readCheckoutGuestContact,
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
const editingAddress = ref(true);
const editingDelivery = ref(false);
const editingPayment = ref(false);
const addressConfirmed = ref(false);
const shippingConfirmed = ref(false);
const confirmedAddressSignature = ref("");
const confirmedDeliveryMethod = ref("");
const customerName = ref("");
const customerEmail = ref("");
const isGuestCheckout = ref(false);
const formState = reactive(createEmptyAddress());
const ui = reactive({
  message: "",
  type: "",
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
const guestContactReady = computed(() => {
  if (!isGuestCheckout.value) {
    return true;
  }

  const nameReady = String(customerName.value || "").trim().length >= 2;
  const emailReady = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(String(customerEmail.value || "").trim());
  return nameReady && emailReady;
});
const addressReady = computed(() =>
  Boolean(
    guestContactReady.value
    && String(formState.addressLine || "").trim()
    && String(formState.city || "").trim()
    && String(formState.country || "").trim()
    && String(formState.zipCode || "").trim()
    && String(formState.phoneNumber || "").trim(),
  ),
);
const availablePaymentMethods = computed(() => {
  if (isGuestCheckout.value) {
    return [
      {
        value: "cash",
        title: "Cash on delivery",
        copy: "Pay when the order reaches you. Create an account later if you want saved order history.",
        status: "Guest",
      },
    ];
  }

  if (selectedDeliveryMethod.value === "pickup") {
    return [
      {
        value: "card-online",
        title: "Card payment",
        copy: "Pickup orders can be completed only with online payment.",
        status: "Online",
      },
    ];
  }

  return [
    {
      value: "cash",
      title: "Cash on delivery",
      copy: "Pay when the order reaches you.",
      status: "Pay on arrival",
    },
    {
      value: "card-online",
      title: "Card payment",
      copy: "Continue with Stripe to complete the order online.",
      status: "Online",
    },
  ];
});
const canSubmitCheckout = computed(() =>
  addressConfirmed.value
  && shippingConfirmed.value
  && Boolean(selectedMethod.value)
  && !submitting.value,
);
const selectedDeliveryOption = computed(() =>
  deliveryOptions.value.find(
    (option) => String(option.value || "").trim().toLowerCase() === selectedDeliveryMethod.value,
  ) || null,
);
const selectedPaymentOption = computed(() =>
  availablePaymentMethods.value.find(
    (option) => String(option.value || "").trim().toLowerCase() === selectedMethod.value,
  ) || null,
);
const checkoutCustomerName = computed(() =>
  String(customerName.value || "").trim() || "Delivery contact",
);
const addressSummaryText = computed(() => {
  const pieces = [
    String(formState.addressLine || "").trim(),
    [String(formState.zipCode || "").trim(), String(formState.city || "").trim()].filter(Boolean).join(" "),
    String(formState.country || "").trim(),
  ].filter(Boolean);

  if (pieces.length === 0) {
    return "Add your delivery address to continue.";
  }

  return pieces.join(", ");
});
const deliverySummaryTitle = computed(() =>
  selectedDeliveryOption.value?.label || "Choose delivery option",
);
const deliverySummaryText = computed(() => {
  const pieces = [
    String(selectedDeliveryOption.value?.estimatedDeliveryText || "").trim(),
    shippingConfirmed.value
      ? (shippingAmount.value > 0 ? formatPrice(shippingAmount.value) : "Free delivery")
      : "Select and confirm delivery",
  ].filter(Boolean);

  return pieces.join(" • ");
});
const paymentSummaryTitle = computed(() =>
  selectedPaymentOption.value?.title || "Choose payment method",
);
const paymentSummaryText = computed(() =>
  String(selectedPaymentOption.value?.copy || "").trim() || "Select how you want to complete the order.",
);
const primarySubmitLabel = computed(() => {
  if (submitting.value) {
    return "Processing...";
  }

  if (selectedMethod.value === "card-online") {
    return "Continue to payment";
  }

  return "Place order";
});

function filterDeliveryOptionsForCheckout(options) {
  const sourceOptions = Array.isArray(options) && options.length > 0
    ? options
    : DELIVERY_METHOD_OPTIONS;
  if (!isGuestCheckout.value) {
    return sourceOptions;
  }

  return sourceOptions.filter((option) => String(option.value || "").trim().toLowerCase() !== "pickup");
}

function syncPaymentMethodAvailability() {
  if (
    isGuestCheckout.value
    && selectedDeliveryMethod.value === "pickup"
  ) {
    selectedDeliveryMethod.value = "";
    persistCheckoutDeliveryMethod("");
  }

  if (selectedDeliveryMethod.value === "pickup" && selectedMethod.value === "cash") {
    selectedMethod.value = "";
    persistCheckoutPaymentMethod("");
  }

  if (
    isGuestCheckout.value
    && selectedMethod.value
    && !availablePaymentMethods.value.some((option) => option.value === selectedMethod.value)
  ) {
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
    customerName: isGuestCheckout.value ? String(customerName.value || "").trim().toLowerCase() : "",
    customerEmail: isGuestCheckout.value ? String(customerEmail.value || "").trim().toLowerCase() : "",
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
  editingAddress.value = true;
  editingDelivery.value = false;
  editingPayment.value = false;

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
    isGuestCheckout.value = !user;
    if (!user) {
      persistCheckoutGuestMode(true);
    } else {
      persistCheckoutGuestMode(false);
    }

    checkoutSelectedIds.value = readCheckoutSelectedCartIds();
    if (checkoutSelectedIds.value.length === 0) {
      router.replace("/cart");
      return;
    }

    if (user) {
      customerName.value = String(
        user.fullName || [user.firstName, user.lastName].filter(Boolean).join(" "),
      ).trim();
    } else {
      const guestContact = readCheckoutGuestContact();
      customerName.value = guestContact.customerName;
      customerEmail.value = guestContact.customerEmail;
    }
    deliveryOptions.value = filterDeliveryOptionsForCheckout(DELIVERY_METHOD_OPTIONS);
    syncPaymentMethodAvailability();

    await loadSavedAddress({ skipRemote: isGuestCheckout.value });
    await loadCheckoutPreview({ silent: true });
  } finally {
    markRouteReady();
  }
});

async function loadSavedAddress({ skipRemote = false } = {}) {
  const draftAddress = readCheckoutAddressDraft();
  const fallbackAddress = draftAddress || createEmptyAddress();
  Object.assign(formState, fallbackAddress);
  if (!formState.country) {
    formState.country = "Kosove";
  }

  if (skipRemote) {
    savedAddress.value = null;
    return;
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
  const rawOptions = Array.isArray(pricingPayload?.availableDeliveryMethods)
    && pricingPayload.availableDeliveryMethods.length > 0
    ? pricingPayload.availableDeliveryMethods
    : DELIVERY_METHOD_OPTIONS;
  const nextOptions = filterDeliveryOptionsForCheckout(rawOptions);

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

async function loadCheckoutPreview({ silent = false } = {}) {
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

  if (!silent) {
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
  ui.message = "Adresa e ruajtur u vendos. Tani kliko save address.";
  ui.type = "success";
  void loadCheckoutPreview({ silent: true });
}

function handleDeliverySelection(method) {
  const nextMethod = String(method || "").trim().toLowerCase() || "standard";
  if (selectedDeliveryMethod.value !== nextMethod) {
    shippingConfirmed.value = false;
    confirmedDeliveryMethod.value = "";
    selectedMethod.value = "";
    persistCheckoutPaymentMethod("");
    editingPayment.value = false;
  }
  selectedDeliveryMethod.value = nextMethod;
  persistCheckoutDeliveryMethod(nextMethod);
  syncPaymentMethodAvailability();
  editingDelivery.value = true;
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

  if (isGuestCheckout.value && nextMethod !== "cash") {
    return;
  }

  selectedMethod.value = nextMethod;
  persistCheckoutPaymentMethod(nextMethod);
  editingPayment.value = false;
}

function handleAddressContextBlur() {
  persistCheckoutAddressDraft(formState);
  invalidateAddressConfirmationIfNeeded();
  void loadCheckoutPreview({ silent: true });
}

function persistGuestContactDraft() {
  if (!isGuestCheckout.value) {
    return;
  }

  persistCheckoutGuestContact({
    customerName: customerName.value,
    customerEmail: customerEmail.value,
  });
  invalidateAddressConfirmationIfNeeded();
}

function confirmAddressStep() {
  if (!guestContactReady.value) {
    ui.message = "Shkruaj emrin dhe email-in per te vazhduar si guest.";
    ui.type = "error";
    return;
  }

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
  editingAddress.value = false;
  editingDelivery.value = true;
  editingPayment.value = false;
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
  editingDelivery.value = false;
  editingPayment.value = true;
}

async function continueToPayment() {
  ui.message = "";
  ui.type = "";

  persistCheckoutAddressDraft(formState);
  if (isGuestCheckout.value) {
    persistCheckoutGuestContact({
      customerName: customerName.value,
      customerEmail: customerEmail.value,
    });
    await handleCheckoutAction();
    return;
  }

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
    customerName: customerName.value,
    customerEmail: customerEmail.value,
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
  const payload = {
    cartItemIds: checkoutSelectedIds.value,
    paymentMethod: "card-online",
    deliveryMethod: selectedDeliveryMethod.value,
    promoCode: promoCode.value,
    customerName: customerName.value,
    customerEmail: customerEmail.value,
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

  if (isGuestCheckout.value && selectedMethod.value !== "cash") {
    ui.message = "Guest checkout mund te vazhdoje me pagese ne dore.";
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
</script>

<template>
  <section class="checkout-review" aria-label="Checkout">
    <div class="checkout-review__container">
      <header class="checkout-review__top">
        <nav class="checkout-review__steps" aria-label="Checkout steps">
          <div class="checkout-review__step checkout-review__step--completed">
            <span class="checkout-review__step-circle" aria-hidden="true">
              <svg viewBox="0 0 20 20">
                <path d="m5.2 10.2 3.1 3.1 6.5-6.5"></path>
              </svg>
            </span>
            <span class="checkout-review__step-label">Order</span>
          </div>
          <span class="checkout-review__step-line" aria-hidden="true"></span>
          <div class="checkout-review__step checkout-review__step--active">
            <span class="checkout-review__step-circle">2</span>
            <span class="checkout-review__step-label">Checkout</span>
          </div>
          <span class="checkout-review__step-line" aria-hidden="true"></span>
          <div class="checkout-review__step">
            <span class="checkout-review__step-circle">3</span>
            <span class="checkout-review__step-label">Payment</span>
          </div>
          <span class="checkout-review__step-line" aria-hidden="true"></span>
          <div class="checkout-review__step">
            <span class="checkout-review__step-circle">4</span>
            <span class="checkout-review__step-label">Review</span>
          </div>
        </nav>
      </header>

      <div
        v-if="ui.message"
        class="checkout-review__notice"
        :class="{
          'checkout-review__notice--error': ui.type === 'error',
          'checkout-review__notice--success': ui.type === 'success',
        }"
        role="status"
        aria-live="polite"
      >
        {{ ui.message }}
      </div>

      <div v-if="isGuestCheckout" class="checkout-review__notice checkout-review__notice--guest">
        Guest checkout: vendos email-in qe te marresh konfirmimin e porosise. Llogaria nuk eshte e detyrueshme.
      </div>

      <form class="checkout-review__layout" @submit.prevent="continueToPayment">
        <main class="checkout-review__main">
          <section class="checkout-review__section">
            <div class="checkout-review__section-head">
              <h1>Order details</h1>
            </div>

            <div v-if="summaryItems.length > 0" class="checkout-review__items">
              <article v-for="item in summaryItems" :key="item.id" class="checkout-review__item-row">
                <div class="checkout-review__item-image-wrap">
                  <img
                    :src="item.imagePath"
                    :alt="item.title"
                    width="96"
                    height="96"
                    loading="lazy"
                    decoding="async"
                  >
                </div>
                <div class="checkout-review__item-copy">
                  <strong>{{ item.title }}</strong>
                  <span v-if="item.businessName">{{ item.businessName }}</span>
                  <span v-if="item.size || item.color">
                    {{ [item.size ? `Size ${item.size}` : "", item.color ? `Color ${item.color}` : ""].filter(Boolean).join(" • ") }}
                  </span>
                </div>
                <span class="checkout-review__item-qty">{{ Math.max(1, Number(item.quantity) || 1) }} pc</span>
                <strong class="checkout-review__item-price">
                  {{ formatPrice((Number(item.price) || 0) * Math.max(1, Number(item.quantity) || 1)) }}
                </strong>
              </article>
            </div>

            <div v-else class="checkout-review__empty">
              No items are selected for checkout.
            </div>
          </section>

          <section class="checkout-review__section">
            <div class="checkout-review__section-head">
              <h2>Delivery</h2>
              <button
                class="checkout-review__edit"
                type="button"
                @click="
                  editingAddress = true;
                  editingDelivery = addressConfirmed;
                  editingPayment = false;
                "
              >
                Edit
              </button>
            </div>

            <div class="checkout-review__info-grid">
              <article class="checkout-review__info-card">
                <div class="checkout-review__info-icon">
                  <svg viewBox="0 0 24 24" aria-hidden="true">
                    <path d="M12 21s6-5.3 6-10.2A6 6 0 0 0 6 10.8C6 15.7 12 21 12 21Z"></path>
                    <circle cx="12" cy="10.8" r="2.4"></circle>
                  </svg>
                </div>
                <div class="checkout-review__info-copy">
                  <strong>{{ checkoutCustomerName }}</strong>
                  <p>{{ addressSummaryText }}</p>
                </div>
              </article>

              <article class="checkout-review__info-card">
                <div class="checkout-review__info-icon">
                  <svg viewBox="0 0 24 24" aria-hidden="true">
                    <path d="M4.8 7.5h10.6v8.2H4.8z"></path>
                    <path d="M15.4 10.1h2.7l1.1 1.5v4.1h-3.8"></path>
                    <circle cx="8.1" cy="17.1" r="1.4"></circle>
                    <circle cx="16.8" cy="17.1" r="1.4"></circle>
                  </svg>
                </div>
                <div class="checkout-review__info-copy">
                  <strong>{{ deliverySummaryTitle }}</strong>
                  <p>{{ deliverySummaryText }}</p>
                </div>
              </article>
            </div>

            <div v-if="editingAddress || !addressConfirmed" class="checkout-review__editor">
              <div class="checkout-review__editor-head">
                <strong>Address details</strong>
                <button
                  v-if="savedAddress && !isGuestCheckout"
                  class="checkout-review__text-button"
                  type="button"
                  @click="applySavedAddress"
                >
                  Use saved address
                </button>
              </div>

              <div class="checkout-review__form-grid">
                <label class="checkout-review__field">
                  <span>Full name</span>
                  <input
                    v-model="customerName"
                    type="text"
                    placeholder="Your full name"
                    autocomplete="name"
                    @blur="persistGuestContactDraft"
                  >
                </label>

                <label v-if="isGuestCheckout" class="checkout-review__field">
                  <span>Email</span>
                  <input
                    v-model="customerEmail"
                    type="email"
                    placeholder="you@example.com"
                    autocomplete="email"
                    @blur="persistGuestContactDraft"
                  >
                </label>

                <label class="checkout-review__field">
                  <span>Phone number</span>
                  <input
                    v-model="formState.phoneNumber"
                    type="tel"
                    placeholder="+383 44 123 456"
                    autocomplete="tel"
                    @blur="handleAddressContextBlur"
                  >
                </label>

                <label class="checkout-review__field">
                  <span>Country</span>
                  <select v-model="formState.country" @change="handleAddressContextBlur">
                    <option v-for="country in COUNTRY_OPTIONS" :key="country" :value="country">
                      {{ country }}
                    </option>
                  </select>
                </label>

                <label class="checkout-review__field">
                  <span>City</span>
                  <input
                    v-model="formState.city"
                    type="text"
                    placeholder="City"
                    @blur="handleAddressContextBlur"
                  >
                </label>

                <label class="checkout-review__field checkout-review__field--full">
                  <span>Address</span>
                  <input
                    v-model="formState.addressLine"
                    type="text"
                    placeholder="Street, building, apartment"
                    @blur="handleAddressContextBlur"
                  >
                </label>

                <label class="checkout-review__field">
                  <span>ZIP code</span>
                  <input
                    v-model="formState.zipCode"
                    type="text"
                    placeholder="ZIP code"
                    @blur="handleAddressContextBlur"
                  >
                </label>
              </div>

              <div class="checkout-review__editor-actions">
                <label v-if="!isGuestCheckout" class="checkout-review__checkbox">
                  <input v-model="saveForLater" type="checkbox">
                  <span>Save this address for next time</span>
                </label>

                <button
                  class="checkout-review__secondary"
                  type="button"
                  :disabled="!addressReady"
                  @click="confirmAddressStep"
                >
                  {{ addressConfirmed ? "Address saved" : "Save address" }}
                </button>
              </div>
            </div>

            <div v-if="addressConfirmed && (editingDelivery || !shippingConfirmed)" class="checkout-review__editor">
              <div class="checkout-review__editor-head">
                <strong>Delivery option</strong>
              </div>

              <div class="checkout-review__choice-grid">
                <button
                  v-for="option in deliveryOptions"
                  :key="option.value"
                  class="checkout-review__choice-card"
                  type="button"
                  :class="{ 'checkout-review__choice-card--active': selectedDeliveryMethod === option.value }"
                  :aria-pressed="selectedDeliveryMethod === option.value"
                  @click="handleDeliverySelection(option.value)"
                >
                  <div class="checkout-review__choice-copy">
                    <strong>{{ option.label }}</strong>
                    <p>{{ option.description || option.estimatedDeliveryText }}</p>
                  </div>
                  <div class="checkout-review__choice-meta">
                    <span>{{ option.estimatedDeliveryText }}</span>
                    <strong>{{ Number(option.shippingAmount || 0) > 0 ? formatPrice(option.shippingAmount) : "Free" }}</strong>
                  </div>
                </button>
              </div>

              <div class="checkout-review__editor-actions checkout-review__editor-actions--end">
                <button
                  class="checkout-review__secondary"
                  type="button"
                  :disabled="!selectedDeliveryMethod"
                  @click="confirmShippingStep"
                >
                  {{ shippingConfirmed ? "Delivery saved" : "Save delivery" }}
                </button>
              </div>
            </div>
          </section>

          <section class="checkout-review__section">
            <div class="checkout-review__section-head">
              <h2>Payment method</h2>
              <button
                class="checkout-review__edit"
                type="button"
                :disabled="!shippingConfirmed"
                @click="editingPayment = true"
              >
                Edit
              </button>
            </div>

            <article class="checkout-review__payment-card" :class="{ 'checkout-review__payment-card--placeholder': !selectedPaymentOption }">
              <div class="checkout-review__info-icon">
                <svg viewBox="0 0 24 24" aria-hidden="true">
                  <rect x="3.5" y="6.5" width="17" height="11" rx="2"></rect>
                  <path d="M3.5 10h17"></path>
                </svg>
              </div>
              <div class="checkout-review__info-copy">
                <strong>{{ paymentSummaryTitle }}</strong>
                <p>{{ paymentSummaryText }}</p>
              </div>
            </article>

            <div v-if="shippingConfirmed && (editingPayment || !selectedMethod)" class="checkout-review__editor">
              <div class="checkout-review__choice-grid checkout-review__choice-grid--payment">
                <button
                  v-for="option in availablePaymentMethods"
                  :key="option.value"
                  class="checkout-review__choice-card"
                  type="button"
                  :class="{ 'checkout-review__choice-card--active': selectedMethod === option.value }"
                  :aria-pressed="selectedMethod === option.value"
                  @click="handlePaymentSelection(option.value)"
                >
                  <div class="checkout-review__choice-copy">
                    <strong>{{ option.title }}</strong>
                    <p>{{ option.copy }}</p>
                  </div>
                  <div class="checkout-review__choice-meta">
                    <span>{{ option.status }}</span>
                  </div>
                </button>
              </div>
            </div>

            <p v-else-if="!shippingConfirmed" class="checkout-review__hint">
              Confirm delivery to unlock payment selection.
            </p>
          </section>
        </main>

        <aside class="checkout-review__summary">
          <div class="checkout-review__summary-head">
            <span>Total</span>
            <strong>{{ formatPrice(totalAmount) }}</strong>
          </div>

          <div class="checkout-review__summary-divider"></div>

          <div class="checkout-review__summary-line">
            <span>Subtotal</span>
            <strong>{{ formatPrice(subtotalAmount) }}</strong>
          </div>
          <div class="checkout-review__summary-line">
            <span>Discount</span>
            <strong class="checkout-review__summary-line--discount">
              {{ discountAmount > 0 ? `-${formatPrice(discountAmount)}` : formatPrice(0) }}
            </strong>
          </div>
          <div class="checkout-review__summary-line">
            <span>Delivery</span>
            <strong>{{ shippingAmount > 0 ? formatPrice(shippingAmount) : "Free" }}</strong>
          </div>

          <button class="checkout-review__primary" type="submit" :disabled="!canSubmitCheckout">
            {{ primarySubmitLabel }}
          </button>

          <p class="checkout-review__legal">
            By continuing, you agree to our
            <RouterLink to="/refund-returne">returns policy</RouterLink>
            and can contact
            <RouterLink to="/mesazhet">support</RouterLink>.
          </p>

          <button class="checkout-review__back" type="button" @click="backToCart">
            Back to cart
          </button>
        </aside>
      </form>
    </div>
  </section>
</template>

<style scoped>
.checkout-review {
  min-height: 100%;
  background: #f5f5f5;
  padding: 32px 20px 64px;
}

.checkout-review__container {
  width: min(100%, 1240px);
  margin: 0 auto;
}

.checkout-review__top {
  margin-bottom: 24px;
}

.checkout-review__steps {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 14px;
}

.checkout-review__step {
  display: inline-flex;
  align-items: center;
  gap: 10px;
  color: #9a9a9a;
  font-size: 12px;
  font-weight: 500;
  line-height: 1;
}

.checkout-review__step-circle {
  width: 28px;
  height: 28px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  border: 1px solid #dbdbdb;
  border-radius: 999px;
  background: #ececec;
  color: #8a8a8a;
  font-size: 12px;
  font-weight: 600;
}

.checkout-review__step--completed {
  color: #2d7f4f;
}

.checkout-review__step--completed .checkout-review__step-circle {
  border-color: #2d7f4f;
  background: #2d7f4f;
  color: #ffffff;
}

.checkout-review__step--completed svg {
  width: 14px;
  height: 14px;
  fill: none;
  stroke: currentColor;
  stroke-width: 2;
  stroke-linecap: round;
  stroke-linejoin: round;
}

.checkout-review__step--active {
  color: #111111;
}

.checkout-review__step--active .checkout-review__step-circle {
  border-color: #111111;
  background: #111111;
  color: #ffffff;
}

.checkout-review__step-line {
  width: 56px;
  height: 1px;
  background: #dddddd;
}

.checkout-review__notice {
  margin-bottom: 20px;
  padding: 14px 16px;
  border: 1px solid #e5e5e5;
  border-radius: 12px;
  background: #ffffff;
  color: #4f4f4f;
  font-size: 14px;
  line-height: 1.5;
}

.checkout-review__notice--error {
  border-color: #efcccc;
  color: #b43b3b;
}

.checkout-review__notice--success {
  border-color: #cae4d4;
  color: #2d7f4f;
}

.checkout-review__notice--guest {
  border-color: #d8dde6;
  background: #f8fafc;
  color: #445060;
}

.checkout-review__layout {
  display: grid;
  grid-template-columns: minmax(0, 1.95fr) minmax(300px, 0.95fr);
  gap: 28px;
  align-items: start;
}

.checkout-review__main {
  display: grid;
  gap: 32px;
}

.checkout-review__section,
.checkout-review__summary {
  background: #ffffff;
  border: 1px solid #e5e5e5;
  border-radius: 12px;
}

.checkout-review__section {
  padding: 22px;
}

.checkout-review__summary {
  position: sticky;
  top: 24px;
  padding: 22px;
  box-shadow: 0 12px 28px rgba(17, 17, 17, 0.04);
}

.checkout-review__section-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  margin-bottom: 18px;
}

.checkout-review__section-head h1,
.checkout-review__section-head h2 {
  margin: 0;
  color: #111111;
  font-size: 22px;
  font-weight: 600;
  line-height: 1.2;
}

.checkout-review__edit,
.checkout-review__text-button,
.checkout-review__back {
  border: 0;
  background: transparent;
  padding: 0;
  color: #666666;
  font-size: 13px;
  font-weight: 500;
  line-height: 1;
  cursor: pointer;
}

.checkout-review__edit:hover,
.checkout-review__text-button:hover,
.checkout-review__back:hover {
  color: #111111;
}

.checkout-review__edit:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.checkout-review__items {
  display: grid;
  gap: 14px;
}

.checkout-review__item-row {
  min-height: 92px;
  display: grid;
  grid-template-columns: 72px minmax(0, 1fr) auto auto;
  align-items: center;
  gap: 16px;
  padding: 16px 18px;
  border-radius: 12px;
  background: #f7f7f7;
}

.checkout-review__item-image-wrap {
  width: 72px;
  height: 72px;
  overflow: hidden;
  border-radius: 10px;
  background: #ececec;
}

.checkout-review__item-image-wrap img {
  width: 100%;
  height: 100%;
  display: block;
  object-fit: cover;
}

.checkout-review__item-copy {
  min-width: 0;
  display: grid;
  gap: 5px;
}

.checkout-review__item-copy strong {
  color: #111111;
  font-size: 14px;
  font-weight: 600;
  line-height: 1.4;
}

.checkout-review__item-copy span,
.checkout-review__item-qty {
  color: #707070;
  font-size: 13px;
  line-height: 1.4;
}

.checkout-review__item-qty,
.checkout-review__item-price {
  white-space: nowrap;
}

.checkout-review__item-price {
  color: #111111;
  font-size: 14px;
  font-weight: 600;
}

.checkout-review__empty,
.checkout-review__hint {
  color: #727272;
  font-size: 14px;
  line-height: 1.5;
}

.checkout-review__info-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 18px;
}

.checkout-review__info-card,
.checkout-review__payment-card {
  min-height: 112px;
  display: grid;
  grid-template-columns: 52px minmax(0, 1fr);
  gap: 14px;
  align-items: start;
  padding: 18px;
  border: 1px solid #e5e5e5;
  border-radius: 12px;
  background: #ffffff;
}

.checkout-review__payment-card--placeholder {
  background: #fafafa;
}

.checkout-review__info-icon {
  width: 52px;
  height: 52px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  border-radius: 14px;
  background: #f4f4f4;
  color: #111111;
}

.checkout-review__info-icon svg {
  width: 22px;
  height: 22px;
  fill: none;
  stroke: currentColor;
  stroke-width: 1.8;
  stroke-linecap: round;
  stroke-linejoin: round;
}

.checkout-review__info-copy {
  display: grid;
  gap: 6px;
}

.checkout-review__info-copy strong {
  color: #111111;
  font-size: 15px;
  font-weight: 600;
  line-height: 1.35;
}

.checkout-review__info-copy p {
  margin: 0;
  color: #717171;
  font-size: 13px;
  line-height: 1.5;
}

.checkout-review__editor {
  margin-top: 18px;
  padding-top: 18px;
  border-top: 1px solid #ededed;
  display: grid;
  gap: 16px;
}

.checkout-review__editor-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

.checkout-review__editor-head strong {
  color: #111111;
  font-size: 14px;
  font-weight: 600;
}

.checkout-review__form-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 14px 16px;
}

.checkout-review__field {
  display: grid;
  gap: 8px;
}

.checkout-review__field--full {
  grid-column: 1 / -1;
}

.checkout-review__field span {
  color: #6f6f6f;
  font-size: 12px;
  font-weight: 500;
  line-height: 1.2;
}

.checkout-review__field input,
.checkout-review__field select {
  width: 100%;
  height: 44px;
  border: 1px solid #dedede;
  border-radius: 10px;
  background: #ffffff;
  padding: 0 14px;
  color: #111111;
  font-size: 14px;
  outline: none;
  transition: border-color 160ms ease;
}

.checkout-review__field input:focus,
.checkout-review__field select:focus {
  border-color: #bdbdbd;
}

.checkout-review__editor-actions {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  flex-wrap: wrap;
}

.checkout-review__editor-actions--end {
  justify-content: flex-end;
}

.checkout-review__checkbox {
  display: inline-flex;
  align-items: center;
  gap: 10px;
  color: #666666;
  font-size: 13px;
  line-height: 1.4;
}

.checkout-review__secondary {
  min-width: 152px;
  height: 42px;
  border: 1px solid #d8d8d8;
  border-radius: 10px;
  background: #ffffff;
  color: #111111;
  padding: 0 16px;
  font-size: 14px;
  font-weight: 600;
  cursor: pointer;
  transition: background-color 160ms ease, border-color 160ms ease;
}

.checkout-review__secondary:hover {
  background: #f7f7f7;
}

.checkout-review__secondary:disabled,
.checkout-review__primary:disabled {
  cursor: not-allowed;
  opacity: 0.55;
}

.checkout-review__choice-grid {
  display: grid;
  gap: 12px;
}

.checkout-review__choice-card {
  width: 100%;
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 16px;
  padding: 18px;
  border: 1px solid #e3e3e3;
  border-radius: 12px;
  background: #fafafa;
  color: #111111;
  text-align: left;
  cursor: pointer;
  transition: border-color 160ms ease, background-color 160ms ease;
}

.checkout-review__choice-card:hover,
.checkout-review__choice-card--active {
  border-color: #111111;
  background: #ffffff;
}

.checkout-review__choice-copy {
  min-width: 0;
  display: grid;
  gap: 6px;
}

.checkout-review__choice-copy strong {
  color: #111111;
  font-size: 14px;
  font-weight: 600;
  line-height: 1.35;
}

.checkout-review__choice-copy p {
  margin: 0;
  color: #717171;
  font-size: 13px;
  line-height: 1.45;
}

.checkout-review__choice-meta {
  display: grid;
  justify-items: end;
  gap: 6px;
  flex-shrink: 0;
}

.checkout-review__choice-meta span {
  color: #717171;
  font-size: 12px;
  line-height: 1.3;
}

.checkout-review__choice-meta strong {
  color: #111111;
  font-size: 14px;
  font-weight: 600;
}

.checkout-review__summary-head,
.checkout-review__summary-line {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
}

.checkout-review__summary-head {
  color: #111111;
  font-size: 18px;
  font-weight: 600;
}

.checkout-review__summary-head strong {
  font-size: 24px;
  font-weight: 700;
}

.checkout-review__summary-divider {
  height: 1px;
  margin: 18px 0;
  background: #ebebeb;
}

.checkout-review__summary-line {
  color: #666666;
  font-size: 14px;
  line-height: 1.5;
}

.checkout-review__summary-line + .checkout-review__summary-line {
  margin-top: 12px;
}

.checkout-review__summary-line strong {
  color: #111111;
  font-weight: 600;
}

.checkout-review__summary-line--discount {
  color: #c33939;
}

.checkout-review__primary {
  width: 100%;
  height: 46px;
  margin-top: 24px;
  border: 0;
  border-radius: 10px;
  background: linear-gradient(180deg, #242424 0%, #111111 100%);
  color: #ffffff;
  font-size: 14px;
  font-weight: 600;
  cursor: pointer;
  transition: opacity 160ms ease;
}

.checkout-review__primary:hover {
  opacity: 0.94;
}

.checkout-review__legal {
  margin: 14px 0 0;
  color: #787878;
  font-size: 12px;
  line-height: 1.6;
}

.checkout-review__legal a {
  color: #555555;
  text-decoration: underline;
}

.checkout-review__back {
  margin-top: 16px;
}

@media (max-width: 980px) {
  .checkout-review__layout {
    grid-template-columns: 1fr;
  }

  .checkout-review__summary {
    position: static;
  }
}

@media (max-width: 760px) {
  .checkout-review {
    padding: 20px 14px 40px;
  }

  .checkout-review__steps {
    gap: 8px;
  }

  .checkout-review__step-label {
    display: none;
  }

  .checkout-review__step-line {
    width: 28px;
  }

  .checkout-review__section {
    padding: 18px;
  }

  .checkout-review__section-head h1,
  .checkout-review__section-head h2 {
    font-size: 20px;
  }

  .checkout-review__item-row {
    grid-template-columns: 64px minmax(0, 1fr);
    gap: 14px;
  }

  .checkout-review__item-image-wrap {
    width: 64px;
    height: 64px;
  }

  .checkout-review__item-qty,
  .checkout-review__item-price {
    grid-column: 2;
  }

  .checkout-review__info-grid,
  .checkout-review__form-grid {
    grid-template-columns: 1fr;
  }

  .checkout-review__editor-actions {
    align-items: stretch;
  }

  .checkout-review__secondary {
    width: 100%;
  }
}
</style>
