<script setup>
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from "vue";
import { RouterLink, useRoute, useRouter } from "vue-router";
import { PRIMARY_NAVIGATION } from "../lib/shop";
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
let lastScrollY = 0;

const cartBadgeLabel = computed(() => {
  if (appState.cartCount <= 0) {
    return "0";
  }

  return appState.cartCount > 99 ? "99+" : String(appState.cartCount);
});

const isBusinessUser = computed(() => appState.user?.role === "business");

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

async function handleLogout() {
  const { data } = await logoutUser();
  closeExpandedPanels();
  mobileMenuOpen.value = false;
  await ensureSessionLoaded({ force: true });
  router.push(data?.redirectTo || "/login");
}

function submitNavSearch() {
  const nextValue = searchQuery.value.trim();
  closeExpandedPanels();
  mobileMenuOpen.value = false;
  router.push({
    path: "/kerko",
    query: nextValue ? { q: nextValue } : {},
  });
}

watch(
  () => route.fullPath,
  () => {
    mobileMenuOpen.value = false;
    isMobileSearchOnly.value = false;
    closeExpandedPanels();
    searchQuery.value = String(route.query.q || "").trim();
  },
);

onMounted(async () => {
  updateViewportState();
  lastScrollY = window.scrollY || window.pageYOffset || 0;
  window.addEventListener("resize", updateViewportState);
  window.addEventListener("scroll", handleWindowScroll, { passive: true });
  document.addEventListener("click", closeOnOutsideClick);
  document.addEventListener("keydown", closeOnEscape);
  searchQuery.value = String(route.query.q || "").trim();
});

onBeforeUnmount(() => {
  window.removeEventListener("resize", updateViewportState);
  window.removeEventListener("scroll", handleWindowScroll);
  document.removeEventListener("click", closeOnOutsideClick);
  document.removeEventListener("keydown", closeOnEscape);
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
      <img class="brand-logo" src="/trego-logo.png" alt="Logo e TREGO" width="420" height="159" fetchpriority="high">
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

      <RouterLink class="nav-icon-button wishlist-link nav-mobile-shortcut" to="/wishlist" aria-label="Wishlist">
        <svg class="nav-icon" viewBox="0 0 24 24" aria-hidden="true">
          <path d="M12 20.4 4.9 13.8a4.8 4.8 0 0 1 6.8-6.8l.3.3.3-.3a4.8 4.8 0 1 1 6.8 6.8Z"></path>
        </svg>
      </RouterLink>

      <RouterLink class="nav-icon-button cart-button nav-mobile-shortcut" to="/cart" aria-label="My Cart">
        <svg class="nav-icon" viewBox="0 0 24 24" aria-hidden="true">
          <path d="M3 5h2l2.1 9.1a1 1 0 0 0 1 .8h8.8a1 1 0 0 0 1-.8L20 8H7.2"></path>
          <circle cx="10" cy="19" r="1.4"></circle>
          <circle cx="18" cy="19" r="1.4"></circle>
        </svg>
        <span class="nav-cart-badge" :hidden="appState.cartCount <= 0">{{ cartBadgeLabel }}</span>
      </RouterLink>

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
      <button
        v-if="searchMenuOpen"
        class="nav-search-backdrop"
        type="button"
        aria-label="Mbylle kerkimin"
        @click="closeExpandedPanels"
      ></button>
    </Transition>

    <Transition name="nav-floating-panel">
      <form
        v-if="searchMenuOpen"
        class="nav-search-panel"
        role="search"
        @click.stop
        @submit.prevent="submitNavSearch"
      >
        <label class="sr-only" for="nav-search-input">Kerko produktet</label>
        <input
          id="nav-search-input"
          ref="searchInputElement"
          v-model="searchQuery"
          class="nav-search-input"
          type="search"
          name="q"
          placeholder="p.sh. dua pantallona te gjera"
          autocomplete="off"
        >
        <button class="nav-search-submit" type="submit">Kerko</button>
      </form>
    </Transition>

    <div id="site-nav-mobile-panel" class="nav-links">
      <template v-for="section in PRIMARY_NAVIGATION" :key="section.key">
        <div v-if="section.items" class="nav-dropdown nav-dropdown-split" :class="{ open: openDropdownKey === section.key }">
          <RouterLink
            class="nav-link nav-dropdown-link"
            :to="section.href"
            @click="closeExpandedPanels"
          >
            <span>{{ section.label }}</span>
          </RouterLink>

          <button
            class="nav-dropdown-toggle"
            type="button"
            :aria-expanded="openDropdownKey === section.key ? 'true' : 'false'"
            :aria-label="`Hape menune per ${section.label}`"
            @click="toggleDropdown(section.key)"
          >
            <svg class="nav-chevron" viewBox="0 0 24 24" aria-hidden="true">
              <path d="m7 10 5 5 5-5"></path>
            </svg>
          </button>

          <div class="nav-dropdown-menu" :hidden="openDropdownKey !== section.key">
            <RouterLink
              v-for="item in section.items"
              :key="item.href"
              class="nav-dropdown-item"
              :to="item.href"
              @click="closeExpandedPanels"
            >
              {{ item.label }}
            </RouterLink>
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

      <RouterLink class="nav-icon-button wishlist-link" to="/wishlist" aria-label="Wishlist">
        <svg class="nav-icon" viewBox="0 0 24 24" aria-hidden="true">
          <path d="M12 20.4 4.9 13.8a4.8 4.8 0 0 1 6.8-6.8l.3.3.3-.3a4.8 4.8 0 1 1 6.8 6.8Z"></path>
        </svg>
      </RouterLink>

      <RouterLink class="nav-icon-button cart-button" to="/cart" aria-label="My Cart">
        <svg class="nav-icon" viewBox="0 0 24 24" aria-hidden="true">
          <path d="M3 5h2l2.1 9.1a1 1 0 0 0 1 .8h8.8a1 1 0 0 0 1-.8L20 8H7.2"></path>
          <circle cx="10" cy="19" r="1.4"></circle>
          <circle cx="18" cy="19" r="1.4"></circle>
        </svg>
        <span class="nav-cart-badge" :hidden="appState.cartCount <= 0">{{ cartBadgeLabel }}</span>
      </RouterLink>

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
                {{ link.label }}
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
