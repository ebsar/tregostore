<script setup lang="ts">
import { Capacitor } from "@capacitor/core";
import {
  IonIcon,
  IonLabel,
  IonRouterOutlet,
  IonTabBar,
  IonTabButton,
  IonTabs,
} from "@ionic/vue";
import { cartOutline, heartOutline, homeOutline, personCircleOutline, searchOutline } from "ionicons/icons";
import { computed, onMounted, onUnmounted } from "vue";
import { activityBadgeCount, sessionState } from "../stores/session";

const cartBadge = computed(() => (sessionState.cartCount > 0 ? String(sessionState.cartCount) : ""));
const wishlistBadge = computed(() => (sessionState.wishlistCount > 0 ? String(sessionState.wishlistCount) : ""));
const isNativeIOS = Capacitor.isNativePlatform() && Capacitor.getPlatform() === "ios";
const activityBadge = computed(() => {
  const total = Math.max(0, Number(activityBadgeCount.value || 0));
  if (total <= 0) {
    return "";
  }
  return total > 99 ? "99+" : String(total);
});

onMounted(() => {
  if (typeof document !== "undefined") {
    document.body.dataset.mobileTabbar = "1";
    if (isNativeIOS) {
      document.body.dataset.nativeIosSwiftuiTabbar = "1";
    }
  }
});

onUnmounted(() => {
  if (typeof document !== "undefined") {
    delete document.body.dataset.mobileTabbar;
    if (isNativeIOS) {
      delete document.body.dataset.nativeIosSwiftuiTabbar;
    }
  }
});
</script>

<template>
  <IonTabs>
    <IonRouterOutlet />

    <IonTabBar v-show="!isNativeIOS" slot="bottom" class="mobile-tabbar">
      <IonTabButton tab="home" href="/tabs/home">
        <IonIcon :icon="homeOutline" />
        <IonLabel>Home</IonLabel>
      </IonTabButton>
      <IonTabButton tab="search" href="/tabs/search">
        <IonIcon :icon="searchOutline" />
        <IonLabel>Kerko</IonLabel>
      </IonTabButton>
      <IonTabButton tab="wishlist" href="/tabs/wishlist">
        <IonIcon :icon="heartOutline" />
        <IonLabel>Wishlist</IonLabel>
        <span v-if="wishlistBadge" class="mobile-tabbar-badge">{{ wishlistBadge }}</span>
      </IonTabButton>
      <IonTabButton tab="cart" href="/tabs/cart">
        <IonIcon :icon="cartOutline" />
        <IonLabel>Cart</IonLabel>
        <span v-if="cartBadge" class="mobile-tabbar-badge">{{ cartBadge }}</span>
      </IonTabButton>
      <IonTabButton tab="account" href="/tabs/account">
        <IonIcon :icon="personCircleOutline" />
        <IonLabel>Llogaria</IonLabel>
        <span v-if="activityBadge" class="mobile-tabbar-badge">{{ activityBadge }}</span>
      </IonTabButton>
    </IonTabBar>
  </IonTabs>
</template>

<style scoped>
.mobile-tabbar {
  position: fixed;
  left: 50%;
  right: auto;
  bottom: 10px;
  transform: translateX(-50%);
  box-sizing: border-box;
  display: flex;
  align-items: stretch;
  justify-content: center;
  overflow: hidden;
  margin: 0;
  width: calc(100vw - 20px - env(safe-area-inset-left, 0px) - env(safe-area-inset-right, 0px));
  max-width: 540px;
  min-height: 72px;
  padding: 8px 10px calc(env(safe-area-inset-bottom, 0px) + 8px);
  border-radius: 30px;
  border: 1px solid rgba(255, 255, 255, 0.6);
  --background: transparent;
  z-index: 40;
  background:
    linear-gradient(180deg, rgba(255, 255, 255, 0.24), rgba(255, 255, 255, 0.08)),
    radial-gradient(circle at 50% -8%, rgba(255, 255, 255, 0.34), transparent 38%),
    radial-gradient(circle at 12% 10%, rgba(255, 255, 255, 0.16), transparent 18%),
    radial-gradient(circle at 88% 12%, rgba(255, 255, 255, 0.14), transparent 18%);
  box-shadow:
    0 18px 38px rgba(31, 41, 55, 0.14),
    inset 0 1px 0 rgba(255, 255, 255, 0.82),
    inset 0 -14px 22px rgba(255, 255, 255, 0.04);
  backdrop-filter: blur(26px) saturate(175%);
  -webkit-backdrop-filter: blur(26px) saturate(175%);
}

.mobile-tabbar::before {
  content: "";
  position: absolute;
  inset: 1px;
  border-radius: inherit;
  background:
    linear-gradient(180deg, rgba(255, 255, 255, 0.24), transparent 18%, rgba(255, 255, 255, 0) 100%),
    radial-gradient(circle at 15% 0%, rgba(255, 255, 255, 0.26), transparent 24%),
    radial-gradient(circle at 50% 100%, rgba(122, 195, 255, 0.1), transparent 36%);
  pointer-events: none;
}

.mobile-tabbar::after {
  content: "";
  position: absolute;
  inset: auto 16px 10px;
  height: 18px;
  border-radius: 999px;
  background: linear-gradient(90deg, rgba(89, 195, 255, 0.08), rgba(255, 255, 255, 0.18), rgba(255, 162, 214, 0.08));
  filter: blur(10px);
  pointer-events: none;
}

.mobile-tabbar :deep(.tabbar-background) {
  opacity: 0;
  background: transparent;
  border: 0;
}

.mobile-tabbar ion-tab-button {
  flex: 1 1 0;
  max-width: none;
  position: relative;
  border-radius: 24px;
  color: rgba(47, 52, 70, 0.62);
  --color-selected: var(--trego-dark);
  --ripple-color: transparent;
  min-height: 56px;
  --padding-top: 0;
  --padding-bottom: 0;
  --padding-start: 0;
  --padding-end: 0;
}

.mobile-tabbar ion-tab-button.tab-selected {
  background:
    linear-gradient(180deg, rgba(255, 255, 255, 0.46), rgba(255, 255, 255, 0.16)),
    radial-gradient(circle at 50% 0%, rgba(255, 255, 255, 0.38), transparent 44%);
  box-shadow:
    inset 0 1px 0 rgba(255, 255, 255, 0.9),
    0 10px 18px rgba(31, 41, 55, 0.08);
}

.mobile-tabbar ion-tab-button :deep(.button-native) {
  min-height: 54px;
  border-radius: 22px;
  padding: 5px 5px 4px;
}

.mobile-tabbar ion-tab-button :deep(.button-inner) {
  min-height: 42px;
  border-radius: 20px;
  padding: 0 8px;
  gap: 3px;
}

.mobile-tabbar ion-label {
  font-size: 0.67rem;
  font-weight: 700;
}

.mobile-tabbar ion-icon {
  font-size: 1.14rem;
}

.mobile-tabbar-badge {
  position: absolute;
  top: 7px;
  right: 18px;
  min-width: 18px;
  height: 18px;
  padding: 0 5px;
  border-radius: 999px;
  background: var(--trego-accent);
  color: var(--trego-badge-text);
  font-size: 0.66rem;
  font-weight: 800;
  line-height: 18px;
}

:global(body[data-platform="ios"]) .mobile-tabbar {
  bottom: calc(env(safe-area-inset-bottom, 0px) + 8px);
  width: calc(100vw - 22px - env(safe-area-inset-left, 0px) - env(safe-area-inset-right, 0px));
  max-width: 520px;
  min-height: 76px;
  padding: 8px 9px calc(env(safe-area-inset-bottom, 0px) + 8px);
  border-radius: 34px;
  border-color: rgba(255, 255, 255, 0.62);
  background:
    linear-gradient(180deg, rgba(255, 255, 255, 0.34), rgba(255, 255, 255, 0.08)),
    radial-gradient(circle at 50% -18%, rgba(255, 255, 255, 0.48), transparent 42%),
    radial-gradient(circle at 0% 46%, rgba(153, 224, 255, 0.14), transparent 30%),
    radial-gradient(circle at 100% 46%, rgba(255, 186, 219, 0.14), transparent 30%),
    linear-gradient(90deg, rgba(126, 217, 255, 0.06), rgba(255, 255, 255, 0.12), rgba(255, 186, 219, 0.06));
  box-shadow:
    0 28px 54px rgba(31, 41, 55, 0.14),
    inset 0 1px 0 rgba(255, 255, 255, 0.92),
    inset 0 -18px 26px rgba(255, 255, 255, 0.05);
  backdrop-filter: blur(34px) saturate(210%);
  -webkit-backdrop-filter: blur(34px) saturate(210%);
}

:global(body[data-platform="ios"]) .mobile-tabbar::before {
  background:
    linear-gradient(180deg, rgba(255, 255, 255, 0.3), transparent 18%, rgba(255, 255, 255, 0) 100%),
    radial-gradient(circle at 12% 0%, rgba(255, 255, 255, 0.3), transparent 22%),
    radial-gradient(circle at 50% 100%, rgba(122, 195, 255, 0.14), transparent 36%),
    radial-gradient(circle at 100% 100%, rgba(255, 176, 216, 0.12), transparent 34%);
}

:global(body[data-platform="ios"]) .mobile-tabbar::after {
  inset: auto 18px 12px;
  height: 20px;
  background: linear-gradient(90deg, rgba(89, 195, 255, 0.12), rgba(255, 255, 255, 0.22), rgba(255, 162, 214, 0.12));
  filter: blur(12px);
}

:global(body[data-platform="ios"]) .mobile-tabbar ion-tab-button {
  min-height: 58px;
  border-radius: 26px;
  color: rgba(47, 52, 70, 0.64);
}

:global(body[data-platform="ios"]) .mobile-tabbar ion-tab-button :deep(.button-native) {
  min-height: 56px;
  border-radius: 24px;
}

:global(body[data-platform="ios"]) .mobile-tabbar ion-tab-button :deep(.button-inner) {
  min-height: 46px;
  border-radius: 22px;
  gap: 4px;
}

:global(body[data-platform="ios"]) .mobile-tabbar ion-tab-button.tab-selected {
  background:
    linear-gradient(180deg, rgba(255, 255, 255, 0.58), rgba(255, 255, 255, 0.18)),
    radial-gradient(circle at 50% 0%, rgba(255, 255, 255, 0.48), transparent 46%);
  box-shadow:
    inset 0 1px 0 rgba(255, 255, 255, 0.94),
    0 12px 22px rgba(31, 41, 55, 0.08);
}

:global(body[data-platform="ios"]) .mobile-tabbar ion-label {
  font-size: 0.66rem;
  font-weight: 800;
}

:global(body[data-platform="ios"]) .mobile-tabbar ion-icon {
  font-size: 1.18rem;
}

body[data-theme="dark"] .mobile-tabbar {
  border-color: rgba(255, 255, 255, 0.12);
  background:
    linear-gradient(180deg, rgba(18, 18, 20, 0.82), rgba(10, 10, 12, 0.42)),
    radial-gradient(circle at 50% 0%, rgba(255, 255, 255, 0.08), transparent 36%),
    radial-gradient(circle at 0% 40%, rgba(122, 195, 255, 0.08), transparent 30%),
    radial-gradient(circle at 100% 42%, rgba(255, 162, 214, 0.08), transparent 30%);
}

body[data-theme="dark"] .mobile-tabbar ion-tab-button {
  color: rgba(237, 242, 247, 0.64);
}

body[data-theme="dark"] .mobile-tabbar ion-tab-button.tab-selected {
  background:
    linear-gradient(180deg, rgba(255, 255, 255, 0.1), rgba(255, 255, 255, 0.04)),
    radial-gradient(circle at 50% 0%, rgba(255, 255, 255, 0.08), transparent 42%);
}
</style>
