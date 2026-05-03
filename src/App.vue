<script setup>
import { computed, defineAsyncComponent, nextTick, onBeforeUnmount, onMounted, ref, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import CommerceHeader from "./components/CommerceHeader.vue";
import LoaderOverlay from "./components/LoaderOverlay.vue";
import LoginGreetingToast from "./components/LoginGreetingToast.vue";
import { applyDocumentSeo } from "./lib/seo";
import { appState, ensureSessionLoaded, syncGreetingToastFromSession } from "./stores/app-state";

const route = useRoute();
const router = useRouter();
let globalToastTimeoutId = 0;
const globalToastMessage = ref("");
const globalToastType = ref("success");
const globalToastActions = ref([]);
let lastGlobalToastKey = "";
let inlineSuccessObserver = null;
const inlineSuccessStatusMessages = new WeakMap();
let speedInsightsHandle = null;
let computeSpeedInsightsRoute = null;
const VoiceAssistantWidget = defineAsyncComponent(() => import("./components/VoiceAssistantWidget.vue"));
const ProductCompareTray = defineAsyncComponent(() => import("./components/ProductCompareTray.vue"));
const PushNotificationPrompt = defineAsyncComponent(() => import("./components/PushNotificationPrompt.vue"));
const SiteFooter = defineAsyncComponent(() => import("./components/SiteFooter.vue"));
const speedInsightsClientConfig = String(import.meta.env.VITE_VERCEL_OBSERVABILITY_CLIENT_CONFIG || "").trim();
const speedInsightsBasePath = String(import.meta.env.VITE_VERCEL_OBSERVABILITY_BASEPATH || "").trim();
const hasVoiceAssistantConfig = Boolean(
  String(import.meta.env.VITE_VAPI_PUBLIC_KEY || "").trim()
  && String(import.meta.env.VITE_VAPI_ASSISTANT_ID || "").trim(),
);
const deferredChromeReady = ref(false);
let cancelSessionWarmup = () => {};
let cancelDeferredChrome = () => {};
let cancelSpeedInsightsWarmup = () => {};
const CHROMELESS_AUTH_PAGE_KEYS = new Set([
  "login",
  "signup",
  "forgot-password",
  "verify-email",
  "change-password",
]);
const NOINDEX_PAGE_KEYS = new Set([
  "search",
  "login",
  "signup",
  "verify-email",
  "forgot-password",
  "change-password",
  "wishlist",
  "cart",
  "account",
  "personal-data",
  "addresses",
  "orders",
  "track-order",
  "refund-returns",
  "notifications",
  "business-orders",
  "admin-orders",
  "checkout-address",
  "payment-options",
  "order-success",
  "admin-products",
  "business-dashboard",
  "registered-businesses",
  "product-compare",
  "liquid-glass",
]);
const DEFAULT_ROUTE_DESCRIPTIONS = {
  home: "TREGIO eshte marketplace per biznese lokale me produkte publike, checkout te sigurt dhe porosi te gjurmueshme.",
  "product-detail": "Shiko detajet e produktit, cmimin, stokun, vleresimet dhe porosit me checkout te sigurt ne TREGIO.",
  "business-profile": "Shfleto profilin publik te biznesit, produktet aktive dhe informacionin kryesor te shitjes ne TREGIO.",
  businesses: "Shfleto bizneset publike ne TREGIO, profilet e tyre dhe produktet aktive ne marketplace.",
  search: "Kerko produkte dhe filtro katalogun sipas kategorise, markes dhe cmimit ne TREGIO.",
  "order-success": "Shiko konfirmimin e porosise, adresen e faturimit dhe permbledhjen finale pas pageses ne TREGIO.",
};

const isChromelessAuthPage = computed(() =>
  CHROMELESS_AUTH_PAGE_KEYS.has(String(route.meta.pageKey || "").trim()),
);
const showSiteFooter = computed(() =>
  !isChromelessAuthPage.value,
);
const showDeferredFooter = computed(() =>
  deferredChromeReady.value && showSiteFooter.value,
);
const showDeferredChrome = computed(() =>
  deferredChromeReady.value && !isChromelessAuthPage.value,
);
const showVoiceAssistant = computed(() =>
  showDeferredChrome.value && hasVoiceAssistantConfig,
);

watch(
  [() => route.fullPath, () => route.meta.title, () => route.meta.pageKey],
  ([fullPath, title, pageKey]) => {
    const normalizedPageKey = String(pageKey || "").trim();
    const canonicalPath = normalizedPageKey === "search" ? "/kerko" : String(fullPath || route.path || "/");
    applyDocumentSeo({
      title: String(title || "TREGIO"),
      description: DEFAULT_ROUTE_DESCRIPTIONS[normalizedPageKey] || "TREGIO marketplace per produkte, biznese lokale dhe porosi te menaxhuara ne nje vend.",
      canonicalPath,
      image: "/trego-logo.webp?v=20260410",
      robots: NOINDEX_PAGE_KEYS.has(normalizedPageKey) ? "noindex,nofollow" : "index,follow",
    });
  },
  { immediate: true },
);

watch(
  () => route.fullPath,
  () => {
    syncGreetingToastFromSession();
    updateSpeedInsightsRoute();
    nextTick(() => scanInlineSuccessStatuses());
  },
);

onMounted(() => {
  syncGreetingToastFromSession();
  cancelSessionWarmup = scheduleIdleTask(() => {
    void ensureSessionLoaded();
  }, 900);
  cancelDeferredChrome = scheduleIdleTask(() => {
    deferredChromeReady.value = true;
  }, 1200);
  cancelSpeedInsightsWarmup = scheduleIdleTask(() => {
    void initializeSpeedInsights();
  }, 1800);
  window.addEventListener("trego:toast", handleGlobalToastEvent);
  startInlineSuccessObserver();
  nextTick(() => scanInlineSuccessStatuses());
});

onBeforeUnmount(() => {
  window.removeEventListener("trego:toast", handleGlobalToastEvent);
  if (inlineSuccessObserver) {
    inlineSuccessObserver.disconnect();
    inlineSuccessObserver = null;
  }
  if (globalToastTimeoutId) {
    window.clearTimeout(globalToastTimeoutId);
    globalToastTimeoutId = 0;
  }
  cancelSessionWarmup();
  cancelDeferredChrome();
  cancelSpeedInsightsWarmup();
});

function scheduleIdleTask(callback, timeout = 1200) {
  if (typeof window === "undefined") {
    return () => {};
  }

  if (typeof window.requestIdleCallback === "function") {
    const idleId = window.requestIdleCallback(callback, { timeout });
    return () => window.cancelIdleCallback?.(idleId);
  }

  const timeoutId = window.setTimeout(callback, timeout);
  return () => window.clearTimeout(timeoutId);
}

function handleGlobalToastEvent(event) {
  const message = String(event?.detail?.message || "").trim();
  const type = String(event?.detail?.type || "success").trim() || "success";
  const actions = Array.isArray(event?.detail?.actions)
    ? event.detail.actions
      .map((action) => ({
        label: String(action?.label || "").trim(),
        to: action?.to ?? "",
      }))
      .filter((action) => action.label && action.to)
    : [];
  if (!message) {
    return;
  }

  const toastKey = `${type}:${message}:${actions.map((action) => action.label).join("|")}`;
  if (lastGlobalToastKey === toastKey) {
    return;
  }

  lastGlobalToastKey = toastKey;
  globalToastMessage.value = message;
  globalToastType.value = type;
  globalToastActions.value = actions;
  if (globalToastTimeoutId) {
    window.clearTimeout(globalToastTimeoutId);
  }
  const dismissDelay = type === "error" ? 5000 : actions.length > 0 ? 6500 : 3200;
  globalToastTimeoutId = window.setTimeout(() => {
    dismissGlobalToast();
  }, dismissDelay);
}

function dismissGlobalToast() {
  globalToastMessage.value = "";
  globalToastType.value = "success";
  globalToastActions.value = [];
  globalToastTimeoutId = 0;
  lastGlobalToastKey = "";
}

async function handleGlobalToastAction(action) {
  const target = action?.to;
  dismissGlobalToast();
  if (!target) {
    return;
  }

  await router.push(target);
}

function startInlineSuccessObserver() {
  if (typeof window === "undefined" || inlineSuccessObserver) {
    return;
  }

  inlineSuccessObserver = new MutationObserver(() => {
    scanInlineSuccessStatuses();
  });
  inlineSuccessObserver.observe(document.body, {
    childList: true,
    subtree: true,
    characterData: true,
  });
}

function scanInlineSuccessStatuses() {
  if (typeof document === "undefined") {
    return;
  }

  document.querySelectorAll(".market-status--success").forEach((element) => {
    const message = String(element.textContent || "").replace(/\s+/g, " ").trim();
    if (!message) {
      return;
    }

    if (inlineSuccessStatusMessages.get(element) === message) {
      return;
    }

    inlineSuccessStatusMessages.set(element, message);
    handleGlobalToastEvent(new CustomEvent("trego:toast", {
      detail: {
        message,
        type: "success",
      },
    }));
  });
}

async function initializeSpeedInsights() {
  if (typeof window === "undefined") {
    return;
  }

  try {
    const speedInsights = await import("@vercel/speed-insights");
    computeSpeedInsightsRoute = speedInsights.computeRoute;
    speedInsightsHandle = speedInsights.injectSpeedInsights(
      {
        framework: "vue",
        ...(speedInsightsBasePath ? { basePath: speedInsightsBasePath } : {}),
      },
      speedInsightsClientConfig || undefined,
    );
  } catch (error) {
    console.warn("Speed Insights could not be initialized.", error);
    return;
  }

  updateSpeedInsightsRoute();
}

function updateSpeedInsightsRoute() {
  if (!speedInsightsHandle || !computeSpeedInsightsRoute) {
    return;
  }

  speedInsightsHandle.setRoute?.(computeSpeedInsightsRoute(route.path, route.params));
}
</script>

<template>
  <LoaderOverlay v-if="appState.loaderVisible" />
  <LoginGreetingToast v-if="appState.loginGreeting && !isChromelessAuthPage" :message="appState.loginGreeting" />
  <div
    v-if="globalToastMessage && !isChromelessAuthPage"
    class="market-global-toast-screen"
    role="status"
    aria-live="polite"
    @click="dismissGlobalToast"
  >
    <div
      class="market-global-toast"
      :class="`market-global-toast--${globalToastType}`"
    >
      <p>
        {{ globalToastMessage }}
      </p>
      <div v-if="globalToastActions.length" class="market-global-toast__actions">
        <button
          v-for="action in globalToastActions"
          :key="`${action.label}:${String(action.to)}`"
          class="market-button market-button--secondary"
          type="button"
          @click="handleGlobalToastAction(action)"
        >
          {{ action.label }}
        </button>
      </div>
    </div>
  </div>
  <VoiceAssistantWidget v-if="showVoiceAssistant" />
  <ProductCompareTray v-if="showDeferredChrome" />
  <PushNotificationPrompt v-if="showDeferredChrome && appState.user" />

  <div class="market-app">
    <CommerceHeader v-if="!isChromelessAuthPage" />

    <div class="market-shell">
      <main class="market-main">
      <RouterView />
      </main>

      <SiteFooter v-if="showDeferredFooter" />
    </div>
  </div>
</template>

<style scoped>
.market-global-toast-screen {
  position: fixed;
  inset: 0;
  z-index: 9000;
  display: grid;
  place-items: center;
  padding: 24px;
  background: rgba(17, 17, 17, 0.08);
}

.market-global-toast {
  width: min(100%, 360px);
  padding: 18px 20px;
  border: 1px solid #eeeeee;
  border-radius: 16px;
  background: #ffffff;
  box-shadow: 0 18px 48px rgba(17, 17, 17, 0.12);
  color: #111111;
  text-align: center;
  animation: market-toast-pop 180ms ease-out;
}

.market-global-toast--success {
  border-top: 3px solid var(--color-primary);
}

.market-global-toast--error {
  border-top: 3px solid var(--color-error);
}

.market-global-toast p {
  margin: 0;
  color: inherit;
  font-size: 14px;
  font-weight: 600;
  line-height: 1.5;
}

.market-global-toast__actions {
  display: flex;
  justify-content: center;
  gap: 8px;
  margin-top: 14px;
}

@keyframes market-toast-pop {
  from {
    opacity: 0;
    transform: translateY(8px) scale(0.98);
  }

  to {
    opacity: 1;
    transform: translateY(0) scale(1);
  }
}
</style>
