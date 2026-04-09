<script setup>
import { computed, onBeforeUnmount, onMounted, reactive, ref, watch } from "vue";
import { RouterLink, useRouter } from "vue-router";
import HomeMarketplaceCard from "../components/HomeMarketplaceCard.vue";
import PromoSlider from "../components/PromoSlider.vue";
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
});

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

  <section v-else class="collection-page home-marketplace-page" aria-label="Faqja kryesore">
    <section
      v-if="homeHeroSlides.length > 0 || homeMiniSliderCards.length > 0"
      class="home-marketplace-showcase home-marketplace-showcase--top"
      aria-label="Slideri kryesor i faqes"
    >
      <PromoSlider v-if="homeHeroSlides.length > 0" :slides="homeHeroSlides" />

      <div v-if="homeMiniSliderCards.length > 0" class="home-marketplace-feature-row" aria-label="Slideret e vegjel">
        <RouterLink
          v-for="card in homeMiniSliderCards"
          :key="`${card.label}-${card.title}`"
          class="home-marketplace-feature-card"
          :class="`is-${card.tone}`"
          :to="card.to"
        >
          <img
            :src="card.imagePath"
            :alt="card.title"
            width="420"
            height="240"
            loading="lazy"
            decoding="async"
          >
          <div class="home-marketplace-feature-copy">
            <span>{{ card.label }}</span>
            <strong>{{ card.title }}</strong>
            <small>{{ card.copy }}</small>
          </div>
        </RouterLink>
      </div>
    </section>

    <section
      id="home-marketplace-catalog"
      class="home-marketplace-section home-marketplace-catalog"
      aria-label="Produktet"
    >
      <RecommendationSections
        v-if="homeRecommendationSections.length > 0"
        :sections="homeRecommendationSections"
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
