<script setup lang="ts">
import { IonIcon, IonRouterOutlet, IonTabs } from "@ionic/vue";
import { cartOutline, heartOutline, homeOutline, personCircleOutline, searchOutline } from "ionicons/icons";
import { computed } from "vue";
import { useRoute, useRouter } from "vue-router";
import { activityBadgeCount, sessionState } from "../stores/session";

type TabShellItem = {
  key: "home" | "wishlist" | "cart" | "llogaria" | "kerko";
  label: string;
  icon: string;
  path: string;
};

const route = useRoute();
const router = useRouter();

const groupedTabs: TabShellItem[] = [
  { key: "home", label: "Home", icon: homeOutline, path: "/tabs/home" },
  { key: "wishlist", label: "Wishlist", icon: heartOutline, path: "/tabs/wishlist" },
  { key: "cart", label: "Cart", icon: cartOutline, path: "/tabs/cart" },
  { key: "llogaria", label: "Llogaria", icon: personCircleOutline, path: "/tabs/account" },
];

const searchTab: TabShellItem = {
  key: "kerko",
  label: "Kerko",
  icon: searchOutline,
  path: "/tabs/search",
};

const cartBadge = computed(() => (sessionState.cartCount > 0 ? String(sessionState.cartCount) : ""));
const wishlistBadge = computed(() => (sessionState.wishlistCount > 0 ? String(sessionState.wishlistCount) : ""));
const activityBadge = computed(() => {
  const total = Math.max(0, Number(activityBadgeCount.value || 0));
  if (total <= 0) {
    return "";
  }
  return total > 99 ? "99+" : String(total);
});

const badgeMap = computed<Record<string, string>>(() => ({
  wishlist: wishlistBadge.value,
  cart: cartBadge.value,
  llogaria: activityBadge.value,
}));

const usesNativeIOSTabs = computed(
  () => typeof document !== "undefined" && document.body.dataset.iosNativeTabs === "1",
);

const activeTab = computed<TabShellItem["key"]>(() => {
  const path = String(route.path || "");
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
  return "home";
});

const activeGroupIndex = computed(() => {
  const index = groupedTabs.findIndex((item) => item.key === activeTab.value);
  return index >= 0 ? index : 0;
});

function navigateTo(path: string) {
  if (route.fullPath === path || route.path === path) {
    return;
  }
  void router.push(path);
}
</script>

<template>
  <IonTabs>
    <IonRouterOutlet />

    <nav v-if="!usesNativeIOSTabs" class="mobile-tabbar-shell" aria-label="Primary">
      <div class="mobile-tabbar-group">
        <div class="mobile-tabbar-selection" :style="{ '--tab-index': String(activeGroupIndex) }" />

        <button
          v-for="item in groupedTabs"
          :key="item.key"
          class="mobile-tabbar-button"
          :class="{ 'is-active': activeTab === item.key }"
          type="button"
          @click="navigateTo(item.path)"
        >
          <span
            v-if="badgeMap[item.key]"
            class="mobile-tabbar-badge"
          >
            {{ badgeMap[item.key] }}
          </span>
          <IonIcon :icon="item.icon" />
          <span>{{ item.label }}</span>
        </button>
      </div>

      <button
        class="mobile-tabbar-search"
        :class="{ 'is-active': activeTab === searchTab.key }"
        type="button"
        @click="navigateTo(searchTab.path)"
        :aria-label="searchTab.label"
      >
        <span class="mobile-tabbar-search-inner">
          <IonIcon :icon="searchTab.icon" />
        </span>
      </button>
    </nav>
  </IonTabs>
</template>

<style scoped>
.mobile-tabbar-shell {
  position: fixed;
  left: 50%;
  bottom: 10px;
  z-index: 40;
  display: flex;
  align-items: center;
  gap: 5px;
  width: calc(100vw - 20px - env(safe-area-inset-left, 0px) - env(safe-area-inset-right, 0px));
  max-width: 540px;
  transform: translateX(-50%);
}

.mobile-tabbar-group,
.mobile-tabbar-search {
  position: relative;
  isolation: isolate;
  overflow: hidden;
  border-radius: 999px;
  border: 1px solid rgba(255, 255, 255, 0.6);
  background:
    linear-gradient(180deg, rgba(255, 255, 255, 0.24), rgba(255, 255, 255, 0.09)),
    radial-gradient(circle at 50% -4%, rgba(255, 255, 255, 0.28), transparent 42%),
    radial-gradient(circle at 14% 12%, rgba(255, 255, 255, 0.14), transparent 18%);
  box-shadow:
    0 10px 20px rgba(31, 41, 55, 0.08),
    inset 0 1px 0 rgba(255, 255, 255, 0.8);
  backdrop-filter: none;
  -webkit-backdrop-filter: none;
}

.mobile-tabbar-group::before,
.mobile-tabbar-search::before {
  content: "";
  position: absolute;
  inset: 1px;
  border-radius: inherit;
  background:
    linear-gradient(180deg, rgba(255, 255, 255, 0.18), rgba(255, 255, 255, 0.05)),
    radial-gradient(circle at 18% 0%, rgba(255, 255, 255, 0.18), transparent 26%);
  pointer-events: none;
}

.mobile-tabbar-group {
  flex: 1 1 auto;
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  min-height: 62px;
  padding: 4px;
  overflow: hidden;
}

.mobile-tabbar-selection {
  position: absolute;
  top: 4px;
  bottom: 4px;
  left: 4px;
  width: calc((100% - 8px) / 4);
  border-radius: 999px;
  background:
    linear-gradient(180deg, rgba(255, 255, 255, 0.4), rgba(255, 255, 255, 0.14)),
    radial-gradient(circle at 50% 0%, rgba(255, 255, 255, 0.34), transparent 52%);
  box-shadow:
    inset 0 1px 0 rgba(255, 255, 255, 0.88),
    0 6px 14px rgba(31, 41, 55, 0.05);
  transform: translateX(calc(var(--tab-index, 0) * 100%));
  transition: transform 300ms cubic-bezier(0.22, 1, 0.36, 1);
  pointer-events: none;
}

.mobile-tabbar-button,
.mobile-tabbar-search {
  border: 0;
  color: rgba(47, 52, 70, 0.66);
}

.mobile-tabbar-button {
  position: relative;
  z-index: 1;
  display: grid;
  gap: 4px;
  place-items: center;
  min-height: 54px;
  padding: 6px 4px 4px;
  background: transparent;
  font: inherit;
}

.mobile-tabbar-button ion-icon,
.mobile-tabbar-search ion-icon {
  font-size: 1.12rem;
}

.mobile-tabbar-button span:last-child {
  font-size: 0.66rem;
  font-weight: 700;
}

.mobile-tabbar-button.is-active,
.mobile-tabbar-search.is-active {
  color: rgba(31, 41, 55, 0.94);
}

.mobile-tabbar-badge {
  position: absolute;
  top: 6px;
  right: 14px;
  min-width: 18px;
  height: 18px;
  padding: 0 5px;
  border-radius: 999px;
  background: var(--trego-accent);
  color: var(--trego-badge-text);
  font-size: 0.64rem;
  font-weight: 800;
  line-height: 18px;
}

.mobile-tabbar-search {
  flex: 0 0 62px;
  display: inline-flex;
  width: 62px;
  height: 62px;
  align-items: center;
  justify-content: center;
  padding: 0;
}

.mobile-tabbar-search-inner {
  display: inline-flex;
  width: 52px;
  height: 52px;
  align-items: center;
  justify-content: center;
  border-radius: 999px;
  transition: background 240ms ease, box-shadow 240ms ease, transform 240ms ease;
}

.mobile-tabbar-search.is-active .mobile-tabbar-search-inner {
  background:
    linear-gradient(180deg, rgba(255, 255, 255, 0.4), rgba(255, 255, 255, 0.16)),
    radial-gradient(circle at 50% 0%, rgba(255, 255, 255, 0.34), transparent 54%);
  box-shadow:
    inset 0 1px 0 rgba(255, 255, 255, 0.88),
    0 6px 14px rgba(31, 41, 55, 0.05);
  transform: scale(1.02);
}

body[data-theme="dark"] .mobile-tabbar-group,
body[data-theme="dark"] .mobile-tabbar-search {
  border-color: rgba(255, 255, 255, 0.12);
  background:
    linear-gradient(180deg, rgba(18, 18, 20, 0.82), rgba(10, 10, 12, 0.42)),
    radial-gradient(circle at 50% 0%, rgba(255, 255, 255, 0.08), transparent 38%);
}

body[data-theme="dark"] .mobile-tabbar-group::before,
body[data-theme="dark"] .mobile-tabbar-search::before {
  background:
    linear-gradient(180deg, rgba(255, 255, 255, 0.08), rgba(255, 255, 255, 0.02)),
    radial-gradient(circle at 18% 0%, rgba(255, 255, 255, 0.08), transparent 26%);
}

body[data-theme="dark"] .mobile-tabbar-selection,
body[data-theme="dark"] .mobile-tabbar-search.is-active .mobile-tabbar-search-inner {
  background:
    linear-gradient(180deg, rgba(255, 255, 255, 0.12), rgba(255, 255, 255, 0.05)),
    radial-gradient(circle at 50% 0%, rgba(255, 255, 255, 0.08), transparent 54%);
  box-shadow:
    inset 0 1px 0 rgba(255, 255, 255, 0.14),
    0 10px 18px rgba(0, 0, 0, 0.18);
}

body[data-theme="dark"] .mobile-tabbar-button,
body[data-theme="dark"] .mobile-tabbar-search {
  color: rgba(237, 242, 247, 0.66);
}

body[data-theme="dark"] .mobile-tabbar-button.is-active,
body[data-theme="dark"] .mobile-tabbar-search.is-active {
  color: rgba(255, 255, 255, 0.94);
}
</style>
