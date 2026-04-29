<script setup>
import { computed, defineAsyncComponent, onBeforeUnmount, onMounted, reactive, ref, shallowRef, watch } from "vue";
import { RouterLink, useRouter } from "vue-router";
import MarketSectionTitle from "../components/MarketSectionTitle.vue";
import HomeProductCard from "../components/HomeProductCard.vue";
import SplitProductHero from "../components/SplitProductHero.vue";
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
import { applyDocumentSeo, buildAbsoluteUrl } from "../lib/seo";
import {
  compareState,
  ensureCompareItemsLoaded,
  toggleComparedProduct,
} from "../stores/product-compare";
import { appState, ensureSessionLoaded, markRouteReady, setCartItems } from "../stores/app-state";

const router = useRouter();
const ProductCard = defineAsyncComponent(() => import("../components/ProductCard.vue"));
const RecommendationSections = defineAsyncComponent(() => import("../components/RecommendationSections.vue"));
const heroSearchQuery = ref("");
const heroVisualSearchInputElement = ref(null);
const products = shallowRef([]);
const homeCatalogProducts = shallowRef([]);
const homeRecommendationSections = shallowRef([]);
const businesses = shallowRef([]);
const recentlyViewedProducts = shallowRef([]);
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
const homeNewsletterBenefits = [
  "Oferta reale nga produktet e publikuara",
  "Njoftime kur dalin artikuj te rinj",
  "Drop-et dhe zbritjet me te mira te javes",
];

function updateHomeSeo() {
  const featuredProducts = homeCatalogProducts.value.slice(0, 8);
  const featuredBusinesses = businesses.value.slice(0, 6);
  const description = totalProductsCount.value > 0
    ? `Marketplace me ${totalProductsCount.value} produkte publike dhe ${featuredBusinesses.length} biznese aktive ne TREGIO.`
    : "Marketplace per biznese lokale me produkte publike, porosi te sigurta dhe gjurmim te porosive ne TREGIO.";

  const jsonLd = [
    {
      "@context": "https://schema.org",
      "@type": "WebSite",
      name: "TREGIO",
      url: buildAbsoluteUrl("/"),
      potentialAction: {
        "@type": "SearchAction",
        target: `${buildAbsoluteUrl("/kerko")}?q={search_term_string}`,
        "query-input": "required name=search_term_string",
      },
    },
    {
      "@context": "https://schema.org",
      "@type": "Organization",
      name: "TREGIO",
      url: buildAbsoluteUrl("/"),
      logo: buildAbsoluteUrl("/trego-logo.webp?v=20260410"),
    },
  ];

  if (featuredProducts.length > 0) {
    jsonLd.push({
      "@context": "https://schema.org",
      "@type": "ItemList",
      name: "Featured marketplace products",
      itemListElement: featuredProducts.map((product, index) => ({
        "@type": "ListItem",
        position: index + 1,
        url: buildAbsoluteUrl(getProductDetailUrl(product.id)),
        name: String(product.title || "").trim() || `Product ${product.id}`,
      })),
    });
  }

  if (featuredBusinesses.length > 0) {
    jsonLd.push({
      "@context": "https://schema.org",
      "@type": "ItemList",
      name: "Featured marketplace businesses",
      itemListElement: featuredBusinesses.map((business, index) => ({
        "@type": "ListItem",
        position: index + 1,
        url: buildAbsoluteUrl(getBusinessProfileUrl(business.id)),
        name: String(business.businessName || "").trim() || `Business ${business.id}`,
      })),
    });
  }

  applyDocumentSeo({
    title: "TREGIO | Home",
    description,
    canonicalPath: "/",
    image: featuredProducts[0]?.imagePath || "/trego-logo.webp?v=20260410",
    jsonLd,
  });
}

watch([totalProductsCount, businesses, homeCatalogProducts], () => {
  updateHomeSeo();
}, { immediate: true });

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
const heroLeadProduct = computed(() =>
  activeCommerceHeroProduct.value
  || commerceHeroProducts.value[0]
  || marketplaceProducts.value[0]
  || homeCatalogProducts.value[0]
  || null,
);
const heroGridProducts = computed(() =>
  buildUniqueProducts(
    [
      heroLeadProduct.value,
      ...commerceHeroProducts.value,
      ...marketplaceProducts.value,
      ...homeCatalogProducts.value,
      ...products.value,
    ].filter((product) => Boolean(product?.imagePath)),
    8,
  ),
);
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
const visibleHomeRecommendationSections = computed(() => homeRecommendationSections.value);

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

  const initialDataPromises = [
    loadProducts(),
    loadHomeRecommendations(),
    loadHomeCatalogProducts(),
    loadBusinesses(),
    ensureSessionLoaded().then(async (user) => {
      if (user?.role === "business") {
        await Promise.all([loadBusinessProfile(), loadBusinessProducts()]);
      } else {
        await refreshCollectionState();
      }
    })
  ];

  try {
    await Promise.all(initialDataPromises);
  } catch (error) {
    console.error("[TREGIO] Data load failed:", error);
    statusText.value = "Produktet nuk u ngarkuan. Provoje perseri pas pak.";
  } finally {
    markRouteReady();
  }
});

onBeforeUnmount(() => {
  stopProductsPageSizeSubscription();
});

watch(
  () => commerceHeroProducts.value.length,
  (nextLength) => {
    if (commerceHeroIndex.value >= nextLength) {
      commerceHeroIndex.value = 0;
    }
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
  const payload = await fetchHomeRecommendations(16);
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
  <section
    v-if="isBusinessUser"
    class="market-page market-page--wide home-page"
    aria-label="Faqja kryesore e biznesit"
  >
    <div
      v-if="businessUi.message"
      :class="['market-status', businessUi.type === 'error' ? 'market-status--error' : '']"
      role="status"
      aria-live="polite"
    >
      {{ businessUi.message }}
    </div>

    <section class="market-card market-card--padded business-hero">
      <div class="business-hero__main">
        <div class="business-hero__identity">
          <div class="business-hero__logo">
            <img
              v-if="businessProfile?.logoPath"
              :src="businessProfile.logoPath"
              :alt="businessDisplayName"
              width="220"
              height="220"
            >
            <span v-else class="business-hero__logo-mark">
              {{ getBusinessInitials(businessDisplayName) }}
            </span>
          </div>

          <div class="business-hero__summary">
            <p class="business-hero__label">Business mode</p>
            <h1>{{ businessDisplayName }}</h1>
            <p>{{ businessDescription }}</p>
          </div>
        </div>

        <div class="business-hero__actions">
          <RouterLink class="market-button market-button--primary" to="/biznesi-juaj?view=add-product">
            Shto artikull
          </RouterLink>
          <RouterLink class="market-button market-button--secondary" to="/biznesi-juaj">
            Menaxho profilin
          </RouterLink>
          <RouterLink
            v-if="businessPublicProfileUrl"
            class="market-button market-button--secondary"
            :to="businessPublicProfileUrl"
          >
            Profili publik
          </RouterLink>
        </div>
      </div>

      <div class="metric-grid">
        <article class="metric-card">
          <p class="metric-card__label">Ndjekesit</p>
          <strong>{{ businessFollowersCount }}</strong>
          <p>Shiko si po rritet interesi per biznesin tend.</p>
        </article>

        <article class="metric-card">
          <p class="metric-card__label">Artikujt</p>
          <strong>{{ businessProductsCount }}</strong>
          <p>Te gjitha produktet qe ke publikuar ose ruajtur ne panel.</p>
        </article>

        <article class="metric-card">
          <p class="metric-card__label">Porosite</p>
          <strong>{{ businessOrdersCount }}</strong>
          <p>Numri i porosive ku jane perfshire produktet e biznesit tend.</p>
        </article>
      </div>
    </section>

    <section class="market-card market-card--padded">
      <MarketSectionTitle
        eyebrow="Workspace"
        title="Veprimet qe perdoren me shpesh"
        copy="Kalo direkt te shtimi i artikujve, porosite, mesazhet dhe profili publik pa humbur kohe ne navigim."
      />

      <div class="metric-grid">
        <RouterLink
          v-for="item in businessWorkspaceActions"
          :key="item.title"
          class="metric-card"
          :to="item.to"
        >
          <p class="metric-card__label">{{ item.title }}</p>
          <strong>{{ item.title }}</strong>
          <p>{{ item.copy }}</p>
        </RouterLink>
      </div>
    </section>

    <section class="market-card market-card--padded">
      <MarketSectionTitle
        eyebrow="Produktet e tua"
        title="Lista e artikujve"
        copy="Homepage e biznesit eshte thjeshtuar per te treguar profilin, veprimet kryesore dhe produktet qe po menaxhon."
      />

      <section v-if="businessProducts.length > 0" class="product-collection__grid" aria-label="Produktet e biznesit tend">
        <ProductCard
          v-for="product in businessProducts"
          :key="product.id"
          :product="product"
          :show-overlay-actions="false"
          :show-business-name="false"
        />
      </section>

      <div v-else class="market-empty">
        <h3>Nuk ke artikuj ende</h3>
        <p>Shto produktin e pare dhe ai do te shfaqet ketu me prezantim te paster dhe gati per blerje.</p>
      </div>
    </section>
  </section>

  <section v-else class="market-page market-page--wide home-page" aria-label="Faqja kryesore">
    <div
      v-if="ui.message"
      :class="['market-status', ui.type === 'error' ? 'market-status--error' : ui.type === 'success' ? 'market-status--success' : '']"
      role="status"
      aria-live="polite"
    >
      {{ ui.message }}
    </div>

    <SplitProductHero
      v-if="heroLeadProduct && heroGridProducts.length"
      :lead-product="heroLeadProduct"
      :products="heroGridProducts"
    />

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

    <section class="home-catalog" aria-label="Produktet">
      <header class="home-catalog__header">
        <h2 class="home-catalog__title">All product</h2>
      </header>

      <section v-if="filteredProducts.length > 0" class="home-product-grid" aria-label="Te gjitha produktet">
        <HomeProductCard
          v-for="product in filteredProducts"
          :key="product.id"
          :product="product"
          :is-wishlisted="wishlistIds.includes(product.id)"
          :is-in-cart="cartIds.includes(product.id)"
          :wishlist-busy="busyWishlistIds.includes(product.id)"
          :cart-busy="busyCartIds.includes(product.id)"
          @wishlist="handleWishlist"
          @cart="handleCart"
        />
      </section>

      <div v-else class="market-empty">
        <h3>Nuk ka produkte publike ende</h3>
        <p>Marketplace do të mbushet automatikisht sapo bizneset të publikojnë artikuj të rinj.</p>
      </div>

      <div v-if="products.length > 0 && hasMoreProducts" class="home-catalog__footer">
        <div v-if="supportsAutoLoad" ref="loadMoreSentinel" aria-hidden="true"></div>
        <p v-if="loadingMoreProducts" class="market-status market-status--compact">
          Duke ngarkuar edhe produkte...
        </p>
        <button
          v-else-if="!supportsAutoLoad"
          class="market-button market-button--secondary"
          type="button"
          :disabled="loadingMoreProducts"
          @click="loadMoreProducts"
        >
          {{ loadingMoreProducts ? "Duke ngarkuar..." : "Shih me shume" }}
        </button>
      </div>
    </section>
  </section>
</template>

<style scoped>
.home-page {
  width: min(100%, 1440px);
  margin: 0 auto;
  padding: 24px clamp(20px, 5vw, 64px) 72px;
  background: #fbfbfa;
}

.home-catalog__header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  margin-bottom: 16px;
}

.home-catalog__title {
  margin: 0;
  color: #111111;
  font-size: 22px;
  font-weight: 700;
  line-height: 1.2;
}

.home-page > * + * {
  margin-top: 48px;
}

.market-status {
  margin-bottom: 24px;
  padding: 12px 14px;
  border: 1px solid #e2e2e2;
  border-radius: 10px;
  background: #ffffff;
  color: #555555;
  font-family: "Inter", "Segoe UI", "Helvetica Neue", Arial, sans-serif;
  font-size: 14px;
  line-height: 1.5;
}

.market-status--error {
  border-color: #efc8c8;
  background: #fff8f8;
  color: #a13232;
}

.market-status--success {
  border-color: #d6ddd6;
  background: #fbfcfb;
  color: #415c47;
}

.home-product-grid {
  display: grid;
  grid-template-columns: repeat(6, minmax(0, 1fr));
  column-gap: 20px;
  row-gap: 42px;
  align-items: start;
}

.home-product-grid > * {
  width: min(100%, 190px);
  justify-self: center;
}

@media (max-width: 720px) {
  .home-page {
    padding: 16px 16px 48px;
  }

  .home-page > * + * {
    margin-top: 36px;
  }

  .home-catalog__header {
    align-items: flex-start;
    flex-direction: column;
    gap: 10px;
    margin-bottom: 14px;
  }

  .home-catalog__title {
    font-size: 20px;
  }

  .home-product-grid {
    grid-template-columns: repeat(auto-fit, minmax(148px, 1fr));
    column-gap: 12px;
    row-gap: 18px;
  }

  .home-product-grid > * {
    width: 100%;
    max-width: none;
  }
}

@media (max-width: 1180px) {
  .home-product-grid {
    grid-template-columns: repeat(5, minmax(0, 1fr));
  }
}

@media (max-width: 880px) {
  .home-product-grid {
    grid-template-columns: repeat(4, minmax(0, 1fr));
    column-gap: 16px;
    row-gap: 32px;
  }
}

@media (max-width: 540px) {
  .home-product-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
    column-gap: 12px;
    row-gap: 16px;
  }

  .home-product-grid > * {
    width: 100%;
  }
}

@media (max-width: 400px) {
  .home-product-grid {
    column-gap: 10px;
    row-gap: 14px;
  }
}

@media (max-width: 340px) {
  .home-product-grid {
    grid-template-columns: 1fr;
  }
}

</style>
