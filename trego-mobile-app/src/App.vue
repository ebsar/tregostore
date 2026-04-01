<script setup lang="ts">
import { IonApp, IonRouterOutlet } from "@ionic/vue";
import { App as CapacitorApp } from "@capacitor/app";
import { computed, onMounted, onUnmounted, ref, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import AppBootSplash from "./components/AppBootSplash.vue";
import { useConnectivity } from "./composables/useConnectivity";
import { ensurePushClient, requestPushPermissionIfNeeded, syncPushIdentity } from "./lib/push";
import { ensureSession, refreshCounts, refreshSession, sessionState } from "./stores/session";

const route = useRoute();
const router = useRouter();
const { isOnline, isConnectionUnstable } = useConnectivity();
const resumeListener = ref<{ remove: () => Promise<void> } | null>(null);
const bootSplashVisible = ref(true);
const bannerLabel = computed(() => {
  if (!isOnline.value) {
    return "Pa lidhje me internetin";
  }

  if (isConnectionUnstable.value) {
    return "Lidhja po rikthehet";
  }

  if (!sessionState.sessionLoaded) {
    return "Po lidhet me llogarine";
  }

  return "";
});
const showStatusBanner = computed(() => Boolean(bannerLabel.value));
const allowSwipeBack = computed(() => !String(route.path || "").startsWith("/tabs/"));
const edgeSwipe = {
  active: false,
  startX: 0,
  startY: 0,
  lastBackAt: 0,
};

function handleEdgeTouchStart(event: TouchEvent) {
  if (!allowSwipeBack.value || event.touches.length !== 1) {
    edgeSwipe.active = false;
    return;
  }

  const touch = event.touches[0];
  if (!touch || touch.clientX > 28) {
    edgeSwipe.active = false;
    return;
  }

  edgeSwipe.active = true;
  edgeSwipe.startX = touch.clientX;
  edgeSwipe.startY = touch.clientY;
}

function handleEdgeTouchEnd(event: TouchEvent) {
  if (!edgeSwipe.active || !allowSwipeBack.value) {
    edgeSwipe.active = false;
    return;
  }

  edgeSwipe.active = false;
  const touch = event.changedTouches[0];
  if (!touch) {
    return;
  }

  const deltaX = touch.clientX - edgeSwipe.startX;
  const deltaY = Math.abs(touch.clientY - edgeSwipe.startY);
  const now = Date.now();
  if (deltaX < 96 || deltaY > 56 || now - edgeSwipe.lastBackAt < 420) {
    return;
  }

  if (typeof window !== "undefined" && window.history.length > 1) {
    edgeSwipe.lastBackAt = now;
    router.back();
  }
}

onMounted(async () => {
  void ensurePushClient(router);
  const minimumBootDelay = new Promise((resolve) => {
    window.setTimeout(resolve, 950);
  });
  const initialSessionPromise = ensureSession();
  void Promise.allSettled([initialSessionPromise, minimumBootDelay]).finally(() => {
    bootSplashVisible.value = false;
  });

  try {
    resumeListener.value = await CapacitorApp.addListener("appStateChange", async ({ isActive }) => {
      if (!isActive) {
        return;
      }

      await refreshSession();
      await refreshCounts();
    });
  } catch (error) {
    console.warn("App state listener unavailable", error);
  }

  if (typeof window !== "undefined") {
    window.addEventListener("touchstart", handleEdgeTouchStart, { passive: true });
    window.addEventListener("touchend", handleEdgeTouchEnd, { passive: true });
  }
});

onUnmounted(() => {
  void resumeListener.value?.remove();
  if (typeof window !== "undefined") {
    window.removeEventListener("touchstart", handleEdgeTouchStart);
    window.removeEventListener("touchend", handleEdgeTouchEnd);
  }
});

watch(
  () => [sessionState.user?.id || 0, sessionState.user?.role || "", sessionState.sessionLoaded, bootSplashVisible.value] as const,
  async ([userId, _userRole, sessionLoaded, splashVisible]) => {
    if (!sessionLoaded) {
      return;
    }

    await syncPushIdentity(sessionState.user, router);
    if (userId > 0 && !splashVisible) {
      await requestPushPermissionIfNeeded(false, router);
    }
  },
  { immediate: true },
);
</script>

<template>
  <IonApp>
    <Transition name="boot-splash">
      <AppBootSplash v-if="bootSplashVisible" />
    </Transition>

    <div
      v-if="showStatusBanner"
      class="app-status-banner"
      :class="{
        'is-offline': !isOnline,
        'is-loading': isOnline && !sessionState.sessionLoaded,
      }"
    >
      <span class="app-status-dot" />
      <span>{{ bannerLabel }}</span>
      <small>{{ route.meta?.tabLabel || "TREGO Mobile" }}</small>
    </div>
    <IonRouterOutlet :swipe-gesture="allowSwipeBack" />
  </IonApp>
</template>
