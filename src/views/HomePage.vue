<script setup>
import { computed, onBeforeUnmount, onMounted, reactive, ref, watch } from "vue";
import { RouterLink, useRouter } from "vue-router";
import ProductCard from "../components/ProductCard.vue";
import RecommendationSections from "../components/RecommendationSections.vue";
import { useInfiniteScrollSentinel } from "../composables/useInfiniteScrollSentinel";
import {
  fetchHomeRecommendations,
  fetchProtectedCollection,
  requestJson,
  resolveApiMessage,
} from "../lib/api";
import { PRODUCT_PAGE_SECTION_OPTIONS, deriveSectionFromCategory } from "../lib/product-catalog";
import { getProductsPageSize, subscribeProductsPageSize } from "../lib/product-pagination";
import { readRecentlyViewedProducts } from "../lib/recently-viewed";
import { setPendingVisualSearchFile } from "../lib/visual-search-transfer";
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
const heroSearchQuery = ref("");
const heroVisualSearchInputElement = ref(null);
const products = ref([]);
const homeCatalogProducts = ref([]);
const homeRecommendationSections = ref([]);
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
const statusText = ref("Po ngarkohen produktet publike te TREGIO.");
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
const commerceHeroIndex = ref(0);
const dealsClockNow = ref(Date.now());
const dealsCountdownTarget = Date.now() + (((16 * 24) + 21) * 60 * 60 * 1000) + (57 * 60 * 1000) + (23 * 1000);
const businessUi = reactive({
  message: "",
  type: "",
});
let stopProductsPageSizeSubscription = () => {};
let publicProductsRequestId = 0;
let homeCatalogRequestId = 0;
let publicBusinessesRequestId = 0;
let businessProfileRequestId = 0;
let businessProductsRequestId = 0;
let homeRecommendationsRequestId = 0;
let commerceHeroAutoplayId = 0;
let dealsCountdownIntervalId = 0;
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
const commerceSocialItems = [
  { label: "Twitter", icon: "twitter" },
  { label: "Facebook", icon: "facebook" },
  { label: "Pinterest", icon: "pinterest" },
  { label: "Instagram", icon: "instagram" },
];
const commerceQuickLinks = computed(() => ([
  {
    label: "Track Order",
    to: "/track-order",
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
const commerceActionItems = computed(() => ([
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
    badge: wishlistIds.value.length > 0 ? (wishlistIds.value.length > 99 ? "99+" : String(wishlistIds.value.length)) : "",
    icon: "heart",
  },
  {
    key: "account",
    label: appState.user ? "My account" : "Login",
    to: appState.user ? "/llogaria" : "/login",
    badge: "",
    icon: "user",
  },
]));
const commerceServiceCards = [
  {
    title: "FAST DELIVERY",
    copy: "Delivery in 24/7 nga bizneset lokale.",
    icon: "box",
  },
  {
    title: "24 HOURS RETURN",
    copy: "Kthim i qarte dhe i kontrolluar.",
    icon: "return",
  },
  {
    title: "SECURE PAYMENT",
    copy: "Pagesa te sigurta dhe checkout i thjeshte.",
    icon: "card",
  },
  {
    title: "SUPPORT 24/7",
    copy: "Support i drejtperdrejte me mesazhe.",
    icon: "headset",
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
    { label: "Produktet", type: "scroll", target: "home-marketplace-catalog" },
    { label: "Markat lokale", type: "scroll", target: "home-marketplace-local-brands" },
    { label: "Fashion", type: "route", to: navigationByKey.clothing || "/kerko" },
    { label: "Beauty", type: "route", to: navigationByKey.cosmetics || "/kerko" },
    { label: "Tech", type: "route", to: navigationByKey.technology || "/kerko" },
    { label: "Home", type: "route", to: navigationByKey.home || "/kerko" },
  ];
});
const consumerUtilityActions = computed(() => {
  if (!appState.user) {
    return [
      {
        title: "Login",
        copy: "Ruaje wishlist-in dhe porosite ne nje vend.",
        to: "/login",
      },
      {
        title: "Sign up",
        copy: "Krijo llogari per checkout, njoftime dhe mesazhe.",
        to: "/signup",
      },
      {
        title: "Katalogu",
        copy: "Hape kerkimet dhe filtrat e plote te marketplace-it.",
        to: "/kerko",
      },
      {
        title: "Markat lokale",
        copy: "Shiko bizneset qe shesin aktualisht ne platforme.",
        to: "/bizneset-e-regjistruara",
      },
    ];
  }

  return [
    {
      title: "Porosite",
      copy: "Ndjek statusin, pagesen dhe doren e porosive.",
      to: "/porosite",
    },
    {
      title: "Wishlist",
      copy: "Rikthehu te produktet qe i ke ruajtur me heret.",
      to: "/wishlist",
    },
    {
      title: "Mesazhet",
      copy: "Vazhdo bisedat me bizneset dhe support-in.",
      to: "/mesazhet",
    },
    {
      title: "Adresat",
      copy: "Perditeso adresat dhe checkout-in me me pak hapa.",
      to: "/adresat",
    },
    {
      title: "Njoftimet",
      copy: "Shiko alertet e porosive, mesazheve dhe aktivitetit.",
      to: "/njoftimet",
    },
    {
      title: "Kthimet",
      copy: "Kontrollo refund-et dhe kerkesat e hapura.",
      to: "/refund-returne",
    },
  ];
});
const businessWorkspaceActions = computed(() => ([
  {
    title: "Shto artikull",
    copy: "Hape builder-in dhe publiko produktin e ardhshem.",
    to: "/biznesi-juaj?view=add-product",
  },
  {
    title: "Porosite e biznesit",
    copy: businessOrdersCount.value > 0
      ? `${businessOrdersCount.value} porosi jane ne qarkullim tani.`
      : "Kontrollo kerkesat sapo te vijne porosite e para.",
    to: "/porosite-e-biznesit",
  },
  {
    title: "Mesazhet",
    copy: "Kalo direkt te inbox-i me klientet dhe support-i.",
    to: "/mesazhet",
  },
  {
    title: businessPublicProfileUrl.value ? "Profili publik" : "Menaxho profilin",
    copy: businessPublicProfileUrl.value
      ? "Shiko si duket biznesi yt per bleresit."
      : "Plotesoje profilin qe biznesi te jete me i besueshem.",
    to: businessPublicProfileUrl.value || "/biznesi-juaj",
  },
]));
const featuredBusinesses = computed(() => businesses.value.slice(0, 6));
function normalizeLookupValue(value) {
  return String(value || "").trim().toLowerCase();
}

function getBusinessLeadProduct(business) {
  const businessName = normalizeLookupValue(business?.businessName);
  if (!businessName) {
    return null;
  }

  return (
    [...marketplaceProducts.value, ...homeCatalogProducts.value, ...products.value]
      .find((product) => normalizeLookupValue(product?.businessName) === businessName)
    || null
  );
}

const spotlightBusiness = computed(() =>
  featuredBusinesses.value.find((business) => Boolean(business?.logoPath) || Boolean(getBusinessLeadProduct(business)))
  || featuredBusinesses.value[0]
  || null,
);
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
const saleTickerProducts = computed(() => {
  const discountedProducts = buildUniqueProducts(
    [
      ...flashDealProducts.value,
      ...[...marketplaceProducts.value]
        .filter((product) => getProductDiscountPercent(product) > 0)
        .sort((left, right) => {
          const discountDifference = getProductDiscountPercent(right) - getProductDiscountPercent(left);
          if (discountDifference !== 0) {
            return discountDifference;
          }

          return getProductPopularityScore(right) - getProductPopularityScore(left);
        }),
      ...bestSellerProducts.value,
    ],
    8,
  );

  if (discountedProducts.length > 0) {
    return discountedProducts;
  }

  return buildUniqueProducts(
    [
      ...flashDealProducts.value,
      ...bestSellerProducts.value,
      ...marketplaceProducts.value,
    ],
    8,
  );
});
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
const curatedHomeHeroSlides = [
  {
    badge: "Clearance Sale",
    title: "Clearance Sale 70% Off",
    description: "",
    ctaHref: "/kerko",
    ctaLabel: "Shop now",
    imagePath: "/home-slider-zbritje.webp",
    hideCopy: true,
  },
  {
    badge: "Mega Sale",
    title: "Mega Sale Special Offer",
    description: "",
    ctaHref: "/kerko",
    ctaLabel: "Shop now",
    imagePath: "/home-slider-megasales.webp",
    hideCopy: true,
  },
  {
    badge: "Mega Sale 90%",
    title: "90 Percent Off Mega Sale",
    description: "",
    ctaHref: "/kerko",
    ctaLabel: "Shop now",
    imagePath: "/home-slider-megasales90.webp",
    hideCopy: true,
  },
];
const homeHeroSlides = computed(() => {
  const curatedSlides = curatedHomeHeroSlides.filter((slide) => Boolean(slide.imagePath));
  if (curatedSlides.length) {
    return curatedSlides;
  }

  const slides = [];
  const seenEntries = new Set();

  function pushSlide(key, slide) {
    if (!key || seenEntries.has(key) || !slide?.imagePath) {
      return;
    }

    seenEntries.add(key);
    slides.push(slide);
  }

  const flashDeal = flashDealProducts.value[0];
  if (flashDeal) {
    pushSlide(`product-${flashDeal.id}`, {
      badge: "Oferta javore",
      title: flashDeal.title,
      description: `Zbritje reale nga ${flashDeal.businessName || "katalogu aktiv"} me stok live dhe checkout te paster.`,
      ctaHref: getProductDetailUrl(flashDeal.id, "/"),
      ctaLabel: "Shiko oferten",
      imagePath: flashDeal.imagePath,
    });
  }

  const trendingProduct = bestSellerProducts.value[0] || popularNowProducts.value[0] || null;
  if (trendingProduct) {
    pushSlide(`product-${trendingProduct.id}`, {
      badge: "Trending tani",
      title: trendingProduct.title,
      description: `Produkt me interes te larte nga ${trendingProduct.businessName || "marketplace-i"} dhe sinjale reale shitjeje.`,
      ctaHref: getProductDetailUrl(trendingProduct.id, "/"),
      ctaLabel: "Hape produktin",
      imagePath: trendingProduct.imagePath,
    });
  }

  const highlightedBusiness = spotlightBusiness.value;
  if (highlightedBusiness) {
    const relatedProduct = getBusinessLeadProduct(highlightedBusiness);
    pushSlide(`business-${highlightedBusiness.id}`, {
      badge: "Biznes spotlight",
      title: highlightedBusiness.businessName,
      description: highlightedBusiness.city
        ? `${highlightedBusiness.city} · Shiko produktet dhe prezantimin publik te biznesit.`
        : "Njih biznesin, ofertat dhe produktet qe po reklamohen tani.",
      ctaHref: highlightedBusiness.profileUrl || getBusinessProfileUrl(highlightedBusiness.id),
      ctaLabel: "Hape biznesin",
      imagePath: relatedProduct?.imagePath || highlightedBusiness.logoPath,
    });
  }

  const freshProduct = newArrivalProducts.value[0] || popularNowProducts.value[1] || marketplaceProducts.value[0] || null;
  if (freshProduct) {
    pushSlide(`product-${freshProduct.id}`, {
      badge: "Drop i ri",
      title: freshProduct.title,
      description: `Artikull i publikuar se fundi me pamje te paster dhe rruge direkte drejt faqes se produktit.`,
      ctaHref: getProductDetailUrl(freshProduct.id, "/"),
      ctaLabel: "Shiko detajet",
      imagePath: freshProduct.imagePath,
    });
  }

  return slides.slice(0, 4);
});
const homeHeroMiniPanels = computed(() => {
  const panels = [];
  const flashDeal = flashDealProducts.value[0];
  const trendingProduct = bestSellerProducts.value[0] || popularNowProducts.value[0] || null;
  const highlightedBusiness = spotlightBusiness.value;

  if (flashDeal?.imagePath) {
    panels.push({
      key: "sale",
      tone: "sale",
      label: "Sale",
      title: flashDeal.title,
      copy: `${Math.max(getProductDiscountPercent(flashDeal), 0)}% ulje · ${formatPrice(flashDeal.price)}`,
      imagePath: flashDeal.imagePath,
      to: getProductDetailUrl(flashDeal.id, "/"),
    });
  }

  if (trendingProduct?.imagePath) {
    panels.push({
      key: "trending",
      tone: "trending",
      label: "Trending",
      title: trendingProduct.title,
      copy: `${trendingProduct.businessName || "Marketplace"} · ${formatPrice(trendingProduct.price)}`,
      imagePath: trendingProduct.imagePath,
      to: getProductDetailUrl(trendingProduct.id, "/"),
    });
  }

  if (highlightedBusiness) {
    const relatedProduct = getBusinessLeadProduct(highlightedBusiness);
    const imagePath = relatedProduct?.imagePath || highlightedBusiness.logoPath || trendingProduct?.imagePath || flashDeal?.imagePath || "";
    if (imagePath) {
      panels.push({
        key: "business",
        tone: "business",
        label: "Bizneset",
        title: highlightedBusiness.businessName,
        copy: highlightedBusiness.city || "Profil publik me produkte lokale",
        imagePath,
        to: highlightedBusiness.profileUrl || getBusinessProfileUrl(highlightedBusiness.id),
      });
    }
  }

  return panels.slice(0, 3);
});
const homeFeatureCards = computed(() => {
  const cards = [];
  const seen = new Set();

  function pushCard(key, card) {
    if (!key || seen.has(key) || !card?.imagePath) {
      return;
    }

    seen.add(key);
    cards.push(card);
  }

  const candidates = [
    {
      key: flashDealProducts.value[1]?.id ? `sale-${flashDealProducts.value[1].id}` : "",
      product: flashDealProducts.value[1] || flashDealProducts.value[0] || null,
      label: "Oferta",
      tone: "sale",
    },
    {
      key: bestSellerProducts.value[1]?.id ? `trend-${bestSellerProducts.value[1].id}` : "",
      product: bestSellerProducts.value[1] || bestSellerProducts.value[0] || null,
      label: "Trending",
      tone: "trending",
    },
    {
      key: newArrivalProducts.value[0]?.id ? `new-${newArrivalProducts.value[0].id}` : "",
      product: newArrivalProducts.value[0] || popularNowProducts.value[2] || null,
      label: "Drop i ri",
      tone: "fresh",
    },
  ];

  candidates.forEach((entry) => {
    if (!entry.product?.imagePath) {
      return;
    }

    pushCard(entry.key, {
      label: entry.label,
      tone: entry.tone,
      title: entry.product.title,
      copy: `${entry.product.businessName || "Marketplace"} · ${formatPrice(entry.product.price)}`,
      imagePath: entry.product.imagePath,
      to: getProductDetailUrl(entry.product.id, "/"),
    });
  });

  const businessCandidate = featuredBusinesses.value.find((business) => Boolean(getBusinessLeadProduct(business)));
  if (businessCandidate) {
    const product = getBusinessLeadProduct(businessCandidate);
    pushCard(`business-${businessCandidate.id}`, {
      label: "Biznes",
      tone: "business",
      title: businessCandidate.businessName,
      copy: businessCandidate.city || "Profil publik dhe produkte lokale",
      imagePath: product?.imagePath || businessCandidate.logoPath,
      to: businessCandidate.profileUrl || getBusinessProfileUrl(businessCandidate.id),
    });
  }

  return cards.slice(0, 4);
});
const homeMiniSliderCards = computed(() => {
  const cards = [...homeFeatureCards.value];
  const seenTargets = new Set(cards.map((card) => card.to));
  const fallbackProducts = buildUniqueProducts(
    [
      ...popularNowProducts.value,
      ...marketplaceProducts.value,
      ...homeCatalogProducts.value,
    ],
    8,
  );

  fallbackProducts.forEach((product, index) => {
    if (cards.length >= 4 || !product?.imagePath) {
      return;
    }

    const to = getProductDetailUrl(product.id, "/");
    if (seenTargets.has(to)) {
      return;
    }

    seenTargets.add(to);
    cards.push({
      label: index % 2 === 0 ? "Produkt" : "Oferta",
      tone: index % 2 === 0 ? "fresh" : "sale",
      title: product.title,
      copy: `${product.businessName || "TREGIO"} · ${formatPrice(product.price)}`,
      imagePath: product.imagePath,
      to,
    });
  });

  return cards.slice(0, 4);
});
const personalizedProducts = computed(() => {
  const viewedIds = new Set(recentlyViewedProducts.value.map((product) => Number(product?.id || 0)));
  const preferredCategories = new Set(
    recentlyViewedProducts.value
      .map((product) => normalizeLookupValue(product?.category))
      .filter(Boolean),
  );
  const preferredBusinesses = new Set(
    recentlyViewedProducts.value
      .map((product) => normalizeLookupValue(product?.businessName))
      .filter(Boolean),
  );

  const scoredProducts = [...marketplaceProducts.value]
    .map((product) => {
      const productId = Number(product?.id || 0);
      const categoryKey = normalizeLookupValue(product?.category);
      const businessKey = normalizeLookupValue(product?.businessName);
      let score = getProductPopularityScore(product);

      if (preferredCategories.has(categoryKey)) {
        score += 28;
      }

      if (preferredBusinesses.has(businessKey)) {
        score += 34;
      }

      if (!viewedIds.has(productId)) {
        score += 6;
      } else {
        score -= 12;
      }

      if (getProductDiscountPercent(product) > 0) {
        score += 8;
      }

      return { product, score };
    })
    .sort((left, right) => right.score - left.score)
    .map((entry) => entry.product);

  const fallbackProducts = buildUniqueProducts(
    [
      ...scoredProducts,
      ...popularNowProducts.value,
      ...recentlyViewedProducts.value,
      ...marketplaceProducts.value,
    ],
    10,
  );

  return fallbackProducts.slice(0, 8);
});
const homeBusinessBillboard = computed(() => {
  const business = spotlightBusiness.value || featuredBusinesses.value[0] || null;
  if (!business) {
    return null;
  }

  const leadProduct = getBusinessLeadProduct(business);
  const relatedProducts = buildUniqueProducts(
    marketplaceProducts.value.filter(
      (product) => normalizeLookupValue(product?.businessName) === normalizeLookupValue(business.businessName),
    ),
    3,
  );

  return {
    business,
    leadProduct,
    relatedProducts,
    target: business.profileUrl || getBusinessProfileUrl(business.id),
  };
});
const heroSpotlightProduct = computed(() =>
  flashDealProducts.value[0]
  || bestSellerProducts.value[0]
  || newArrivalProducts.value[0]
  || marketplaceProducts.value[0]
  || null,
);
const commerceHeroProducts = computed(() =>
  buildUniqueProducts(
    [
      heroSpotlightProduct.value,
      ...flashDealProducts.value,
      ...bestSellerProducts.value,
      ...newArrivalProducts.value,
      ...popularNowProducts.value,
      ...marketplaceProducts.value,
    ].filter((product) => hasProductAvailableStock(product)),
    5,
  ),
);
const activeCommerceHeroProduct = computed(() => {
  const productsPool = commerceHeroProducts.value;
  if (!productsPool.length) {
    return null;
  }

  return productsPool[commerceHeroIndex.value] || productsPool[0];
});
const commerceHeroSideCards = computed(() =>
  buildUniqueProducts(
    commerceHeroProducts.value.filter(
      (product) => Number(product?.id || 0) !== Number(activeCommerceHeroProduct.value?.id || 0),
    ),
    2,
  ),
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
const commerceHeaderCategories = computed(() =>
  PRODUCT_PAGE_SECTION_OPTIONS.slice(0, 6).map((section) => ({
    value: section.value,
    label: section.label,
  })),
);
const bestDealsSection = computed(() =>
  homeRecommendationSections.value.find((section) => section.key === "best-sellers")
  || homeRecommendationSections.value.find((section) => section.key === "recommended-for-you")
  || homeRecommendationSections.value.find((section) => section.key === "new-arrivals")
  || null,
);
const visibleHomeRecommendationSections = computed(() => {
  if (!bestDealsSection.value) {
    return homeRecommendationSections.value;
  }

  return homeRecommendationSections.value.filter((section) => section.key !== bestDealsSection.value.key);
});
const bestDealsProducts = computed(() => {
  const recommendationProducts = Array.isArray(bestDealsSection.value?.products)
    ? bestDealsSection.value.products
    : [];

  const fallbackProducts = [
    ...flashDealProducts.value,
    ...bestSellerProducts.value,
    ...newArrivalProducts.value,
    ...popularNowProducts.value,
    ...marketplaceProducts.value,
  ];

  return buildUniqueProducts(
    [...recommendationProducts, ...fallbackProducts]
      .filter((product) => hasProductAvailableStock(product))
      .sort((left, right) => {
        const discountDifference = getProductDiscountPercent(right) - getProductDiscountPercent(left);
        if (discountDifference !== 0) {
          return discountDifference;
        }

        return getProductPopularityScore(right) - getProductPopularityScore(left);
      }),
    9,
  );
});
const categoryShelfCards = computed(() => featuredCategoryCards.value.slice(0, 6));
const featuredProductsSection = computed(() =>
  visibleHomeRecommendationSections.value.find((section) => section.key === "recommended-for-you")
  || visibleHomeRecommendationSections.value.find((section) => section.key === "new-arrivals")
  || visibleHomeRecommendationSections.value[0]
  || null,
);
const featuredProductsShelf = computed(() => {
  const recommendationProducts = Array.isArray(featuredProductsSection.value?.products)
    ? featuredProductsSection.value.products
    : [];

  return buildUniqueProducts(
    [
      ...recommendationProducts,
      ...popularNowProducts.value,
      ...newArrivalProducts.value,
      ...marketplaceProducts.value,
    ].filter((product) => hasProductAvailableStock(product)),
    8,
  );
});
const featuredProductTabs = computed(() => {
  const baseTabs = [
    { label: "All Product", to: "/kerko", isAccent: false },
    ...categoryShelfCards.value.slice(0, 4).map((category) => ({
      label: category.label,
      to: category.href || "/kerko",
      isAccent: false,
    })),
  ];

  baseTabs.push({
    label: "Browse All Product",
    to: "/kerko",
    isAccent: true,
  });

  return baseTabs;
});
const dealsCountdownText = computed(() => formatCountdownLabel(dealsCountdownTarget - dealsClockNow.value));

const collectionLabel = computed(() => {
  if (!products.value.length) {
    return "Nuk ka produkte publike ende.";
  }

  if (!filters.size && !filters.color && !filters.sort) {
    return totalProductsCount.value > products.value.length
      ? `Po shfaqen ${products.value.length} nga ${totalProductsCount.value} produkte publike te TREGIO.`
      : statusText.value;
  }

  return totalProductsCount.value > 0
    ? `Po shfaqen ${filteredProducts.value.length} nga ${products.value.length} produkte te ngarkuara (${totalProductsCount.value} gjithsej) sipas filtrave te zgjedhur.`
    : `Po shfaqen ${filteredProducts.value.length} nga ${products.value.length} produkte sipas filtrave te zgjedhur.`;
});

onMounted(async () => {
  startCommerceHeroAutoplay();
  startDealsCountdown();
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
    void loadHomeRecommendations();
    void loadHomeCatalogProducts();
    void loadBusinesses();
    void ensureSessionLoaded()
      .then(async (user) => {
        if (user?.role === "business") {
          await Promise.all([loadBusinessProfile(), loadBusinessProducts()]);
          return;
        }

        await Promise.all([refreshCollectionState(), loadHomeRecommendations()]);
      })
      .catch((error) => {
        console.error(error);
      });

    await publicProductsPromise;
    markRouteReady();
  } catch (error) {
    statusText.value = "Produktet nuk u ngarkuan. Provoje perseri pas pak.";
    console.error(error);
    markRouteReady();
  }
});

onBeforeUnmount(() => {
  stopProductsPageSizeSubscription();
  stopCommerceHeroAutoplay();
  stopDealsCountdown();
});

watch(
  () => commerceHeroProducts.value.length,
  (nextLength) => {
    if (commerceHeroIndex.value >= nextLength) {
      commerceHeroIndex.value = 0;
    }
    startCommerceHeroAutoplay();
  },
);

watch(
  () => `${appState.user?.id || 0}:${appState.user?.role || ""}`,
  async (nextValue, previousValue) => {
    if (nextValue === previousValue) {
      return;
    }

    await loadHomeRecommendations();
  },
);

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

    await Promise.all([loadProducts(), loadHomeCatalogProducts(), loadBusinesses(), loadHomeRecommendations()]);
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
  const requestId = ++publicProductsRequestId;
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
  if (requestId !== publicProductsRequestId) {
    return;
  }
  if (!response.ok || !data?.ok) {
    statusText.value = resolveApiMessage(data, "Produktet nuk u ngarkuan.");
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
      ? `Po shfaqen ${products.value.length} nga ${totalProductsCount.value} produkte publike te TREGIO.`
      : "Nuk ka produkte publike ende.";
}

async function loadHomeRecommendations() {
  if (isBusinessUser.value) {
    homeRecommendationSections.value = [];
    return;
  }

  const requestId = ++homeRecommendationsRequestId;
  const payload = await fetchHomeRecommendations(8);
  if (requestId !== homeRecommendationsRequestId) {
    return;
  }

  homeRecommendationSections.value = Array.isArray(payload.sections) ? payload.sections : [];
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
  const requestId = ++publicBusinessesRequestId;
  const { response, data } = await requestJson("/api/businesses/public", {}, { cacheTtlMs: 30000 });
  if (requestId !== publicBusinessesRequestId) {
    return;
  }
  if (!response.ok || !data?.ok) {
    return;
  }

  businesses.value = Array.isArray(data.businesses) ? data.businesses : [];
}

async function loadHomeCatalogProducts() {
  const requestId = ++homeCatalogRequestId;
  const { response, data } = await requestJson(
    "/api/products?limit=24&offset=0",
    {},
    { cacheTtlMs: 30000 },
  );
  if (requestId !== homeCatalogRequestId) {
    return;
  }
  if (!response.ok || !data?.ok) {
    return;
  }

  const nextProducts = Array.isArray(data.products) ? data.products : [];
  homeCatalogProducts.value = nextProducts.filter((product) => hasProductAvailableStock(product));
}

async function loadBusinessProfile() {
  const requestId = ++businessProfileRequestId;
  const { response, data } = await requestJson("/api/business-profile");
  if (requestId !== businessProfileRequestId) {
    return;
  }
  if (!response.ok || !data?.ok) {
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
  const requestId = ++businessProductsRequestId;
  const { response, data } = await requestJson("/api/business/products");
  if (requestId !== businessProductsRequestId) {
    return;
  }
  if (!response.ok || !data?.ok) {
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

async function submitHeroSearch() {
  const normalizedQuery = String(heroSearchQuery.value || "").trim();
  await router.push(
    normalizedQuery
      ? {
          path: "/kerko",
          query: { q: normalizedQuery },
        }
      : "/kerko",
  );
}

function openHeroVisualSearchPicker() {
  heroVisualSearchInputElement.value?.click?.();
}

async function handleHeroVisualSearchSelection(event) {
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

function navigateToCommerceCategory(event) {
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

function startCommerceHeroAutoplay() {
  stopCommerceHeroAutoplay();
  if (typeof window === "undefined" || isBusinessUser.value || commerceHeroProducts.value.length <= 1) {
    return;
  }

  commerceHeroAutoplayId = window.setInterval(() => {
    commerceHeroIndex.value = (commerceHeroIndex.value + 1) % commerceHeroProducts.value.length;
  }, 5200);
}

function stopCommerceHeroAutoplay() {
  if (!commerceHeroAutoplayId) {
    return;
  }

  window.clearInterval(commerceHeroAutoplayId);
  commerceHeroAutoplayId = 0;
}

function goToCommerceHeroSlide(index) {
  const totalSlides = commerceHeroProducts.value.length;
  if (!totalSlides) {
    return;
  }

  commerceHeroIndex.value = (index + totalSlides) % totalSlides;
  startCommerceHeroAutoplay();
}

function startDealsCountdown() {
  stopDealsCountdown();
  if (typeof window === "undefined" || isBusinessUser.value) {
    return;
  }

  dealsClockNow.value = Date.now();
  dealsCountdownIntervalId = window.setInterval(() => {
    dealsClockNow.value = Date.now();
  }, 1000);
}

function stopDealsCountdown() {
  if (!dealsCountdownIntervalId) {
    return;
  }

  window.clearInterval(dealsCountdownIntervalId);
  dealsCountdownIntervalId = 0;
}

function formatCountdownLabel(milliseconds) {
  const remaining = Math.max(0, Math.floor(milliseconds / 1000));
  const days = Math.floor(remaining / 86400);
  const hours = Math.floor((remaining % 86400) / 3600);
  const minutes = Math.floor((remaining % 3600) / 60);
  const seconds = remaining % 60;
  return `${days}d : ${String(hours).padStart(2, "0")}h : ${String(minutes).padStart(2, "0")}m : ${String(seconds).padStart(2, "0")}s`;
}

function renderCommerceIcon(icon) {
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
      return "M3 5h2.1l1.4 8.2a1 1 0 0 0 1 .8h8.8a1 1 0 0 0 1-.8L19 7H7.4M9 19a1.5 1.5 0 1 0 0 .1zm7 0a1.5 1.5 0 1 0 0 .1z";
    case "heart":
      return "m12 20.4-1.2-1C5.4 14.6 2 11.5 2 7.8A4.8 4.8 0 0 1 6.8 3 5.3 5.3 0 0 1 12 5.9 5.3 5.3 0 0 1 17.2 3 4.8 4.8 0 0 1 22 7.8c0 3.7-3.4 6.8-8.8 11.6z";
    case "user":
      return "M12 12a4.2 4.2 0 1 0 0-8.4 4.2 4.2 0 0 0 0 8.4zm0 2.2c-3.6 0-6.5 2.4-7.3 5.8h14.6c-.8-3.4-3.7-5.8-7.3-5.8z";
    case "box":
      return "M4.8 8.1 12 4l7.2 4.1V16L12 20l-7.2-4ZM12 12l7.2-3.9M12 12 4.8 8.1M12 12v8";
    case "return":
      return "M7 7H3v4M3 11c1.2-3.4 4.1-5.5 7.8-5.5 4.8 0 8.7 3.9 8.7 8.7S15.6 23 10.8 23c-3.4 0-6.4-2-7.8-5.1";
    case "card":
      return "M3 7.5A2.5 2.5 0 0 1 5.5 5h13A2.5 2.5 0 0 1 21 7.5v9a2.5 2.5 0 0 1-2.5 2.5h-13A2.5 2.5 0 0 1 3 16.5Zm0 2.2h18M7 15h3";
    case "headset":
      return "M4 12a8 8 0 1 1 16 0v5a2 2 0 0 1-2 2h-2v-6h4M4 13h4v6H6a2 2 0 0 1-2-2z";
    default:
      return "";
  }
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
  void loadHomeRecommendations();
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
  void loadHomeRecommendations();
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

    <section class="card business-home-workspace" aria-label="Veprimet kryesore te biznesit">
      <div class="business-home-workspace-head">
        <div>
          <p class="section-label">Workspace i biznesit</p>
          <h2>Veprimet qe perdoren me shpesh</h2>
          <p class="section-text">
            Kalo direkt te shtimi i artikujve, porosite, mesazhet dhe profili publik pa humbur kohe ne navigim.
          </p>
        </div>
      </div>

      <div class="business-home-workspace-grid">
        <RouterLink
          v-for="item in businessWorkspaceActions"
          :key="item.title"
          class="business-home-workspace-card"
          :to="item.to"
        >
          <strong>{{ item.title }}</strong>
          <span>{{ item.copy }}</span>
        </RouterLink>
      </div>
    </section>

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

  <section v-else class="collection-page home-marketplace-page commerce-home-page" aria-label="Faqja kryesore">
    <section class="commerce-home-hero" aria-label="Hero i marketplace">
      <article v-if="activeCommerceHeroProduct" class="commerce-home-hero-main">
        <div class="commerce-home-hero-copy">
          <span class="commerce-home-hero-kicker">THE BEST PLACE TO BUY</span>
          <h1>{{ activeCommerceHeroProduct.title }}</h1>
          <p>
            {{ activeCommerceHeroProduct.description || "Oferta reale, stok aktiv dhe produkte qe po performojne me mire ne marketplace." }}
          </p>
          <RouterLink class="commerce-home-hero-cta" :to="getProductDetailUrl(activeCommerceHeroProduct.id, '/')">
            SHOP NOW
          </RouterLink>
        </div>

        <div class="commerce-home-hero-visual">
          <img
            class="commerce-home-hero-image"
            :src="activeCommerceHeroProduct.imagePath"
            :alt="activeCommerceHeroProduct.title"
            width="760"
            height="760"
            loading="eager"
            decoding="async"
            fetchpriority="high"
          >
          <div class="commerce-home-hero-price">
            {{ formatPrice(activeCommerceHeroProduct.price) }}
          </div>
        </div>

        <div class="commerce-home-hero-overlay">
          <span class="commerce-home-hero-dot-indicator"></span>
        </div>
        <div class="commerce-home-hero-dots" aria-label="Zgjedh slide">
          <button
            v-for="(product, index) in commerceHeroProducts"
            :key="`${product.id}-${product.title}`"
            class="commerce-home-hero-dot"
            :class="{ 'is-active': index === commerceHeroIndex }"
            type="button"
            :aria-label="`Hap slide ${index + 1}`"
            @click="goToCommerceHeroSlide(index)"
          ></button>
        </div>
      </article>

      <div v-if="commerceHeroSideCards.length > 0" class="commerce-home-hero-side">
        <RouterLink
            v-for="(product, index) in commerceHeroSideCards"
            :key="product.id"
            class="commerce-home-side-card"
            :class="index === 0 ? 'is-dark' : 'is-light'"
          :to="getProductDetailUrl(product.id, '/')"
        >
          <div class="commerce-home-side-copy">
            <span>{{ index === 0 ? "Summer sales" : "Trending now" }}</span>
            <strong>{{ product.title }}</strong>
            <small>{{ formatPrice(product.price) }}</small>
            <em>Shop now</em>
          </div>
          <img
            :src="product.imagePath"
            :alt="product.title"
            width="360"
            height="260"
            loading="lazy"
            decoding="async"
          >
        </RouterLink>
      </div>
    </section>

    <section class="commerce-home-service-strip" aria-label="Sherbimet kryesore">
      <article
        v-for="item in commerceServiceCards"
        :key="item.title"
        class="commerce-home-service-card"
      >
        <span class="commerce-home-service-icon" aria-hidden="true">
          <svg viewBox="0 0 24 24">
            <path :d="renderCommerceIcon(item.icon)" />
          </svg>
        </span>
        <div>
          <strong>{{ item.title }}</strong>
          <span>{{ item.copy }}</span>
        </div>
      </article>
    </section>

    <section v-if="bestDealsProducts.length > 0" class="commerce-home-best-deals" aria-label="Best deals">
      <header class="commerce-home-section-head">
        <div class="commerce-home-section-title">
          <h2>Best Deals</h2>
          <div class="commerce-home-countdown">
            <span>Deals ends in</span>
            <strong>{{ dealsCountdownText }}</strong>
          </div>
        </div>
        <RouterLink class="commerce-home-section-link" to="/kerko">
          Browse All Product
        </RouterLink>
      </header>

      <div class="commerce-home-best-grid">
        <article
          v-for="(product, index) in bestDealsProducts"
          :key="`best-deal-${product.id}`"
          class="commerce-home-best-card"
          :class="{ 'is-featured': index === 0 }"
        >
          <RouterLink class="commerce-home-best-card-link" :to="getProductDetailUrl(product.id, '/')">
            <span
              v-if="getShowcaseBadge(product, index)"
              class="commerce-home-best-badge"
              :class="{ 'is-alert': getShowcaseBadgeTone(product) === 'alert' }"
            >
              {{ getShowcaseBadge(product, index) }}
            </span>
            <img
              :src="product.imagePath"
              :alt="product.title"
              width="420"
              height="420"
              loading="lazy"
              decoding="async"
            >
            <div class="commerce-home-best-copy">
              <div v-if="index === 0" class="commerce-home-best-rating">
                <span>★★★★★</span>
                <small>({{ Number(product.reviewCount || 0) }})</small>
              </div>
              <strong>{{ product.title }}</strong>
              <p v-if="index === 0">
                {{ product.description || "Produkti me performancen me te mire nga Recommendation MVP." }}
              </p>
              <div class="commerce-home-best-price">
                <span v-if="Number(product.compareAtPrice || product.originalPrice || 0) > Number(product.price || 0)">
                  {{ formatPrice(product.compareAtPrice || product.originalPrice) }}
                </span>
                <strong>{{ formatPrice(product.price) }}</strong>
              </div>
            </div>
          </RouterLink>

          <div v-if="index === 0" class="commerce-home-best-actions">
            <button
              class="commerce-home-icon-action"
              type="button"
              :disabled="busyWishlistIds.includes(product.id)"
              @click="handleWishlist(product.id)"
            >
              <svg viewBox="0 0 24 24" aria-hidden="true">
                <path :d="renderCommerceIcon('heart')" />
              </svg>
            </button>
            <button
              class="commerce-home-primary-action"
              type="button"
              :disabled="busyCartIds.includes(product.id)"
              @click="handleCart(product.id)"
            >
              Add to cart
            </button>
            <button
              class="commerce-home-icon-action"
              type="button"
              @click="handleCompare(product)"
            >
              <svg viewBox="0 0 24 24" aria-hidden="true">
                <path d="M6.9 8.7a5.1 5.1 0 0 1 8.7-1.5l1.3-1.3v4.2h-4.2l1.5-1.5a3 3 0 1 0 .9 2.1h2.1a5.1 5.1 0 1 1-10.3 0c0-.3 0-.7.1-1zm10.2 6.6A5.1 5.1 0 0 1 8.4 17L7.1 18.3v-4.2h4.2l-1.5 1.5a3 3 0 1 0-.9-2.1H6.8a5.1 5.1 0 1 1 10.3 0c0 .3 0 .7-.1 1z" />
              </svg>
            </button>
          </div>
        </article>
      </div>
    </section>

    <section v-if="categoryShelfCards.length > 0" class="commerce-home-category-showcase" aria-label="Shop with categories">
      <header class="commerce-home-category-head">
        <h2>Shop with Categories</h2>
      </header>

      <div class="commerce-home-category-rail">
        <span class="commerce-home-category-arrow" aria-hidden="true">‹</span>
        <RouterLink
          v-for="category in categoryShelfCards"
          :key="category.value"
          class="commerce-home-category-card"
          :to="category.href || '/kerko'"
        >
          <img
            :src="category.imagePath"
            :alt="category.label"
            width="220"
            height="180"
            loading="lazy"
            decoding="async"
          >
          <strong>{{ category.label }}</strong>
        </RouterLink>
        <span class="commerce-home-category-arrow" aria-hidden="true">›</span>
      </div>

      <div class="commerce-home-featured-block">
        <aside class="commerce-home-featured-banner">
          <span>COMPUTER & ACCESSORIES</span>
          <strong>{{ highestDiscountDisplay }} Discount</strong>
          <p>For all electronics products dhe ofertat me te mira te dites.</p>
          <RouterLink class="commerce-home-banner-cta" to="/kerko">
            Shop now
          </RouterLink>
          <img
            v-if="activeCommerceHeroProduct?.imagePath"
            :src="activeCommerceHeroProduct.imagePath"
            :alt="activeCommerceHeroProduct.title"
            width="420"
            height="620"
            loading="lazy"
            decoding="async"
          >
        </aside>

        <div class="commerce-home-featured-products">
          <header class="commerce-home-featured-head">
            <h3>Featured Products</h3>
            <nav class="commerce-home-featured-tabs" aria-label="Featured product tabs">
              <RouterLink
                v-for="tab in featuredProductTabs"
                :key="tab.label"
                :to="tab.to"
                :class="{ 'is-accent': tab.isAccent }"
              >
                {{ tab.label }}
              </RouterLink>
            </nav>
          </header>

          <div class="commerce-home-featured-grid">
            <article
              v-for="product in featuredProductsShelf"
              :key="`featured-${product.id}`"
              class="commerce-home-featured-card"
            >
              <RouterLink class="commerce-home-featured-link" :to="getProductDetailUrl(product.id, '/')">
                <span
                  v-if="getShowcaseBadge(product)"
                  class="commerce-home-featured-badge"
                  :class="{ 'is-alert': getShowcaseBadgeTone(product) === 'alert' }"
                >
                  {{ getShowcaseBadge(product) }}
                </span>
                <img
                  :src="product.imagePath"
                  :alt="product.title"
                  width="280"
                  height="220"
                  loading="lazy"
                  decoding="async"
                >
                <div class="commerce-home-featured-rating">★★★★★ <small>({{ Number(product.reviewCount || 0) }})</small></div>
                <strong>{{ product.title }}</strong>
                <div class="commerce-home-featured-price">
                  <span v-if="Number(product.compareAtPrice || product.originalPrice || 0) > Number(product.price || 0)">
                    {{ formatPrice(product.compareAtPrice || product.originalPrice) }}
                  </span>
                  <strong>{{ formatPrice(product.price) }}</strong>
                </div>
              </RouterLink>
            </article>
          </div>
        </div>
      </div>
    </section>

    <section
      id="home-marketplace-catalog"
      class="home-marketplace-section home-marketplace-catalog"
      aria-label="Produktet"
    >
      <RecommendationSections
        v-if="visibleHomeRecommendationSections.length > 0"
        :sections="visibleHomeRecommendationSections"
        :wishlist-ids="wishlistIds"
        :cart-ids="cartIds"
        :busy-wishlist-ids="busyWishlistIds"
        :busy-cart-ids="busyCartIds"
        :compared-product-ids="comparedProductIds"
        @wishlist="handleWishlist"
        @cart="handleCart"
        @compare="handleCompare"
      />

      <header class="home-marketplace-section-head home-marketplace-catalog-head">
        <div>
          <p class="section-label">PRODUKTE</p>
        </div>
      </header>

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

<style scoped>
.commerce-home-page {
  display: grid;
  gap: 28px;
}

.commerce-home-shell {
  display: grid;
  gap: 0;
  overflow: hidden;
  border-radius: 18px;
  background: #ffffff;
  border: 1px solid rgba(15, 23, 42, 0.08);
  box-shadow: 0 18px 40px rgba(15, 23, 42, 0.06);
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

.commerce-home-promo-cta,
.commerce-home-hero-cta,
.commerce-home-banner-cta,
.commerce-home-primary-action {
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

.commerce-home-promo-cta:hover,
.commerce-home-hero-cta:hover,
.commerce-home-banner-cta:hover,
.commerce-home-primary-action:hover {
  transform: translateY(-1px);
  box-shadow: 0 16px 28px rgba(247, 201, 72, 0.24);
}

.commerce-home-info-bar,
.commerce-home-header-bar {
  display: grid;
  align-items: center;
  gap: 18px;
  padding: 12px 28px;
  background: #f97316;
  color: rgba(255, 255, 255, 0.94);
}

.commerce-home-info-bar {
  grid-template-columns: minmax(0, 1fr) auto;
  font-size: 0.88rem;
  background: #ea6b0d;
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
  background: #f97316;
}

.commerce-home-brand {
  display: inline-flex;
  align-items: center;
  gap: 14px;
  color: #fff;
  text-decoration: none;
}

.commerce-home-brand img {
  width: 52px;
  height: 52px;
  object-fit: contain;
}

.commerce-home-brand strong {
  display: block;
  font-size: 1.75rem;
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
  color: #f97316;
}

.commerce-home-search-visual svg,
.commerce-home-search-submit svg,
.commerce-home-header-action svg,
.commerce-home-subnav-support svg,
.commerce-home-service-icon svg,
.commerce-home-icon-action svg {
  width: 20px;
  height: 20px;
  fill: currentColor;
}

.commerce-home-header-actions {
  display: inline-flex;
  align-items: center;
  gap: 10px;
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
  background: rgba(255, 255, 255, 0.16);
}

.commerce-home-header-badge {
  position: absolute;
  top: -2px;
  right: -2px;
  min-width: 18px;
  height: 18px;
  padding: 0 5px;
  border-radius: 999px;
  background: #f97316;
  color: #fff;
  font-size: 0.66rem;
  font-weight: 800;
  line-height: 18px;
  text-align: center;
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
.commerce-home-section-link,
.commerce-home-featured-tabs a {
  color: #475569;
  text-decoration: none;
  font-weight: 600;
}

.commerce-home-hero {
  display: grid;
  grid-template-columns: minmax(0, 1.7fr) minmax(280px, 0.8fr);
  gap: 18px;
}

.commerce-home-hero-main,
.commerce-home-side-card,
.commerce-home-best-deals,
.commerce-home-category-showcase {
  background: #fff;
  border: 1px solid rgba(15, 23, 42, 0.08);
  box-shadow: 0 24px 54px rgba(15, 23, 42, 0.06);
}

.commerce-home-hero-main {
  display: grid;
  grid-template-columns: minmax(0, 1fr) minmax(280px, 0.9fr);
  align-items: center;
  min-height: 430px;
  padding: 38px 44px;
  overflow: hidden;
  border-radius: 14px;
  background: #f8fafc;
}

.commerce-home-hero-copy {
  display: grid;
  gap: 14px;
  max-width: 380px;
}

.commerce-home-hero-copy h1,
.commerce-home-section-head h2,
.commerce-home-category-head h2,
.commerce-home-featured-head h3 {
  margin: 0;
  color: #111827;
  letter-spacing: -0.04em;
}

.commerce-home-hero-copy h1 {
  font-size: clamp(2.4rem, 4vw, 3.6rem);
  line-height: 0.95;
}

.commerce-home-hero-copy p {
  margin: 0;
  color: #475569;
  line-height: 1.55;
  font-size: 1.05rem;
}

.commerce-home-hero-kicker {
  display: inline-flex;
  width: fit-content;
  color: #0ea5e9;
  background: transparent;
  padding: 0;
  border-radius: 0;
  font-size: 0.86rem;
  font-weight: 800;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.commerce-home-hero-visual {
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 320px;
}

.commerce-home-hero-image {
  width: 100%;
  max-width: 420px;
  height: 320px;
  object-fit: contain;
  display: block;
}

.commerce-home-hero-price {
  position: absolute;
  top: 16px;
  right: 20px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 94px;
  height: 94px;
  border-radius: 999px;
  background: #22aaf5;
  color: #fff;
  font-size: 1.55rem;
  font-weight: 800;
  box-shadow: 0 18px 32px rgba(34, 170, 245, 0.22);
}

.commerce-home-hero-overlay {
  position: absolute;
  left: 44px;
  bottom: 24px;
}

.commerce-home-hero-dot-indicator {
  display: none;
}

.commerce-home-hero-dots {
  position: absolute;
  left: 44px;
  bottom: 22px;
  display: inline-flex;
  gap: 8px;
}

.commerce-home-hero-dot {
  width: 9px;
  height: 9px;
  border: 0;
  border-radius: 999px;
  background: rgba(148, 163, 184, 0.45);
  cursor: pointer;
}

.commerce-home-hero-dot.is-active {
  background: #111827;
}

.commerce-home-hero-side {
  display: grid;
  gap: 18px;
}

.commerce-home-side-card {
  display: grid;
  grid-template-columns: minmax(0, 1fr) 140px;
  align-items: center;
  gap: 14px;
  min-height: 220px;
  padding: 22px;
  border-radius: 14px;
  text-decoration: none;
}

.commerce-home-side-card.is-dark {
  background: #1f2937;
  color: #fff;
}

.commerce-home-side-card.is-light {
  background: #f8fafc;
  color: #0f172a;
}

.commerce-home-side-card img {
  width: 100%;
  height: 150px;
  object-fit: contain;
}

.commerce-home-side-copy {
  display: grid;
  gap: 8px;
}

.commerce-home-side-copy span,
.commerce-home-featured-banner span {
  color: #f59e0b;
  font-size: 0.78rem;
  font-weight: 800;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.commerce-home-side-copy strong {
  font-size: 1.7rem;
  line-height: 1.06;
  letter-spacing: -0.04em;
}

.commerce-home-side-copy small {
  color: inherit;
  font-size: 1rem;
  font-weight: 700;
}

.commerce-home-side-copy em {
  font-style: normal;
  font-weight: 800;
  color: #f97316;
}

.commerce-home-service-strip {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 12px;
}

.commerce-home-service-card {
  display: flex;
  align-items: center;
  gap: 14px;
  padding: 18px 20px;
  border-radius: 10px;
  background: #fff;
  border: 1px solid rgba(15, 23, 42, 0.08);
}

.commerce-home-service-icon {
  display: inline-flex;
  width: 42px;
  height: 42px;
  align-items: center;
  justify-content: center;
  border-radius: 14px;
  color: #0f6aa3;
  background: rgba(15, 106, 163, 0.08);
}

.commerce-home-service-card div {
  display: grid;
  gap: 4px;
}

.commerce-home-service-card strong {
  color: #111827;
  font-size: 0.84rem;
  letter-spacing: 0.05em;
}

.commerce-home-service-card span {
  color: #64748b;
  font-size: 0.86rem;
}

.commerce-home-best-deals,
.commerce-home-category-showcase {
  display: grid;
  gap: 20px;
  padding: 24px;
  border-radius: 12px;
}

.commerce-home-section-head,
.commerce-home-category-head,
.commerce-home-featured-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
}

.commerce-home-section-title {
  display: flex;
  align-items: center;
  gap: 16px;
  flex-wrap: wrap;
}

.commerce-home-countdown {
  display: inline-flex;
  align-items: center;
  gap: 10px;
  color: #475569;
  font-size: 0.88rem;
}

.commerce-home-countdown strong {
  display: inline-flex;
  min-height: 34px;
  align-items: center;
  padding: 0 12px;
  border-radius: 10px;
  background: #fde68a;
  color: #7c2d12;
}

.commerce-home-best-grid {
  display: grid;
  grid-template-columns: repeat(5, minmax(0, 1fr));
  gap: 0;
  border-radius: 0;
  overflow: hidden;
  border: 1px solid rgba(15, 23, 42, 0.08);
}

.commerce-home-best-card {
  position: relative;
  background: #fff;
  border-right: 1px solid rgba(15, 23, 42, 0.08);
  border-bottom: 1px solid rgba(15, 23, 42, 0.08);
}

.commerce-home-best-card.is-featured {
  grid-row: span 2;
}

.commerce-home-best-card-link,
.commerce-home-featured-link {
  display: grid;
  gap: 10px;
  height: 100%;
  padding: 18px;
  color: inherit;
  text-decoration: none;
}

.commerce-home-best-card img,
.commerce-home-featured-card img,
.commerce-home-category-card img {
  width: 100%;
  object-fit: contain;
  display: block;
}

.commerce-home-best-card:not(.is-featured) img {
  height: 140px;
}

.commerce-home-best-card.is-featured img {
  height: 240px;
}

.commerce-home-best-badge,
.commerce-home-featured-badge {
  display: inline-flex;
  width: fit-content;
  min-height: 24px;
  padding: 0 9px;
  align-items: center;
  border-radius: 8px;
  background: #fde68a;
  color: #7c2d12;
  font-size: 0.68rem;
  font-weight: 800;
}

.commerce-home-best-badge.is-alert,
.commerce-home-featured-badge.is-alert {
  background: #fee2e2;
  color: #b91c1c;
}

.commerce-home-best-copy,
.commerce-home-featured-card strong {
  display: grid;
  gap: 8px;
}

.commerce-home-best-copy strong,
.commerce-home-featured-card strong,
.commerce-home-category-card strong {
  color: #111827;
  line-height: 1.35;
}

.commerce-home-best-copy p {
  margin: 0;
  color: #64748b;
  line-height: 1.55;
}

.commerce-home-best-price,
.commerce-home-featured-price {
  display: flex;
  align-items: baseline;
  gap: 8px;
  flex-wrap: wrap;
}

.commerce-home-best-price span,
.commerce-home-featured-price span {
  color: #94a3b8;
  text-decoration: line-through;
}

.commerce-home-best-price strong,
.commerce-home-featured-price strong {
  color: #0f6aa3;
  font-size: 1rem;
}

.commerce-home-best-rating,
.commerce-home-featured-rating {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  color: #f59e0b;
  font-size: 0.84rem;
}

.commerce-home-best-rating small,
.commerce-home-featured-rating small {
  color: #94a3b8;
}

.commerce-home-best-actions {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 0 18px 18px;
}

.commerce-home-icon-action {
  display: inline-flex;
  width: 42px;
  height: 42px;
  align-items: center;
  justify-content: center;
  border-radius: 12px;
  border: 1px solid rgba(15, 23, 42, 0.12);
  color: #334155;
  background: #fff;
  cursor: pointer;
}

.commerce-home-primary-action {
  min-width: 140px;
}

.commerce-home-category-showcase {
  gap: 26px;
}

.commerce-home-category-head {
  justify-content: center;
}

.commerce-home-category-rail {
  display: grid;
  grid-template-columns: auto repeat(6, minmax(0, 1fr)) auto;
  gap: 12px;
  align-items: center;
}

.commerce-home-category-arrow {
  display: inline-flex;
  width: 44px;
  height: 44px;
  align-items: center;
  justify-content: center;
  border-radius: 999px;
  color: #fff;
  background: #f97316;
  font-size: 1.6rem;
  line-height: 1;
}

.commerce-home-category-card {
  display: grid;
  gap: 12px;
  justify-items: center;
  min-height: 170px;
  padding: 18px 12px;
  border-radius: 8px;
  border: 1px solid rgba(15, 23, 42, 0.08);
  color: #111827;
  text-align: center;
  text-decoration: none;
  background: #fff;
}

.commerce-home-category-card img {
  height: 92px;
}

.commerce-home-featured-block {
  display: grid;
  grid-template-columns: 280px minmax(0, 1fr);
  gap: 18px;
  align-items: start;
}

.commerce-home-featured-banner {
  position: relative;
  display: grid;
  gap: 10px;
  min-height: 100%;
  padding: 26px;
  overflow: hidden;
  border-radius: 10px;
  background: linear-gradient(180deg, #fde68a, #f8cf4b);
}

.commerce-home-featured-banner strong {
  color: #111827;
  font-size: 2rem;
  line-height: 1;
  letter-spacing: -0.04em;
}

.commerce-home-featured-banner p {
  margin: 0;
  color: rgba(17, 24, 39, 0.78);
  line-height: 1.55;
}

.commerce-home-featured-banner img {
  width: 100%;
  margin-top: 10px;
  border-radius: 18px;
  object-fit: cover;
}

.commerce-home-featured-products {
  display: grid;
  gap: 16px;
}

.commerce-home-featured-tabs {
  display: flex;
  align-items: center;
  gap: 12px;
  flex-wrap: wrap;
}

.commerce-home-featured-tabs a {
  font-size: 0.88rem;
}

.commerce-home-featured-tabs a.is-accent {
  color: #f97316;
}

.commerce-home-featured-grid {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 12px;
}

.commerce-home-featured-card {
  position: relative;
  display: grid;
  gap: 10px;
  padding: 16px;
  border-radius: 8px;
  border: 1px solid rgba(15, 23, 42, 0.08);
  background: #fff;
}

.commerce-home-featured-card img {
  height: 150px;
}

.commerce-home-featured-card strong {
  font-size: 0.95rem;
}

.commerce-home-visual-input {
  display: none;
}

@media (max-width: 1180px) {
  .commerce-home-header-bar,
  .commerce-home-hero,
  .commerce-home-featured-block,
  .commerce-home-category-rail,
  .commerce-home-best-grid,
  .commerce-home-featured-grid,
  .commerce-home-service-strip {
    grid-template-columns: 1fr;
  }

  .commerce-home-search {
    grid-template-columns: 1fr auto auto;
  }

  .commerce-home-category-rail {
    display: flex;
    overflow-x: auto;
    padding-bottom: 4px;
  }

  .commerce-home-category-arrow {
    flex: 0 0 auto;
  }
}

@media (max-width: 760px) {
  .commerce-home-page {
    gap: 22px;
  }

  .commerce-home-promo-bar,
  .commerce-home-info-bar,
  .commerce-home-header-bar,
  .commerce-home-subnav,
  .commerce-home-best-deals,
  .commerce-home-category-showcase {
    padding-left: 16px;
    padding-right: 16px;
  }

  .commerce-home-promo-bar,
  .commerce-home-info-bar,
  .commerce-home-subnav,
  .commerce-home-section-head,
  .commerce-home-featured-head {
    grid-template-columns: 1fr;
    flex-direction: column;
    align-items: flex-start;
  }

  .commerce-home-brand strong {
    font-size: 1.35rem;
  }

  .commerce-home-search {
    min-height: 52px;
  }

  .commerce-home-hero-main {
    grid-template-columns: 1fr;
    min-height: 360px;
    padding: 24px 18px 42px;
  }

  .commerce-home-hero-copy h1 {
    font-size: 1.65rem;
  }

  .commerce-home-hero-price {
    width: 72px;
    height: 72px;
    font-size: 1.1rem;
  }

  .commerce-home-side-card {
    grid-template-columns: 1fr;
  }

  .commerce-home-best-grid,
  .commerce-home-featured-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }

  .commerce-home-best-card.is-featured {
    grid-column: 1 / -1;
    grid-row: auto;
  }

  .commerce-home-best-card.is-featured img {
    height: 180px;
  }

  .commerce-home-best-actions {
    flex-wrap: wrap;
  }

  .commerce-home-category-card {
    min-width: 150px;
  }
}
</style>
