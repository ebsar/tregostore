<script setup>
import { computed, onBeforeUnmount, onMounted, reactive, ref, watch } from "vue";
import { RouterLink, useRouter } from "vue-router";
import HomeMarketplaceCard from "../components/HomeMarketplaceCard.vue";
import ProductCard from "../components/ProductCard.vue";
import { useInfiniteScrollSentinel } from "../composables/useInfiniteScrollSentinel";
import { fetchProtectedCollection, requestJson, resolveApiMessage } from "../lib/api";
import { PRODUCT_PAGE_SECTION_OPTIONS, deriveSectionFromCategory } from "../lib/product-catalog";
import { getProductsPageSize, subscribeProductsPageSize } from "../lib/product-pagination";
import { readRecentlyViewedProducts } from "../lib/recently-viewed";
import {
  formatCategoryLabel,
  formatPrice,
  getBusinessInitials,
  getBusinessProfileUrl,
  getProductDetailUrl,
  hasProductAvailableStock,
  PRIMARY_NAVIGATION,
} from "../lib/shop";
import {
  compareState,
  ensureCompareItemsLoaded,
  toggleComparedProduct,
} from "../stores/product-compare";
import { appState, ensureSessionLoaded, markRouteReady, setCartItems } from "../stores/app-state";

const router = useRouter();
const products = ref([]);
const homeCatalogProducts = ref([]);
const businesses = ref([]);
const recentlyViewedProducts = ref([]);
const newsletterEmail = ref("");
const businessProfile = ref(null);
const businessProducts = ref([]);
const wishlistIds = ref([]);
const cartIds = ref([]);
const busyWishlistIds = ref([]);
const busyCartIds = ref([]);
const totalProductsCount = ref(0);
const hasMoreProducts = ref(false);
const loadingMoreProducts = ref(false);
const filtersVisible = ref(false);
const statusText = ref("Po ngarkohen produktet publike te TREGO.");
const productsPageSize = ref(getProductsPageSize());
const availableFilters = ref(createEmptyProductFacets());
const filters = reactive({
  pageSection: "",
  category: "",
  productType: "",
  size: "",
  color: "",
  sort: "",
});
const ui = reactive({
  message: "",
  type: "",
});
const businessUi = reactive({
  message: "",
  type: "",
});
let stopProductsPageSizeSubscription = () => {};
const isBusinessUser = computed(() => appState.user?.role === "business");
const homeAnnouncementItems = [
  {
    title: "Dergese nga biznese lokale",
    description: "Porosite nga disa kategori ne nje marketplace te vetem.",
  },
  {
    title: "Pagesa te sigurta",
    description: "Checkout i paster, transparent dhe i gatshem per shitje.",
  },
  {
    title: "Stok real",
    description: "Produktet shfaqen vetem kur jane vertet te disponueshme.",
  },
];
const homeTrustCards = [
  {
    title: "Dergese e qarte",
    copy: "Opsione transporti dhe pickup sipas biznesit, me info te sakte ne checkout.",
  },
  {
    title: "Kthime te kontrolluara",
    copy: "Rrjedhe me rimbursim dhe konfirmim te porosive ne menyre profesionale.",
  },
  {
    title: "Pagese e sigurt",
    copy: "Eksperience e paster blerjeje me checkout te ndertuar per besim.",
  },
  {
    title: "Komunikim direkt",
    copy: "Mesazhe, njoftime dhe status i porosise ne nje vend te vetem.",
  },
];
const homeNewsletterBenefits = [
  "Oferta reale nga produktet e publikuara",
  "Njoftime kur dalin artikuj te rinj",
  "Drop-et dhe zbritjet me te mira te javes",
];
const HOME_CATEGORY_ICON_MAP = {
  clothing: {
    tone: "fashion",
    paths: [
      "M7 6.8 10 4h4l3 2.8V10a2.2 2.2 0 0 1-2.2 2.2H15v6.8l-3-1.8-3 1.8V12.2H9.2A2.2 2.2 0 0 1 7 10Z",
    ],
  },
  cosmetics: {
    tone: "beauty",
    paths: [
      "M10 4h4v4.2l1.7 2.2A4.4 4.4 0 0 1 16.6 13v4.4A2.6 2.6 0 0 1 14 20H10a2.6 2.6 0 0 1-2.6-2.6V13a4.4 4.4 0 0 1 .9-2.6L10 8.2Z",
      "M10 6h4",
    ],
  },
  home: {
    tone: "home",
    paths: [
      "M4.8 10.4 12 4.8l7.2 5.6v7a1.6 1.6 0 0 1-1.6 1.6H6.4a1.6 1.6 0 0 1-1.6-1.6Z",
      "M9.5 19v-5.4h5V19",
    ],
  },
  sport: {
    tone: "sport",
    paths: [
      "M6 9.2h2.2l1.6 1.6h4.4l1.6-1.6H18v5.6h-2.2l-1.6-1.6H9.8L8.2 14.8H6Z",
    ],
  },
  technology: {
    tone: "tech",
    paths: [
      "M4.5 6.5A1.5 1.5 0 0 1 6 5h12a1.5 1.5 0 0 1 1.5 1.5V14A1.5 1.5 0 0 1 18 15.5H6A1.5 1.5 0 0 1 4.5 14Z",
      "M9 19h6",
      "M12 15.5V19",
    ],
  },
};

const businessDisplayName = computed(() =>
  String(
    businessProfile.value?.businessName
    || appState.user?.businessName
    || appState.user?.fullName
    || "Biznesi yt",
  ).trim(),
);

const businessDescription = computed(() =>
  String(businessProfile.value?.businessDescription || "").trim()
  || "Nga kjo faqe ke qasje direkte te profili yt, artikujt e biznesit dhe veprimet kryesore.",
);

const businessPublicProfileUrl = computed(() =>
  String(businessProfile.value?.publicProfileUrl || appState.user?.businessProfileUrl || "").trim(),
);

const businessFollowersCount = computed(() => Math.max(0, Number(businessProfile.value?.followersCount || 0)));
const businessOrdersCount = computed(() => Math.max(0, Number(businessProfile.value?.ordersCount || 0)));
const businessProductsCount = computed(() =>
  Math.max(
    0,
    businessProducts.value.length || Number(businessProfile.value?.productsCount || 0),
  ),
);
const groupedPageSections = new Set(["clothing", "cosmetics"]);
const { target: loadMoreSentinel, supportsAutoLoad } = useInfiniteScrollSentinel({
  enabled: computed(() => !isBusinessUser.value),
  hasMore: hasMoreProducts,
  loading: loadingMoreProducts,
  onLoadMore: loadMoreProducts,
});

const availablePageSectionOptions = computed(() => availableFilters.value.pageSections);
const availableCategoryOptions = computed(() =>
  !filters.pageSection || !groupedPageSections.has(filters.pageSection)
    ? []
    : availableFilters.value.categories.filter((option) =>
        String(option.pageSection || "") === filters.pageSection,
      ),
);
const availableProductTypeOptions = computed(() =>
  !filters.pageSection
    ? []
    : availableFilters.value.productTypes.filter((option) => {
        const matchesSection = String(option.pageSection || "") === filters.pageSection;
        const hasNestedCategories = availableCategoryOptions.value.length > 0;
        const matchesCategory = !hasNestedCategories || String(option.category || "") === filters.category;
        return matchesSection && matchesCategory;
      }),
);
const availableSizeOptions = computed(() => availableFilters.value.sizes);
const availableColorOptions = computed(() => availableFilters.value.colors);
const shouldShowProductTypeFilter = computed(() => {
  if (!filters.pageSection || availableProductTypeOptions.value.length === 0) {
    return false;
  }

  return availableCategoryOptions.value.length === 0 || Boolean(filters.category);
});
const shouldRequestFacets = computed(() =>
  filtersVisible.value
  || Boolean(filters.pageSection || filters.category || filters.productType || filters.size || filters.color),
);

const filteredProducts = computed(() => {
  let nextProducts = [...products.value];

  if (filters.sort === "price-asc") {
    nextProducts.sort((left, right) => Number(left.price || 0) - Number(right.price || 0));
  } else if (filters.sort === "price-desc") {
    nextProducts.sort((left, right) => Number(right.price || 0) - Number(left.price || 0));
  }

  return nextProducts;
});

const marketplaceProducts = computed(() =>
  buildUniqueProducts(
    [...homeCatalogProducts.value, ...products.value].filter((product) => hasProductAvailableStock(product)),
    24,
  ),
);

const visibleRecentlyViewedProducts = computed(() =>
  recentlyViewedProducts.value.filter((product) => hasProductAvailableStock(product)).slice(0, 4),
);
const comparedProductIds = computed(() =>
  compareState.items
    .map((item) => Number(item.id || item.productId || 0))
    .filter((id) => Number.isFinite(id) && id > 0),
);
const curatedProductsDisplay = computed(() => formatMarketplaceMetric(totalProductsCount.value, 250));
const localBrandsDisplay = computed(() => formatMarketplaceMetric(businesses.value.length, Number.POSITIVE_INFINITY));
const quickNavigationItems = computed(() =>
  PRIMARY_NAVIGATION.slice(0, 5).map((item) => ({
    ...item,
    icon: HOME_CATEGORY_ICON_MAP[item.key] || HOME_CATEGORY_ICON_MAP.clothing,
  })),
);
const homeQuickChips = computed(() => {
  const navigationByKey = Object.fromEntries(PRIMARY_NAVIGATION.map((item) => [item.key, item.href]));
  return [
    { label: "New arrivals", type: "scroll", target: "home-marketplace-new-arrivals" },
    { label: "Best sellers", type: "scroll", target: "home-marketplace-best-sellers" },
    { label: "Fashion", type: "route", to: navigationByKey.clothing || "/kerko" },
    { label: "Beauty", type: "route", to: navigationByKey.cosmetics || "/kerko" },
    { label: "Tech", type: "route", to: navigationByKey.technology || "/kerko" },
    { label: "Home", type: "route", to: navigationByKey.home || "/kerko" },
  ];
});
const featuredBusinesses = computed(() => businesses.value.slice(0, 6));
const flashDealProducts = computed(() =>
  buildUniqueProducts(
    [...marketplaceProducts.value]
      .sort((left, right) => {
        const discountDifference = getProductDiscountPercent(right) - getProductDiscountPercent(left);
        if (discountDifference !== 0) {
          return discountDifference;
        }

        return getProductPopularityScore(right) - getProductPopularityScore(left);
      }),
    4,
  ),
);
const bestSellerProducts = computed(() =>
  buildUniqueProducts(
    [...marketplaceProducts.value].sort(
      (left, right) => getProductPopularityScore(right) - getProductPopularityScore(left),
    ),
    4,
  ),
);
const newArrivalProducts = computed(() =>
  buildUniqueProducts(
    [...marketplaceProducts.value].sort((left, right) => getProductDateValue(right) - getProductDateValue(left)),
    4,
  ),
);
const popularNowProducts = computed(() =>
  buildUniqueProducts(
    [
      ...flashDealProducts.value,
      ...bestSellerProducts.value,
      ...newArrivalProducts.value,
      ...marketplaceProducts.value,
    ],
    8,
  ),
);
const heroSpotlightProduct = computed(() =>
  flashDealProducts.value[0]
  || bestSellerProducts.value[0]
  || newArrivalProducts.value[0]
  || marketplaceProducts.value[0]
  || null,
);
const heroMiniProducts = computed(() =>
  buildUniqueProducts(
    marketplaceProducts.value.filter((product) => Number(product.id) !== Number(heroSpotlightProduct.value?.id || 0)),
    2,
  ),
);
const featuredCategoryCards = computed(() => {
  return PRODUCT_PAGE_SECTION_OPTIONS.map((section) => {
    const sectionProducts = marketplaceProducts.value.filter(
      (product) => getProductSectionValue(product) === section.value,
    );
    if (sectionProducts.length === 0) {
      return null;
    }

    const leadProduct = sectionProducts[0];
    const navigationItem = quickNavigationItems.value.find((entry) => entry.key === section.value);

    return {
      ...section,
      href: navigationItem?.href || "/kerko",
      count: sectionProducts.length,
      imagePath: leadProduct.imagePath,
      helper: leadProduct.productType
        ? formatCategoryLabel(leadProduct.productType)
        : "Zgjedhje te kuruara per kete kategori",
    };
  })
    .filter(Boolean)
    .sort((left, right) => right.count - left.count)
    .slice(0, 5);
});
const highestDiscountDisplay = computed(() => {
  const highestDiscount = marketplaceProducts.value.reduce(
    (maximum, product) => Math.max(maximum, getProductDiscountPercent(product)),
    0,
  );
  return highestDiscount > 0 ? `${highestDiscount}%` : "Oferta";
});
const homeTestimonials = computed(() => {
  const businessNames = businesses.value.slice(0, 3).map((business) => business.businessName).filter(Boolean);

  return [
    {
      quote:
        "E gjeta produktin shume me shpejt dhe checkout-i u ndje si nje dyqan i vertete, jo si nje katalog i thjeshte.",
      author: "Arta K.",
      meta: "Kliente nga Prishtina",
    },
    {
      quote:
        "Si biznes lokal, faqja jep me shume besim: produktet dalin bukur, ofertat kuptohen dhe porosite jane me te qarta.",
      author: businessNames[0] || "Biznes partner",
      meta: "Shitje me prezantim me profesional",
    },
    {
      quote:
        "Nga kategorite deri te kartat e produkteve, gjithcka ndihet e paster, e shpejte dhe gati per blerje reale.",
      author: "Bleres i verifikuar",
      meta: businessNames[1] || "Marketplace experience",
    },
  ];
});

const collectionLabel = computed(() => {
  if (!products.value.length) {
    return "Nuk ka produkte publike ende.";
  }

  if (!filters.size && !filters.color && !filters.sort) {
    return totalProductsCount.value > products.value.length
      ? `Po shfaqen ${products.value.length} nga ${totalProductsCount.value} produkte publike te TREGO.`
      : statusText.value;
  }

  return totalProductsCount.value > 0
    ? `Po shfaqen ${filteredProducts.value.length} nga ${products.value.length} produkte te ngarkuara (${totalProductsCount.value} gjithsej) sipas filtrave te zgjedhur.`
    : `Po shfaqen ${filteredProducts.value.length} nga ${products.value.length} produkte sipas filtrave te zgjedhur.`;
});

onMounted(async () => {
  ensureCompareItemsLoaded();
  recentlyViewedProducts.value = readRecentlyViewedProducts();
  stopProductsPageSizeSubscription = subscribeProductsPageSize((nextPageSize) => {
    if (nextPageSize === productsPageSize.value) {
      return;
    }

    productsPageSize.value = nextPageSize;
    if (!isBusinessUser.value) {
      void loadProducts();
    }
  });

  try {
    if (appState.sessionLoaded && appState.user?.role === "business") {
      await Promise.all([loadBusinessProfile(), loadBusinessProducts()]);
      markRouteReady();
      return;
    }

    const publicProductsPromise = loadProducts();
    const homeHighlightsPromise = loadHomeCatalogProducts();
    const publicBusinessesPromise = loadBusinesses();
    void ensureSessionLoaded()
      .then(async (user) => {
        if (user?.role === "business") {
          await Promise.all([loadBusinessProfile(), loadBusinessProducts()]);
          return;
        }

        await refreshCollectionState();
      })
      .catch((error) => {
        console.error(error);
      });

    await Promise.all([publicProductsPromise, homeHighlightsPromise, publicBusinessesPromise]);
    markRouteReady();
  } catch (error) {
    statusText.value = "Produktet nuk u ngarkuan. Provoje perseri pas pak.";
    console.error(error);
    markRouteReady();
  }
});

onBeforeUnmount(() => {
  stopProductsPageSizeSubscription();
});

watch(
  () => appState.catalogRevision,
  async (nextRevision, previousRevision) => {
    if (nextRevision === previousRevision) {
      return;
    }

    if (isBusinessUser.value) {
      await Promise.all([loadBusinessProfile(), loadBusinessProducts()]);
      return;
    }

    await Promise.all([loadProducts(), loadHomeCatalogProducts(), loadBusinesses()]);
  },
);

async function refreshCollectionState() {
  if (!appState.user) {
    wishlistIds.value = [];
    cartIds.value = [];
    return;
  }

  const [wishlistItems, cartItems] = await Promise.all([
    fetchProtectedCollection("/api/wishlist"),
    fetchProtectedCollection("/api/cart"),
  ]);

  wishlistIds.value = wishlistItems.map((item) => item.id);
  cartIds.value = cartItems.map((item) => item.productId || item.id);
  setCartItems(cartItems);
}

async function loadProducts(options = {}) {
  const { append = false, forceFacets = false } = options;
  const offset = append ? products.value.length : 0;
  const includeFacets = !append && (forceFacets || shouldRequestFacets.value);
  const params = new URLSearchParams();
  params.set("limit", String(productsPageSize.value));
  params.set("offset", String(offset));
  if (includeFacets) {
    params.set("includeFacets", "1");
  }
  if (filters.pageSection) {
    params.set("pageSection", filters.pageSection);
  }
  if (filters.category) {
    params.set("category", filters.category);
  }
  if (filters.productType) {
    params.set("productType", filters.productType);
  }
  if (filters.size) {
    params.set("size", filters.size);
  }
  if (filters.color) {
    params.set("color", filters.color);
  }

  const { response, data } = await requestJson(
    `/api/products?${params.toString()}`,
    {},
    { cacheTtlMs: append ? 0 : 15000 },
  );
  if (!response.ok || !data?.ok) {
    statusText.value = resolveApiMessage(data, "Produktet nuk u ngarkuan.");
    if (!append) {
      products.value = [];
      totalProductsCount.value = 0;
      hasMoreProducts.value = false;
      availableFilters.value = createEmptyProductFacets();
    }
    return;
  }

  const nextProducts = Array.isArray(data.products) ? data.products : [];
  const visibleProducts = nextProducts.filter((product) => hasProductAvailableStock(product));
  products.value = append ? [...products.value, ...visibleProducts] : visibleProducts;
  totalProductsCount.value = Number(data.total || products.value.length || 0);
  hasMoreProducts.value = Boolean(data.hasMore);
  if (data.facets) {
    availableFilters.value = normalizeProductFacets(data.facets);
  }
  statusText.value =
    totalProductsCount.value > 0
      ? `Po shfaqen ${products.value.length} nga ${totalProductsCount.value} produkte publike te TREGO.`
      : "Nuk ka produkte publike ende.";
}

async function loadMoreProducts() {
  if (loadingMoreProducts.value || !hasMoreProducts.value) {
    return;
  }

  loadingMoreProducts.value = true;
  try {
    await loadProducts({ append: true });
  } finally {
    loadingMoreProducts.value = false;
  }
}

async function loadBusinesses() {
  const { response, data } = await requestJson("/api/businesses/public", {}, { cacheTtlMs: 30000 });
  if (!response.ok || !data?.ok) {
    return;
  }

  businesses.value = Array.isArray(data.businesses) ? data.businesses : [];
}

async function loadHomeCatalogProducts() {
  const { response, data } = await requestJson(
    "/api/products?limit=24&offset=0",
    {},
    { cacheTtlMs: 30000 },
  );
  if (!response.ok || !data?.ok) {
    homeCatalogProducts.value = [];
    return;
  }

  const nextProducts = Array.isArray(data.products) ? data.products : [];
  homeCatalogProducts.value = nextProducts.filter((product) => hasProductAvailableStock(product));
}

async function loadBusinessProfile() {
  const { response, data } = await requestJson("/api/business-profile");
  if (!response.ok || !data?.ok) {
    businessProfile.value = null;
    businessUi.message = resolveApiMessage(data, "Profili i biznesit nuk u ngarkua.");
    businessUi.type = "error";
    return;
  }

  businessProfile.value = data.profile || null;
  if (!businessProfile.value) {
    businessUi.message = "Plotesoje profilin e biznesit per te filluar me publikimin e artikujve.";
    businessUi.type = "";
    return;
  }

  businessUi.message = "";
  businessUi.type = "";
}

async function loadBusinessProducts() {
  const { response, data } = await requestJson("/api/business/products");
  if (!response.ok || !data?.ok) {
    businessProducts.value = [];
    businessUi.message = resolveApiMessage(data, "Artikujt e biznesit nuk u ngarkuan.");
    businessUi.type = "error";
    return;
  }

  businessProducts.value = Array.isArray(data.products) ? data.products : [];
  if (businessProfile.value) {
    businessUi.message = "";
    businessUi.type = "";
  }
}

function setMessage(message, type = "") {
  ui.message = message;
  ui.type = type;
}

function handleCompare(product) {
  toggleComparedProduct(product);
}

function createEmptyProductFacets() {
  return {
    pageSections: [],
    categories: [],
    productTypes: [],
    sizes: [],
    colors: [],
  };
}

function formatMarketplaceMetric(value, cap) {
  const count = Math.max(0, Math.trunc(Number(value) || 0));
  if (count >= cap) {
    return `${cap}+`;
  }

  return String(count);
}

function normalizeProductFacets(rawFacets) {
  return {
    pageSections: Array.isArray(rawFacets?.pageSections) ? rawFacets.pageSections : [],
    categories: Array.isArray(rawFacets?.categories) ? rawFacets.categories : [],
    productTypes: Array.isArray(rawFacets?.productTypes) ? rawFacets.productTypes : [],
    sizes: Array.isArray(rawFacets?.sizes) ? rawFacets.sizes : [],
    colors: Array.isArray(rawFacets?.colors) ? rawFacets.colors : [],
  };
}

function getProductCompareAtPrice(product) {
  const rawValue = Number(product?.compareAtPrice ?? product?.originalPrice ?? 0);
  const currentPrice = Number(product?.price || 0);
  if (!Number.isFinite(rawValue) || rawValue <= currentPrice) {
    return 0;
  }

  return rawValue;
}

function getProductDiscountPercent(product) {
  const compareAtPrice = getProductCompareAtPrice(product);
  const currentPrice = Number(product?.price || 0);
  if (!compareAtPrice || compareAtPrice <= currentPrice || compareAtPrice <= 0) {
    return 0;
  }

  return Math.max(0, Math.round(((compareAtPrice - currentPrice) / compareAtPrice) * 100));
}

function getProductDateValue(product) {
  const timestamp = Date.parse(String(product?.createdAt || ""));
  if (Number.isNaN(timestamp)) {
    return 0;
  }

  return timestamp;
}

function getProductPopularityScore(product) {
  const buyersCount = Number(product?.buyersCount ?? product?.unitsSold ?? 0) || 0;
  const reviewCount = Number(product?.reviewCount ?? 0) || 0;
  const ratingAverage = Number(product?.averageRating ?? product?.ratingAverage ?? 0) || 0;
  return (buyersCount * 4) + (reviewCount * 2) + ratingAverage;
}

function getProductSectionValue(product) {
  return String(product?.pageSection || deriveSectionFromCategory(product?.category || ""))
    .trim()
    .toLowerCase();
}

function buildUniqueProducts(items, limit = 8) {
  const nextItems = [];
  const seenIds = new Set();

  items.forEach((item) => {
    const productId = Number(item?.id || 0);
    if (!Number.isFinite(productId) || productId <= 0 || seenIds.has(productId)) {
      return;
    }

    seenIds.add(productId);
    nextItems.push(item);
  });

  return nextItems.slice(0, limit);
}

function getShowcaseBadge(product, index = 0) {
  const discountPercent = getProductDiscountPercent(product);
  if (discountPercent > 0) {
    return `-${discountPercent}%`;
  }

  if (index === 0) {
    return "Best Seller";
  }

  if (getProductDateValue(product) > 0) {
    return "New";
  }

  return "Premium";
}

function getShowcaseBadgeTone(product) {
  return getProductDiscountPercent(product) > 0 ? "alert" : "premium";
}

function handleNewsletterSubmit() {
  const nextEmail = String(newsletterEmail.value || "").trim();
  if (!nextEmail) {
    setMessage("Shkruaje email-in tend qe te vazhdosh me ofertat dhe drop-et.", "error");
    return;
  }

  setMessage("Krijo nje llogari per te marre ofertat dhe njoftimet ne email.", "success");
  router.push("/signup");
}

function scrollToMarketplaceSection(sectionId) {
  if (typeof window === "undefined") {
    return;
  }

  const target = document.getElementById(sectionId);
  if (!target) {
    return;
  }

  target.scrollIntoView({ behavior: "smooth", block: "start" });
}

function handlePageSectionChange() {
  filters.category = "";
  filters.productType = "";
  void loadProducts();
}

function handleCategoryChange() {
  filters.productType = "";
  void loadProducts();
}

function handleCatalogFilterChange() {
  void loadProducts();
}

function toggleFiltersPanel() {
  filtersVisible.value = !filtersVisible.value;
  if (filtersVisible.value && availablePageSectionOptions.value.length === 0) {
    void loadProducts({ forceFacets: true });
  }
}

function resetFilters() {
  filters.pageSection = "";
  filters.category = "";
  filters.productType = "";
  filters.size = "";
  filters.color = "";
  filters.sort = "";
  void loadProducts();
}

async function handleWishlist(productId) {
  if (!appState.user) {
    setMessage(
      "Duhet te kyçesh ose te krijosh llogari para se te perdoresh wishlist ose cart.",
      "error",
    );
    return;
  }

  busyWishlistIds.value = [...busyWishlistIds.value, productId];
  const isWishlisted = wishlistIds.value.includes(productId);
  wishlistIds.value = isWishlisted
    ? wishlistIds.value.filter((id) => id !== productId)
    : [...wishlistIds.value, productId];

  const { response, data } = await requestJson("/api/wishlist/toggle", {
    method: "POST",
    body: JSON.stringify({ productId }),
  });

  busyWishlistIds.value = busyWishlistIds.value.filter((id) => id !== productId);

  if (!response.ok || !data?.ok) {
    wishlistIds.value = isWishlisted
      ? [...wishlistIds.value, productId]
      : wishlistIds.value.filter((id) => id !== productId);
    setMessage(resolveApiMessage(data, "Wishlist nuk u perditesua."), "error");
    return;
  }

  wishlistIds.value = Array.isArray(data.items) ? data.items.map((item) => item.id) : [];
  setMessage(data.message || "Produkti u shtua ne shporte.", "success");
  if (!isWishlisted) {
    window.dispatchEvent(new CustomEvent("trego:toast", {
      detail: { message: "Artikulli eshte shtuar ne wishlist." },
    }));
  }
}

async function handleCart(productId) {
  if (!appState.user) {
    setMessage(
      "Duhet te kyçesh ose te krijosh llogari para se te perdoresh wishlist ose cart.",
      "error",
    );
    return;
  }

  const product = [...marketplaceProducts.value, ...products.value]
    .find((entry) => Number(entry.id) === Number(productId));
  if (product?.requiresVariantSelection) {
    router.push(getProductDetailUrl(productId, "/"));
    return;
  }

  busyCartIds.value = [...busyCartIds.value, productId];
  if (!cartIds.value.includes(productId)) {
    cartIds.value = [...cartIds.value, productId];
  }

  const { response, data } = await requestJson("/api/cart/add", {
    method: "POST",
    body: JSON.stringify({ productId }),
  });

  busyCartIds.value = busyCartIds.value.filter((id) => id !== productId);

  if (!response.ok || !data?.ok) {
    cartIds.value = cartIds.value.filter((id) => id !== productId);
    setMessage(resolveApiMessage(data, "Shporta nuk u perditesua."), "error");
    return;
  }

  const items = Array.isArray(data.items) ? data.items : [];
  cartIds.value = items.map((item) => item.productId || item.id);
  setCartItems(items);
  setMessage(data.message || "Produkti u shtua ne shporte.", "success");
}
</script>

<template>
  <section v-if="isBusinessUser" class="collection-page business-home-page" aria-label="Faqja kryesore e biznesit">
    <section class="card business-home-hero">
      <div class="business-home-branding">
        <div class="business-home-logo-shell">
          <img
            v-if="businessProfile?.logoPath"
            class="business-home-logo"
            :src="businessProfile.logoPath"
            :alt="businessDisplayName"
            width="220"
            height="220"
          >
          <span v-else class="business-home-logo-fallback">
            {{ getBusinessInitials(businessDisplayName) }}
          </span>
        </div>

        <div class="business-home-copy">
          <p class="section-label">Business mode</p>
          <h1>{{ businessDisplayName }}</h1>
          <p class="section-text">{{ businessDescription }}</p>
        </div>
      </div>

      <div class="business-home-actions">
        <RouterLink class="nav-action nav-action-primary" to="/biznesi-juaj?view=add-product">
          Shto artikull
        </RouterLink>
        <RouterLink class="nav-action nav-action-secondary" to="/biznesi-juaj">
          Menaxho profilin
        </RouterLink>
        <RouterLink
          v-if="businessPublicProfileUrl"
          class="nav-action nav-action-secondary"
          :to="businessPublicProfileUrl"
        >
          Profili publik
        </RouterLink>
      </div>
    </section>

    <div class="business-home-summary-grid">
      <article class="card business-home-stat">
        <span class="business-home-stat-label">Ndjekesit</span>
        <strong>{{ businessFollowersCount }}</strong>
        <p>Shiko si po rritet interesi per biznesin tend.</p>
      </article>

      <article class="card business-home-stat">
        <span class="business-home-stat-label">Artikujt e tu</span>
        <strong>{{ businessProductsCount }}</strong>
        <p>Te gjitha produktet qe ke publikuar ose ruajtur ne panel.</p>
      </article>

      <article class="card business-home-stat">
        <span class="business-home-stat-label">Porosite</span>
        <strong>{{ businessOrdersCount }}</strong>
        <p>Numri i porosive ku jane perfshire produktet e biznesit tend.</p>
      </article>
    </div>

    <section class="card business-home-contact">
      <div>
        <p class="section-label">Kontaktet</p>
        <h2>Mesazhet dhe ndjekesit</h2>
        <p class="section-text">
          Ketu ke qasje te shpejte te inbox-it te mesazheve dhe profilit publik te biznesit.
        </p>
      </div>

      <div class="business-home-contact-actions">
        <RouterLink class="nav-action nav-action-secondary" to="/mesazhet">
          Hape mesazhet
        </RouterLink>
        <RouterLink
          v-if="businessPublicProfileUrl"
          class="nav-action nav-action-primary"
          :to="businessPublicProfileUrl"
        >
          Shiko ndjekesit
        </RouterLink>
      </div>
    </section>

    <div class="form-message" :class="businessUi.type" role="status" aria-live="polite">
      {{ businessUi.message }}
    </div>

    <section class="business-home-products" aria-label="Produktet e biznesit tend">
      <header class="collection-page-header business-home-products-header">
        <p class="section-label">Produktet e tua</p>
        <h2>Lista e artikujve</h2>
        <p>
          Ne homepage te biznesit shfaqen vetem profili yt, produktet e tua dhe qasja direkte per shtim artikujsh.
        </p>
      </header>

      <section v-if="businessProducts.length > 0" class="pet-products-grid business-home-products-grid">
        <ProductCard
          v-for="product in businessProducts"
          :key="product.id"
          :product="product"
          :show-overlay-actions="false"
          :show-business-name="false"
        />
      </section>

      <div v-else class="collection-empty-state business-home-empty-state">
        Nuk ke artikuj ende. Shto produktin e pare dhe ai do te shfaqet ketu.
      </div>
    </section>

    <section class="card business-home-bottom-cta">
      <div>
        <p class="section-label">Veprimi i shpejte</p>
        <h2>Shto produkte te reja</h2>
        <p class="section-text">
          Kalo direkt te forma e artikullit dhe vazhdo me publikimin e produkteve te biznesit tend.
        </p>
      </div>

      <RouterLink class="hero-cta" to="/biznesi-juaj?view=add-product">
        Shto artikull
      </RouterLink>
    </section>
  </section>

  <section v-else class="collection-page home-marketplace-page" aria-label="Faqja kryesore">
    <section class="home-marketplace-quick-chips" aria-label="Shkurtore te shpejta">
      <template v-for="chip in homeQuickChips" :key="chip.label">
        <button
          v-if="chip.type === 'scroll'"
          class="home-marketplace-quick-chip"
          type="button"
          @click="scrollToMarketplaceSection(chip.target)"
        >
          {{ chip.label }}
        </button>
        <RouterLink
          v-else
          class="home-marketplace-quick-chip"
          :to="chip.to"
        >
          {{ chip.label }}
        </RouterLink>
      </template>
    </section>

    <section class="home-marketplace-announcement" aria-label="Highlights te marketplace-it">
      <article
        v-for="item in homeAnnouncementItems"
        :key="item.title"
        class="home-marketplace-announcement-item"
      >
        <strong>{{ item.title }}</strong>
        <span>{{ item.description }}</span>
      </article>
    </section>

    <section class="home-marketplace-masthead" aria-label="Hyrja kryesore ne marketplace">
      <aside class="home-marketplace-category-rail">
        <header class="home-marketplace-rail-head">
          <p class="section-label">Shop categories</p>
          <h2>Hyr shpejt ne seksionin qe te duhet.</h2>
        </header>

        <nav class="home-marketplace-category-list" aria-label="Navigimi kryesor sipas kategorive">
          <RouterLink
            v-for="item in quickNavigationItems"
            :key="item.key"
            class="home-marketplace-category-link"
            :class="`is-${item.icon.tone}`"
            :to="item.href"
          >
            <span class="home-marketplace-category-icon" :class="`is-${item.icon.tone}`" aria-hidden="true">
              <svg viewBox="0 0 24 24" fill="none">
                <path
                  v-for="path in item.icon.paths"
                  :key="path"
                  :d="path"
                />
              </svg>
            </span>
            <span class="home-marketplace-category-text">{{ item.label }}</span>
            <small>{{ item.groups.length }} hyrje</small>
          </RouterLink>
        </nav>

        <RouterLink class="home-marketplace-category-all" to="/kerko">
          Shiko gjithe katalogun
        </RouterLink>
      </aside>

      <section class="home-marketplace-hero-surface" aria-label="Hero banner i marketplace-it">
        <div class="home-marketplace-hero-copy">
          <p class="home-marketplace-kicker">Marketplace premium per produkte lokale</p>
          <h1>
            Trego i ben produktet reale te duken
            <span>gati per shitje, te pastra dhe te besueshme.</span>
          </h1>
          <p>
            Nje homepage e ndertuar si nje dyqan i vertete online: kategori te qarta, oferta
            reale, karta produktesh me besim dhe hyrje te shpejte drejt checkout-it.
          </p>

          <div class="home-marketplace-hero-actions">
            <RouterLink class="nav-action nav-action-primary" to="/kerko">
              Eksploro produktet
            </RouterLink>
            <RouterLink class="nav-action nav-action-secondary" to="/bizneset-e-regjistruara">
              Shiko markat lokale
            </RouterLink>
          </div>

          <div class="home-marketplace-hero-stats">
            <article class="home-marketplace-stat">
              <strong>{{ curatedProductsDisplay }}</strong>
              <span>Produkte live</span>
            </article>
            <article class="home-marketplace-stat">
              <strong>{{ localBrandsDisplay }}</strong>
              <span>Marka lokale</span>
            </article>
            <article class="home-marketplace-stat">
              <strong>{{ highestDiscountDisplay }}</strong>
              <span>Ulja me e larte</span>
            </article>
          </div>
        </div>

        <div class="home-marketplace-hero-visual">
          <RouterLink
            v-if="heroSpotlightProduct"
            class="home-marketplace-spotlight"
            :to="getProductDetailUrl(heroSpotlightProduct.id, '/')"
          >
            <div class="home-marketplace-spotlight-media">
              <img
                :src="heroSpotlightProduct.imagePath"
                :alt="heroSpotlightProduct.title"
                width="920"
                height="760"
                loading="eager"
                decoding="async"
              >
              <span class="home-marketplace-spotlight-badge">
                {{ getProductDiscountPercent(heroSpotlightProduct) > 0 ? `${getProductDiscountPercent(heroSpotlightProduct)}% OFF` : "Featured pick" }}
              </span>
            </div>

            <div class="home-marketplace-spotlight-copy">
              <p>
                {{ formatCategoryLabel(heroSpotlightProduct.category) }}
                <span v-if="heroSpotlightProduct.businessName">· {{ heroSpotlightProduct.businessName }}</span>
              </p>
              <h2>{{ heroSpotlightProduct.title }}</h2>
              <div class="home-marketplace-spotlight-pricing">
                <strong>{{ formatPrice(heroSpotlightProduct.price) }}</strong>
                <span v-if="getProductCompareAtPrice(heroSpotlightProduct)">
                  {{ formatPrice(getProductCompareAtPrice(heroSpotlightProduct)) }}
                </span>
              </div>
            </div>
          </RouterLink>

          <article v-else class="home-marketplace-spotlight is-placeholder">
            <div class="home-marketplace-spotlight-copy">
              <p>Marketplace spotlight</p>
              <h2>Po ngarkohet vitrini kryesor i faqes.</h2>
              <div class="home-marketplace-spotlight-pricing">
                <strong>—</strong>
              </div>
            </div>
          </article>

          <div v-if="heroMiniProducts.length > 0" class="home-marketplace-mini-strip">
            <RouterLink
              v-for="product in heroMiniProducts"
              :key="`mini-${product.id}`"
              class="home-marketplace-mini-card"
              :to="getProductDetailUrl(product.id, '/')"
            >
              <img
                :src="product.imagePath"
                :alt="product.title"
                width="240"
                height="240"
                loading="lazy"
                decoding="async"
              >
              <div>
                <span>{{ formatCategoryLabel(product.category) }}</span>
                <strong>{{ product.title }}</strong>
                <small>{{ formatPrice(product.price) }}</small>
              </div>
            </RouterLink>
          </div>
        </div>
      </section>

      <aside class="home-marketplace-insight-rail">
        <article class="home-marketplace-insight-card is-alert">
          <p class="section-label">Flash deals</p>
          <strong>{{ highestDiscountDisplay }}</strong>
          <span>Oferta me zbritjen me te forte nga produktet reale te publikuara tani.</span>
          <RouterLink to="/kerko">Shiko ofertat</RouterLink>
        </article>

        <article class="home-marketplace-insight-card">
          <p class="section-label">Trusted checkout</p>
          <strong>Pagesa + transport</strong>
          <span>Porosite llogariten me stok real, shipping dhe rregulla sipas biznesit.</span>
        </article>

        <article class="home-marketplace-insight-card">
          <p class="section-label">Local brands</p>
          <strong>{{ localBrandsDisplay }}</strong>
          <span>Biznese aktive me profile publike, katalog dhe status porosie ne nje vend.</span>
        </article>
      </aside>
    </section>

    <section v-if="featuredCategoryCards.length > 0" class="home-marketplace-section" aria-label="Kategorite e kuruara">
      <header class="home-marketplace-section-head">
        <div>
          <p class="section-label">Featured categories</p>
          <h2>Fillo nga koleksioni qe te pershtatet me shume.</h2>
          <p>Hyrje te shpejta ne seksionet me te forta te marketplace-it, me produkte dhe imazhe reale.</p>
        </div>
        <RouterLink class="home-marketplace-section-link" to="/kerko">Te gjitha kategorite</RouterLink>
      </header>

      <div class="home-marketplace-category-grid">
        <RouterLink
          v-for="category in featuredCategoryCards"
          :key="category.value"
          class="home-marketplace-category-card"
          :to="category.href"
        >
          <div class="home-marketplace-category-media">
            <img
              v-if="category.imagePath"
              :src="category.imagePath"
              :alt="category.label"
              width="560"
              height="420"
              loading="lazy"
              decoding="async"
            >
          </div>
          <div class="home-marketplace-category-copy">
            <span>{{ category.count }} produkte</span>
            <strong>{{ category.label }}</strong>
            <small>{{ category.helper }}</small>
          </div>
        </RouterLink>
      </div>
    </section>

    <section v-if="flashDealProducts.length > 0" class="home-marketplace-section" aria-label="Flash deals">
      <header class="home-marketplace-section-head">
        <div>
          <p class="section-label">Flash deals</p>
          <h2>Ofertat me te mira qe duken qarte dhe shiten me bindje.</h2>
          <p>Karta moderne me cmim aktual, cmim te vjeter, rating dhe qasje direkte drejt shportes.</p>
        </div>
        <RouterLink class="home-marketplace-section-link" to="/kerko">Shiko me shume</RouterLink>
      </header>

      <div class="home-marketplace-products-grid">
        <HomeMarketplaceCard
          v-for="(product, index) in flashDealProducts"
          :key="`flash-${product.id}`"
          :product="product"
          :badge="getShowcaseBadge(product, index)"
          :badge-tone="getShowcaseBadgeTone(product)"
          :cart-busy="busyCartIds.includes(product.id)"
          @cart="handleCart"
        />
      </div>
    </section>

    <section
      v-if="bestSellerProducts.length > 0 || newArrivalProducts.length > 0"
      class="home-marketplace-section home-marketplace-dual-section"
      aria-label="Best sellers dhe new arrivals"
    >
      <article id="home-marketplace-best-sellers" class="home-marketplace-product-column">
        <header class="home-marketplace-column-head">
          <p class="section-label">Best sellers</p>
          <h2>Produktet qe po marrin me shume vemendje.</h2>
        </header>
        <div class="home-marketplace-products-grid is-compact">
          <HomeMarketplaceCard
            v-for="(product, index) in bestSellerProducts"
            :key="`best-${product.id}`"
            :product="product"
            :badge="index === 0 ? 'Best Seller' : getShowcaseBadge(product, index)"
            badge-tone="premium"
            compact
            :cart-busy="busyCartIds.includes(product.id)"
            @cart="handleCart"
          />
        </div>
      </article>

      <article id="home-marketplace-new-arrivals" class="home-marketplace-product-column">
        <header class="home-marketplace-column-head">
          <p class="section-label">New arrivals</p>
          <h2>Artikuj te rinj qe e mbajne homepage-in aktiv dhe aktual.</h2>
        </header>
        <div class="home-marketplace-products-grid is-compact">
          <HomeMarketplaceCard
            v-for="(product, index) in newArrivalProducts"
            :key="`new-${product.id}`"
            :product="product"
            :badge="index === 0 ? 'New' : getShowcaseBadge(product, index)"
            badge-tone="premium"
            compact
            :cart-busy="busyCartIds.includes(product.id)"
            @cart="handleCart"
          />
        </div>
      </article>
    </section>

    <section class="home-marketplace-trust-grid" aria-label="Besimi dhe sherbimi">
      <article
        v-for="card in homeTrustCards"
        :key="card.title"
        class="home-marketplace-trust-card"
      >
        <p class="section-label">{{ card.title }}</p>
        <h3>{{ card.title }}</h3>
        <p>{{ card.copy }}</p>
      </article>
    </section>

    <section v-if="featuredBusinesses.length > 0" class="home-marketplace-section" aria-label="Markat lokale">
      <header class="home-marketplace-section-head">
        <div>
          <p class="section-label">Local brands</p>
          <h2>Biznese reale qe i japin fytyre marketplace-it.</h2>
          <p>Profile publike me katalog, produkte te publikuara dhe identitet te qarte vizual.</p>
        </div>
        <RouterLink class="home-marketplace-section-link" to="/bizneset-e-regjistruara">
          Shiko te gjitha markat
        </RouterLink>
      </header>

      <div class="home-marketplace-brand-grid">
        <RouterLink
          v-for="business in featuredBusinesses"
          :key="business.id"
          class="home-marketplace-brand-card"
          :to="business.profileUrl || getBusinessProfileUrl(business.id)"
        >
          <div class="home-marketplace-brand-logo">
            <img
              v-if="business.logoPath"
              :src="business.logoPath"
              :alt="business.businessName"
              width="140"
              height="140"
              loading="lazy"
              decoding="async"
            >
            <span v-else>{{ getBusinessInitials(business.businessName) }}</span>
          </div>
          <div class="home-marketplace-brand-copy">
            <strong>{{ business.businessName }}</strong>
            <span>{{ business.city || "Partner i TREGO" }}</span>
          </div>
        </RouterLink>
      </div>
    </section>

    <section
      v-if="visibleRecentlyViewedProducts.length > 0"
      class="home-marketplace-section"
      aria-label="Produktet e pare se fundi"
    >
      <header class="home-marketplace-section-head">
        <div>
          <p class="section-label">Pare se fundi</p>
          <h2>Rikthehu te produktet qe i pe pak me pare.</h2>
          <p>Nje shtrese e shpejte rikthimi per user-in pa e humbur rrjedhen e blerjes.</p>
        </div>
      </header>

      <div class="home-marketplace-products-grid is-compact">
        <HomeMarketplaceCard
          v-for="product in visibleRecentlyViewedProducts"
          :key="`home-recent-${product.id}`"
          :product="product"
          badge="Viewed"
          badge-tone="premium"
          compact
          :cart-busy="busyCartIds.includes(product.id)"
          @cart="handleCart"
        />
      </div>
    </section>

    <section v-if="popularNowProducts.length > 0" class="home-marketplace-section" aria-label="Popular right now">
      <header class="home-marketplace-section-head">
        <div>
          <p class="section-label">Popular right now</p>
          <h2>Produktet qe po e mbajne katalogun aktiv tani.</h2>
          <p>Mix i best sellers, ofertave dhe artikujve te rinj per nje homepage qe duket gjithmone live.</p>
        </div>
        <RouterLink class="home-marketplace-section-link" to="/kerko">Shfleto gjithcka</RouterLink>
      </header>

      <div class="home-marketplace-products-grid">
        <HomeMarketplaceCard
          v-for="(product, index) in popularNowProducts.slice(0, 4)"
          :key="`popular-${product.id}`"
          :product="product"
          :badge="getShowcaseBadge(product, index)"
          :badge-tone="getShowcaseBadgeTone(product)"
          :cart-busy="busyCartIds.includes(product.id)"
          @cart="handleCart"
        />
      </div>
    </section>

    <section class="home-marketplace-proof-layout" aria-label="Reviews dhe newsletter">
      <article class="home-marketplace-proof-column home-marketplace-testimonials">
        <header class="home-marketplace-column-head">
          <p class="section-label">Reviews</p>
          <h2>Pershtypje qe e bejne faqen te ndihet e besueshme.</h2>
        </header>

        <div class="home-marketplace-testimonial-grid">
          <article
            v-for="testimonial in homeTestimonials"
            :key="testimonial.author"
            class="home-marketplace-testimonial-card"
          >
            <p>“{{ testimonial.quote }}”</p>
            <strong>{{ testimonial.author }}</strong>
            <span>{{ testimonial.meta }}</span>
          </article>
        </div>
      </article>

      <article class="home-marketplace-proof-column home-marketplace-newsletter">
        <header class="home-marketplace-column-head">
          <p class="section-label">Newsletter</p>
          <h2>Merri drop-et, ofertat dhe produktet e reja ne inbox.</h2>
          <p>
            Nje CTA e thjeshte qe e kthen faqen nga katalog pasiv ne nje kanal te rregullt rikthimi.
          </p>
        </header>

        <form class="home-marketplace-newsletter-form" @submit.prevent="handleNewsletterSubmit">
          <input
            v-model="newsletterEmail"
            type="email"
            inputmode="email"
            autocomplete="email"
            placeholder="Shkruaj email-in tend"
            aria-label="Email per newsletter"
          >
          <button type="submit">Regjistrohu</button>
        </form>

        <ul class="home-marketplace-newsletter-list">
          <li v-for="benefit in homeNewsletterBenefits" :key="benefit">{{ benefit }}</li>
        </ul>
      </article>
    </section>

    <section class="home-marketplace-section home-marketplace-catalog" aria-label="Katalogu i plote">
      <header class="home-marketplace-section-head home-marketplace-catalog-head">
        <div>
          <p class="section-label">Gjithe katalogu</p>
          <p>{{ collectionLabel }}</p>
        </div>
      </header>

      <div class="collection-toolbar">
        <button
          class="filter-toggle-button"
          type="button"
          :aria-expanded="filtersVisible ? 'true' : 'false'"
          @click="toggleFiltersPanel"
        >
          Filtro
        </button>
      </div>

      <section v-if="filtersVisible" class="search-filters-panel" aria-label="Filtro produktet ne faqen kryesore">
        <div class="search-filters-grid">
          <label v-if="availablePageSectionOptions.length > 0" class="field">
            <span>Kategoria kryesore</span>
            <select v-model="filters.pageSection" class="search-filter-select" @change="handlePageSectionChange">
              <option value="">Te gjitha kategorite</option>
              <option
                v-for="option in availablePageSectionOptions"
                :key="option.value"
                :value="option.value"
              >
                {{ option.label }}
              </option>
            </select>
          </label>

          <label v-if="filters.pageSection && availableCategoryOptions.length > 0" class="field">
            <span>Nenkategoria</span>
            <select v-model="filters.category" class="search-filter-select" @change="handleCategoryChange">
              <option value="">Te gjitha nenkategorite</option>
              <option
                v-for="option in availableCategoryOptions"
                :key="option.value"
                :value="option.value"
              >
                {{ option.label }}
              </option>
            </select>
          </label>

          <label v-if="shouldShowProductTypeFilter" class="field">
            <span>Produkti</span>
            <select v-model="filters.productType" class="search-filter-select" @change="handleCatalogFilterChange">
              <option value="">Te gjitha llojet</option>
              <option
                v-for="option in availableProductTypeOptions"
                :key="`${option.category}-${option.value}`"
                :value="option.value"
              >
                {{ option.label }}
              </option>
            </select>
          </label>

          <label v-if="availableSizeOptions.length > 0" class="field">
            <span>Madhesia</span>
            <select v-model="filters.size" class="search-filter-select" @change="handleCatalogFilterChange">
              <option value="">Te gjitha madhesite</option>
              <option
                v-for="option in availableSizeOptions"
                :key="option.value"
                :value="option.value"
              >
                {{ option.label }}
              </option>
            </select>
          </label>

          <label v-if="availableColorOptions.length > 0" class="field">
            <span>Ngjyra</span>
            <select v-model="filters.color" class="search-filter-select" @change="handleCatalogFilterChange">
              <option value="">Te gjitha ngjyrat</option>
              <option
                v-for="option in availableColorOptions"
                :key="option.value"
                :value="option.value"
              >
                {{ option.label }}
              </option>
            </select>
          </label>

          <label class="field">
            <span>Cmimi</span>
            <select v-model="filters.sort" class="search-filter-select">
              <option value="">Renditja standarde</option>
              <option value="price-asc">Nga me i uleti</option>
              <option value="price-desc">Nga me i larti</option>
            </select>
          </label>
        </div>

        <div class="search-filter-actions">
          <button class="search-reset-button" type="button" @click="resetFilters">Pastro filtrat</button>
        </div>
      </section>

      <div class="form-message" :class="ui.type" role="status" aria-live="polite">
        {{ ui.message }}
      </div>

      <section v-if="filteredProducts.length > 0" class="pet-products-grid" aria-label="Te gjitha produktet">
        <ProductCard
          v-for="product in filteredProducts"
          :key="product.id"
          :product="product"
          :is-wishlisted="wishlistIds.includes(product.id)"
          :is-in-cart="cartIds.includes(product.id)"
          :wishlist-busy="busyWishlistIds.includes(product.id)"
          :cart-busy="busyCartIds.includes(product.id)"
          :is-compared="comparedProductIds.includes(product.id)"
          @wishlist="handleWishlist"
          @cart="handleCart"
          @compare="handleCompare"
        />
      </section>

      <div
        v-if="products.length > 0 && hasMoreProducts"
        class="collection-load-more"
        :class="{ 'is-auto-loading': supportsAutoLoad }"
      >
        <div
          v-if="supportsAutoLoad"
          ref="loadMoreSentinel"
          class="collection-load-more-sentinel"
          aria-hidden="true"
        ></div>
        <p v-if="loadingMoreProducts" class="collection-load-more-copy">
          Duke ngarkuar edhe 6 produkte...
        </p>
        <button
          v-else-if="!supportsAutoLoad"
          class="search-reset-button collection-load-more-button"
          type="button"
          :disabled="loadingMoreProducts"
          @click="loadMoreProducts"
        >
          {{ loadingMoreProducts ? "Duke ngarkuar..." : "Shih me shume" }}
        </button>
      </div>

      <div v-if="products.length === 0" class="collection-empty-state">
        Nuk ka produkte publike ende.
      </div>
    </section>
  </section>
</template>
