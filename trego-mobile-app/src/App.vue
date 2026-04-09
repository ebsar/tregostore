<script setup lang="ts">
import { IonApp, IonRouterOutlet } from "@ionic/vue";
import { App as CapacitorApp } from "@capacitor/app";
import { Capacitor } from "@capacitor/core";
import { Keyboard, KeyboardResize } from "@capacitor/keyboard";
import { computed, onMounted, onUnmounted, ref, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import AppBootSplash from "./components/AppBootSplash.vue";
import { useConnectivity } from "./composables/useConnectivity";
import { ensurePushClient, requestPushPermissionIfNeeded, syncPushIdentity } from "./lib/push";
import { activityBadgeCount, ensureSession, refreshCounts, refreshSession, sessionState } from "./stores/session";

const route = useRoute();
const router = useRouter();
const { isOnline, isConnectionUnstable } = useConnectivity();
const isNativeIOS = Capacitor.isNativePlatform() && Capacitor.getPlatform() === "ios";
const useNativeIOSTabShell = false;
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

function normalizeBadge(value: number | string | null | undefined) {
  const total = Math.max(0, Number(value || 0));
  if (total <= 0) {
    return "";
  }

  return total > 99 ? "99+" : String(total);
}

function resolveTabId(path: string) {
  if (path.startsWith("/tabs/home")) {
    return "home";
  }

  if (path.startsWith("/tabs/search")) {
    return "kerko";
  }

  if (path.startsWith("/tabs/wishlist")) {
    return "wishlist";
  }

  if (path.startsWith("/tabs/cart")) {
    return "cart";
  }

  if (path.startsWith("/tabs/account")) {
    return "llogaria";
  }

  return "";
}

function postNativeTabState() {
  if (!useNativeIOSTabShell || !isNativeIOS || typeof window === "undefined") {
    return;
  }

  const handler = (window as any)?.webkit?.messageHandlers?.tregoTabState;
  if (!handler || typeof handler.postMessage !== "function") {
    return;
  }

  const selectedTab = resolveTabId(route.path);
  handler.postMessage({
    currentPath: route.fullPath,
    selectedTab,
    showTabBar: !bootSplashVisible.value && route.path.startsWith("/tabs/"),
    badges: {
      wishlist: normalizeBadge(sessionState.wishlistCount),
      cart: normalizeBadge(sessionState.cartCount),
      llogaria: normalizeBadge(activityBadgeCount.value),
    },
  });
}

function navigateFromNative(path: string) {
  if (!path || route.fullPath === path || route.path === path) {
    return;
  }

  void router.push(path);
}

function handleNativeTabNavigate(event: Event) {
  const path = (event as CustomEvent<{ path?: string }>).detail?.path || "";
  navigateFromNative(path);
}

onMounted(async () => {
  void ensurePushClient(router);
  const minimumBootDelay = new Promise((resolve) => {
    window.setTimeout(resolve, 460);
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

  if (isNativeIOS) {
    try {
      await Keyboard.setResizeMode({ mode: KeyboardResize.None });
    } catch (error) {
      console.warn("Keyboard resize mode unavailable", error);
    }
  }

  if (typeof window !== "undefined") {
    window.addEventListener("touchstart", handleEdgeTouchStart, { passive: true });
    window.addEventListener("touchend", handleEdgeTouchEnd, { passive: true });
    if (isNativeIOS && useNativeIOSTabShell) {
      window.addEventListener("trego:native-tab-navigate", handleNativeTabNavigate as EventListener);
      (window as any).__tregoNativeNavigateTo = navigateFromNative;
      document.documentElement.dataset.iosNativeTabs = "1";
      document.body.dataset.iosNativeTabs = "1";
      postNativeTabState();
    } else if (isNativeIOS) {
      delete document.documentElement.dataset.iosNativeTabs;
      delete document.body.dataset.iosNativeTabs;
    }
  }
});

onUnmounted(() => {
  void resumeListener.value?.remove();
  if (typeof window !== "undefined") {
    window.removeEventListener("touchstart", handleEdgeTouchStart);
    window.removeEventListener("touchend", handleEdgeTouchEnd);
    if (isNativeIOS && useNativeIOSTabShell) {
      window.removeEventListener("trego:native-tab-navigate", handleNativeTabNavigate as EventListener);
      delete (window as any).__tregoNativeNavigateTo;
      delete document.documentElement.dataset.iosNativeTabs;
      delete document.body.dataset.iosNativeTabs;
    }
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

watch(
  () => [
    route.fullPath,
    sessionState.wishlistCount,
    sessionState.cartCount,
    activityBadgeCount.value,
    bootSplashVisible.value,
  ] as const,
  () => {
    postNativeTabState();
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
      <small>{{ route.meta?.tabLabel || "TREGIO Mobile" }}</small>
    </div>
    <IonRouterOutlet :swipe-gesture="allowSwipeBack" />
  </IonApp>
</template>
