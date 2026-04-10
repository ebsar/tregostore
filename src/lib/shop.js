import {
  PRODUCT_COLOR_LABELS,
  PRODUCT_COLOR_OPTIONS,
  PRODUCT_PAGE_SECTION_OPTIONS,
  PRODUCT_AUDIENCE_OPTIONS,
  PRODUCT_SECTION_OPTIONS,
  PRODUCT_TYPE_LABELS,
  PRODUCT_TYPE_OPTIONS_BY_CATEGORY,
  SECTION_PRODUCT_TYPE_OPTIONS,
  buildCategoryFromSelection,
  deriveSectionFromCategory,
  isClothingSection as isCatalogClothingSection,
} from "./product-catalog";

export const LOGIN_GREETING_KEY = "trego_login_greeting";
export const CHECKOUT_ADDRESS_DRAFT_KEY = "trego_checkout_address_draft";
export const CHECKOUT_PAYMENT_METHOD_KEY = "trego_checkout_payment_method";
export const CHECKOUT_DELIVERY_METHOD_KEY = "trego_checkout_delivery_method";
export const CHECKOUT_SELECTED_CART_IDS_KEY = "trego_checkout_selected_cart_ids";
export const ORDER_CONFIRMATION_MESSAGE_KEY = "trego_order_confirmation_message";
export const TRACK_ORDER_LOOKUP_KEY = "trego_track_order_lookup";
export const SAVED_FOR_LATER_ITEMS_KEY = "trego_saved_for_later_items";
export const APP_LOADER_MIN_DURATION_MS = 160;
const MAX_SAVED_FOR_LATER_ITEMS = 24;
export const DELIVERY_METHOD_OPTIONS = [
  {
    value: "standard",
    label: "Dergese standard",
    description: "Opsioni me i balancuar, me kosto qe llogaritet sipas biznesit ne shporte.",
    shippingAmount: 2.5,
    estimatedDeliveryText: "2-4 dite pune",
    badge: "Opsioni 01",
  },
  {
    value: "express",
    label: "Dergese express",
    description: "Per porosi me urgjence, nese bizneset ne shporte e kane aktivizuar.",
    shippingAmount: 4.9,
    estimatedDeliveryText: "1-2 dite pune",
    badge: "Opsioni 02",
  },
  {
    value: "pickup",
    label: "Terheqje ne biznes",
    description: "Rezervo online dhe terhiqe produktin direkt te biznesi kur pickup eshte aktiv.",
    shippingAmount: 0,
    estimatedDeliveryText: "Gati per terheqje brenda 24 oresh",
    badge: "Opsioni 03",
  },
];

function createSearchHref({ categoryGroup = "", category = "", productType = "" } = {}) {
  const params = new URLSearchParams();
  if (categoryGroup) {
    params.set("categoryGroup", categoryGroup);
  }
  if (category) {
    params.set("category", category);
  }
  if (productType) {
    params.set("productType", productType);
  }

  return `/kerko?${params.toString()}`;
}

function createNavigationGroups(sectionValue) {
  const audiences = PRODUCT_AUDIENCE_OPTIONS[sectionValue] || [];

  if (audiences.length > 0) {
    return audiences.map((audience) => {
      const category = buildCategoryFromSelection(sectionValue, audience.value);

      return {
        key: `${sectionValue}-${audience.value}`,
        label: audience.label,
        href: createSearchHref({ category }),
      };
    });
  }

  const productTypes = PRODUCT_TYPE_OPTIONS_BY_CATEGORY[sectionValue] || [];

  return productTypes.slice(0, 6).map((productType) => ({
    key: `${sectionValue}-${productType.value}`,
    label: productType.label,
    href: createSearchHref({ category: sectionValue, productType: productType.value }),
  }));
}

function buildSavedForLaterItemKey(item = {}) {
  const productId = Number(item?.productId ?? item?.id ?? 0);
  if (!Number.isFinite(productId) || productId <= 0) {
    return "";
  }

  const variantKey = String(item?.variantKey || "").trim();
  const selectedSize = String(item?.selectedSize || item?.size || "").trim().toUpperCase();
  const selectedColor = String(item?.selectedColor || item?.color || "").trim().toLowerCase();

  return [productId, variantKey || selectedSize || "-", selectedColor || "-"].join(":");
}

function sanitizeSavedForLaterItem(item) {
  const productId = Number(item?.productId ?? item?.id ?? 0);
  if (!Number.isFinite(productId) || productId <= 0) {
    return null;
  }

  return {
    id: productId,
    productId,
    title: String(item?.title || item?.productName || "").trim() || "Produkt",
    description: String(item?.description || "").trim(),
    price: Number(item?.price || 0),
    imagePath:
      String(item?.imagePath || item?.image_path || item?.image || "").trim() || "/bujqesia.webp",
    category: String(item?.category || "").trim(),
    productType: String(item?.productType || "").trim(),
    businessName: String(item?.businessName || "").trim(),
    quantity: Math.max(1, Math.trunc(Number(item?.quantity || 1) || 1)),
    variantKey: String(item?.variantKey || "").trim(),
    variantLabel: String(item?.variantLabel || "").trim(),
    selectedSize: String(item?.selectedSize || item?.size || "").trim().toUpperCase(),
    selectedColor: String(item?.selectedColor || item?.color || "").trim().toLowerCase(),
    showStockPublic: Boolean(item?.showStockPublic),
    stockQuantity: Number(item?.stockQuantity || 0),
  };
}

function normalizeSavedForLaterItems(items = []) {
  if (!Array.isArray(items)) {
    return [];
  }

  const nextItems = [];
  const seenKeys = new Set();

  items.forEach((item) => {
    const snapshot = sanitizeSavedForLaterItem(item);
    if (!snapshot) {
      return;
    }

    const key = buildSavedForLaterItemKey(snapshot);
    if (!key || seenKeys.has(key)) {
      return;
    }

    seenKeys.add(key);
    nextItems.push(snapshot);
  });

  return nextItems.slice(0, MAX_SAVED_FOR_LATER_ITEMS);
}

export const PRIMARY_NAVIGATION = PRODUCT_PAGE_SECTION_OPTIONS.map((section) => {
  const hasAudiences = (PRODUCT_AUDIENCE_OPTIONS[section.value] || []).length > 0;

  return {
    key: section.value,
    label: section.label,
    href: hasAudiences
      ? createSearchHref({ categoryGroup: section.value })
      : createSearchHref({ category: section.value }),
    groups: createNavigationGroups(section.value),
  };
});

export const HOME_PROMO_SLIDES = [
  {
    title: "Oferta te reja cdo jave",
    description:
      "Zbulo produktet me te kerkuara per shtepi, bukuri dhe stil ne nje vend te vetem.",
    badge: "Reklame 01",
    ctaLabel: "Shiko produktet",
    ctaHref: "/kerko",
    imagePath: "/bujqesia.webp",
  },
  {
    title: "Veshje dhe kozmetike ne trend",
    description:
      "Nga veshjet per meshkuj e femra deri te kozmetika e perditshme, tash i gjen me shpejt.",
    badge: "Reklame 02",
    ctaLabel: "Kerko koleksionin",
    ctaHref: "/kerko?category=clothing-women",
    imagePath: "/gjelbert.webp",
  },
  {
    title: "Teknologji dhe shtepi me oferta",
    description:
      "Aksesor per telefon, dekor dhe produkte praktike per perditshmeri ne nje katalog te vetem.",
    badge: "Reklame 03",
    ctaLabel: "Hap kategorite",
    ctaHref: "/kerko?category=technology",
    imagePath: "/gruri.webp",
  },
];

export function calculateCartItemsCount(items = []) {
  if (!Array.isArray(items)) {
    return 0;
  }

  return items.reduce((total, item) => {
    const quantity = Number(item?.quantity);
    if (Number.isFinite(quantity) && quantity > 0) {
      return total + Math.trunc(quantity);
    }

    return total + 1;
  }, 0);
}

export function persistLoginGreeting(value) {
  try {
    const nextValue = String(value || "").trim() || "User";
    window.sessionStorage.setItem(LOGIN_GREETING_KEY, nextValue);
  } catch (error) {
    console.error(error);
  }
}

export function consumeLoginGreeting() {
  try {
    const value = String(window.sessionStorage.getItem(LOGIN_GREETING_KEY) || "").trim();
    if (!value) {
      return "";
    }

    window.sessionStorage.removeItem(LOGIN_GREETING_KEY);
    return value;
  } catch (error) {
    console.error(error);
    return "";
  }
}

export function persistCheckoutSelectedCartIds(ids) {
  try {
    window.sessionStorage.setItem(
      CHECKOUT_SELECTED_CART_IDS_KEY,
      JSON.stringify(
        Array.isArray(ids)
          ? ids
              .map((id) => Number(id))
              .filter((id) => Number.isFinite(id) && id > 0)
          : [],
      ),
    );
  } catch (error) {
    console.error(error);
  }
}

export function readCheckoutSelectedCartIds() {
  try {
    const rawValue = window.sessionStorage.getItem(CHECKOUT_SELECTED_CART_IDS_KEY);
    if (!rawValue) {
      return [];
    }

    const parsedValue = JSON.parse(rawValue);
    if (!Array.isArray(parsedValue)) {
      return [];
    }

    return parsedValue
      .map((id) => Number(id))
      .filter((id) => Number.isFinite(id) && id > 0);
  } catch (error) {
    console.error(error);
    return [];
  }
}

export function persistCheckoutAddressDraft(address) {
  try {
    window.sessionStorage.setItem(
      CHECKOUT_ADDRESS_DRAFT_KEY,
      JSON.stringify(normalizeAddress(address)),
    );
  } catch (error) {
    console.error(error);
  }
}

export function readCheckoutAddressDraft() {
  try {
    const rawValue = window.sessionStorage.getItem(CHECKOUT_ADDRESS_DRAFT_KEY);
    if (!rawValue) {
      return null;
    }

    return normalizeAddress(JSON.parse(rawValue));
  } catch (error) {
    console.error(error);
    return null;
  }
}

export function persistCheckoutPaymentMethod(method) {
  try {
    window.sessionStorage.setItem(
      CHECKOUT_PAYMENT_METHOD_KEY,
      String(method || "").trim(),
    );
  } catch (error) {
    console.error(error);
  }
}

export function readCheckoutPaymentMethod() {
  try {
    return String(window.sessionStorage.getItem(CHECKOUT_PAYMENT_METHOD_KEY) || "").trim();
  } catch (error) {
    console.error(error);
    return "";
  }
}

export function persistCheckoutDeliveryMethod(method) {
  try {
    window.sessionStorage.setItem(
      CHECKOUT_DELIVERY_METHOD_KEY,
      String(method || "").trim() || "standard",
    );
  } catch (error) {
    console.error(error);
  }
}

export function readCheckoutDeliveryMethod() {
  try {
    const nextValue = String(window.sessionStorage.getItem(CHECKOUT_DELIVERY_METHOD_KEY) || "").trim();
    return nextValue || "standard";
  } catch (error) {
    console.error(error);
    return "standard";
  }
}

export function persistOrderConfirmationMessage(message) {
  try {
    const nextValue = String(message || "").trim();
    if (!nextValue) {
      return;
    }

    window.sessionStorage.setItem(ORDER_CONFIRMATION_MESSAGE_KEY, nextValue);
  } catch (error) {
    console.error(error);
  }
}

export function consumeOrderConfirmationMessage() {
  try {
    const value = String(window.sessionStorage.getItem(ORDER_CONFIRMATION_MESSAGE_KEY) || "").trim();
    if (!value) {
      return "";
    }

    window.sessionStorage.removeItem(ORDER_CONFIRMATION_MESSAGE_KEY);
    return value;
  } catch (error) {
    console.error(error);
    return "";
  }
}

export function persistTrackedOrderLookup(payload) {
  try {
    const orderId = Math.max(0, Math.trunc(Number(payload?.orderId || payload?.order?.id || 0) || 0));
    const billingEmail = String(payload?.billingEmail || "").trim().toLowerCase();
    const order = payload?.order && typeof payload.order === "object" ? payload.order : null;

    if (!orderId || !billingEmail || !order) {
      return null;
    }

    const snapshot = {
      orderId,
      billingEmail,
      order,
      lookedUpAt: new Date().toISOString(),
    };

    window.sessionStorage.setItem(TRACK_ORDER_LOOKUP_KEY, JSON.stringify(snapshot));
    return snapshot;
  } catch (error) {
    console.error(error);
    return null;
  }
}

export function readTrackedOrderLookup() {
  try {
    const rawValue = window.sessionStorage.getItem(TRACK_ORDER_LOOKUP_KEY);
    if (!rawValue) {
      return null;
    }

    const parsedValue = JSON.parse(rawValue);
    if (!parsedValue || typeof parsedValue !== "object") {
      return null;
    }

    const orderId = Math.max(0, Math.trunc(Number(parsedValue.orderId || parsedValue.order?.id || 0) || 0));
    const billingEmail = String(parsedValue.billingEmail || "").trim().toLowerCase();
    const order = parsedValue.order && typeof parsedValue.order === "object" ? parsedValue.order : null;

    if (!orderId || !billingEmail || !order) {
      return null;
    }

    return {
      orderId,
      billingEmail,
      order,
      lookedUpAt: String(parsedValue.lookedUpAt || "").trim(),
    };
  } catch (error) {
    console.error(error);
    return null;
  }
}

export function clearTrackedOrderLookup() {
  try {
    window.sessionStorage.removeItem(TRACK_ORDER_LOOKUP_KEY);
  } catch (error) {
    console.error(error);
  }
}

export function clearCheckoutFlowState() {
  try {
    window.sessionStorage.removeItem(CHECKOUT_ADDRESS_DRAFT_KEY);
    window.sessionStorage.removeItem(CHECKOUT_PAYMENT_METHOD_KEY);
    window.sessionStorage.removeItem(CHECKOUT_DELIVERY_METHOD_KEY);
    window.sessionStorage.removeItem(CHECKOUT_SELECTED_CART_IDS_KEY);
  } catch (error) {
    console.error(error);
  }
}

export function readSavedForLaterItems() {
  try {
    const rawValue = window.localStorage.getItem(SAVED_FOR_LATER_ITEMS_KEY);
    if (!rawValue) {
      return [];
    }

    const parsedValue = JSON.parse(rawValue);
    if (!Array.isArray(parsedValue)) {
      return [];
    }

    return normalizeSavedForLaterItems(parsedValue);
  } catch (error) {
    console.error(error);
    return [];
  }
}

export function persistSavedForLaterItems(items) {
  try {
    const normalizedItems = normalizeSavedForLaterItems(items);
    window.localStorage.setItem(SAVED_FOR_LATER_ITEMS_KEY, JSON.stringify(normalizedItems));
    return normalizedItems;
  } catch (error) {
    console.error(error);
    return [];
  }
}

export function rememberSavedForLaterItem(item) {
  try {
    const snapshot = sanitizeSavedForLaterItem(item);
    if (!snapshot) {
      return readSavedForLaterItems();
    }

    const snapshotKey = buildSavedForLaterItemKey(snapshot);
    const nextItems = [
      snapshot,
      ...readSavedForLaterItems().filter((entry) => buildSavedForLaterItemKey(entry) !== snapshotKey),
    ].slice(0, MAX_SAVED_FOR_LATER_ITEMS);

    window.localStorage.setItem(SAVED_FOR_LATER_ITEMS_KEY, JSON.stringify(nextItems));
    return nextItems;
  } catch (error) {
    console.error(error);
    return readSavedForLaterItems();
  }
}

export function removeSavedForLaterItem(itemOrId, variantKey = "", selectedSize = "", selectedColor = "") {
  try {
    const targetKey =
      itemOrId && typeof itemOrId === "object"
        ? buildSavedForLaterItemKey(itemOrId)
        : buildSavedForLaterItemKey({
            id: itemOrId,
            variantKey,
            selectedSize,
            selectedColor,
          });
    if (!targetKey) {
      return readSavedForLaterItems();
    }

    const nextItems = readSavedForLaterItems().filter(
      (entry) => buildSavedForLaterItemKey(entry) !== targetKey,
    );
    window.localStorage.setItem(SAVED_FOR_LATER_ITEMS_KEY, JSON.stringify(nextItems));
    return nextItems;
  } catch (error) {
    console.error(error);
    return readSavedForLaterItems();
  }
}

export function clearSavedForLaterItems() {
  try {
    window.localStorage.removeItem(SAVED_FOR_LATER_ITEMS_KEY);
  } catch (error) {
    console.error(error);
  }

  return [];
}

export function formatPrice(value) {
  const number = Number(value);
  if (Number.isNaN(number)) {
    return "€0";
  }

  return `€${number.toFixed(2).replace(/\.?0+$/, "")}`;
}

export function formatCount(value) {
  const number = Number(value || 0);
  if (Number.isNaN(number) || number <= 0) {
    return "0";
  }

  return new Intl.NumberFormat("sq-AL", {
    maximumFractionDigits: 0,
  }).format(number);
}

export function formatCategoryLabel(category) {
  const labels = {
    "clothing-babies": "Veshje per beba",
    "cosmetics-kids": "Kozmetike per femije",
    pets: "Kafshet shtepiake",
    agriculture: "Bujqesi",
    medicine: "Barnat",
  };

  return labels[category] || PRODUCT_SECTION_OPTIONS.find((option) => option.value === category)?.label || humanizeSlug(category);
}

export function formatCategoryGroupLabel(group) {
  const labels = {
    clothing: "Veshje",
    cosmetics: "Kozmetika",
  };

  return labels[String(group || "").trim().toLowerCase()] || humanizeSlug(group);
}

export function formatProductTypeLabel(productType) {
  const labels = {
    clothing: "Veshje",
    cream: "Kremera",
    food: "Ushqim",
    tools: "Vegla",
    other: "Tjera",
  };

  return labels[productType] || PRODUCT_TYPE_LABELS[productType] || humanizeSlug(productType);
}

export function formatProductColorLabel(color) {
  return PRODUCT_COLOR_LABELS[color] || color;
}

export function formatStockQuantity(value) {
  const number = Number(value);
  if (!Number.isFinite(number)) {
    return "0 cope";
  }

  return `${Math.max(0, Math.trunc(number))} cope`;
}

export function hasProductAvailableStock(product = {}) {
  const variantInventory = Array.isArray(product?.variantInventory) ? product.variantInventory : [];
  if (variantInventory.length > 0) {
    const selectedVariantKey = String(
      product?.variantKey
      || product?.selectedVariantKey
      || product?.variantId
      || "",
    ).trim();
    const selectedSize = String(product?.selectedSize || product?.size || "").trim().toUpperCase();
    const selectedColor = String(product?.selectedColor || product?.color || "").trim().toLowerCase();

    if (selectedVariantKey) {
      const selectedVariant = variantInventory.find((entry) => String(entry?.key || entry?.variantKey || entry?.id || "").trim() === selectedVariantKey);
      if (selectedVariant) {
        return Number(selectedVariant?.quantity || 0) > 0;
      }
    }

    if (selectedSize || selectedColor) {
      const selectedVariant = variantInventory.find((entry) => {
        const entrySize = String(entry?.size || "").trim().toUpperCase();
        const entryColor = String(entry?.color || "").trim().toLowerCase();
        const sizeMatches = !selectedSize || entrySize === selectedSize;
        const colorMatches = !selectedColor || entryColor === selectedColor;
        return sizeMatches && colorMatches;
      });

      if (selectedVariant) {
        return Number(selectedVariant?.quantity || 0) > 0;
      }
    }

    return variantInventory.some((entry) => Number(entry?.quantity || 0) > 0);
  }

  return Number(product?.stockQuantity || 0) > 0;
}

export function getProductStockMessage(product = {}) {
  return hasProductAvailableStock(product)
    ? ""
    : "Na vjen keq, ky produkt nuk eshte me ne stok.";
}

export function formatDateLabel(value) {
  if (!value) {
    return "-";
  }

  const parsedDate = new Date(String(value).replace(" ", "T"));
  if (Number.isNaN(parsedDate.getTime())) {
    return String(value);
  }

  return parsedDate.toLocaleDateString("sq-AL", {
    year: "numeric",
    month: "long",
    day: "numeric",
  });
}

export function getProductDetailUrl(productId, backPath = "") {
  const cleanBackPath = String(backPath || "").trim();
  const baseUrl = `/produkti?id=${encodeURIComponent(productId)}`;
  if (!cleanBackPath) {
    return baseUrl;
  }

  return `${baseUrl}&back=${encodeURIComponent(cleanBackPath)}`;
}

export function getBusinessProfileUrl(businessId) {
  return `/profili-biznesit?id=${encodeURIComponent(businessId)}`;
}

export function getVerifyEmailUrl(email = "") {
  const cleanEmail = String(email || "").trim();
  if (!cleanEmail) {
    return "/verifiko-email";
  }

  return `/verifiko-email?email=${encodeURIComponent(cleanEmail)}`;
}

export function getCategoryUrl(category) {
  const urls = {
    "clothing-men": "/kerko?category=clothing-men",
    "clothing-women": "/kerko?category=clothing-women",
    "clothing-kids": "/kerko?category=clothing-kids",
    "clothing-babies": "/kerko?category=clothing-babies",
    "cosmetics-men": "/kerko?category=cosmetics-men",
    "cosmetics-women": "/kerko?category=cosmetics-women",
    "cosmetics-kids": "/kerko?category=cosmetics-kids",
    pets: "/kerko?category=pets",
    agriculture: "/kerko?category=agriculture",
    medicine: "/kerko?category=medicine",
    home: "/kerko?category=home",
    sport: "/kerko?category=sport",
    technology: "/kerko?category=technology",
  };

  return urls[category] || "/";
}

export function getProductImageGallery(product) {
  const gallery = [];
  const rawGallery = Array.isArray(product?.imageGallery) ? product.imageGallery : [];

  rawGallery.forEach((path) => {
    const normalizedPath = String(path || "").trim();
    if (normalizedPath && !gallery.includes(normalizedPath)) {
      gallery.push(normalizedPath);
    }
  });

  const coverImage = String(product?.imagePath || "").trim();
  if (coverImage && !gallery.includes(coverImage)) {
    gallery.unshift(coverImage);
  }

  return gallery;
}

export function getSafeGalleryIndex(index, totalImages) {
  const total = Number(totalImages);
  if (!Number.isFinite(total) || total <= 0) {
    return 0;
  }

  const current = Number(index);
  if (!Number.isFinite(current) || current < 0) {
    return 0;
  }

  return Math.min(total - 1, Math.trunc(current));
}

export function getBusinessInitials(value) {
  const parts = String(value || "")
    .trim()
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2);

  if (parts.length === 0) {
    return "TR";
  }

  return parts
    .map((part) => part.charAt(0).toUpperCase())
    .join("");
}

export function formatRoleLabel(role) {
  const labels = {
    admin: "Admin",
    business: "Biznes",
    client: "User",
  };

  return labels[String(role || "").trim()] || "User";
}

export function formatPaymentMethodLabel(paymentMethod) {
  const labels = {
    cash: "Pages cash",
    "card-online": "Pages me kartel online",
  };

  return labels[String(paymentMethod || "").trim()] || "Pagesa";
}

export function getDeliveryMethodOption(deliveryMethod) {
  const normalizedValue = String(deliveryMethod || "").trim().toLowerCase() || "standard";
  return (
    DELIVERY_METHOD_OPTIONS.find((option) => option.value === normalizedValue)
    || DELIVERY_METHOD_OPTIONS[0]
  );
}

export function formatDeliveryMethodLabel(deliveryMethod) {
  return getDeliveryMethodOption(deliveryMethod)?.label || "Dergese standard";
}

export function formatEstimatedDeliveryLabel(deliveryMethod, fallbackText = "") {
  const explicitText = String(fallbackText || "").trim();
  if (explicitText) {
    return explicitText;
  }

  return getDeliveryMethodOption(deliveryMethod)?.estimatedDeliveryText || "";
}

export function formatOrderStatusLabel(status) {
  const labels = {
    pending_confirmation: "Porosia pret konfirmim",
    confirmed: "Porosia u konfirmua",
    partially_confirmed: "Porosia pjeserisht u konfirmua",
    pending: "Ne pritje",
    packed: "Po pergatitet",
    shipped: "Ne transport",
    delivered: "E dorezuar",
    cancelled: "E anuluar",
    returned: "E kthyer",
  };

  return labels[String(status || "").trim()] || "Porosia";
}

export function formatOrderStatusBadgeLabel(status) {
  const labels = {
    pending_confirmation: "Pret konfirmim",
    partially_confirmed: "Pjeserisht e konfirmuar",
  };

  return labels[String(status || "").trim()] || "";
}

export function formatFulfillmentStatusLabel(status) {
  const labels = {
    pending_confirmation: "Ne pritje te konfirmimit",
    confirmed: "E konfirmuar",
    partially_confirmed: "Pjeserisht e konfirmuar",
    packed: "E paketuar",
    shipped: "Ne dergese",
    delivered: "E dorezuar",
    cancelled: "E anuluar",
    returned: "E kthyer",
  };

  return labels[String(status || "").trim()] || "Ne proces";
}

export function buildFulfillmentTimeline(item = {}) {
  const normalizedStatus = String(item?.fulfillmentStatus || item?.status || "confirmed")
    .trim()
    .toLowerCase() || "pending_confirmation";
  const progressSteps = ["pending_confirmation", "confirmed", "packed", "shipped", "delivered"];
  const indexedStatus = progressSteps.indexOf(normalizedStatus);
  const fallbackIndex = normalizedStatus === "returned" ? 4 : 0;
  const resolvedIndex = indexedStatus >= 0 ? indexedStatus : fallbackIndex;

  return progressSteps.map((stepKey, index) => {
    let meta = "";
    if (stepKey === "pending_confirmation") {
      const confirmationDueAt = item?.confirmationDueAt || "";
      meta = confirmationDueAt ? `Afati: ${formatDateLabel(confirmationDueAt)}` : "";
    } else if (stepKey === "confirmed") {
      const confirmedAt = item?.confirmedAt || item?.createdAt || "";
      meta = confirmedAt ? formatDateLabel(confirmedAt) : "";
    } else if (stepKey === "shipped") {
      meta = item?.shippedAt ? formatDateLabel(item.shippedAt) : "";
    } else if (stepKey === "delivered") {
      meta = item?.deliveredAt ? formatDateLabel(item.deliveredAt) : "";
    }

    return {
      key: stepKey,
      label: formatOrderStatusLabel(stepKey),
      meta,
      isCompleted: index < resolvedIndex || (index === resolvedIndex && normalizedStatus === "delivered"),
      isCurrent: index === resolvedIndex && !["delivered", "cancelled", "returned"].includes(normalizedStatus),
      isDelivered: stepKey === "delivered" && ["delivered", "returned"].includes(normalizedStatus),
    };
  });
}

export function getFulfillmentTerminalEvent(item = {}) {
  const normalizedStatus = String(item?.fulfillmentStatus || item?.status || "")
    .trim()
    .toLowerCase();

  if (normalizedStatus === "cancelled") {
    return {
      label: formatFulfillmentStatusLabel(normalizedStatus),
      meta: item?.cancelledAt ? formatDateLabel(item.cancelledAt) : "",
      tone: "cancelled",
    };
  }

  if (normalizedStatus === "returned") {
    return {
      label: formatFulfillmentStatusLabel(normalizedStatus),
      meta: item?.deliveredAt ? formatDateLabel(item.deliveredAt) : "",
      tone: "returned",
    };
  }

  return null;
}

export function formatReturnRequestStatusLabel(status) {
  const labels = {
    requested: "Kerkese e derguar",
    approved: "E aprovuar",
    rejected: "E refuzuar",
    received: "Produkti u pranua",
    refunded: "E rimbursuar",
  };

  return labels[String(status || "").trim()] || "Ne shqyrtim";
}

export function isAutomaticRefundRequest(request = {}) {
  const haystack = [
    request?.reason,
    request?.details,
    request?.returnRequestReason,
    request?.returnRequestDetails,
  ]
    .map((value) => String(value || "").toLowerCase())
    .join(" ");

  return (
    haystack.includes("refund automatik")
    || haystack.includes("u anulua automatikisht")
    || haystack.includes("nuk u konfirmua brenda afatit")
  );
}

export function getAutomaticRefundNotice(request = {}) {
  if (!isAutomaticRefundRequest(request)) {
    return "";
  }

  return "Na vjen keq, ky artikull nuk u konfirmua nga biznesi brenda afatit dhe kaloi ne refund automatik.";
}

export function formatVerificationStatusLabel(status) {
  const labels = {
    unverified: "Pa verifikim",
    pending: "Ne shqyrtim",
    verified: "I verifikuar",
    rejected: "I refuzuar",
  };

  return labels[String(status || "").trim()] || "Pa verifikim";
}

export function humanizeSlug(value) {
  return String(value || "")
    .replace(/-/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .replace(/\b\w/g, (character) => character.toUpperCase());
}

export function normalizeAddress(address) {
  return {
    addressLine: String(address?.addressLine || ""),
    city: String(address?.city || ""),
    country: String(address?.country || ""),
    zipCode: String(address?.zipCode || ""),
    phoneNumber: String(address?.phoneNumber || ""),
  };
}

export function createEmptyAddress() {
  return {
    addressLine: "",
    city: "",
    country: "",
    zipCode: "",
    phoneNumber: "",
  };
}

export function isClothingSection(sectionValue) {
  return isCatalogClothingSection(sectionValue);
}

export function getProfileValuesFromUser(user) {
  const firstName = String(user?.firstName || "").trim();
  const lastName = String(user?.lastName || "").trim();
  const profileImagePath = String(user?.profileImagePath || "").trim();

  if (firstName || lastName) {
    return {
      firstName,
      lastName,
      birthDate: String(user?.birthDate || ""),
      gender: String(user?.gender || ""),
      profileImagePath,
    };
  }

  const nameParts = String(user?.fullName || "")
    .trim()
    .split(/\s+/)
    .filter(Boolean);

  return {
    firstName: nameParts[0] || "",
    lastName: nameParts.slice(1).join(" "),
    birthDate: String(user?.birthDate || ""),
    gender: String(user?.gender || ""),
    profileImagePath,
  };
}
