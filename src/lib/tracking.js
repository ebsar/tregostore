const TRACKING_CONSENT_STORAGE_KEY = "trego_tracking_consent";
const DEFAULT_CURRENCY = "EUR";

function safeWindow() {
  return typeof window !== "undefined" ? window : null;
}

export function hasTrackingConsent() {
  const win = safeWindow();
  if (!win) {
    return false;
  }

  try {
    const consentValue = String(win.localStorage.getItem(TRACKING_CONSENT_STORAGE_KEY) || "").trim().toLowerCase();
    return consentValue === "granted" || consentValue === "true" || consentValue === "1";
  } catch (error) {
    console.error(error);
    return false;
  }
}

export function setTrackingConsent(enabled) {
  const win = safeWindow();
  if (!win) {
    return;
  }
  try {
    win.localStorage.setItem(TRACKING_CONSENT_STORAGE_KEY, enabled ? "granted" : "denied");
  } catch (error) {
    console.error(error);
  }
}

function buildProductTrackingPayload(product = {}, overrides = {}) {
  const productId = String(product?.id || overrides.id || "").trim();
  const title = String(product?.title || product?.name || overrides.title || "Product").trim();
  const priceValue = Number(product?.price ?? overrides.price ?? 0);
  const currency = String(overrides.currency || DEFAULT_CURRENCY).trim().toUpperCase() || DEFAULT_CURRENCY;

  return {
    id: productId,
    title,
    price: Number.isFinite(priceValue) ? priceValue : 0,
    currency,
    category: String(product?.category || overrides.category || "").trim(),
  };
}

function safeCallFbq(eventName, payload) {
  const win = safeWindow();
  if (!win || typeof win.fbq !== "function") {
    return;
  }
  try {
    win.fbq("track", eventName, payload);
  } catch (error) {
    console.error(error);
  }
}

function safeCallGtag(eventName, payload) {
  const win = safeWindow();
  if (!win || typeof win.gtag !== "function") {
    return;
  }
  try {
    win.gtag("event", eventName, payload);
  } catch (error) {
    console.error(error);
  }
}

export function trackProductView(product, options = {}) {
  if (!hasTrackingConsent()) {
    return;
  }

  const payload = buildProductTrackingPayload(product, options);
  if (!payload.id) {
    return;
  }

  safeCallFbq("ViewContent", {
    content_ids: [payload.id],
    content_name: payload.title,
    content_type: "product",
    value: payload.price,
    currency: payload.currency,
  });

  safeCallGtag("view_item", {
    currency: payload.currency,
    value: payload.price,
    items: [
      {
        item_id: payload.id,
        item_name: payload.title,
        item_category: payload.category || undefined,
        price: payload.price,
      },
    ],
  });
}

export function trackAddToCart(product, options = {}) {
  if (!hasTrackingConsent()) {
    return;
  }

  const payload = buildProductTrackingPayload(product, options);
  if (!payload.id) {
    return;
  }
  const quantity = Math.max(1, Math.trunc(Number(options.quantity || 1)));
  const value = Number((payload.price * quantity).toFixed(2));

  safeCallFbq("AddToCart", {
    content_ids: [payload.id],
    content_name: payload.title,
    content_type: "product",
    value,
    currency: payload.currency,
  });

  safeCallGtag("add_to_cart", {
    currency: payload.currency,
    value,
    items: [
      {
        item_id: payload.id,
        item_name: payload.title,
        item_category: payload.category || undefined,
        price: payload.price,
        quantity,
      },
    ],
  });
}
