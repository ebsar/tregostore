<script setup>
import { computed, onMounted, ref } from "vue";
import {
  detectPushPlatform,
  enableWebPushNotifications,
  getPushCapability,
  sendPushTestNotification,
} from "../lib/push-notifications";

const DISMISS_STORAGE_KEY = "trego-push-prompt-dismissed";

const isVisible = ref(false);
const isBusy = ref(false);
const isEnabled = ref(false);
const statusMessage = ref("");
const requiresInstall = ref(false);
const platform = ref(detectPushPlatform());

const titleText = computed(() => (requiresInstall.value ? "Enable on iPhone" : "Enable notifications"));
const bodyText = computed(() => {
  if (requiresInstall.value) {
    return "Open Share, then Add to Home Screen to receive real push notifications.";
  }
  if (isEnabled.value) {
    return "This device can receive order, message, and account alerts.";
  }
  return "Get order, message, and account alerts instantly.";
});

onMounted(async () => {
  try {
    if (window.localStorage.getItem(DISMISS_STORAGE_KEY) === "1") {
      return;
    }

    const capability = await getPushCapability();
    platform.value = capability;
    requiresInstall.value = Boolean(capability.requiresInstall);
    isEnabled.value = capability.permission === "granted" && capability.supported && capability.configured;
    isVisible.value = capability.requiresInstall || (capability.supported && capability.permission !== "denied" && !isEnabled.value);
  } catch {
    isVisible.value = false;
  }
});

function dismissPrompt() {
  try {
    window.localStorage.setItem(DISMISS_STORAGE_KEY, "1");
  } catch {
    // noop
  }
  isVisible.value = false;
}

async function enableNotifications() {
  isBusy.value = true;
  statusMessage.value = "";
  try {
    const result = await enableWebPushNotifications();
    requiresInstall.value = Boolean(result.requiresInstall);
    statusMessage.value = result.message || "";
    isEnabled.value = Boolean(result.ok);
    if (result.ok) {
      window.setTimeout(() => {
        isVisible.value = false;
      }, 1200);
    }
  } catch (error) {
    statusMessage.value = error?.message || "Njoftimet nuk u aktivizuan.";
  } finally {
    isBusy.value = false;
  }
}

async function sendTest() {
  isBusy.value = true;
  try {
    const result = await sendPushTestNotification();
    statusMessage.value = result.message || (result.ok ? "Test sent." : "Test failed.");
  } finally {
    isBusy.value = false;
  }
}
</script>

<template>
  <aside
    v-if="isVisible"
    class="push-prompt"
    aria-live="polite"
  >
    <div class="push-prompt__icon" aria-hidden="true">
      <svg viewBox="0 0 24 24" focusable="false">
        <path d="M12 22a2.5 2.5 0 0 0 2.45-2h-4.9A2.5 2.5 0 0 0 12 22Zm7-6V11a7 7 0 0 0-5-6.7V3a2 2 0 1 0-4 0v1.3A7 7 0 0 0 5 11v5l-1.4 1.4A1 1 0 0 0 4.3 19h15.4a1 1 0 0 0 .7-1.6L19 16Z" />
      </svg>
    </div>
    <div class="push-prompt__content">
      <strong>{{ titleText }}</strong>
      <span>{{ bodyText }}</span>
      <small v-if="statusMessage">{{ statusMessage }}</small>
    </div>
    <div class="push-prompt__actions">
      <button
        v-if="!requiresInstall && !isEnabled"
        class="push-prompt__primary"
        type="button"
        :disabled="isBusy"
        @click="enableNotifications"
      >
        {{ isBusy ? "..." : "Enable" }}
      </button>
      <button
        v-else-if="isEnabled"
        class="push-prompt__primary"
        type="button"
        :disabled="isBusy"
        @click="sendTest"
      >
        Test
      </button>
      <button
        class="push-prompt__ghost"
        type="button"
        :disabled="isBusy"
        @click="dismissPrompt"
      >
        Later
      </button>
    </div>
  </aside>
</template>

<style scoped>
.push-prompt {
  position: fixed;
  right: 18px;
  bottom: 18px;
  z-index: 8600;
  display: grid;
  grid-template-columns: 36px minmax(0, 1fr) auto;
  align-items: center;
  gap: 10px;
  width: min(calc(100vw - 24px), 420px);
  padding: 10px;
  border: 1px solid var(--color-primary-border);
  border-radius: 16px;
  background: rgba(255, 255, 255, 0.96);
  box-shadow: 0 18px 48px rgba(17, 17, 17, 0.14);
  color: #111111;
}

.push-prompt__icon {
  display: grid;
  width: 36px;
  height: 36px;
  place-items: center;
  border-radius: 12px;
  background: var(--color-primary-soft);
  color: var(--color-primary);
}

.push-prompt__icon svg {
  width: 18px;
  height: 18px;
  fill: currentColor;
}

.push-prompt__content {
  display: grid;
  gap: 2px;
  min-width: 0;
}

.push-prompt__content strong {
  font-size: 13px;
  line-height: 1.2;
}

.push-prompt__content span,
.push-prompt__content small {
  color: #5f6368;
  font-size: 12px;
  line-height: 1.35;
}

.push-prompt__actions {
  display: flex;
  gap: 6px;
}

.push-prompt__primary,
.push-prompt__ghost {
  min-height: 32px;
  padding: 0 12px;
  border-radius: 999px;
  font-size: 12px;
  font-weight: 700;
  cursor: pointer;
}

.push-prompt__primary {
  border: 1px solid var(--color-primary);
  background: var(--color-primary);
  color: #ffffff;
}

.push-prompt__ghost {
  border: 1px solid #eeeeee;
  background: #ffffff;
  color: #5f6368;
}

@media (max-width: 560px) {
  .push-prompt {
    right: 12px;
    bottom: 12px;
    grid-template-columns: 32px minmax(0, 1fr);
  }

  .push-prompt__actions {
    grid-column: 1 / -1;
    justify-content: flex-end;
  }
}
</style>
