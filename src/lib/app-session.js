export const APP_LOADER_MIN_DURATION_MS = 160;
export const LOGIN_GREETING_KEY = "trego_login_greeting";
export const TRACK_ORDER_LOOKUP_KEY = "trego_track_order_lookup";

export function calculateCartItemsCount(items = []) {
  return (Array.isArray(items) ? items : []).reduce((total, item) => {
    const quantity = Number(item?.quantity || 0);
    if (!Number.isFinite(quantity) || quantity <= 0) {
      return total;
    }

    return total + Math.trunc(quantity);
  }, 0);
}

export function consumeLoginGreeting() {
  if (typeof window === "undefined") {
    return "";
  }

  try {
    const value = String(window.sessionStorage.getItem(LOGIN_GREETING_KEY) || "").trim();
    window.sessionStorage.removeItem(LOGIN_GREETING_KEY);
    return value;
  } catch (error) {
    console.error(error);
    return "";
  }
}

export function clearTrackedOrderLookup() {
  if (typeof window === "undefined") {
    return;
  }

  try {
    window.sessionStorage.removeItem(TRACK_ORDER_LOOKUP_KEY);
  } catch (error) {
    console.error(error);
  }
}
