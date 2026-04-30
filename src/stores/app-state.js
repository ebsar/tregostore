import { reactive, watch } from "vue";
import {
  APP_LOADER_MIN_DURATION_MS,
  calculateCartItemsCount,
  clearTrackedOrderLookup,
  consumeLoginGreeting,
} from "../lib/app-session";
import { queryClient } from "../lib/query-client";
import { queryKeys } from "../lib/query-keys";

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
const AUTH_INVALIDATION_LISTENER_KEY = "__tregioAuthInvalidationListenerBound__";
const AUTH_INVALIDATION_EVENT_NAME = "tregio:auth-invalidated";

function clearActiveSessionState({ clearTracking = false } = {}) {
  appState.user = null;
  appState.sessionLoaded = true;
  appState.cartCount = 0;
  
  // Clear TanStack Query Cache
  queryClient.clear();

  if (clearTracking) {
    clearTrackedOrderLookup();
  }
}

function handleAuthInvalidation() {
  clearActiveSessionState({ clearTracking: true });
}

if (
  typeof window !== "undefined"
  && !window[AUTH_INVALIDATION_LISTENER_KEY]
) {
  window[AUTH_INVALIDATION_LISTENER_KEY] = true;
  window.addEventListener(AUTH_INVALIDATION_EVENT_NAME, handleAuthInvalidation);
}

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

// Subscribe to Cart query to sync cartCount
queryClient.getQueryCache().subscribe((event) => {
  if (
    event?.query?.queryKey?.[0] === "cart" &&
    (event.type === "updated" || event.type === "removed")
  ) {
    const cartData = queryClient.getQueryData(queryKeys.cart.main());
    if (Array.isArray(cartData)) {
      setCartItems(cartData);
    } else if (cartData === null || cartData === undefined) {
      setCartCount(0);
    }
  }
});

export function bumpCatalogRevision() {
  appState.catalogRevision += 1;
}

async function fetchBusinessSessionData() {
  try {
    const { requestJson } = await import("../lib/api");
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

async function enrichBusinessUserSessionInBackground(user) {
  if (!user || user.role !== "business") {
    return;
  }

  const businessSessionData = await queryClient.fetchQuery({
    queryKey: queryKeys.user.profile(),
    queryFn: fetchBusinessSessionData,
    staleTime: Infinity,
  });

  if (!businessSessionData) {
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

async function setAuthenticatedUser(user) {
  if (!user) {
    appState.user = null;
    appState.sessionLoaded = true;
    setCartCount(0);
    return null;
  }

  appState.user = user;
  appState.sessionLoaded = true;

  // Prefetch cart
  if (user.role === "client") {
    void queryClient.prefetchQuery({
      queryKey: queryKeys.cart.main(),
      queryFn: async () => {
        const { fetchProtectedCollection } = await import("../lib/api");
        return fetchProtectedCollection("/api/cart");
      },
    });
  }

  if (user.role === "business") {
    void enrichBusinessUserSessionInBackground(user).catch((error) => {
      console.error(error);
    });
  }

  return user;
}

export async function applyAuthenticatedSession(user) {
  return setAuthenticatedUser(user);
}

export async function ensureSessionLoaded(options = {}) {
  const { force = false } = options;
  
  if (appState.sessionLoaded && !force) {
    return appState.user;
  }

  return queryClient.fetchQuery({
    queryKey: queryKeys.user.session(),
    queryFn: async () => {
      const { fetchCurrentUserSession } = await import("../lib/api");
      const currentSession = await fetchCurrentUserSession();
      
      if (currentSession.status === "unreachable") {
         appState.sessionLoaded = true;
         return appState.user;
      }

      return setAuthenticatedUser(currentSession.user);
    },
    staleTime: force ? 0 : Infinity,
  });
}

export async function refreshSession() {
  return ensureSessionLoaded({ force: true });
}

export async function logoutUser() {
  const { clearDebugSessionToken, requestJson } = await import("../lib/api");
  const { response, data } = await requestJson("/api/logout", { method: "POST" });
  if ((response.ok && data?.ok) || response.status === 401 || response.status === 403) {
    clearActiveSessionState({ clearTracking: true });
    clearDebugSessionToken();
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
