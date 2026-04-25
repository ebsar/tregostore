<script setup>
import { computed, onBeforeUnmount, onMounted, ref, watch } from "vue";
import { RouterLink, useRoute, useRouter } from "vue-router";
import HeaderCartOverlay from "./HeaderCartOverlay.vue";
import { deriveSectionFromCategory, PRODUCT_PAGE_SECTION_OPTIONS } from "../lib/product-catalog";
import { appState } from "../stores/app-state";

const route = useRoute();
const router = useRouter();
const searchQuery = ref("");
const cartDrawerOpen = ref(false);
const promoNow = ref(Date.now());
const promoDeadline = Date.now() + ((((4 * 24) + 18) * 60 * 60) * 1000);
let promoIntervalId = 0;

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

const promoUnits = computed(() => {
  const remainingMilliseconds = Math.max(0, promoDeadline - promoNow.value);
  const totalSeconds = Math.floor(remainingMilliseconds / 1000);
  const days = Math.floor(totalSeconds / 86400);
  const hours = Math.floor((totalSeconds % 86400) / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const seconds = totalSeconds % 60;

  return [
    { label: "Days", value: String(days).padStart(2, "0") },
    { label: "Hours", value: String(hours).padStart(2, "0") },
    { label: "Minutes", value: String(minutes).padStart(2, "0") },
    { label: "Seconds", value: String(seconds).padStart(2, "0") },
  ];
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
  },
);

onMounted(() => {
  promoNow.value = Date.now();
  promoIntervalId = window.setInterval(() => {
    promoNow.value = Date.now();
  }, 1000);

  window.addEventListener("tregio:open-track-order", handleOpenTrackOrderEvent);
});

onBeforeUnmount(() => {
  if (promoIntervalId) {
    window.clearInterval(promoIntervalId);
    promoIntervalId = 0;
  }

  window.removeEventListener("tregio:open-track-order", handleOpenTrackOrderEvent);
});

function normalizeSearchQuery(value) {
  if (Array.isArray(value)) {
    return String(value[0] || "").trim();
  }

  return String(value || "").trim();
}

function buildCategoryRoute(pageSection) {
  const nextQuery = {};
  const activeQuery = normalizeSearchQuery(route.query.q);

  if (activeQuery) {
    nextQuery.q = activeQuery;
  }

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
    return;
  }

  await router.push({
    path: "/kerko",
    query: nextQuery ? { q: nextQuery } : {},
  });
}

async function handleOpenTrackOrderEvent() {
  await router.push("/track-order");
}

function openCartDrawer() {
  cartDrawerOpen.value = true;
}

function closeCartDrawer() {
  cartDrawerOpen.value = false;
}
</script>

<template>
  <header class="site-header">
    <div class="site-header__main">
      <RouterLink class="site-header__brand" to="/" aria-label="TREGIO home">
        <img
          class="site-header__brand-image"
          src="/trego-logo.png"
          alt="TREGIO"
          width="1024"
          height="1024"
        >
      </RouterLink>

      <form class="site-header__search" role="search" @submit.prevent="handleSearchSubmit">
        <label class="site-header__search-label" for="site-header-search">Search products</label>
        <input
          id="site-header-search"
          v-model="searchQuery"
          class="site-header__search-input"
          type="search"
          name="q"
          placeholder="Search products, brands, and stores"
          autocomplete="off"
        />
      </form>

      <div class="site-header__actions" aria-label="Quick actions">
        <RouterLink class="site-header__icon-link" :to="accountTarget" aria-label="Account">
          <svg viewBox="0 0 24 24" aria-hidden="true">
            <circle cx="12" cy="8.5" r="3.75"></circle>
            <path d="M4.5 19.25c1.4-3.35 4.3-5 7.5-5s6.1 1.65 7.5 5"></path>
          </svg>
        </RouterLink>

        <RouterLink class="site-header__icon-link" to="/wishlist" aria-label="Wishlist">
          <svg viewBox="0 0 24 24" aria-hidden="true">
            <path d="M12 20.25 5.35 14.1a5 5 0 0 1-.55-6.75 4.25 4.25 0 0 1 6.15-.25L12 8.15l1.05-1.05a4.25 4.25 0 0 1 6.15.25 5 5 0 0 1-.55 6.75Z"></path>
          </svg>
        </RouterLink>

        <button class="site-header__icon-link site-header__icon-button" type="button" aria-label="Cart" @click="openCartDrawer">
          <svg viewBox="0 0 24 24" aria-hidden="true">
            <path d="M3 4.75h2.1l1.45 8.65a1 1 0 0 0 .98.82h9.86a1 1 0 0 0 .97-.73L19.8 8.5H6.3"></path>
            <circle cx="9.25" cy="19.1" r="1.25"></circle>
            <circle cx="16.25" cy="19.1" r="1.25"></circle>
          </svg>
          <span v-if="cartBadgeLabel" class="site-header__icon-badge">{{ cartBadgeLabel }}</span>
        </button>
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
        <p>Free shipping on all orders before</p>

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
</template>

<style scoped>
.site-header {
  position: sticky;
  top: 0;
  z-index: 1000;
  width: 100%;
  background: #ffffff;
  border-bottom: 1px solid #ececec;
  font-family: "Inter", "Segoe UI", "Helvetica Neue", Arial, sans-serif;
}

.site-header__main {
  width: min(100%, 1280px);
  margin: 0 auto;
  box-sizing: border-box;
  min-height: 124px;
  display: grid;
  grid-template-columns: auto minmax(260px, 560px) auto;
  align-items: center;
  gap: 18px;
  justify-content: space-between;
  padding: 0 24px;
  background: #ffffff;
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
  width: 114px;
  height: 114px;
  display: block;
  object-fit: contain;
}

.site-header__search {
  width: 100%;
  min-width: 0;
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
  height: 42px;
  border: 1px solid #e5e5e5;
  border-radius: 999px;
  padding: 0 18px;
  background: #fbfbfb;
  color: #111111;
  font-size: 14px;
  line-height: 1;
  outline: none;
  transition:
    border-color 160ms ease,
    background-color 160ms ease;
}

.site-header__search-input::placeholder {
  color: #8a8a8a;
}

.site-header__search-input:focus {
  border-color: #cfcfcf;
  background: #ffffff;
}

.site-header__actions {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 16px;
}

.site-header__icon-link {
  position: relative;
  width: 20px;
  height: 20px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  color: #1a1a1a;
  text-decoration: none;
  opacity: 0.94;
  transition:
    opacity 160ms ease,
    color 160ms ease;
}

.site-header__icon-button {
  border: 0;
  background: transparent;
  padding: 0;
  cursor: pointer;
}

.site-header__icon-link:hover {
  opacity: 1;
  color: #111111;
}

.site-header__icon-link svg {
  width: 20px;
  height: 20px;
  stroke: currentColor;
  stroke-width: 1.7;
  fill: none;
  stroke-linecap: round;
  stroke-linejoin: round;
}

.site-header__icon-badge {
  position: absolute;
  top: -8px;
  right: -12px;
  min-width: 16px;
  height: 16px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  padding: 0 4px;
  border-radius: 999px;
  background: #111111;
  color: #ffffff;
  font-size: 10px;
  font-weight: 700;
  line-height: 1;
}

.site-header__category-strip {
  border-top: 1px solid #f4f4f4;
  border-bottom: 1px solid #f0f0f0;
  background: #ffffff;
  padding: 0;
}

.site-header__category-nav {
  width: min(100%, 1280px);
  margin: 0 auto;
  box-sizing: border-box;
  min-height: 46px;
  display: flex;
  align-items: center;
  gap: 18px;
  padding: 0 24px;
  overflow-x: auto;
  scrollbar-width: none;
}

.site-header__category-nav::-webkit-scrollbar {
  display: none;
}

.site-header__category-link {
  position: relative;
  flex: 0 0 auto;
  color: #666666;
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
  background: #111111;
  opacity: 0;
  transition: opacity 160ms ease;
}

.site-header__category-link:hover {
  color: #111111;
}

.site-header__category-link--active {
  color: #111111;
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
  border: 1px solid #f4d2c0;
  border-radius: 999px;
  background: #fff7f2;
  color: #d95716;
  font-weight: 700;
}

.site-header__category-link--business::after {
  display: none;
}

.site-header__category-link--business:hover,
.site-header__category-link--business.site-header__category-link--active {
  border-color: #f36a20;
  background: #f36a20;
  color: #ffffff;
}

.site-header__promo {
  min-height: 38px;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 0;
  background: #f36a20;
}

.site-header__promo-inner {
  width: min(100%, 1280px);
  margin: 0 auto;
  box-sizing: border-box;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 18px;
  padding: 0 24px;
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
    gap: 16px;
    min-height: 118px;
    padding: 0 18px;
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
    padding: 0 14px;
    padding-top: 14px;
    padding-bottom: 14px;
  }

  .site-header__brand {
    grid-area: brand;
  }

  .site-header__search {
    grid-area: search;
  }

  .site-header__actions {
    grid-area: actions;
    gap: 14px;
  }

  .site-header__brand {
    justify-content: flex-start;
  }

  .site-header__brand-image {
    width: 96px;
    height: 96px;
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
