<script setup>
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from "vue";
import { RouterLink, useRoute, useRouter } from "vue-router";
import { PRIMARY_NAVIGATION, formatPrice, getProductDetailUrl } from "../lib/shop";
import { setPendingVisualSearchFile } from "../lib/visual-search-transfer";
import { requestJson, resolveApiMessage, searchProductsByImage } from "../lib/api";
import { appState, ensureSessionLoaded, logoutUser } from "../stores/app-state";

const route = useRoute();
const router = useRouter();
const navElement = ref(null);
const mobileMenuOpen = ref(false);
const openDropdownKey = ref("");
const userMenuOpen = ref(false);
const searchMenuOpen = ref(false);
const isMobileViewport = ref(false);
const isMobileSearchOnly = ref(false);
const searchQuery = ref("");
const searchInputElement = ref(null);
const navVisualSearchInputElement = ref(null);
const navSearchResult = ref(null);
const navSearchLoading = ref(false);
const navSearchMessage = ref("");
const unreadMessagesCount = ref(0);
let lastScrollY = 0;
let unreadMessagesPollIntervalId = 0;
const UNREAD_MESSAGES_POLL_MS = 3000;
const AI_SEARCH_PROMPTS = [
  "me trego maica te kuqe",
  "dua pantallona te gjera",
  "me gjej patika te veres",
];

function resetNavSearchPreview() {
  navSearchResult.value = null;
  navSearchMessage.value = "";
}

const cartBadgeLabel = computed(() => {
  if (appState.cartCount <= 0) {
    return "0";
  }

  return appState.cartCount > 99 ? "99+" : String(appState.cartCount);
});

const isBusinessUser = computed(() => appState.user?.role === "business");
const showConsumerNavigation = computed(() => !isBusinessUser.value);
const canUseMessages = computed(() => ["client", "business", "admin"].includes(String(appState.user?.role || "").trim()));
const showMessagesShortcut = computed(() => canUseMessages.value || !appState.user);
const unreadMessagesBadgeLabel = computed(() => {
  if (unreadMessagesCount.value <= 0) {
    return "0";
  }

  return unreadMessagesCount.value > 99 ? "99+" : String(unreadMessagesCount.value);
});

const userMenuLinks = computed(() => {
  if (!appState.user) {
    return [];
  }

  if (appState.user.role === "admin") {
    return [
      { label: "Artikujt", href: "/admin-products" },
      { label: "Bizneset e regjistruara", href: "/bizneset-e-regjistruara" },
      { label: "Porosit", href: "/admin-porosite" },
      { label: "Te dhenat personale", href: "/te-dhenat-personale" },
    ];
  }

  if (appState.user.role === "business") {
    return [
      { label: "Biznesi i imi", href: "/biznesi-juaj" },
      ...(String(appState.user.businessProfileUrl || "").trim()
        ? [{ label: "Profili publik", href: String(appState.user.businessProfileUrl || "").trim() }]
        : []),
      { label: "Porosite e bera", href: "/porosite-e-biznesit" },
      { label: "Te dhenat personale", href: "/te-dhenat-personale" },
    ];
  }

  return [
    { label: "Porosite", href: "/porosite" },
    { label: "Refund / Returne", href: "/refund-returne" },
    { label: "Adresat", href: "/adresat" },
    { label: "Te dhenat personale", href: "/te-dhenat-personale" },
  ];
});

const userDisplayName = computed(() => {
  if (!appState.user) {
    return "";
  }

  if (appState.user.role === "business") {
    return String(appState.user.businessName || "").trim() || String(appState.user.fullName || "").trim();
  }

  return String(appState.user.fullName || "").trim();
});

const userAvatarPath = computed(() => {
  if (!appState.user) {
    return "";
  }

  if (appState.user.role === "business" && String(appState.user.businessLogoPath || "").trim()) {
    return String(appState.user.businessLogoPath || "").trim();
  }

  return String(appState.user.profileImagePath || "").trim();
});

const userPanelLabel = computed(() => {
  if (!appState.user) {
    return "";
  }

  if (appState.user.role === "admin") {
    return "Administrimi";
  }

  if (appState.user.role === "business") {
    return "Biznesi yt";
  }

  return "Llogaria ime";
});

const navSearchResultLink = computed(() => {
  if (!navSearchResult.value) {
    const query = searchQuery.value.trim();
    return {
      path: "/kerko",
      query: query ? { q: query } : {},
    };
  }

  return getProductDetailUrl(navSearchResult.value.id, route.fullPath);
});

const navSearchResultImage = computed(() => {
  if (!navSearchResult.value) {
    return "";
  }

  return (
    navSearchResult.value.imagePath
    || navSearchResult.value.image_path
    || navSearchResult.value.image
    || "/bujqesia.webp"
  );
});

function updateViewportState() {
  isMobileViewport.value = window.matchMedia("(max-width: 920px)").matches;
  if (!isMobileViewport.value) {
    mobileMenuOpen.value = false;
    isMobileSearchOnly.value = false;
  }
}

function handleWindowScroll() {
  if (!isMobileViewport.value || mobileMenuOpen.value || searchMenuOpen.value) {
    isMobileSearchOnly.value = false;
    lastScrollY = window.scrollY || window.pageYOffset || 0;
    return;
  }

  const currentScrollY = window.scrollY || window.pageYOffset || 0;
  const delta = currentScrollY - lastScrollY;

  if (currentScrollY <= 24) {
    isMobileSearchOnly.value = false;
    lastScrollY = currentScrollY;
    return;
  }

  if (delta > 10) {
    isMobileSearchOnly.value = true;
  } else if (delta < -8) {
    isMobileSearchOnly.value = false;
  }

  lastScrollY = currentScrollY;
}

function closeExpandedPanels() {
  openDropdownKey.value = "";
  userMenuOpen.value = false;
  searchMenuOpen.value = false;
}

function toggleMobileMenu() {
  mobileMenuOpen.value = !mobileMenuOpen.value;
  if (!mobileMenuOpen.value) {
    closeExpandedPanels();
  }
}

function toggleDropdown(key) {
  userMenuOpen.value = false;
  searchMenuOpen.value = false;
  openDropdownKey.value = openDropdownKey.value === key ? "" : key;
}

async function toggleSearchPanel() {
  userMenuOpen.value = false;
  openDropdownKey.value = "";
  const shouldOpen = !searchMenuOpen.value;

  if (shouldOpen && isMobileViewport.value && isMobileSearchOnly.value) {
    isMobileSearchOnly.value = false;
    await nextTick();
  }

  searchMenuOpen.value = shouldOpen;

  if (shouldOpen) {
    await nextTick();
    searchInputElement.value?.focus();
    searchInputElement.value?.select?.();
  }
}

function handleMessagesClick() {
  if (canUseMessages.value) {
    mobileMenuOpen.value = false;
    closeExpandedPanels();
    router.push("/mesazhet");
    return;
  }

  mobileMenuOpen.value = false;
  closeExpandedPanels();
  window.dispatchEvent(new CustomEvent("trego:toast", {
    detail: {
      type: "info",
      message: "Per te pare mesazhe ju duhet te hyni. Kliko ketu per te vazhduar.",
      actions: [
        {
          label: "Login",
          to: {
            path: "/login",
            query: { redirect: "/mesazhet" },
          },
        },
        {
          label: "Sign Up",
          to: {
            path: "/signup",
            query: { redirect: "/mesazhet" },
          },
        },
      ],
    },
  }));
}

function handleUserTrigger() {
  if (isMobileViewport.value) {
    mobileMenuOpen.value = false;
    router.push("/llogaria");
    return;
  }

  openDropdownKey.value = "";
  searchMenuOpen.value = false;
  userMenuOpen.value = !userMenuOpen.value;
}

function closeOnOutsideClick(event) {
  if (!navElement.value?.contains(event.target)) {
    closeExpandedPanels();
    if (isMobileViewport.value) {
      mobileMenuOpen.value = false;
    }
  }
}

function closeOnEscape(event) {
  if (event.key === "Escape") {
    closeExpandedPanels();
    mobileMenuOpen.value = false;
  }
}

async function loadUnreadMessagesCount() {
  if (!canUseMessages.value) {
    unreadMessagesCount.value = 0;
    return;
  }

  try {
    const { response, data } = await requestJson("/api/chat/conversations", {}, { cacheTtlMs: 2500 });
    if (!response.ok || !data?.ok) {
      unreadMessagesCount.value = 0;
      return;
    }

    unreadMessagesCount.value = Math.max(0, Number(data.unreadCount || 0));
  } catch (error) {
    console.error(error);
    unreadMessagesCount.value = 0;
  }
}

function handleWindowFocus() {
  void loadUnreadMessagesCount();
}

function handleVisibilityChange() {
  if (document.visibilityState === "visible") {
    void loadUnreadMessagesCount();
  }
}

async function handleLogout() {
  const { data } = await logoutUser();
  closeExpandedPanels();
  mobileMenuOpen.value = false;
  unreadMessagesCount.value = 0;
  await ensureSessionLoaded({ force: true });
  router.push(data?.redirectTo || "/login");
}

async function submitNavSearch() {
  mobileMenuOpen.value = false;
  await fetchNavSearchResult();
}

async function fetchNavSearchResult() {
  const query = searchQuery.value.trim();
  if (!query) {
    navSearchResult.value = null;
    navSearchMessage.value = "";
    return;
  }

  navSearchLoading.value = true;
  resetNavSearchPreview();

  try {
    const params = new URLSearchParams();
    params.set("limit", "1");
    params.set("q", query);
    const { response, data } = await requestJson(`/api/products/search?${params.toString()}`);
    if (!response.ok || !data?.ok) {
      navSearchMessage.value = resolveApiMessage(data, "Nuk u gjet produkti.");
      return;
    }

    const first = Array.isArray(data.products) ? data.products[0] : null;
    if (!first) {
      navSearchMessage.value = "Nuk u gjet asnje produkt per kete kerkim.";
      return;
    }

    navSearchResult.value = first;
  } catch (error) {
    console.error(error);
    navSearchMessage.value = "Serveri nuk po pergjigjet.";
  } finally {
    navSearchLoading.value = false;
  }
}

function applySearchPrompt(prompt) {
  searchQuery.value = String(prompt || "").trim();
  fetchNavSearchResult();
}

function openNavVisualSearchPicker() {
  navVisualSearchInputElement.value?.click?.();
}

async function handleNavVisualSearchSelection(event) {
  const nextFile = event?.target?.files?.[0] || null;
  if (!nextFile) {
    return;
  }

  setPendingVisualSearchFile(nextFile);
  navSearchLoading.value = true;
  resetNavSearchPreview();

  try {
    const result = await searchProductsByImage(nextFile, { limit: 1 });
    if (result.ok && Array.isArray(result.products) && result.products.length) {
      navSearchResult.value = result.products[0];
      navSearchMessage.value = "";
    } else {
      navSearchMessage.value = result.message || "Nuk u gjet asnje produkt i ngjashem.";
    }
  } catch (error) {
    console.error(error);
    navSearchMessage.value = "Serveri nuk po pergjigjet.";
  } finally {
    navSearchLoading.value = false;
  }

  searchInputElement.value?.focus?.();

  if (event?.target) {
    event.target.value = "";
  }
}

watch(
  () => route.fullPath,
  () => {
    mobileMenuOpen.value = false;
    isMobileSearchOnly.value = false;
    closeExpandedPanels();
    searchQuery.value = String(route.query.q || "").trim();
    navSearchResult.value = null;
    navSearchMessage.value = "";
    void loadUnreadMessagesCount();
  },
);

watch(
  () => appState.user?.id,
  () => {
    void loadUnreadMessagesCount();
  },
);

watch(searchQuery, (nextValue) => {
  if (!String(nextValue || "").trim()) {
    resetNavSearchPreview();
  }
});

onMounted(async () => {
  updateViewportState();
  lastScrollY = window.scrollY || window.pageYOffset || 0;
  window.addEventListener("resize", updateViewportState);
  window.addEventListener("scroll", handleWindowScroll, { passive: true });
  window.addEventListener("focus", handleWindowFocus);
  document.addEventListener("visibilitychange", handleVisibilityChange);
  document.addEventListener("click", closeOnOutsideClick);
  document.addEventListener("keydown", closeOnEscape);
  searchQuery.value = String(route.query.q || "").trim();
  void loadUnreadMessagesCount();
  unreadMessagesPollIntervalId = window.setInterval(() => {
    if (document.visibilityState !== "hidden") {
      void loadUnreadMessagesCount();
    }
  }, UNREAD_MESSAGES_POLL_MS);
});

onBeforeUnmount(() => {
  window.removeEventListener("resize", updateViewportState);
  window.removeEventListener("scroll", handleWindowScroll);
  window.removeEventListener("focus", handleWindowFocus);
  document.removeEventListener("visibilitychange", handleVisibilityChange);
  document.removeEventListener("click", closeOnOutsideClick);
  document.removeEventListener("keydown", closeOnEscape);
  if (unreadMessagesPollIntervalId) {
    window.clearInterval(unreadMessagesPollIntervalId);
    unreadMessagesPollIntervalId = 0;
  }
});
</script>

<template>
  <nav
    ref="navElement"
    class="site-nav"
    :class="{
      'mobile-menu-open': mobileMenuOpen,
      'mobile-search-only': isMobileSearchOnly,
    }"
    aria-label="Navigimi kryesor"
  >
    <RouterLink class="brand has-logo" to="/">
      <img class="brand-logo" src="/trego-logo.webp" alt="Logo e TREGO" width="420" height="159" fetchpriority="high">
      <span class="sr-only">TREGO</span>
    </RouterLink>

    <div class="nav-mobile-tray">
      <RouterLink
        v-if="isBusinessUser"
        class="nav-icon-button add-product-button nav-mobile-shortcut"
        to="/biznesi-juaj?view=add-product"
        aria-label="Shto artikull te ri"
      >
        <svg class="nav-icon" viewBox="0 0 24 24" aria-hidden="true">
          <path d="M12 5v14"></path>
          <path d="M5 12h14"></path>
        </svg>
      </RouterLink>

      <button
        class="nav-icon-button search-button nav-mobile-shortcut"
        type="button"
        aria-label="Kerko ketu"
        :aria-expanded="searchMenuOpen ? 'true' : 'false'"
        @click="toggleSearchPanel"
      >
        <svg class="nav-icon" viewBox="0 0 24 24" aria-hidden="true">
          <circle cx="11" cy="11" r="6"></circle>
          <path d="m20 20-4.2-4.2"></path>
        </svg>
        <span class="nav-mobile-search-label">Kerko ketu...</span>
      </button>

      <RouterLink
        v-if="showConsumerNavigation"
        class="nav-icon-button wishlist-link nav-mobile-shortcut"
        to="/wishlist"
        aria-label="Wishlist"
      >
        <svg class="nav-icon" viewBox="0 0 24 24" aria-hidden="true">
          <path d="M12 20.4 4.9 13.8a4.8 4.8 0 0 1 6.8-6.8l.3.3.3-.3a4.8 4.8 0 1 1 6.8 6.8Z"></path>
        </svg>
      </RouterLink>

      <RouterLink
        v-if="showConsumerNavigation"
        class="nav-icon-button cart-button nav-mobile-shortcut"
        to="/cart"
        aria-label="My Cart"
      >
        <svg class="nav-icon" viewBox="0 0 24 24" aria-hidden="true">
          <path d="M3 5h2l2.1 9.1a1 1 0 0 0 1 .8h8.8a1 1 0 0 0 1-.8L20 8H7.2"></path>
          <circle cx="10" cy="19" r="1.4"></circle>
          <circle cx="18" cy="19" r="1.4"></circle>
        </svg>
        <span class="nav-cart-badge" :hidden="appState.cartCount <= 0">{{ cartBadgeLabel }}</span>
      </RouterLink>

      <button
        v-if="showMessagesShortcut"
        class="nav-icon-button messages-button nav-mobile-shortcut"
        type="button"
        aria-label="Mesazhet"
        @click="handleMessagesClick"
      >
        <svg class="nav-icon" viewBox="0 0 24 24" aria-hidden="true">
          <path d="M5 6.5h14a1.5 1.5 0 0 1 1.5 1.5v8a1.5 1.5 0 0 1-1.5 1.5H10l-4.5 3v-3H5A1.5 1.5 0 0 1 3.5 16V8A1.5 1.5 0 0 1 5 6.5Z"></path>
        </svg>
        <span class="nav-cart-badge nav-messages-badge" :hidden="unreadMessagesCount <= 0">{{ unreadMessagesBadgeLabel }}</span>
      </button>

      <button
        class="nav-mobile-toggle"
        type="button"
        :aria-expanded="mobileMenuOpen ? 'true' : 'false'"
        aria-controls="site-nav-mobile-panel"
        :aria-label="mobileMenuOpen ? 'Mbylle menune' : 'Hape menune'"
        @click="toggleMobileMenu"
      >
        <svg v-if="!mobileMenuOpen" class="nav-mobile-toggle-icon" viewBox="0 0 24 24" aria-hidden="true">
          <path d="M4 7h16M4 12h16M4 17h16"></path>
        </svg>
        <svg v-else class="nav-mobile-toggle-icon" viewBox="0 0 24 24" aria-hidden="true">
          <path d="M6 6l12 12M18 6 6 18"></path>
        </svg>
      </button>
    </div>

    <Transition name="nav-floating-panel">
      <form
        v-if="searchMenuOpen"
        class="nav-search-panel"
        role="search"
        @click.stop
        @submit.prevent="submitNavSearch"
      >
        <label class="sr-only" for="nav-search-input">Kerko produktet</label>
        <div class="nav-search-field">
          <input
            id="nav-search-input"
            ref="searchInputElement"
            v-model="searchQuery"
            class="nav-search-input"
            type="search"
            name="q"
            placeholder="Kerko ketu..."
            autocomplete="off"
          >
          <button
            class="nav-search-camera"
            type="button"
            aria-label="Kerko me foto"
            @click="openNavVisualSearchPicker"
          >
            <svg viewBox="0 0 24 24" aria-hidden="true">
              <rect x="4" y="7" width="16" height="11" rx="3"></rect>
              <circle cx="12" cy="12.5" r="3"></circle>
              <path d="M7 7 5 6H3"></path>
            </svg>
          </button>
        </div>

        <div class="nav-search-preview" v-if="navSearchLoading || navSearchResult || navSearchMessage">
          <div class="nav-search-loading" v-if="navSearchLoading">
            Po ngarkohet produkti...
          </div>

          <div
            v-else-if="navSearchResult"
            class="nav-search-preview-card nav-search-mini-card"
          >
            <div class="nav-search-product-image">
              <img
                v-if="navSearchResultImage"
                :src="navSearchResultImage"
                alt="Produkt i rekomanduar"
                loading="lazy"
              >
            </div>
            <div class="nav-search-product-info">
              <p class="nav-search-preview-title">
                {{ navSearchResult.title || navSearchResult.productName || "Produkti i kerkuar" }}
              </p>
              <p class="nav-search-preview-subtitle">
                {{ navSearchResult.price ? formatPrice(navSearchResult.price) : "Çmimi i disponueshëm" }}
              </p>
              <p class="nav-search-preview-description">
                {{ navSearchResult.description || navSearchResult.tagline || "" }}
              </p>
              <RouterLink class="nav-search-more" :to="navSearchResultLink">
                Shiko me shum
              </RouterLink>
            </div>
          </div>

          <p v-else class="nav-search-no-results">
            {{ navSearchMessage || "Nuk ka ne stok ky produkt." }}
          </p>
        </div>

        <input
          ref="navVisualSearchInputElement"
          class="sr-only"
          type="file"
          accept="image/*"
          capture="environment"
          @change="handleNavVisualSearchSelection"
        >
      </form>
    </Transition>

    <div v-if="showConsumerNavigation" id="site-nav-mobile-panel" class="nav-links">
      <template v-for="section in PRIMARY_NAVIGATION" :key="section.key">
        <div v-if="section.groups?.length" class="nav-dropdown" :class="{ open: openDropdownKey === section.key }">
          <button
            class="nav-dropdown-trigger"
            type="button"
            :aria-expanded="openDropdownKey === section.key ? 'true' : 'false'"
            :aria-label="`Hape menune per ${section.label}`"
            @click="toggleDropdown(section.key)"
          >
            <span>{{ section.label }}</span>
            <svg class="nav-chevron" viewBox="0 0 24 24" aria-hidden="true">
              <path d="m7 10 5 5 5-5"></path>
            </svg>
          </button>

          <div class="nav-dropdown-menu nav-dropdown-menu-rich" :hidden="openDropdownKey !== section.key">
            <RouterLink
              class="nav-dropdown-all-link"
              :to="section.href"
              @click="closeExpandedPanels"
            >
              Shih te gjitha
            </RouterLink>

            <section
              v-for="group in section.groups"
              :key="group.key"
              class="nav-dropdown-group"
            >
              <RouterLink
                class="nav-dropdown-group-link"
                :to="group.href"
                @click="closeExpandedPanels"
              >
                {{ group.label }}
              </RouterLink>

              <div class="nav-dropdown-group-items">
                <RouterLink
                  v-for="item in group.items"
                  :key="item.key || item.href"
                  class="nav-dropdown-item nav-dropdown-subitem"
                  :to="item.href"
                  @click="closeExpandedPanels"
                >
                  {{ item.label }}
                </RouterLink>
              </div>
            </section>
          </div>
        </div>

        <RouterLink
          v-else
          class="nav-link"
          :to="section.href"
          @click="closeExpandedPanels"
        >
          {{ section.label }}
        </RouterLink>
      </template>
    </div>

    <div class="nav-actions">
      <RouterLink
        v-if="isBusinessUser"
        class="nav-icon-button add-product-button"
        to="/biznesi-juaj?view=add-product"
        aria-label="Shto artikull te ri"
      >
        <svg class="nav-icon" viewBox="0 0 24 24" aria-hidden="true">
          <path d="M12 5v14"></path>
          <path d="M5 12h14"></path>
        </svg>
      </RouterLink>

      <button
        class="nav-icon-button search-button"
        type="button"
        aria-label="Kerko"
        :aria-expanded="searchMenuOpen ? 'true' : 'false'"
        @click="toggleSearchPanel"
      >
        <svg class="nav-icon" viewBox="0 0 24 24" aria-hidden="true">
          <circle cx="11" cy="11" r="6"></circle>
          <path d="m20 20-4.2-4.2"></path>
        </svg>
      </button>

      <RouterLink
        v-if="showConsumerNavigation"
        class="nav-icon-button wishlist-link"
        to="/wishlist"
        aria-label="Wishlist"
      >
        <svg class="nav-icon" viewBox="0 0 24 24" aria-hidden="true">
          <path d="M12 20.4 4.9 13.8a4.8 4.8 0 0 1 6.8-6.8l.3.3.3-.3a4.8 4.8 0 1 1 6.8 6.8Z"></path>
        </svg>
      </RouterLink>

      <RouterLink
        v-if="showConsumerNavigation"
        class="nav-icon-button cart-button"
        to="/cart"
        aria-label="My Cart"
      >
        <svg class="nav-icon" viewBox="0 0 24 24" aria-hidden="true">
          <path d="M3 5h2l2.1 9.1a1 1 0 0 0 1 .8h8.8a1 1 0 0 0 1-.8L20 8H7.2"></path>
          <circle cx="10" cy="19" r="1.4"></circle>
          <circle cx="18" cy="19" r="1.4"></circle>
        </svg>
        <span class="nav-cart-badge" :hidden="appState.cartCount <= 0">{{ cartBadgeLabel }}</span>
      </RouterLink>

      <button
        v-if="showMessagesShortcut"
        class="nav-icon-button messages-button"
        type="button"
        aria-label="Mesazhet"
        @click="handleMessagesClick"
      >
        <svg class="nav-icon" viewBox="0 0 24 24" aria-hidden="true">
          <path d="M5 6.5h14a1.5 1.5 0 0 1 1.5 1.5v8a1.5 1.5 0 0 1-1.5 1.5H10l-4.5 3v-3H5A1.5 1.5 0 0 1 3.5 16V8A1.5 1.5 0 0 1 5 6.5Z"></path>
        </svg>
        <span class="nav-cart-badge nav-messages-badge" :hidden="unreadMessagesCount <= 0">{{ unreadMessagesBadgeLabel }}</span>
      </button>

      <template v-if="!appState.user">
        <RouterLink class="nav-action nav-action-secondary nav-link-login" to="/login">
          Login
        </RouterLink>
        <RouterLink class="nav-action nav-action-primary nav-link-signup" to="/signup">
          Sign Up
        </RouterLink>
      </template>

      <div
        v-else
        class="nav-user-menu"
        :class="{ open: userMenuOpen && !isMobileViewport }"
      >
        <button
          class="nav-user-trigger"
          type="button"
          :aria-expanded="userMenuOpen && !isMobileViewport ? 'true' : 'false'"
          aria-label="Hape menune e perdoruesit"
          @click="handleUserTrigger"
        >
          <span class="nav-user-avatar" aria-hidden="true">
            <img
              v-if="userAvatarPath"
              class="nav-user-avatar-image"
              :src="userAvatarPath"
              :alt="userDisplayName"
              width="160"
              height="160"
              loading="lazy"
              decoding="async"
            >
            <span v-else class="nav-user-avatar-fallback nav-user-avatar-icon">
              <svg viewBox="0 0 24 24" aria-hidden="true">
                <path d="M12 12a4.25 4.25 0 1 0-4.25-4.25A4.25 4.25 0 0 0 12 12Z"></path>
                <path d="M4.75 19.25a7.25 7.25 0 0 1 14.5 0"></path>
              </svg>
            </span>
          </span>

          <span class="nav-user-trigger-copy">
            <span class="nav-user-name">{{ userDisplayName }}</span>
          </span>

          <svg class="nav-user-trigger-chevron" viewBox="0 0 24 24" aria-hidden="true">
            <path d="m7 10 5 5 5-5"></path>
          </svg>
        </button>

        <Transition name="nav-floating-panel">
          <div v-if="userMenuOpen && !isMobileViewport" class="nav-user-panel">
            <div class="nav-user-panel-head">
              <span class="nav-user-avatar nav-user-avatar-large" aria-hidden="true">
                <img
                  v-if="userAvatarPath"
                  class="nav-user-avatar-image"
                  :src="userAvatarPath"
                  :alt="userDisplayName"
                  width="160"
                  height="160"
                  loading="lazy"
                  decoding="async"
                >
                <span v-else class="nav-user-avatar-fallback nav-user-avatar-icon">
                  <svg viewBox="0 0 24 24" aria-hidden="true">
                    <path d="M12 12a4.25 4.25 0 1 0-4.25-4.25A4.25 4.25 0 0 0 12 12Z"></path>
                    <path d="M4.75 19.25a7.25 7.25 0 0 1 14.5 0"></path>
                  </svg>
                </span>
              </span>

              <div class="nav-user-panel-copy">
                <p class="nav-user-panel-label">{{ userPanelLabel }}</p>
                <strong class="nav-user-panel-name">{{ userDisplayName }}</strong>
                <span class="nav-user-panel-email">{{ appState.user.email }}</span>
              </div>
            </div>

            <div class="nav-user-panel-links">
              <RouterLink
                v-for="link in userMenuLinks"
                :key="link.href"
                class="nav-user-panel-link"
                :to="link.href"
                @click="closeExpandedPanels"
              >
                <span>{{ link.label }}</span>
              </RouterLink>
            </div>

            <button class="nav-user-panel-logout" type="button" @click="handleLogout">
              Shkycu
            </button>
          </div>
        </Transition>
      </div>
    </div>
  </nav>
</template>
