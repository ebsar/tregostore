<script setup>
import { computed, onBeforeUnmount, onMounted, ref, watch } from "vue";
import { useRoute } from "vue-router";
import { appState } from "../stores/app-state";

const VAPI_WIDGET_SCRIPT_URL = "https://unpkg.com/@vapi-ai/client-sdk-react/dist/embed/widget.umd.js";
const VAPI_WIDGET_SCRIPT_ID = "trego-vapi-widget-script";

let vapiWidgetScriptPromise;

const route = useRoute();
const widgetElement = ref(null);
const statusMessage = ref("");
const isScriptReady = ref(false);

const publicKey = String(import.meta.env.VITE_VAPI_PUBLIC_KEY || "").trim();
const assistantId = String(import.meta.env.VITE_VAPI_ASSISTANT_ID || "").trim();
const assistantLabel = String(import.meta.env.VITE_VAPI_ASSISTANT_LABEL || "Asistenti zanor TREGIO").trim();
const isConfigured = computed(() => Boolean(publicKey && assistantId));

const assistantOverrides = computed(() =>
  JSON.stringify({
    variableValues: {
      siteName: "TREGIO",
      currentPage: route.fullPath,
      visitorRole: String(appState.user?.role || "guest"),
      visitorName: String(appState.user?.fullName || "").trim(),
    },
  }),
);

function ensureVapiWidgetScript() {
  if (typeof window === "undefined") {
    return Promise.resolve();
  }

  if (window.customElements?.get("vapi-widget")) {
    return Promise.resolve();
  }

  if (vapiWidgetScriptPromise) {
    return vapiWidgetScriptPromise;
  }

  const existingScript = document.getElementById(VAPI_WIDGET_SCRIPT_ID);
  if (existingScript) {
    vapiWidgetScriptPromise = new Promise((resolve, reject) => {
      if (window.customElements?.get("vapi-widget")) {
        resolve();
        return;
      }

      existingScript.addEventListener("load", () => resolve(), { once: true });
      existingScript.addEventListener("error", () => reject(new Error("Vapi widget script failed to load.")), { once: true });
    });
    return vapiWidgetScriptPromise;
  }

  vapiWidgetScriptPromise = new Promise((resolve, reject) => {
    const script = document.createElement("script");
    script.id = VAPI_WIDGET_SCRIPT_ID;
    script.src = VAPI_WIDGET_SCRIPT_URL;
    script.async = true;
    script.type = "text/javascript";
    script.onload = () => resolve();
    script.onerror = () => reject(new Error("Vapi widget script failed to load."));
    document.head.appendChild(script);
  });

  return vapiWidgetScriptPromise;
}

function showStatus(message) {
  statusMessage.value = String(message || "").trim();
  if (!statusMessage.value) {
    return;
  }

  window.clearTimeout(showStatus.timeoutId);
  showStatus.timeoutId = window.setTimeout(() => {
    statusMessage.value = "";
  }, 5000);
}

showStatus.timeoutId = 0;

function handleWidgetError(event) {
  console.error("Vapi widget error", event?.detail || event);
  showStatus("Asistenti zanor nuk u hap. Kontrollo mikrofonin ose provo perseri.");
}

function handleCallStart() {
  statusMessage.value = "";
}

function attachWidgetEvents() {
  if (!widgetElement.value) {
    return;
  }

  widgetElement.value.addEventListener("error", handleWidgetError);
  widgetElement.value.addEventListener("call-start", handleCallStart);
}

function detachWidgetEvents() {
  if (!widgetElement.value) {
    return;
  }

  widgetElement.value.removeEventListener("error", handleWidgetError);
  widgetElement.value.removeEventListener("call-start", handleCallStart);
}

async function initializeWidget() {
  if (!isConfigured.value) {
    return;
  }

  try {
    await ensureVapiWidgetScript();
    isScriptReady.value = true;
    attachWidgetEvents();
  } catch (error) {
    console.error(error);
    showStatus("Asistenti zanor nuk u ngarkua.");
  }
}

watch(
  () => widgetElement.value,
  (nextElement, previousElement) => {
    if (previousElement) {
      previousElement.removeEventListener("error", handleWidgetError);
      previousElement.removeEventListener("call-start", handleCallStart);
    }

    if (nextElement && isScriptReady.value) {
      attachWidgetEvents();
    }
  },
);

onMounted(async () => {
  await initializeWidget();
});

onBeforeUnmount(() => {
  detachWidgetEvents();
  window.clearTimeout(showStatus.timeoutId);
});
</script>

<template>
  <Teleport to="body">
    <div v-if="isConfigured && isScriptReady" class="voice-assistant-shell" aria-live="polite">
      <div v-if="statusMessage" class="voice-assistant-status">
        {{ statusMessage }}
      </div>

      <vapi-widget
        ref="widgetElement"
        :public-key="publicKey"
        :assistant-id="assistantId"
        mode="voice"
        theme="light"
        position="bottom-right"
        size="compact"
        radius="large"
        base-color="#fffaf4"
        accent-color="#8f654d"
        button-base-color="#f5eee5"
        button-accent-color="#6a4632"
        :main-label="assistantLabel"
        start-button-text="Fillo biseden"
        end-button-text="Mbylle"
        empty-voice-message="Preke dhe fol me asistentin e TREGIO."
        require-consent="true"
        terms-content="Duke përdorur asistentin zanor, pranon që biseda mund të përpunohet nga ofruesi i voice assistant për të kthyer përgjigje dhe transkript."
        local-storage-key="trego_voice_assistant_consent"
        show-transcript="true"
        :assistant-overrides="assistantOverrides"
      ></vapi-widget>
    </div>
  </Teleport>
</template>
