<script setup>
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from "vue";
import gsap from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";
import { RouterLink, useRoute, useRouter } from "vue-router";
import { PRIMARY_NAVIGATION } from "../lib/shop";
import { appState, ensureSessionLoaded, logoutUser } from "../stores/app-state";

gsap.registerPlugin(ScrollTrigger);

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
let mobileNavMatchMedia = null;
let mobileNavScrollTrigger = null;
const resolveMobileNavEase = gsap.parseEase("power2.out");

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
    applyMobileNavShellProgress(0);
  }
}

function applyMobileNavShellProgress(progressValue) {
  if (!navElement.value) {
    return;
  }

  const normalizedProgress = Math.max(0, Math.min(progressValue, 1));

  gsap.set(navElement.value, {
    "--mobile-nav-progress": normalizedProgress.toFixed(3),
  });
}

function syncMobileNavFromScroll(trigger) {
  if (!trigger) {
    return;
  }

  if (!isMobileViewport.value || mobileMenuOpen.value || searchMenuOpen.value) {
    isMobileSearchOnly.value = false;
    applyMobileNavShellProgress(0);
    return;
  }

  const rawProgress = Math.max(0, Math.min(trigger.progress, 1));
  const shellProgress = rawProgress <= 0.01 ? 0 : resolveMobileNavEase(rawProgress);
  const currentScrollY = trigger.scroll();

  applyMobileNavShellProgress(shellProgress);

  if (!isMobileSearchOnly.value && rawProgress > 0.985 && trigger.direction > 0 && currentScrollY > 190) {
    isMobileSearchOnly.value = true;
  } else if (isMobileSearchOnly.value && (rawProgress < 0.72 || trigger.direction < 0 || currentScrollY < 136)) {
    isMobileSearchOnly.value = false;
  }
}

function setupMobileNavScrollTrigger() {
  if (!navElement.value || typeof window === "undefined") {
    return;
  }

  if (mobileNavMatchMedia) {
    mobileNavMatchMedia.revert();
  }

  mobileNavMatchMedia = gsap.matchMedia();
  mobileNavMatchMedia.add("(max-width: 920px)", () => {
    applyMobileNavShellProgress(0);
    gsap.set(navElement.value, {
      force3D: true,
    });

    mobileNavScrollTrigger = ScrollTrigger.create({
      start: 0,
      end: 180,
      scrub: 0.55,
      fastScrollEnd: false,
      invalidateOnRefresh: true,
      onUpdate(self) {
        syncMobileNavFromScroll(self);
      },
      onRefresh(self) {
        syncMobileNavFromScroll(self);
      },
      onLeaveBack() {
        isMobileSearchOnly.value = false;
        applyMobileNavShellProgress(0);
      },
    });

    window.requestAnimationFrame(() => {
      mobileNavScrollTrigger?.refresh();
    });

    return () => {
      isMobileSearchOnly.value = false;
      mobileNavScrollTrigger = null;
      applyMobileNavShellProgress(0);
    };
  });
}

function closeExpandedPanels() {
  openDropdownKey.value = "";
  userMenuOpen.value = false;
  searchMenuOpen.value = false;
}

function toggleMobileMenu() {
  mobileMenuOpen.value = !mobileMenuOpen.value;
  if (mobileMenuOpen.value) {
    closeExpandedPanels();
    return;
  }

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
    applyMobileNavShellProgress(0);
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
    nextTick(() => {
      applyMobileNavShellProgress(0);
      ScrollTrigger.refresh();
    });
  },
);

watch([mobileMenuOpen, searchMenuOpen], ([menuOpen, searchOpen]) => {
  if (menuOpen || searchOpen) {
    isMobileSearchOnly.value = false;
    applyMobileNavShellProgress(0);
    return;
  }

  if (mobileNavScrollTrigger) {
    syncMobileNavFromScroll(mobileNavScrollTrigger);
  }
});

onMounted(async () => {
  updateViewportState();
  window.addEventListener("resize", updateViewportState);
  document.addEventListener("click", closeOnOutsideClick);
  document.addEventListener("keydown", closeOnEscape);
  searchQuery.value = String(route.query.q || "").trim();
  await nextTick();
  setupMobileNavScrollTrigger();
});

onBeforeUnmount(() => {
  if (mobileNavMatchMedia) {
    mobileNavMatchMedia.revert();
    mobileNavMatchMedia = null;
  }
  window.removeEventListener("resize", updateViewportState);
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

    <div class="nav-mobile-tray" :class="{ 'is-search-pill': isMobileSearchOnly && !mobileMenuOpen }">
      <button
        v-if="isMobileSearchOnly && !mobileMenuOpen"
        class="nav-icon-button search-button nav-mobile-search-pill"
        type="button"
        aria-label="Kerko"
        :aria-expanded="searchMenuOpen ? 'true' : 'false'"
        @click="toggleSearchPanel"
      >
        <span class="nav-mobile-search-pill-content">
          <svg class="nav-icon nav-mobile-search-pill-icon" viewBox="0 0 24 24" aria-hidden="true">
            <circle cx="11" cy="11" r="6"></circle>
            <path d="m20 20-4.2-4.2"></path>
          </svg>
          <span class="nav-mobile-search-pill-label">Kerko ketu...</span>
          <span class="nav-mobile-search-pill-spacer" aria-hidden="true"></span>
        </span>
      </button>

      <template v-else>
        <button
          class="nav-icon-button search-button nav-mobile-shortcut"
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
      </template>
    </div>

    <Transition name="nav-floating-panel">
      <button
        v-if="searchMenuOpen"
        class="nav-search-dismiss-layer"
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
          placeholder="Kerko ketu..."
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

      <RouterLink
        v-if="isBusinessUser && isMobileViewport"
        class="nav-action nav-action-primary nav-mobile-business-action"
        to="/biznesi-juaj?view=add-product"
        @click="closeExpandedPanels"
      >
        Shto artikull
      </RouterLink>
    </div>
  </nav>
</template>
