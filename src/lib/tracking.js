const TRACKING_CONSENT_STORAGE_KEY = "trego_tracking_consent";
const DEFAULT_CURRENCY = "EUR";
const MAX_TRACKING_ITEMS = 20;
const FIRED_EVENT_KEYS = new Set();

function safeWindow() {
  return typeof window !== "undefined" ? window : null;
}

export function getTrackingConsentState() {
  const win = safeWindow();
  if (!win) {
    return "unset";
  }

  try {
    const consentValue = String(win.localStorage.getItem(TRACKING_CONSENT_STORAGE_KEY) || "").trim().toLowerCase();
    if (consentValue === "granted" || consentValue === "true" || consentValue === "1") {
      return "granted";
    }
    if (consentValue === "denied" || consentValue === "false" || consentValue === "0") {
      return "denied";
    }
    return "unset";
  } catch (error) {
    console.error(error);
    return "unset";
  }
}

export function hasTrackingConsent() {
  return getTrackingConsentState() === "granted";
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

function normalizeTrackingItems(products = [], currency = DEFAULT_CURRENCY) {
  if (!Array.isArray(products)) {
    return [];
  }
  return products
    .map((product) => buildProductTrackingPayload(product, { currency }))
    .filter((item) => item.id)
    .slice(0, MAX_TRACKING_ITEMS)
    .map((item) => ({
      item_id: item.id,
      item_name: item.title,
      item_category: item.category || undefined,
      price: item.price,
    }));
}

function shouldSkipDuplicateEvent(eventKey = "") {
  const normalizedKey = String(eventKey || "").trim();
  if (!normalizedKey) {
    return false;
  }
  if (FIRED_EVENT_KEYS.has(normalizedKey)) {
    return true;
  }
  FIRED_EVENT_KEYS.add(normalizedKey);
  if (FIRED_EVENT_KEYS.size > 400) {
    FIRED_EVENT_KEYS.clear();
  }
  return false;
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

export function trackSearchResults(options = {}) {
  if (!hasTrackingConsent()) {
    return;
  }

  const query = String(options.query || "").trim();
  const currency = String(options.currency || DEFAULT_CURRENCY).trim().toUpperCase() || DEFAULT_CURRENCY;
  const items = normalizeTrackingItems(options.products, currency);
  const totalValue = options.total ?? items.length ?? 0;
  const numberOfResults = Math.max(0, Math.trunc(Number(totalValue)));
  if (!query && items.length === 0) {
    return;
  }

  const contentIds = items.map((item) => item.item_id).filter(Boolean);
  const eventKey = `search:${query}:${numberOfResults}:${contentIds.join(",")}`;
  if (shouldSkipDuplicateEvent(eventKey)) {
    return;
  }

  safeCallFbq("Search", {
    search_string: query || undefined,
    content_ids: contentIds,
    content_type: "product",
  });

  safeCallGtag("view_search_results", {
    search_term: query || undefined,
    currency,
    number_of_results: numberOfResults,
    items,
  });
}
