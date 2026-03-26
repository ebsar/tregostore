<script setup>
import { computed, onBeforeUnmount, onMounted, ref, watch } from "vue";
import { RouterLink, useRoute, useRouter } from "vue-router";
import { PRIMARY_NAVIGATION } from "../lib/shop";
import { appState, ensureSessionLoaded, logoutUser } from "../stores/app-state";

const route = useRoute();
const router = useRouter();
const navElement = ref(null);
const mobileMenuOpen = ref(false);
const openDropdownKey = ref("");
const userMenuOpen = ref(false);
const isMobileViewport = ref(false);

const cartBadgeLabel = computed(() => {
  if (appState.cartCount <= 0) {
    return "0";
  }

  return appState.cartCount > 99 ? "99+" : String(appState.cartCount);
});

const adminLinks = computed(() => {
  if (appState.user?.role !== "admin") {
    return [];
  }

  return [
    { label: "Artikujt", href: "/admin-products" },
    { label: "Bizneset e regjistruara", href: "/bizneset-e-regjistruara" },
  ];
});

const businessLinks = computed(() => {
  if (appState.user?.role !== "business") {
    return [];
  }

  return [
    { label: "Biznesi juaj", href: "/biznesi-juaj" },
    { label: "Porosite e biznesit", href: "/porosite-e-biznesit", secondary: true },
  ];
});

function updateViewportState() {
  isMobileViewport.value = window.matchMedia("(max-width: 920px)").matches;
  if (!isMobileViewport.value) {
    mobileMenuOpen.value = false;
  }
}

function closeExpandedPanels() {
  openDropdownKey.value = "";
  userMenuOpen.value = false;
}

function toggleMobileMenu() {
  mobileMenuOpen.value = !mobileMenuOpen.value;
  if (!mobileMenuOpen.value) {
    closeExpandedPanels();
  }
}

function toggleDropdown(key) {
  userMenuOpen.value = false;
  openDropdownKey.value = openDropdownKey.value === key ? "" : key;
}

function handleUserTrigger() {
  if (isMobileViewport.value) {
    mobileMenuOpen.value = false;
    window.location.href = "/llogaria";
    return;
  }

  openDropdownKey.value = "";
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

watch(
  () => route.fullPath,
  () => {
    mobileMenuOpen.value = false;
    closeExpandedPanels();
  },
);

onMounted(async () => {
  updateViewportState();
  window.addEventListener("resize", updateViewportState);
  document.addEventListener("click", closeOnOutsideClick);
  document.addEventListener("keydown", closeOnEscape);
  await ensureSessionLoaded();
});

onBeforeUnmount(() => {
  window.removeEventListener("resize", updateViewportState);
  document.removeEventListener("click", closeOnOutsideClick);
  document.removeEventListener("keydown", closeOnEscape);
});
</script>

<template>
  <nav
    ref="navElement"
    class="site-nav"
    :class="{ 'mobile-menu-open': mobileMenuOpen }"
    aria-label="Navigimi kryesor"
  >
    <RouterLink class="brand has-logo" to="/">
      <img class="brand-logo" src="/trego-logo.png" alt="Logo e TREGO">
      <span class="sr-only">TREGO</span>
    </RouterLink>

    <button
      class="nav-mobile-toggle"
      type="button"
      :aria-expanded="mobileMenuOpen ? 'true' : 'false'"
      aria-controls="site-nav-mobile-panel"
      :aria-label="mobileMenuOpen ? 'Mbylle menune' : 'Hape menune'"
      @click="toggleMobileMenu"
    >
      <svg v-if="!mobileMenuOpen" viewBox="0 0 24 24" aria-hidden="true">
        <path d="M4 7h16M4 12h16M4 17h16"></path>
      </svg>
      <svg v-else viewBox="0 0 24 24" aria-hidden="true">
        <path d="M6 6l12 12M18 6 6 18"></path>
      </svg>
    </button>

    <div id="site-nav-mobile-panel" class="nav-links">
      <template v-for="section in PRIMARY_NAVIGATION" :key="section.key">
        <div v-if="section.items" class="nav-dropdown" :class="{ open: openDropdownKey === section.key }">
          <button
            class="nav-dropdown-trigger"
            type="button"
            :aria-expanded="openDropdownKey === section.key ? 'true' : 'false'"
            @click="toggleDropdown(section.key)"
          >
            <span>{{ section.label }}</span>
            <svg viewBox="0 0 24 24" aria-hidden="true">
              <path d="m7 10 5 5 5-5"></path>
            </svg>
          </button>

          <div class="nav-dropdown-menu" :hidden="openDropdownKey !== section.key">
            <RouterLink
              v-for="item in section.items"
              :key="item.href"
              class="nav-dropdown-item"
              :to="item.href"
            >
              {{ item.label }}
            </RouterLink>
          </div>
        </div>

        <RouterLink
          v-else
          class="nav-link"
          :to="section.href"
        >
          {{ section.label }}
        </RouterLink>
      </template>
    </div>

    <div class="nav-actions">
      <RouterLink class="nav-icon-button search-button" to="/kerko" aria-label="Kerko">
        <svg class="nav-icon" viewBox="0 0 24 24" aria-hidden="true">
          <circle cx="11" cy="11" r="6"></circle>
          <path d="m20 20-4.2-4.2"></path>
        </svg>
      </RouterLink>

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
          <span class="nav-user-name">{{ appState.user.fullName }}</span>
        </button>

        <div class="nav-user-panel" :hidden="!userMenuOpen || isMobileViewport">
          <p class="nav-user-panel-label">Llogaria ime</p>
          <strong class="nav-user-panel-name">{{ appState.user.fullName }}</strong>
          <span class="nav-user-panel-email">{{ appState.user.email }}</span>

          <div class="nav-user-panel-links">
            <a
              v-for="link in adminLinks"
              :key="link.href"
              class="nav-user-panel-link"
              :href="link.href"
            >
              {{ link.label }}
            </a>

            <a
              v-for="link in businessLinks"
              :key="link.href"
              class="nav-user-panel-link"
              :class="{ 'nav-user-panel-link-secondary': link.secondary }"
              :href="link.href"
            >
              {{ link.label }}
            </a>

            <a class="nav-user-panel-link" href="/te-dhenat-personale">Te dhenat personale</a>
            <a class="nav-user-panel-link nav-user-panel-link-secondary" href="/adresat">Adresat</a>
            <a class="nav-user-panel-link nav-user-panel-link-secondary" href="/porosite">Porosite</a>
            <a class="nav-user-panel-link nav-user-panel-link-secondary" href="/ndrysho-fjalekalimin">Ndryshimi i fjalekalimit</a>
          </div>

          <button class="nav-user-panel-logout" type="button" @click="handleLogout">
            Shkycu
          </button>
        </div>
      </div>
    </div>
  </nav>
</template>
