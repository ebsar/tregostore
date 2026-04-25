<script setup>
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from "vue";
import { RouterLink, useRoute, useRouter } from "vue-router";
import { clearRecentSearches, readRecentSearches, rememberRecentSearch, removeRecentSearch } from "../lib/search-history";
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
const mobileQuickSearchOpen = ref(false);
const isMobileViewport = ref(false);
const searchQuery = ref("");
const mobileQuickSearchQuery = ref("");
const searchInputElement = ref(null);
const mobileQuickSearchInputElement = ref(null);
const navVisualSearchInputElement = ref(null);
const navSearchResult = ref(null);
const navSearchProducts = ref([]);
const navSearchBusinesses = ref([]);
const navSearchCategories = ref([]);
const navSearchLoading = ref(false);
const navSearchMessage = ref("");
const navSearchRecent = ref([]);
const mobileQuickSearchProducts = ref([]);
const mobileQuickSearchLoading = ref(false);
const mobileQuickSearchMessage = ref("");
const mobileQuickSearchRecent = ref([]);
const unreadMessagesCount = ref(0);
const unreadNotificationsCount = ref(0);
let unreadMessagesPollIntervalId = 0;
let mobileQuickSearchTimeoutId = 0;
let navSearchTimeoutId = 0;
const UNREAD_MESSAGES_POLL_MS = 3000;
const MOBILE_QUICK_SEARCH_RECENT_KEY = "trego-mobile-quick-search-recent";
const AI_SEARCH_PROMPTS = [
  "me trego maica te kuqe",
  "dua pantallona te gjera",
  "me gjej patika te veres",
];

function resetNavSearchPreview() {
  navSearchResult.value = null;
  navSearchProducts.value = [];
  navSearchBusinesses.value = [];
  navSearchCategories.value = [];
  navSearchMessage.value = "";
  navSearchLoading.value = false;
}

function resetMobileQuickSearchProducts() {
  mobileQuickSearchProducts.value = [];
  mobileQuickSearchMessage.value = "";
  mobileQuickSearchLoading.value = false;
}

function loadRecentMobileQuickSearches() {
  try {
    const parsed = JSON.parse(window.localStorage.getItem(MOBILE_QUICK_SEARCH_RECENT_KEY) || "[]");
    mobileQuickSearchRecent.value = Array.isArray(parsed)
      ? parsed.map((item) => String(item || "").trim()).filter(Boolean).slice(0, 6)
      : [];
  } catch (error) {
    console.error(error);
    mobileQuickSearchRecent.value = [];
  }
}

function persistRecentMobileQuickSearches() {
  try {
    window.localStorage.setItem(
      MOBILE_QUICK_SEARCH_RECENT_KEY,
      JSON.stringify(mobileQuickSearchRecent.value.slice(0, 6)),
    );
  } catch (error) {
    console.error(error);
  }
}

function clearRecentMobileQuickSearches() {
  mobileQuickSearchRecent.value = [];
  try {
    window.localStorage.removeItem(MOBILE_QUICK_SEARCH_RECENT_KEY);
  } catch (error) {
    console.error(error);
  }
}

function removeRecentMobileQuickSearch(term) {
  const normalizedTerm = normalizeQuickSearchValue(term);
  mobileQuickSearchRecent.value = mobileQuickSearchRecent.value.filter(
    (item) => normalizeQuickSearchValue(item) !== normalizedTerm,
  );
  persistRecentMobileQuickSearches();
}

function rememberMobileQuickSearch(term) {
  const nextTerm = String(term || "").trim();
  if (!nextTerm) {
    return;
  }

  mobileQuickSearchRecent.value = [
    nextTerm,
    ...mobileQuickSearchRecent.value.filter((item) => normalizeQuickSearchValue(item) !== normalizeQuickSearchValue(nextTerm)),
  ].slice(0, 6);
  persistRecentMobileQuickSearches();
}

async function fetchMobileQuickSearchProducts(query) {
  const normalizedQuery = String(query || "").trim();
  if (!normalizedQuery || normalizedQuery.length < 2) {
    resetMobileQuickSearchProducts();
    return;
  }

  mobileQuickSearchLoading.value = true;
  mobileQuickSearchMessage.value = "";

  try {
    const params = new URLSearchParams();
    params.set("limit", "5");
    params.set("q", normalizedQuery);
    const { response, data } = await requestJson(`/api/products/search?${params.toString()}`, {}, { cacheTtlMs: 4000 });
    if (!response.ok || !data?.ok) {
      mobileQuickSearchProducts.value = [];
      mobileQuickSearchMessage.value = resolveApiMessage(data, "Produktet nuk u ngarkuan.");
      return;
    }

    mobileQuickSearchProducts.value = Array.isArray(data.products) ? data.products.slice(0, 5) : [];
    if (mobileQuickSearchProducts.value.length === 0) {
      mobileQuickSearchMessage.value = "Nuk u gjet asnje produkt me kete kerkim.";
    }
  } catch (error) {
    console.error(error);
    mobileQuickSearchProducts.value = [];
    mobileQuickSearchMessage.value = "Serveri nuk po pergjigjet.";
  } finally {
    mobileQuickSearchLoading.value = false;
  }
}

function applyMobileQuickSearchTerm(term) {
  mobileQuickSearchQuery.value = String(term || "").trim();
  nextTick(() => {
    mobileQuickSearchInputElement.value?.focus();
    mobileQuickSearchInputElement.value?.select?.();
  });
}

function getMobileQuickSearchProductImage(product) {
  return (
    product?.imagePath
    || product?.image_path
    || product?.image
    || "/bujqesia.webp"
  );
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

const unreadNotificationsBadgeLabel = computed(() => {
  if (unreadNotificationsCount.value <= 0) {
    return "0";
  }

  return unreadNotificationsCount.value > 99 ? "99+" : String(unreadNotificationsCount.value);
});

function normalizeQuickSearchValue(value) {
  return String(value || "")
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/\s+/g, " ")
    .trim();
}

function quickSearchTargetKey(target) {
  return typeof target === "string" ? target : JSON.stringify(target);
}

function matchesQuickSearchAction(action, normalizedQuery) {
  if (!normalizedQuery) {
    return true;
  }

  return normalizeQuickSearchValue([
    action.label,
    action.description,
    ...(Array.isArray(action.keywords) ? action.keywords : []),
  ].join(" ")).includes(normalizedQuery);
}

const userMenuLinks = computed(() => {
  if (!appState.user) {
    return [];
  }

  if (appState.user.role === "admin") {
    return [
      { label: "Artikujt", href: "/admin-products" },
      { label: "Bizneset e regjistruara", href: "/bizneset-e-regjistruara" },
      { label: "Porosit", href: "/admin-porosite" },
      { label: "Njoftimet", href: "/njoftimet", showUnreadNotifications: true },
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
      { label: "Njoftimet", href: "/njoftimet", showUnreadNotifications: true },
      { label: "Te dhenat personale", href: "/te-dhenat-personale" },
    ];
  }

  return [
    { label: "Porosite", href: "/porosite" },
    { label: "Refund / Returne", href: "/refund-returne" },
    { label: "Adresat", href: "/adresat" },
    { label: "Njoftimet", href: "/njoftimet", showUnreadNotifications: true },
    { label: "Te dhenat personale", href: "/te-dhenat-personale" },
  ];
});

const mobileQuickSearchActions = computed(() => {
  if (!appState.user) {
    return [];
  }

  const actions = [];
  const seen = new Set();
  const pushAction = (action) => {
    const key = JSON.stringify(action.to);
    if (seen.has(key)) {
      return;
    }
    seen.add(key);
    actions.push(action);
  };

  pushAction({
    label: "Llogaria ime",
    description: "Hape qendren kryesore te llogarise.",
    to: "/llogaria",
    keywords: ["llogaria", "account", "menu", "profili"],
  });
  pushAction({
    label: "Mesazhet",
    description: "Shih bisedat, support-in dhe mesazhet e reja.",
    to: "/mesazhet",
    keywords: ["mesazhe", "chat", "biseda", "support"],
  });
  pushAction({
    label: "Njoftimet",
    description: "Kontrollo njoftimet dhe perditesimet.",
    to: "/njoftimet",
    keywords: ["njoftime", "notification", "alerts", "updates"],
  });
  pushAction({
    label: "Te dhenat personale",
    description: "Ndrysho foton, emrin, emailin ose te dhenat e profilit.",
    to: "/te-dhenat-personale",
    keywords: ["foto", "profili", "avatar", "emer", "email", "te dhena"],
  });
  pushAction({
    label: "Ndrysho fjalekalimin",
    description: "Hape sigurine dhe ndryshimin e fjalekalimit.",
    to: "/ndrysho-fjalekalimin",
    keywords: ["fjalekalim", "password", "siguri", "kod", "reset"],
  });

  if (appState.user.role === "admin") {
    pushAction({
      label: "Artikujt e adminit",
      description: "Menaxho artikujt, perdoruesit dhe raportimet.",
      to: "/admin-products",
      keywords: ["admin", "produkte", "artikuj", "raportime", "perdoruesit", "users"],
    });
    pushAction({
      label: "Bizneset e regjistruara",
      description: "Kontrollo verifikimet dhe editimet e bizneseve.",
      to: "/bizneset-e-regjistruara",
      keywords: ["bizneset", "verifikim", "editim", "approval", "registered businesses"],
    });
    pushAction({
      label: "Porosite e adminit",
      description: "Kerko ose kontrollo porosite ne nivel administrimi.",
      to: "/admin-porosite",
      keywords: ["porosi", "order", "admin orders", "status"],
    });
  } else if (appState.user.role === "business") {
    pushAction({
      label: "Biznesi juaj",
      description: "Hape dashboard-in, profilin dhe katalogun e biznesit.",
      to: "/biznesi-juaj",
      keywords: ["biznesi", "dashboard", "logo", "edit biznesin", "profili biznesit"],
    });
    pushAction({
      label: "Shto produkt",
      description: "Shko direkt te formulari per shtimin e produktit.",
      to: { path: "/biznesi-juaj", query: { view: "add-product" } },
      keywords: ["shto produkt", "artikull i ri", "new product", "katalogu"],
    });
    pushAction({
      label: "Porosite e biznesit",
      description: "Kontrollo porosite qe kane ardhur per biznesin tend.",
      to: "/porosite-e-biznesit",
      keywords: ["porosi", "orders", "status", "kerko porosine"],
    });
    if (String(appState.user.businessProfileUrl || "").trim()) {
      pushAction({
        label: "Profili publik",
        description: "Shih faqen publike te biznesit.",
        to: String(appState.user.businessProfileUrl || "").trim(),
        keywords: ["profili publik", "business page", "shop page"],
      });
    }
  } else {
    pushAction({
      label: "Porosite",
      description: "Shih porosite e tua dhe statusin e tyre.",
      to: "/porosite",
      keywords: ["porosi", "orders", "status", "kerko porosine"],
    });
    pushAction({
      label: "Adresat",
      description: "Shto ose ndrysho adresat e ruajtura.",
      to: "/adresat",
      keywords: ["adresa", "shipping", "delivery", "vendbanimi"],
    });
    pushAction({
      label: "Refund / Returne",
      description: "Kontrollo kthimet dhe kerkesat e refund-it.",
      to: "/refund-returne",
      keywords: ["refund", "returne", "kthim", "rikthim"],
    });
    pushAction({
      label: "Wishlist",
      description: "Hape artikujt e ruajtur.",
      to: "/wishlist",
      keywords: ["wishlist", "favoritet", "ruajtur"],
    });
    pushAction({
      label: "Shporta",
      description: "Shih produktet ne shporte dhe vazhdo porosine.",
      to: "/cart",
      keywords: ["cart", "shporta", "checkout", "porosi"],
    });
  }

  return actions;
});

const mobileQuickSearchPublicActions = computed(() => {
  const actions = [];
  const seen = new Set();
  const pushAction = (action) => {
    const key = quickSearchTargetKey(action.to);
    if (seen.has(key)) {
      return;
    }
    seen.add(key);
    actions.push(action);
  };

  pushAction({
    label: "Home",
    description: "Kthehu ne faqen kryesore te marketplace-it.",
    to: "/",
    keywords: ["home", "kryefaqja", "faqja kryesore", "ballina"],
  });
  pushAction({
    label: "Kerko produktet",
    description: "Hape faqen publike te kerkimit dhe filtrave.",
    to: "/kerko",
    keywords: ["kerko", "search", "produkte", "filter", "kategorite"],
  });

  PRIMARY_NAVIGATION.forEach((section) => {
    pushAction({
      label: section.label,
      description: `Shih produktet publike te seksionit ${section.label}.`,
      to: section.href,
      keywords: ["kategori", "seksion", "produkte", section.key, section.label],
    });

    (Array.isArray(section.groups) ? section.groups : []).forEach((group) => {
      pushAction({
        label: group.label,
        description: `Hape nenkategorine ${group.label}.`,
        to: group.href,
        keywords: ["nenkategori", "kategori", group.key, section.label, group.label],
      });
    });
  });

  pushAction({
    label: "Wishlist",
    description: "Shih produktet e ruajtura.",
    to: "/wishlist",
    keywords: ["wishlist", "favoritet", "ruajtur"],
  });
  pushAction({
    label: "Shporta",
    description: "Hape shporten dhe checkout-in.",
    to: "/cart",
    keywords: ["shporta", "cart", "checkout", "pagese"],
  });

  return actions;
});

const filteredMobileQuickSearchActions = computed(() => {
  const query = normalizeQuickSearchValue(mobileQuickSearchQuery.value);
  const actions = mobileQuickSearchActions.value;

  if (!query) {
    return actions.slice(0, 8);
  }

  return actions
    .filter((action) => normalizeQuickSearchValue([
      action.label,
      action.description,
      ...(Array.isArray(action.keywords) ? action.keywords : []),
    ].join(" ")).includes(query))
    .slice(0, 12);
});

const filteredMobileQuickSearchPublicActions = computed(() => {
  const query = normalizeQuickSearchValue(mobileQuickSearchQuery.value);
  const usedTargets = new Set(filteredMobileQuickSearchActions.value.map((action) => quickSearchTargetKey(action.to)));
  const matches = mobileQuickSearchPublicActions.value.filter((action) => {
    if (usedTargets.has(quickSearchTargetKey(action.to))) {
      return false;
    }
    return matchesQuickSearchAction(action, query);
  });

  if (!query) {
    return matches.slice(0, 6);
  }

  return matches.slice(0, 8);
});

const mobileQuickSearchHasQuery = computed(() => normalizeQuickSearchValue(mobileQuickSearchQuery.value).length > 0);

const mobileQuickSearchSuggestions = computed(() => {
  const labelsByRole = appState.user?.role === "admin"
    ? ["Artikujt e adminit", "Bizneset e regjistruara", "Porosite e adminit", "Ndrysho fjalekalimin"]
    : appState.user?.role === "business"
      ? ["Biznesi juaj", "Mesazhet", "Porosite e biznesit", "Ndrysho fjalekalimin"]
      : ["Mesazhet", "Porosite", "Adresat", "Ndrysho fjalekalimin"];

  return labelsByRole
    .map((label) => mobileQuickSearchActions.value.find((action) => action.label === label))
    .filter(Boolean);
});

const mobileQuickSearchPublicSuggestions = computed(() => {
  const labels = ["Home", "Kerko produktet", "Veshje", "Teknologji"];

  return labels
    .map((label) => mobileQuickSearchPublicActions.value.find((action) => action.label === label))
    .filter(Boolean);
});

const navSearchBrowseSuggestions = computed(() =>
  PRIMARY_NAVIGATION.slice(0, 4).map((section) => ({
    label: section.label,
    to: section.href,
  })),
);

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
  }
}

function closeExpandedPanels() {
  openDropdownKey.value = "";
  userMenuOpen.value = false;
  searchMenuOpen.value = false;
  mobileQuickSearchOpen.value = false;
  mobileQuickSearchQuery.value = "";
  resetMobileQuickSearchProducts();
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
  mobileQuickSearchOpen.value = false;
  openDropdownKey.value = openDropdownKey.value === key ? "" : key;
}

async function toggleSearchPanel() {
  userMenuOpen.value = false;
  openDropdownKey.value = "";
  mobileQuickSearchOpen.value = false;
  const shouldOpen = !searchMenuOpen.value;

  searchMenuOpen.value = shouldOpen;

  if (shouldOpen) {
    loadRecentNavSearches();
    await nextTick();
    searchInputElement.value?.focus();
    searchInputElement.value?.select?.();
    if (searchQuery.value.trim().length >= 2) {
      void fetchNavSearchResult();
    } else if (searchQuery.value.trim()) {
      navSearchMessage.value = "Shkruaj se paku 2 shkronja.";
    }
  }
}

async function toggleMobileQuickSearch() {
  if (!isMobileViewport.value || !mobileMenuOpen.value || !appState.user) {
    return;
  }

  userMenuOpen.value = false;
  openDropdownKey.value = "";
  searchMenuOpen.value = false;
  const shouldOpen = !mobileQuickSearchOpen.value;
  mobileQuickSearchOpen.value = shouldOpen;

  if (!shouldOpen) {
    mobileQuickSearchQuery.value = "";
    resetMobileQuickSearchProducts();
    return;
  }

  await nextTick();
  mobileQuickSearchInputElement.value?.focus();
  mobileQuickSearchInputElement.value?.select?.();
}

async function openMobileQuickAction(action) {
  if (!action?.to) {
    return;
  }

  rememberMobileQuickSearch(mobileQuickSearchQuery.value || action.label);
  mobileQuickSearchOpen.value = false;
  mobileQuickSearchQuery.value = "";
  mobileMenuOpen.value = false;
  closeExpandedPanels();
  await router.push(action.to);
}

async function openMobileQuickProduct(product) {
  if (!product?.id) {
    return;
  }

  rememberMobileQuickSearch(mobileQuickSearchQuery.value || product.title || product.productName);
  mobileQuickSearchOpen.value = false;
  mobileQuickSearchQuery.value = "";
  mobileMenuOpen.value = false;
  closeExpandedPanels();
  await router.push(getProductDetailUrl(product.id, route.fullPath));
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
    mobileQuickSearchOpen.value = false;
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

async function loadUnreadNotificationsCount() {
  if (!appState.user) {
    unreadNotificationsCount.value = 0;
    return;
  }

  try {
    const { response, data } = await requestJson("/api/notifications/count", {}, { cacheTtlMs: 2500 });
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

function handleWindowFocus() {
  void loadUnreadMessagesCount();
  void loadUnreadNotificationsCount();
}

function handleVisibilityChange() {
  if (document.visibilityState === "visible") {
    void loadUnreadMessagesCount();
    void loadUnreadNotificationsCount();
  }
}

async function handleLogout() {
  const { data } = await logoutUser();
  closeExpandedPanels();
  mobileMenuOpen.value = false;
  unreadMessagesCount.value = 0;
  unreadNotificationsCount.value = 0;
  await ensureSessionLoaded({ force: true });
  router.push("/");
}

async function submitNavSearch() {
  await openSearchResultsPage();
}

async function fetchNavSearchResult() {
  const query = searchQuery.value.trim();
  if (!query) {
    resetNavSearchPreview();
    return;
  }

  navSearchLoading.value = true;
  resetNavSearchPreview();
  navSearchLoading.value = true;

  try {
    const params = new URLSearchParams();
    params.set("limit", "4");
    params.set("q", query);
    const { response, data } = await requestJson(
      `/api/search/autocomplete?${params.toString()}`,
      {},
      { cacheTtlMs: 3000 },
    );
    if (!response.ok || !data?.ok) {
      navSearchMessage.value = resolveApiMessage(data, "Kerkimi nuk u ngarkua.");
      return;
    }

    const nextProducts = Array.isArray(data.products) ? data.products.slice(0, 4) : [];
    const nextBusinesses = Array.isArray(data.businesses) ? data.businesses.slice(0, 4) : [];
    const nextCategories = Array.isArray(data.categories) ? data.categories.slice(0, 4) : [];
    if (!nextProducts.length && !nextBusinesses.length && !nextCategories.length) {
      navSearchMessage.value = "Nuk u gjet asnje rezultat per kete kerkim.";
      return;
    }

    navSearchProducts.value = nextProducts;
    navSearchBusinesses.value = nextBusinesses;
    navSearchCategories.value = nextCategories;
    navSearchResult.value = nextProducts[0] || nextBusinesses[0] || nextCategories[0] || null;
  } catch (error) {
    console.error(error);
    navSearchMessage.value = "Serveri nuk po pergjigjet.";
  } finally {
    navSearchLoading.value = false;
  }
}

function applySearchPrompt(prompt) {
  searchQuery.value = String(prompt || "").trim();
  nextTick(() => {
    searchInputElement.value?.focus();
    searchInputElement.value?.select?.();
  });
}

function loadRecentNavSearches() {
  navSearchRecent.value = readRecentSearches();
}

function applyNavSearchTerm(term) {
  searchQuery.value = String(term || "").trim();
  nextTick(() => {
    searchInputElement.value?.focus();
    searchInputElement.value?.select?.();
  });
}

function clearNavSearchHistory() {
  navSearchRecent.value = clearRecentSearches();
}

function removeNavSearchHistoryEntry(term) {
  navSearchRecent.value = removeRecentSearch(term);
}

async function openSearchResultsPage(queryValue = searchQuery.value) {
  const normalizedQuery = String(queryValue || "").trim();
  if (!normalizedQuery) {
    return;
  }

  navSearchRecent.value = rememberRecentSearch(normalizedQuery);
  mobileMenuOpen.value = false;
  closeExpandedPanels();
  await router.push({
    path: "/kerko",
    query: { q: normalizedQuery },
  });
}

async function openNavSearchProduct(product) {
  if (!product?.id) {
    await openSearchResultsPage();
    return;
  }

  navSearchRecent.value = rememberRecentSearch(searchQuery.value || product.title || product.productName);
  mobileMenuOpen.value = false;
  closeExpandedPanels();
  await router.push(getProductDetailUrl(product.id, route.fullPath));
}

async function openNavSearchBusiness(business) {
  const nextTarget = String(business?.profileUrl || "").trim();
  if (!nextTarget) {
    await openSearchResultsPage();
    return;
  }

  navSearchRecent.value = rememberRecentSearch(searchQuery.value || business.businessName || "Biznes");
  mobileMenuOpen.value = false;
  closeExpandedPanels();
  await router.push(nextTarget);
}

async function openNavSearchSuggestion(target) {
  if (!target) {
    return;
  }

  if (searchQuery.value.trim()) {
    navSearchRecent.value = rememberRecentSearch(searchQuery.value);
  }
  mobileMenuOpen.value = false;
  closeExpandedPanels();
  await router.push(target);
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
      navSearchProducts.value = result.products.slice(0, 1);
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
    closeExpandedPanels();
    searchQuery.value = String(route.query.q || "").trim();
    resetNavSearchPreview();
    loadRecentNavSearches();
    void loadUnreadMessagesCount();
    void loadUnreadNotificationsCount();
  },
);

watch(
  () => appState.user?.id,
  () => {
    mobileQuickSearchQuery.value = "";
    mobileQuickSearchOpen.value = false;
    void loadUnreadMessagesCount();
    void loadUnreadNotificationsCount();
  },
);

watch(searchQuery, (nextValue) => {
  if (navSearchTimeoutId) {
    window.clearTimeout(navSearchTimeoutId);
    navSearchTimeoutId = 0;
  }

  const normalizedQuery = String(nextValue || "").trim();
  if (!normalizedQuery) {
    resetNavSearchPreview();
    return;
  }

  if (!searchMenuOpen.value) {
    return;
  }

  if (normalizedQuery.length < 2) {
    navSearchProducts.value = [];
    navSearchMessage.value = "Shkruaj se paku 2 shkronja.";
    navSearchLoading.value = false;
    return;
  }

  navSearchLoading.value = true;
  navSearchMessage.value = "";
  navSearchTimeoutId = window.setTimeout(() => {
    void fetchNavSearchResult();
  }, 220);
});

watch(mobileQuickSearchQuery, (nextValue) => {
  if (mobileQuickSearchTimeoutId) {
    window.clearTimeout(mobileQuickSearchTimeoutId);
    mobileQuickSearchTimeoutId = 0;
  }

  const query = String(nextValue || "").trim();
  if (!query) {
    resetMobileQuickSearchProducts();
    return;
  }

  if (query.length < 2) {
    mobileQuickSearchProducts.value = [];
    mobileQuickSearchMessage.value = "";
    mobileQuickSearchLoading.value = false;
    return;
  }

  mobileQuickSearchLoading.value = true;
  mobileQuickSearchMessage.value = "";
  mobileQuickSearchTimeoutId = window.setTimeout(() => {
    void fetchMobileQuickSearchProducts(query);
  }, 220);
});

onMounted(async () => {
  updateViewportState();
  loadRecentMobileQuickSearches();
  loadRecentNavSearches();
  window.addEventListener("resize", updateViewportState);
  window.addEventListener("focus", handleWindowFocus);
  document.addEventListener("visibilitychange", handleVisibilityChange);
  document.addEventListener("click", closeOnOutsideClick);
  document.addEventListener("keydown", closeOnEscape);
  searchQuery.value = String(route.query.q || "").trim();
  void loadUnreadMessagesCount();
  void loadUnreadNotificationsCount();
  unreadMessagesPollIntervalId = window.setInterval(() => {
    if (document.visibilityState !== "hidden") {
      void loadUnreadMessagesCount();
      void loadUnreadNotificationsCount();
    }
  }, UNREAD_MESSAGES_POLL_MS);
});

onBeforeUnmount(() => {
  window.removeEventListener("resize", updateViewportState);
  window.removeEventListener("focus", handleWindowFocus);
  document.removeEventListener("visibilitychange", handleVisibilityChange);
  document.removeEventListener("click", closeOnOutsideClick);
  document.removeEventListener("keydown", closeOnEscape);
  if (mobileQuickSearchTimeoutId) {
    window.clearTimeout(mobileQuickSearchTimeoutId);
    mobileQuickSearchTimeoutId = 0;
  }
  if (navSearchTimeoutId) {
    window.clearTimeout(navSearchTimeoutId);
    navSearchTimeoutId = 0;
  }
  if (unreadMessagesPollIntervalId) {
    window.clearInterval(unreadMessagesPollIntervalId);
    unreadMessagesPollIntervalId = 0;
  }
});
</script>

<template>
  <nav
    ref="navElement"
   
   
    aria-label="Navigimi kryesor"
  >
    <RouterLink to="/">
      <img src="/trego-logo.webp?v=20260410" alt="Logo e TREGIO" width="1024" height="1024" fetchpriority="high">
      <span>TREGIO</span>
    </RouterLink>

    <div>
      <RouterLink
        v-if="isBusinessUser"
       
        to="/biznesi-juaj?view=add-product"
        aria-label="Shto artikull te ri"
      >
        <svg viewBox="0 0 24 24" aria-hidden="true">
          <path d="M12 5v14"></path>
          <path d="M5 12h14"></path>
        </svg>
      </RouterLink>

      <button
       
        type="button"
        aria-label="Kerko ketu"
        :aria-expanded="searchMenuOpen ? 'true' : 'false'"
        @click="toggleSearchPanel"
      >
        <svg viewBox="0 0 24 24" aria-hidden="true">
          <circle cx="11" cy="11" r="6"></circle>
          <path d="m20 20-4.2-4.2"></path>
        </svg>
        <span>Kerko ketu...</span>
      </button>

      <RouterLink
        v-if="showConsumerNavigation"
       
        to="/wishlist"
        aria-label="Wishlist"
      >
        <svg viewBox="0 0 24 24" aria-hidden="true">
          <path d="M12 20.4 4.9 13.8a4.8 4.8 0 0 1 6.8-6.8l.3.3.3-.3a4.8 4.8 0 1 1 6.8 6.8Z"></path>
        </svg>
      </RouterLink>

      <RouterLink
        v-if="showConsumerNavigation"
       
        to="/cart"
        aria-label="My Cart"
      >
        <svg viewBox="0 0 24 24" aria-hidden="true">
          <path d="M3 5h2l2.1 9.1a1 1 0 0 0 1 .8h8.8a1 1 0 0 0 1-.8L20 8H7.2"></path>
          <circle cx="10" cy="19" r="1.4"></circle>
          <circle cx="18" cy="19" r="1.4"></circle>
        </svg>
        <span :hidden="appState.cartCount <= 0">{{ cartBadgeLabel }}</span>
      </RouterLink>

      <button
        v-if="showMessagesShortcut"
       
        type="button"
        aria-label="Mesazhet"
        @click="handleMessagesClick"
      >
        <svg viewBox="0 0 24 24" aria-hidden="true">
          <path d="M5 6.5h14a1.5 1.5 0 0 1 1.5 1.5v8a1.5 1.5 0 0 1-1.5 1.5H10l-4.5 3v-3H5A1.5 1.5 0 0 1 3.5 16V8A1.5 1.5 0 0 1 5 6.5Z"></path>
        </svg>
        <span :hidden="unreadMessagesCount <= 0">{{ unreadMessagesBadgeLabel }}</span>
      </button>

      <button
        v-if="mobileMenuOpen && isMobileViewport && appState.user"
       
        type="button"
        aria-label="Kerko ne menune tende"
        :aria-expanded="mobileQuickSearchOpen ? 'true' : 'false'"
        @click="toggleMobileQuickSearch"
      >
        <svg viewBox="0 0 24 24" aria-hidden="true">
          <circle cx="11" cy="11" r="6"></circle>
          <path d="m20 20-4.2-4.2"></path>
        </svg>
      </button>

      <button
       
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
    </div>

    <Transition name="nav-floating-panel">
      <div
        v-if="mobileMenuOpen && isMobileViewport && appState.user && mobileQuickSearchOpen"
       
        @click.stop
      >
        <label for="nav-mobile-menu-search-input">
          <svg viewBox="0 0 24 24" aria-hidden="true">
            <circle cx="11" cy="11" r="6"></circle>
            <path d="m20 20-4.2-4.2"></path>
          </svg>
          <input
           
            ref="mobileQuickSearchInputElement"
            v-model="mobileQuickSearchQuery"
           
            type="search"
            autocomplete="off"
            placeholder="Kerko mesazhe, porosi, adresa..."
          >
        </label>

        <div aria-live="polite">
          <template v-if="!mobileQuickSearchHasQuery">
            <section v-if="mobileQuickSearchRecent.length > 0">
              <div>
                <p>Kerkuar se fundi</p>
                <button
                 
                  type="button"
                  @click="clearRecentMobileQuickSearches"
                >
                  Pastro
                </button>
              </div>
              <div>
                <div
                  v-for="term in mobileQuickSearchRecent"
                  :key="term"
                 
                >
                  <button
                   
                    type="button"
                    @click="applyMobileQuickSearchTerm(term)"
                  >
                    {{ term }}
                  </button>
                  <button
                   
                    type="button"
                    :aria-label="`Hiq ${term} nga historiku`"
                    @click.stop="removeRecentMobileQuickSearch(term)"
                  >
                    <svg viewBox="0 0 24 24" aria-hidden="true">
                      <path d="M6 6l12 12M18 6 6 18"></path>
                    </svg>
                  </button>
                </div>
              </div>
            </section>

            <section v-if="mobileQuickSearchSuggestions.length > 0">
              <p>Sugjerime per ty</p>
              <button
                v-for="action in mobileQuickSearchSuggestions"
                :key="JSON.stringify(action.to)"
               
                type="button"
                @click="openMobileQuickAction(action)"
              >
                <span>
                  <strong>{{ action.label }}</strong>
                  <span>{{ action.description }}</span>
                </span>
                <svg viewBox="0 0 24 24" aria-hidden="true">
                  <path d="M9 6l6 6-6 6"></path>
                </svg>
              </button>
            </section>

            <section v-if="mobileQuickSearchPublicSuggestions.length > 0">
              <p>Faqe publike</p>
              <div>
                <button
                  v-for="action in mobileQuickSearchPublicSuggestions"
                  :key="JSON.stringify(action.to)"
                 
                  type="button"
                  @click="openMobileQuickAction(action)"
                >
                  {{ action.label }}
                </button>
              </div>
            </section>
          </template>

          <template v-else>
            <section v-if="filteredMobileQuickSearchActions.length > 0">
              <p>Opsionet e llogarise</p>
              <button
                v-for="action in filteredMobileQuickSearchActions"
                :key="JSON.stringify(action.to)"
               
                type="button"
                @click="openMobileQuickAction(action)"
              >
                <span>
                  <strong>{{ action.label }}</strong>
                  <span>{{ action.description }}</span>
                </span>
                <svg viewBox="0 0 24 24" aria-hidden="true">
                  <path d="M9 6l6 6-6 6"></path>
                </svg>
              </button>
            </section>

            <section v-if="filteredMobileQuickSearchPublicActions.length > 0">
              <p>Faqe publike</p>
              <button
                v-for="action in filteredMobileQuickSearchPublicActions"
                :key="JSON.stringify(action.to)"
               
                type="button"
                @click="openMobileQuickAction(action)"
              >
                <span>
                  <strong>{{ action.label }}</strong>
                  <span>{{ action.description }}</span>
                </span>
                <svg viewBox="0 0 24 24" aria-hidden="true">
                  <path d="M9 6l6 6-6 6"></path>
                </svg>
              </button>
            </section>

            <section
              v-if="mobileQuickSearchLoading || mobileQuickSearchProducts.length > 0 || mobileQuickSearchMessage"
             
            >
              <p>Produkte</p>
              <div v-if="mobileQuickSearchLoading">
                Po kerkohet ne katalog...
              </div>

              <template v-else-if="mobileQuickSearchProducts.length > 0">
                <button
                  v-for="product in mobileQuickSearchProducts"
                  :key="product.id"
                 
                  type="button"
                  @click="openMobileQuickProduct(product)"
                >
                  <span>
                    <img
                     
                      :src="getMobileQuickSearchProductImage(product)"
                      :alt="product.title || product.productName || 'Produkt'"
                      loading="lazy"
                    >
                  </span>
                  <span>
                    <strong>
                      {{ product.title || product.productName || "Produkt" }}
                    </strong>
                    <span>
                      {{ product.price ? formatPrice(product.price) : "Cmimi sipas artikullit" }}
                    </span>
                  </span>
                  <svg viewBox="0 0 24 24" aria-hidden="true">
                    <path d="M9 6l6 6-6 6"></path>
                  </svg>
                </button>
              </template>

              <p v-else>
                {{ mobileQuickSearchMessage }}
              </p>
            </section>

            <p
              v-if="!mobileQuickSearchLoading && !filteredMobileQuickSearchActions.length && !filteredMobileQuickSearchPublicActions.length && !mobileQuickSearchProducts.length && !mobileQuickSearchMessage"
             
            >
              Nuk u gjet asnje opsion ose produkt me kete kerkim.
            </p>
          </template>
        </div>
      </div>
    </Transition>

    <Transition name="nav-floating-panel">
      <form
        v-if="searchMenuOpen"
       
        role="search"
        @click.stop
        @submit.prevent="submitNavSearch"
      >
        <label for="nav-search-input">Kerko produktet</label>
        <div>
          <span aria-hidden="true">
            <svg viewBox="0 0 24 24">
              <circle cx="11" cy="11" r="6"></circle>
              <path d="m20 20-4.2-4.2"></path>
            </svg>
          </span>
          <input
           
            ref="searchInputElement"
            v-model="searchQuery"
           
            type="search"
            name="q"
            placeholder="Kerko ketu..."
            autocomplete="off"
          >
          <button
           
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

        <div>
          <template v-if="!searchQuery.trim()">
            <div v-if="navSearchRecent.length > 0">
              <div>
                <p>Kerkuar se fundi</p>
                <button type="button" @click="clearNavSearchHistory">
                  Pastro
                </button>
              </div>
              <div>
                <div
                  v-for="term in navSearchRecent"
                  :key="term"
                 
                >
                  <button type="button" @click="applyNavSearchTerm(term)">
                    {{ term }}
                  </button>
                  <button
                   
                    type="button"
                    :aria-label="`Hiq ${term} nga historiku`"
                    @click.stop="removeNavSearchHistoryEntry(term)"
                  >
                    <svg viewBox="0 0 24 24" aria-hidden="true">
                      <path d="M6 6l12 12M18 6 6 18"></path>
                    </svg>
                  </button>
                </div>
              </div>
            </div>

            <div>
              <p>Kerkime te shpejta</p>
              <div>
                <button
                  v-for="prompt in AI_SEARCH_PROMPTS"
                  :key="prompt"
                 
                  type="button"
                  @click="applySearchPrompt(prompt)"
                >
                  {{ prompt }}
                </button>
              </div>
            </div>

            <div>
              <p>Shfleto kategorite</p>
              <div>
                <button
                  v-for="item in navSearchBrowseSuggestions"
                  :key="item.label"
                 
                  type="button"
                  @click="openNavSearchSuggestion(item.to)"
                >
                  {{ item.label }}
                </button>
              </div>
            </div>
          </template>

          <template v-else>
            <div v-if="navSearchLoading">
              Po kerkohet ne katalog...
            </div>

            <template
              v-else-if="navSearchProducts.length > 0 || navSearchBusinesses.length > 0 || navSearchCategories.length > 0"
            >
              <div v-if="navSearchProducts.length > 0">
                <p>Produkte</p>
                <div>
                  <button
                    v-for="product in navSearchProducts"
                    :key="`product-${product.id}`"
                   
                    type="button"
                    @click="openNavSearchProduct(product)"
                  >
                    <span>
                      <img
                        :src="product.imagePath || product.image_path || product.image || '/bujqesia.webp'"
                        :alt="product.title || product.productName || 'Produkt'"
                        loading="lazy"
                      >
                    </span>
                    <span>
                      <strong>{{ product.title || product.productName || "Produkt" }}</strong>
                      <span>{{ product.price ? formatPrice(product.price) : "Cmimi sipas artikullit" }}</span>
                    </span>
                    <svg viewBox="0 0 24 24" aria-hidden="true">
                      <path d="M9 6l6 6-6 6"></path>
                    </svg>
                  </button>
                </div>
              </div>

              <div v-if="navSearchBusinesses.length > 0">
                <p>Biznese</p>
                <div>
                  <button
                    v-for="business in navSearchBusinesses"
                    :key="`business-${business.id}`"
                   
                    type="button"
                    @click="openNavSearchBusiness(business)"
                  >
                    <span>
                      <img
                        v-if="business.logoPath"
                        :src="business.logoPath"
                        :alt="business.businessName || 'Biznes'"
                        loading="lazy"
                      >
                      <span v-else>
                        {{ String(business.businessName || "B").trim().slice(0, 1).toUpperCase() }}
                      </span>
                    </span>
                    <span>
                      <strong>{{ business.businessName || "Biznes" }}</strong>
                      <span>{{ business.city || business.businessDescription || "Profili publik i biznesit" }}</span>
                    </span>
                    <svg viewBox="0 0 24 24" aria-hidden="true">
                      <path d="M9 6l6 6-6 6"></path>
                    </svg>
                  </button>
                </div>
              </div>

              <div v-if="navSearchCategories.length > 0">
                <p>Kategori</p>
                <div>
                  <button
                    v-for="item in navSearchCategories"
                    :key="`category-${item.href}`"
                   
                    type="button"
                    @click="openNavSearchSuggestion(item.href)"
                  >
                    <span>
                      <svg viewBox="0 0 24 24" aria-hidden="true">
                        <path d="M5 7h14"></path>
                        <path d="M5 12h14"></path>
                        <path d="M5 17h9"></path>
                      </svg>
                    </span>
                    <span>
                      <strong>{{ item.label || "Kategori" }}</strong>
                      <span>{{ item.subtitle || "Shfleto kategorine" }}</span>
                    </span>
                    <svg viewBox="0 0 24 24" aria-hidden="true">
                      <path d="M9 6l6 6-6 6"></path>
                    </svg>
                  </button>
                </div>
              </div>
            </template>

            <p v-else>
              {{ navSearchMessage || "Nuk u gjet asnje rezultat per kete kerkim." }}
            </p>

            <button
              v-if="searchQuery.trim()"
             
              type="button"
              @click="openSearchResultsPage()"
            >
              Shih te gjitha rezultatet per “{{ searchQuery.trim() }}”
            </button>
          </template>
        </div>

        <input
          ref="navVisualSearchInputElement"
         
          type="file"
          accept="image/*"
          capture="environment"
          @change="handleNavVisualSearchSelection"
        >
      </form>
    </Transition>

    <div v-if="showConsumerNavigation">
      <template v-for="section in PRIMARY_NAVIGATION" :key="section.key">
        <div v-if="section.groups?.length">
          <button
           
            type="button"
            :aria-expanded="openDropdownKey === section.key ? 'true' : 'false'"
            :aria-label="`Hape menune per ${section.label}`"
            @click="toggleDropdown(section.key)"
          >
            <span>{{ section.label }}</span>
            <svg viewBox="0 0 24 24" aria-hidden="true">
              <path d="m7 10 5 5 5-5"></path>
            </svg>
          </button>

          <div :hidden="openDropdownKey !== section.key">
            <RouterLink
             
              :to="section.href"
              @click="closeExpandedPanels"
            >
              Shih te gjitha
            </RouterLink>

            <div>
              <RouterLink
                v-for="group in section.groups"
                :key="group.key"
               
                :to="group.href"
                @click="closeExpandedPanels"
              >
                {{ group.label }}
              </RouterLink>
            </div>
          </div>
        </div>

        <RouterLink
          v-else
         
          :to="section.href"
          @click="closeExpandedPanels"
        >
          {{ section.label }}
        </RouterLink>
      </template>
    </div>

    <div>
      <RouterLink
        v-if="isBusinessUser"
       
        to="/biznesi-juaj?view=add-product"
        aria-label="Shto artikull te ri"
      >
        <svg viewBox="0 0 24 24" aria-hidden="true">
          <path d="M12 5v14"></path>
          <path d="M5 12h14"></path>
        </svg>
      </RouterLink>

      <button
       
        type="button"
        aria-label="Kerko ketu"
        :aria-expanded="searchMenuOpen ? 'true' : 'false'"
        @click="toggleSearchPanel"
      >
        <svg viewBox="0 0 24 24" aria-hidden="true">
          <circle cx="11" cy="11" r="6"></circle>
          <path d="m20 20-4.2-4.2"></path>
        </svg>
      </button>

      <RouterLink
        v-if="showConsumerNavigation"
       
        to="/wishlist"
        aria-label="Wishlist"
      >
        <svg viewBox="0 0 24 24" aria-hidden="true">
          <path d="M12 20.4 4.9 13.8a4.8 4.8 0 0 1 6.8-6.8l.3.3.3-.3a4.8 4.8 0 1 1 6.8 6.8Z"></path>
        </svg>
      </RouterLink>

      <RouterLink
        v-if="showConsumerNavigation"
       
        to="/cart"
        aria-label="My Cart"
      >
        <svg viewBox="0 0 24 24" aria-hidden="true">
          <path d="M3 5h2l2.1 9.1a1 1 0 0 0 1 .8h8.8a1 1 0 0 0 1-.8L20 8H7.2"></path>
          <circle cx="10" cy="19" r="1.4"></circle>
          <circle cx="18" cy="19" r="1.4"></circle>
        </svg>
        <span :hidden="appState.cartCount <= 0">{{ cartBadgeLabel }}</span>
      </RouterLink>

      <button
        v-if="showMessagesShortcut"
       
        type="button"
        aria-label="Mesazhet"
        @click="handleMessagesClick"
      >
        <svg viewBox="0 0 24 24" aria-hidden="true">
          <path d="M5 6.5h14a1.5 1.5 0 0 1 1.5 1.5v8a1.5 1.5 0 0 1-1.5 1.5H10l-4.5 3v-3H5A1.5 1.5 0 0 1 3.5 16V8A1.5 1.5 0 0 1 5 6.5Z"></path>
        </svg>
        <span :hidden="unreadMessagesCount <= 0">{{ unreadMessagesBadgeLabel }}</span>
      </button>

      <template v-if="!appState.user">
        <RouterLink to="/login">
          Login
        </RouterLink>
        <RouterLink to="/signup">
          Sign Up
        </RouterLink>
      </template>

      <div
        v-else
       
       
      >
        <button
         
          type="button"
          :aria-expanded="userMenuOpen && !isMobileViewport ? 'true' : 'false'"
          aria-label="Hape menune e perdoruesit"
          @click="handleUserTrigger"
        >
          <span aria-hidden="true">
            <img
              v-if="userAvatarPath"
             
              :src="userAvatarPath"
              :alt="userDisplayName"
              width="160"
              height="160"
              loading="lazy"
              decoding="async"
            >
            <span v-else>
              <svg viewBox="0 0 24 24" aria-hidden="true">
                <path d="M12 12a4.25 4.25 0 1 0-4.25-4.25A4.25 4.25 0 0 0 12 12Z"></path>
                <path d="M4.75 19.25a7.25 7.25 0 0 1 14.5 0"></path>
              </svg>
            </span>
          </span>

          <span>
            <span>{{ userDisplayName }}</span>
          </span>

          <svg viewBox="0 0 24 24" aria-hidden="true">
            <path d="m7 10 5 5 5-5"></path>
          </svg>
        </button>

        <Transition name="nav-floating-panel">
          <div v-if="userMenuOpen && !isMobileViewport">
            <div>
              <span aria-hidden="true">
                <img
                  v-if="userAvatarPath"
                 
                  :src="userAvatarPath"
                  :alt="userDisplayName"
                  width="160"
                  height="160"
                  loading="lazy"
                  decoding="async"
                >
                <span v-else>
                  <svg viewBox="0 0 24 24" aria-hidden="true">
                    <path d="M12 12a4.25 4.25 0 1 0-4.25-4.25A4.25 4.25 0 0 0 12 12Z"></path>
                    <path d="M4.75 19.25a7.25 7.25 0 0 1 14.5 0"></path>
                  </svg>
                </span>
              </span>

              <div>
                <p>{{ userPanelLabel }}</p>
                <strong>{{ userDisplayName }}</strong>
                <span>{{ appState.user.email }}</span>
              </div>
            </div>

            <div>
              <RouterLink
                v-for="link in userMenuLinks"
                :key="link.href"
               
                :to="link.href"
                @click="closeExpandedPanels"
              >
                <span>{{ link.label }}</span>
                <span
                  v-if="link.showUnreadNotifications && unreadNotificationsCount > 0"
                 
                >
                  {{ unreadNotificationsBadgeLabel }}
                </span>
              </RouterLink>
            </div>

            <button type="button" @click="handleLogout">
              Shkycu
            </button>
          </div>
        </Transition>
      </div>
    </div>
  </nav>
</template>
