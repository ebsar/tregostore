<script setup>
import { computed, onBeforeUnmount, onMounted, ref } from "vue";
import { RouterLink, useRoute, useRouter } from "vue-router";
import { requestJson } from "../../lib/api";
import { getDashboardIconPath } from "../../lib/dashboard-ui";
import { formatDateLabel } from "../../lib/shop";
import { logoutUser } from "../../stores/app-state";

const props = defineProps({
  navItems: {
    type: Array,
    default: () => [],
  },
  activeKey: {
    type: String,
    default: "",
  },
  brandInitial: {
    type: String,
    default: "TG",
  },
  brandTitle: {
    type: String,
    default: "Tregio",
  },
  brandSubtitle: {
    type: String,
    default: "Workspace",
  },
  brandImagePath: {
    type: String,
    default: "",
  },
  brandFallbackIcon: {
    type: String,
    default: "dashboard",
  },
  profileImagePath: {
    type: String,
    default: "",
  },
  profileFallbackIcon: {
    type: String,
    default: "",
  },
  profileName: {
    type: String,
    default: "",
  },
  profileSubtitle: {
    type: String,
    default: "",
  },
  searchQuery: {
    type: String,
    default: "",
  },
  searchPlaceholder: {
    type: String,
    default: "Search dashboard",
  },
  notificationCount: {
    type: Number,
    default: 0,
  },
});

const emit = defineEmits(["update:searchQuery", "submit-search", "nav-select"]);
const route = useRoute();
const router = useRouter();
const sidebarOpen = ref(false);
const profileMenuOpen = ref(false);
const notificationsMenuOpen = ref(false);
const profileMenuRef = ref(null);
const notificationsMenuRef = ref(null);
const logoutBusy = ref(false);
const notifications = ref([]);
const notificationsBusy = ref(false);
const notificationsLoaded = ref(false);
const notificationsMessage = ref("");
const hasNotifications = computed(() => Number(props.notificationCount || 0) > 0);
const brandImageSrc = computed(() => String(props.brandImagePath || "").trim());
const profileImageSrc = computed(() => String(props.profileImagePath || "").trim() || brandImageSrc.value);
const notificationPreviewItems = computed(() => notifications.value.slice(0, 6));
const groupedNavItems = computed(() => {
  const groups = [];
  const groupMap = new Map();

  props.navItems.forEach((item) => {
    const groupLabel = String(item?.group || "").trim();
    const groupKey = groupLabel || "__default__";
    if (!groupMap.has(groupKey)) {
      const nextGroup = {
        key: groupKey,
        label: groupLabel,
        items: [],
      };
      groupMap.set(groupKey, nextGroup);
      groups.push(nextGroup);
    }

    groupMap.get(groupKey)?.items.push(item);
  });

  return groups;
});
const brandFallbackIconName = computed(() => String(props.brandFallbackIcon || "dashboard").trim() || "dashboard");
const profileFallbackIconName = computed(() =>
  String(props.profileFallbackIcon || props.brandFallbackIcon || "user").trim() || "user",
);
const profileSettingsTarget = computed(() => {
  const settingsItem = props.navItems.find((item) => ["settings", "profile"].includes(String(item?.key || "")));
  return settingsItem?.to || "/te-dhenat-personale";
});
const profileDropdownItems = computed(() => [
  {
    label: "Account",
    caption: "Dashboard overview",
    icon: "dashboard",
    to: "/llogaria",
  },
  {
    label: "Messages",
    caption: "Conversations and support",
    icon: "messages",
    to: "/mesazhet",
  },
  {
    label: "Settings",
    caption: "Profile details",
    icon: "settings",
    to: profileSettingsTarget.value,
  },
  {
    label: "Change password",
    caption: "Security",
    icon: "lock",
    to: "/ndrysho-fjalekalimin",
  },
]);

function handleSearchInput(event) {
  emit("update:searchQuery", event?.target?.value || "");
}

async function handleSearchSubmit() {
  const query = String(props.searchQuery || "").trim();
  if (!query) {
    emit("submit-search", query);
    return;
  }

  const dashboardTarget = resolveDashboardSearchTarget(query);
  if (dashboardTarget) {
    await router.push(dashboardTarget);
    return;
  }

  emit("submit-search", query);
}

function handleSelectNav(item) {
  emit("nav-select", item);
  sidebarOpen.value = false;
}

function toggleProfileMenu() {
  notificationsMenuOpen.value = false;
  profileMenuOpen.value = !profileMenuOpen.value;
}

function closeProfileMenu() {
  profileMenuOpen.value = false;
}

async function toggleNotificationsMenu() {
  profileMenuOpen.value = false;
  notificationsMenuOpen.value = !notificationsMenuOpen.value;

  if (!notificationsMenuOpen.value) {
    return;
  }

  await ensureNotificationsLoaded();
}

function closeNotificationsMenu() {
  notificationsMenuOpen.value = false;
}

async function handleLogout() {
  if (logoutBusy.value) {
    return;
  }

  logoutBusy.value = true;
  closeProfileMenu();
  closeNotificationsMenu();

  try {
    const { response, data } = await logoutUser();
    if (!response.ok || !data?.ok) {
      return;
    }

    await router.push("/");
  } finally {
    logoutBusy.value = false;
  }
}

function handleGlobalPointerDown(event) {
  if (profileMenuOpen.value && !profileMenuRef.value?.contains(event.target)) {
    closeProfileMenu();
  }

  if (notificationsMenuOpen.value && !notificationsMenuRef.value?.contains(event.target)) {
    closeNotificationsMenu();
  }
}

function handleGlobalKeydown(event) {
  if (event.key === "Escape") {
    closeProfileMenu();
    closeNotificationsMenu();
  }
}

async function ensureNotificationsLoaded(force = false) {
  if (notificationsBusy.value || (notificationsLoaded.value && !force)) {
    return;
  }

  notificationsBusy.value = true;
  notificationsMessage.value = "";

  try {
    const { response, data } = await requestJson("/api/notifications");
    if (!response.ok || !data?.ok) {
      notifications.value = [];
      notificationsMessage.value = data?.message || "Notifications could not be loaded.";
      return;
    }

    notifications.value = Array.isArray(data.notifications) ? data.notifications : [];
    notificationsLoaded.value = true;
  } finally {
    notificationsBusy.value = false;
  }
}

function handleNotificationItemClick(href) {
  closeNotificationsMenu();
  if (!href) {
    return;
  }

  router.push(href);
}

onMounted(() => {
  window.addEventListener("pointerdown", handleGlobalPointerDown);
  window.addEventListener("keydown", handleGlobalKeydown);
});

onBeforeUnmount(() => {
  window.removeEventListener("pointerdown", handleGlobalPointerDown);
  window.removeEventListener("keydown", handleGlobalKeydown);
});

function normalizeDashboardSearchValue(value) {
  return String(value || "")
    .trim()
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "");
}

function extractDashboardOrderNumber(query) {
  const match = normalizeDashboardSearchValue(query).match(/(?:#|order|porosi|nr|number|numri)?\s*(\d{1,})/);
  return match?.[1] || "";
}

function resolveDashboardSearchTarget(query) {
  const normalizedQuery = normalizeDashboardSearchValue(query);
  const orderNumber = extractDashboardOrderNumber(query);
  const hasOrderIntent = /\b(order|orders|porosi|porosite|history|historik|nr|number|numri)\b/.test(normalizedQuery);

  if ((hasOrderIntent || normalizedQuery === orderNumber) && orderNumber) {
    const orderTarget = findDashboardNavItem(["orders", "order-history"], ["order", "porosi", "history"]);
    if (orderTarget?.to) {
      return buildDashboardRoute(orderTarget.to, { q: orderNumber });
    }
  }

  if (matchesAnyDashboardTerm(normalizedQuery, ["password", "fjalekalim", "fjalekalimi", "passcode", "nderrim password", "ndrysho password"])) {
    return { path: "/ndrysho-fjalekalimin" };
  }

  const targetGroups = [
    {
      keys: ["settings", "profile"],
      terms: ["setting", "settings", "profile", "profili", "personal", "te dhenat", "data", "ndrysho", "nderrim", "edit"],
      fallback: "/te-dhenat-personale",
    },
    {
      keys: ["address"],
      terms: ["address", "adresa", "adresat", "delivery", "shipping address"],
      fallback: "/adresat",
    },
    {
      keys: ["notifications"],
      terms: ["notification", "notifications", "njoftim", "njoftime", "njoftimet", "alerts"],
      fallback: "/njoftimet",
    },
    {
      keys: ["returns"],
      terms: ["refund", "refunds", "return", "returns", "kthim", "kthime", "refunde", "returne"],
      fallback: "/refund-returne",
    },
    {
      keys: ["wishlist"],
      terms: ["wishlist", "favorite", "favorit", "saved", "ruajtur"],
      fallback: "/wishlist",
    },
    {
      keys: ["compare"],
      terms: ["compare", "krahaso", "comparison"],
      fallback: "/krahaso-produkte",
    },
    {
      keys: ["cart"],
      terms: ["cart", "shporte", "shporta", "shopping cart"],
      fallback: "/cart",
    },
    {
      keys: ["inventory", "stock"],
      terms: ["inventory", "product", "products", "produkt", "produkte", "artikull", "artikuj", "stock", "stok"],
    },
    {
      keys: ["businesses", "business-page", "profile"],
      terms: ["business", "businesses", "biznes", "bizneset", "store", "dyqan", "vendor", "seller"],
    },
    {
      keys: ["messages"],
      terms: ["message", "messages", "chat", "inbox", "mesazh", "mesazhe", "mesazhet"],
      fallback: "/mesazhet",
    },
    {
      keys: ["dashboard", "analytics"],
      terms: ["dashboard", "overview", "analytics", "panel", "home"],
    },
    {
      keys: ["orders"],
      terms: ["order", "orders", "porosi", "porosite", "history", "historik"],
    },
  ];

  for (const group of targetGroups) {
    if (!matchesAnyDashboardTerm(normalizedQuery, group.terms)) {
      continue;
    }

    const shouldCarrySearch = ["inventory", "products", "stock", "businesses", "orders"].some((key) => group.keys.includes(key))
      && !group.terms.some((term) => normalizedQuery === normalizeDashboardSearchValue(term));
    const searchQuery = shouldCarrySearch ? { q: query } : {};

    const navItem = findDashboardNavItem(group.keys, group.terms);
    if (navItem?.to) {
      return buildDashboardRoute(navItem.to, searchQuery);
    }

    if (group.fallback) {
      return { path: group.fallback, query: searchQuery };
    }
  }

  const directNavMatch = findDashboardNavItem([], [normalizedQuery]);
  return directNavMatch?.to ? buildDashboardRoute(directNavMatch.to) : null;
}

function matchesAnyDashboardTerm(normalizedQuery, terms) {
  return terms.some((term) => {
    const normalizedTerm = normalizeDashboardSearchValue(term);
    return normalizedQuery === normalizedTerm
      || normalizedQuery.includes(normalizedTerm)
      || normalizedTerm.includes(normalizedQuery);
  });
}

function findDashboardNavItem(keys = [], terms = []) {
  const normalizedKeys = keys.map(normalizeDashboardSearchValue);
  const normalizedTerms = terms.map(normalizeDashboardSearchValue);

  return props.navItems.find((item) => {
    const itemKey = normalizeDashboardSearchValue(item?.key);
    const itemLabel = normalizeDashboardSearchValue(item?.label);
    const itemIcon = normalizeDashboardSearchValue(item?.icon);
    const haystack = [itemKey, itemLabel, itemIcon].filter(Boolean).join(" ");

    return normalizedKeys.some((key) => itemKey === key || itemIcon === key)
      || normalizedTerms.some((term) => haystack.includes(term) || term.includes(itemLabel));
  });
}

function buildDashboardRoute(target, extraQuery = {}) {
  if (typeof target === "object" && target !== null) {
    return {
      ...target,
      query: {
        ...(target.query || {}),
        ...extraQuery,
      },
    };
  }

  const [path, search = ""] = String(target || route.path).split("?");
  const query = {};
  const params = new URLSearchParams(search);
  params.forEach((value, key) => {
    query[key] = value;
  });

  return {
    path,
    query: {
      ...query,
      ...extraQuery,
    },
  };
}
</script>

<template>
  <div class="tregio-dashboard-shell">
    <div class="dashboard-layout" :class="{ 'dashboard-layout--sidebar-open': sidebarOpen }">
      <button
        class="dashboard-sidebar__overlay"
        type="button"
        aria-label="Close sidebar"
        @click="sidebarOpen = false"
      ></button>

      <aside class="dashboard-sidebar" aria-label="Dashboard navigation">
        <div class="dashboard-nav-brand">
          <span class="dashboard-nav-brand__mark">
            <img
              v-if="brandImageSrc"
              :src="brandImageSrc"
              :alt="`${brandTitle} logo`"
            >
            <svg v-else viewBox="0 0 24 24" aria-hidden="true">
              <path :d="getDashboardIconPath(brandFallbackIconName)" />
            </svg>
          </span>
          <div>
            <strong>{{ brandTitle }}</strong>
            <span>{{ brandSubtitle }}</span>
          </div>
        </div>

        <div class="dashboard-nav-links">
          <div
            v-for="group in groupedNavItems"
            :key="group.key"
            class="dashboard-nav-group"
          >
            <p v-if="group.label" class="dashboard-nav-group__label">
              {{ group.label }}
            </p>

            <template v-for="item in group.items" :key="`${item.key}-${item.label}`">
              <RouterLink
                v-if="item.to && !item.local"
                :to="item.to"
                :class="{ 'is-active': activeKey === item.key }"
                @click="sidebarOpen = false"
              >
                <svg viewBox="0 0 24 24" aria-hidden="true">
                  <path :d="getDashboardIconPath(item.icon)" />
                </svg>
                <span>{{ item.label }}</span>
                <small v-if="item.badge">{{ item.badge }}</small>
              </RouterLink>

              <button
                v-else
                type="button"
                :class="{ 'is-active': activeKey === item.key }"
                @click="handleSelectNav(item)"
              >
                <svg viewBox="0 0 24 24" aria-hidden="true">
                  <path :d="getDashboardIconPath(item.icon)" />
                </svg>
                <span>{{ item.label }}</span>
                <small v-if="item.badge">{{ item.badge }}</small>
              </button>
            </template>
          </div>
        </div>

        <div class="dashboard-sidebar__footer">
          <slot name="sidebar-footer" />
        </div>
      </aside>

      <div class="dashboard-main">
        <header class="dashboard-topbar">
          <button
            class="dashboard-topbar__menu"
            type="button"
            aria-label="Open sidebar"
            @click="sidebarOpen = true"
          >
            <span></span>
            <span></span>
            <span></span>
          </button>

          <form class="dashboard-topbar__search" role="search" @submit.prevent="handleSearchSubmit">
            <svg viewBox="0 0 24 24" aria-hidden="true">
              <path :d="getDashboardIconPath('search')" />
            </svg>
            <input
              :value="searchQuery"
              type="search"
              :placeholder="searchPlaceholder"
              @input="handleSearchInput"
            >
          </form>

          <div class="dashboard-topbar__actions">
            <div ref="notificationsMenuRef" class="dashboard-topbar__profile-menu dashboard-topbar__notifications-menu">
              <button
                class="dashboard-topbar__icon-button"
                type="button"
                :aria-expanded="notificationsMenuOpen ? 'true' : 'false'"
                aria-haspopup="menu"
                aria-label="Notifications"
                @click="toggleNotificationsMenu"
              >
                <svg viewBox="0 0 24 24" aria-hidden="true">
                  <path :d="getDashboardIconPath('bell')" />
                </svg>
                <span v-if="hasNotifications" class="dashboard-topbar__badge">
                  {{ notificationCount > 99 ? "99+" : notificationCount }}
                </span>
              </button>

              <div
                v-if="notificationsMenuOpen"
                class="dashboard-topbar__dropdown dashboard-topbar__notifications-dropdown"
                role="menu"
              >
                <div class="dashboard-topbar__dropdown-head dashboard-topbar__dropdown-head--stack">
                  <div>
                    <strong>Notifications</strong>
                    <span>Recent updates and marketplace alerts</span>
                  </div>
                  <button
                    class="dashboard-topbar__dropdown-link"
                    type="button"
                    @click="ensureNotificationsLoaded(true)"
                  >
                    Refresh
                  </button>
                </div>

                <div v-if="notificationsBusy" class="dashboard-topbar__notifications-state">
                  Loading notifications...
                </div>

                <div v-else-if="notificationsMessage" class="dashboard-topbar__notifications-state">
                  {{ notificationsMessage }}
                </div>

                <div v-else-if="notificationPreviewItems.length === 0" class="dashboard-topbar__notifications-state">
                  No notifications yet.
                </div>

                <div v-else class="dashboard-topbar__notifications-list">
                  <button
                    v-for="notification in notificationPreviewItems"
                    :key="notification.id"
                    class="dashboard-topbar__notification-item"
                    type="button"
                    role="menuitem"
                    @click="handleNotificationItemClick(notification.href)"
                  >
                    <span class="dashboard-topbar__notification-icon">
                      <svg viewBox="0 0 24 24" aria-hidden="true">
                        <path :d="getDashboardIconPath('bell')" />
                      </svg>
                    </span>
                    <span class="dashboard-topbar__notification-copy">
                      <strong>{{ notification.title || "Notification" }}</strong>
                      <small>{{ notification.body || "Open update" }}</small>
                      <time v-if="notification.createdAt">{{ formatDateLabel(notification.createdAt) }}</time>
                    </span>
                  </button>
                </div>

                <RouterLink
                  to="/njoftimet"
                  class="dashboard-topbar__dropdown-item dashboard-topbar__dropdown-item--footer"
                  role="menuitem"
                  @click="closeNotificationsMenu"
                >
                  <svg viewBox="0 0 24 24" aria-hidden="true">
                    <path :d="getDashboardIconPath('bell')" />
                  </svg>
                  <span>
                    <strong>View all notifications</strong>
                    <small>Open the full notifications page</small>
                  </span>
                </RouterLink>
              </div>
            </div>

            <RouterLink class="dashboard-topbar__icon-button" to="/mesazhet" aria-label="Messages">
              <svg viewBox="0 0 24 24" aria-hidden="true">
                <path :d="getDashboardIconPath('messages')" />
              </svg>
            </RouterLink>

            <div ref="profileMenuRef" class="dashboard-topbar__profile-menu">
              <button
                class="dashboard-topbar__icon-button dashboard-topbar__profile-trigger"
                type="button"
                :aria-expanded="profileMenuOpen ? 'true' : 'false'"
                aria-haspopup="menu"
                aria-label="Open profile menu"
                @click="toggleProfileMenu"
              >
                <span class="dashboard-topbar__avatar">
                  <img
                    v-if="profileImageSrc"
                    :src="profileImageSrc"
                    :alt="`${profileName || brandTitle} avatar`"
                  >
                  <svg v-else viewBox="0 0 24 24" aria-hidden="true">
                    <path :d="getDashboardIconPath(profileFallbackIconName)" />
                  </svg>
                </span>
              </button>

              <div v-if="profileMenuOpen" class="dashboard-topbar__dropdown" role="menu">
                <div class="dashboard-topbar__dropdown-head">
                  <span class="dashboard-topbar__avatar">
                    <img
                      v-if="profileImageSrc"
                      :src="profileImageSrc"
                      :alt="`${profileName || brandTitle} avatar`"
                    >
                    <svg v-else viewBox="0 0 24 24" aria-hidden="true">
                      <path :d="getDashboardIconPath(profileFallbackIconName)" />
                    </svg>
                  </span>
                  <div>
                    <strong>{{ profileName || brandTitle }}</strong>
                    <span>{{ profileSubtitle || brandSubtitle }}</span>
                  </div>
                </div>

                <RouterLink
                  v-for="item in profileDropdownItems"
                  :key="`${item.label}-${item.to}`"
                  :to="item.to"
                  class="dashboard-topbar__dropdown-item"
                  role="menuitem"
                  @click="closeProfileMenu"
                >
                  <svg viewBox="0 0 24 24" aria-hidden="true">
                    <path :d="getDashboardIconPath(item.icon)" />
                  </svg>
                  <span>
                    <strong>{{ item.label }}</strong>
                    <small>{{ item.caption }}</small>
                  </span>
                </RouterLink>

                <button
                  class="dashboard-topbar__dropdown-item dashboard-topbar__dropdown-item--danger"
                  type="button"
                  role="menuitem"
                  :disabled="logoutBusy"
                  @click="handleLogout"
                >
                  <svg viewBox="0 0 24 24" aria-hidden="true">
                    <path :d="getDashboardIconPath('logout')" />
                  </svg>
                  <span>
                    <strong>{{ logoutBusy ? "Logging out..." : "Log out" }}</strong>
                    <small>End the current session</small>
                  </span>
                </button>
              </div>
            </div>

            <slot name="topbar-actions" />
          </div>
        </header>

        <slot />
      </div>
    </div>
  </div>
</template>
