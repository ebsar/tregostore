import { reactive } from "vue";
import { fetchCurrentUserOptional, fetchProtectedCollection, requestJson } from "../lib/api";
import {
  APP_LOADER_MIN_DURATION_MS,
  calculateCartItemsCount,
  consumeLoginGreeting,
} from "../lib/shop";

export const appState = reactive({
  user: null,
  sessionLoaded: false,
  cartCount: 0,
  loaderVisible: true,
  loaderStartedAt: Date.now(),
  loginGreeting: "",
});

let routeLoaderToken = 0;
let greetingTimeoutId = 0;

export function beginRouteLoading() {
  routeLoaderToken += 1;
  appState.loaderVisible = true;
  appState.loaderStartedAt = Date.now();
  return routeLoaderToken;
}

export function markRouteReady(token = routeLoaderToken) {
  if (!appState.loaderVisible) {
    return;
  }

  const remaining = Math.max(
    0,
    APP_LOADER_MIN_DURATION_MS - (Date.now() - appState.loaderStartedAt),
  );

  window.setTimeout(() => {
    if (token !== routeLoaderToken) {
      return;
    }

    appState.loaderVisible = false;
  }, remaining);
}

export function setCartCount(count) {
  const normalizedCount = Number.isFinite(Number(count))
    ? Math.max(0, Math.trunc(Number(count)))
    : 0;
  appState.cartCount = normalizedCount;
}

export function setCartItems(items = []) {
  setCartCount(calculateCartItemsCount(items));
}

async function enrichUserSessionData(user) {
  if (!user || user.role !== "business") {
    return user;
  }

  try {
    const { response, data } = await requestJson("/api/business/profile");
    if (!response.ok || !data?.ok || !data.profile) {
      return user;
    }

    return {
      ...user,
      businessName: String(data.profile.businessName || "").trim(),
      businessLogoPath: String(data.profile.logoPath || "").trim(),
    };
  } catch (error) {
    console.error(error);
    return user;
  }
}

export async function ensureSessionLoaded(options = {}) {
  const { force = false } = options;
  if (
    appState.sessionLoaded &&
    !force &&
    !(appState.user?.role === "business" && !String(appState.user?.businessName || "").trim())
  ) {
    return appState.user;
  }

  const currentUser = await fetchCurrentUserOptional();
  const user = await enrichUserSessionData(currentUser);
  appState.user = user;
  appState.sessionLoaded = true;

  if (!user) {
    setCartCount(0);
    return null;
  }

  const cartItems = await fetchProtectedCollection("/api/cart");
  setCartItems(cartItems);
  return user;
}

export async function refreshSession() {
  return ensureSessionLoaded({ force: true });
}

export async function logoutUser() {
  const { response, data } = await requestJson("/api/logout", { method: "POST" });
  if (response.ok && data?.ok) {
    appState.user = null;
    appState.sessionLoaded = true;
    setCartCount(0);
  }

  return { response, data };
}

export function syncGreetingToastFromSession() {
  const greetingName = consumeLoginGreeting();
  if (!greetingName) {
    return;
  }

  if (greetingTimeoutId) {
    window.clearTimeout(greetingTimeoutId);
  }

  appState.loginGreeting = greetingName;
  greetingTimeoutId = window.setTimeout(() => {
    appState.loginGreeting = "";
  }, 2400);
}
