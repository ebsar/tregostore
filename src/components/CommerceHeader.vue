<script setup>
import { computed, nextTick, onBeforeUnmount, onMounted, reactive, ref, watch } from "vue";
import { RouterLink, useRoute, useRouter } from "vue-router";
import HeaderAccountDropdown from "./HeaderAccountDropdown.vue";
import HeaderCartOverlay from "./HeaderCartOverlay.vue";
import HeaderTrackOrderOverlay from "./HeaderTrackOrderOverlay.vue";
import HeaderWishlistOverlay from "./HeaderWishlistOverlay.vue";
import { PRODUCT_PAGE_SECTION_OPTIONS } from "../lib/product-catalog";
import { setPendingVisualSearchFile } from "../lib/visual-search-transfer";
import { appState } from "../stores/app-state";

const PROMO_BAR_DISMISSED_KEY = "tregio_promo_bar_dismissed";

const route = useRoute();
const router = useRouter();
const searchQuery = ref("");
const visualSearchInputElement = ref(null);
const accountDropdownOpen = ref(false);
const cartOverlayOpen = ref(false);
const wishlistOverlayOpen = ref(false);
const trackOrderOverlayOpen = ref(false);
const mobileMenuOpen = ref(false);
const promoBarDismissed = ref(false);
const accountMenuElement = ref(null);
const accountButtonElement = ref(null);
const mobileMenuElement = ref(null);
const mobileMenuButtonElement = ref(null);
const accountMenuPosition = reactive({
  top: 0,
  left: 0,
  width: 380,
});
let loginOverlayScrollY = 0;

const socialItems = [
  { label: "Twitter", icon: "twitter" },
  { label: "Facebook", icon: "facebook" },
  { label: "Pinterest", icon: "pinterest" },
  { label: "Instagram", icon: "instagram" },
];

const quickLinks = computed(() => ([
  {
    label: "Track Order",
    action: "track-order",
  },
  {
    label: "Compare",
    to: "/krahaso",
  },
  {
    label: "Customer Support",
    to: "/mesazhet",
  },
  {
    label: "Need Help",
    to: "/refund-returne",
  },
]));

const actionItems = computed(() => ([
  {
    key: "cart",
    label: "Cart",
    to: "/cart",
    badge: appState.cartCount > 0 ? (appState.cartCount > 99 ? "99+" : String(appState.cartCount)) : "",
    icon: "cart",
  },
  {
    key: "wishlist",
    label: "Wishlist",
    to: "/wishlist",
    badge: "",
    icon: "heart",
  },
]));

const headerCategories = computed(() =>
  PRODUCT_PAGE_SECTION_OPTIONS.slice(0, 6).map((section) => ({
    value: section.value,
    label: section.label,
  })),
);
const showLoginOverlay = computed(() => accountDropdownOpen.value && !appState.user);
const showAccountMenu = computed(() => accountDropdownOpen.value && Boolean(appState.user));
const showAnyBlockingOverlay = computed(
  () => showLoginOverlay.value || cartOverlayOpen.value || wishlistOverlayOpen.value || trackOrderOverlayOpen.value,
);
const accountMenuPanelStyle = computed(() => ({
  top: `${accountMenuPosition.top}px`,
  left: `${accountMenuPosition.left}px`,
  width: `${accountMenuPosition.width}px`,
}));

watch(
  () => route.query.q,
  (value) => {
    searchQuery.value = String(value || "").trim();
  },
  { immediate: true },
);

watch(
  () => route.fullPath,
  () => {
    accountDropdownOpen.value = false;
    cartOverlayOpen.value = false;
    wishlistOverlayOpen.value = false;
    trackOrderOverlayOpen.value = false;
    mobileMenuOpen.value = false;
  },
);

watch(showAccountMenu, async (isOpen) => {
  if (!isOpen) {
    return;
  }

  await nextTick();
  updateAccountMenuPosition();
});

watch(showAnyBlockingOverlay, (isOpen) => {
  syncLoginOverlayScrollLock(isOpen);
});

onMounted(() => {
  try {
    promoBarDismissed.value = window.localStorage.getItem(PROMO_BAR_DISMISSED_KEY) === "1";
  } catch (error) {
    console.error(error);
  }
  document.addEventListener("pointerdown", handlePointerDownOutside);
  document.addEventListener("keydown", handleEscapeDismiss);
  window.addEventListener("resize", handleViewportChange);
  window.addEventListener("scroll", handleViewportChange, { passive: true });
  window.addEventListener("tregio:open-track-order", handleOpenTrackOrderEvent);
});

onBeforeUnmount(() => {
  document.removeEventListener("pointerdown", handlePointerDownOutside);
  document.removeEventListener("keydown", handleEscapeDismiss);
  window.removeEventListener("resize", handleViewportChange);
  window.removeEventListener("scroll", handleViewportChange);
  window.removeEventListener("tregio:open-track-order", handleOpenTrackOrderEvent);
  syncLoginOverlayScrollLock(false);
});

async function submitSearch() {
  const normalizedQuery = String(searchQuery.value || "").trim();
  await router.push(
    normalizedQuery
      ? {
          path: "/kerko",
          query: { q: normalizedQuery },
        }
      : "/kerko",
  );
}

function openVisualSearchPicker() {
  visualSearchInputElement.value?.click();
}

async function handleVisualSearchSelection(event) {
  const file = event?.target?.files?.[0];
  if (!file) {
    return;
  }

  setPendingVisualSearchFile(file);
  await router.push("/kerko");

  if (event?.target) {
    event.target.value = "";
  }
}

function navigateToCategory(event) {
  const nextValue = String(event?.target?.value || "").trim();
  if (!nextValue) {
    router.push("/kerko");
    return;
  }

  router.push({
    path: "/kerko",
    query: { pageSection: nextValue },
  });
}

async function toggleAccountDropdown() {
  cartOverlayOpen.value = false;
  wishlistOverlayOpen.value = false;
  mobileMenuOpen.value = false;

  if (appState.user) {
    accountDropdownOpen.value = !accountDropdownOpen.value;
    return;
  }

  accountDropdownOpen.value = !accountDropdownOpen.value;
}

function closeAccountDropdown() {
  accountDropdownOpen.value = false;
}

function openCartOverlay() {
  accountDropdownOpen.value = false;
  wishlistOverlayOpen.value = false;
  trackOrderOverlayOpen.value = false;
  mobileMenuOpen.value = false;
  cartOverlayOpen.value = true;
}

function closeCartOverlay() {
  cartOverlayOpen.value = false;
}

function handleCartLoginRequest() {
  cartOverlayOpen.value = false;
  accountDropdownOpen.value = true;
}

function openWishlistOverlay() {
  accountDropdownOpen.value = false;
  cartOverlayOpen.value = false;
  trackOrderOverlayOpen.value = false;
  mobileMenuOpen.value = false;
  wishlistOverlayOpen.value = true;
}

function closeWishlistOverlay() {
  wishlistOverlayOpen.value = false;
}

function handleWishlistLoginRequest() {
  wishlistOverlayOpen.value = false;
  accountDropdownOpen.value = true;
}

function openTrackOrderOverlay() {
  accountDropdownOpen.value = false;
  cartOverlayOpen.value = false;
  wishlistOverlayOpen.value = false;
  mobileMenuOpen.value = false;
  trackOrderOverlayOpen.value = true;
}

function closeTrackOrderOverlay() {
  trackOrderOverlayOpen.value = false;
}

async function handleTrackOrderSuccess(snapshot) {
  trackOrderOverlayOpen.value = false;
  await router.push({
    path: "/track-order",
    query: snapshot?.orderId ? { id: String(snapshot.orderId) } : undefined,
  });
}

function toggleMobileMenu() {
  accountDropdownOpen.value = false;
  cartOverlayOpen.value = false;
  wishlistOverlayOpen.value = false;
  trackOrderOverlayOpen.value = false;
  mobileMenuOpen.value = !mobileMenuOpen.value;
}

function closeMobileMenu() {
  mobileMenuOpen.value = false;
}

function handleOpenTrackOrderEvent() {
  openTrackOrderOverlay();
}

function dismissPromoBar() {
  promoBarDismissed.value = true;
  try {
    window.localStorage.setItem(PROMO_BAR_DISMISSED_KEY, "1");
  } catch (error) {
    console.error(error);
  }
}

async function openAccountFromMobileMenu() {
  mobileMenuOpen.value = false;

  if (appState.user) {
    accountDropdownOpen.value = true;
    return;
  }

  accountDropdownOpen.value = true;
}

function syncLoginOverlayScrollLock(isOpen) {
  if (typeof document === "undefined" || typeof window === "undefined") {
    return;
  }

  const { body, documentElement } = document;

  body.classList.toggle("commerce-login-overlay-open", isOpen);
  documentElement.classList.toggle("commerce-login-overlay-open", isOpen);

  if (isOpen) {
    loginOverlayScrollY = window.scrollY || window.pageYOffset || 0;
    body.style.position = "fixed";
    body.style.top = `-${loginOverlayScrollY}px`;
    body.style.left = "0";
    body.style.right = "0";
    body.style.width = "100%";
    body.style.overflow = "hidden";
    documentElement.style.overflow = "hidden";
    return;
  }

  body.style.position = "";
  body.style.top = "";
  body.style.left = "";
  body.style.right = "";
  body.style.width = "";
  body.style.overflow = "";
  documentElement.style.overflow = "";

  if (loginOverlayScrollY) {
    window.scrollTo(0, loginOverlayScrollY);
    loginOverlayScrollY = 0;
  }
}

function handlePointerDownOutside(event) {
  const target = event.target;

  if (accountDropdownOpen.value && appState.user) {
    const menuElement = accountMenuElement.value;
    const buttonElement = accountButtonElement.value;

    if (!menuElement?.contains(target) && !buttonElement?.contains(target)) {
      accountDropdownOpen.value = false;
    }
  }

  if (mobileMenuOpen.value) {
    const menuElement = mobileMenuElement.value;
    const buttonElement = mobileMenuButtonElement.value;

    if (!menuElement?.contains(target) && !buttonElement?.contains(target)) {
      mobileMenuOpen.value = false;
    }
  }
}

function handleEscapeDismiss(event) {
  if (event.key === "Escape") {
    accountDropdownOpen.value = false;
    cartOverlayOpen.value = false;
    wishlistOverlayOpen.value = false;
    trackOrderOverlayOpen.value = false;
    mobileMenuOpen.value = false;
  }
}

async function handleQuickLinkClick(link) {
  if (link?.action === "track-order") {
    openTrackOrderOverlay();
    return;
  }

  closeMobileMenu();
  if (link?.to) {
    await router.push(link.to);
  }
}

function handleViewportChange() {
  if (showAccountMenu.value) {
    updateAccountMenuPosition();
  }
}

function updateAccountMenuPosition() {
  if (typeof window === "undefined") {
    return;
  }

  const buttonRect = accountButtonElement.value?.getBoundingClientRect();
  if (!buttonRect) {
    return;
  }

  const viewportPadding = 12;
  const dropdownWidth = Math.min(window.innerWidth - viewportPadding * 2, window.innerWidth <= 760 ? 420 : 380);
  const preferredLeft = buttonRect.right - dropdownWidth;
  accountMenuPosition.width = dropdownWidth;
  accountMenuPosition.left = Math.max(
    viewportPadding,
    Math.min(preferredLeft, window.innerWidth - dropdownWidth - viewportPadding),
  );
  accountMenuPosition.top = buttonRect.bottom + 14;
}

function renderIcon(icon) {
  switch (icon) {
    case "twitter":
      return "M18.9 7.2c.7-.4 1.2-1 1.5-1.8-.6.4-1.4.7-2.1.8a3.5 3.5 0 0 0-6 3.2 9.9 9.9 0 0 1-7.2-3.6 3.5 3.5 0 0 0 1.1 4.7c-.6 0-1.1-.2-1.6-.4 0 1.7 1.2 3.1 2.8 3.4-.3.1-.7.1-1 .1-.2 0-.5 0-.7-.1.5 1.5 1.9 2.6 3.6 2.6A7.1 7.1 0 0 1 4 17.9a9.9 9.9 0 0 0 5.4 1.6c6.5 0 10.1-5.4 10.1-10.1v-.5c.7-.5 1.3-1.1 1.8-1.7-.7.3-1.4.5-2.1.6.7-.4 1.3-1 1.7-1.7-.7.4-1.5.7-2.3.9z";
    case "facebook":
      return "M13.5 21v-8h2.7l.4-3h-3.1V8.1c0-.9.3-1.6 1.7-1.6h1.5V3.8c-.3 0-1.2-.1-2.3-.1-2.3 0-3.8 1.4-3.8 4v2.3H8v3h2.6v8z";
    case "pinterest":
      return "M12.2 2C6.7 2 4 5.9 4 9.8c0 2.4.9 4.5 2.8 5.3.3.1.5 0 .6-.2.1-.2.2-.8.2-1-.1-.2-.6-.7-.6-1.7 0-2.2 1.7-4.2 4.4-4.2 2.4 0 3.7 1.5 3.7 3.4 0 2.5-1.1 4.7-2.8 4.7-.9 0-1.6-.8-1.4-1.8.3-1.2.8-2.5.8-3.3 0-.8-.4-1.4-1.3-1.4-1 0-1.8 1-1.8 2.4 0 .9.3 1.5.3 1.5l-1.2 5c-.4 1.7-.1 3.8-.1 4 .1.2.2.2.3.1.1-.2 1.2-1.5 1.6-3.6l.5-2c.2-.4.9-.7 1.6-.7 2.1 0 3.6-1.9 3.6-4.4 0-2.4-2-4.7-5.1-4.7z";
    case "instagram":
      return "M12 7.3a4.7 4.7 0 1 0 0 9.4 4.7 4.7 0 0 0 0-9.4zm0 7.7a3 3 0 1 1 0-6.1 3 3 0 0 1 0 6.1zm5.9-7.9a1.1 1.1 0 1 1 0 2.2 1.1 1.1 0 0 1 0-2.2zM12 3.8c2.7 0 3 .1 4 .1 1 0 1.7.2 2.3.5.7.2 1.2.6 1.7 1.1.5.5.9 1 1.1 1.7.3.6.4 1.3.5 2.3.1 1 .1 1.3.1 4s-.1 3-.1 4c0 1-.2 1.7-.5 2.3-.2.7-.6 1.2-1.1 1.7-.5.5-1 .9-1.7 1.1-.6.3-1.3.4-2.3.5-1 .1-1.3.1-4 .1s-3-.1-4-.1c-1 0-1.7-.2-2.3-.5a4.7 4.7 0 0 1-1.7-1.1 4.7 4.7 0 0 1-1.1-1.7c-.3-.6-.4-1.3-.5-2.3-.1-1-.1-1.3-.1-4s.1-3 .1-4c0-1 .2-1.7.5-2.3.2-.7.6-1.2 1.1-1.7.5-.5 1-.9 1.7-1.1.6-.3 1.3-.4 2.3-.5 1-.1 1.3-.1 4-.1z";
    case "cart":
      return "M3 4.5h2.2l1.45 9.1a1 1 0 0 0 .99.84h9.88a1 1 0 0 0 .97-.74l1.45-5.95H6.35M9.25 19.25a1.25 1.25 0 1 1 0 2.5 1.25 1.25 0 0 1 0-2.5Zm7 0a1.25 1.25 0 1 1 0 2.5 1.25 1.25 0 0 1 0-2.5Z";
    case "heart":
      return "M12 20.5s-7.5-4.35-9.2-8.2C1.45 9.2 3.15 5.5 6.95 5.5c2.06 0 3.33 1.05 4.07 2.17C11.76 6.55 13.03 5.5 15.1 5.5c3.78 0 5.5 3.68 4.15 6.8C17.55 16.15 12 20.5 12 20.5Z";
    case "user":
      return "M12 12.2a4.45 4.45 0 1 0 0-8.9 4.45 4.45 0 0 0 0 8.9Zm-7.05 7.5c.76-2.9 3.62-4.95 7.05-4.95s6.29 2.05 7.05 4.95";
    default:
      return "";
  }
}
</script>

<template>
  <header class="commerce-header">
    <input
      ref="visualSearchInputElement"
      class="commerce-home-visual-input"
      type="file"
      accept="image/*"
      hidden
      @change="handleVisualSearchSelection"
    >

    <section class="commerce-home-shell" aria-label="Header i marketplace">
      <div v-if="!promoBarDismissed" class="commerce-home-promo-bar">
        <div class="commerce-home-promo-copy">
          <span class="commerce-home-promo-badge">New user</span>
          <strong>Up to 20% extra</strong>
        </div>
        <div class="commerce-home-promo-actions">
          <RouterLink class="commerce-home-promo-cta" to="/signup">
            Create account
          </RouterLink>
          <button
            type="button"
            class="commerce-home-promo-close"
            aria-label="Close announcement"
            @click="dismissPromoBar"
          >
            ×
          </button>
        </div>
      </div>

      <div class="commerce-home-info-bar">
        <p>Welcome to TREGIO online marketplace store.</p>
        <div class="commerce-home-info-socials">
          <span>Follow us:</span>
          <span
            v-for="item in socialItems"
            :key="item.label"
            class="commerce-home-info-icon"
            :aria-label="item.label"
          >
            <svg viewBox="0 0 24 24" aria-hidden="true">
              <path :d="renderIcon(item.icon)" />
            </svg>
          </span>
          <span class="commerce-home-info-meta">Eng</span>
          <span class="commerce-home-info-meta">USD</span>
        </div>
      </div>

      <div class="commerce-home-header-bar">
        <RouterLink class="commerce-home-brand" to="/">
          <img src="/trego-logo.webp?v=20260410" alt="TREGIO" width="1024" height="1024">
          <span class="commerce-home-brand-wordmark">TREGIO</span>
        </RouterLink>

        <form class="commerce-home-search" @submit.prevent="submitSearch">
          <input
            v-model="searchQuery"
            class="commerce-home-search-input"
            type="search"
            placeholder="Search for anything..."
            autocomplete="off"
          >
          <button
            class="commerce-home-search-visual"
            type="button"
            aria-label="Visual search"
            @click="openVisualSearchPicker"
          >
            <svg viewBox="0 0 24 24" aria-hidden="true">
              <path d="M7 8.5A1.5 1.5 0 0 1 8.5 7h1.2l1-1.3a1.5 1.5 0 0 1 1.2-.6h.2a1.5 1.5 0 0 1 1.2.6l1 1.3h1.2A1.5 1.5 0 0 1 18 8.5v7A1.5 1.5 0 0 1 16.5 17h-8A1.5 1.5 0 0 1 7 15.5Zm5.5 6a3 3 0 1 0 0-6 3 3 0 0 0 0 6z" />
            </svg>
          </button>
          <button class="commerce-home-search-submit" type="submit" aria-label="Search">
            <svg viewBox="0 0 24 24" aria-hidden="true">
              <path d="M10.5 4a6.5 6.5 0 1 0 4 11.6l4 4 1.4-1.4-4-4A6.5 6.5 0 0 0 10.5 4zm0 2a4.5 4.5 0 1 1 0 9 4.5 4.5 0 0 1 0-9z" />
            </svg>
          </button>
        </form>

        <div class="commerce-home-header-actions" aria-label="Veprimet kryesore">
          <button
            type="button"
            class="commerce-home-header-action"
            aria-label="Open cart"
            @click.stop="openCartOverlay"
          >
            <span v-if="actionItems[0]?.badge" class="commerce-home-header-badge">{{ actionItems[0].badge }}</span>
            <svg class="commerce-home-header-action-icon" viewBox="0 0 24 24" aria-hidden="true">
              <path :d="renderIcon('cart')" />
            </svg>
          </button>

          <button
            class="commerce-home-header-action"
            type="button"
            aria-label="Wishlist"
            @click.stop="openWishlistOverlay"
          >
            <svg class="commerce-home-header-action-icon" viewBox="0 0 24 24" aria-hidden="true">
              <path :d="renderIcon('heart')" />
            </svg>
          </button>

          <div class="commerce-home-header-account">
            <button
              ref="accountButtonElement"
              class="commerce-home-header-action"
              type="button"
              :aria-expanded="accountDropdownOpen ? 'true' : 'false'"
              :aria-label="appState.user ? 'Open account menu' : 'Open login menu'"
              @click.stop="toggleAccountDropdown"
            >
              <svg class="commerce-home-header-action-icon" viewBox="0 0 24 24" aria-hidden="true">
                <path :d="renderIcon('user')" />
              </svg>
            </button>

          </div>
        </div>

        <button
          ref="mobileMenuButtonElement"
          type="button"
          class="commerce-home-mobile-toggle"
          :aria-expanded="mobileMenuOpen ? 'true' : 'false'"
          aria-label="Open mobile menu"
          @click.stop="toggleMobileMenu"
        >
          <span></span>
          <span></span>
          <span></span>
        </button>
      </div>

      <div class="commerce-home-subnav">
        <div class="commerce-home-subnav-left">
          <select class="commerce-home-subnav-select" @change="navigateToCategory">
            <option value="">All Category</option>
            <option
              v-for="category in headerCategories"
              :key="category.value"
              :value="category.value"
            >
              {{ category.label }}
            </option>
          </select>

          <nav class="commerce-home-subnav-links" aria-label="Shortcut links">
            <component
              v-for="link in quickLinks"
              :key="link.label"
              :is="link.to ? RouterLink : 'button'"
              :to="link.to || undefined"
              type="button"
              @click="!link.to ? handleQuickLinkClick(link) : undefined"
            >
              {{ link.label }}
            </component>
          </nav>
        </div>

        <div class="commerce-home-subnav-spacer" aria-hidden="true"></div>
      </div>

      <div
        v-if="mobileMenuOpen"
        ref="mobileMenuElement"
        class="commerce-home-mobile-panel"
      >
        <form class="commerce-home-mobile-search" @submit.prevent="submitSearch">
          <input
            v-model="searchQuery"
            class="commerce-home-mobile-search-input"
            type="search"
            placeholder="Search for anything..."
            autocomplete="off"
          >
          <button class="commerce-home-mobile-search-submit" type="submit" aria-label="Search">
            <svg viewBox="0 0 24 24" aria-hidden="true">
              <path d="M10.5 4a6.5 6.5 0 1 0 4 11.6l4 4 1.4-1.4-4-4A6.5 6.5 0 0 0 10.5 4zm0 2a4.5 4.5 0 1 1 0 9 4.5 4.5 0 0 1 0-9z" />
            </svg>
          </button>
        </form>

        <div class="commerce-home-mobile-actions">
          <button type="button" class="commerce-home-mobile-action" @click="openCartOverlay">
            Cart
          </button>
          <button type="button" class="commerce-home-mobile-action" @click="openWishlistOverlay">
            Wishlist
          </button>
          <button type="button" class="commerce-home-mobile-action" @click="openAccountFromMobileMenu">
            {{ appState.user ? "Account" : "Login" }}
          </button>
        </div>

        <select class="commerce-home-mobile-select" @change="navigateToCategory">
          <option value="">All Category</option>
          <option
            v-for="category in headerCategories"
            :key="`mobile-${category.value}`"
            :value="category.value"
          >
            {{ category.label }}
          </option>
        </select>

        <nav class="commerce-home-mobile-links" aria-label="Mobile shortcut links">
          <component
            v-for="link in quickLinks"
            :key="`mobile-${link.label}`"
            :is="link.to ? RouterLink : 'button'"
            :to="link.to || undefined"
            type="button"
            @click="!link.to ? handleQuickLinkClick(link) : closeMobileMenu()"
          >
            {{ link.label }}
          </component>
        </nav>
      </div>
    </section>
  </header>

  <Teleport to="body">
    <div
      v-if="showAccountMenu"
      ref="accountMenuElement"
      class="commerce-home-account-dropdown"
      :style="accountMenuPanelStyle"
    >
      <HeaderAccountDropdown
        @close="closeAccountDropdown"
        @authenticated="closeAccountDropdown"
      />
    </div>
  </Teleport>

  <Teleport to="body">
    <div
      v-if="showLoginOverlay"
      class="commerce-home-login-overlay"
      role="dialog"
      aria-modal="true"
      aria-label="Login"
      @click="closeAccountDropdown"
    >
      <div class="commerce-home-login-overlay-panel" @click.stop>
        <HeaderAccountDropdown
          expanded
          show-close
          @close="closeAccountDropdown"
          @authenticated="closeAccountDropdown"
        />
      </div>
    </div>
  </Teleport>

  <Teleport to="body">
    <div
      v-if="cartOverlayOpen"
      class="commerce-home-login-overlay"
      role="dialog"
      aria-modal="true"
      aria-label="Cart"
      @click="closeCartOverlay"
    >
      <div class="commerce-home-login-overlay-panel commerce-home-login-overlay-panel--cart" @click.stop>
        <HeaderCartOverlay
          @close="closeCartOverlay"
          @request-login="handleCartLoginRequest"
        />
      </div>
    </div>
  </Teleport>

  <Teleport to="body">
    <div
      v-if="wishlistOverlayOpen"
      class="commerce-home-login-overlay"
      role="dialog"
      aria-modal="true"
      aria-label="Wishlist"
      @click="closeWishlistOverlay"
    >
      <div class="commerce-home-login-overlay-panel commerce-home-login-overlay-panel--cart" @click.stop>
        <HeaderWishlistOverlay
          modal-only
          @close="closeWishlistOverlay"
          @request-login="handleWishlistLoginRequest"
        />
      </div>
    </div>
  </Teleport>

  <Teleport to="body">
    <div
      v-if="trackOrderOverlayOpen"
      class="commerce-home-login-overlay"
      role="dialog"
      aria-modal="true"
      aria-label="Track Order"
      @click="closeTrackOrderOverlay"
    >
      <div class="commerce-home-login-overlay-panel commerce-home-login-overlay-panel--track" @click.stop>
        <HeaderTrackOrderOverlay
          show-close
          @close="closeTrackOrderOverlay"
          @tracked="handleTrackOrderSuccess"
        />
      </div>
    </div>
  </Teleport>
</template>

<style scoped>
.commerce-header {
  position: sticky;
  top: 0;
  left: 0;
  right: 0;
  z-index: 70;
  width: 100%;
}

.commerce-home-shell {
  display: grid;
  gap: 0;
  width: 100%;
  overflow: hidden;
  background: #ffffff;
  border-bottom: 1px solid rgba(15, 23, 42, 0.08);
  box-shadow: 0 16px 38px rgba(15, 23, 42, 0.08);
}

.commerce-home-promo-bar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  padding: 16px 28px;
  background: #171a1f;
  color: #f8fafc;
}

.commerce-home-promo-copy {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 14px;
}

.commerce-home-promo-copy strong {
  font-size: clamp(1.15rem, 2vw, 1.85rem);
  font-weight: 800;
  letter-spacing: -0.03em;
}

.commerce-home-promo-actions {
  display: inline-flex;
  align-items: center;
  gap: 12px;
}

.commerce-home-promo-badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-height: 38px;
  padding: 0 14px;
  border-radius: 10px;
  background: #f7c948;
  color: #171717;
  font-weight: 800;
}

.commerce-home-promo-cta {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-height: 46px;
  padding: 0 18px;
  border-radius: 12px;
  border: 0;
  color: #171717;
  background: #f7c948;
  font-weight: 800;
  text-decoration: none;
  transition: transform 0.18s ease, box-shadow 0.18s ease, opacity 0.18s ease;
}

.commerce-home-promo-cta:hover {
  transform: translateY(-1px);
  box-shadow: 0 16px 28px rgba(247, 201, 72, 0.24);
}

.commerce-home-promo-close {
  display: inline-flex;
  width: 42px;
  height: 42px;
  align-items: center;
  justify-content: center;
  border: 1px solid rgba(255, 255, 255, 0.12);
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.08);
  color: rgba(255, 255, 255, 0.92);
  font-size: 1.5rem;
  line-height: 1;
  cursor: pointer;
  transition: background 0.18s ease, transform 0.18s ease, opacity 0.18s ease;
}

.commerce-home-promo-close:hover {
  background: rgba(255, 255, 255, 0.14);
  transform: translateY(-1px);
}

.commerce-home-info-bar,
.commerce-home-header-bar {
  display: grid;
  align-items: center;
  gap: 18px;
  padding: 12px 28px;
  background: #2a3447;
  color: rgba(255, 255, 255, 0.94);
}

.commerce-home-info-bar {
  grid-template-columns: minmax(0, 1fr) auto;
  font-size: 0.88rem;
  background: #2a3447;
}

.commerce-home-info-bar p {
  margin: 0;
}

.commerce-home-info-socials {
  display: inline-flex;
  align-items: center;
  gap: 10px;
  flex-wrap: wrap;
}

.commerce-home-info-meta {
  color: rgba(255, 255, 255, 0.82);
  font-weight: 700;
}

.commerce-home-info-icon {
  display: inline-flex;
  width: 22px;
  height: 22px;
  align-items: center;
  justify-content: center;
  border-radius: 999px;
  color: #fff;
}

.commerce-home-info-icon svg {
  width: 14px;
  height: 14px;
  fill: currentColor;
}

.commerce-home-header-bar {
  grid-template-columns: auto minmax(0, 1fr) auto;
  padding-top: 22px;
  padding-bottom: 22px;
  background: #2a3447;
}

.commerce-home-brand {
  display: inline-flex;
  align-items: center;
  gap: 12px;
  color: #fff;
  text-decoration: none;
}

.commerce-home-brand img {
  width: 70px;
  height: 70px;
  object-fit: contain;
}

.commerce-home-brand-wordmark {
  display: none;
  color: #fff;
  font-size: 1.7rem;
  font-weight: 800;
  letter-spacing: -0.04em;
}

.commerce-home-search {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto auto;
  align-items: center;
  gap: 0;
  min-height: 58px;
  overflow: hidden;
  border-radius: 14px;
  background: #fff;
  box-shadow: 0 12px 30px rgba(15, 23, 42, 0.14);
}

.commerce-home-search-input,
.commerce-home-search-visual,
.commerce-home-search-submit {
  height: 100%;
  border: 0;
  background: transparent;
}

.commerce-home-search-input {
  width: 100%;
  padding: 0 16px;
  color: #0f172a;
  font-size: 0.98rem;
}

.commerce-home-search-input:focus {
  outline: none;
}

.commerce-home-search-visual,
.commerce-home-search-submit {
  display: inline-flex;
  width: 54px;
  align-items: center;
  justify-content: center;
  color: #64748b;
  cursor: pointer;
}

.commerce-home-search-submit {
  color: #163b67;
}

.commerce-home-search-visual svg,
.commerce-home-search-submit svg {
  width: 20px;
  height: 20px;
  fill: currentColor;
}

.commerce-home-header-actions {
  display: inline-flex;
  align-items: center;
  gap: 10px;
}

.commerce-home-mobile-toggle {
  display: none;
  align-items: center;
  justify-content: center;
  width: 52px;
  height: 52px;
  padding: 0;
  border: 0;
  background: transparent;
  color: #fff;
  cursor: pointer;
}

.commerce-home-mobile-toggle span {
  display: block;
  width: 30px;
  height: 2.5px;
  border-radius: 999px;
  background: currentColor;
  transform-origin: center;
  transition: transform 0.18s ease, opacity 0.18s ease;
}

.commerce-home-mobile-toggle {
  gap: 6px;
  flex-direction: column;
}

.commerce-home-mobile-toggle[aria-expanded="true"] span:nth-child(1) {
  transform: translateY(8px) rotate(45deg);
}

.commerce-home-mobile-toggle[aria-expanded="true"] span:nth-child(2) {
  opacity: 0;
}

.commerce-home-mobile-toggle[aria-expanded="true"] span:nth-child(3) {
  transform: translateY(-8px) rotate(-45deg);
}

.commerce-home-header-account {
  position: relative;
}

.commerce-home-header-action {
  position: relative;
  display: inline-flex;
  width: 46px;
  height: 46px;
  align-items: center;
  justify-content: center;
  border-radius: 999px;
  color: #fff;
  text-decoration: none;
  background: transparent;
  border: 0;
  box-shadow: none;
  cursor: pointer;
  transition: color 0.18s ease, transform 0.18s ease, opacity 0.18s ease;
}

.commerce-home-header-action:hover {
  color: #ffd36b;
  transform: translateY(-1px);
}

.commerce-home-header-action:focus-visible {
  outline: 2px solid rgba(255, 211, 107, 0.75);
  outline-offset: 4px;
}

.commerce-home-header-action[aria-expanded="true"] {
  color: #ffd36b;
}

.commerce-home-header-action-icon {
  width: 23px;
  height: 23px;
  fill: none;
  stroke: currentColor;
  stroke-width: 1.9;
  stroke-linecap: round;
  stroke-linejoin: round;
  overflow: visible;
}

.commerce-home-header-badge {
  position: absolute;
  top: -5px;
  right: -4px;
  display: inline-flex;
  min-width: 20px;
  height: 20px;
  padding: 0 5px;
  align-items: center;
  justify-content: center;
  border-radius: 999px;
  background: #fff;
  color: #163b67;
  font-size: 0.66rem;
  font-weight: 800;
  line-height: 18px;
  text-align: center;
}

.commerce-home-account-dropdown {
  position: fixed;
  z-index: 121;
}

.commerce-home-login-overlay {
  position: fixed;
  inset: 0;
  z-index: 120;
  display: flex;
  align-items: flex-start;
  justify-content: center;
  overflow-y: auto;
  overscroll-behavior: contain;
  padding: clamp(88px, 10vh, 148px) 16px max(18px, env(safe-area-inset-bottom));
  background: rgba(15, 23, 42, 0.34);
  backdrop-filter: blur(4px);
  -webkit-backdrop-filter: blur(4px);
}

.commerce-home-login-overlay-panel {
  position: relative;
  display: flex;
  justify-content: center;
  flex: 0 0 auto;
  width: min(432px, calc(100vw - 24px));
  max-width: 100%;
}

.commerce-home-login-overlay-panel--cart {
  width: min(760px, calc(100vw - 32px));
}

.commerce-home-login-overlay-panel--track {
  width: min(960px, calc(100vw - 32px));
}

.commerce-home-subnav {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 14px;
  padding: 16px 28px;
  background: #fff;
  border-top: 1px solid rgba(15, 23, 42, 0.08);
}

.commerce-home-subnav-left {
  display: flex;
  align-items: center;
  gap: 16px;
  flex-wrap: wrap;
}

.commerce-home-subnav-select {
  min-height: 42px;
  padding: 0 14px;
  border: 1px solid rgba(15, 23, 42, 0.1);
  border-radius: 10px;
  color: #111827;
  background: #f8fafc;
  font-weight: 700;
}

.commerce-home-subnav-links {
  display: flex;
  align-items: center;
  gap: 22px;
  flex-wrap: wrap;
}

.commerce-home-subnav-links a,
.commerce-home-subnav-links button {
  color: #475569;
  text-decoration: none;
  font-weight: 600;
  border: 0;
  background: transparent;
  padding: 0;
  cursor: pointer;
  font: inherit;
}

.commerce-home-mobile-panel {
  display: none;
}

.commerce-home-visual-input {
  display: none;
}

@media (max-width: 1180px) {
  .commerce-home-header-bar {
    grid-template-columns: 1fr;
  }

  .commerce-home-search {
    grid-template-columns: 1fr auto auto;
  }
}

@media (max-width: 760px) {
  .commerce-home-promo-bar,
  .commerce-home-info-bar,
  .commerce-home-subnav,
  .commerce-home-search,
  .commerce-home-header-actions {
    display: none;
  }

  .commerce-home-shell {
    overflow: visible;
    border-bottom: 0;
    box-shadow: none;
  }

  .commerce-home-header-bar {
    grid-template-columns: minmax(0, 1fr) auto;
    gap: 12px;
    padding: 12px 16px;
    background: #2a3447;
  }

  .commerce-home-brand-wordmark {
    display: none;
  }

  .commerce-home-brand img {
    width: 53px;
    height: 53px;
  }

  .commerce-home-mobile-toggle {
    display: inline-flex;
  }

  .commerce-home-mobile-panel {
    position: absolute;
    top: 100%;
    left: 0;
    right: 0;
    z-index: 85;
    display: grid;
    gap: 14px;
    padding: 16px;
    background: #ffffff;
    border-bottom: 1px solid rgba(15, 23, 42, 0.08);
    box-shadow: 0 18px 38px rgba(15, 23, 42, 0.16);
  }

  .commerce-home-mobile-search {
    display: grid;
    grid-template-columns: minmax(0, 1fr) auto;
    min-height: 50px;
    overflow: hidden;
    border: 1px solid rgba(15, 23, 42, 0.1);
    border-radius: 14px;
    background: #fff;
  }

  .commerce-home-mobile-search-input,
  .commerce-home-mobile-search-submit,
  .commerce-home-mobile-select {
    border: 0;
    background: transparent;
  }

  .commerce-home-mobile-search-input {
    min-width: 0;
    padding: 0 14px;
    color: #0f172a;
    font-size: 0.96rem;
  }

  .commerce-home-mobile-search-input:focus,
  .commerce-home-mobile-select:focus {
    outline: none;
  }

  .commerce-home-mobile-search-submit {
    display: inline-flex;
    width: 52px;
    align-items: center;
    justify-content: center;
    color: #1b5f8a;
  }

  .commerce-home-mobile-search-submit svg {
    width: 20px;
    height: 20px;
    fill: currentColor;
  }

  .commerce-home-mobile-actions {
    display: grid;
    grid-template-columns: repeat(3, minmax(0, 1fr));
    gap: 10px;
  }

  .commerce-home-mobile-action {
    display: inline-flex;
    min-height: 44px;
    align-items: center;
    justify-content: center;
    padding: 0 12px;
    border: 1px solid rgba(15, 23, 42, 0.08);
    border-radius: 12px;
    background: #f8fafc;
    color: #0f172a;
    text-decoration: none;
    font-size: 0.9rem;
    font-weight: 700;
    cursor: pointer;
  }

  .commerce-home-mobile-select {
    min-height: 48px;
    padding: 0 14px;
    border: 1px solid rgba(15, 23, 42, 0.1);
    border-radius: 12px;
    color: #0f172a;
    background: #f8fafc;
    font-weight: 700;
  }

  .commerce-home-mobile-links {
    display: grid;
    gap: 10px;
  }

.commerce-home-mobile-links a,
.commerce-home-mobile-links button {
  color: #475569;
  text-decoration: none;
  font-weight: 700;
  border: 0;
  background: transparent;
  padding: 0;
  text-align: left;
  cursor: pointer;
  font: inherit;
}

  .commerce-home-login-overlay {
    padding: calc(66px + env(safe-area-inset-top)) 8px max(12px, env(safe-area-inset-bottom));
  }

  .commerce-home-login-overlay-panel {
    width: min(100%, 700px);
  }
}
</style>
