<script setup>
import { SpeedInsights } from "@vercel/speed-insights/vue";
import { computed, onBeforeUnmount, onMounted, ref, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import LoaderOverlay from "./components/LoaderOverlay.vue";
import LoginGreetingToast from "./components/LoginGreetingToast.vue";
import SiteNav from "./components/SiteNav.vue";
import VoiceAssistantWidget from "./components/VoiceAssistantWidget.vue";
import { appState, ensureSessionLoaded, syncGreetingToastFromSession } from "./stores/app-state";

const route = useRoute();
const router = useRouter();
let lockedScrollY = 0;
let globalToastTimeoutId = 0;
const globalToastMessage = ref("");
const globalToastType = ref("success");
const globalToastActions = ref([]);
let formMessageObserver = null;
let lastGlobalToastKey = "";

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
    document.title = String(title || "TREGO");
  },
  { immediate: true },
);

watch(
  () => route.fullPath,
  () => {
    syncGreetingToastFromSession();
  },
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
  void ensureSessionLoaded();
  window.addEventListener("trego:toast", handleGlobalToastEvent);
  startFormMessageObserver();
});

onBeforeUnmount(() => {
  window.removeEventListener("trego:toast", handleGlobalToastEvent);
  stopFormMessageObserver();
  if (globalToastTimeoutId) {
    window.clearTimeout(globalToastTimeoutId);
    globalToastTimeoutId = 0;
  }
  document.body.classList.remove("app-loading");
  document.body.style.position = "";
  document.body.style.top = "";
  document.body.style.left = "";
  document.body.style.right = "";
  document.body.style.width = "";
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
  const dismissDelay = actions.length > 0 ? 6500 : type === "error" ? 5000 : 2800;
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
  <SpeedInsights />

  <div class="background-orb orb-left"></div>
  <div class="background-orb orb-right"></div>

  <div :class="shellClass">
    <SiteNav />

    <main :class="mainClass">
      <RouterView />
    </main>

    <footer v-if="showSiteFooter" class="site-footer" aria-label="Footer i faqes">
      <div class="site-footer-grid">
        <div class="site-footer-brand">
          <img class="site-footer-logo" src="/trego-logo.png" alt="TREGO" width="420" height="159">
          <p class="site-footer-copy">
            TREGO lidh bizneset dhe bleresit ne nje eksperience te paster, moderne dhe te shpejte.
          </p>
        </div>

        <nav class="site-footer-links" aria-label="Lidhjet e footer-it">
          <RouterLink to="/">Ballina</RouterLink>
          <RouterLink to="/kerko">Produktet</RouterLink>
          <RouterLink to="/wishlist">Wishlist</RouterLink>
          <RouterLink to="/cart">Cart</RouterLink>
        </nav>

        <div class="site-footer-meta">
          <p class="site-footer-note">Blerje me stil. Biznese me prezence te forte.</p>
          <p class="site-footer-note">© TREGO</p>
        </div>
      </div>
    </footer>
  </div>
</template>
