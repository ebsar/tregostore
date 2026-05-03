<script setup lang="ts">
import { IonIcon, IonRouterOutlet, IonTabs } from "@ionic/vue";
import { cartOutline, homeOutline, personCircleOutline, searchOutline, storefrontOutline } from "ionicons/icons";
import { computed } from "vue";
import { useRoute, useRouter } from "vue-router";
import { activityBadgeCount, sessionState } from "../stores/session";

type TabShellItem = {
  key: "home" | "bizneset" | "cart" | "llogaria" | "kerko";
  label: string;
  icon: string;
  path: string;
};

const route = useRoute();
const router = useRouter();

const groupedTabs: TabShellItem[] = [
  { key: "home", label: "Home", icon: homeOutline, path: "/tabs/home" },
  { key: "kerko", label: "Search", icon: searchOutline, path: "/tabs/search" },
  { key: "bizneset", label: "Bizneset", icon: storefrontOutline, path: "/tabs/businesses" },
  { key: "cart", label: "Cart", icon: cartOutline, path: "/tabs/cart" },
  { key: "llogaria", label: "Llogaria", icon: personCircleOutline, path: "/tabs/account" },
];

const cartBadge = computed(() => (sessionState.cartCount > 0 ? String(sessionState.cartCount) : ""));
const activityBadge = computed(() => {
  const total = Math.max(0, Number(activityBadgeCount.value || 0));
  if (total <= 0) {
    return "";
  }
  return total > 99 ? "99+" : String(total);
});

const badgeMap = computed<Record<string, string>>(() => ({
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
  if (path.startsWith("/tabs/businesses")) {
    return "bizneset";
  }
  if (path.startsWith("/tabs/wishlist")) {
    return "cart";
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

    <nav v-if="!usesNativeIOSTabs" class="trego-tab-shell" aria-label="Primary">
      <div class="trego-tab-shell__group">
        <div
          class="trego-tab-shell__indicator"
          :style="{ transform: `translateX(${activeGroupIndex * 100}%)` }"
        />

        <button
          v-for="item in groupedTabs"
          :key="item.key"
          :class="['trego-tab-shell__item', { 'is-active': activeTab === item.key }]"
          type="button"
          @click="navigateTo(item.path)"
        >
          <span
            v-if="badgeMap[item.key]"
            class="trego-tab-shell__badge"
          >
            {{ badgeMap[item.key] }}
          </span>
          <IonIcon :icon="item.icon" />
          <span>{{ item.label }}</span>
        </button>
      </div>

    </nav>
  </IonTabs>
</template>
