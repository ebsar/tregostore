document.addEventListener("DOMContentLoaded", () => {
  initializeLoadingScreen();
  initializeBrandLogo();
  initializeSiteNavigation();
  initializeLoginGreeting();
  const page = document.body.dataset.page;

  if (page === "home") {
    initializeHomePage();
    return;
  }

  if (page === "login") {
    initializeLoginPage();
    return;
  }

  if (page === "forgot-password") {
    initializeForgotPasswordPage();
    return;
  }

  if (page === "signup") {
    initializeSignupPage();
    return;
  }

  if (page === "verify-email") {
    initializeVerifyEmailPage();
    return;
  }

  if (page === "account") {
    initializeAccountPage();
    return;
  }

  if (page === "business-dashboard") {
    initializeBusinessDashboardPage();
    return;
  }

  if (page === "orders") {
    initializeOrdersPage();
    return;
  }

  if (page === "business-orders") {
    initializeBusinessOrdersPage();
    return;
  }

  if (page === "change-password") {
    initializeChangePasswordPage();
    return;
  }

  if (page === "personal-data") {
    initializePersonalDataPage();
    return;
  }

  if (page === "addresses") {
    initializeAddressesPage();
    return;
  }

  if (page === "checkout-address") {
    initializeCheckoutAddressPage();
    return;
  }

  if (page === "payment-options") {
    initializePaymentOptionsPage();
    return;
  }

  if (page === "product-detail") {
    initializeProductDetailPage();
    return;
  }

  if (page === "pets") {
    initializePetsPage();
    return;
  }

  if (page === "search") {
    initializeSearchPage();
    return;
  }

  if (page === "business-profile") {
    initializeBusinessProfilePage();
    return;
  }

  if (page === "wishlist") {
    initializeWishlistPage();
    return;
  }

  if (page === "cart") {
    initializeCartPage();
    return;
  }

  if (page === "registered-businesses") {
    initializeRegisteredBusinessesPage();
    return;
  }

  if (page === "admin-products") {
    initializeAdminProductsPage();
  }
});

const CHECKOUT_ADDRESS_DRAFT_KEY = "trego_checkout_address";
const CHECKOUT_PAYMENT_METHOD_KEY = "trego_checkout_payment_method";
const CHECKOUT_SELECTED_CART_IDS_KEY = "trego_checkout_selected_cart_ids";
const ORDER_CONFIRMATION_MESSAGE_KEY = "trego_order_confirmation_message";
const LOGIN_GREETING_KEY = "trego_login_greeting";


function getVerifyEmailUrl(email = "") {
  const cleanEmail = String(email || "").trim();
  if (!cleanEmail) {
    return "/verifiko-email";
  }

  return `/verifiko-email?email=${encodeURIComponent(cleanEmail)}`;
}


function initializeBrandLogo() {
  const brandLinks = document.querySelectorAll(".brand");

  brandLinks.forEach((brandLink) => {
    if (brandLink.querySelector(".brand-logo")) {
      return;
    }

    brandLink.classList.add("has-logo");
    brandLink.innerHTML = `
      <img class="brand-logo" src="/trego-logo.png" alt="Logo e TREGO">
      <span class="sr-only">TREGO</span>
    `;
  });
}


function initializeLoginGreeting() {
  const greetingName = consumeLoginGreeting();
  if (!greetingName) {
    return;
  }

  const toast = document.createElement("div");
  toast.className = "login-greeting-toast";
  toast.textContent = `Pershendetje ${greetingName}!`;
  document.body.appendChild(toast);

  window.requestAnimationFrame(() => {
    toast.classList.add("is-visible");
  });

  window.setTimeout(() => {
    toast.classList.remove("is-visible");
    window.setTimeout(() => {
      toast.remove();
    }, 260);
  }, 2400);
}


function initializeLoadingScreen() {
  if (document.querySelector(".app-loader")) {
    return;
  }

  const loader = document.createElement("div");
  loader.className = "app-loader";
  loader.setAttribute("aria-hidden", "true");
  loader.innerHTML = `
    <div class="app-loader-backdrop"></div>
    <div class="app-loader-panel">
      <div class="app-loader-icons">
        <span class="app-loader-icon-chip app-loader-icon-chip-bag">
          ${shoppingBagIcon()}
        </span>
        <span class="app-loader-icon-chip app-loader-icon-chip-cart">
          ${loaderCartIcon()}
        </span>
        <span class="app-loader-icon-chip app-loader-icon-chip-box">
          ${packageIcon()}
        </span>
      </div>
      <p class="app-loader-copy">Duke hapur dyqanin online...</p>
      <strong class="app-loader-brand">TREGO</strong>
    </div>
  `;

  document.body.append(loader);

  const startedAt = Date.now();
  let isHidden = false;

  const hideLoader = () => {
    if (isHidden) {
      return;
    }

    const elapsed = Date.now() - startedAt;
    const remaining = Math.max(0, 700 - elapsed);

    window.setTimeout(() => {
      if (isHidden) {
        return;
      }

      isHidden = true;
      loader.classList.add("is-hidden");
      window.setTimeout(() => {
        loader.remove();
      }, 700);
    }, remaining);
  };

  window.addEventListener("load", hideLoader, { once: true });
  window.setTimeout(hideLoader, 2200);
}


function initializeSiteNavigation() {
  const navLinks = document.querySelector(".nav-links");
  const navActions = document.querySelector(".nav-actions");
  const loginLink = navActions?.querySelector(".nav-link-login");
  const signupLink = navActions?.querySelector(".nav-link-signup");

  if (navLinks) {
    navLinks.innerHTML = renderPrimaryNavigation();
    initializePrimaryNavDropdowns(navLinks);
  }

  if (!navActions || !loginLink || !signupLink) {
    return;
  }

  if (!navActions.querySelector(".search-button")) {
    const searchLink = document.createElement("a");
    searchLink.className = "nav-icon-button search-button";
    searchLink.href = "/kerko";
    searchLink.setAttribute("aria-label", "Kerko");
    searchLink.innerHTML = searchIcon();
    navActions.insertBefore(searchLink, navActions.firstChild);
  }

  bootstrap();

  async function bootstrap() {
    const currentUser = await fetchCurrentUserOptional();
    if (!currentUser) {
      return;
    }

    loginLink.remove();
    signupLink.remove();
    const adminLinks = currentUser.role === "admin"
      ? `
          <a class="nav-user-panel-link" href="/admin-products">Artikujt</a>
          <a class="nav-user-panel-link" href="/bizneset-e-regjistruara">Bizneset e regjistruara</a>
        `
      : "";
    const businessLink = currentUser.role === "business"
      ? `
          <a class="nav-user-panel-link" href="/biznesi-juaj">Biznesi juaj</a>
          <a class="nav-user-panel-link nav-user-panel-link-secondary" href="/porosite-e-biznesit">Porosite e biznesit</a>
        `
      : "";

    const menu = document.createElement("div");
    menu.className = "nav-user-menu";
    menu.innerHTML = `
      <button class="nav-user-trigger" type="button" aria-expanded="false" aria-label="Hape menune e perdoruesit">
        <span class="nav-user-name">${escapeHtml(currentUser.fullName)}</span>
      </button>
      <div class="nav-user-panel" hidden>
        <p class="nav-user-panel-label">Llogaria ime</p>
        <strong class="nav-user-panel-name">${escapeHtml(currentUser.fullName)}</strong>
        <span class="nav-user-panel-email">${escapeHtml(currentUser.email)}</span>
        <div class="nav-user-panel-links">
          ${adminLinks}
          ${businessLink}
          <a class="nav-user-panel-link" href="/te-dhenat-personale">Te dhenat personale</a>
          <a class="nav-user-panel-link nav-user-panel-link-secondary" href="/adresat">Adresat</a>
          <a class="nav-user-panel-link nav-user-panel-link-secondary" href="/porosite">Porosite</a>
          <a class="nav-user-panel-link nav-user-panel-link-secondary" href="/ndrysho-fjalekalimin">Ndryshimi i fjalekalimit</a>
        </div>
        <button class="nav-user-panel-logout" type="button">Shkycu</button>
      </div>
    `;

    navActions.append(menu);

    const trigger = menu.querySelector(".nav-user-trigger");
    const panel = menu.querySelector(".nav-user-panel");
    const logoutButton = menu.querySelector(".nav-user-panel-logout");

    if (!trigger || !panel || !logoutButton) {
      return;
    }

    trigger.addEventListener("click", async () => {
      const isOpen = !panel.hidden;
      panel.hidden = isOpen;
      trigger.setAttribute("aria-expanded", isOpen ? "false" : "true");
      menu.classList.toggle("open", !isOpen);
    });

    logoutButton.addEventListener("click", async () => {
      setButtonLoading(logoutButton, true, "Shkycu", "Duke dale...");

      try {
        const { response, data } = await requestJson("/api/logout", {
          method: "POST",
        });

        if (!response.ok || !data.ok) {
          return;
        }

        window.location.href = data.redirectTo || "/login";
      } catch (error) {
        console.error(error);
      } finally {
        setButtonLoading(logoutButton, false, "Shkycu", "Duke dale...");
      }
    });

    document.addEventListener("click", (event) => {
      if (!menu.contains(event.target)) {
        panel.hidden = true;
        trigger.setAttribute("aria-expanded", "false");
        menu.classList.remove("open");
      }
    });

    document.addEventListener("keydown", (event) => {
      if (event.key === "Escape") {
        panel.hidden = true;
        trigger.setAttribute("aria-expanded", "false");
        menu.classList.remove("open");
      }
    });
  }
}


function renderPrimaryNavigation() {
  return `
    <div class="nav-dropdown">
      <button class="nav-dropdown-trigger" type="button" aria-expanded="false">
        <span>Veshje</span>
        ${chevronDownIcon()}
      </button>
      <div class="nav-dropdown-menu" hidden>
        <a class="nav-dropdown-item" href="/kerko?category=clothing-men">Meshkuj</a>
        <a class="nav-dropdown-item" href="/kerko?category=clothing-women">Femra</a>
        <a class="nav-dropdown-item" href="/kerko?category=clothing-kids">Femije</a>
      </div>
    </div>
    <div class="nav-dropdown">
      <button class="nav-dropdown-trigger" type="button" aria-expanded="false">
        <span>Kozmetik</span>
        ${chevronDownIcon()}
      </button>
      <div class="nav-dropdown-menu" hidden>
        <a class="nav-dropdown-item" href="/kerko?category=cosmetics-men">Meshkuj</a>
        <a class="nav-dropdown-item" href="/kerko?category=cosmetics-women">Femra</a>
        <a class="nav-dropdown-item" href="/kerko?category=cosmetics-kids">Femije</a>
      </div>
    </div>
    <a class="nav-link nav-link-home" href="/kerko?category=home">Shtepi</a>
    <a class="nav-link nav-link-sport" href="/kerko?category=sport">Sport</a>
    <a class="nav-link nav-link-tech" href="/kerko?category=technology">Teknologji</a>
  `;
}


function initializePrimaryNavDropdowns(navLinks) {
  const dropdowns = Array.from(navLinks.querySelectorAll(".nav-dropdown"));
  if (dropdowns.length === 0) {
    return;
  }

  const closeDropdown = (dropdown) => {
    const trigger = dropdown.querySelector(".nav-dropdown-trigger");
    const menu = dropdown.querySelector(".nav-dropdown-menu");
    if (!trigger || !menu) {
      return;
    }

    dropdown.classList.remove("open");
    trigger.setAttribute("aria-expanded", "false");
    menu.hidden = true;
  };

  const openDropdown = (dropdown) => {
    const trigger = dropdown.querySelector(".nav-dropdown-trigger");
    const menu = dropdown.querySelector(".nav-dropdown-menu");
    if (!trigger || !menu) {
      return;
    }

    dropdowns.forEach((item) => {
      if (item !== dropdown) {
        closeDropdown(item);
      }
    });

    dropdown.classList.add("open");
    trigger.setAttribute("aria-expanded", "true");
    menu.hidden = false;
  };

  dropdowns.forEach((dropdown) => {
    const trigger = dropdown.querySelector(".nav-dropdown-trigger");
    const menu = dropdown.querySelector(".nav-dropdown-menu");

    if (!trigger || !menu) {
      return;
    }

    trigger.addEventListener("click", (event) => {
      event.preventDefault();
      const shouldOpen = menu.hidden;

      if (shouldOpen) {
        openDropdown(dropdown);
        return;
      }

      closeDropdown(dropdown);
    });
  });

  document.addEventListener("click", (event) => {
    if (!navLinks.contains(event.target)) {
      dropdowns.forEach((dropdown) => {
        closeDropdown(dropdown);
      });
    }
  });

  document.addEventListener("keydown", (event) => {
    if (event.key !== "Escape") {
      return;
    }

    dropdowns.forEach((dropdown) => {
      closeDropdown(dropdown);
    });
  });
}


const PRODUCT_SECTION_OPTIONS = [
  { value: "clothing-men", label: "Veshje per meshkuj" },
  { value: "clothing-women", label: "Veshje per femra" },
  { value: "clothing-kids", label: "Veshje per femije" },
  { value: "cosmetics-men", label: "Kozmetik per meshkuj" },
  { value: "cosmetics-women", label: "Kozmetik per femra" },
  { value: "cosmetics-kids", label: "Kozmetik per femije" },
  { value: "home", label: "Shtepi" },
  { value: "sport", label: "Sport" },
  { value: "technology", label: "Teknologji" },
];

const SECTION_PRODUCT_TYPE_OPTIONS = {
  "clothing-men": [
    { value: "tshirt", label: "Maica" },
    { value: "undershirt", label: "Maica e brendshme" },
    { value: "pants", label: "Pantallona" },
    { value: "hoodie", label: "Duks" },
    { value: "turtleneck", label: "Rollke" },
    { value: "jacket", label: "Jakne" },
    { value: "underwear", label: "Te brendshme" },
    { value: "pajamas", label: "Pixhama" },
  ],
  "clothing-women": [
    { value: "tshirt", label: "Maica" },
    { value: "undershirt", label: "Maica e brendshme" },
    { value: "pants", label: "Pantallona" },
    { value: "hoodie", label: "Duks" },
    { value: "turtleneck", label: "Rollke" },
    { value: "jacket", label: "Jakne" },
    { value: "underwear", label: "Te brendshme" },
    { value: "pajamas", label: "Pixhama" },
  ],
  "clothing-kids": [
    { value: "tshirt", label: "Maica" },
    { value: "undershirt", label: "Maica e brendshme" },
    { value: "pants", label: "Pantallona" },
    { value: "hoodie", label: "Duks" },
    { value: "turtleneck", label: "Rollke" },
    { value: "jacket", label: "Jakne" },
    { value: "underwear", label: "Te brendshme" },
    { value: "pajamas", label: "Pixhama" },
  ],
  "cosmetics-men": [
    { value: "perfumes", label: "Parfume" },
    { value: "hygiene", label: "Higjiena" },
    { value: "creams", label: "Kremerat" },
  ],
  "cosmetics-women": [
    { value: "perfumes", label: "Parfume" },
    { value: "hygiene", label: "Higjiena" },
    { value: "creams", label: "Kremerat" },
    { value: "makeup", label: "Makup" },
    { value: "nails", label: "Thonjet" },
    { value: "hair-colors", label: "Ngjyrat e flokeve" },
  ],
  "cosmetics-kids": [
    { value: "hygiene", label: "Higjiena" },
    { value: "creams", label: "Kremerat" },
    { value: "kids-care", label: "Kujdes per femije" },
  ],
  home: [
    { value: "room-decor", label: "Dekorim per dhome" },
    { value: "bathroom-items", label: "Pjeset per banjo" },
    { value: "bedroom-items", label: "Pjeset per dhome te gjumit" },
    { value: "kids-room-items", label: "Pjese per dhomat e femijeve" },
  ],
  sport: [
    { value: "sports-equipment", label: "Pajisje sportive" },
    { value: "sportswear", label: "Veshje sportive" },
    { value: "sports-accessories", label: "Aksesor sportiv" },
  ],
  technology: [
    { value: "phone-cases", label: "Mbrojtese per telefon" },
    { value: "headphones", label: "Ndegjuesit" },
    { value: "phone-parts", label: "Pjese per telefon" },
    { value: "phone-accessories", label: "Aksesor te telefonave" },
  ],
};


function populateProductSectionSelect(selectElement, preferredValue = "") {
  if (!selectElement) {
    return;
  }

  selectElement.innerHTML = PRODUCT_SECTION_OPTIONS
    .map((option) => `
      <option value="${escapeAttribute(option.value)}">${escapeHtml(option.label)}</option>
    `)
    .join("");

  const nextValue = PRODUCT_SECTION_OPTIONS.some((option) => option.value === preferredValue)
    ? preferredValue
    : PRODUCT_SECTION_OPTIONS[0]?.value || "";

  selectElement.value = nextValue;
}


function populateProductTypeSelect(sectionValue, selectElement, preferredValue = "") {
  if (!selectElement) {
    return;
  }

  const options = SECTION_PRODUCT_TYPE_OPTIONS[sectionValue] || [];
  selectElement.innerHTML = options
    .map((option) => `
      <option value="${escapeAttribute(option.value)}">${escapeHtml(option.label)}</option>
    `)
    .join("");

  const nextValue = options.some((option) => option.value === preferredValue)
    ? preferredValue
    : options[0]?.value || "";

  selectElement.value = nextValue;
}


function isClothingSection(sectionValue) {
  return String(sectionValue || "").startsWith("clothing-");
}


function initializeSearchPage() {
  const form = document.getElementById("search-form");
  const input = document.getElementById("search-input");
  const submitButton = document.getElementById("search-submit-button");
  const sizeFilter = document.getElementById("search-size-filter");
  const colorFilter = document.getElementById("search-color-filter");
  const sortFilter = document.getElementById("search-sort-filter");
  const resetButton = document.getElementById("search-reset-button");
  const messageElement = document.getElementById("search-page-message");
  const resultsLabel = document.getElementById("search-results-label");
  const resultsGrid = document.getElementById("search-results-grid");

  if (
    !form ||
    !input ||
    !submitButton ||
    !sizeFilter ||
    !colorFilter ||
    !sortFilter ||
    !resetButton ||
    !messageElement ||
    !resultsLabel ||
    !resultsGrid
  ) {
    return;
  }

  let currentUser = null;
  let wishlistIds = new Set();
  let cartIds = new Set();
  const initialParams = new URLSearchParams(window.location.search);
  let currentQuery = initialParams.get("q")?.trim() || "";
  let currentCategory = initialParams.get("category")?.trim().toLowerCase() || "";
  let currentProductType = initialParams.get("productType")?.trim().toLowerCase() || "";
  let currentSize = initialParams.get("size")?.trim().toUpperCase() || "";
  let currentColor = initialParams.get("color")?.trim().toLowerCase() || "";
  let currentSort = initialParams.get("sort")?.trim().toLowerCase() || "";

  bootstrap();

  async function bootstrap() {
    currentUser = await fetchCurrentUserOptional();
    await refreshCollectionState();

    input.value = currentQuery;
    sizeFilter.value = currentSize;
    colorFilter.value = currentColor;
    sortFilter.value = currentSort;
    form.addEventListener("submit", handleSearchSubmit);
    sizeFilter.addEventListener("change", handleFilterChange);
    colorFilter.addEventListener("change", handleFilterChange);
    sortFilter.addEventListener("change", handleFilterChange);
    resetButton.addEventListener("click", handleResetFilters);
    resultsGrid.addEventListener("click", handleGridAction);
    await loadSearchResults(currentQuery);
  }

  async function refreshCollectionState() {
    if (!currentUser) {
      wishlistIds = new Set();
      cartIds = new Set();
      return;
    }

    const [wishlistItems, cartItems] = await Promise.all([
      fetchProtectedCollection("/api/wishlist"),
      fetchProtectedCollection("/api/cart"),
    ]);

    wishlistIds = new Set(wishlistItems.map((item) => item.id));
    cartIds = new Set(cartItems.map((item) => item.id));
  }

  async function handleSearchSubmit(event) {
    event.preventDefault();
    currentQuery = input.value.trim();
    updateSearchPageUrl();
    await loadSearchResults(currentQuery);
  }

  async function handleFilterChange() {
    currentSize = sizeFilter.value.trim().toUpperCase();
    currentColor = colorFilter.value.trim().toLowerCase();
    currentSort = sortFilter.value.trim().toLowerCase();
    updateSearchPageUrl();
    await loadSearchResults(currentQuery);
  }

  async function handleResetFilters() {
    currentQuery = "";
    currentCategory = "";
    currentProductType = "";
    currentSize = "";
    currentColor = "";
    currentSort = "";
    input.value = "";
    sizeFilter.value = "";
    colorFilter.value = "";
    sortFilter.value = "";
    updateSearchPageUrl();
    await loadSearchResults("");
  }

  function updateSearchPageUrl() {
    const nextParams = new URLSearchParams();
    if (currentQuery) {
      nextParams.set("q", currentQuery);
    }
    if (currentCategory) {
      nextParams.set("category", currentCategory);
    }
    if (currentProductType) {
      nextParams.set("productType", currentProductType);
    }
    if (currentSize) {
      nextParams.set("size", currentSize);
    }
    if (currentColor) {
      nextParams.set("color", currentColor);
    }
    if (currentSort) {
      nextParams.set("sort", currentSort);
    }

    const nextUrl = nextParams.toString()
      ? `/kerko?${nextParams.toString()}`
      : "/kerko";
    window.history.replaceState({}, "", nextUrl);
  }

  async function loadSearchResults(query) {
    showMessage(messageElement, "", "");
    resultsGrid.innerHTML = "";

    if (!query) {
      await loadAllProducts();
      return;
    }

    setButtonLoading(
      submitButton,
      true,
      "Kerko",
      "Duke kerkuar...",
    );

    try {
      const { response, data } = await requestJson(`/api/products/search?q=${encodeURIComponent(query)}`);

      if (!response.ok || !data.ok) {
        const message =
          data.errors?.join(" ") ||
          data.message ||
          "Kerkimi nuk funksionoi.";
        showMessage(messageElement, message, "error");
        resultsLabel.textContent = "";
        resultsGrid.innerHTML = `
          <div class="collection-empty-state">
            ${escapeHtml(message)}
          </div>
        `;
        return;
      }

      const products = Array.isArray(data.products) ? data.products : [];
      const filteredProducts = applySearchFilters(products);
      resultsLabel.textContent = buildSearchResultsLabel(query, filteredProducts.length);

      if (filteredProducts.length === 0) {
        resultsGrid.innerHTML = `
          <div class="collection-empty-state">
            Nuk u gjet asnje produkt per kerkimin dhe filtrat qe zgjodhe.
          </div>
        `;
        return;
      }

      resultsGrid.innerHTML = filteredProducts
        .map((product) =>
          renderPetProductCard(product, {
            isWishlisted: wishlistIds.has(product.id),
            isInCart: cartIds.has(product.id),
          }),
        )
        .join("");
    } catch (error) {
      showMessage(
        messageElement,
        "Serveri nuk po pergjigjet. Provoje perseri.",
        "error",
      );
      resultsGrid.innerHTML = `
        <div class="collection-empty-state">
          Kerkimi nuk funksionoi. Provoje perseri.
        </div>
      `;
      console.error(error);
    } finally {
      setButtonLoading(
        submitButton,
        false,
        "Kerko",
        "Duke kerkuar...",
      );
    }
  }

  async function loadAllProducts() {
    setButtonLoading(
      submitButton,
      true,
      "Kerko",
      "Duke ngarkuar...",
    );

    try {
      const { response, data } = await requestJson("/api/products");

      if (!response.ok || !data.ok) {
        const message =
          data.errors?.join(" ") ||
          data.message ||
          "Produktet nuk u ngarkuan.";
        showMessage(messageElement, message, "error");
        resultsLabel.textContent = "";
        resultsGrid.innerHTML = `
          <div class="collection-empty-state">
            ${escapeHtml(message)}
          </div>
        `;
        return;
      }

      const products = Array.isArray(data.products) ? data.products : [];
      const filteredProducts = applySearchFilters(products);
      resultsLabel.textContent = buildSearchResultsLabel("", filteredProducts.length);

      if (filteredProducts.length === 0) {
        resultsGrid.innerHTML = `
          <div class="collection-empty-state">
            Nuk ka produkte qe perputhen me filtrat e zgjedhur.
          </div>
        `;
        return;
      }

      resultsGrid.innerHTML = filteredProducts
        .map((product) =>
          renderPetProductCard(product, {
            isWishlisted: wishlistIds.has(product.id),
            isInCart: cartIds.has(product.id),
          }),
        )
        .join("");
    } catch (error) {
      showMessage(
        messageElement,
        "Serveri nuk po pergjigjet. Provoje perseri.",
        "error",
      );
      resultsGrid.innerHTML = `
        <div class="collection-empty-state">
          Produktet nuk u ngarkuan. Provoje perseri.
        </div>
      `;
      console.error(error);
    } finally {
      setButtonLoading(
        submitButton,
        false,
        "Kerko",
        "Duke ngarkuar...",
      );
    }
  }

  function applySearchFilters(products) {
    const filteredProducts = products.filter((product) => {
      const matchesCategory =
        !currentCategory || String(product.category || "").toLowerCase() === currentCategory;
      const matchesProductType =
        !currentProductType || String(product.productType || "").toLowerCase() === currentProductType;
      const matchesSize = !currentSize || String(product.size || "").toUpperCase() === currentSize;
      const matchesColor = !currentColor || String(product.color || "").toLowerCase() === currentColor;
      return matchesCategory && matchesProductType && matchesSize && matchesColor;
    });

    if (currentSort === "price-asc") {
      filteredProducts.sort((first, second) => Number(first.price) - Number(second.price));
    } else if (currentSort === "price-desc") {
      filteredProducts.sort((first, second) => Number(second.price) - Number(first.price));
    }

    return filteredProducts;
  }

  function buildSearchResultsLabel(query, totalProducts) {
    const activeFilters = [];
    if (currentCategory) {
      activeFilters.push(`Kategoria: ${formatCategoryLabel(currentCategory)}`);
    }
    if (currentProductType) {
      activeFilters.push(`Tipi: ${formatProductTypeLabel(currentProductType)}`);
    }
    if (currentSize) {
      activeFilters.push(`Madhesia: ${currentSize}`);
    }
    if (currentColor) {
      activeFilters.push(`Ngjyra: ${formatProductColorLabel(currentColor)}`);
    }
    if (currentSort === "price-asc") {
      activeFilters.push("Cmimi: nga me i uleti");
    } else if (currentSort === "price-desc") {
      activeFilters.push("Cmimi: nga me i larti");
    }

    const prefix = query
      ? `Rezultatet per "${query}"`
      : "Te gjitha produktet";
    const suffix = activeFilters.length > 0
      ? ` • ${activeFilters.join(" • ")}`
      : "";

    return `${prefix} • ${totalProducts} produkt/e${suffix}`;
  }

  async function handleGridAction(event) {
    const button = event.target.closest("[data-action][data-product-id]");
    if (!button) {
      return;
    }

    if (!currentUser) {
      showMessage(
        messageElement,
        "Duhet te kyçesh ose te krijosh llogari para se te përdorësh wishlist ose cart.",
        "error",
      );
      return;
    }

    const productId = Number(button.dataset.productId);
    if (!Number.isFinite(productId)) {
      return;
    }

    const action = button.dataset.action;

    if (action === "wishlist") {
      const { response, data } = await requestJson("/api/wishlist/toggle", {
        method: "POST",
        body: JSON.stringify({ productId }),
      });

      if (!response.ok || !data.ok) {
        const message =
          data.errors?.join(" ") || data.message || "Wishlist nuk u perditesua.";
        showMessage(messageElement, message, "error");
        return;
      }

      wishlistIds = new Set((data.items || []).map((item) => item.id));
      showMessage(messageElement, data.message || "Wishlist u perditesua.", "success");
      await loadSearchResults(currentQuery);
      return;
    }

    if (action === "cart") {
      const { response, data } = await requestJson("/api/cart/add", {
        method: "POST",
        body: JSON.stringify({ productId }),
      });

      if (!response.ok || !data.ok) {
        const message =
          data.errors?.join(" ") || data.message || "Shporta nuk u perditesua.";
        showMessage(messageElement, message, "error");
        return;
      }

      cartIds = new Set((data.items || []).map((item) => item.id));
      showMessage(messageElement, data.message || "Produkti u shtua ne shporte.", "success");
      await loadSearchResults(currentQuery);
    }
  }
}


function initializeAddressesPage() {
  const form = document.getElementById("addresses-form");
  const messageElement = document.getElementById("addresses-page-message");
  const emptyState = document.getElementById("default-address-empty");
  const summaryElement = document.getElementById("default-address-summary");
  const addressLineInput = document.getElementById("address-line-input");
  const cityInput = document.getElementById("city-input");
  const countryInput = document.getElementById("country-input");
  const zipCodeInput = document.getElementById("zip-code-input");
  const phoneNumberInput = document.getElementById("phone-number-input");
  const saveButton = document.getElementById("addresses-save-button");
  const cancelButton = document.getElementById("addresses-cancel-button");

  if (
    !form ||
    !messageElement ||
    !emptyState ||
    !summaryElement ||
    !addressLineInput ||
    !cityInput ||
    !countryInput ||
    !zipCodeInput ||
    !phoneNumberInput ||
    !saveButton ||
    !cancelButton
  ) {
    return;
  }

  let initialAddress = null;

  bootstrap();

  async function bootstrap() {
    const currentUser = await fetchCurrentUserOptional();
    if (!currentUser) {
      window.location.href = "/login";
      return;
    }

    await loadAddress();
    form.addEventListener("submit", handleSave);
    cancelButton.addEventListener("click", handleCancel);
  }

  async function loadAddress() {
    showMessage(messageElement, "", "");

    try {
      const { response, data } = await requestJson("/api/address");

      if (!response.ok || !data.ok) {
        const message = data.message || "Adresa nuk u ngarkua.";
        showMessage(messageElement, message, "error");
        return;
      }

      initialAddress = data.address ? normalizeAddress(data.address) : createEmptyAddress();
      hydrateAddressForm(initialAddress);
      renderAddressSummary(data.address ? initialAddress : null);
    } catch (error) {
      showMessage(
        messageElement,
        "Serveri nuk po pergjigjet. Provoje perseri.",
        "error",
      );
      console.error(error);
    }
  }

  function hydrateAddressForm(address) {
    addressLineInput.value = address.addressLine;
    cityInput.value = address.city;
    countryInput.value = address.country;
    zipCodeInput.value = address.zipCode;
    phoneNumberInput.value = address.phoneNumber;
  }

  function renderAddressSummary(address) {
    const summaryLine = document.getElementById("address-summary-line");
    const summaryCity = document.getElementById("address-summary-city");
    const summaryCountry = document.getElementById("address-summary-country");
    const summaryZip = document.getElementById("address-summary-zip");
    const summaryPhone = document.getElementById("address-summary-phone");

    if (!summaryLine || !summaryCity || !summaryCountry || !summaryZip || !summaryPhone) {
      return;
    }

    if (!address) {
      emptyState.hidden = false;
      summaryElement.hidden = true;
      return;
    }

    emptyState.hidden = true;
    summaryElement.hidden = false;
    summaryLine.textContent = address.addressLine || "-";
    summaryCity.textContent = address.city || "-";
    summaryCountry.textContent = address.country || "-";
    summaryZip.textContent = address.zipCode || "-";
    summaryPhone.textContent = address.phoneNumber || "-";
  }

  function handleCancel() {
    hydrateAddressForm(initialAddress || createEmptyAddress());
    showMessage(messageElement, "", "");
  }

  async function handleSave(event) {
    event.preventDefault();
    showMessage(messageElement, "", "");

    const payload = {
      addressLine: addressLineInput.value.trim(),
      city: cityInput.value.trim(),
      country: countryInput.value.trim(),
      zipCode: zipCodeInput.value.trim(),
      phoneNumber: phoneNumberInput.value.trim(),
    };

    setButtonLoading(
      saveButton,
      true,
      "Ruaj",
      "Duke ruajtur...",
    );

    try {
      const { response, data } = await requestJson("/api/address", {
        method: "POST",
        body: JSON.stringify(payload),
      });

      if (!response.ok || !data.ok || !data.address) {
        const message =
          data.errors?.join(" ") ||
          data.message ||
          "Ruajtja e adreses nuk funksionoi.";
        showMessage(messageElement, message, "error");
        return;
      }

      initialAddress = normalizeAddress(data.address);
      hydrateAddressForm(initialAddress);
      renderAddressSummary(initialAddress);
      showMessage(
        messageElement,
        data.message || "Adresa default u ruajt.",
        "success",
      );
    } catch (error) {
      showMessage(
        messageElement,
        "Serveri nuk po pergjigjet. Provoje perseri.",
        "error",
      );
      console.error(error);
    } finally {
      setButtonLoading(
        saveButton,
        false,
        "Ruaj",
        "Duke ruajtur...",
      );
    }
  }
}


function initializeCheckoutAddressPage() {
  const messageElement = document.getElementById("checkout-address-message");
  const savedPanel = document.getElementById("checkout-saved-address-panel");
  const emptyState = document.getElementById("checkout-address-empty-state");
  const savedSummary = document.getElementById("checkout-saved-address-summary");
  const savedButton = document.getElementById("checkout-use-saved-button");
  const newAddressLead = document.getElementById("checkout-new-address-lead");
  const form = document.getElementById("checkout-address-form");
  const addressLineInput = document.getElementById("checkout-address-line-input");
  const cityInput = document.getElementById("checkout-city-input");
  const countryInput = document.getElementById("checkout-country-input");
  const zipCodeInput = document.getElementById("checkout-zip-code-input");
  const phoneNumberInput = document.getElementById("checkout-phone-number-input");
  const saveAddressOption = document.getElementById("checkout-save-address-option");
  const saveAddressCheckbox = document.getElementById("checkout-save-address-checkbox");
  const submitButton = document.getElementById("checkout-address-submit");
  const cancelButton = document.getElementById("checkout-address-cancel");

  if (
    !messageElement ||
    !savedPanel ||
    !emptyState ||
    !savedSummary ||
    !savedButton ||
    !newAddressLead ||
    !form ||
    !addressLineInput ||
    !cityInput ||
    !countryInput ||
    !zipCodeInput ||
    !phoneNumberInput ||
    !saveAddressOption ||
    !saveAddressCheckbox ||
    !submitButton ||
    !cancelButton
  ) {
    return;
  }

  let savedAddress = null;

  bootstrap();

  async function bootstrap() {
    const currentUser = await fetchCurrentUserOptional();
    if (!currentUser) {
      window.location.href = "/login";
      return;
    }

    savedButton.addEventListener("click", handleContinueWithSavedAddress);
    submitButton.addEventListener("click", handleContinue);
    cancelButton.addEventListener("click", handleCancel);

    await loadSavedAddress();
  }

  async function loadSavedAddress() {
    showMessage(messageElement, "", "");

    try {
      const { response, data } = await requestJson("/api/address");

      if (!response.ok || !data.ok) {
        const message = data.errors?.join(" ") || data.message || "Adresa nuk u ngarkua.";
        showMessage(messageElement, message, "error");
        return;
      }

      savedAddress = data.address ? normalizeAddress(data.address) : null;
      renderSavedAddressSummary(savedAddress);
      hydrateAddressForm(readCheckoutAddressDraft() || createEmptyAddress());

      if (savedAddress) {
        savedPanel.hidden = false;
        emptyState.hidden = true;
        savedSummary.hidden = false;
        newAddressLead.textContent = "Ose vazhdo me regjistrimin e nje adrese te re.";
      } else {
        savedPanel.hidden = true;
        emptyState.hidden = false;
        savedSummary.hidden = true;
        newAddressLead.textContent = "Vazhdo me regjistrimin e adreses.";
      }
    } catch (error) {
      showMessage(
        messageElement,
        "Serveri nuk po pergjigjet. Provoje perseri.",
        "error",
      );
      console.error(error);
    }
  }

  function renderSavedAddressSummary(address) {
    const summaryLine = document.getElementById("checkout-summary-line");
    const summaryCity = document.getElementById("checkout-summary-city");
    const summaryCountry = document.getElementById("checkout-summary-country");
    const summaryZip = document.getElementById("checkout-summary-zip");
    const summaryPhone = document.getElementById("checkout-summary-phone");

    if (!summaryLine || !summaryCity || !summaryCountry || !summaryZip || !summaryPhone) {
      return;
    }

    if (!address) {
      savedSummary.hidden = true;
      return;
    }

    summaryLine.textContent = address.addressLine || "-";
    summaryCity.textContent = address.city || "-";
    summaryCountry.textContent = address.country || "-";
    summaryZip.textContent = address.zipCode || "-";
    summaryPhone.textContent = address.phoneNumber || "-";
  }

  function hydrateAddressForm(address) {
    addressLineInput.value = address.addressLine || "";
    cityInput.value = address.city || "";
    countryInput.value = address.country || "";
    zipCodeInput.value = address.zipCode || "";
    phoneNumberInput.value = address.phoneNumber || "";
    saveAddressCheckbox.checked = false;
  }

  function handleContinueWithSavedAddress() {
    showMessage(messageElement, "", "");

    if (!savedAddress) {
      return;
    }

    persistCheckoutAddressDraft(savedAddress);
    window.location.href = "/menyra-e-pageses";
  }

  function getAddressPayload() {
    return {
      addressLine: addressLineInput.value.trim(),
      city: cityInput.value.trim(),
      country: countryInput.value.trim(),
      zipCode: zipCodeInput.value.trim(),
      phoneNumber: phoneNumberInput.value.trim(),
    };
  }

  async function handleContinue() {
    showMessage(messageElement, "", "");

    if (!form.reportValidity()) {
      return;
    }

    const payload = getAddressPayload();

    if (!saveAddressCheckbox.checked) {
      persistCheckoutAddressDraft(payload);
      window.location.href = "/menyra-e-pageses";
      return;
    }

    setButtonLoading(
      submitButton,
      true,
      "Konfirmo adresen",
      "Duke ruajtur...",
    );

    try {
      const { response, data } = await requestJson("/api/address", {
        method: "POST",
        body: JSON.stringify(payload),
      });

      if (!response.ok || !data.ok || !data.address) {
        const message =
          data.errors?.join(" ") ||
          data.message ||
          "Ruajtja e adreses nuk funksionoi.";
        showMessage(messageElement, message, "error");
        return;
      }

      savedAddress = normalizeAddress(data.address);
      persistCheckoutAddressDraft(savedAddress);
      renderSavedAddressSummary(savedAddress);
      savedPanel.hidden = false;
      emptyState.hidden = true;
      hydrateAddressForm(savedAddress);
      savedSummary.hidden = false;
      newAddressLead.textContent = "Ose vazhdo me regjistrimin e nje adrese te re.";
      window.location.href = "/menyra-e-pageses";
    } catch (error) {
      showMessage(
        messageElement,
        "Serveri nuk po pergjigjet. Provoje perseri.",
        "error",
      );
      console.error(error);
    } finally {
      setButtonLoading(
        submitButton,
        false,
        "Vazhdo me regjistrimin e adreses",
        "Duke ruajtur...",
      );
    }
  }

  function handleCancel() {
    showMessage(messageElement, "", "");
    hydrateAddressForm(readCheckoutAddressDraft() || createEmptyAddress());
  }
}


function initializePaymentOptionsPage() {
  const messageElement = document.getElementById("payment-options-message");
  const submitButton = document.getElementById("payment-options-submit");
  const cancelButton = document.getElementById("payment-options-cancel");
  const optionButtons = Array.from(document.querySelectorAll("[data-payment-method]"));

  if (!messageElement || !submitButton || !cancelButton || optionButtons.length === 0) {
    return;
  }

  let selectedMethod = readCheckoutPaymentMethod();
  let currentUser = null;

  bootstrap();

  async function bootstrap() {
    currentUser = await fetchCurrentUserOptional();
    if (!currentUser) {
      window.location.href = "/login";
      return;
    }

    const checkoutAddress = readCheckoutAddressDraft();
    if (!checkoutAddress || !checkoutAddress.addressLine) {
      window.location.href = "/adresa-e-porosise";
      return;
    }

    const selectedCartIds = readCheckoutSelectedCartIds();
    if (selectedCartIds.length === 0) {
      window.location.href = "/cart";
      return;
    }

    renderSelectedMethod();
    optionButtons.forEach((button) => {
      button.addEventListener("click", () => {
        selectedMethod = button.dataset.paymentMethod || "";
        renderSelectedMethod();
        showMessage(messageElement, "", "");
      });
    });
    submitButton.addEventListener("click", handleSubmit);
    cancelButton.addEventListener("click", () => {
      window.location.href = "/adresa-e-porosise";
    });
  }

  function renderSelectedMethod() {
    optionButtons.forEach((button) => {
      const isActive = (button.dataset.paymentMethod || "") === selectedMethod;
      button.classList.toggle("active", isActive);
      button.setAttribute("aria-pressed", String(isActive));
    });
  }

  function handleSubmit() {
    showMessage(messageElement, "", "");

    if (!selectedMethod) {
      showMessage(
        messageElement,
        "Zgjedhe nje menyre pagese para se te vazhdosh.",
        "error",
      );
      return;
    }

    submitOrder();
  }

  async function submitOrder() {
    const checkoutAddress = readCheckoutAddressDraft();
    const selectedCartIds = readCheckoutSelectedCartIds();

    if (!checkoutAddress || !checkoutAddress.addressLine) {
      window.location.href = "/adresa-e-porosise";
      return;
    }

    if (!currentUser) {
      window.location.href = "/login";
      return;
    }

    if (selectedCartIds.length === 0) {
      showMessage(
        messageElement,
        "Nuk ka produkte te zgjedhura per kete porosi. Kthehu te shporta.",
        "error",
      );
      return;
    }

    setButtonLoading(
      submitButton,
      true,
      "Konfirmo menyren e pageses",
      "Duke konfirmuar porosine...",
    );

    try {
      const payload = {
        productIds: selectedCartIds,
        paymentMethod: selectedMethod,
        ...checkoutAddress,
      };

      const { response, data } = await requestJson("/api/orders/create", {
        method: "POST",
        body: JSON.stringify(payload),
      });

      if (!response.ok || !data.ok) {
        const message =
          data.errors?.join(" ") ||
          data.message ||
          "Porosia nuk u konfirmua.";
        showMessage(messageElement, message, "error");
        return;
      }

      persistCheckoutPaymentMethod(selectedMethod);
      const notificationWarnings = Array.isArray(data.notificationWarnings)
        ? data.notificationWarnings.filter(Boolean)
        : [];
      const confirmationMessage = notificationWarnings.length > 0
        ? `${data.message || "Porosia u konfirmua me sukses."} ${notificationWarnings.join(" ")}`
        : (data.message || "Porosia u konfirmua me sukses.");
      persistOrderConfirmationMessage(confirmationMessage);
      clearCheckoutFlowState();
      window.location.href = "/porosite";
    } catch (error) {
      showMessage(
        messageElement,
        "Serveri nuk po pergjigjet. Provoje perseri.",
        "error",
      );
      console.error(error);
    } finally {
      setButtonLoading(
        submitButton,
        false,
        "Konfirmo menyren e pageses",
        "Duke konfirmuar porosine...",
      );
    }
  }
}


function initializePersonalDataPage() {
  const form = document.getElementById("personal-data-form");
  const messageElement = document.getElementById("personal-data-page-message");
  const emailElement = document.getElementById("profile-email");
  const createdAtElement = document.getElementById("profile-created-at");
  const photoPreviewElement = document.getElementById("personal-data-photo-preview");
  const profileImageInput = document.getElementById("personal-data-profile-image");
  const profileImageFileNameElement = document.getElementById("personal-data-photo-file-name");
  const firstNameInput = document.getElementById("personal-data-first-name");
  const lastNameInput = document.getElementById("personal-data-last-name");
  const birthDateInput = document.getElementById("personal-data-birth-date");
  const genderInput = document.getElementById("personal-data-gender");
  const saveButton = document.getElementById("personal-data-save-button");
  const cancelButton = document.getElementById("personal-data-cancel-button");
  const deleteForm = document.getElementById("personal-data-delete-form");
  const deletePasswordInput = document.getElementById("personal-data-delete-password");
  const deleteButton = document.getElementById("personal-data-delete-button");
  const deleteMessageElement = document.getElementById("personal-data-delete-message");

  if (
    !form ||
    !messageElement ||
    !emailElement ||
    !createdAtElement ||
    !photoPreviewElement ||
    !profileImageInput ||
    !profileImageFileNameElement ||
    !firstNameInput ||
    !lastNameInput ||
    !birthDateInput ||
    !genderInput ||
    !saveButton ||
    !cancelButton ||
    !deleteForm ||
    !deletePasswordInput ||
    !deleteButton ||
    !deleteMessageElement
  ) {
    return;
  }

  let initialProfile = null;
  let profilePhotoPreviewUrl = "";

  bootstrap();

  async function bootstrap() {
    const currentUser = await fetchCurrentUserOptional();
    if (!currentUser) {
      window.location.href = "/login";
      return;
    }

    initialProfile = getProfileValuesFromUser(currentUser);
    hydrateProfileForm(currentUser);
    showMessage(messageElement, "", "");

    form.addEventListener("submit", handleSave);
    cancelButton.addEventListener("click", handleCancel);
    profileImageInput.addEventListener("change", handleProfileImageChange);
    deleteForm.addEventListener("submit", handleDeleteAccount);
  }

  function hydrateProfileForm(user) {
    const profileValues = getProfileValuesFromUser(user);
    firstNameInput.value = profileValues.firstName;
    lastNameInput.value = profileValues.lastName;
    birthDateInput.value = profileValues.birthDate;
    genderInput.value = profileValues.gender;
    emailElement.textContent = user.email || "-";
    createdAtElement.textContent = formatDateLabel(user.createdAt);
    renderProfileImagePreview(profileValues.profileImagePath);
  }

  function handleCancel() {
    if (!initialProfile) {
      return;
    }

    firstNameInput.value = initialProfile.firstName;
    lastNameInput.value = initialProfile.lastName;
    birthDateInput.value = initialProfile.birthDate;
    genderInput.value = initialProfile.gender;
    profileImageInput.value = "";
    profileImageFileNameElement.textContent = "Nuk eshte zgjedhur asnje foto.";
    renderProfileImagePreview(initialProfile.profileImagePath);
    showMessage(messageElement, "", "");
  }

  function handleProfileImageChange() {
    const selectedFile = profileImageInput.files?.[0] || null;
    profileImageFileNameElement.textContent = selectedFile
      ? `Foto e zgjedhur: ${selectedFile.name}`
      : "Nuk eshte zgjedhur asnje foto.";
    renderProfileImagePreview(initialProfile?.profileImagePath || "");
  }

  async function handleSave(event) {
    event.preventDefault();
    showMessage(messageElement, "", "");

    setButtonLoading(
      saveButton,
      true,
      "Ruaj",
      "Duke ruajtur...",
    );

    let profileImagePath = initialProfile?.profileImagePath || "";
    const selectedProfileImage = profileImageInput.files?.[0] || null;

    if (selectedProfileImage) {
      const uploadedProfileImagePath = await uploadProfileImage(selectedProfileImage, messageElement);
      if (!uploadedProfileImagePath) {
        setButtonLoading(
          saveButton,
          false,
          "Ruaj",
          "Duke ruajtur...",
        );
        return;
      }

      profileImagePath = uploadedProfileImagePath;
    }

    const payload = {
      firstName: firstNameInput.value.trim(),
      lastName: lastNameInput.value.trim(),
      birthDate: birthDateInput.value,
      gender: genderInput.value,
      profileImagePath,
    };

    try {
      const { response, data } = await requestJson("/api/profile", {
        method: "POST",
        body: JSON.stringify(payload),
      });

      if (!response.ok || !data.ok || !data.user) {
        const message =
          data.errors?.join(" ") ||
          data.message ||
          "Ruajtja e te dhenave nuk funksionoi.";
        showMessage(messageElement, message, "error");
        return;
      }

      initialProfile = getProfileValuesFromUser(data.user);
      hydrateProfileForm(data.user);
      profileImageInput.value = "";
      profileImageFileNameElement.textContent = "Nuk eshte zgjedhur asnje foto.";
      updateNavigationUserInfo(data.user);
      showMessage(
        messageElement,
        data.message || "Te dhenat personale u ruajten.",
        "success",
      );
    } catch (error) {
      showMessage(
        messageElement,
        "Serveri nuk po pergjigjet. Provoje perseri.",
        "error",
      );
      console.error(error);
    } finally {
      setButtonLoading(
        saveButton,
        false,
        "Ruaj",
        "Duke ruajtur...",
      );
    }
  }

  function renderProfileImagePreview(currentImagePath = "") {
    revokeProfileImagePreviewUrl();
    const selectedFile = profileImageInput.files?.[0] || null;

    if (selectedFile) {
      profilePhotoPreviewUrl = URL.createObjectURL(selectedFile);
      photoPreviewElement.innerHTML = `
        <img class="profile-photo-image" src="${escapeAttribute(profilePhotoPreviewUrl)}" alt="${escapeAttribute(selectedFile.name)}">
      `;
      return;
    }

    if (currentImagePath) {
      photoPreviewElement.innerHTML = `
        <img class="profile-photo-image" src="${escapeAttribute(currentImagePath)}" alt="Foto e profilit">
      `;
      return;
    }

    const initials = getBusinessInitials(`${firstNameInput.value} ${lastNameInput.value}`.trim() || "User");
    photoPreviewElement.innerHTML = `
      <div class="profile-photo-placeholder">${escapeHtml(initials)}</div>
    `;
  }

  function revokeProfileImagePreviewUrl() {
    if (!profilePhotoPreviewUrl) {
      return;
    }

    URL.revokeObjectURL(profilePhotoPreviewUrl);
    profilePhotoPreviewUrl = "";
  }

  async function handleDeleteAccount(event) {
    event.preventDefault();
    showMessage(deleteMessageElement, "", "");

    const password = deletePasswordInput.value;
    const shouldDelete = window.confirm(
      "A je i sigurt qe deshiron ta fshish komplet llogarine?",
    );

    if (!shouldDelete) {
      return;
    }

    setButtonLoading(
      deleteButton,
      true,
      "Fshije llogarine",
      "Duke fshire...",
    );

    try {
      const { response, data } = await requestJson("/api/account/delete", {
        method: "POST",
        body: JSON.stringify({ password }),
      });

      if (!response.ok || !data.ok) {
        const message =
          data.errors?.join(" ") ||
          data.message ||
          "Fshirja e llogarise nuk funksionoi.";
        showMessage(deleteMessageElement, message, "error");
        return;
      }

      showMessage(
        deleteMessageElement,
        data.message || "Llogaria u fshi me sukses.",
        "success",
      );
      deleteForm.reset();
      window.setTimeout(() => {
        window.location.href = data.redirectTo || "/signup";
      }, 800);
    } catch (error) {
      showMessage(
        deleteMessageElement,
        "Serveri nuk po pergjigjet. Provoje perseri.",
        "error",
      );
      console.error(error);
    } finally {
      setButtonLoading(
        deleteButton,
        false,
        "Fshije llogarine",
        "Duke fshire...",
      );
    }
  }
}


function initializeAccountPage() {
  const pageMessage = document.getElementById("account-page-message");
  const nameElement = document.getElementById("account-full-name");
  const emailElement = document.getElementById("account-email");
  const createdAtElement = document.getElementById("account-created-at");
  const passwordForm = document.getElementById("account-password-form");
  const passwordMessage = document.getElementById("account-password-message");
  const passwordSubmit = document.getElementById("account-password-submit");

  if (
    !pageMessage ||
    !nameElement ||
    !emailElement ||
    !createdAtElement ||
    !passwordForm ||
    !passwordMessage ||
    !passwordSubmit
  ) {
    return;
  }

  bootstrap();

  async function bootstrap() {
    const currentUser = await fetchCurrentUserOptional();
    if (!currentUser) {
      window.location.href = "/login";
      return;
    }

    nameElement.textContent = currentUser.fullName;
    emailElement.textContent = currentUser.email;
    createdAtElement.textContent = formatDateLabel(currentUser.createdAt);
    showMessage(pageMessage, "", "");

    passwordForm.addEventListener("submit", handlePasswordChange);
  }

  async function handlePasswordChange(event) {
    event.preventDefault();
    showMessage(passwordMessage, "", "");

    const formData = new FormData(passwordForm);
    const payload = {
      currentPassword: formData.get("currentPassword")?.toString() || "",
      newPassword: formData.get("newPassword")?.toString() || "",
      confirmPassword: formData.get("confirmPassword")?.toString() || "",
    };

    setButtonLoading(
      passwordSubmit,
      true,
      "Ruaje fjalekalimin e ri",
      "Duke ruajtur...",
    );

    try {
      const { response, data } = await requestJson("/api/change-password", {
        method: "POST",
        body: JSON.stringify(payload),
      });

      if (!response.ok || !data.ok) {
        const message =
          data.errors?.join(" ") ||
          data.message ||
          "Ndryshimi i fjalekalimit nuk funksionoi.";
        showMessage(passwordMessage, message, "error");
        return;
      }

      showMessage(passwordMessage, data.message || "Fjalekalimi u ndryshua.", "success");
      passwordForm.reset();
      window.setTimeout(() => {
        window.location.href = data.redirectTo || "/login";
      }, 900);
    } catch (error) {
      showMessage(
        passwordMessage,
        "Serveri nuk po pergjigjet. Provoje perseri.",
        "error",
      );
      console.error(error);
    } finally {
      setButtonLoading(
        passwordSubmit,
        false,
        "Ruaje fjalekalimin e ri",
        "Duke ruajtur...",
      );
    }
  }
}


function initializeBusinessDashboardPage() {
  const userElement = document.getElementById("business-user-role");
  const accessElement = document.getElementById("business-access-note");
  const profileForm = document.getElementById("business-profile-form");
  const profileMessageElement = document.getElementById("business-profile-message");
  const profileSubmitButton = document.getElementById("business-profile-submit");
  const businessLogoInput = document.getElementById("business-logo");
  const businessLogoPreview = document.getElementById("business-logo-preview");
  const productFormSection = document.getElementById("business-product-form-section");
  const productForm = document.getElementById("business-product-form");
  const productFormMessageElement = document.getElementById("business-product-form-message");
  const productSubmitButton = document.getElementById("business-product-submit");
  const productsListMessageElement = document.getElementById("business-products-list-message");
  const productsListElement = document.getElementById("business-products-list");
  const productCategorySelect = document.getElementById("business-product-category");
  const productTypeSelect = document.getElementById("business-product-type");
  const productSizeField = document.getElementById("business-product-size-field");
  const productSizeSelect = document.getElementById("business-product-size");
  const productImagesInput = document.getElementById("business-product-images");
  const productUploadPreview = document.getElementById("business-product-upload-preview");

  if (
    !userElement ||
    !accessElement ||
    !profileForm ||
    !profileMessageElement ||
    !profileSubmitButton ||
    !businessLogoInput ||
    !businessLogoPreview ||
    !productFormSection ||
    !productForm ||
    !productFormMessageElement ||
    !productSubmitButton ||
    !productsListMessageElement ||
    !productsListElement ||
    !productCategorySelect ||
    !productTypeSelect ||
    !productSizeField ||
    !productSizeSelect ||
    !productImagesInput ||
    !productUploadPreview
  ) {
    return;
  }

  let currentUser = null;
  let businessProfile = null;
  let previewUrls = [];
  let businessLogoPreviewUrl = "";

  bootstrap();

  async function bootstrap() {
    try {
      const { response, data } = await requestJson("/api/me");

      if (!response.ok || !data.ok || !data.user) {
        window.location.href = "/login";
        return;
      }

      currentUser = data.user;
      userElement.textContent = `${data.user.fullName} • ${formatRoleLabel(data.user.role)}`;

      if (data.user.role === "admin") {
        window.location.href = "/admin-products";
        return;
      }

      if (data.user.role !== "business") {
        window.location.href = "/";
        return;
      }

      accessElement.textContent =
        "Je kyçur si biznes. Ketu mund ta regjistrosh biznesin dhe t'i menaxhosh vetem artikujt e tu.";
      populateProductSectionSelect(productCategorySelect);
      populateProductTypeSelect(productCategorySelect.value, productTypeSelect);
      syncProductSizeField();
      renderSelectedImagePreviews();
      await Promise.all([loadBusinessProfile(), loadProducts()]);

      profileForm.addEventListener("submit", handleBusinessProfileSave);
      businessLogoInput.addEventListener("change", handleBusinessLogoChange);
      productForm.addEventListener("submit", handleProductSubmit);
      productCategorySelect.addEventListener("change", handleProductSectionChange);
      productImagesInput.addEventListener("change", renderSelectedImagePreviews);
      productsListElement.addEventListener("click", handleListAction);
    } catch (error) {
      accessElement.textContent =
        "Nuk mund ta kontrollojme sesionin tani. Provoje perseri pas pak.";
      console.error(error);
    }
  }

  async function loadBusinessProfile() {
    showMessage(profileMessageElement, "", "");

    try {
      const { response, data } = await requestJson("/api/business-profile");

      if (!response.ok || !data.ok) {
        const message = data.errors?.join(" ") || data.message || "Biznesi nuk u ngarkua.";
        showMessage(profileMessageElement, message, "error");
        toggleProductForm(Boolean(businessProfile));
        return;
      }

      businessProfile = data.profile || null;
      hydrateBusinessProfileForm(businessProfile);
      toggleProductForm(Boolean(businessProfile));
    } catch (error) {
      showMessage(
        profileMessageElement,
        "Serveri nuk po pergjigjet. Provoje perseri.",
        "error",
      );
      toggleProductForm(Boolean(businessProfile));
      console.error(error);
    }
  }

  function hydrateBusinessProfileForm(profile) {
    const profileValues = {
      businessName: String(profile?.businessName || ""),
      businessDescription: String(profile?.businessDescription || ""),
      businessNumber: String(profile?.businessNumber || ""),
      logoPath: String(profile?.logoPath || ""),
      phoneNumber: String(profile?.phoneNumber || ""),
      city: String(profile?.city || ""),
      addressLine: String(profile?.addressLine || ""),
    };

    profileForm.elements.businessName.value = profileValues.businessName;
    profileForm.elements.businessDescription.value = profileValues.businessDescription;
    profileForm.elements.businessNumber.value = profileValues.businessNumber;
    profileForm.elements.phoneNumber.value = profileValues.phoneNumber;
    profileForm.elements.city.value = profileValues.city;
    profileForm.elements.addressLine.value = profileValues.addressLine;
    businessLogoInput.value = "";
    renderBusinessLogoPreview(profileValues.logoPath);
  }

  function toggleProductForm(hasBusinessProfile) {
    productFormSection.hidden = !hasBusinessProfile;

    if (hasBusinessProfile) {
      accessElement.textContent =
        "Biznesi yt eshte gati. Mund te shtosh artikuj dhe te menaxhosh vetem artikujt e biznesit tend.";
      return;
    }

    accessElement.textContent =
      "Ruaje fillimisht regjistrimin e biznesit qe te aktivizohet pjesa e artikujve.";
  }

  async function handleBusinessProfileSave(event) {
    event.preventDefault();
    showMessage(profileMessageElement, "", "");

    const formData = new FormData(profileForm);
    const logoFile = businessLogoInput.files?.[0] || null;
    const payload = {
      businessName: formData.get("businessName")?.toString().trim() || "",
      businessDescription: formData.get("businessDescription")?.toString().trim() || "",
      businessNumber: formData.get("businessNumber")?.toString().trim() || "",
      businessLogoPath: String(businessProfile?.logoPath || ""),
      phoneNumber: formData.get("phoneNumber")?.toString().trim() || "",
      city: formData.get("city")?.toString().trim() || "",
      addressLine: formData.get("addressLine")?.toString().trim() || "",
    };

    setButtonLoading(
      profileSubmitButton,
      true,
      "Ruaje biznesin",
      "Duke ruajtur...",
    );

    try {
      if (logoFile) {
        const uploadedLogoPaths = await uploadProductImagesForPanel(
          [logoFile],
          profileMessageElement,
        );
        if (uploadedLogoPaths.length === 0) {
          return;
        }

        payload.businessLogoPath = uploadedLogoPaths[0];
      }

      const { response, data } = await requestJson("/api/business-profile", {
        method: "POST",
        body: JSON.stringify(payload),
      });

      if (!response.ok || !data.ok || !data.profile) {
        const message =
          data.errors?.join(" ") ||
          data.message ||
          "Biznesi nuk u ruajt.";
        showMessage(profileMessageElement, message, "error");
        return;
      }

      businessProfile = data.profile;
      hydrateBusinessProfileForm(businessProfile);
      toggleProductForm(true);
      showMessage(
        profileMessageElement,
        data.message || "Biznesi u ruajt me sukses.",
        "success",
      );
    } catch (error) {
      showMessage(
        profileMessageElement,
        "Serveri nuk po pergjigjet. Provoje perseri.",
        "error",
      );
      console.error(error);
    } finally {
      setButtonLoading(
        profileSubmitButton,
        false,
        "Ruaje biznesin",
        "Duke ruajtur...",
      );
    }
  }

  function handleBusinessLogoChange() {
    renderBusinessLogoPreview(String(businessProfile?.logoPath || ""));
  }

  function renderBusinessLogoPreview(currentLogoPath = "") {
    revokeBusinessLogoPreviewUrl();
    const selectedFile = businessLogoInput.files?.[0] || null;

    if (selectedFile) {
      businessLogoPreviewUrl = URL.createObjectURL(selectedFile);
      businessLogoPreview.innerHTML = `
        <figure class="product-upload-preview-item business-logo-preview-item">
          <img class="product-upload-preview-image business-logo-preview-image" src="${escapeAttribute(businessLogoPreviewUrl)}" alt="${escapeAttribute(selectedFile.name)}">
          <figcaption class="product-upload-preview-name">
            Logo e zgjedhur • ${escapeHtml(selectedFile.name)}
          </figcaption>
        </figure>
      `;
      return;
    }

    if (currentLogoPath) {
      businessLogoPreview.innerHTML = `
        <figure class="product-upload-preview-item business-logo-preview-item">
          <img class="product-upload-preview-image business-logo-preview-image" src="${escapeAttribute(currentLogoPath)}" alt="Logo e biznesit">
          <figcaption class="product-upload-preview-name">
            Logo aktuale e biznesit
          </figcaption>
        </figure>
      `;
      return;
    }

    businessLogoPreview.innerHTML = `
      <div class="product-upload-empty">Nuk eshte zgjedhur asnje logo ende.</div>
    `;
  }

  function revokeBusinessLogoPreviewUrl() {
    if (!businessLogoPreviewUrl) {
      return;
    }

    URL.revokeObjectURL(businessLogoPreviewUrl);
    businessLogoPreviewUrl = "";
  }

  async function handleProductSubmit(event) {
    event.preventDefault();
    showMessage(productFormMessageElement, "", "");

    if (!businessProfile) {
      showMessage(
        productFormMessageElement,
        "Regjistroje fillimisht biznesin para se te shtosh artikuj.",
        "error",
      );
      return;
    }

    const formData = new FormData(productForm);
    const imageFiles = Array.from(productImagesInput.files || []);
    const payload = {
      title: formData.get("title")?.toString().trim() || "",
      price: formData.get("price")?.toString().trim() || "",
      description: formData.get("description")?.toString().trim() || "",
      category: formData.get("category")?.toString().trim() || "",
      productType: formData.get("productType")?.toString().trim() || "",
      size: formData.get("size")?.toString().trim() || "",
      color: formData.get("color")?.toString().trim() || "",
      stockQuantity: formData.get("stockQuantity")?.toString().trim() || "",
    };

    if (imageFiles.length === 0) {
      showMessage(
        productFormMessageElement,
        "Zgjidh te pakten nje foto te produktit.",
        "error",
      );
      return;
    }

    setButtonLoading(
      productSubmitButton,
      true,
      "Ruaje artikullin",
      "Duke ruajtur...",
    );

    try {
      const uploadedImagePaths = await uploadProductImagesForPanel(
        imageFiles,
        productFormMessageElement,
      );
      if (uploadedImagePaths.length === 0) {
        return;
      }

      payload.imageGallery = uploadedImagePaths;
      payload.imagePath = uploadedImagePaths[0];

      const { response, data } = await requestJson("/api/products", {
        method: "POST",
        body: JSON.stringify(payload),
      });

      if (!response.ok || !data.ok) {
        const message =
          data.errors?.join(" ") ||
          data.message ||
          "Artikulli nuk u ruajt.";
        showMessage(productFormMessageElement, message, "error");
        return;
      }

      showMessage(
        productFormMessageElement,
        "Artikulli u ruajt me sukses ne biznesin tend.",
        "success",
      );
      productForm.reset();
      revokePreviewUrls();
      renderSelectedImagePreviews();
      productCategorySelect.value = PRODUCT_SECTION_OPTIONS[0]?.value || "";
      populateProductTypeSelect(productCategorySelect.value, productTypeSelect);
      productSizeSelect.value = "";
      document.getElementById("business-product-color").value = "";
      document.getElementById("business-product-stock-quantity").value = "1";
      syncProductSizeField();
      await loadProducts();
    } catch (error) {
      showMessage(
        productFormMessageElement,
        "Serveri nuk po pergjigjet. Provoje perseri.",
        "error",
      );
      console.error(error);
    } finally {
      setButtonLoading(
        productSubmitButton,
        false,
        "Ruaje artikullin",
        "Duke ruajtur...",
      );
    }
  }

  async function loadProducts() {
    try {
      const { response, data } = await requestJson("/api/business/products");

      if (!response.ok || !data.ok) {
        const message =
          data.errors?.join(" ") ||
          data.message ||
          "Lista e artikujve nuk u ngarkua.";
        showMessage(productsListMessageElement, message, "error");
        productsListElement.innerHTML = `
          <div class="admin-empty-state">
            ${escapeHtml(message)}
          </div>
        `;
        return;
      }

      const products = Array.isArray(data.products) ? data.products : [];
      if (products.length === 0) {
        productsListElement.innerHTML = `
          <div class="admin-empty-state">
            Ende nuk ke artikuj te publikuar nga ky biznes.
          </div>
        `;
        return;
      }

      showMessage(productsListMessageElement, "", "");
      productsListElement.innerHTML = products
        .map((product) => renderAdminProductItem(product))
        .join("");
    } catch (error) {
      productsListElement.innerHTML = `
        <div class="admin-empty-state">
          Artikujt nuk u ngarkuan. Provoje perseri.
        </div>
      `;
      console.error(error);
    }
  }

  async function handleListAction(event) {
    const button = event.target.closest("[data-action][data-product-id]");
    if (!button) {
      return;
    }

    const productId = Number(button.dataset.productId);
    if (!Number.isFinite(productId)) {
      return;
    }

    const productCard = button.closest(".admin-product-item");
    const action = button.dataset.action;

    if (action === "delete-product") {
      const shouldDelete = window.confirm("A do ta fshish kete produkt?");
      if (!shouldDelete) {
        return;
      }

      await submitBusinessProductAction(
        "/api/products/delete",
        { productId },
        "Produkti u fshi me sukses.",
      );
      return;
    }

    if (action === "toggle-visibility") {
      const nextValue = button.dataset.nextValue === "true";
      await submitBusinessProductAction(
        "/api/products/public-visibility",
        { productId, isPublic: nextValue },
        nextValue
          ? "Produkti tani shfaqet per userat."
          : "Produkti u fsheh nga pamja publike.",
      );
      return;
    }

    if (action === "toggle-stock-public") {
      const nextValue = button.dataset.nextValue === "true";
      await submitBusinessProductAction(
        "/api/products/public-stock",
        { productId, showStockPublic: nextValue },
        nextValue
          ? "Gjendja ne stok tani shfaqet publikisht."
          : "Gjendja ne stok u fsheh nga pamja publike.",
      );
      return;
    }

    if (action === "restock" && productCard) {
      const input = productCard.querySelector("[data-restock-input]");
      const quantity = input?.value?.toString().trim() || "";

      await submitBusinessProductAction(
        "/api/products/restock",
        { productId, quantity },
        "Stoku u perditesua me sukses.",
      );

      if (input) {
        input.value = "1";
      }
    }
  }

  async function submitBusinessProductAction(url, payload, successMessage) {
    showMessage(productsListMessageElement, "", "");

    try {
      const { response, data } = await requestJson(url, {
        method: "POST",
        body: JSON.stringify(payload),
      });

      if (!response.ok || !data.ok) {
        const message =
          data.errors?.join(" ") ||
          data.message ||
          "Veprimi nuk u ruajt.";
        showMessage(productsListMessageElement, message, "error");
        return;
      }

      showMessage(
        productsListMessageElement,
        data.message || successMessage,
        "success",
      );
      await loadProducts();
    } catch (error) {
      showMessage(
        productsListMessageElement,
        "Serveri nuk po pergjigjet. Provoje perseri.",
        "error",
      );
      console.error(error);
    }
  }

  function handleProductSectionChange() {
    populateProductTypeSelect(productCategorySelect.value, productTypeSelect);
    syncProductSizeField();
  }

  function syncProductSizeField() {
    const isClothing = isClothingSection(productCategorySelect.value);
    productSizeField.hidden = !isClothing;
    productSizeSelect.required = isClothing;

    if (!isClothing) {
      productSizeSelect.value = "";
    }
  }

  function renderSelectedImagePreviews() {
    revokePreviewUrls();
    const files = Array.from(productImagesInput.files || []);

    if (files.length === 0) {
      productUploadPreview.innerHTML = `
        <div class="product-upload-empty">Asnje foto nuk eshte zgjedhur ende.</div>
      `;
      return;
    }

    productUploadPreview.innerHTML = files
      .map((file, index) => {
        const objectUrl = URL.createObjectURL(file);
        previewUrls.push(objectUrl);

        return `
          <figure class="product-upload-preview-item">
            <img class="product-upload-preview-image" src="${escapeAttribute(objectUrl)}" alt="${escapeAttribute(file.name)}">
            <figcaption class="product-upload-preview-name">
              ${index === 0 ? "Cover" : `Foto ${index + 1}`} • ${escapeHtml(file.name)}
            </figcaption>
          </figure>
        `;
      })
      .join("");
  }

  function revokePreviewUrls() {
    previewUrls.forEach((previewUrl) => {
      URL.revokeObjectURL(previewUrl);
    });
    previewUrls = [];
  }
}


function initializeOrdersPage() {
  const messageElement = document.getElementById("orders-page-message");
  const listElement = document.getElementById("orders-list");

  if (!messageElement || !listElement) {
    return;
  }

  bootstrap();

  async function bootstrap() {
    const currentUser = await fetchCurrentUserOptional();
    if (!currentUser) {
      window.location.href = "/login";
      return;
    }

    const confirmationMessage = consumeOrderConfirmationMessage();
    if (confirmationMessage) {
      showMessage(messageElement, confirmationMessage, "success");
    } else {
      showMessage(messageElement, "", "");
    }

    try {
      const { response, data } = await requestJson("/api/orders");
      if (!response.ok || !data.ok) {
        const message =
          data.errors?.join(" ") ||
          data.message ||
          "Porosite nuk u ngarkuan.";
        showMessage(messageElement, message, "error");
        listElement.innerHTML = renderOrdersEmptyState(message);
        return;
      }

      const orders = Array.isArray(data.orders) ? data.orders : [];
      if (orders.length === 0) {
        listElement.innerHTML = renderOrdersEmptyState("Ju nuk keni asnje porosi ende.");
        return;
      }

      listElement.innerHTML = orders.map((order) => renderUserOrderCard(order)).join("");
    } catch (error) {
      showMessage(messageElement, "Porosite nuk u ngarkuan. Provoje perseri.", "error");
      listElement.innerHTML = renderOrdersEmptyState("Porosite nuk u ngarkuan. Provoje perseri.");
      console.error(error);
    }
  }
}


function initializeBusinessOrdersPage() {
  const messageElement = document.getElementById("business-orders-page-message");
  const listElement = document.getElementById("business-orders-list");

  if (!messageElement || !listElement) {
    return;
  }

  bootstrap();

  async function bootstrap() {
    const currentUser = await fetchCurrentUserOptional();
    if (!currentUser) {
      window.location.href = "/login";
      return;
    }

    if (currentUser.role !== "business") {
      window.location.href = "/";
      return;
    }

    showMessage(messageElement, "", "");

    try {
      const { response, data } = await requestJson("/api/business/orders");
      if (!response.ok || !data.ok) {
        const message =
          data.errors?.join(" ") ||
          data.message ||
          "Porosite e biznesit nuk u ngarkuan.";
        showMessage(messageElement, message, "error");
        listElement.innerHTML = renderOrdersEmptyState(message);
        return;
      }

      const orders = Array.isArray(data.orders) ? data.orders : [];
      if (orders.length === 0) {
        listElement.innerHTML = renderOrdersEmptyState("Ende nuk ka porosi per biznesin tend.");
        return;
      }

      listElement.innerHTML = orders.map((order) => renderBusinessOrderCard(order)).join("");
    } catch (error) {
      showMessage(
        messageElement,
        "Porosite e biznesit nuk u ngarkuan. Provoje perseri.",
        "error",
      );
      listElement.innerHTML = renderOrdersEmptyState("Porosite e biznesit nuk u ngarkuan. Provoje perseri.");
      console.error(error);
    }
  }
}


function initializeRegisteredBusinessesPage() {
  const accessElement = document.getElementById("registered-businesses-access-note");
  const form = document.getElementById("admin-business-account-form");
  const formMessageElement = document.getElementById("registered-businesses-form-message");
  const submitButton = document.getElementById("admin-business-account-submit");
  const searchForm = document.getElementById("registered-businesses-search-form");
  const searchInput = document.getElementById("registered-businesses-search-input");
  const searchSubmitButton = document.getElementById("registered-businesses-search-submit");
  const searchResetButton = document.getElementById("registered-businesses-search-reset");
  const searchStatusElement = document.getElementById("registered-businesses-search-status");
  const messageElement = document.getElementById("registered-businesses-message");
  const listElement = document.getElementById("registered-businesses-list");
  const totalElement = document.getElementById("registered-businesses-total");

  if (
    !accessElement ||
    !form ||
    !formMessageElement ||
    !submitButton ||
    !searchForm ||
    !searchInput ||
    !searchSubmitButton ||
    !searchResetButton ||
    !searchStatusElement ||
    !messageElement ||
    !listElement ||
    !totalElement
  ) {
    return;
  }

  let allBusinesses = [];
  let currentSearchQuery = "";
  let editingBusinessId = null;

  bootstrap();

  async function bootstrap() {
    const currentUser = await fetchCurrentUserOptional();

    if (!currentUser) {
      window.location.href = "/login";
      return;
    }

    if (currentUser.role !== "admin") {
      window.location.href = "/";
      return;
    }

    accessElement.textContent =
      "Je kycur si admin. Ketu shfaqen bizneset e regjistruara ne TREGO dhe statistikat baze te tyre.";
    form.addEventListener("submit", handleBusinessAccountCreate);
    searchForm.addEventListener("submit", handleSearchSubmit);
    searchInput.addEventListener("input", handleSearchInput);
    searchResetButton.addEventListener("click", handleSearchReset);
    listElement.addEventListener("click", handleBusinessActionClick);
    listElement.addEventListener("submit", handleBusinessEditSubmit);
    listElement.addEventListener("change", handleBusinessLogoChange);
    await loadBusinesses();
  }

  async function loadBusinesses() {
    showMessage(messageElement, "", "");
    listElement.innerHTML = `
      <div class="collection-empty-state">
        Po ngarkohen bizneset e regjistruara...
      </div>
    `;

    try {
      const { response, data } = await requestJson("/api/admin/businesses");

      if (!response.ok || !data.ok) {
        const message =
          data.errors?.join(" ") ||
          data.message ||
          "Lista e bizneseve nuk u ngarkua.";
        totalElement.textContent = "0";
        showMessage(messageElement, message, "error");
        listElement.innerHTML = `
          <div class="collection-empty-state">
            ${escapeHtml(message)}
          </div>
        `;
        return;
      }

      allBusinesses = Array.isArray(data.businesses) ? data.businesses : [];
      if (
        editingBusinessId !== null &&
        !allBusinesses.some((business) => Number(business.id) === Number(editingBusinessId))
      ) {
        editingBusinessId = null;
      }
      totalElement.textContent = String(allBusinesses.length);
      renderBusinessesList();
    } catch (error) {
      totalElement.textContent = "0";
      allBusinesses = [];
      searchStatusElement.textContent = "";
      showMessage(
        messageElement,
        "Serveri nuk po pergjigjet. Provoje perseri.",
        "error",
      );
      listElement.innerHTML = `
        <div class="collection-empty-state">
          Serveri nuk po pergjigjet per bizneset.
        </div>
      `;
      console.error(error);
    }
  }

  async function handleBusinessAccountCreate(event) {
    event.preventDefault();
    showMessage(formMessageElement, "", "");

    const formData = new FormData(form);
    const payload = {
      fullName: formData.get("fullName")?.toString().trim() || "",
      email: formData.get("email")?.toString().trim() || "",
      password: formData.get("password")?.toString() || "",
      businessName: formData.get("businessName")?.toString().trim() || "",
      businessNumber: formData.get("businessNumber")?.toString().trim() || "",
      phoneNumber: formData.get("phoneNumber")?.toString().trim() || "",
      city: formData.get("city")?.toString().trim() || "",
      addressLine: formData.get("addressLine")?.toString().trim() || "",
      businessDescription: formData.get("businessDescription")?.toString().trim() || "",
    };

    setButtonLoading(
      submitButton,
      true,
      "Krijo llogarine e biznesit",
      "Duke krijuar...",
    );

    try {
      const { response, data } = await requestJson("/api/admin/businesses/create", {
        method: "POST",
        body: JSON.stringify(payload),
      });

      if (!response.ok || !data.ok) {
        const message =
          data.errors?.join(" ") ||
          data.message ||
          "Llogaria e biznesit nuk u krijua.";
        showMessage(formMessageElement, message, "error");
        return;
      }

      form.reset();
      showMessage(
        formMessageElement,
        data.message || "Llogaria e biznesit u krijua me sukses.",
        "success",
      );
      await loadBusinesses();
    } catch (error) {
      showMessage(
        formMessageElement,
        "Serveri nuk po pergjigjet. Provoje perseri.",
        "error",
      );
      console.error(error);
    } finally {
      setButtonLoading(
        submitButton,
        false,
        "Krijo llogarine e biznesit",
        "Duke krijuar...",
      );
    }
  }

  function handleSearchSubmit(event) {
    event.preventDefault();
    currentSearchQuery = searchInput.value.trim().toLowerCase();
    renderBusinessesList();
  }

  function handleSearchInput() {
    currentSearchQuery = searchInput.value.trim().toLowerCase();
    renderBusinessesList();
  }

  function handleSearchReset() {
    currentSearchQuery = "";
    searchInput.value = "";
    renderBusinessesList();
  }

  function renderBusinessesList() {
    const filteredBusinesses = filterBusinesses(allBusinesses, currentSearchQuery);

    if (allBusinesses.length === 0) {
      searchStatusElement.textContent = "";
      listElement.innerHTML = `
        <div class="collection-empty-state">
          Ende nuk ka biznese te regjistruara.
        </div>
      `;
      return;
    }

    searchStatusElement.textContent = currentSearchQuery
      ? `Po shfaqen ${filteredBusinesses.length} nga ${allBusinesses.length} biznese per kerkimin "${searchInput.value.trim()}".`
      : `Po shfaqen te gjitha ${allBusinesses.length} bizneset aktive.`;

    if (filteredBusinesses.length === 0) {
      listElement.innerHTML = `
        <div class="collection-empty-state">
          Nuk u gjet asnje biznes per kerkimin qe bere.
        </div>
      `;
      return;
    }

    listElement.innerHTML = filteredBusinesses
      .map((business) =>
        renderRegisteredBusinessCard(business, {
          isEditing: Number(business.id) === Number(editingBusinessId),
        }),
      )
      .join("");
  }

  function filterBusinesses(businesses, query) {
    if (!query) {
      return businesses;
    }

    return businesses.filter((business) => {
      const ownerName = String(business.ownerName || "").trim().toLowerCase();
      const businessName = String(business.businessName || "").trim().toLowerCase();
      const businessNumber = String(business.businessNumber || "").trim().toLowerCase();
      const searchableText = [ownerName, businessName, businessNumber].join(" ");
      return searchableText.includes(query);
    });
  }

  async function handleBusinessLogoChange(event) {
    const input = event.target.closest("input[data-business-logo-input]");
    if (!input) {
      return;
    }

    const businessId = Number(input.dataset.businessId);
    const selectedFile = input.files?.[0] || null;
    if (!Number.isFinite(businessId) || !selectedFile) {
      return;
    }

    showMessage(messageElement, "", "");

    try {
      const uploadedLogoPaths = await uploadProductImagesForPanel([selectedFile], messageElement);
      if (uploadedLogoPaths.length === 0) {
        return;
      }

      const { response, data } = await requestJson("/api/admin/businesses/logo", {
        method: "POST",
        body: JSON.stringify({
          businessId,
          businessLogoPath: uploadedLogoPaths[0],
        }),
      });

      if (!response.ok || !data.ok || !data.business) {
        const message =
          data.errors?.join(" ") ||
          data.message ||
          "Logoja e biznesit nuk u ruajt.";
        showMessage(messageElement, message, "error");
        return;
      }

      allBusinesses = allBusinesses.map((business) =>
        Number(business.id) === businessId ? data.business : business,
      );
      renderBusinessesList();
      showMessage(
        messageElement,
        data.message || "Logoja e biznesit u ruajt me sukses.",
        "success",
      );
    } catch (error) {
      showMessage(
        messageElement,
        "Serveri nuk po pergjigjet. Provoje perseri.",
        "error",
      );
      console.error(error);
    } finally {
      input.value = "";
    }
  }

  function handleBusinessActionClick(event) {
    const button = event.target.closest("[data-business-action][data-business-id]");
    if (!button) {
      return;
    }

    const businessId = Number(button.dataset.businessId);
    if (!Number.isFinite(businessId)) {
      return;
    }

    const action = button.dataset.businessAction;

    if (action === "edit") {
      editingBusinessId = businessId;
      renderBusinessesList();
      return;
    }

    if (action === "cancel-edit") {
      editingBusinessId = null;
      renderBusinessesList();
    }
  }

  async function handleBusinessEditSubmit(event) {
    const formElement = event.target.closest("form[data-business-edit-form]");
    if (!formElement) {
      return;
    }

    event.preventDefault();
    showMessage(messageElement, "", "");

    const businessId = Number(formElement.dataset.businessId);
    if (!Number.isFinite(businessId)) {
      showMessage(messageElement, "Biznesi i zgjedhur nuk eshte valid.", "error");
      return;
    }

    const formData = new FormData(formElement);
    const payload = {
      businessId,
      businessName: formData.get("businessName")?.toString().trim() || "",
      businessNumber: formData.get("businessNumber")?.toString().trim() || "",
      phoneNumber: formData.get("phoneNumber")?.toString().trim() || "",
      city: formData.get("city")?.toString().trim() || "",
      addressLine: formData.get("addressLine")?.toString().trim() || "",
      businessDescription: formData.get("businessDescription")?.toString().trim() || "",
    };

    const submitButton = formElement.querySelector("[data-business-save-button]");
    if (submitButton) {
      setButtonLoading(submitButton, true, "Ruaj ndryshimet", "Duke ruajtur...");
    }

    try {
      const { response, data } = await requestJson("/api/admin/businesses/update", {
        method: "POST",
        body: JSON.stringify(payload),
      });

      if (!response.ok || !data.ok || !data.business) {
        const message =
          data.errors?.join(" ") ||
          data.message ||
          "Biznesi nuk u perditesua.";
        showMessage(messageElement, message, "error");
        return;
      }

      allBusinesses = allBusinesses.map((business) =>
        Number(business.id) === businessId ? data.business : business,
      );
      editingBusinessId = null;
      renderBusinessesList();
      showMessage(
        messageElement,
        data.message || "Biznesi u perditesua me sukses.",
        "success",
      );
    } catch (error) {
      showMessage(
        messageElement,
        "Serveri nuk po pergjigjet. Provoje perseri.",
        "error",
      );
      console.error(error);
    } finally {
      if (submitButton) {
        setButtonLoading(submitButton, false, "Ruaj ndryshimet", "Duke ruajtur...");
      }
    }
  }
}


function renderRegisteredBusinessCard(business, options = {}) {
  const businessId = Number(business.id) || 0;
  const ownerName = String(business.ownerName || "").trim() || "Pa emer";
  const ownerEmail = String(business.ownerEmail || "").trim() || "Pa email";
  const businessName = String(business.businessName || "").trim() || "Biznes pa emer";
  const businessDescription = String(business.businessDescription || "").trim();
  const logoPath = String(business.logoPath || "").trim();
  const businessInitials = getBusinessInitials(businessName);
  const phoneNumber = String(business.phoneNumber || "").trim() || "-";
  const city = String(business.city || "").trim() || "-";
  const addressLine = String(business.addressLine || "").trim() || "-";
  const businessNumber = String(business.businessNumber || "").trim() || "-";
  const productsCount = Number.isFinite(Number(business.productsCount))
    ? String(Math.max(0, Number(business.productsCount)))
    : "0";
  const ordersCount = Number.isFinite(Number(business.ordersCount))
    ? String(Math.max(0, Number(business.ordersCount)))
    : "0";
  const updatedAt = formatDateLabel(business.updatedAt || business.createdAt || "");

  return `
    <article class="registered-business-card">
      <div class="registered-business-card-head">
        <div class="registered-business-identity">
          <div class="registered-business-avatar-shell">
            ${
              logoPath
                ? `<img class="registered-business-avatar-image" src="${escapeAttribute(logoPath)}" alt="${escapeAttribute(businessName)}">`
                : `<span class="registered-business-avatar-fallback">${escapeHtml(businessInitials)}</span>`
            }
          </div>
          <div class="registered-business-copy">
            <p class="section-label">Biznes i regjistruar</p>
            <h2>${escapeHtml(businessName)}</h2>
            <p class="registered-business-owner">
              Pronari: <strong>${escapeHtml(ownerName)}</strong>
            </p>
          </div>
        </div>

        <div class="registered-business-head-actions">
          <label class="registered-business-logo-upload" for="registered-business-logo-${businessId}">
            ${logoPath ? "Ndrysho logon" : "Ngarko logo"}
          </label>
          <button
            class="registered-business-edit-toggle"
            type="button"
            data-business-action="${options.isEditing ? "cancel-edit" : "edit"}"
            data-business-id="${businessId}"
          >
            ${options.isEditing ? "Mbylle editimin" : "Edito biznesin"}
          </button>
          <input
            id="registered-business-logo-${businessId}"
            class="registered-business-logo-input"
            type="file"
            accept="image/*"
            data-business-logo-input
            data-business-id="${businessId}"
          >
          <div class="registered-business-number-chip">
            Nr. biznesi: <strong>${escapeHtml(String(businessNumber))}</strong>
          </div>
        </div>
      </div>

      <div class="registered-business-grid">
        <div class="summary-chip">
          <span>Emri dhe mbiemri</span>
          <strong>${escapeHtml(ownerName)}</strong>
        </div>
        <div class="summary-chip">
          <span>Emri i biznesit</span>
          <strong>${escapeHtml(businessName)}</strong>
        </div>
        <div class="summary-chip">
          <span>Numri i telefonit</span>
          <strong>${escapeHtml(phoneNumber)}</strong>
        </div>
        <div class="summary-chip">
          <span>Email-i i biznesit</span>
          <strong>${escapeHtml(ownerEmail)}</strong>
        </div>
        <div class="summary-chip">
          <span>Qyteti</span>
          <strong>${escapeHtml(city)}</strong>
        </div>
        <div class="summary-chip">
          <span>Adresa e biznesit</span>
          <strong>${escapeHtml(addressLine)}</strong>
        </div>
        <div class="summary-chip">
          <span>Numri i porosive</span>
          <strong>${escapeHtml(ordersCount)}</strong>
        </div>
        <div class="summary-chip">
          <span>Numri i produkteve</span>
          <strong>${escapeHtml(productsCount)}</strong>
        </div>
        <div class="summary-chip">
          <span>Perditesuar se fundi</span>
          <strong>${escapeHtml(updatedAt)}</strong>
        </div>
      </div>

      ${
        options.isEditing
          ? `
            <form class="auth-form registered-business-edit-form" data-business-edit-form data-business-id="${businessId}">
              <div class="field-row">
                <label class="field">
                  <span>Emri i biznesit</span>
                  <input name="businessName" type="text" value="${escapeAttribute(businessName)}" required>
                </label>

                <label class="field">
                  <span>Nr. i biznesit</span>
                  <input name="businessNumber" type="text" value="${escapeAttribute(businessNumber)}" required>
                </label>
              </div>

              <div class="field-row">
                <label class="field">
                  <span>Numri i telefonit</span>
                  <input name="phoneNumber" type="text" value="${escapeAttribute(phoneNumber === "-" ? "" : phoneNumber)}" required>
                </label>

                <label class="field">
                  <span>Qyteti</span>
                  <input name="city" type="text" value="${escapeAttribute(city === "-" ? "" : city)}" required>
                </label>
              </div>

              <label class="field">
                <span>Adresa e biznesit</span>
                <input name="addressLine" type="text" value="${escapeAttribute(addressLine === "-" ? "" : addressLine)}" required>
              </label>

              <label class="field">
                <span>Pershkrimi i biznesit</span>
                <textarea name="businessDescription" rows="4" required>${escapeHtml(businessDescription)}</textarea>
              </label>

              <div class="registered-business-edit-actions">
                <button class="registered-business-save-button" type="submit" data-business-save-button>Ruaj ndryshimet</button>
                <button
                  class="ghost-button registered-business-cancel-button"
                  type="button"
                  data-business-action="cancel-edit"
                  data-business-id="${businessId}"
                >
                  Anulo
                </button>
              </div>
            </form>
          `
          : ""
      }
    </article>
  `;
}


function initializeChangePasswordPage() {
  const form = document.getElementById("change-password-form");
  const messageElement = document.getElementById("change-password-message");
  const submitButton = document.getElementById("change-password-submit");

  if (!form || !messageElement || !submitButton) {
    return;
  }

  bootstrap();

  async function bootstrap() {
    const currentUser = await fetchCurrentUserOptional();
    if (!currentUser) {
      window.location.href = "/login";
      return;
    }

    form.addEventListener("submit", handlePasswordChange);
  }

  async function handlePasswordChange(event) {
    event.preventDefault();
    showMessage(messageElement, "", "");

    const formData = new FormData(form);
    const payload = {
      currentPassword: formData.get("currentPassword")?.toString() || "",
      newPassword: formData.get("newPassword")?.toString() || "",
      confirmPassword: formData.get("confirmPassword")?.toString() || "",
    };

    setButtonLoading(
      submitButton,
      true,
      "Ruaje fjalekalimin e ri",
      "Duke ruajtur...",
    );

    try {
      const { response, data } = await requestJson("/api/change-password", {
        method: "POST",
        body: JSON.stringify(payload),
      });

      if (!response.ok || !data.ok) {
        const message =
          data.errors?.join(" ") ||
          data.message ||
          "Ndryshimi i fjalekalimit nuk funksionoi.";
        showMessage(messageElement, message, "error");
        return;
      }

      showMessage(
        messageElement,
        data.message || "Fjalekalimi u ndryshua.",
        "success",
      );
      form.reset();
      window.setTimeout(() => {
        window.location.href = data.redirectTo || "/login";
      }, 900);
    } catch (error) {
      showMessage(
        messageElement,
        "Serveri nuk po pergjigjet. Provoje perseri.",
        "error",
      );
      console.error(error);
    } finally {
      setButtonLoading(
        submitButton,
        false,
        "Ruaje fjalekalimin e ri",
        "Duke ruajtur...",
      );
    }
  }
}


function initializeHomePage() {
  const promoTrack = document.getElementById("home-promo-track");
  const promoDots = document.getElementById("home-promo-dots");
  const promoPrevButton = document.getElementById("home-promo-prev");
  const promoNextButton = document.getElementById("home-promo-next");
  const productsStatusElement = document.getElementById("home-products-status");
  const messageElement = document.getElementById("home-page-message");
  const grid = document.getElementById("home-products-grid");
  const businessesSection = document.getElementById("home-businesses-section");
  const businessesTrack = document.getElementById("home-businesses-track");

  if (
    !promoTrack ||
    !promoDots ||
    !promoPrevButton ||
    !promoNextButton ||
    !productsStatusElement ||
    !messageElement ||
    !grid
  ) {
    return;
  }

  const promoSlides = [
    {
      title: "Oferta te reja cdo jave",
      description:
        "Zbulo produktet me te kerkuara per shtepi, bukuri dhe stil ne nje vend te vetem.",
      badge: "Reklame 01",
      ctaLabel: "Shiko produktet",
      ctaHref: "/kerko",
      imagePath: "/bujqesia.jpg",
    },
    {
      title: "Veshje dhe kozmetike ne trend",
      description:
        "Nga veshjet per meshkuj e femra deri te kozmetika e perditshme, tash i gjen me shpejt.",
      badge: "Reklame 02",
      ctaLabel: "Kerko koleksionin",
      ctaHref: "/kerko?category=clothing-women",
      imagePath: "/gjelbert.jpeg",
    },
    {
      title: "Teknologji dhe shtepi me oferta",
      description:
        "Aksesor per telefon, dekor dhe produkte praktike per perditshmeri ne nje katalog te vetem.",
      badge: "Reklame 03",
      ctaLabel: "Hap kategorite",
      ctaHref: "/kerko?category=technology",
      imagePath: "/gruri.webp",
    },
  ];

  let currentUser = null;
  let wishlistIds = new Set();
  let cartIds = new Set();
  let allProducts = [];
  let currentSlideIndex = 0;
  let promoIntervalId = null;
  let homeRevealObserver = null;
  let homeRevealResizeFrame = null;

  bootstrap();

  async function bootstrap() {
    try {
      currentUser = await fetchCurrentUserOptional();
      renderPromoSlides();
      startPromoAutoplay();
      await refreshCollectionState();
      await Promise.all([loadProducts(), loadFeaturedBusinesses()]);
      grid.addEventListener("click", handleGridAction);
      window.addEventListener("resize", handleGridResize);
      promoPrevButton.addEventListener("click", () => {
        goToSlide(currentSlideIndex - 1);
        restartPromoAutoplay();
      });
      promoNextButton.addEventListener("click", () => {
        goToSlide(currentSlideIndex + 1);
        restartPromoAutoplay();
      });
      promoDots.addEventListener("click", handleDotClick);
    } catch (error) {
      productsStatusElement.textContent =
        "Produktet nuk u ngarkuan. Provoje perseri pas pak.";
      grid.innerHTML = `
        <div class="collection-empty-state">
          Produktet nuk u ngarkuan. Provoje perseri pas pak.
        </div>
      `;
      console.error(error);
    }
  }

  function renderPromoSlides() {
    promoTrack.innerHTML = promoSlides
      .map((slide) => renderHomePromoSlide(slide))
      .join("");

    promoDots.innerHTML = promoSlides
      .map(
        (slide, index) => `
          <button
            class="home-promo-dot${index === 0 ? " active" : ""}"
            type="button"
            data-slide-index="${index}"
            aria-label="Hap slide ${index + 1}: ${escapeAttribute(slide.title)}"
          ></button>
        `,
      )
      .join("");

    updatePromoSlider();
  }

  function updatePromoSlider() {
    promoTrack.style.transform = `translateX(-${currentSlideIndex * 100}%)`;
    promoDots.querySelectorAll(".home-promo-dot").forEach((dot, index) => {
      dot.classList.toggle("active", index === currentSlideIndex);
    });
  }

  function goToSlide(nextIndex) {
    if (promoSlides.length === 0) {
      return;
    }

    const totalSlides = promoSlides.length;
    currentSlideIndex = (nextIndex + totalSlides) % totalSlides;
    updatePromoSlider();
  }

  function handleDotClick(event) {
    const button = event.target.closest("[data-slide-index]");
    if (!button) {
      return;
    }

    const slideIndex = Number(button.dataset.slideIndex);
    if (!Number.isFinite(slideIndex)) {
      return;
    }

    goToSlide(slideIndex);
    restartPromoAutoplay();
  }

  function startPromoAutoplay() {
    stopPromoAutoplay();
    promoIntervalId = window.setInterval(() => {
      goToSlide(currentSlideIndex + 1);
    }, 4800);
  }

  function stopPromoAutoplay() {
    if (promoIntervalId) {
      window.clearInterval(promoIntervalId);
      promoIntervalId = null;
    }
  }

  function restartPromoAutoplay() {
    startPromoAutoplay();
  }

  async function refreshCollectionState() {
    if (!currentUser) {
      wishlistIds = new Set();
      cartIds = new Set();
      return;
    }

    const [wishlistItems, cartItems] = await Promise.all([
      fetchProtectedCollection("/api/wishlist"),
      fetchProtectedCollection("/api/cart"),
    ]);

    wishlistIds = new Set(wishlistItems.map((item) => item.id));
    cartIds = new Set(cartItems.map((item) => item.id));
  }

  async function loadProducts() {
    showMessage(messageElement, "", "");
    disconnectHomeRevealObserver();

    const { response, data } = await requestJson("/api/products");

    if (!response.ok || !data.ok) {
      const message =
        data.errors?.join(" ") ||
        data.message ||
        "Produktet nuk u ngarkuan.";
      productsStatusElement.textContent = message;
      grid.innerHTML = `
        <div class="collection-empty-state">
          ${escapeHtml(message)}
        </div>
      `;
      return;
    }

    allProducts = Array.isArray(data.products) ? data.products : [];

    if (allProducts.length === 0) {
      productsStatusElement.textContent = "Ende nuk ka produkte publike ne faqe.";
      grid.innerHTML = `
        <div class="collection-empty-state">
          Ende nuk ka produkte publike ne faqe.
        </div>
      `;
      return;
    }

    productsStatusElement.textContent = `Po shfaqen ${allProducts.length} produkte publike ne TREGO.`;
    grid.innerHTML = allProducts
      .map((product) =>
        renderPetProductCard(product, {
          isWishlisted: wishlistIds.has(product.id),
          isInCart: cartIds.has(product.id),
        }),
      )
      .join("");

    applyHomeProductReveal();
  }

  function handleGridResize() {
    if (homeRevealResizeFrame) {
      window.cancelAnimationFrame(homeRevealResizeFrame);
    }

    homeRevealResizeFrame = window.requestAnimationFrame(() => {
      homeRevealResizeFrame = null;
      applyHomeProductReveal();
    });
  }

  function applyHomeProductReveal() {
    disconnectHomeRevealObserver();

    const cards = Array.from(grid.querySelectorAll(".pet-product-card"));
    if (cards.length === 0) {
      return;
    }

    cards.forEach((card) => {
      card.classList.remove("product-scroll-reveal", "is-visible");
    });

    const columnCount = countGridColumns(grid);
    const hiddenStartIndex = columnCount * 10;

    if (cards.length <= hiddenStartIndex) {
      return;
    }

    const cardsToReveal = cards.slice(hiddenStartIndex);
    if (!("IntersectionObserver" in window)) {
      cardsToReveal.forEach((card) => {
        card.classList.add("product-scroll-reveal", "is-visible");
      });
      return;
    }

    homeRevealObserver = new window.IntersectionObserver(handleRevealIntersection, {
      root: null,
      rootMargin: "240px 0px",
      threshold: 0.08,
    });

    cardsToReveal.forEach((card) => {
      card.classList.add("product-scroll-reveal");
      homeRevealObserver.observe(card);
    });
  }

  function handleRevealIntersection(entries) {
    entries.forEach((entry) => {
      if (!entry.isIntersecting) {
        return;
      }

      entry.target.classList.add("is-visible");
      homeRevealObserver?.unobserve(entry.target);
    });
  }

  function disconnectHomeRevealObserver() {
    if (!homeRevealObserver) {
      return;
    }

    homeRevealObserver.disconnect();
    homeRevealObserver = null;
  }

  async function loadFeaturedBusinesses() {
    if (!businessesSection || !businessesTrack) {
      return;
    }

    try {
      const { response, data } = await requestJson("/api/businesses/public");
      if (!response.ok || !data.ok) {
        businessesSection.hidden = true;
        businessesTrack.innerHTML = "";
        return;
      }

      const businesses = Array.isArray(data.businesses) ? data.businesses : [];
      if (businesses.length === 0) {
        businessesSection.hidden = true;
        businessesTrack.innerHTML = "";
        return;
      }

      businessesSection.hidden = false;
      businessesTrack.innerHTML = renderHomeBusinessesTrack(businesses);
    } catch (error) {
      businessesSection.hidden = true;
      businessesTrack.innerHTML = "";
      console.error(error);
    }
  }

  async function handleGridAction(event) {
    const button = event.target.closest("[data-action][data-product-id]");
    if (!button) {
      return;
    }

    if (!currentUser) {
      showMessage(
        messageElement,
        "Duhet te kyçesh ose te krijosh llogari para se te perdorësh wishlist ose cart.",
        "error",
      );
      return;
    }

    const productId = Number(button.dataset.productId);
    if (!Number.isFinite(productId)) {
      return;
    }

    const action = button.dataset.action;

    if (action === "wishlist") {
      const { response, data } = await requestJson("/api/wishlist/toggle", {
        method: "POST",
        body: JSON.stringify({ productId }),
      });

      if (!response.ok || !data.ok) {
        const message =
          data.errors?.join(" ") || data.message || "Wishlist nuk u perditesua.";
        showMessage(messageElement, message, "error");
        return;
      }

      wishlistIds = new Set((data.items || []).map((item) => item.id));
      showMessage(messageElement, data.message || "Wishlist u perditesua.", "success");
      await loadProducts();
      return;
    }

    if (action === "cart") {
      const { response, data } = await requestJson("/api/cart/add", {
        method: "POST",
        body: JSON.stringify({ productId }),
      });

      if (!response.ok || !data.ok) {
        const message =
          data.errors?.join(" ") || data.message || "Shporta nuk u perditesua.";
        showMessage(messageElement, message, "error");
        return;
      }

      cartIds = new Set((data.items || []).map((item) => item.id));
      showMessage(messageElement, data.message || "Produkti u shtua ne shporte.", "success");
      await loadProducts();
    }
  }
}


function initializeLoginPage() {
  const form = document.getElementById("login-form");
  const messageElement = document.getElementById("login-message");
  const submitButton = document.getElementById("login-submit-button");

  if (!form || !messageElement || !submitButton) {
    return;
  }

  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    showMessage(messageElement, "", "");

    const formData = new FormData(form);
    const payload = {
      email: formData.get("email")?.toString().trim() || "",
      password: formData.get("password")?.toString() || "",
    };

    setButtonLoading(submitButton, true, "Kycu", "Duke kontrolluar...");

    try {
      const { response, data } = await requestJson("/api/login", {
        method: "POST",
        body: JSON.stringify(payload),
      });

      if (!response.ok || !data.ok) {
        const message =
          data.errors?.join(" ") ||
          data.message ||
          "Kerkojme falje, por llogaria nuk ekziston.";
        showMessage(messageElement, message, "error");
        if (data.redirectTo) {
          window.setTimeout(() => {
            window.location.href = data.redirectTo;
          }, 1100);
        }
        return;
      }

      showMessage(messageElement, data.message || "U kyqe me sukses.", "success");
      persistLoginGreeting(data.user?.firstName || data.user?.fullName || "User");
      window.setTimeout(() => {
        window.location.href = data.redirectTo || "/";
      }, 700);
    } catch (error) {
      showMessage(
        messageElement,
        "Serveri nuk po pergjigjet. Provoje perseri.",
        "error",
      );
      console.error(error);
    } finally {
      setButtonLoading(submitButton, false, "Kycu", "Duke kontrolluar...");
    }
  });
}


function initializeSignupPage() {
  const form = document.getElementById("signup-form");
  const messageElement = document.getElementById("signup-message");
  const submitButton = document.getElementById("signup-submit-button");

  if (!form || !messageElement || !submitButton) {
    return;
  }

  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    showMessage(messageElement, "", "");

    const formData = new FormData(form);
    const payload = {
      fullName: formData.get("fullName")?.toString().trim() || "",
      email: formData.get("email")?.toString().trim() || "",
      birthDate: formData.get("birthDate")?.toString().trim() || "",
      gender: formData.get("gender")?.toString().trim() || "",
      password: formData.get("password")?.toString() || "",
    };

    setButtonLoading(submitButton, true, "Ruaje llogarine", "Duke ruajtur...");

    try {
      const { response, data } = await requestJson("/api/register", {
        method: "POST",
        body: JSON.stringify(payload),
      });

      if (!response.ok || !data.ok) {
        const message =
          data.errors?.join(" ") || data.message || "Regjistrimi nuk funksionoi.";
        showMessage(messageElement, message, "error");
        return;
      }

      const successMessage =
        data.message || "Llogaria u ruajt me sukses. Po kalon te verifikimi i email-it...";

      showMessage(
        messageElement,
        successMessage,
        "success",
      );
      form.reset();
      window.setTimeout(() => {
        window.location.href = data.redirectTo || getVerifyEmailUrl(payload.email);
      }, 900);
    } catch (error) {
      showMessage(
        messageElement,
        "Serveri nuk po pergjigjet. Provoje perseri.",
        "error",
      );
      console.error(error);
    } finally {
      setButtonLoading(
        submitButton,
        false,
        "Ruaje llogarine",
        "Duke ruajtur...",
      );
    }
  });
}


function initializeVerifyEmailPage() {
  const form = document.getElementById("verify-email-form");
  const messageElement = document.getElementById("verify-email-message");
  const submitButton = document.getElementById("verify-email-submit-button");
  const resendButton = document.getElementById("verify-email-resend-button");
  const emailInput = document.getElementById("verify-email-address");
  const successDialog = document.getElementById("verify-email-success-dialog");
  const successContinueButton = document.getElementById("verify-email-success-continue");

  if (
    !form ||
    !messageElement ||
    !submitButton ||
    !resendButton ||
    !emailInput ||
    !successDialog ||
    !successContinueButton
  ) {
    return;
  }

  let successRedirectUrl = "/login";

  const searchParams = new URLSearchParams(window.location.search);
  const prefilledEmail = searchParams.get("email") || "";
  if (prefilledEmail && !emailInput.value.trim()) {
    emailInput.value = prefilledEmail;
  }

  function openSuccessDialog() {
    successDialog.hidden = false;
    document.body.classList.add("dialog-open");
    window.requestAnimationFrame(() => {
      successDialog.classList.add("is-visible");
    });
  }

  function goToSuccessRedirect() {
    window.location.href = successRedirectUrl || "/login";
  }

  successContinueButton.addEventListener("click", goToSuccessRedirect);

  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    showMessage(messageElement, "", "");

    const formData = new FormData(form);
    const payload = {
      email: formData.get("email")?.toString().trim() || "",
      code: formData.get("code")?.toString().trim() || "",
    };

    setButtonLoading(
      submitButton,
      true,
      "Verifiko emailin",
      "Duke verifikuar...",
    );

    try {
      const { response, data } = await requestJson("/api/email/verify", {
        method: "POST",
        body: JSON.stringify(payload),
      });

      if (!response.ok || !data.ok) {
        const message =
          data.errors?.join(" ") ||
          data.message ||
          "Verifikimi i email-it nuk funksionoi.";
        showMessage(messageElement, message, "error");
        return;
      }

      showMessage(
        messageElement,
        data.message || "Email-i u verifikua me sukses.",
        "success",
      );
      form.reset();
      emailInput.value = payload.email;
      successRedirectUrl = data.redirectTo || "/login";
      openSuccessDialog();
    } catch (error) {
      showMessage(
        messageElement,
        "Serveri nuk po pergjigjet. Provoje perseri.",
        "error",
      );
      console.error(error);
    } finally {
      setButtonLoading(
        submitButton,
        false,
        "Verifiko emailin",
        "Duke verifikuar...",
      );
    }
  });

  resendButton.addEventListener("click", async () => {
    showMessage(messageElement, "", "");

    const payload = {
      email: String(emailInput.value || "").trim(),
    };

    setButtonLoading(
      resendButton,
      true,
      "Dergoje kodin perseri",
      "Duke derguar...",
    );

    try {
      const { response, data } = await requestJson("/api/email/resend", {
        method: "POST",
        body: JSON.stringify(payload),
      });

      if (!response.ok || !data.ok) {
        const message =
          data.errors?.join(" ") ||
          data.message ||
          "Kodi nuk u dergua perseri.";
        showMessage(messageElement, message, "error");
        return;
      }

      const message = data.message || "Kodi i verifikimit u dergua perseri.";
      showMessage(messageElement, message, "success");

      if (data.redirectTo) {
        window.setTimeout(() => {
          window.location.href = data.redirectTo;
        }, 900);
      }
    } catch (error) {
      showMessage(
        messageElement,
        "Serveri nuk po pergjigjet. Provoje perseri.",
        "error",
      );
      console.error(error);
    } finally {
      setButtonLoading(
        resendButton,
        false,
        "Dergoje kodin perseri",
        "Duke derguar...",
      );
    }
  });
}


function initializePetsPage() {
  const grid = document.getElementById("pet-products-grid");
  const messageElement = document.getElementById("pets-page-message");

  if (!grid || !messageElement) {
    return;
  }

  let currentUser = null;
  let wishlistIds = new Set();
  let cartIds = new Set();

  bootstrap();

  async function bootstrap() {
    try {
      currentUser = await fetchCurrentUserOptional();
      await refreshCollectionState();
      await loadProducts();
      grid.addEventListener("click", handleGridAction);
    } catch (error) {
      grid.innerHTML = `
        <div class="pets-empty-state">
          Produktet nuk u ngarkuan. Provoje perseri pas pak.
        </div>
      `;
      console.error(error);
    }
  }

  async function refreshCollectionState() {
    if (!currentUser) {
      wishlistIds = new Set();
      cartIds = new Set();
      return;
    }

    const [wishlistItems, cartItems] = await Promise.all([
      fetchProtectedCollection("/api/wishlist"),
      fetchProtectedCollection("/api/cart"),
    ]);

    wishlistIds = new Set(wishlistItems.map((item) => item.id));
    cartIds = new Set(cartItems.map((item) => item.id));
  }

  async function loadProducts() {
    try {
      const { response, data } = await requestJson("/api/products?category=pets");

      if (!response.ok || !data.ok) {
        grid.innerHTML = `
          <div class="pets-empty-state">
            Nuk mund t'i ngarkojme produktet tani. Provoje perseri pas pak.
          </div>
        `;
        return;
      }

      const products = Array.isArray(data.products) ? data.products : [];
      if (products.length === 0) {
        grid.innerHTML = `
          <div class="pets-empty-state">
            Ende nuk ka produkte ne kete kategori. Hyr si admin dhe shto artikullin e pare.
          </div>
        `;
        return;
      }

      grid.innerHTML = products
        .map((product) =>
          renderPetProductCard(product, {
            isWishlisted: wishlistIds.has(product.id),
            isInCart: cartIds.has(product.id),
          }),
        )
        .join("");
    } catch (error) {
      grid.innerHTML = `
        <div class="pets-empty-state">
          Produktet nuk u ngarkuan. Provoje perseri pas pak.
        </div>
      `;
      console.error(error);
    }
  }

  async function handleGridAction(event) {
    const button = event.target.closest("[data-action][data-product-id]");
    if (!button) {
      return;
    }

    if (!currentUser) {
      showMessage(
        messageElement,
        "Duhet te kyçesh ose te krijosh llogari para se te përdorësh wishlist ose cart.",
        "error",
      );
      return;
    }

    const productId = Number(button.dataset.productId);
    if (!Number.isFinite(productId)) {
      return;
    }

    const action = button.dataset.action;

    if (action === "wishlist") {
      const { response, data } = await requestJson("/api/wishlist/toggle", {
        method: "POST",
        body: JSON.stringify({ productId }),
      });

      if (!response.ok || !data.ok) {
        const message =
          data.errors?.join(" ") || data.message || "Wishlist nuk u perditesua.";
        showMessage(messageElement, message, "error");
        return;
      }

      wishlistIds = new Set((data.items || []).map((item) => item.id));
      showMessage(messageElement, data.message || "Wishlist u perditesua.", "success");
      await loadProducts();
      return;
    }

    if (action === "cart") {
      const { response, data } = await requestJson("/api/cart/add", {
        method: "POST",
        body: JSON.stringify({ productId }),
      });

      if (!response.ok || !data.ok) {
        const message =
          data.errors?.join(" ") || data.message || "Shporta nuk u perditesua.";
        showMessage(messageElement, message, "error");
        return;
      }

      cartIds = new Set((data.items || []).map((item) => item.id));
      showMessage(messageElement, data.message || "Produkti u shtua ne shporte.", "success");
      await loadProducts();
    }
  }
}


function initializeBusinessProfilePage() {
  const heroElement = document.getElementById("business-profile-hero");
  const grid = document.getElementById("business-profile-products-grid");
  const messageElement = document.getElementById("business-profile-message");

  if (!heroElement || !grid || !messageElement) {
    return;
  }

  let currentUser = null;
  let currentBusiness = null;
  let wishlistIds = new Set();
  let cartIds = new Set();

  bootstrap();

  async function bootstrap() {
    const searchParams = new URLSearchParams(window.location.search);
    const businessId = Number(searchParams.get("id"));

    if (!Number.isFinite(businessId) || businessId <= 0) {
      heroElement.innerHTML = renderBusinessProfileEmptyState("Biznesi nuk u gjet.");
      grid.innerHTML = "";
      return;
    }

    try {
      currentUser = await fetchCurrentUserOptional();
      await refreshCollectionState();

      const [businessResponse, productsResponse] = await Promise.all([
        requestJson(`/api/business/public?id=${encodeURIComponent(businessId)}`),
        requestJson(`/api/business/public-products?id=${encodeURIComponent(businessId)}`),
      ]);

      if (!businessResponse.response.ok || !businessResponse.data.ok || !businessResponse.data.business) {
        const message =
          businessResponse.data.errors?.join(" ") ||
          businessResponse.data.message ||
          "Biznesi nuk u gjet.";
        heroElement.innerHTML = renderBusinessProfileEmptyState(message);
        grid.innerHTML = "";
        return;
      }

      currentBusiness = businessResponse.data.business;
      heroElement.innerHTML = renderBusinessProfileHero(currentBusiness, currentUser);

      if (!productsResponse.response.ok || !productsResponse.data.ok) {
        grid.innerHTML = `
          <div class="pets-empty-state">
            Produktet e biznesit nuk u ngarkuan. Provoje perseri pas pak.
          </div>
        `;
      } else {
        const products = Array.isArray(productsResponse.data.products)
          ? productsResponse.data.products
          : [];

        if (products.length === 0) {
          grid.innerHTML = `
            <div class="pets-empty-state">
              Ky biznes ende nuk ka produkte publike.
            </div>
          `;
        } else {
          grid.innerHTML = products
            .map((product) =>
              renderPetProductCard(product, {
                isWishlisted: wishlistIds.has(product.id),
                isInCart: cartIds.has(product.id),
              }),
            )
            .join("");
        }
      }

      heroElement.addEventListener("click", handleHeroAction);
      grid.addEventListener("click", handleGridAction);
    } catch (error) {
      heroElement.innerHTML = renderBusinessProfileEmptyState("Biznesi nuk u ngarkua. Provoje perseri.");
      grid.innerHTML = "";
      console.error(error);
    }
  }

  async function refreshCollectionState() {
    if (!currentUser) {
      wishlistIds = new Set();
      cartIds = new Set();
      return;
    }

    const [wishlistItems, cartItems] = await Promise.all([
      fetchProtectedCollection("/api/wishlist"),
      fetchProtectedCollection("/api/cart"),
    ]);

    wishlistIds = new Set(wishlistItems.map((item) => item.id));
    cartIds = new Set(cartItems.map((item) => item.id));
  }

  async function handleHeroAction(event) {
    const followButton = event.target.closest("[data-business-follow-button]");
    if (!followButton || !currentBusiness) {
      return;
    }

    if (!currentUser) {
      showMessage(
        messageElement,
        "Duhet te kyçesh ose te krijosh llogari para se ta ndjekesh nje biznes.",
        "error",
      );
      return;
    }

    if (currentUser.role === "business" && Number(currentUser.id) === Number(currentBusiness.userId)) {
      showMessage(
        messageElement,
        "Nuk mund ta ndjekesh profilin e biznesit tend.",
        "error",
      );
      return;
    }

    followButton.disabled = true;

    try {
      const { response, data } = await requestJson("/api/business/follow-toggle", {
        method: "POST",
        body: JSON.stringify({ businessId: currentBusiness.id }),
      });

      if (!response.ok || !data.ok || !data.business) {
        const message =
          data.errors?.join(" ") ||
          data.message ||
          "Ndjekja e biznesit nuk u perditesua.";
        showMessage(messageElement, message, "error");
        return;
      }

      currentBusiness = data.business;
      heroElement.innerHTML = renderBusinessProfileHero(currentBusiness, currentUser);
      showMessage(messageElement, data.message || "Profili i biznesit u perditesua.", "success");
    } catch (error) {
      showMessage(
        messageElement,
        "Serveri nuk po pergjigjet. Provoje perseri.",
        "error",
      );
      console.error(error);
    } finally {
      const nextButton = heroElement.querySelector("[data-business-follow-button]");
      if (nextButton) {
        nextButton.disabled = false;
      }
    }
  }

  async function handleGridAction(event) {
    const button = event.target.closest("[data-action][data-product-id]");
    if (!button) {
      return;
    }

    if (!currentUser) {
      showMessage(
        messageElement,
        "Duhet te kyçesh ose te krijosh llogari para se te perdorësh wishlist ose cart.",
        "error",
      );
      return;
    }

    const productId = Number(button.dataset.productId);
    if (!Number.isFinite(productId)) {
      return;
    }

    const action = button.dataset.action;

    if (action === "wishlist") {
      const { response, data } = await requestJson("/api/wishlist/toggle", {
        method: "POST",
        body: JSON.stringify({ productId }),
      });

      if (!response.ok || !data.ok) {
        const message =
          data.errors?.join(" ") || data.message || "Wishlist nuk u perditesua.";
        showMessage(messageElement, message, "error");
        return;
      }

      wishlistIds = new Set((data.items || []).map((item) => item.id));
      showMessage(messageElement, data.message || "Wishlist u perditesua.", "success");
      await reloadProducts();
      return;
    }

    if (action === "cart") {
      const { response, data } = await requestJson("/api/cart/add", {
        method: "POST",
        body: JSON.stringify({ productId }),
      });

      if (!response.ok || !data.ok) {
        const message =
          data.errors?.join(" ") || data.message || "Shporta nuk u perditesua.";
        showMessage(messageElement, message, "error");
        return;
      }

      cartIds = new Set((data.items || []).map((item) => item.id));
      showMessage(messageElement, data.message || "Produkti u shtua ne shporte.", "success");
      await reloadProducts();
    }
  }

  async function reloadProducts() {
    if (!currentBusiness?.id) {
      return;
    }

    const { response, data } = await requestJson(
      `/api/business/public-products?id=${encodeURIComponent(currentBusiness.id)}`,
    );

    if (!response.ok || !data.ok) {
      return;
    }

    const products = Array.isArray(data.products) ? data.products : [];
    if (products.length === 0) {
      grid.innerHTML = `
        <div class="pets-empty-state">
          Ky biznes ende nuk ka produkte publike.
        </div>
      `;
      return;
    }

    grid.innerHTML = products
      .map((product) =>
        renderPetProductCard(product, {
          isWishlisted: wishlistIds.has(product.id),
          isInCart: cartIds.has(product.id),
        }),
      )
      .join("");
  }
}


function initializeProductDetailPage() {
  const container = document.getElementById("product-detail-container");
  const messageElement = document.getElementById("product-detail-message");

  if (!container || !messageElement) {
    return;
  }

  const params = new URLSearchParams(window.location.search);
  const productId = Number(params.get("id") || params.get("productId") || "");
  let currentUser = null;
  let currentProduct = null;
  let currentImageIndex = 0;
  let wishlistIds = new Set();
  let cartIds = new Set();

  bootstrap();

  async function bootstrap() {
    if (!Number.isFinite(productId) || productId <= 0) {
      renderMissingState("Produkti nuk u gjet.");
      return;
    }

    try {
      currentUser = await fetchCurrentUserOptional();
      await refreshCollectionState();
      await loadProduct();
      container.addEventListener("click", handleAction);
    } catch (error) {
      renderMissingState("Produkti nuk u ngarkua. Provoje perseri pas pak.");
      console.error(error);
    }
  }

  async function refreshCollectionState() {
    if (!currentUser) {
      wishlistIds = new Set();
      cartIds = new Set();
      return;
    }

    const [wishlistItems, cartItems] = await Promise.all([
      fetchProtectedCollection("/api/wishlist"),
      fetchProtectedCollection("/api/cart"),
    ]);

    wishlistIds = new Set(wishlistItems.map((item) => item.id));
    cartIds = new Set(cartItems.map((item) => item.id));
  }

  async function loadProduct() {
    const { response, data } = await requestJson(`/api/product?id=${encodeURIComponent(productId)}`);

    if (!response.ok || !data.ok || !data.product) {
      renderMissingState(data.message || data.errors?.join(" ") || "Produkti nuk u gjet.");
      return;
    }

    currentProduct = data.product;
    currentImageIndex = 0;
    renderProduct();
  }

  function renderMissingState(message) {
    showMessage(messageElement, "", "");
    container.innerHTML = `
      <div class="pets-empty-state">
        ${escapeHtml(message)}
      </div>
    `;
  }

  function renderProduct() {
    if (!currentProduct) {
      return;
    }

    container.innerHTML = renderProductDetailCard(currentProduct, {
      currentImageIndex,
      isWishlisted: wishlistIds.has(currentProduct.id),
      isInCart: cartIds.has(currentProduct.id),
    });
  }

  async function handleAction(event) {
    const button = event.target.closest("[data-action][data-product-id]");
    if (!button || !currentProduct) {
      return;
    }

    const action = button.dataset.action;

    if (action === "next-image") {
      const gallery = getProductImageGallery(currentProduct);
      if (gallery.length > 1) {
        currentImageIndex = (currentImageIndex + 1) % gallery.length;
        renderProduct();
      }
      return;
    }

    if (!currentUser) {
      showMessage(
        messageElement,
        "Duhet te kyçesh ose te krijosh llogari para se te perdoresh wishlist ose cart.",
        "error",
      );
      return;
    }

    if (action === "wishlist") {
      const { response, data } = await requestJson("/api/wishlist/toggle", {
        method: "POST",
        body: JSON.stringify({ productId: currentProduct.id }),
      });

      if (!response.ok || !data.ok) {
        const message =
          data.errors?.join(" ") || data.message || "Wishlist nuk u perditesua.";
        showMessage(messageElement, message, "error");
        return;
      }

      wishlistIds = new Set((data.items || []).map((item) => item.id));
      showMessage(messageElement, data.message || "Wishlist u perditesua.", "success");
      renderProduct();
      return;
    }

    if (action === "cart") {
      const { response, data } = await requestJson("/api/cart/add", {
        method: "POST",
        body: JSON.stringify({ productId: currentProduct.id }),
      });

      if (!response.ok || !data.ok) {
        const message =
          data.errors?.join(" ") || data.message || "Shporta nuk u perditesua.";
        showMessage(messageElement, message, "error");
        return;
      }

      cartIds = new Set((data.items || []).map((item) => item.id));
      showMessage(messageElement, data.message || "Produkti u shtua ne shporte.", "success");
      renderProduct();
    }
  }
}


function initializeWishlistPage() {
  const grid = document.getElementById("wishlist-products-grid");
  const messageElement = document.getElementById("wishlist-page-message");
  const toolbar = document.getElementById("wishlist-selection-toolbar");
  const selectAllCheckbox = document.getElementById("wishlist-select-all");
  const selectedCountElement = document.getElementById("wishlist-selected-count");
  const bulkCartButton = document.getElementById("wishlist-bulk-cart-button");

  if (
    !grid ||
    !messageElement ||
    !toolbar ||
    !selectAllCheckbox ||
    !selectedCountElement ||
    !bulkCartButton
  ) {
    return;
  }

  let currentUser = null;
  let itemsState = [];
  let selectedIds = new Set();
  let selectionInitialized = false;

  bootstrap();

  async function bootstrap() {
    currentUser = await fetchCurrentUserOptional();

    if (!currentUser) {
      const guestMessage = "Per te perdorur wishlist duhet te kyçesh ose te krijosh llogari.";
      grid.innerHTML = `
        <div class="collection-empty-state">
          ${escapeHtml(guestMessage)}
        </div>
      `;
      toolbar.hidden = true;
      showMessage(messageElement, guestMessage, "error");
      return;
    }

    grid.addEventListener("click", handleCollectionAction);
    grid.addEventListener("change", handleSelectionChange);
    selectAllCheckbox.addEventListener("change", handleSelectAllChange);
    bulkCartButton.addEventListener("click", handleBulkAddToCart);
    await loadItems();
  }

  async function loadItems() {
    try {
      const { response, data } = await requestJson("/api/wishlist");

      if (!response.ok || !data.ok) {
        const message =
          data.errors?.join(" ") || data.message || "Lista nuk u ngarkua.";
        showMessage(messageElement, message, "error");
        toolbar.hidden = true;
        grid.innerHTML = `
          <div class="collection-empty-state">
            ${escapeHtml(message)}
          </div>
        `;
        return;
      }

      itemsState = Array.isArray(data.items) ? data.items : [];
      syncSelectionState();

      if (itemsState.length === 0) {
        toolbar.hidden = true;
        showMessage(messageElement, "", "");
        grid.innerHTML = `
          <div class="collection-empty-state">
            Wishlist-i yt eshte bosh. Shto produkte nga faqet e dyqanit dhe ruaji me zemren.
          </div>
        `;
        return;
      }

      showMessage(messageElement, "", "");
      renderWishlistGrid();
      updateWishlistSelectionUi();
    } catch (error) {
      toolbar.hidden = true;
      showMessage(messageElement, "Lista nuk u ngarkua. Provoje perseri.", "error");
      grid.innerHTML = `
        <div class="collection-empty-state">
          Lista nuk u ngarkua. Provoje perseri.
        </div>
      `;
      console.error(error);
    }
  }

  function shouldEnableSelection() {
    return itemsState.length > 2;
  }

  function syncSelectionState() {
    const availableIds = new Set(itemsState.map((item) => item.id));

    if (!shouldEnableSelection()) {
      selectedIds = new Set(itemsState.map((item) => item.id));
      selectionInitialized = false;
      return;
    }

    if (!selectionInitialized) {
      selectedIds = new Set(itemsState.map((item) => item.id));
      selectionInitialized = true;
      return;
    }

    selectedIds = new Set([...selectedIds].filter((id) => availableIds.has(id)));
  }

  function getSelectedItems() {
    if (!shouldEnableSelection()) {
      return [...itemsState];
    }

    return itemsState.filter((item) => selectedIds.has(item.id));
  }

  function renderWishlistGrid() {
    grid.innerHTML = itemsState
      .map((item) =>
        renderWishlistItem(item, {
          selectionEnabled: shouldEnableSelection(),
          selected: selectedIds.has(item.id),
        }),
      )
      .join("");
  }

  function updateWishlistSelectionUi() {
    const selectionEnabled = shouldEnableSelection();
    toolbar.hidden = !selectionEnabled;

    if (!selectionEnabled) {
      bulkCartButton.disabled = false;
      return;
    }

    const selectedCount = getSelectedItems().length;
    selectedCountElement.textContent = `${selectedCount} produkte te zgjedhura`;
    selectAllCheckbox.checked = itemsState.length > 0 && selectedCount === itemsState.length;
    selectAllCheckbox.indeterminate = selectedCount > 0 && selectedCount < itemsState.length;
    bulkCartButton.disabled = selectedCount === 0;
  }

  async function handleCollectionAction(event) {
    const button = event.target.closest("[data-action][data-product-id]");
    if (!button || !currentUser) {
      return;
    }

    const productId = Number(button.dataset.productId);
    if (!Number.isFinite(productId)) {
      return;
    }

    const action = button.dataset.action;

    if (action === "remove") {
      const { response, data } = await requestJson("/api/wishlist/toggle", {
        method: "POST",
        body: JSON.stringify({ productId }),
      });

      if (!response.ok || !data.ok) {
        const message =
          data.errors?.join(" ") || data.message || "Nuk u perditesua lista.";
        showMessage(messageElement, message, "error");
        return;
      }

      showMessage(messageElement, data.message || "Lista u perditesua.", "success");
      await loadItems();
      return;
    }

    if (action === "add-to-cart") {
      const { response, data } = await requestJson("/api/cart/add", {
        method: "POST",
        body: JSON.stringify({ productId }),
      });

      if (!response.ok || !data.ok) {
        const message =
          data.errors?.join(" ") || data.message || "Shporta nuk u perditesua.";
        showMessage(messageElement, message, "error");
        return;
      }

      showMessage(messageElement, data.message || "Produkti u shtua ne shporte.", "success");
      await loadItems();
    }
  }

  function handleSelectionChange(event) {
    const checkbox = event.target.closest("input[data-select-product-id]");
    if (!checkbox || !shouldEnableSelection()) {
      return;
    }

    const productId = Number(checkbox.dataset.selectProductId);
    if (!Number.isFinite(productId)) {
      return;
    }

    if (checkbox.checked) {
      selectedIds.add(productId);
    } else {
      selectedIds.delete(productId);
    }

    renderWishlistGrid();
    updateWishlistSelectionUi();
  }

  function handleSelectAllChange() {
    if (!shouldEnableSelection()) {
      return;
    }

    if (selectAllCheckbox.checked) {
      selectedIds = new Set(itemsState.map((item) => item.id));
    } else {
      selectedIds = new Set();
    }

    renderWishlistGrid();
    updateWishlistSelectionUi();
  }

  async function handleBulkAddToCart() {
    if (bulkCartButton.disabled || !currentUser) {
      return;
    }

    const selectedItems = getSelectedItems();
    if (selectedItems.length === 0) {
      showMessage(messageElement, "Zgjidh te pakten nje produkt per te vazhduar me blerje.", "error");
      return;
    }

    bulkCartButton.disabled = true;

    for (const item of selectedItems) {
      const { response, data } = await requestJson("/api/cart/add", {
        method: "POST",
        body: JSON.stringify({ productId: item.id }),
      });

      if (!response.ok || !data.ok) {
        const message =
          data.errors?.join(" ") || data.message || "Shporta nuk u perditesua.";
        showMessage(messageElement, message, "error");
        updateWishlistSelectionUi();
        return;
      }
    }

    showMessage(
      messageElement,
      selectedItems.length === 1
        ? "Produkti i zgjedhur u shtua ne cart."
        : "Produktet e zgjedhura u shtuan ne cart.",
      "success",
    );
    window.location.href = "/cart";
  }
}


function initializeCartPage() {
  const productsPanel = document.getElementById("cart-products-panel");
  const grid = document.getElementById("cart-products-grid");
  const toolbar = document.getElementById("cart-selection-toolbar");
  const selectAllCheckbox = document.getElementById("cart-select-all");
  const selectedCountElement = document.getElementById("cart-selected-count");
  const messageElement = document.getElementById("cart-page-message");
  const totalItemsElement = document.getElementById("cart-total-items");
  const totalPriceElement = document.getElementById("cart-total-price");
  const checkoutButton = document.getElementById("cart-checkout-button");
  const summaryCard = document.getElementById("cart-summary-card");

  if (
    !productsPanel ||
    !grid ||
    !toolbar ||
    !selectAllCheckbox ||
    !selectedCountElement ||
    !messageElement ||
    !totalItemsElement ||
    !totalPriceElement ||
    !checkoutButton ||
    !summaryCard
  ) {
    return;
  }

  let currentUser = null;
  let itemsState = [];
  let selectedIds = new Set();
  let selectionInitialized = false;
  let summaryResizeObserver = null;
  let summaryResizeFrame = null;

  bootstrap();

  async function bootstrap() {
    currentUser = await fetchCurrentUserOptional();

    if (!currentUser) {
      const guestMessage = "Per te perdorur shporten duhet te kyçesh ose te krijosh llogari.";
      grid.innerHTML = `
        <div class="collection-empty-state">
          ${escapeHtml(guestMessage)}
        </div>
      `;
      toolbar.hidden = true;
      updateSummary([]);
      checkoutButton.disabled = true;
      scheduleCartPanelHeightSync();
      showMessage(messageElement, guestMessage, "error");
      return;
    }

    checkoutButton.addEventListener("click", handleCheckout);
    grid.addEventListener("click", handleCollectionAction);
    grid.addEventListener("change", handleSelectionChange);
    selectAllCheckbox.addEventListener("change", handleSelectAllChange);
    window.addEventListener("resize", scheduleCartPanelHeightSync);
    setupCartHeightSync();
    await loadItems();
  }

  async function loadItems() {
    try {
      const { response, data } = await requestJson("/api/cart");

      if (!response.ok || !data.ok) {
        const message =
          data.errors?.join(" ") || data.message || "Shporta nuk u ngarkua.";
        showMessage(messageElement, message, "error");
        grid.innerHTML = `
          <div class="collection-empty-state">
            ${escapeHtml(message)}
          </div>
        `;
        toolbar.hidden = true;
        itemsState = [];
        updateSummary([]);
        checkoutButton.disabled = true;
        scheduleCartPanelHeightSync();
        return;
      }

      itemsState = Array.isArray(data.items) ? data.items : [];
      syncSelectionState();
      updateSummary(getSelectedItems());

      if (itemsState.length === 0) {
        showMessage(messageElement, "", "");
        grid.innerHTML = `
          <div class="collection-empty-state">
            Shporta jote eshte bosh. Shto produkte nga faqet e dyqanit dhe pastaj vazhdo me porosine.
          </div>
        `;
        toolbar.hidden = true;
        persistCheckoutSelectedCartIds([]);
        checkoutButton.disabled = true;
        scheduleCartPanelHeightSync();
        return;
      }

      showMessage(messageElement, "", "");
      renderCartGrid();
      updateSelectionUi();
      scheduleCartPanelHeightSync();
    } catch (error) {
      showMessage(messageElement, "Shporta nuk u ngarkua. Provoje perseri.", "error");
      grid.innerHTML = `
        <div class="collection-empty-state">
          Shporta nuk u ngarkua. Provoje perseri.
        </div>
      `;
      toolbar.hidden = true;
      itemsState = [];
      updateSummary([]);
      checkoutButton.disabled = true;
      scheduleCartPanelHeightSync();
      console.error(error);
    }
  }

  function setupCartHeightSync() {
    syncCartPanelHeight();

    if (!("ResizeObserver" in window) || summaryResizeObserver) {
      return;
    }

    summaryResizeObserver = new window.ResizeObserver(() => {
      scheduleCartPanelHeightSync();
    });
    summaryResizeObserver.observe(summaryCard);
  }

  function scheduleCartPanelHeightSync() {
    if (summaryResizeFrame) {
      window.cancelAnimationFrame(summaryResizeFrame);
    }

    summaryResizeFrame = window.requestAnimationFrame(() => {
      summaryResizeFrame = null;
      syncCartPanelHeight();
    });
  }

  function syncCartPanelHeight() {
    if (window.innerWidth <= 780) {
      productsPanel.style.removeProperty("--cart-panel-height");
      return;
    }

    const summaryHeight = Math.ceil(summaryCard.getBoundingClientRect().height);
    if (summaryHeight > 0) {
      productsPanel.style.setProperty("--cart-panel-height", `${summaryHeight}px`);
    }
  }

  function shouldEnableSelection() {
    return itemsState.length > 2;
  }

  function syncSelectionState() {
    const availableIds = new Set(itemsState.map((item) => item.id));

    if (!shouldEnableSelection()) {
      selectedIds = new Set(itemsState.map((item) => item.id));
      selectionInitialized = false;
      return;
    }

    if (!selectionInitialized) {
      selectedIds = new Set(itemsState.map((item) => item.id));
      selectionInitialized = true;
      return;
    }

    selectedIds = new Set([...selectedIds].filter((id) => availableIds.has(id)));
  }

  function getSelectedItems() {
    if (!shouldEnableSelection()) {
      return [...itemsState];
    }

    return itemsState.filter((item) => selectedIds.has(item.id));
  }

  function renderCartGrid() {
    grid.innerHTML = itemsState
      .map((item) =>
        renderCartItem(item, {
          selectionEnabled: shouldEnableSelection(),
          selected: selectedIds.has(item.id),
        }),
      )
      .join("");
  }

  function updateSummary(items) {
    const totals = items.reduce(
      (summary, item) => {
        const quantity = Math.max(0, Number(item.quantity) || 0);
        const price = Number(item.price) || 0;
        summary.items += quantity;
        summary.total += quantity * price;
        return summary;
      },
      { items: 0, total: 0 },
    );

    totalItemsElement.textContent = String(totals.items);
    totalPriceElement.textContent = formatPrice(totals.total);
  }

  function updateSelectionUi() {
    const selectionEnabled = shouldEnableSelection();
    toolbar.hidden = !selectionEnabled;

    if (!selectionEnabled) {
      checkoutButton.disabled = itemsState.length === 0;
      scheduleCartPanelHeightSync();
      return;
    }

    const selectedItems = getSelectedItems();
    const selectedCount = selectedItems.length;
    selectedCountElement.textContent = `${selectedCount} produkte te zgjedhura`;
    selectAllCheckbox.checked = itemsState.length > 0 && selectedCount === itemsState.length;
    selectAllCheckbox.indeterminate = selectedCount > 0 && selectedCount < itemsState.length;
    checkoutButton.disabled = selectedCount === 0;
    scheduleCartPanelHeightSync();
  }

  async function handleCollectionAction(event) {
    const button = event.target.closest("[data-action][data-product-id]");
    if (!button || !currentUser) {
      return;
    }

    const productId = Number(button.dataset.productId);
    if (!Number.isFinite(productId)) {
      return;
    }

    const action = button.dataset.action;

    if (action === "remove") {
      const { response, data } = await requestJson("/api/cart/remove", {
        method: "POST",
        body: JSON.stringify({ productId }),
      });

      if (!response.ok || !data.ok) {
        const message =
          data.errors?.join(" ") || data.message || "Shporta nuk u perditesua.";
        showMessage(messageElement, message, "error");
        return;
      }

      showMessage(messageElement, data.message || "Shporta u perditesua.", "success");
      await loadItems();
      return;
    }

    if (action === "increase-quantity") {
      const { response, data } = await requestJson("/api/cart/add", {
        method: "POST",
        body: JSON.stringify({ productId }),
      });

      if (!response.ok || !data.ok) {
        const message =
          data.errors?.join(" ") || data.message || "Shporta nuk u perditesua.";
        showMessage(messageElement, message, "error");
        return;
      }

      showMessage(messageElement, data.message || "Sasia u perditesua.", "success");
      await loadItems();
      return;
    }

    if (action === "decrease-quantity") {
      const currentQuantity = Number(button.dataset.currentQuantity);
      const nextQuantity = currentQuantity - 1;

      if (!Number.isFinite(currentQuantity) || nextQuantity < 1) {
        return;
      }

      const { response, data } = await requestJson("/api/cart/quantity", {
        method: "POST",
        body: JSON.stringify({ productId, quantity: nextQuantity }),
      });

      if (!response.ok || !data.ok) {
        const message =
          data.errors?.join(" ") || data.message || "Shporta nuk u perditesua.";
        showMessage(messageElement, message, "error");
        return;
      }

      showMessage(messageElement, data.message || "Sasia u perditesua.", "success");
      await loadItems();
    }
  }

  function handleSelectionChange(event) {
    const checkbox = event.target.closest("input[data-select-product-id]");
    if (!checkbox || !shouldEnableSelection()) {
      return;
    }

    const productId = Number(checkbox.dataset.selectProductId);
    if (!Number.isFinite(productId)) {
      return;
    }

    if (checkbox.checked) {
      selectedIds.add(productId);
    } else {
      selectedIds.delete(productId);
    }

    renderCartGrid();
    updateSummary(getSelectedItems());
    updateSelectionUi();
  }

  function handleSelectAllChange() {
    if (!shouldEnableSelection()) {
      return;
    }

    if (selectAllCheckbox.checked) {
      selectedIds = new Set(itemsState.map((item) => item.id));
    } else {
      selectedIds = new Set();
    }

    renderCartGrid();
    updateSummary(getSelectedItems());
    updateSelectionUi();
  }

  function handleCheckout() {
    if (checkoutButton.disabled) {
      return;
    }

    const selectedItems = getSelectedItems();
    if (selectedItems.length === 0) {
      showMessage(messageElement, "Zgjidh te pakten nje produkt per te vazhduar me porosi.", "error");
      return;
    }

    persistCheckoutSelectedCartIds(selectedItems.map((item) => item.id));
    window.location.href = "/adresa-e-porosise";
  }
}


function initializeSavedProductsPage(config) {
  const grid = document.getElementById(config.gridId);
  const messageElement = document.getElementById(config.messageId);

  if (!grid || !messageElement) {
    return;
  }

  let currentUser = null;

  bootstrap();

  async function bootstrap() {
    currentUser = await fetchCurrentUserOptional();

    if (!currentUser) {
      grid.innerHTML = `
        <div class="collection-empty-state">
          ${escapeHtml(config.guestMessage)}
        </div>
      `;
      showMessage(messageElement, config.guestMessage, "error");
      return;
    }

    await loadItems();
    grid.addEventListener("click", handleCollectionAction);
  }

  async function loadItems() {
    try {
      const { response, data } = await requestJson(config.fetchUrl);

      if (!response.ok || !data.ok) {
        const message =
          data.errors?.join(" ") || data.message || "Lista nuk u ngarkua.";
        showMessage(messageElement, message, "error");
        grid.innerHTML = `
          <div class="collection-empty-state">
            ${escapeHtml(message)}
          </div>
        `;
        return;
      }

      const items = Array.isArray(data.items) ? data.items : [];
      if (items.length === 0) {
        showMessage(messageElement, "", "");
        grid.innerHTML = `
          <div class="collection-empty-state">
            ${escapeHtml(config.emptyMessage)}
          </div>
        `;
        return;
      }

      showMessage(messageElement, "", "");
      grid.innerHTML = items.map((item) => config.renderItem(item)).join("");
    } catch (error) {
      showMessage(messageElement, "Lista nuk u ngarkua. Provoje perseri.", "error");
      grid.innerHTML = `
        <div class="collection-empty-state">
          Lista nuk u ngarkua. Provoje perseri.
        </div>
      `;
      console.error(error);
    }
  }

  async function handleCollectionAction(event) {
    const button = event.target.closest("[data-action][data-product-id]");
    if (!button || !currentUser) {
      return;
    }

    const productId = Number(button.dataset.productId);
    if (!Number.isFinite(productId)) {
      return;
    }

    const action = button.dataset.action;

    if (action === "remove" && config.actions.remove) {
      const { response, data } = await requestJson(config.actions.remove, {
        method: "POST",
        body: JSON.stringify({ productId }),
      });

      if (!response.ok || !data.ok) {
        const message =
          data.errors?.join(" ") || data.message || "Nuk u perditesua lista.";
        showMessage(messageElement, message, "error");
        return;
      }

      showMessage(messageElement, data.message || "Lista u perditesua.", "success");
      await loadItems();
      return;
    }

    if (action === "add-to-cart" && config.actions.addToCart) {
      const { response, data } = await requestJson(config.actions.addToCart, {
        method: "POST",
        body: JSON.stringify({ productId }),
      });

      if (!response.ok || !data.ok) {
        const message =
          data.errors?.join(" ") || data.message || "Shporta nuk u perditesua.";
        showMessage(messageElement, message, "error");
        return;
      }

      showMessage(messageElement, data.message || "Produkti u shtua ne shporte.", "success");
      await loadItems();
    }
  }
}


function initializeAdminProductsPage() {
  const userElement = document.getElementById("admin-user-role");
  const accessElement = document.getElementById("admin-access-note");
  const formSection = document.getElementById("admin-form-section");
  const form = document.getElementById("product-form");
  const submitButton = document.getElementById("product-submit-button");
  const messageElement = document.getElementById("product-form-message");
  const listMessageElement = document.getElementById("admin-list-message");
  const listElement = document.getElementById("admin-products-list");
  const usersMessageElement = document.getElementById("admin-users-message");
  const usersListElement = document.getElementById("admin-users-list");
  const productCategorySelect = document.getElementById("product-category");
  const productTypeSelect = document.getElementById("product-type");
  const productSizeField = document.getElementById("product-size-field");
  const productSizeSelect = document.getElementById("product-size");
  const productImagesInput = document.getElementById("product-images");
  const productUploadPreview = document.getElementById("product-upload-preview");

  if (
    !userElement ||
    !accessElement ||
    !formSection ||
    !form ||
    !submitButton ||
    !messageElement ||
    !listMessageElement ||
    !listElement ||
    !usersMessageElement ||
    !usersListElement ||
    !productCategorySelect ||
    !productTypeSelect ||
    !productSizeField ||
    !productSizeSelect ||
    !productImagesInput ||
    !productUploadPreview
  ) {
    return;
  }

  let previewUrls = [];

  bootstrap();

  async function bootstrap() {
    try {
      const { response, data } = await requestJson("/api/me");

      if (!response.ok || !data.ok || !data.user) {
        window.location.href = "/login";
        return;
      }

      userElement.textContent = `${data.user.fullName} • ${formatRoleLabel(data.user.role)}`;

      if (data.user.role !== "admin") {
        accessElement.textContent = "Vetem admin mund te shtoje dhe menaxhoje artikuj.";
        formSection.hidden = true;
        listElement.innerHTML = `
          <div class="admin-empty-state">
            Nuk ke akses administrativ ne kete faqe.
          </div>
        `;
        return;
      }

      accessElement.textContent =
        "Je kyçur si admin. Nga kjo faqe mund të shtosh artikuj të rinj që dalin automatikisht si karta.";
      formSection.hidden = false;
      populateProductSectionSelect(productCategorySelect);
      populateProductTypeSelect(productCategorySelect.value, productTypeSelect);
      syncProductSizeField();
      renderSelectedImagePreviews();
      await Promise.all([loadProducts(), loadUsers(data.user)]);

      form.addEventListener("submit", handleSubmit);
      productCategorySelect.addEventListener("change", handleProductSectionChange);
      productImagesInput.addEventListener("change", renderSelectedImagePreviews);
      listElement.addEventListener("click", handleListAction);
      usersListElement.addEventListener("click", handleUserAction);
    } catch (error) {
      accessElement.textContent =
        "Nuk mund ta kontrollojme sesionin tani. Provoje perseri pas pak.";
      console.error(error);
    }
  }

  async function handleSubmit(event) {
    event.preventDefault();
    showMessage(messageElement, "", "");

    const formData = new FormData(form);
    const imageFiles = Array.from(productImagesInput.files || []);
    const payload = {
      title: formData.get("title")?.toString().trim() || "",
      price: formData.get("price")?.toString().trim() || "",
      description: formData.get("description")?.toString().trim() || "",
      category: formData.get("category")?.toString().trim() || "",
      productType: formData.get("productType")?.toString().trim() || "",
      size: formData.get("size")?.toString().trim() || "",
      color: formData.get("color")?.toString().trim() || "",
      stockQuantity: formData.get("stockQuantity")?.toString().trim() || "",
    };

    if (imageFiles.length === 0) {
      showMessage(
        messageElement,
        "Zgjidh te pakten nje foto te produktit.",
        "error",
      );
      return;
    }

    setButtonLoading(
      submitButton,
      true,
      "Ruaje artikullin",
      "Duke ruajtur...",
    );

    try {
      const uploadedImagePaths = await uploadProductImages(imageFiles);
      if (uploadedImagePaths.length === 0) {
        return;
      }

      payload.imageGallery = uploadedImagePaths;
      payload.imagePath = uploadedImagePaths[0];

      const { response, data } = await requestJson("/api/products", {
        method: "POST",
        body: JSON.stringify(payload),
      });

      if (!response.ok || !data.ok) {
        const message =
          data.errors?.join(" ") ||
          data.message ||
          "Artikulli nuk u ruajt.";
        showMessage(messageElement, message, "error");
        return;
      }

      showMessage(
        messageElement,
        "Artikulli u ruajt me sukses dhe tani del ne faqen e kategorise.",
        "success",
      );
      form.reset();
      revokePreviewUrls();
      renderSelectedImagePreviews();
      productCategorySelect.value = PRODUCT_SECTION_OPTIONS[0]?.value || "";
      populateProductTypeSelect(productCategorySelect.value, productTypeSelect);
      productSizeSelect.value = "";
      const productColorSelect = document.getElementById("product-color");
      if (productColorSelect) {
        productColorSelect.value = "";
      }

      const stockQuantityInput = document.getElementById("product-stock-quantity");
      if (stockQuantityInput) {
        stockQuantityInput.value = "1";
      }

      syncProductSizeField();

      await loadProducts();
    } catch (error) {
      showMessage(
        messageElement,
        "Serveri nuk po pergjigjet. Provoje perseri.",
        "error",
      );
      console.error(error);
    } finally {
      setButtonLoading(
        submitButton,
        false,
        "Ruaje artikullin",
        "Duke ruajtur...",
      );
    }
  }

  async function loadProducts() {
    try {
      const { response, data } = await requestJson("/api/admin/products");

      if (!response.ok || !data.ok) {
        listElement.innerHTML = `
          <div class="admin-empty-state">
            Lista e artikujve nuk u ngarkua.
          </div>
        `;
        return;
      }

      const products = Array.isArray(data.products) ? data.products : [];
      if (products.length === 0) {
        listElement.innerHTML = `
          <div class="admin-empty-state">
            Ende nuk ka artikuj. Përdore formën lart për të shtuar produktin e parë.
          </div>
        `;
        return;
      }

      listElement.innerHTML = products
        .map((product) => renderAdminProductItem(product))
        .join("");
    } catch (error) {
      listElement.innerHTML = `
        <div class="admin-empty-state">
          Artikujt nuk u ngarkuan. Provoje perseri.
        </div>
      `;
      console.error(error);
    }
  }

  async function uploadProductImages(files) {
    return uploadProductImagesForPanel(files, messageElement);
  }

  async function loadUsers(currentUser) {
    try {
      const { response, data } = await requestJson("/api/admin/users");

      if (!response.ok || !data.ok) {
        usersListElement.innerHTML = `
          <div class="admin-empty-state">
            Lista e perdoruesve nuk u ngarkua.
          </div>
        `;
        return;
      }

      const users = Array.isArray(data.users) ? data.users : [];
      if (users.length === 0) {
        usersListElement.innerHTML = `
          <div class="admin-empty-state">
            Ende nuk ka perdorues te regjistruar.
          </div>
        `;
        return;
      }

      usersListElement.innerHTML = users
        .map((user) => renderAdminUserItem(user, currentUser))
        .join("");
    } catch (error) {
      usersListElement.innerHTML = `
        <div class="admin-empty-state">
          Perdoruesit nuk u ngarkuan. Provoje perseri.
        </div>
      `;
      console.error(error);
    }
  }

  async function handleListAction(event) {
    const button = event.target.closest("[data-action][data-product-id]");
    if (!button) {
      return;
    }

    const productId = Number(button.dataset.productId);
    if (!Number.isFinite(productId)) {
      return;
    }

    const productCard = button.closest(".admin-product-item");
    const action = button.dataset.action;

    if (action === "delete-product") {
      const shouldDelete = window.confirm("A do ta fshish kete produkt?");
      if (!shouldDelete) {
        return;
      }

      await submitAdminListAction(
        "/api/products/delete",
        { productId },
        "Produkti u fshi me sukses.",
      );
      return;
    }

    if (action === "toggle-visibility") {
      const nextValue = button.dataset.nextValue === "true";
      await submitAdminListAction(
        "/api/products/public-visibility",
        { productId, isPublic: nextValue },
        nextValue
          ? "Produkti tani shfaqet per userat."
          : "Produkti u fsheh nga pamja publike.",
      );
      return;
    }

    if (action === "toggle-stock-public") {
      const nextValue = button.dataset.nextValue === "true";
      await submitAdminListAction(
        "/api/products/public-stock",
        { productId, showStockPublic: nextValue },
        nextValue
          ? "Gjendja ne stok tani shfaqet publikisht."
          : "Gjendja ne stok u fsheh nga pamja publike.",
      );
      return;
    }

    if (action === "restock" && productCard) {
      const input = productCard.querySelector("[data-restock-input]");
      const quantity = input?.value?.toString().trim() || "";

      await submitAdminListAction(
        "/api/products/restock",
        { productId, quantity },
        "Stoku u perditesua me sukses.",
      );

      if (input) {
        input.value = "1";
      }
    }
  }

  async function submitAdminListAction(url, payload, successMessage) {
    showMessage(listMessageElement, "", "");

    try {
      const { response, data } = await requestJson(url, {
        method: "POST",
        body: JSON.stringify(payload),
      });

      if (!response.ok || !data.ok) {
        const message =
          data.errors?.join(" ") ||
          data.message ||
          "Veprimi nuk u ruajt.";
        showMessage(listMessageElement, message, "error");
        return;
      }

      showMessage(
        listMessageElement,
        data.message || successMessage,
        "success",
      );
      await loadProducts();
    } catch (error) {
      showMessage(
        listMessageElement,
        "Serveri nuk po pergjigjet. Provoje perseri.",
        "error",
      );
      console.error(error);
    }
  }

  async function handleUserAction(event) {
    const button = event.target.closest("[data-action][data-user-id]");
    if (!button) {
      return;
    }

    const userId = Number(button.dataset.userId);
    if (!Number.isFinite(userId)) {
      return;
    }

    showMessage(usersMessageElement, "", "");
    const action = button.dataset.action;
    const userCard = button.closest(".admin-user-item");

    if (action === "toggle-role") {
      const nextRole = button.dataset.nextRole || "";
      await submitAdminUserAction(
        "/api/admin/users/role",
        { userId, role: nextRole },
        "Roli u perditesua me sukses.",
      );
      return;
    }

    if (action === "delete-user") {
      const shouldDelete = window.confirm("A do ta fshish kete user?");
      if (!shouldDelete) {
        return;
      }

      await submitAdminUserAction(
        "/api/admin/users/delete",
        { userId },
        "Perdoruesi u fshi me sukses.",
      );
      return;
    }

    if (action === "set-user-password" && userCard) {
      const passwordInput = userCard.querySelector("[data-admin-password-input]");
      const newPassword = passwordInput?.value?.toString() || "";

      await submitAdminUserAction(
        "/api/admin/users/set-password",
        { userId, newPassword },
        "Fjalekalimi u ndryshua me sukses.",
      );

      if (passwordInput) {
        passwordInput.value = "";
        passwordInput.type = "password";
      }
      return;
    }

    if (action === "toggle-user-password" && userCard) {
      const passwordInput = userCard.querySelector("[data-admin-password-input]");
      const iconWrap = button.querySelector(".admin-password-toggle-icon");
      if (!passwordInput) {
        return;
      }

      const isVisible = passwordInput.type === "text";
      passwordInput.type = isVisible ? "password" : "text";
      button.setAttribute(
        "aria-label",
        isVisible ? "Shfaq fjalekalimin" : "Fshehe fjalekalimin",
      );
      if (iconWrap) {
        iconWrap.innerHTML = isVisible ? eyeIcon() : eyeOffIcon();
      }
    }
  }

  async function submitAdminUserAction(url, payload, successMessage) {
    try {
      const { response, data } = await requestJson(url, {
        method: "POST",
        body: JSON.stringify(payload),
      });

      if (!response.ok || !data.ok) {
        const message =
          data.errors?.join(" ") ||
          data.message ||
          "Veprimi nuk u ruajt.";
        showMessage(usersMessageElement, message, "error");
        return;
      }

      showMessage(
        usersMessageElement,
        data.message || successMessage,
        "success",
      );

      const currentUser = await fetchCurrentUserOptional();
      await loadUsers(currentUser);
    } catch (error) {
      showMessage(
        usersMessageElement,
        "Serveri nuk po pergjigjet. Provoje perseri.",
        "error",
      );
      console.error(error);
    }
  }

  function handleProductSectionChange() {
    populateProductTypeSelect(productCategorySelect.value, productTypeSelect);
    syncProductSizeField();
  }

  function syncProductSizeField() {
    const isClothing = isClothingSection(productCategorySelect.value);
    productSizeField.hidden = !isClothing;
    productSizeSelect.required = isClothing;

    if (!isClothing) {
      productSizeSelect.value = "";
    }
  }

  function renderSelectedImagePreviews() {
    revokePreviewUrls();
    const files = Array.from(productImagesInput.files || []);

    if (files.length === 0) {
      productUploadPreview.innerHTML = `
        <div class="product-upload-empty">Asnje foto nuk eshte zgjedhur ende.</div>
      `;
      return;
    }

    productUploadPreview.innerHTML = files
      .map((file, index) => {
        const objectUrl = URL.createObjectURL(file);
        previewUrls.push(objectUrl);

        return `
          <figure class="product-upload-preview-item">
            <img class="product-upload-preview-image" src="${escapeAttribute(objectUrl)}" alt="${escapeAttribute(file.name)}">
            <figcaption class="product-upload-preview-name">
              ${index === 0 ? "Cover" : `Foto ${index + 1}`} • ${escapeHtml(file.name)}
            </figcaption>
          </figure>
        `;
      })
      .join("");
  }

  function revokePreviewUrls() {
    previewUrls.forEach((previewUrl) => {
      URL.revokeObjectURL(previewUrl);
    });
    previewUrls = [];
  }
}


function initializeForgotPasswordPage() {
  const form = document.getElementById("forgot-password-form");
  const messageElement = document.getElementById("forgot-password-message");
  const submitButton = document.getElementById("forgot-password-submit-button");

  if (!form || !messageElement || !submitButton) {
    return;
  }

  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    showMessage(messageElement, "", "");

    const formData = new FormData(form);
    const payload = {
      email: formData.get("email")?.toString().trim() || "",
    };

    setButtonLoading(
      submitButton,
      true,
      "Me dergo kodin per ndryshim te fjalekalimit",
      "Duke derguar kerkesen...",
    );

    try {
      const { response, data } = await requestJson("/api/forgot-password", {
        method: "POST",
        body: JSON.stringify(payload),
      });

      if (!response.ok || !data.ok) {
        const message =
          data.errors?.join(" ") ||
          data.message ||
          "Kerkesa per kod nuk funksionoi.";
        showMessage(messageElement, message, "error");
        return;
      }

      showMessage(
        messageElement,
        data.message || "Kerkesa per kod u pranua.",
        "success",
      );
      form.reset();
    } catch (error) {
      showMessage(
        messageElement,
        "Serveri nuk po pergjigjet. Provoje perseri.",
        "error",
      );
      console.error(error);
    } finally {
      setButtonLoading(
        submitButton,
        false,
        "Me dergo kodin per ndryshim te fjalekalimit",
        "Duke derguar kerkesen...",
      );
    }
  });
}


async function requestJson(url, options = {}) {
  const config = { ...options };
  config.headers = { ...(options.headers || {}) };

  if (
    config.body &&
    !(config.body instanceof FormData) &&
    !config.headers["Content-Type"]
  ) {
    config.headers["Content-Type"] = "application/json";
  }

  const response = await fetch(url, config);
  let data = {};

  try {
    data = await response.json();
  } catch (error) {
    console.error(error);
  }

  return { response, data };
}


async function uploadProductImagesForPanel(files, messageElement) {
  const uploadData = new FormData();
  files.forEach((file) => {
    uploadData.append("images", file);
  });

  const { response, data } = await requestJson("/api/uploads", {
    method: "POST",
    body: uploadData,
  });

  if (
    !response.ok ||
    !data.ok ||
    !Array.isArray(data.paths) ||
    data.paths.length === 0
  ) {
    const message =
      data.errors?.join(" ") ||
      data.message ||
      "Fotot nuk u ngarkuan.";
    showMessage(messageElement, message, "error");
    return [];
  }

  return data.paths;
}


function persistLoginGreeting(value) {
  try {
    const nextValue = String(value || "").trim() || "User";
    window.sessionStorage.setItem(LOGIN_GREETING_KEY, nextValue);
  } catch (error) {
    console.error(error);
  }
}


function consumeLoginGreeting() {
  try {
    const value = String(window.sessionStorage.getItem(LOGIN_GREETING_KEY) || "").trim();
    if (!value) {
      return "";
    }

    window.sessionStorage.removeItem(LOGIN_GREETING_KEY);
    return value;
  } catch (error) {
    console.error(error);
    return "";
  }
}


async function uploadProfileImage(file, messageElement) {
  const uploadData = new FormData();
  uploadData.append("image", file);

  const { response, data } = await requestJson("/api/profile/photo", {
    method: "POST",
    body: uploadData,
  });

  if (!response.ok || !data.ok || !data.path) {
    const message =
      data.errors?.join(" ") ||
      data.message ||
      "Fotoja e profilit nuk u ngarkua.";
    showMessage(messageElement, message, "error");
    return "";
  }

  return String(data.path).trim();
}


function showMessage(element, message, type) {
  element.textContent = message;
  element.className = type ? `form-message ${type}` : "form-message";
}


function setButtonLoading(button, isLoading, idleText, loadingText) {
  button.disabled = isLoading;
  button.textContent = isLoading ? loadingText : idleText;
}


function renderPetProductCard(product, state = {}) {
  const wishlistClass = state.isWishlisted ? " active" : "";
  const cartClass = state.isInCart ? " active" : "";
  const cartLabel = state.isInCart ? "Ne cart" : "Shto ne cart";
  const detailUrl = getProductDetailUrl(product.id);
  const details = [
    formatProductTypeLabel(product.productType),
    product.size ? `Madhesia: ${product.size}` : "",
    product.color ? `Ngjyra: ${formatProductColorLabel(product.color)}` : "",
    product.showStockPublic && Number(product.stockQuantity) > 0 ? "Ne stok" : "",
  ].filter(Boolean);

  return `
    <article class="pet-product-card" aria-label="${escapeHtml(product.title)}">
      <a class="pet-product-link" href="${escapeAttribute(detailUrl)}" aria-label="Hape produktin ${escapeAttribute(product.title)}">
        <div class="pet-product-image-wrap">
          <img class="pet-product-image" src="${escapeAttribute(product.imagePath)}" alt="${escapeAttribute(product.title)}">
        </div>
      </a>
      <div class="pet-product-content">
        <p class="pet-product-label">${escapeHtml(formatCategoryLabel(product.category))}</p>
        <h3><a class="pet-product-title-link" href="${escapeAttribute(detailUrl)}">${escapeHtml(product.title)}</a></h3>
        <p class="pet-product-description">${escapeHtml(product.description)}</p>
        <div class="product-detail-tags">
          ${details.map((detail) => `<span class="product-detail-tag">${escapeHtml(detail)}</span>`).join("")}
        </div>
        <div class="pet-product-footer">
          <strong class="pet-product-price">${escapeHtml(formatPrice(product.price))}</strong>
          <a class="pet-product-more" href="${escapeAttribute(detailUrl)}">Shiko produktin</a>
        </div>
        <div class="product-card-actions">
          <button class="product-action-button wishlist-action${wishlistClass}" type="button" data-action="wishlist" data-product-id="${product.id}" aria-label="Wishlist">
            ${heartIcon()}
            <span>Wishlist</span>
          </button>
          <button class="product-action-button cart-action${cartClass}" type="button" data-action="cart" data-product-id="${product.id}" aria-label="Cart">
            ${cartIcon()}
            <span>${escapeHtml(cartLabel)}</span>
          </button>
        </div>
      </div>
    </article>
  `;
}


function renderHomePromoSlide(slide) {
  return `
    <article class="home-promo-slide" style="background-image: linear-gradient(135deg, rgba(8, 20, 12, 0.18), rgba(8, 20, 12, 0.62)), url('${escapeAttribute(slide.imagePath)}');">
      <div class="home-promo-copy">
        <span class="home-promo-badge">${escapeHtml(slide.badge)}</span>
        <h2>${escapeHtml(slide.title)}</h2>
        <p>${escapeHtml(slide.description)}</p>
        <a class="hero-cta home-promo-cta" href="${escapeAttribute(slide.ctaHref)}">${escapeHtml(slide.ctaLabel)}</a>
      </div>
    </article>
  `;
}


function renderHomeBusinessesTrack(businesses) {
  const normalizedBusinesses = Array.isArray(businesses) ? businesses : [];
  if (normalizedBusinesses.length === 0) {
    return "";
  }

  const loopingBusinesses = [];
  while (loopingBusinesses.length < Math.max(8, normalizedBusinesses.length * 2)) {
    loopingBusinesses.push(...normalizedBusinesses);
  }

  const visibleBusinesses = loopingBusinesses.slice(0, Math.max(8, normalizedBusinesses.length * 2));
  const duplicatedBusinesses = [...visibleBusinesses, ...visibleBusinesses];

  return duplicatedBusinesses
    .map((business) => renderHomeBusinessBadge(business))
    .join("");
}


function countGridColumns(grid) {
  if (!grid) {
    return 1;
  }

  const templateColumns = String(window.getComputedStyle(grid).gridTemplateColumns || "").trim();
  if (!templateColumns || templateColumns === "none") {
    return 1;
  }

  return Math.max(1, templateColumns.split(" ").filter(Boolean).length);
}


function renderHomeBusinessBadge(business) {
  const businessName = String(business?.businessName || "").trim() || "Biznes";
  const logoPath = String(business?.logoPath || "").trim();
  const city = String(business?.city || "").trim();
  const initials = getBusinessInitials(businessName);
  const subtitle = city || "Partner i TREGO";
  const profileUrl = String(business?.profileUrl || "").trim() || getBusinessProfileUrl(business?.id || "");

  return `
    <a class="home-business-badge" href="${escapeAttribute(profileUrl)}" aria-label="${escapeHtml(businessName)}">
      <div class="home-business-logo-shell">
        ${
          logoPath
            ? `<img class="home-business-logo" src="${escapeAttribute(logoPath)}" alt="${escapeAttribute(businessName)}">`
            : `<span class="home-business-logo-fallback">${escapeHtml(initials)}</span>`
        }
      </div>
      <div class="home-business-copy">
        <strong>${escapeHtml(businessName)}</strong>
        <span>${escapeHtml(subtitle)}</span>
      </div>
    </a>
  `;
}


function renderAdminProductItem(product) {
  const details = [
    formatProductTypeLabel(product.productType),
    product.size ? `Madhesia ${product.size}` : "",
    product.color ? `Ngjyra ${formatProductColorLabel(product.color)}` : "",
    `Stok ${formatStockQuantity(product.stockQuantity)}`,
    product.isPublic ? "Publik" : "I fshehur",
    product.showStockPublic && Number(product.stockQuantity) > 0
      ? "Stoku duket publikisht"
      : "Stoku eshte privat",
  ].filter(Boolean);
  const visibilityLabel = product.isPublic ? "Mshehe nga userat" : "Shfaqe per userat";
  const stockLabel = product.showStockPublic && Number(product.stockQuantity) > 0
    ? "Fshehe stokun"
    : "Shfaqe si ne stok";
  const hiddenClass = product.isPublic ? "" : " is-hidden";

  return `
    <article class="admin-product-item${hiddenClass}">
      <a class="admin-product-link" href="${escapeAttribute(getProductDetailUrl(product.id))}">
        <div class="admin-product-thumb-wrap">
          <img class="admin-product-thumb" src="${escapeAttribute(product.imagePath)}" alt="${escapeAttribute(product.title)}">
        </div>
      </a>
      <div class="admin-product-copy">
        <p class="admin-product-meta">${escapeHtml(formatCategoryLabel(product.category))}</p>
        <h3><a class="admin-product-title-link" href="${escapeAttribute(getProductDetailUrl(product.id))}">${escapeHtml(product.title)}</a></h3>
        <p>${escapeHtml(product.description)}</p>
        <div class="product-detail-tags product-detail-tags-admin">
          ${details.map((detail) => `<span class="product-detail-tag">${escapeHtml(detail)}</span>`).join("")}
        </div>
      </div>
      <div class="admin-product-side">
        <strong class="admin-product-price">${escapeHtml(formatPrice(product.price))}</strong>
        <div class="admin-product-controls">
          <div class="admin-stock-editor">
            <input class="admin-stock-input" data-restock-input type="number" min="1" step="1" value="1" aria-label="Shto stok">
            <button class="product-action-button admin-action-button" type="button" data-action="restock" data-product-id="${product.id}">
              <span>Shto stok</span>
            </button>
          </div>
          <button class="product-action-button admin-action-button" type="button" data-action="toggle-visibility" data-next-value="${product.isPublic ? "false" : "true"}" data-product-id="${product.id}">
            <span>${escapeHtml(visibilityLabel)}</span>
          </button>
          <button class="product-action-button admin-action-button" type="button" data-action="toggle-stock-public" data-next-value="${product.showStockPublic && Number(product.stockQuantity) > 0 ? "false" : "true"}" data-product-id="${product.id}">
            <span>${escapeHtml(stockLabel)}</span>
          </button>
          <button class="product-action-button admin-action-button admin-action-danger" type="button" data-action="delete-product" data-product-id="${product.id}">
            <span>Fshije produktin</span>
          </button>
        </div>
      </div>
    </article>
  `;
}


function renderProductDetailCard(product, state = {}) {
  const wishlistClass = state.isWishlisted ? " active" : "";
  const cartClass = state.isInCart ? " active" : "";
  const cartLabel = state.isInCart ? "Ne cart" : "Shto ne cart";
  const imageGallery = getProductImageGallery(product);
  const currentImageIndex = getSafeGalleryIndex(
    state.currentImageIndex,
    imageGallery.length,
  );
  const currentImagePath = imageGallery[currentImageIndex] || product.imagePath;
  const details = [
    formatCategoryLabel(product.category),
    formatProductTypeLabel(product.productType),
    product.size ? `Madhesia: ${product.size}` : "",
    product.color ? `Ngjyra: ${formatProductColorLabel(product.color)}` : "",
    product.showStockPublic && Number(product.stockQuantity) > 0 ? "Ne stok" : "",
  ].filter(Boolean);

  return `
    <article class="card product-detail-card" aria-label="${escapeHtml(product.title)}">
      <div class="product-detail-media">
        <a class="product-detail-back-link" href="${escapeAttribute(getCategoryUrl(product.category))}">Kthehu te produktet</a>
        <div class="product-detail-image-shell">
          <img class="product-detail-image" src="${escapeAttribute(currentImagePath)}" alt="${escapeAttribute(product.title)}">
        </div>
        ${
          imageGallery.length > 1
            ? `
              <div class="product-gallery-controls">
                <span class="product-gallery-counter">${currentImageIndex + 1} / ${imageGallery.length}</span>
                <button class="product-gallery-next" type="button" data-action="next-image" data-product-id="${product.id}">
                  Next
                </button>
              </div>
            `
            : ""
        }
      </div>
      <div class="product-detail-copy">
        <p class="product-detail-category">${escapeHtml(formatCategoryLabel(product.category))}</p>
        <h1>${escapeHtml(product.title)}</h1>
        <p class="product-detail-description">${escapeHtml(product.description)}</p>
        <div class="product-detail-tags">
          ${details.map((detail) => `<span class="product-detail-tag">${escapeHtml(detail)}</span>`).join("")}
        </div>
        <strong class="product-detail-price">${escapeHtml(formatPrice(product.price))}</strong>
        <div class="product-detail-actions">
          <button class="product-action-button wishlist-action${wishlistClass}" type="button" data-action="wishlist" data-product-id="${product.id}" aria-label="Wishlist">
            ${heartIcon()}
            <span>${state.isWishlisted ? "Ne wishlist" : "Wishlist"}</span>
          </button>
          <button class="product-action-button cart-action${cartClass}" type="button" data-action="cart" data-product-id="${product.id}" aria-label="Cart">
            ${cartIcon()}
            <span>${escapeHtml(cartLabel)}</span>
          </button>
        </div>
      </div>
    </article>
  `;
}


function renderAdminUserItem(user, currentUser = null) {
  const isCurrentUser = currentUser && currentUser.id === user.id;
  const disabledAttribute = isCurrentUser ? " disabled" : "";
  const currentUserLabel = isCurrentUser ? " • Ti" : "";
  const roleOptions = [
    { role: "admin", label: "Beje admin" },
    { role: "business", label: "Beje biznes" },
    { role: "client", label: "Beje user" },
  ].filter((option) => option.role !== user.role);

  return `
    <article class="admin-user-item">
      <div class="admin-user-copy">
        <p class="admin-user-meta">${escapeHtml(formatRoleLabel(user.role))}${currentUserLabel}</p>
        <h3>${escapeHtml(user.fullName)}</h3>
        <p>${escapeHtml(user.email)}</p>
        <span class="admin-user-created">Krijuar me ${escapeHtml(formatDateLabel(user.createdAt))}</span>
      </div>
      <div class="admin-user-actions">
        <div class="admin-user-password-row">
          <div class="admin-password-input-wrap">
            <input class="admin-user-password-input" data-admin-password-input type="password" placeholder="Fjalekalim i ri" aria-label="Vendos fjalekalim te ri per ${escapeAttribute(user.fullName)}">
            <button class="admin-password-toggle" type="button" data-action="toggle-user-password" data-user-id="${user.id}" aria-label="Shfaq fjalekalimin">
              <span class="admin-password-toggle-icon">${eyeIcon()}</span>
            </button>
          </div>
          <button class="product-action-button admin-action-button" type="button" data-action="set-user-password" data-user-id="${user.id}">
            <span>Ruaje fjalekalimin</span>
          </button>
        </div>
        <div class="admin-user-button-row">
          ${roleOptions.map((option) => `
            <button class="product-action-button admin-action-button" type="button" data-action="toggle-role" data-user-id="${user.id}" data-next-role="${escapeAttribute(option.role)}"${disabledAttribute}>
              <span>${escapeHtml(option.label)}</span>
            </button>
          `).join("")}
          <button class="product-action-button admin-action-button admin-action-danger" type="button" data-action="delete-user" data-user-id="${user.id}"${disabledAttribute}>
            <span>Fshije user-in</span>
          </button>
        </div>
      </div>
    </article>
  `;
}


function renderWishlistItem(product, options = {}) {
  const details = [
    formatProductTypeLabel(product.productType),
    product.size ? `Madhesia: ${product.size}` : "",
    product.color ? `Ngjyra: ${formatProductColorLabel(product.color)}` : "",
    product.showStockPublic && Number(product.stockQuantity) > 0 ? "Ne stok" : "",
  ].filter(Boolean);

  return `
    <article class="saved-product-card${options.selectionEnabled ? " selectable" : ""}${options.selected ? " is-selected" : ""}" aria-label="${escapeHtml(product.title)}">
      ${options.selectionEnabled ? `
        <div class="saved-product-selector-row">
          <label class="saved-product-selector">
            <input type="checkbox" data-select-product-id="${product.id}"${options.selected ? " checked" : ""}>
            <span>Zgjidhe per blerje</span>
          </label>
        </div>
      ` : ""}
      <div class="saved-product-image-wrap">
        <img class="saved-product-image" src="${escapeAttribute(product.imagePath)}" alt="${escapeAttribute(product.title)}">
      </div>
      <div class="saved-product-copy">
        <p class="saved-product-meta">${escapeHtml(formatCategoryLabel(product.category))}</p>
        <h3>${escapeHtml(product.title)}</h3>
        <p>${escapeHtml(product.description)}</p>
        <div class="product-detail-tags product-detail-tags-saved">
          ${details.map((detail) => `<span class="product-detail-tag">${escapeHtml(detail)}</span>`).join("")}
        </div>
        <strong class="saved-product-price">${escapeHtml(formatPrice(product.price))}</strong>
      </div>
      <div class="saved-product-actions">
        <button class="product-action-button wishlist-action active" type="button" data-action="remove" data-product-id="${product.id}">
          ${heartIcon()}
          <span>Hiqe</span>
        </button>
        <button class="product-action-button cart-action" type="button" data-action="add-to-cart" data-product-id="${product.id}">
          ${cartIcon()}
          <span>Shto ne cart</span>
        </button>
      </div>
    </article>
  `;
}


function renderCartItem(product, options = {}) {
  const details = [
    formatProductTypeLabel(product.productType),
    product.size ? `Madhesia: ${product.size}` : "",
    product.color ? `Ngjyra: ${formatProductColorLabel(product.color)}` : "",
    product.showStockPublic && Number(product.stockQuantity) > 0 ? "Ne stok" : "",
  ].filter(Boolean);

  return `
    <article class="saved-product-card${options.selectionEnabled ? " selectable" : ""}${options.selected ? " is-selected" : ""}" aria-label="${escapeHtml(product.title)}">
      ${options.selectionEnabled ? `
        <div class="saved-product-selector-row">
          <label class="saved-product-selector">
            <input type="checkbox" data-select-product-id="${product.id}"${options.selected ? " checked" : ""}>
            <span>Perfshije ne porosi</span>
          </label>
        </div>
      ` : ""}
      <div class="saved-product-image-wrap">
        <img class="saved-product-image" src="${escapeAttribute(product.imagePath)}" alt="${escapeAttribute(product.title)}">
      </div>
      <div class="saved-product-copy">
        <p class="saved-product-meta">${escapeHtml(formatCategoryLabel(product.category))}</p>
        <h3>${escapeHtml(product.title)}</h3>
        <p>${escapeHtml(product.description)}</p>
        <div class="product-detail-tags product-detail-tags-saved">
          ${details.map((detail) => `<span class="product-detail-tag">${escapeHtml(detail)}</span>`).join("")}
        </div>
        <div class="saved-product-summary">
          <strong class="saved-product-price">${escapeHtml(formatPrice(product.price))}</strong>
          <div class="cart-quantity-control" aria-label="Ndrysho sasine e produktit">
            <button
              class="cart-quantity-button"
              type="button"
              data-action="decrease-quantity"
              data-product-id="${product.id}"
              data-current-quantity="${product.quantity}"
              aria-label="Ule sasine"
              ${Number(product.quantity) <= 1 ? "disabled" : ""}
            >
              -
            </button>
            <span class="saved-product-quantity">${escapeHtml(product.quantity)}</span>
            <button
              class="cart-quantity-button"
              type="button"
              data-action="increase-quantity"
              data-product-id="${product.id}"
              aria-label="Rrite sasine"
            >
              +
            </button>
          </div>
        </div>
      </div>
      <div class="saved-product-actions">
        <button class="product-action-button cart-action active" type="button" data-action="remove" data-product-id="${product.id}">
          ${cartIcon()}
          <span>Hiqe nga cart</span>
        </button>
      </div>
    </article>
  `;
}


function renderOrdersEmptyState(message) {
  return `
    <section class="card account-section orders-empty-card">
      <h2>${escapeHtml(message)}</h2>
    </section>
  `;
}


function renderBusinessProfileEmptyState(message) {
  return `
    <div class="business-public-empty-state">
      <h1>${escapeHtml(message)}</h1>
    </div>
  `;
}


function renderBusinessProfileHero(business, currentUser) {
  const businessName = String(business?.businessName || "").trim() || "Biznes";
  const logoPath = String(business?.logoPath || "").trim();
  const description = String(business?.businessDescription || "").trim() || "Ky biznes ende nuk ka shtuar pershkrim.";
  const city = String(business?.city || "").trim() || "-";
  const addressLine = String(business?.addressLine || "").trim() || "-";
  const phoneNumber = String(business?.phoneNumber || "").trim() || "-";
  const ownerEmail = String(business?.ownerEmail || "").trim();
  const followersCount = Math.max(0, Number(business?.followersCount) || 0);
  const productsCount = Math.max(0, Number(business?.productsCount) || 0);
  const initials = getBusinessInitials(businessName);
  const canFollow = !currentUser || !(currentUser.role === "business" && Number(currentUser.id) === Number(business?.userId));
  const followLabel = business?.isFollowed ? "Following" : "Follow";
  const messageHref = ownerEmail
    ? `mailto:${ownerEmail}?subject=${encodeURIComponent(`Pershendetje ${businessName}`)}`
    : phoneNumber && phoneNumber !== "-"
      ? `tel:${phoneNumber.replace(/\s+/g, "")}`
      : "#";

  return `
    <div class="business-public-hero-layout">
      <div class="business-public-branding">
        <div class="business-public-logo-shell">
          ${
            logoPath
              ? `<img class="business-public-logo" src="${escapeAttribute(logoPath)}" alt="${escapeAttribute(businessName)}">`
              : `<span class="business-public-logo-fallback">${escapeHtml(initials)}</span>`
          }
        </div>
        <div class="business-public-copy">
          <p class="section-label">Biznes partner</p>
          <h1>${escapeHtml(businessName)}</h1>
          <p class="section-text">${escapeHtml(description)}</p>
        </div>
      </div>

      <div class="business-public-actions">
        <button
          class="nav-action ${business?.isFollowed ? "nav-action-secondary" : "nav-action-primary"} business-follow-button"
          type="button"
          data-business-follow-button
          ${canFollow ? "" : "disabled"}
        >
          ${escapeHtml(followLabel)}
        </button>
        <a
          class="nav-action nav-action-secondary business-message-button${messageHref === "#" ? " is-disabled" : ""}"
          href="${escapeAttribute(messageHref)}"
          ${messageHref === "#" ? 'aria-disabled="true" tabindex="-1"' : ""}
        >
          Message
        </a>
      </div>

      <div class="business-public-stats">
        <div class="summary-chip">
          <span>Produktet publike</span>
          <strong>${escapeHtml(String(productsCount))}</strong>
        </div>
        <div class="summary-chip">
          <span>Followers</span>
          <strong>${escapeHtml(String(followersCount))}</strong>
        </div>
        <div class="summary-chip">
          <span>Qyteti</span>
          <strong>${escapeHtml(city)}</strong>
        </div>
        <div class="summary-chip">
          <span>Telefoni</span>
          <strong>${escapeHtml(phoneNumber)}</strong>
        </div>
        <div class="summary-chip">
          <span>Adresa</span>
          <strong>${escapeHtml(addressLine)}</strong>
        </div>
        <div class="summary-chip">
          <span>Kontakti</span>
          <strong>${escapeHtml(ownerEmail || "Kontakto me telefon")}</strong>
        </div>
      </div>
    </div>
  `;
}


function renderUserOrderCard(order) {
  const items = Array.isArray(order?.items) ? order.items : [];
  const addressLine = String(order?.addressLine || "").trim() || "-";
  const city = String(order?.city || "").trim() || "-";
  const country = String(order?.country || "").trim() || "-";
  const zipCode = String(order?.zipCode || "").trim() || "-";
  const phoneNumber = String(order?.phoneNumber || "").trim() || "-";

  return `
    <article class="card order-card">
      <div class="order-card-top">
        <div>
          <p class="section-label">Porosia #${escapeHtml(String(order?.id || "-"))}</p>
          <h2>${escapeHtml(formatOrderStatusLabel(order?.status))}</h2>
        </div>
        <div class="order-card-meta">
          <span>${escapeHtml(formatPaymentMethodLabel(order?.paymentMethod))}</span>
          <strong>${escapeHtml(formatDateLabel(order?.createdAt || ""))}</strong>
        </div>
      </div>

      <div class="order-summary-chips">
        <div class="summary-chip">
          <span>Produktet</span>
          <strong>${escapeHtml(String(order?.totalItems || 0))}</strong>
        </div>
        <div class="summary-chip">
          <span>Shuma totale</span>
          <strong>${escapeHtml(formatPrice(order?.totalPrice || 0))}</strong>
        </div>
      </div>

      <div class="order-card-body">
        <div class="order-items-list">
          ${items.map((item) => renderOrderItemCard(item)).join("")}
        </div>

        <aside class="order-address-card">
          <p class="section-label">Adresa e dergeses</p>
          <div class="order-address-grid">
            <div class="summary-chip">
              <span>Adresa</span>
              <strong>${escapeHtml(addressLine)}</strong>
            </div>
            <div class="summary-chip">
              <span>Qyteti</span>
              <strong>${escapeHtml(city)}</strong>
            </div>
            <div class="summary-chip">
              <span>Shteti</span>
              <strong>${escapeHtml(country)}</strong>
            </div>
            <div class="summary-chip">
              <span>Zip code</span>
              <strong>${escapeHtml(zipCode)}</strong>
            </div>
            <div class="summary-chip">
              <span>Numri i telefonit</span>
              <strong>${escapeHtml(phoneNumber)}</strong>
            </div>
          </div>
        </aside>
      </div>
    </article>
  `;
}


function renderBusinessOrderCard(order) {
  const items = Array.isArray(order?.items) ? order.items : [];
  const addressLine = String(order?.addressLine || "").trim() || "-";
  const city = String(order?.city || "").trim() || "-";
  const country = String(order?.country || "").trim() || "-";
  const zipCode = String(order?.zipCode || "").trim() || "-";
  const phoneNumber = String(order?.phoneNumber || "").trim() || "-";
  const customerName = String(order?.customerName || "").trim() || "Klient";
  const customerEmail = String(order?.customerEmail || "").trim() || "-";

  return `
    <article class="card order-card business-order-card">
      <div class="order-card-top">
        <div>
          <p class="section-label">Porosia #${escapeHtml(String(order?.id || "-"))}</p>
          <h2>${escapeHtml(customerName)}</h2>
          <p class="section-text">${escapeHtml(customerEmail)}</p>
        </div>
        <div class="order-card-meta">
          <span>${escapeHtml(formatPaymentMethodLabel(order?.paymentMethod))}</span>
          <strong>${escapeHtml(formatDateLabel(order?.createdAt || ""))}</strong>
        </div>
      </div>

      <div class="order-card-body">
        <div class="order-items-list">
          ${items.map((item) => renderOrderItemCard(item, { showBusinessName: false })).join("")}
        </div>

        <aside class="order-address-card">
          <p class="section-label">Informacionet e pranimit</p>
          <div class="order-address-grid">
            <div class="summary-chip">
              <span>Adresa</span>
              <strong>${escapeHtml(addressLine)}</strong>
            </div>
            <div class="summary-chip">
              <span>Qyteti</span>
              <strong>${escapeHtml(city)}</strong>
            </div>
            <div class="summary-chip">
              <span>Shteti</span>
              <strong>${escapeHtml(country)}</strong>
            </div>
            <div class="summary-chip">
              <span>Zip code</span>
              <strong>${escapeHtml(zipCode)}</strong>
            </div>
            <div class="summary-chip">
              <span>Numri i telefonit</span>
              <strong>${escapeHtml(phoneNumber)}</strong>
            </div>
            <div class="summary-chip">
              <span>Shuma e porosise</span>
              <strong>${escapeHtml(formatPrice(order?.totalPrice || 0))}</strong>
            </div>
          </div>
        </aside>
      </div>
    </article>
  `;
}


function renderOrderItemCard(item, options = {}) {
  const imagePath = String(item?.imagePath || "").trim();
  const title = String(item?.title || "").trim() || "Produkt";
  const description = String(item?.description || "").trim();
  const quantity = Math.max(1, Number(item?.quantity) || 1);
  const details = [
    item?.productType ? formatProductTypeLabel(item.productType) : "",
    item?.size ? `Madhesia: ${item.size}` : "",
    item?.color ? `Ngjyra: ${formatProductColorLabel(item.color)}` : "",
  ].filter(Boolean);
  const businessName = String(item?.businessName || "").trim();

  return `
    <article class="order-item-card">
      <div class="order-item-image-shell">
        ${imagePath
          ? `<img class="order-item-image" src="${escapeAttribute(imagePath)}" alt="${escapeAttribute(title)}">`
          : `<div class="order-item-image-fallback">${escapeHtml(title.charAt(0).toUpperCase() || "P")}</div>`}
      </div>
      <div class="order-item-copy">
        <p class="order-item-label">${escapeHtml(formatCategoryLabel(item?.category || ""))}</p>
        <h3>${escapeHtml(title)}</h3>
        ${description ? `<p class="order-item-description">${escapeHtml(description)}</p>` : ""}
        ${businessName && options.showBusinessName !== false ? `<p class="order-item-business">Biznesi: <strong>${escapeHtml(businessName)}</strong></p>` : ""}
        <div class="product-detail-tags product-detail-tags-saved">
          ${details.map((detail) => `<span class="product-detail-tag">${escapeHtml(detail)}</span>`).join("")}
        </div>
      </div>
      <div class="order-item-pricing">
        <span>${escapeHtml(formatPrice(item?.unitPrice || 0))}</span>
        <strong>Sasia: ${escapeHtml(String(quantity))}</strong>
        <strong>${escapeHtml(formatPrice(item?.totalPrice || 0))}</strong>
      </div>
    </article>
  `;
}


function formatPrice(value) {
  const number = Number(value);
  if (Number.isNaN(number)) {
    return "€0";
  }

  return `€${number.toFixed(2).replace(/\.?0+$/, "")}`;
}


function formatCategoryLabel(category) {
  const labels = {
    "clothing-men": "Veshje per meshkuj",
    "clothing-women": "Veshje per femra",
    "clothing-kids": "Veshje per femije",
    "cosmetics-men": "Kozmetik per meshkuj",
    "cosmetics-women": "Kozmetik per femra",
    "cosmetics-kids": "Kozmetik per femije",
    pets: "Kafshet shtepiake",
    agriculture: "Bujqesi",
    medicine: "Barnat",
    home: "Shtepi",
    sport: "Sport",
    technology: "Teknologji",
  };

  return labels[category] || humanizeSlug(category);
}


function getCategoryUrl(category) {
  const urls = {
    "clothing-men": "/kerko?category=clothing-men",
    "clothing-women": "/kerko?category=clothing-women",
    "clothing-kids": "/kerko?category=clothing-kids",
    "cosmetics-men": "/kerko?category=cosmetics-men",
    "cosmetics-women": "/kerko?category=cosmetics-women",
    "cosmetics-kids": "/kerko?category=cosmetics-kids",
    pets: "/kafshet-shtepiake",
    agriculture: "/#bujqesi",
    medicine: "/#barnat",
    home: "/kerko?category=home",
    sport: "/kerko?category=sport",
    technology: "/kerko?category=technology",
  };

  return urls[category] || "/";
}


function getProductDetailUrl(productId) {
  return `/produkti?id=${encodeURIComponent(productId)}`;
}


function getBusinessProfileUrl(businessId) {
  return `/profili-biznesit?id=${encodeURIComponent(businessId)}`;
}


function getProductImageGallery(product) {
  const gallery = [];
  const rawGallery = Array.isArray(product?.imageGallery) ? product.imageGallery : [];

  rawGallery.forEach((path) => {
    const normalizedPath = String(path || "").trim();
    if (normalizedPath && !gallery.includes(normalizedPath)) {
      gallery.push(normalizedPath);
    }
  });

  const coverImage = String(product?.imagePath || "").trim();
  if (coverImage && !gallery.includes(coverImage)) {
    gallery.unshift(coverImage);
  }

  return gallery;
}


function getSafeGalleryIndex(index, totalImages) {
  const total = Number(totalImages);
  if (!Number.isFinite(total) || total <= 0) {
    return 0;
  }

  const current = Number(index);
  if (!Number.isFinite(current) || current < 0) {
    return 0;
  }

  return Math.min(total - 1, Math.trunc(current));
}


function formatProductTypeLabel(productType) {
  const labels = {
    clothing: "Veshje",
    cream: "Kremera",
    food: "Ushqim",
    tools: "Vegla",
    other: "Tjera",
    tshirt: "Maica",
    undershirt: "Maica e brendshme",
    pants: "Pantallona",
    hoodie: "Duks",
    turtleneck: "Rollke",
    jacket: "Jakne",
    underwear: "Te brendshme",
    pajamas: "Pixhama",
    perfumes: "Parfume",
    hygiene: "Higjiena",
    creams: "Kremerat",
    makeup: "Makup",
    nails: "Thonjet",
    "hair-colors": "Ngjyrat e flokeve",
    "kids-care": "Kujdes per femije",
    "room-decor": "Dekorim per dhome",
    "bathroom-items": "Pjeset per banjo",
    "bedroom-items": "Pjeset per dhome te gjumit",
    "kids-room-items": "Pjese per dhomat e femijeve",
    "sports-equipment": "Pajisje sportive",
    sportswear: "Veshje sportive",
    "sports-accessories": "Aksesor sportiv",
    "phone-cases": "Mbrojtese per telefon",
    headphones: "Ndegjuesit",
    "phone-parts": "Pjese per telefon",
    "phone-accessories": "Aksesor te telefonave",
  };

  return labels[productType] || humanizeSlug(productType);
}


function formatProductColorLabel(color) {
  const labels = {
    bardhe: "Bardhe",
    zeze: "Zeze",
    gri: "Gri",
    beige: "Beige",
    kafe: "Kafe",
    kuqe: "Kuqe",
    roze: "Roze",
    vjollce: "Vjollce",
    blu: "Blu",
    gjelber: "Gjelber",
    verdhe: "Verdhe",
    portokalli: "Portokalli",
    "shume-ngjyra": "Shume ngjyra",
  };

  return labels[color] || color;
}


function humanizeSlug(value) {
  return String(value || "")
    .replace(/-/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .replace(/\b\w/g, (character) => character.toUpperCase());
}


function getBusinessInitials(value) {
  const parts = String(value || "")
    .trim()
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2);

  if (parts.length === 0) {
    return "GL";
  }

  return parts
    .map((part) => part.charAt(0).toUpperCase())
    .join("");
}


function formatStockQuantity(value) {
  const number = Number(value);
  if (!Number.isFinite(number)) {
    return "0";
  }

  return `${Math.max(0, Math.trunc(number))} cope`;
}


function formatRoleLabel(role) {
  const labels = {
    admin: "Admin",
    business: "Biznes",
    client: "User",
  };

  return labels[role] || "User";
}


function formatPaymentMethodLabel(paymentMethod) {
  const labels = {
    cash: "Pages cash",
    "card-online": "Pages me kartel online",
  };

  return labels[String(paymentMethod || "").trim()] || "Pagesa";
}


function formatOrderStatusLabel(status) {
  const labels = {
    confirmed: "Porosia u konfirmua",
    pending: "Ne pritje",
  };

  return labels[String(status || "").trim()] || "Porosia";
}


function formatDateLabel(value) {
  if (!value) {
    return "-";
  }

  const parsedDate = new Date(String(value).replace(" ", "T"));
  if (Number.isNaN(parsedDate.getTime())) {
    return String(value);
  }

  return parsedDate.toLocaleDateString("sq-AL", {
    year: "numeric",
    month: "long",
    day: "numeric",
  });
}


async function fetchCurrentUserOptional() {
  try {
    const { response, data } = await requestJson("/api/me");
    if (!response.ok || !data.ok || !data.user) {
      return null;
    }

    return data.user;
  } catch (error) {
    console.error(error);
    return null;
  }
}


function getProfileValuesFromUser(user) {
  const firstName = String(user.firstName || "").trim();
  const lastName = String(user.lastName || "").trim();
  const profileImagePath = String(user.profileImagePath || "").trim();

  if (firstName || lastName) {
    return {
      firstName,
      lastName,
      birthDate: String(user.birthDate || ""),
      gender: String(user.gender || ""),
      profileImagePath,
    };
  }

  const nameParts = String(user.fullName || "").trim().split(/\s+/).filter(Boolean);
  return {
    firstName: nameParts[0] || "",
    lastName: nameParts.slice(1).join(" "),
    birthDate: String(user.birthDate || ""),
    gender: String(user.gender || ""),
    profileImagePath,
  };
}


function normalizeAddress(address) {
  return {
    addressLine: String(address?.addressLine || ""),
    city: String(address?.city || ""),
    country: String(address?.country || ""),
    zipCode: String(address?.zipCode || ""),
    phoneNumber: String(address?.phoneNumber || ""),
  };
}


function createEmptyAddress() {
  return {
    addressLine: "",
    city: "",
    country: "",
    zipCode: "",
    phoneNumber: "",
  };
}


function persistCheckoutAddressDraft(address) {
  try {
    window.sessionStorage.setItem(
      CHECKOUT_ADDRESS_DRAFT_KEY,
      JSON.stringify(normalizeAddress(address)),
    );
  } catch (error) {
    console.error(error);
  }
}


function readCheckoutAddressDraft() {
  try {
    const rawValue = window.sessionStorage.getItem(CHECKOUT_ADDRESS_DRAFT_KEY);
    if (!rawValue) {
      return null;
    }

    const parsedValue = JSON.parse(rawValue);
    return normalizeAddress(parsedValue);
  } catch (error) {
    console.error(error);
    return null;
  }
}


function persistCheckoutPaymentMethod(method) {
  try {
    window.sessionStorage.setItem(
      CHECKOUT_PAYMENT_METHOD_KEY,
      String(method || "").trim(),
    );
  } catch (error) {
    console.error(error);
  }
}


function readCheckoutPaymentMethod() {
  try {
    return String(window.sessionStorage.getItem(CHECKOUT_PAYMENT_METHOD_KEY) || "").trim();
  } catch (error) {
    console.error(error);
    return "";
  }
}


function persistCheckoutSelectedCartIds(ids) {
  try {
    window.sessionStorage.setItem(
      CHECKOUT_SELECTED_CART_IDS_KEY,
      JSON.stringify(Array.isArray(ids) ? ids.map((id) => Number(id)).filter(Number.isFinite) : []),
    );
  } catch (error) {
    console.error(error);
  }
}


function readCheckoutSelectedCartIds() {
  try {
    const rawValue = window.sessionStorage.getItem(CHECKOUT_SELECTED_CART_IDS_KEY);
    if (!rawValue) {
      return [];
    }

    const parsedValue = JSON.parse(rawValue);
    if (!Array.isArray(parsedValue)) {
      return [];
    }

    return parsedValue
      .map((id) => Number(id))
      .filter((id) => Number.isFinite(id) && id > 0);
  } catch (error) {
    console.error(error);
    return [];
  }
}


function persistOrderConfirmationMessage(message) {
  try {
    const nextValue = String(message || "").trim();
    if (!nextValue) {
      return;
    }

    window.sessionStorage.setItem(ORDER_CONFIRMATION_MESSAGE_KEY, nextValue);
  } catch (error) {
    console.error(error);
  }
}


function consumeOrderConfirmationMessage() {
  try {
    const value = String(window.sessionStorage.getItem(ORDER_CONFIRMATION_MESSAGE_KEY) || "").trim();
    if (!value) {
      return "";
    }

    window.sessionStorage.removeItem(ORDER_CONFIRMATION_MESSAGE_KEY);
    return value;
  } catch (error) {
    console.error(error);
    return "";
  }
}


function clearCheckoutFlowState() {
  try {
    window.sessionStorage.removeItem(CHECKOUT_ADDRESS_DRAFT_KEY);
    window.sessionStorage.removeItem(CHECKOUT_PAYMENT_METHOD_KEY);
    window.sessionStorage.removeItem(CHECKOUT_SELECTED_CART_IDS_KEY);
  } catch (error) {
    console.error(error);
  }
}


function updateNavigationUserInfo(user) {
  const fullName = String(user.fullName || "").trim();
  const email = String(user.email || "").trim();
  const nameElements = document.querySelectorAll(".nav-user-name, .nav-user-panel-name");
  const emailElements = document.querySelectorAll(".nav-user-panel-email");

  nameElements.forEach((element) => {
    element.textContent = fullName || "-";
  });

  emailElements.forEach((element) => {
    element.textContent = email || "-";
  });
}


async function fetchProtectedCollection(url) {
  try {
    const { response, data } = await requestJson(url);
    if (!response.ok || !data.ok) {
      return [];
    }

    return Array.isArray(data.items) ? data.items : [];
  } catch (error) {
    console.error(error);
    return [];
  }
}


function heartIcon() {
  return `
    <svg class="product-action-icon" viewBox="0 0 24 24" aria-hidden="true">
      <path d="M12 20.4 4.9 13.8a4.8 4.8 0 0 1 6.8-6.8l.3.3.3-.3a4.8 4.8 0 1 1 6.8 6.8Z"></path>
    </svg>
  `;
}


function searchIcon() {
  return `
    <svg class="nav-icon" viewBox="0 0 24 24" aria-hidden="true">
      <circle cx="11" cy="11" r="6.5"></circle>
      <path d="M16 16l5 5"></path>
    </svg>
  `;
}


function chevronDownIcon() {
  return `
    <svg class="nav-chevron" viewBox="0 0 24 24" aria-hidden="true">
      <path d="M7 10.5 12 15.5l5-5"></path>
    </svg>
  `;
}


function shoppingBagIcon() {
  return `
    <svg class="app-loader-icon" viewBox="0 0 24 24" aria-hidden="true">
      <path d="M6 9h12l-1 10.2a1 1 0 0 1-1 .8H8a1 1 0 0 1-1-.8Z"></path>
      <path d="M9 10V8a3 3 0 1 1 6 0v2"></path>
    </svg>
  `;
}


function loaderCartIcon() {
  return `
    <svg class="app-loader-icon" viewBox="0 0 24 24" aria-hidden="true">
      <path d="M3 5h2l2.1 9.1a1 1 0 0 0 1 .8h8.8a1 1 0 0 0 1-.8L20 8H7.2"></path>
      <circle cx="10" cy="19" r="1.4"></circle>
      <circle cx="18" cy="19" r="1.4"></circle>
    </svg>
  `;
}


function packageIcon() {
  return `
    <svg class="app-loader-icon" viewBox="0 0 24 24" aria-hidden="true">
      <path d="M12 3 5 6.8v10.4L12 21l7-3.8V6.8Z"></path>
      <path d="M12 3v18"></path>
      <path d="M5 6.8 12 11l7-4.2"></path>
    </svg>
  `;
}


function cartIcon() {
  return `
    <svg class="product-action-icon" viewBox="0 0 24 24" aria-hidden="true">
      <path d="M3 5h2l2.1 9.1a1 1 0 0 0 1 .8h8.8a1 1 0 0 0 1-.8L20 8H7.2"></path>
      <circle cx="10" cy="19" r="1.4"></circle>
      <circle cx="18" cy="19" r="1.4"></circle>
    </svg>
  `;
}


function eyeIcon() {
  return `
    <svg class="product-action-icon" viewBox="0 0 24 24" aria-hidden="true">
      <path d="M2 12s3.8-6 10-6 10 6 10 6-3.8 6-10 6-10-6-10-6Z"></path>
      <circle cx="12" cy="12" r="3.2"></circle>
    </svg>
  `;
}


function eyeOffIcon() {
  return `
    <svg class="product-action-icon" viewBox="0 0 24 24" aria-hidden="true">
      <path d="M3 3l18 18"></path>
      <path d="M10.6 6.3A11.8 11.8 0 0 1 12 6c6.2 0 10 6 10 6a18 18 0 0 1-3.4 3.9"></path>
      <path d="M6.7 6.8C3.8 8.7 2 12 2 12s3.8 6 10 6c1.7 0 3.2-.4 4.6-1"></path>
      <path d="M9.9 9.9a3 3 0 0 0 4.2 4.2"></path>
    </svg>
  `;
}


function escapeHtml(value) {
  return String(value).replace(/[&<>"']/g, (character) => {
    const replacements = {
      "&": "&amp;",
      "<": "&lt;",
      ">": "&gt;",
      '"': "&quot;",
      "'": "&#39;",
    };

    return replacements[character] || character;
  });
}


function escapeAttribute(value) {
  return escapeHtml(value);
}
