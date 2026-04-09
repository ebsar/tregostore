import { reactive } from "vue";
import { fetchCurrentUserSession, fetchProtectedCollection, requestJson } from "../lib/api";
import {
  APP_LOADER_MIN_DURATION_MS,
  calculateCartItemsCount,
  consumeLoginGreeting,
} from "../lib/shop";

export const appState = reactive({
  user: null,
  sessionLoaded: false,
  cartCount: 0,
  catalogRevision: 0,
  loaderVisible: true,
  loaderStartedAt: Date.now(),
  loginGreeting: "",
});

let routeLoaderToken = 0;
let greetingTimeoutId = 0;
let sessionLoadPromise = null;
let cartWarmupPromise = null;
let sessionLoadRequestId = 0;
let sessionEnrichmentRequestId = 0;

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

async function warmCartForActiveSession(user) {
  if (!user || user.role !== "client") {
    setCartCount(0);
    return;
  }

  if (cartWarmupPromise) {
    return cartWarmupPromise;
  }

  const nextCartWarmupPromise = (async () => {
    const cartItems = await fetchProtectedCollection("/api/cart");
    setCartItems(cartItems);
  })();

  cartWarmupPromise = nextCartWarmupPromise;

  try {
    await nextCartWarmupPromise;
  } finally {
    if (cartWarmupPromise === nextCartWarmupPromise) {
      cartWarmupPromise = null;
    }
  }
}

export function bumpCatalogRevision() {
  appState.catalogRevision += 1;
}

async function fetchBusinessSessionData() {
  try {
    const { response, data } = await requestJson("/api/business-profile");
    if (!response.ok || !data?.ok || !data.profile) {
      return null;
    }

    return {
      businessName: String(data.profile.businessName || "").trim(),
      businessLogoPath: String(data.profile.logoPath || "").trim(),
      businessProfileUrl: String(data.profile.publicProfileUrl || "").trim(),
    };
  } catch (error) {
    console.error(error);
    return null;
  }
}

async function enrichBusinessUserSessionInBackground(user, requestId) {
  if (!user || user.role !== "business") {
    return;
  }

  const businessSessionData = await fetchBusinessSessionData();
  if (!businessSessionData || requestId !== sessionEnrichmentRequestId) {
    return;
  }

  if (!appState.user || Number(appState.user.id) !== Number(user.id) || appState.user.role !== "business") {
    return;
  }

  appState.user = {
    ...appState.user,
    ...businessSessionData,
  };
}

function setAuthenticatedUser(user) {
  sessionEnrichmentRequestId += 1;
  const enrichmentRequestId = sessionEnrichmentRequestId;

  if (!user) {
    appState.user = null;
    appState.sessionLoaded = true;
    setCartCount(0);
    return null;
  }

  appState.user = user;
  appState.sessionLoaded = true;
  void warmCartForActiveSession(user).catch((error) => {
    console.error(error);
  });

  if (user.role === "business") {
    void enrichBusinessUserSessionInBackground(user, enrichmentRequestId).catch((error) => {
      console.error(error);
    });
  }

  return user;
}

export async function applyAuthenticatedSession(user) {
  return setAuthenticatedUser(user);
}

export async function ensureSessionLoaded(options = {}) {
  const { force = false, preserveAuthenticatedUser = true } = options;
  if (appState.sessionLoaded && !force) {
    return appState.user;
  }

  if (sessionLoadPromise && !force) {
    return sessionLoadPromise;
  }

  const nextSessionLoadPromise = (async () => {
    const requestId = ++sessionLoadRequestId;
    const currentSession = await fetchCurrentUserSession();
    if (requestId !== sessionLoadRequestId) {
      return appState.user;
    }

    if (currentSession.status === "unreachable") {
      if (preserveAuthenticatedUser && appState.user) {
        appState.sessionLoaded = true;
        return appState.user;
      }

      return setAuthenticatedUser(null);
    }

    return setAuthenticatedUser(currentSession.user);
  })();

  sessionLoadPromise = nextSessionLoadPromise;

  try {
    return await nextSessionLoadPromise;
  } finally {
    if (sessionLoadPromise === nextSessionLoadPromise) {
      sessionLoadPromise = null;
    }
  }
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
