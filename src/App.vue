<script setup>
import { computeRoute, injectSpeedInsights } from "@vercel/speed-insights";
import { computed, onBeforeUnmount, onMounted, ref, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import CommerceHeader from "./components/CommerceHeader.vue";
import LoaderOverlay from "./components/LoaderOverlay.vue";
import LoginGreetingToast from "./components/LoginGreetingToast.vue";
import ProductCompareTray from "./components/ProductCompareTray.vue";
import VoiceAssistantWidget from "./components/VoiceAssistantWidget.vue";
import { useScreenSafeArea } from "./composables/useScreenSafeArea";
import { appState, ensureSessionLoaded, syncGreetingToastFromSession } from "./stores/app-state";

const route = useRoute();
const router = useRouter();
let lockedScrollY = 0;
let globalToastTimeoutId = 0;
const globalToastMessage = ref("");
const globalToastType = ref("success");
const globalToastActions = ref([]);
let formMessageObserver = null;
const formMessageDismissTimers = new Map();
let lastGlobalToastKey = "";
let speedInsightsHandle = null;
const speedInsightsClientConfig = String(import.meta.env.VITE_VERCEL_OBSERVABILITY_CLIENT_CONFIG || "").trim();
const speedInsightsBasePath = String(import.meta.env.VITE_VERCEL_OBSERVABILITY_BASEPATH || "").trim();
const safeArea = useScreenSafeArea();
let sessionWarmupTimeoutId = 0;

const shellClass = computed(() => route.meta.shellClass || "page-shell");
const mainClass = computed(() => route.meta.mainClass || "page-main");
const showSiteFooter = computed(() =>
  !["login", "signup", "verify-email"].includes(String(route.meta.pageKey || "").trim()),
);

watch(
  () => route.meta.pageKey,
  (pageKey) => {
    if (pageKey) {
      document.body.dataset.page = String(pageKey);
    } else {
      delete document.body.dataset.page;
    }
    document.body.classList.remove("dialog-open");
  },
  { immediate: true },
);

watch(
  () => route.meta.title,
  (title) => {
    document.title = String(title || "TREGIO");
  },
  { immediate: true },
);

watch(
  () => route.fullPath,
  () => {
    syncGreetingToastFromSession();
    updateSpeedInsightsRoute();
  },
);

watch(
  [safeArea.top, safeArea.right, safeArea.bottom, safeArea.left],
  ([top, right, bottom, left]) => {
    if (typeof document === "undefined") {
      return;
    }

    const rootStyle = document.documentElement.style;
    rootStyle.setProperty("--safe-top-runtime", String(top || "0px"));
    rootStyle.setProperty("--safe-right-runtime", String(right || "0px"));
    rootStyle.setProperty("--safe-bottom-runtime", String(bottom || "0px"));
    rootStyle.setProperty("--safe-left-runtime", String(left || "0px"));
  },
  { immediate: true },
);

watch(
  () => appState.loaderVisible,
  (isVisible) => {
    if (isVisible) {
      lockedScrollY = window.scrollY || window.pageYOffset || 0;
      document.body.classList.add("app-loading");
      document.body.style.top = `-${lockedScrollY}px`;
      document.body.style.left = "0";
      document.body.style.right = "0";
      document.body.style.width = "100%";
      document.body.style.position = "fixed";
      return;
    }

    document.body.classList.remove("app-loading");
    document.body.style.position = "";
    document.body.style.top = "";
    document.body.style.left = "";
    document.body.style.right = "";
    document.body.style.width = "";
    window.scrollTo(0, lockedScrollY);
  },
  { immediate: true },
);

onMounted(() => {
  syncGreetingToastFromSession();
  sessionWarmupTimeoutId = window.setTimeout(() => {
    void ensureSessionLoaded();
  }, 180);
  initializeSpeedInsights();
  window.addEventListener("trego:toast", handleGlobalToastEvent);
  startFormMessageObserver();
});

onBeforeUnmount(() => {
  window.removeEventListener("trego:toast", handleGlobalToastEvent);
  stopFormMessageObserver();
  formMessageDismissTimers.forEach((timeoutId) => {
    window.clearTimeout(timeoutId);
  });
  formMessageDismissTimers.clear();
  if (globalToastTimeoutId) {
    window.clearTimeout(globalToastTimeoutId);
    globalToastTimeoutId = 0;
  }
  if (sessionWarmupTimeoutId) {
    window.clearTimeout(sessionWarmupTimeoutId);
    sessionWarmupTimeoutId = 0;
  }
  document.body.classList.remove("app-loading");
  document.body.style.position = "";
  document.body.style.top = "";
  document.body.style.left = "";
  document.body.style.right = "";
  document.body.style.width = "";
  if (typeof document !== "undefined") {
    const rootStyle = document.documentElement.style;
    rootStyle.removeProperty("--safe-top-runtime");
    rootStyle.removeProperty("--safe-right-runtime");
    rootStyle.removeProperty("--safe-bottom-runtime");
    rootStyle.removeProperty("--safe-left-runtime");
  }
});

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
  const dismissDelay = type === "error" ? 5000 : actions.length > 0 ? 6500 : 2800;
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

function triggerToastFromFormMessage(element) {
  if (!(element instanceof HTMLElement)) {
    return;
  }

  const message = String(element.textContent || "").trim();
  if (!message) {
    return;
  }

  const type = element.classList.contains("error")
    ? "error"
    : element.classList.contains("success")
      ? "success"
      : "info";

  handleGlobalToastEvent({
    detail: {
      message,
      type,
    },
  });

  scheduleFormMessageDismiss(element, type);
}

function scheduleFormMessageDismiss(element, type = "info") {
  if (!(element instanceof HTMLElement) || type === "success") {
    return;
  }

  const currentTimer = formMessageDismissTimers.get(element);
  if (currentTimer) {
    window.clearTimeout(currentTimer);
  }

  element.style.removeProperty("display");

  const timeoutId = window.setTimeout(() => {
    if (element.isConnected) {
      element.style.display = "none";
    }
    formMessageDismissTimers.delete(element);
  }, 5000);

  formMessageDismissTimers.set(element, timeoutId);
}

function scanVisibleFormMessages() {
  document.querySelectorAll(".form-message").forEach((element) => {
    triggerToastFromFormMessage(element);
  });
}

function handleFormMessageMutations(mutations = []) {
  let matchedElement = null;

  for (const mutation of mutations) {
    const targetElement = mutation.target instanceof HTMLElement
      ? mutation.target.closest(".form-message")
      : mutation.target?.parentElement?.closest?.(".form-message");

    if (targetElement) {
      matchedElement = targetElement;
      break;
    }

    if (mutation.type === "childList") {
      for (const node of mutation.addedNodes) {
        if (!(node instanceof HTMLElement)) {
          continue;
        }

        if (node.matches?.(".form-message")) {
          matchedElement = node;
          break;
        }

        const nestedElement = node.querySelector?.(".form-message");
        if (nestedElement) {
          matchedElement = nestedElement;
          break;
        }
      }
    }

    if (matchedElement) {
      break;
    }
  }

  if (matchedElement) {
    triggerToastFromFormMessage(matchedElement);
    return;
  }

  scanVisibleFormMessages();
}

function startFormMessageObserver() {
  if (typeof window === "undefined" || formMessageObserver) {
    return;
  }

  formMessageObserver = new MutationObserver(handleFormMessageMutations);
  formMessageObserver.observe(document.body, {
    subtree: true,
    childList: true,
    characterData: true,
  });
}

function stopFormMessageObserver() {
  formMessageObserver?.disconnect?.();
  formMessageObserver = null;
}

function initializeSpeedInsights() {
  if (typeof window === "undefined") {
    return;
  }

  speedInsightsHandle = injectSpeedInsights(
    {
      framework: "vue",
      ...(speedInsightsBasePath ? { basePath: speedInsightsBasePath } : {}),
    },
    speedInsightsClientConfig || undefined,
  );

  updateSpeedInsightsRoute();
}

function updateSpeedInsightsRoute() {
  speedInsightsHandle?.setRoute?.(computeRoute(route.path, route.params));
}
</script>

<template>
  <LoaderOverlay v-if="appState.loaderVisible" />
  <LoginGreetingToast v-if="appState.loginGreeting" :message="appState.loginGreeting" />
  <div
    v-if="globalToastMessage"
    class="global-feedback-toast is-visible"
    :class="`is-${globalToastType}`"
    role="status"
    aria-live="polite"
  >
    <p class="global-feedback-toast-message">
      {{ globalToastMessage }}
    </p>
    <div v-if="globalToastActions.length" class="global-feedback-toast-actions">
      <button
        v-for="action in globalToastActions"
        :key="`${action.label}:${String(action.to)}`"
        class="global-feedback-toast-action"
        type="button"
        @click="handleGlobalToastAction(action)"
      >
        {{ action.label }}
      </button>
    </div>
  </div>
  <VoiceAssistantWidget />
  <ProductCompareTray />

  <CommerceHeader />

  <div class="background-orb orb-left"></div>
  <div class="background-orb orb-right"></div>

  <div class="app-shell" :class="shellClass">
    <main class="app-main" :class="mainClass">
      <RouterView />
    </main>

    <footer v-if="showSiteFooter" class="site-footer" aria-label="Footer i faqes">
      <div class="site-footer-grid">
        <div class="site-footer-brand">
          <img class="site-footer-logo" src="/trego-logo.webp?v=20260410" alt="TREGIO" width="1024" height="1024">
        </div>

        <details class="site-footer-dropdown" open>
          <summary class="site-footer-heading">Marketplace</summary>
          <nav class="site-footer-links" aria-label="Marketplace links">
            <RouterLink to="/">Home</RouterLink>
            <RouterLink to="/kerko">Products</RouterLink>
            <RouterLink to="/bizneset-e-regjistruara">Businesses</RouterLink>
          </nav>
        </details>

        <details class="site-footer-dropdown" open>
          <summary class="site-footer-heading">Services</summary>
          <nav class="site-footer-links" aria-label="Services links">
            <RouterLink to="/cart">Cart</RouterLink>
            <RouterLink to="/porosite">Orders</RouterLink>
            <RouterLink to="/mesazhet">Support</RouterLink>
          </nav>
        </details>

        <nav class="site-footer-links site-footer-links--sparse" aria-label="Account links">
          <p class="site-footer-heading">Account</p>
          <RouterLink to="/login">Login</RouterLink>
          <RouterLink to="/signup">Sign Up</RouterLink>
        </nav>

        <nav class="site-footer-links site-footer-links--sparse" aria-label="More links">
          <p class="site-footer-heading">More</p>
          <RouterLink to="/njoftimet">Updates</RouterLink>
          <RouterLink to="/wishlist">Wishlist</RouterLink>
        </nav>
      </div>

      <div class="site-footer-divider" aria-hidden="true"></div>

      <div class="site-footer-bottom">
        <div class="site-footer-socials" aria-label="Footer social icons">
          <span class="site-footer-social-icon" aria-hidden="true">
            <svg viewBox="0 0 24 24">
              <path d="M13.5 21v-8h2.7l.4-3h-3.1V8.1c0-.9.3-1.6 1.7-1.6h1.5V3.8c-.3 0-1.2-.1-2.3-.1-2.3 0-3.8 1.4-3.8 4v2.3H8v3h2.6v8z" />
            </svg>
          </span>
          <span class="site-footer-social-icon" aria-hidden="true">
            <svg viewBox="0 0 24 24">
              <path d="M18.9 7.2c.7-.4 1.2-1 1.5-1.8-.6.4-1.4.7-2.1.8a3.5 3.5 0 0 0-6 3.2 9.9 9.9 0 0 1-7.2-3.6 3.5 3.5 0 0 0 1.1 4.7c-.6 0-1.1-.2-1.6-.4 0 1.7 1.2 3.1 2.8 3.4-.3.1-.7.1-1 .1-.2 0-.5 0-.7-.1.5 1.5 1.9 2.6 3.6 2.6A7.1 7.1 0 0 1 4 17.9a9.9 9.9 0 0 0 5.4 1.6c6.5 0 10.1-5.4 10.1-10.1v-.5c.7-.5 1.3-1.1 1.8-1.7-.7.3-1.4.5-2.1.6.7-.4 1.3-1 1.7-1.7-.7.4-1.5.7-2.3.9z" />
            </svg>
          </span>
          <span class="site-footer-social-icon" aria-hidden="true">
            <svg viewBox="0 0 24 24">
              <path d="M6.9 8.7a5.1 5.1 0 0 1 8.7-1.5l1.3-1.3v4.2h-4.2l1.5-1.5a3 3 0 1 0 .9 2.1h2.1a5.1 5.1 0 1 1-10.3 0c0-.3 0-.7.1-1zM17.1 15.3a5.1 5.1 0 0 1-8.7 1.5L7.1 18v-4.2h4.2l-1.5 1.5a3 3 0 1 0-.9-2.1H6.8a5.1 5.1 0 1 1 10.3 0c0 .3 0 .7-.1 1z" />
            </svg>
          </span>
          <span class="site-footer-social-icon" aria-hidden="true">
            <svg viewBox="0 0 24 24">
              <path d="M12 7.3a4.7 4.7 0 1 0 0 9.4 4.7 4.7 0 0 0 0-9.4zm0 7.7a3 3 0 1 1 0-6.1 3 3 0 0 1 0 6.1zm5.9-7.9a1.1 1.1 0 1 1 0 2.2 1.1 1.1 0 0 1 0-2.2z" />
              <path d="M12 3.8c2.7 0 3 .1 4 .1 1 0 1.7.2 2.3.5.7.2 1.2.6 1.7 1.1.5.5.9 1 1.1 1.7.3.6.4 1.3.5 2.3.1 1 .1 1.3.1 4s-.1 3-.1 4c0 1-.2 1.7-.5 2.3-.2.7-.6 1.2-1.1 1.7-.5.5-1 .9-1.7 1.1-.6.3-1.3.4-2.3.5-1 .1-1.3.1-4 .1s-3-.1-4-.1c-1 0-1.7-.2-2.3-.5a4.7 4.7 0 0 1-1.7-1.1 4.7 4.7 0 0 1-1.1-1.7c-.3-.6-.4-1.3-.5-2.3-.1-1-.1-1.3-.1-4s.1-3 .1-4c0-1 .2-1.7.5-2.3.2-.7.6-1.2 1.1-1.7.5-.5 1-.9 1.7-1.1.6-.3 1.3-.4 2.3-.5 1-.1 1.3-.1 4-.1zm0-1.8c-2.7 0-3 .1-4.1.1-1.1 0-1.9.2-2.6.5-.8.3-1.6.7-2.2 1.4-.7.6-1.1 1.4-1.4 2.2-.3.7-.5 1.5-.5 2.6C1.1 10 1 10.3 1 13s.1 3 .1 4.1c0 1.1.2 1.9.5 2.6.3.8.7 1.6 1.4 2.2.6.7 1.4 1.1 2.2 1.4.7.3 1.5.5 2.6.5 1.1 0 1.4.1 4.1.1s3-.1 4.1-.1c1.1 0 1.9-.2 2.6-.5.8-.3 1.6-.7 2.2-1.4.7-.6 1.1-1.4 1.4-2.2.3-.7.5-1.5.5-2.6.1-1.1.1-1.4.1-4.1s0-3-.1-4.1c0-1.1-.2-1.9-.5-2.6-.3-.8-.7-1.6-1.4-2.2-.6-.7-1.4-1.1-2.2-1.4-.7-.3-1.5-.5-2.6-.5C15 2.1 14.7 2 12 2z" />
            </svg>
          </span>
        </div>
        <p class="site-footer-copyright">©Copyright. All rights reserved.</p>
      </div>
    </footer>
  </div>
</template>
