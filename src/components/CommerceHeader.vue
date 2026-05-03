<script setup>
import { computed, defineAsyncComponent, nextTick, onBeforeUnmount, onMounted, ref, watch } from "vue";
import { RouterLink, useRoute, useRouter } from "vue-router";
import { deriveSectionFromCategory, PRODUCT_PAGE_SECTION_OPTIONS } from "../lib/product-catalog";
import { requestJson } from "../lib/api";
import { setPendingVisualSearchFile } from "../lib/visual-search-transfer";
import { appState } from "../stores/app-state";

const route = useRoute();
const router = useRouter();
const HeaderCartOverlay = defineAsyncComponent(() => import("./HeaderCartOverlay.vue"));
const HeaderWishlistOverlay = defineAsyncComponent(() => import("./HeaderWishlistOverlay.vue"));
const searchQuery = ref("");
const searchFormElement = ref(null);
const searchInputElement = ref(null);
const mobileSearchToggleElement = ref(null);
const visualSearchInputElement = ref(null);
const notificationsMenuRef = ref(null);
const cartDrawerOpen = ref(false);
const wishlistDrawerOpen = ref(false);
const mobileSearchOpen = ref(false);
const notificationsDropdownOpen = ref(false);
const notificationsBusy = ref(false);
const notificationsLoaded = ref(false);
const notificationsMessage = ref("");
const notifications = ref([]);
const unreadNotificationsCount = ref(0);
const promoHidden = ref(false);

const accountTarget = computed(() => {
  if (!appState.user) {
    return "/login";
  }

  if (appState.user.role === "business") {
    return "/biznesi-juaj";
  }

  if (appState.user.role === "admin") {
    return "/admin-products";
  }

  return "/llogaria";
});

const activeCategoryValue = computed(() => {
  if (route.path === "/bizneset") {
    return "businesses";
  }

  if (route.path !== "/kerko") {
    return "all";
  }

  const categoryFromRoute = normalizeSearchQuery(route.query.category).toLowerCase();
  if (categoryFromRoute) {
    return deriveSectionFromCategory(categoryFromRoute);
  }

  const pageSectionFromRoute = normalizeSearchQuery(route.query.pageSection).toLowerCase();
  return pageSectionFromRoute || "all";
});
const businessDirectoryActive = computed(() => route.path === "/bizneset");
const canUseProductPhotoSearch = computed(() => {
  const role = String(appState.user?.role || "").toLowerCase();
  return role !== "admin" && role !== "business";
});

const categoryLinks = computed(() => ([
  {
    value: "all",
    label: "Te gjitha",
    to: buildCategoryRoute(""),
  },
  ...PRODUCT_PAGE_SECTION_OPTIONS.map((option) => ({
    value: option.value,
    label: option.label,
    to: buildCategoryRoute(option.value),
  })),
]));
const cartBadgeLabel = computed(() => {
  if (appState.cartCount <= 0) {
    return "";
  }

  return appState.cartCount > 99 ? "99+" : String(appState.cartCount);
});
const accountNotificationBadgeLabel = computed(() => {
  if (unreadNotificationsCount.value <= 0) {
    return "";
  }

  return unreadNotificationsCount.value > 99 ? "99+" : String(unreadNotificationsCount.value);
});
const notificationPreviewItems = computed(() => notifications.value.slice(0, 4));

watch(
  () => route.query.q,
  (value) => {
    searchQuery.value = normalizeSearchQuery(value);
  },
  { immediate: true },
);

watch(
  () => route.fullPath,
  () => {
    cartDrawerOpen.value = false;
    wishlistDrawerOpen.value = false;
    mobileSearchOpen.value = false;
    notificationsDropdownOpen.value = false;
    void loadUnreadNotificationsCount();
  },
);

watch(
  () => appState.user?.id,
  () => {
    void loadUnreadNotificationsCount();
  },
);

onMounted(() => {
  handleWindowScroll();
  window.addEventListener("tregio:open-track-order", handleOpenTrackOrderEvent);
  window.addEventListener("click", handleWindowClick);
  window.addEventListener("scroll", handleWindowScroll, { passive: true });
  void loadUnreadNotificationsCount();
});

onBeforeUnmount(() => {
  window.removeEventListener("tregio:open-track-order", handleOpenTrackOrderEvent);
  window.removeEventListener("click", handleWindowClick);
  window.removeEventListener("scroll", handleWindowScroll);
});

function normalizeSearchQuery(value) {
  if (Array.isArray(value)) {
    return String(value[0] || "").trim();
  }

  return String(value || "").trim();
}

function buildCategoryRoute(pageSection) {
  const nextQuery = {};

  if (pageSection) {
    nextQuery.pageSection = pageSection;
  }

  return {
    path: "/kerko",
    query: nextQuery,
  };
}

async function handleSearchSubmit() {
  const nextQuery = searchQuery.value.trim();
  const currentQuery = normalizeSearchQuery(route.query.q);

  if (route.path === "/kerko" && currentQuery === nextQuery) {
    mobileSearchOpen.value = false;
    return;
  }

  await router.push({
    path: "/kerko",
    query: nextQuery ? { q: nextQuery } : {},
  });
  mobileSearchOpen.value = false;
}

async function toggleMobileSearch() {
  mobileSearchOpen.value = !mobileSearchOpen.value;
  if (!mobileSearchOpen.value) {
    return;
  }

  await nextTick();
  searchInputElement.value?.focus?.();
  searchInputElement.value?.select?.();
}

function openVisualSearchPicker() {
  visualSearchInputElement.value?.click?.();
}

async function handleVisualSearchSelection(event) {
  const nextFile = event?.target?.files?.[0] || null;
  if (!nextFile) {
    return;
  }

  setPendingVisualSearchFile(nextFile);
  await router.push("/kerko");

  if (event?.target) {
    event.target.value = "";
  }
}

async function handleOpenTrackOrderEvent() {
  await router.push("/track-order");
}

function handleWindowClick(event) {
  const target = event?.target;
  if (!target) {
    return;
  }

  if (
    mobileSearchOpen.value
    && !searchFormElement.value?.contains(target)
    && !mobileSearchToggleElement.value?.contains(target)
  ) {
    mobileSearchOpen.value = false;
  }

  if (
    notificationsDropdownOpen.value
    && !notificationsMenuRef.value?.contains(target)
  ) {
    notificationsDropdownOpen.value = false;
  }
}

function handleWindowScroll() {
  promoHidden.value = window.scrollY > 80;
}

async function loadUnreadNotificationsCount() {
  if (!appState.user) {
    unreadNotificationsCount.value = 0;
    return;
  }

  try {
    const { response, data } = await requestJson("/api/notifications/count");
    if (!response.ok || !data?.ok) {
      unreadNotificationsCount.value = 0;
      return;
    }

    unreadNotificationsCount.value = Math.max(0, Number(data.unreadCount || 0));
  } catch (error) {
    console.error(error);
    unreadNotificationsCount.value = 0;
  }
}

async function ensureNotificationsLoaded(force = false) {
  if (!appState.user) {
    notifications.value = [];
    notificationsMessage.value = "Sign in to view notifications.";
    notificationsLoaded.value = true;
    return;
  }

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
  } catch (error) {
    console.error(error);
    notifications.value = [];
    notificationsMessage.value = "Notifications could not be loaded.";
  } finally {
    notificationsBusy.value = false;
  }
}

async function toggleNotificationsDropdown() {
  cartDrawerOpen.value = false;
  wishlistDrawerOpen.value = false;
  notificationsDropdownOpen.value = !notificationsDropdownOpen.value;

  if (notificationsDropdownOpen.value) {
    await ensureNotificationsLoaded();
  }
}

function closeNotificationsDropdown() {
  notificationsDropdownOpen.value = false;
}

function formatNotificationTime(value) {
  const rawValue = String(value || "").trim();
  if (!rawValue) {
    return "";
  }

  const parsedDate = new Date(rawValue.includes("T") ? rawValue : rawValue.replace(" ", "T"));
  if (Number.isNaN(parsedDate.getTime())) {
    return rawValue;
  }

  return parsedDate.toLocaleDateString("sq-AL", {
    day: "2-digit",
    month: "short",
  });
}

function openCartDrawer() {
  wishlistDrawerOpen.value = false;
  cartDrawerOpen.value = true;
}

function closeCartDrawer() {
  cartDrawerOpen.value = false;
}

function openWishlistDrawer() {
  cartDrawerOpen.value = false;
  wishlistDrawerOpen.value = true;
}

function closeWishlistDrawer() {
  wishlistDrawerOpen.value = false;
}

async function handleWishlistLogin() {
  wishlistDrawerOpen.value = false;
  await router.push("/login?redirect=%2Fwishlist");
}
</script>

<template>
  <header class="site-header">
    <div class="site-header__main">
      <RouterLink class="site-header__brand" to="/" aria-label="TREGIO home">
        <img
          class="site-header__brand-image"
          src="/trego-logo.webp?v=20260410"
          alt="TREGIO"
          width="1024"
          height="1024"
          decoding="async"
          fetchpriority="high"
        >
      </RouterLink>

      <form
        ref="searchFormElement"
        class="site-header__search"
        :class="{ 'site-header__search--mobile-open': mobileSearchOpen }"
        role="search"
        @submit.prevent="handleSearchSubmit"
      >
        <label class="site-header__search-label" for="site-header-search">Search products</label>
        <div
          class="site-header__search-field"
          :class="{ 'site-header__search-field--photo': canUseProductPhotoSearch }"
        >
          <svg class="site-header__search-icon" viewBox="0 0 24 24" aria-hidden="true">
            <circle cx="11" cy="11" r="6.75"></circle>
            <path d="M16 16l4.25 4.25"></path>
          </svg>
          <input
            id="site-header-search"
            ref="searchInputElement"
            v-model="searchQuery"
            class="site-header__search-input"
            type="search"
            name="q"
            placeholder="Search products, brands, and stores"
            autocomplete="off"
          />
          <button
            v-if="canUseProductPhotoSearch"
            class="site-header__search-camera"
            type="button"
            aria-label="Search products by photo"
            title="Search products by photo"
            @click="openVisualSearchPicker"
          >
            <svg viewBox="0 0 24 24" aria-hidden="true">
              <rect x="4" y="7" width="16" height="11" rx="3"></rect>
              <circle cx="12" cy="12.5" r="3"></circle>
              <path d="M8 7l1.4-2h5.2L16 7"></path>
            </svg>
          </button>
          <input
            v-if="canUseProductPhotoSearch"
            ref="visualSearchInputElement"
            class="site-header__visual-input"
            type="file"
            accept="image/*"
            capture="environment"
            @change="handleVisualSearchSelection"
          >
        </div>
      </form>

      <div class="site-header__actions" aria-label="Quick actions">
        <RouterLink class="site-header__icon-link" to="/njoftimet" aria-label="Notifications">
          <svg viewBox="0 0 24 24" aria-hidden="true">
            <path d="M18 9.8a6 6 0 1 0-12 0c0 5.2-2.2 5.8-2.2 5.8h16.4S18 15 18 9.8"></path>
            <path d="M9.8 19a2.4 2.4 0 0 0 4.4 0"></path>
          </svg>
          <span v-if="accountNotificationBadgeLabel" class="site-header__icon-badge site-header__icon-badge--notification">
            {{ accountNotificationBadgeLabel }}
          </span>
        </RouterLink>

        <button
          ref="mobileSearchToggleElement"
          class="site-header__icon-link site-header__icon-button site-header__mobile-search-toggle"
          type="button"
          :aria-expanded="mobileSearchOpen ? 'true' : 'false'"
          aria-controls="site-header-search"
          aria-label="Search"
          @click="toggleMobileSearch"
        >
          <svg viewBox="0 0 24 24" aria-hidden="true">
            <circle cx="11" cy="11" r="6.75"></circle>
            <path d="M16 16l4.25 4.25"></path>
          </svg>
        </button>

        <button class="site-header__icon-link site-header__icon-button" type="button" aria-label="Wishlist" @click="openWishlistDrawer">
          <svg viewBox="0 0 24 24" aria-hidden="true">
            <path d="M12 20.25 5.35 14.1a5 5 0 0 1-.55-6.75 4.25 4.25 0 0 1 6.15-.25L12 8.15l1.05-1.05a4.25 4.25 0 0 1 6.15.25 5 5 0 0 1-.55 6.75Z"></path>
          </svg>
        </button>

        <button class="site-header__icon-link site-header__icon-button" type="button" aria-label="Cart" @click="openCartDrawer">
          <svg viewBox="0 0 24 24" aria-hidden="true">
            <path d="M3 4.75h2.1l1.45 8.65a1 1 0 0 0 .98.82h9.86a1 1 0 0 0 .97-.73L19.8 8.5H6.3"></path>
            <circle cx="9.25" cy="19.1" r="1.25"></circle>
            <circle cx="16.25" cy="19.1" r="1.25"></circle>
          </svg>
          <span v-if="cartBadgeLabel" class="site-header__icon-badge">{{ cartBadgeLabel }}</span>
        </button>

        <RouterLink class="site-header__icon-link" :to="accountTarget" aria-label="Account">
          <svg viewBox="0 0 24 24" aria-hidden="true">
            <circle cx="12" cy="8.5" r="3.75"></circle>
            <path d="M4.5 19.25c1.4-3.35 4.3-5 7.5-5s6.1 1.65 7.5 5"></path>
          </svg>
        </RouterLink>
      </div>
    </div>

    <div class="site-header__category-strip">
      <nav class="site-header__category-nav" aria-label="Product categories">
        <RouterLink
          v-for="link in categoryLinks"
          :key="link.value"
          class="site-header__category-link"
          :class="{ 'site-header__category-link--active': activeCategoryValue === link.value }"
          :to="link.to"
        >
          {{ link.label }}
        </RouterLink>

        <RouterLink
          class="site-header__category-link site-header__category-link--business"
          :class="{ 'site-header__category-link--active': businessDirectoryActive }"
          to="/bizneset"
        >
          Business
        </RouterLink>
      </nav>
    </div>

    <div class="site-header__promo">
      <div class="site-header__promo-inner">
        <p>Take the chance, create account and get 10% discount on your first order</p>

        <div class="site-header__timer" aria-label="Promotional countdown">
          <div v-for="unit in promoUnits" :key="unit.label" class="site-header__timer-unit">
            <strong>{{ unit.value }}</strong>
            <span>{{ unit.label }}</span>
          </div>
        </div>
      </div>
    </div>
  </header>

  <Teleport to="body">
    <Transition name="cart-drawer">
      <HeaderCartOverlay v-if="cartDrawerOpen" @close="closeCartDrawer" />
    </Transition>
  </Teleport>

  <Teleport to="body">
    <Transition name="wishlist-drawer">
      <HeaderWishlistOverlay
        v-if="wishlistDrawerOpen"
        @close="closeWishlistDrawer"
        @request-login="handleWishlistLogin"
      />
    </Transition>
  </Teleport>
</template>

<style scoped>
.site-header {
  position: sticky;
  top: 0;
  z-index: 1000;
  width: 100%;
  background: rgba(255, 255, 255, 0.88);
  backdrop-filter: blur(16px);
  border-bottom: 1px solid var(--color-border);
  font-family: inherit;
}

.site-header__main {
  width: min(100%, 1360px);
  margin: 0 auto;
  box-sizing: border-box;
  min-height: 72px;
  position: relative;
  display: grid;
  grid-template-columns: auto minmax(320px, 640px) auto;
  align-items: center;
  gap: var(--space-8);
  justify-content: space-between;
  padding: 0 var(--space-6);
}

.site-header__brand {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  color: #111111;
  text-decoration: none;
  white-space: nowrap;
}

.site-header__brand-image {
  height: 52px;
  width: auto;
  display: block;
  object-fit: contain;
}

.site-header__search {
  width: 100%;
  min-width: 0;
}

.site-header__search-field {
  position: relative;
  width: 100%;
  min-width: 0;
}

.site-header__search-icon {
  position: absolute;
  top: 50%;
  left: 14px;
  width: 18px;
  height: 18px;
  transform: translateY(-50%);
  color: var(--color-muted);
  fill: none;
  stroke: currentColor;
  stroke-width: 1.8;
  stroke-linecap: round;
  stroke-linejoin: round;
  pointer-events: none;
}

.site-header__search-label {
  position: absolute;
  width: 1px;
  height: 1px;
  padding: 0;
  margin: -1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  white-space: nowrap;
  border: 0;
}

.site-header__search-input {
  width: 100%;
  height: 44px;
  border: 1px solid var(--color-border);
  border-radius: var(--radius-control);
  padding: 0 48px 0 44px;
  background: #f7f7f7;
  color: var(--color-text);
  font-size: 14px;
  line-height: 1;
  outline: none;
  transition: all 0.2s ease;
}

.site-header__search-field--photo .site-header__search-input {
  padding-right: 54px;
}

.site-header__search-input::placeholder {
  color: var(--color-muted);
}

.site-header__search-input:focus {
  background: var(--color-surface);
  border-color: var(--color-primary);
  box-shadow: 0 0 0 3px var(--color-primary-soft);
}

.site-header__search-camera {
  position: absolute;
  top: 50%;
  right: 6px;
  width: 32px;
  height: 32px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  transform: translateY(-50%);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-pill);
  background: #ffffff;
  color: var(--color-primary);
  cursor: pointer;
  transition:
    border-color 160ms ease,
    background-color 160ms ease,
    color 160ms ease;
}

.site-header__search-camera:hover,
.site-header__search-camera:focus-visible {
  border-color: var(--color-primary-border);
  background: var(--color-primary-soft);
  color: var(--color-primary-hover);
  outline: none;
}

.site-header__search-camera svg {
  width: 16px;
  height: 16px;
  stroke: currentColor;
  stroke-width: 1.8;
  fill: none;
  stroke-linecap: round;
  stroke-linejoin: round;
}

.site-header__visual-input {
  position: absolute;
  width: 1px;
  height: 1px;
  opacity: 0;
  pointer-events: none;
}

.site-header__actions {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: var(--space-2);
}

.site-header__icon-link {
  position: relative;
  width: var(--touch-target);
  height: var(--touch-target);
  display: inline-flex;
  align-items: center;
  justify-content: center;
  color: var(--color-text);
  text-decoration: none;
  border-radius: var(--radius-control);
  transition: all 0.2s ease;
}

.site-header__icon-button {
  border: 0;
  background: transparent;
  padding: 0;
  cursor: pointer;
}

.site-header__mobile-search-toggle {
  display: none;
}

.site-header__icon-link:hover {
  background: var(--color-primary-soft);
  color: var(--color-primary);
}

.site-header__icon-link svg {
  width: 22px;
  height: 22px;
  stroke: currentColor;
  stroke-width: 1.6;
  fill: none;
  stroke-linecap: round;
  stroke-linejoin: round;
}

.site-header__icon-badge {
  position: absolute;
  top: 4px;
  right: 4px;
  min-width: 16px;
  height: 16px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  padding: 0 4px;
  border-radius: 999px;
  background: var(--color-primary);
  color: #ffffff;
  font-size: 10px;
  font-weight: 700;
  line-height: 1;
  box-shadow: 0 0 0 2px var(--color-surface);
}

.site-header__icon-badge--notification {
  background: var(--color-error);
}

.site-header__category-strip {
  border-top: 1px solid var(--color-border);
  border-bottom: 1px solid var(--color-border);
  background: #ffffff;
  padding: 0;
}

.site-header__category-nav {
  width: min(100%, 1360px);
  margin: 0 auto;
  box-sizing: border-box;
  min-height: 46px;
  display: flex;
  align-items: center;
  gap: var(--space-6);
  padding: 0 var(--space-6);
  overflow-x: auto;
  scrollbar-width: none;
}

.site-header__category-nav::-webkit-scrollbar {
  display: none;
}

.site-header__category-link {
  position: relative;
  flex: 0 0 auto;
  color: var(--color-muted);
  text-decoration: none;
  font-size: 13px;
  font-weight: 500;
  line-height: 1;
  white-space: nowrap;
  transition: color 160ms ease;
}

.site-header__category-link::after {
  content: "";
  position: absolute;
  left: 0;
  right: 0;
  bottom: -16px;
  height: 1.5px;
  border-radius: 999px;
  background: var(--color-primary);
  opacity: 0;
  transition: opacity 160ms ease;
}

.site-header__category-link:hover {
  color: var(--color-text);
}

.site-header__category-link--active {
  color: var(--color-text);
  font-weight: 600;
}

.site-header__category-link--active::after {
  opacity: 1;
}

.site-header__category-link--business {
  margin-left: auto;
  min-height: 30px;
  display: inline-flex;
  align-items: center;
  padding: 0 13px;
  border: 1px solid var(--color-primary-border);
  border-radius: var(--radius-pill);
  background: var(--color-primary-soft);
  color: var(--color-primary-hover);
  font-weight: 700;
}

.site-header__category-link--business::after {
  display: none;
}

.site-header__category-link--business:hover,
.site-header__category-link--business.site-header__category-link--active {
  border-color: var(--color-primary);
  background: var(--color-primary);
  color: #ffffff;
}

.site-header__promo {
  min-height: 38px;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 0;
  background: var(--color-primary);
}

.site-header__promo-inner {
  width: min(100%, 1360px);
  margin: 0 auto;
  box-sizing: border-box;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 18px;
  padding: 0 var(--space-6);
  color: #ffffff;
}

.site-header__promo-inner p {
  margin: 0;
  font-size: 13px;
  font-weight: 500;
  line-height: 1;
}

.site-header__timer {
  display: flex;
  align-items: center;
  gap: 8px;
}

.site-header__timer-unit {
  min-width: 48px;
  min-height: 26px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  padding: 0 8px;
  border-radius: 8px;
  background: rgba(255, 255, 255, 0.14);
}

.site-header__timer-unit strong {
  font-size: 12px;
  font-weight: 700;
  line-height: 1;
}

.site-header__timer-unit span {
  font-size: 10px;
  font-weight: 500;
  line-height: 1;
  opacity: 0.92;
  text-transform: uppercase;
  letter-spacing: 0.04em;
}

@media (max-width: 960px) {
  .site-header__main {
    grid-template-columns: auto minmax(0, 1fr) auto;
    gap: var(--space-4);
    min-height: 72px;
    padding: 0 var(--space-4);
  }

  .site-header__category-nav,
  .site-header__promo-inner {
    padding-left: 18px;
    padding-right: 18px;
  }
}

@media (max-width: 640px) {
  .site-header__main {
    grid-template-columns: auto auto;
    grid-template-areas:
      "brand actions"
      "search search";
    align-items: center;
    min-height: 56px;
    padding: 0 var(--space-3);
  }

  .site-header__brand {
    grid-area: brand;
  }

  .site-header__search {
    display: none;
    grid-area: search;
  }

  .site-header__search--mobile-open {
    position: absolute;
    left: var(--space-3);
    right: var(--space-3);
    top: calc(100% + var(--space-2));
    z-index: 8;
    display: block;
    padding: var(--space-2);
    border: 1px solid var(--color-border);
    border-radius: var(--radius-card);
    background: rgba(255, 255, 255, 0.98);
    box-shadow: 0 18px 38px rgba(17, 17, 17, 0.12);
  }

  .site-header__actions {
    grid-area: actions;
    gap: var(--space-1);
  }

  .site-header__mobile-search-toggle {
    display: inline-flex;
  }

  .site-header__brand {
    justify-content: flex-start;
  }

  .site-header__brand-image {
    width: auto;
    height: 38px;
  }

  .site-header__promo {
    padding: 8px 0;
  }

  .site-header__category-strip {
    padding: 0;
  }

  .site-header__category-nav,
  .site-header__promo-inner {
    padding-left: 14px;
    padding-right: 14px;
  }

  .site-header__category-link--business {
    margin-left: 0;
  }

  .site-header__promo-inner {
    flex-direction: column;
    gap: 8px;
  }

  .site-header__promo-inner p {
    text-align: center;
    line-height: 1.35;
  }

  .site-header__timer {
    flex-wrap: wrap;
    justify-content: center;
  }

  .site-header__timer-unit {
    min-width: 44px;
  }
}
</style>
