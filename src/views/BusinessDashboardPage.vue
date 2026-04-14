<script setup>
import { computed, nextTick, onBeforeUnmount, onMounted, reactive, ref, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import ProductVariantConfigurator from "../components/ProductVariantConfigurator.vue";
import {
  commitBusinessCatalogImportPreview,
  createBusinessCatalogImportPreview,
  downloadBusinessProductsImportTemplate,
  fetchBusinessCatalogImportConfig,
  requestProductAIDraft,
  requestJson,
  resolveApiMessage,
  saveBusinessCatalogImportProfile,
  saveBusinessCatalogImportSource,
  syncBusinessCatalogImportSource,
  uploadImages,
} from "../lib/api";
import {
  buildVariantInventoryFromForm,
  createEmptyProductFormState,
  deriveAudienceFromCategory,
  deriveSectionFromCategory,
  hydrateProductFormFromProduct,
  PRODUCT_PAGE_SECTION_OPTIONS,
  PRODUCT_SECTION_OPTIONS,
  PRODUCT_TYPE_OPTIONS_BY_CATEGORY,
  PRODUCT_WEIGHT_UNIT_OPTIONS,
  syncProductFormCatalogState,
} from "../lib/product-catalog";
import {
  DELIVERY_METHOD_OPTIONS,
  formatCategoryLabel,
  formatCount,
  formatDateLabel,
  formatPrice,
  formatStockQuantity,
  formatVerificationStatusLabel,
  getProductImageGallery,
} from "../lib/shop";
import { appState, ensureSessionLoaded, markRouteReady } from "../stores/app-state";

const router = useRouter();
const route = useRoute();
const businessProfile = ref(null);
const analytics = ref(null);
const promotions = ref([]);
const products = ref([]);
const productSearchQuery = ref("");
const logoFile = ref(null);
const logoPreviewUrl = ref("");
const selectedFiles = ref([]);
const previewUrls = ref([]);
const editingProduct = ref(null);
const productTitleInput = ref(null);
const importFileInput = ref(null);
const importFile = ref(null);
const importSourceType = ref("csv");
const importJsonPayload = ref("");
const importJsonRecordPath = ref("");
const importPreviewRows = ref([]);
const importPreviewHeaders = ref([]);
const importDetectedHeaders = ref([]);
const importIsPreviewLoading = ref(false);
const importIsCommitLoading = ref(false);
const importIsSyncLoading = ref(false);
const importIsConfigLoading = ref(false);
const importCurrentJob = ref(null);
const importPreview = ref(null);
const importProfiles = ref([]);
const importSources = ref([]);
const importRecentJobs = ref([]);
const importCanonicalFields = ref([]);
const importCategoryAttributeSets = ref({});
const importSelectedProfileId = ref(0);
const importSelectedSourceId = ref(0);
const importProfileDraftName = ref("");
const importSaveProfile = ref(false);
const importSkippedRowIds = ref([]);
const importApprovedGroupKeys = ref([]);
const importMapping = reactive({});
const activeSection = ref("analytics");
const importApiSource = reactive({
  sourceName: "",
  url: "",
  method: "GET",
  recordPath: "",
  headersText: "",
  bodyText: "",
  syncEnabled: true,
  syncIntervalMinutes: "60",
});
const showVerifiedProfileEditor = ref(false);
const selectedProductIds = ref([]);
const productCategoryFilter = ref("");
const productStockFilter = ref("all");
const productStatusFilter = ref("all");
const productSort = ref("updated-desc");
const bulkCategoryValue = ref("");
const bulkStockValue = ref("");
const promotionForm = reactive({
  code: "",
  title: "",
  description: "",
  discountType: "percent",
  discountValue: "",
  minimumSubtotal: "",
  usageLimit: "",
  perUserLimit: "1",
  pageSection: "",
  category: "",
  startsAt: "",
  endsAt: "",
  isActive: true,
});
const STOCK_ALERT_THRESHOLD = 5;

function createDefaultShippingForm() {
  const standardOption = DELIVERY_METHOD_OPTIONS.find((option) => option.value === "standard");
  const expressOption = DELIVERY_METHOD_OPTIONS.find((option) => option.value === "express");
  const pickupOption = DELIVERY_METHOD_OPTIONS.find((option) => option.value === "pickup");

  return {
    standardEnabled: true,
    standardFee: String(standardOption?.shippingAmount ?? 2.5),
    standardEta: String(standardOption?.estimatedDeliveryText || "2-4 dite pune"),
    expressEnabled: true,
    expressFee: String(expressOption?.shippingAmount ?? 4.9),
    expressEta: String(expressOption?.estimatedDeliveryText || "1-2 dite pune"),
    pickupEnabled: true,
    pickupEta: String(pickupOption?.estimatedDeliveryText || "Gati per terheqje brenda 24 oresh"),
    pickupAddress: "",
    pickupHours: "Kontakto biznesin per orarin",
    pickupMapUrl: "",
    cityRates: [],
    halfOffThreshold: "120",
    freeShippingThreshold: "180",
  };
}

function createEmptyCityRate(rate = null) {
  return {
    city: String(rate?.city || ""),
    surcharge: String(rate?.surcharge ?? ""),
  };
}

const profileForm = reactive({
  businessName: "",
  businessDescription: "",
  businessNumber: "",
  phoneNumber: "",
  supportEmail: "",
  websiteUrl: "",
  supportHours: "",
  returnPolicySummary: "",
  city: "",
  addressLine: "",
  businessLogoPath: "",
});
const shippingForm = reactive(createDefaultShippingForm());

const productForm = reactive(createEmptyProductFormState());
const productFormStep = ref("details");
const ui = reactive({
  accessNote: "Po kontrollohet aksesimi i biznesit...",
  profileMessage: "",
  profileType: "",
  productMessage: "",
  productTypeMessage: "",
  listMessage: "",
  listType: "",
  importMessage: "",
  importType: "",
  productAiBusy: false,
  promotionMessage: "",
  promotionType: "",
  shippingMessage: "",
  shippingType: "",
});
const importSummary = reactive({
  totalRows: 0,
  validRows: 0,
  invalidRows: 0,
  warnings: [],
  parentProducts: 0,
  warningsCount: 0,
  hardErrorsCount: 0,
});

const productPreviewItems = computed(() => {
  if (previewUrls.value.length > 0) {
    return previewUrls.value.map((path, index) => ({
      path,
      label: index === 0 ? "Cover" : `Foto ${index + 1}`,
    }));
  }
  return productForm.imageGallery.map((path, index) => ({
    path,
    label: index === 0 ? "Cover aktual" : `Foto aktuale ${index + 1}`,
  }));
});
const businessLogoPreview = computed(() => logoPreviewUrl.value || profileForm.businessLogoPath || "");
const productVariantEntries = computed(() => buildVariantInventoryFromForm(productForm));
const productMediaCount = computed(() => productPreviewItems.value.length);
const productStockTotal = computed(() =>
  productVariantEntries.value.reduce((total, entry) => total + Math.max(0, Number(entry.quantity || 0)), 0),
);
const productPriceValue = computed(() => Number(productForm.price || 0));
const productCompareAtPriceValue = computed(() => Number(productForm.compareAtPrice || 0));
const productDiscountPercent = computed(() => {
  if (!Number.isFinite(productPriceValue.value) || !Number.isFinite(productCompareAtPriceValue.value) || productPriceValue.value <= 0) {
    return 0;
  }
  if (productCompareAtPriceValue.value <= productPriceValue.value) {
    return 0;
  }
  return Math.max(0, Math.round(((productCompareAtPriceValue.value - productPriceValue.value) / productCompareAtPriceValue.value) * 100));
});
const productPricingReady = computed(() => {
  if (!Number.isFinite(productPriceValue.value) || productPriceValue.value <= 0) {
    return false;
  }
  if (!productCompareAtPriceValue.value) {
    return true;
  }
  if (productCompareAtPriceValue.value <= productPriceValue.value) {
    return false;
  }
  if (!String(productForm.saleEndsAt || "").trim()) {
    return true;
  }
  return Number.isFinite(Date.parse(String(productForm.saleEndsAt || "")));
});
const productChecklist = computed(() => ([
  {
    key: "title",
    label: "Titull + pershkrim",
    done: Boolean(String(productForm.title || "").trim() && String(productForm.description || "").trim()),
  },
  {
    key: "pricing",
    label: "Cmim valid",
    done: productPricingReady.value,
  },
  {
    key: "variants",
    label: "Variantet / stoku",
    done: productStockTotal.value > 0,
  },
  {
    key: "media",
    label: "Foto te produktit",
    done: productMediaCount.value > 0,
  },
]));
const productReadyToSave = computed(() => productChecklist.value.every((item) => item.done));
const productFormSteps = computed(() => ([
  {
    id: "details",
    label: "Detajet",
    caption: "Titull, kategori, copy",
    done: productChecklist.value.find((item) => item.key === "title")?.done,
  },
  {
    id: "pricing",
    label: "Cmimi",
    caption: "Cmim dhe sale",
    done: productChecklist.value.find((item) => item.key === "pricing")?.done,
  },
  {
    id: "variants",
    label: "Variantet",
    caption: "Opsione dhe stok",
    done: productChecklist.value.find((item) => item.key === "variants")?.done,
  },
  {
    id: "media",
    label: "Media",
    caption: "Cover dhe galeri",
    done: productChecklist.value.find((item) => item.key === "media")?.done,
  },
  {
    id: "review",
    label: "Preview",
    caption: "Check final",
    done: productReadyToSave.value,
  },
]));
const productPreviewCover = computed(() => productPreviewItems.value[0]?.path || "");
const filteredProducts = computed(() => {
  const normalizedQuery = String(productSearchQuery.value || "").trim().toLowerCase();
  let nextProducts = [...products.value];

  const scoreProductMatch = (product) => {
    const articleNumber = String(product.articleNumber || "").trim().toLowerCase();
    const title = String(product.title || "").trim().toLowerCase();
    const category = String(product.category || "").trim().toLowerCase();
    const productType = String(product.productType || "").trim().toLowerCase();
    const description = String(product.description || "").trim().toLowerCase();

    if (articleNumber.startsWith(normalizedQuery)) {
      return 0;
    }
    if (title.startsWith(normalizedQuery)) {
      return 1;
    }
    if (articleNumber.includes(normalizedQuery)) {
      return 2;
    }
    if (title.includes(normalizedQuery)) {
      return 3;
    }
    if (category.includes(normalizedQuery)) {
      return 4;
    }
    if (productType.includes(normalizedQuery)) {
      return 5;
    }
    if (description.includes(normalizedQuery)) {
      return 6;
    }
    return 99;
  };

  if (normalizedQuery) {
    nextProducts = nextProducts
      .map((product) => ({ product, score: scoreProductMatch(product) }))
      .filter((entry) => entry.score < 99)
      .sort((left, right) =>
        left.score - right.score
        || String(left.product.title || "").localeCompare(String(right.product.title || ""))
      )
      .map((entry) => entry.product);
  }

  if (productCategoryFilter.value) {
    nextProducts = nextProducts.filter((product) =>
      String(product.category || "").trim().toLowerCase() === productCategoryFilter.value,
    );
  }

  if (productStockFilter.value === "in-stock") {
    nextProducts = nextProducts.filter((product) => Number(product.stockQuantity || 0) > 0);
  } else if (productStockFilter.value === "low-stock") {
    nextProducts = nextProducts.filter((product) => {
      const stock = Number(product.stockQuantity || 0);
      return stock > 0 && stock <= STOCK_ALERT_THRESHOLD;
    });
  } else if (productStockFilter.value === "out-of-stock") {
    nextProducts = nextProducts.filter((product) => Number(product.stockQuantity || 0) <= 0);
  }

  if (productStatusFilter.value === "public") {
    nextProducts = nextProducts.filter((product) => Boolean(product.isPublic));
  } else if (productStatusFilter.value === "hidden") {
    nextProducts = nextProducts.filter((product) => !product.isPublic);
  }

  nextProducts.sort((left, right) => {
    const leftPrice = Number(left.price || 0);
    const rightPrice = Number(right.price || 0);
    const leftStock = Number(left.stockQuantity || 0);
    const rightStock = Number(right.stockQuantity || 0);
    const leftTitle = String(left.title || "");
    const rightTitle = String(right.title || "");
    const leftDate = Date.parse(String(left.createdAt || left.updatedAt || 0));
    const rightDate = Date.parse(String(right.createdAt || right.updatedAt || 0));

    if (productSort.value === "price-asc") {
      return leftPrice - rightPrice || leftTitle.localeCompare(rightTitle);
    }
    if (productSort.value === "price-desc") {
      return rightPrice - leftPrice || leftTitle.localeCompare(rightTitle);
    }
    if (productSort.value === "stock-asc") {
      return leftStock - rightStock || leftTitle.localeCompare(rightTitle);
    }
    if (productSort.value === "stock-desc") {
      return rightStock - leftStock || leftTitle.localeCompare(rightTitle);
    }
    if (productSort.value === "title-asc") {
      return leftTitle.localeCompare(rightTitle);
    }
    if (productSort.value === "title-desc") {
      return rightTitle.localeCompare(leftTitle);
    }
    return (Number.isFinite(rightDate) ? rightDate : 0) - (Number.isFinite(leftDate) ? leftDate : 0);
  });

  return nextProducts;
});
const selectedProducts = computed(() => {
  const selectedIds = new Set(selectedProductIds.value);
  return products.value.filter((product) => selectedIds.has(Number(product.id || 0)));
});
const hasSelectedProducts = computed(() => selectedProducts.value.length > 0);
const productCategoryOptions = computed(() => {
  const categories = new Map();
  PRODUCT_SECTION_OPTIONS.forEach((option) => {
    categories.set(String(option.value || "").trim().toLowerCase(), option.label);
  });
  return Array.from(categories.entries()).map(([value, label]) => ({ value, label }));
});

const lowStockProducts = computed(() =>
  products.value.filter((product) => {
    const stockQuantity = Number(product.stockQuantity || 0);
    return stockQuantity > 0 && stockQuantity <= STOCK_ALERT_THRESHOLD;
  }),
);
const outOfStockProducts = computed(() =>
  products.value.filter((product) => Number(product.stockQuantity || 0) <= 0),
);
const stockAlertProducts = computed(() => [...outOfStockProducts.value, ...lowStockProducts.value].slice(0, 6));
const stockAlertCount = computed(() => outOfStockProducts.value.length + lowStockProducts.value.length);
const engagementSummaryItems = computed(() => ([
  { label: "Views", value: formatCount(analytics.value?.viewsCount || 0) },
  { label: "Wishlist", value: formatCount(analytics.value?.wishlistCount || 0) },
  { label: "Cart", value: formatCount(analytics.value?.cartCount || 0) },
  { label: "Share", value: formatCount(analytics.value?.shareCount || 0) },
]));

const promotionCategoryOptions = computed(() => {
  if (!promotionForm.pageSection) {
    return PRODUCT_SECTION_OPTIONS;
  }

  return PRODUCT_SECTION_OPTIONS.filter(
    (option) => deriveSectionFromCategory(option.value) === promotionForm.pageSection,
  );
});

const isBusinessVerified = computed(
  () => String(businessProfile.value?.verificationStatus || "").trim().toLowerCase() === "verified",
);
const profileEditAccessStatus = computed(
  () => String(businessProfile.value?.profileEditAccessStatus || "locked").trim().toLowerCase(),
);
const canManageCatalog = computed(() => Boolean(businessProfile.value) && isBusinessVerified.value);
const importFieldList = computed(() =>
  importCanonicalFields.value.length
    ? importCanonicalFields.value
    : ["title", "description", "price", "stock", "category", "sku", "image", "color", "size"],
);
const selectedImportProfile = computed(() =>
  importProfiles.value.find((profile) => Number(profile.id || 0) === Number(importSelectedProfileId.value || 0)) || null,
);
const selectedImportSource = computed(() =>
  importSources.value.find((source) => Number(source.id || 0) === Number(importSelectedSourceId.value || 0)) || null,
);
const importPreviewRecords = computed(() => Array.isArray(importPreview.value?.records) ? importPreview.value.records : []);
const importPreviewGroups = computed(() => Array.isArray(importPreview.value?.groups) ? importPreview.value.groups : []);
const importPreviewHasChanges = computed(() => Boolean(importCurrentJob.value?.id) && Boolean(importPreview.value));
const shouldShowProfileCard = computed(
  () => !businessProfile.value || !isBusinessVerified.value || showVerifiedProfileEditor.value,
);
const dashboardSections = computed(() => ([
  {
    key: "analytics",
    label: "Analytics",
    navLabel: "Dashboard",
    visible: true,
  },
  {
    key: "stock",
    label: "Stoku",
    navLabel: "Stock",
    visible: canManageCatalog.value,
  },
  {
    key: "shipping",
    label: "Transport",
    navLabel: "Shipping",
    visible: canManageCatalog.value,
  },
  {
    key: "add-product",
    label: "Shto",
    navLabel: "Add",
    visible: canManageCatalog.value,
  },
  {
    key: "import",
    label: "Import",
    navLabel: "Import",
    visible: canManageCatalog.value,
  },
  {
    key: "offers",
    label: "Ofertat",
    navLabel: "Offers",
    visible: canManageCatalog.value,
  },
  {
    key: "products",
    label: "Produktet",
    navLabel: "Products",
    visible: canManageCatalog.value,
  },
  {
    key: "profile",
    label: "Profili",
    navLabel: "Settings",
    visible: shouldShowProfileCard.value,
  },
]).filter((section) => section.visible));
const activeSectionMeta = computed(() =>
  dashboardSections.value.find((section) => section.key === activeSection.value) || dashboardSections.value[0] || null,
);
const dashboardSidebarSections = computed(() => dashboardSections.value.filter((section) =>
  ["analytics", "products", "stock", "import", "offers", "profile"].includes(section.key),
));
const dashboardMetrics = computed(() => {
  if (!analytics.value) {
    return [];
  }

  return [
    {
      key: "sales",
      label: "Total Sales",
      value: formatPrice(analytics.value.grossSales || 0),
      meta: `${formatCount(analytics.value.unitsSold || 0)} sold`,
      tone: "violet",
    },
    {
      key: "orders",
      label: "Orders",
      value: formatCount(analytics.value.orderItems || 0),
      meta: `${formatPrice(analytics.value.readyPayout || 0)} ready`,
      tone: "mint",
    },
    {
      key: "stock",
      label: "Low Stock",
      value: formatCount(stockAlertCount.value || 0),
      meta: `${formatCount(outOfStockProducts.value.length || 0)} out`,
      tone: "amber",
    },
    {
      key: "products",
      label: "Products",
      value: formatCount(analytics.value.totalProducts || 0),
      meta: `${formatCount(analytics.value.publicProducts || 0)} live`,
      tone: "blue",
    },
  ];
});
const dashboardQuickActions = computed(() => [
  { key: "add-product", label: "Add Product", tone: "violet" },
  { key: "import", label: "Import", tone: "mint" },
  { key: "stock", label: "Manage Stock", tone: "amber" },
  { key: "offers", label: "Discount", tone: "pink" },
]);
const recentDashboardProducts = computed(() => products.value.slice(0, 4));
const recentDiscounts = computed(() => promotions.value.slice(0, 3));
const dashboardDateRangeLabel = computed(() => {
  const now = new Date();
  const monthLabel = now.toLocaleDateString("en-US", { month: "short" });
  const year = now.getFullYear();
  const lastDay = new Date(year, now.getMonth() + 1, 0).getDate();
  return `${monthLabel} 1 - ${monthLabel} ${lastDay}`;
});
const dashboardAvatarLabel = computed(() => {
  const businessName = String(profileForm.businessName || businessProfile.value?.businessName || "").trim();
  if (businessName) {
    return businessName
      .split(/\s+/)
      .slice(0, 2)
      .map((chunk) => chunk.charAt(0).toUpperCase())
      .join("");
  }

  const currentUser = appState.currentUser || {};
  const email = String(currentUser.email || "").trim();
  if (email) {
    return email.slice(0, 2).toUpperCase();
  }
  return "BP";
});
const dashboardChartLabels = computed(() => {
  const base = new Date();
  return Array.from({ length: 7 }, (_, index) => {
    const nextDate = new Date(base);
    nextDate.setDate(base.getDate() - (6 - index));
    return nextDate.toLocaleDateString("en-US", { month: "short", day: "numeric" });
  });
});
const dashboardChartValues = computed(() => {
  if (!analytics.value) {
    return [420, 560, 740, 470, 710, 640, 860];
  }

  const seeds = [
    Number(analytics.value.grossSales || 0),
    Number(analytics.value.sellerEarnings || 0),
    Number(analytics.value.readyPayout || 0),
    Number(analytics.value.pendingPayout || 0),
    Number(analytics.value.viewsCount || 0),
    Number(analytics.value.wishlistCount || 0),
    Number(analytics.value.cartCount || 0),
  ];
  const maxSeed = Math.max(...seeds, 1);
  return seeds.map((value, index) => {
    const normalized = 260 + (value / maxSeed) * 560;
    return Math.round(normalized + ((index % 2 === 0 ? 1 : -1) * 35));
  });
});
const dashboardChartPoints = computed(() => {
  const values = dashboardChartValues.value;
  const width = 640;
  const height = 220;
  const paddingX = 18;
  const paddingY = 18;
  const minValue = Math.min(...values);
  const maxValue = Math.max(...values);
  const valueRange = Math.max(maxValue - minValue, 1);
  return values.map((value, index) => {
    const x = paddingX + (index * (width - paddingX * 2)) / Math.max(values.length - 1, 1);
    const y = height - paddingY - ((value - minValue) / valueRange) * (height - paddingY * 2);
    return { x, y, value };
  });
});
const dashboardChartLinePath = computed(() => {
  const points = dashboardChartPoints.value;
  if (!points.length) {
    return "";
  }
  return points.map((point, index) => `${index === 0 ? "M" : "L"} ${point.x} ${point.y}`).join(" ");
});
const dashboardChartAreaPath = computed(() => {
  const points = dashboardChartPoints.value;
  if (!points.length) {
    return "";
  }
  const firstPoint = points[0];
  const lastPoint = points[points.length - 1];
  return `${dashboardChartLinePath.value} L ${lastPoint.x} 220 L ${firstPoint.x} 220 Z`;
});

function formatPromotionSectionLabel(sectionValue) {
  const match = PRODUCT_PAGE_SECTION_OPTIONS.find((option) => option.value === String(sectionValue || "").trim().toLowerCase());
  return match?.label || String(sectionValue || "").trim();
}

function getStockAlertLabel(product) {
  const stockQuantity = Number(product?.stockQuantity || 0);
  if (stockQuantity <= 0) {
    return "Stok i mbaruar";
  }

  if (stockQuantity <= STOCK_ALERT_THRESHOLD) {
    return `Stok i ulet • ${formatStockQuantity(stockQuantity)}`;
  }

  return `Stok • ${formatStockQuantity(stockQuantity)}`;
}

function handleDashboardQuickAction(actionKey) {
  if (actionKey === "add-product") {
    openAddProductForm();
    return;
  }
  setActiveSection(actionKey);
}

function setActiveSection(sectionKey) {
  if (!dashboardSections.value.some((section) => section.key === sectionKey)) {
    return;
  }
  activeSection.value = sectionKey;
}

onMounted(async () => {
  try {
    const user = await ensureSessionLoaded();
    if (!user) {
      router.replace("/login");
      return;
    }

    if (user.role === "admin") {
      router.replace("/admin-products");
      return;
    }

    if (user.role !== "business") {
      router.replace("/");
      return;
    }

    ui.accessNote = "Je kyçur si biznes. Ketu mund ta menaxhosh profilin dhe katalogun tend sipas statusit te verifikimit.";
    await loadBusinessProfile();
    await Promise.all([
      loadBusinessAnalytics(),
      canManageCatalog.value ? loadProducts() : Promise.resolve(),
      canManageCatalog.value ? loadPromotions() : Promise.resolve(),
      canManageCatalog.value ? loadCatalogImportConfig() : Promise.resolve(),
    ]);
    activeSection.value = !canManageCatalog.value && shouldShowProfileCard.value
      ? "profile"
      : "analytics";
    await handleRouteView();
  } finally {
    markRouteReady();
  }
});

watch(
  dashboardSections,
  (sections) => {
    if (sections.some((section) => section.key === activeSection.value)) {
      return;
    }
    activeSection.value = sections[0]?.key || "analytics";
  },
  { immediate: true },
);

watch(
  () => route.query.view,
  async (view) => {
    if (view === "add-product") {
      await handleRouteView();
    }
  },
);

watch(
  () => importSelectedProfileId.value,
  (profileId) => {
    const profile = importProfiles.value.find((item) => Number(item.id || 0) === Number(profileId || 0)) || null;
    if (!profile) {
      replaceImportMapping({});
      return;
    }

    importProfileDraftName.value = String(profile.profileName || "").trim();
    if (!importPreview.value) {
      replaceImportMapping(profile.fieldMapping || {});
    }
  },
);

watch(
  () => importSelectedSourceId.value,
  (sourceId) => {
    const source = importSources.value.find((item) => Number(item.id || 0) === Number(sourceId || 0)) || null;
    if (!source) {
      return;
    }

    importSourceType.value = String(source.sourceType || "api-json").trim().toLowerCase() || "api-json";
    importApiSource.sourceName = String(source.sourceName || "").trim();
    importApiSource.url = String(source.sourceConfig?.url || "").trim();
    importApiSource.method = String(source.sourceConfig?.method || "GET").trim().toUpperCase();
    importApiSource.recordPath = String(source.sourceConfig?.recordPath || "").trim();
    importApiSource.headersText = Object.keys(source.sourceConfig?.headers || {}).length
      ? JSON.stringify(source.sourceConfig.headers, null, 2)
      : "";
    importApiSource.bodyText = source.sourceConfig?.body != null
      ? JSON.stringify(source.sourceConfig.body, null, 2)
      : "";
    importApiSource.syncEnabled = Boolean(source.syncEnabled);
    importApiSource.syncIntervalMinutes = String(source.syncIntervalMinutes || "60");
    if (Number(source.profileId || 0) > 0) {
      importSelectedProfileId.value = Number(source.profileId || 0);
    }
  },
);

onBeforeUnmount(() => {
  revokeLogoPreview();
  revokePreviewUrls();
});

watch(
  () => promotionForm.pageSection,
  (nextSection) => {
    if (!nextSection) {
      promotionForm.category = "";
      return;
    }

    if (!promotionCategoryOptions.value.some((option) => option.value === promotionForm.category)) {
      promotionForm.category = "";
    }
  },
);

function revokeLogoPreview() {
  if (logoPreviewUrl.value) {
    URL.revokeObjectURL(logoPreviewUrl.value);
    logoPreviewUrl.value = "";
  }
}

function revokePreviewUrls() {
  previewUrls.value.forEach((url) => URL.revokeObjectURL(url));
  previewUrls.value = [];
}

async function loadBusinessProfile() {
  const { response, data } = await requestJson("/api/business-profile");
  if (!response.ok || !data?.ok) {
    ui.profileMessage = resolveApiMessage(data, "Biznesi nuk u ngarkua.");
    ui.profileType = "error";
    return;
  }

  businessProfile.value = data.profile || null;
  hydrateProfileForm(businessProfile.value);
  hydrateShippingForm(businessProfile.value?.shippingSettings || null, businessProfile.value);
  if (!isBusinessVerified.value || profileEditAccessStatus.value !== "approved") {
    showVerifiedProfileEditor.value = false;
  }
}

async function requestVerificationReview() {
  const { response, data } = await requestJson("/api/business-profile/verification-request", {
    method: "POST",
  });

  if (!response.ok || !data?.ok) {
    ui.profileMessage = resolveApiMessage(data, "Kerkesa per verifikim nuk u dergua.");
    ui.profileType = "error";
    return;
  }

  businessProfile.value = data.profile || businessProfile.value;
  if (businessProfile.value) {
    hydrateProfileForm(businessProfile.value);
    hydrateShippingForm(businessProfile.value?.shippingSettings || null, businessProfile.value);
  }
  ui.profileMessage = data.message || "Kerkesa per verifikim u dergua.";
  ui.profileType = "success";
}

async function requestBusinessProfileEditAccess() {
  const { response, data } = await requestJson("/api/business-profile/edit-request", {
    method: "POST",
  });

  if (!response.ok || !data?.ok) {
    ui.profileMessage = resolveApiMessage(data, "Kerkesa per editim nuk u dergua.");
    ui.profileType = "error";
    return;
  }

  businessProfile.value = data.profile || businessProfile.value;
  if (businessProfile.value) {
    hydrateProfileForm(businessProfile.value);
    hydrateShippingForm(businessProfile.value?.shippingSettings || null, businessProfile.value);
  }
  ui.profileMessage = data.message || "Kerkesa per editim u dergua te admini.";
  ui.profileType = "success";
}

async function handleBusinessEditButton() {
  if (!businessProfile.value || !isBusinessVerified.value) {
    return;
  }

  if (profileEditAccessStatus.value === "approved") {
    showVerifiedProfileEditor.value = true;
    setActiveSection("profile");
    ui.profileMessage = "Admini e ka aprovuar editimin. Tani mund t'i ruash ndryshimet.";
    ui.profileType = "success";
    await nextTick();
    return;
  }

  await requestBusinessProfileEditAccess();
}

function hydrateProfileForm(profile) {
  profileForm.businessName = String(profile?.businessName || "");
  profileForm.businessDescription = String(profile?.businessDescription || "");
  profileForm.businessNumber = String(profile?.businessNumber || "");
  profileForm.phoneNumber = String(profile?.phoneNumber || "");
  profileForm.supportEmail = String(profile?.supportEmail || "");
  profileForm.websiteUrl = String(profile?.websiteUrl || "");
  profileForm.supportHours = String(profile?.supportHours || "");
  profileForm.returnPolicySummary = String(profile?.returnPolicySummary || "");
  profileForm.city = String(profile?.city || "");
  profileForm.addressLine = String(profile?.addressLine || "");
  profileForm.businessLogoPath = String(profile?.logoPath || "");
  logoFile.value = null;
  revokeLogoPreview();
}

function hydrateShippingForm(settings, profile = null) {
  const defaults = createDefaultShippingForm();
  shippingForm.standardEnabled = settings?.standardEnabled ?? defaults.standardEnabled;
  shippingForm.standardFee = String(settings?.standardFee ?? defaults.standardFee);
  shippingForm.standardEta = String(settings?.standardEta ?? defaults.standardEta);
  shippingForm.expressEnabled = settings?.expressEnabled ?? defaults.expressEnabled;
  shippingForm.expressFee = String(settings?.expressFee ?? defaults.expressFee);
  shippingForm.expressEta = String(settings?.expressEta ?? defaults.expressEta);
  shippingForm.pickupEnabled = settings?.pickupEnabled ?? defaults.pickupEnabled;
  shippingForm.pickupEta = String(settings?.pickupEta ?? defaults.pickupEta);
  shippingForm.pickupAddress = String(settings?.pickupAddress || profile?.addressLine || defaults.pickupAddress);
  shippingForm.pickupHours = String(settings?.pickupHours ?? defaults.pickupHours);
  shippingForm.pickupMapUrl = String(settings?.pickupMapUrl ?? defaults.pickupMapUrl);
  shippingForm.cityRates = Array.isArray(settings?.cityRates) && settings.cityRates.length > 0
    ? settings.cityRates.map((rate) => createEmptyCityRate(rate))
    : [createEmptyCityRate()];
  shippingForm.halfOffThreshold = String(settings?.halfOffThreshold ?? defaults.halfOffThreshold);
  shippingForm.freeShippingThreshold = String(settings?.freeShippingThreshold ?? defaults.freeShippingThreshold);
}

function addShippingCityRate() {
  shippingForm.cityRates.push(createEmptyCityRate());
}

function removeShippingCityRate(index) {
  if (shippingForm.cityRates.length <= 1) {
    shippingForm.cityRates.splice(0, shippingForm.cityRates.length, createEmptyCityRate());
    return;
  }
  shippingForm.cityRates.splice(index, 1);
}

async function saveBusinessProfile() {
  let logoPath = profileForm.businessLogoPath;
  if (logoFile.value) {
    const uploadResult = await uploadImages([logoFile.value]);
    if (!uploadResult.ok) {
      ui.profileMessage = uploadResult.message;
      ui.profileType = "error";
      return;
    }
    logoPath = uploadResult.paths[0] || "";
  }

  const payload = {
    businessName: profileForm.businessName.trim(),
    businessDescription: profileForm.businessDescription.trim(),
    businessNumber: profileForm.businessNumber.trim(),
    businessLogoPath: logoPath,
    phoneNumber: profileForm.phoneNumber.trim(),
    supportEmail: profileForm.supportEmail.trim(),
    websiteUrl: profileForm.websiteUrl.trim(),
    supportHours: profileForm.supportHours.trim(),
    returnPolicySummary: profileForm.returnPolicySummary.trim(),
    city: profileForm.city.trim(),
    addressLine: profileForm.addressLine.trim(),
  };

  const { response, data } = await requestJson("/api/business-profile", {
    method: "POST",
    body: JSON.stringify(payload),
  });

  if (!response.ok || !data?.ok || !data.profile) {
    ui.profileMessage = resolveApiMessage(data, "Biznesi nuk u ruajt.");
    ui.profileType = "error";
    return;
  }

  businessProfile.value = data.profile;
  hydrateProfileForm(data.profile);
  hydrateShippingForm(data.profile?.shippingSettings || null, data.profile);
  showVerifiedProfileEditor.value = false;
  ui.profileMessage = data.message || "Biznesi u ruajt me sukses.";
  ui.profileType = "success";
}

async function saveShippingSettings() {
  ui.shippingMessage = "";
  ui.shippingType = "";

  const payload = {
    shippingSettings: {
      standardEnabled: Boolean(shippingForm.standardEnabled),
      standardFee: shippingForm.standardFee,
      standardEta: shippingForm.standardEta.trim(),
      expressEnabled: Boolean(shippingForm.expressEnabled),
      expressFee: shippingForm.expressFee,
      expressEta: shippingForm.expressEta.trim(),
      pickupEnabled: Boolean(shippingForm.pickupEnabled),
      pickupEta: shippingForm.pickupEta.trim(),
      pickupAddress: shippingForm.pickupAddress.trim(),
      pickupHours: shippingForm.pickupHours.trim(),
      pickupMapUrl: shippingForm.pickupMapUrl.trim(),
      cityRates: shippingForm.cityRates.map((rate) => ({
        city: String(rate.city || "").trim(),
        surcharge: String(rate.surcharge ?? "").trim(),
      })),
      halfOffThreshold: shippingForm.halfOffThreshold,
      freeShippingThreshold: shippingForm.freeShippingThreshold,
    },
  };

  const { response, data } = await requestJson("/api/business-profile/shipping", {
    method: "POST",
    body: JSON.stringify(payload),
  });

  if (!response.ok || !data?.ok || !data.profile) {
    ui.shippingMessage = resolveApiMessage(data, "Transporti nuk u ruajt.");
    ui.shippingType = "error";
    return;
  }

  businessProfile.value = data.profile;
  hydrateShippingForm(data.profile?.shippingSettings || null, data.profile);
  ui.shippingMessage = data.message || "Transporti u ruajt.";
  ui.shippingType = "success";
}

function handleLogoChange(event) {
  revokeLogoPreview();
  logoFile.value = event.target.files?.[0] || null;
  if (logoFile.value) {
    logoPreviewUrl.value = URL.createObjectURL(logoFile.value);
  }
}

async function loadProducts() {
  const { response, data } = await requestJson("/api/business/products");
  if (!response.ok || !data?.ok) {
    ui.listMessage = resolveApiMessage(data, "Lista e artikujve nuk u ngarkua.");
    ui.listType = "error";
    products.value = [];
    return;
  }

  products.value = Array.isArray(data.products) ? data.products : [];
  const nextIds = new Set(products.value.map((product) => Number(product.id || 0)));
  selectedProductIds.value = selectedProductIds.value.filter((id) => nextIds.has(id));
  ui.listMessage = "";
  ui.listType = "";
}

async function loadBusinessAnalytics() {
  const { response, data } = await requestJson("/api/business/analytics");
  if (!response.ok || !data?.ok) {
    analytics.value = null;
    return;
  }
  analytics.value = data.analytics || null;
}

async function loadPromotions() {
  const { response, data } = await requestJson("/api/business/promotions");
  if (!response.ok || !data?.ok) {
    promotions.value = [];
    return;
  }
  promotions.value = Array.isArray(data.promotions) ? data.promotions : [];
}

function resetPromotionForm() {
  promotionForm.code = "";
  promotionForm.title = "";
  promotionForm.description = "";
  promotionForm.discountType = "percent";
  promotionForm.discountValue = "";
  promotionForm.minimumSubtotal = "";
  promotionForm.usageLimit = "";
  promotionForm.perUserLimit = "1";
  promotionForm.pageSection = "";
  promotionForm.category = "";
  promotionForm.startsAt = "";
  promotionForm.endsAt = "";
  promotionForm.isActive = true;
}

function resetProductForm() {
  Object.assign(productForm, createEmptyProductFormState());
  productFormStep.value = "details";
  editingProduct.value = null;
  selectedFiles.value = [];
  revokePreviewUrls();
  ui.productMessage = "";
  ui.productTypeMessage = "";
}

function focusProductFormStep(stepId = "details") {
  productFormStep.value = stepId;
  const target = typeof document !== "undefined"
    ? document.getElementById(`business-product-step-${stepId}`)
    : null;
  if (target) {
    target.scrollIntoView({ behavior: "smooth", block: "start" });
  }
}

async function handleRouteView() {
  if (String(route.query.view || "").trim() !== "add-product") {
    return;
  }

  if (!canManageCatalog.value) {
    return;
  }

  setActiveSection("add-product");
  resetProductForm();
  await nextTick();
  window.setTimeout(() => {
    focusProductFormStep("details");
    productTitleInput.value?.focus?.();
  }, 120);
}

async function openAddProductForm() {
  if (!canManageCatalog.value) {
    return;
  }

  setActiveSection("add-product");
  resetProductForm();
  await nextTick();
  window.setTimeout(() => {
    focusProductFormStep("details");
    productTitleInput.value?.focus?.();
  }, 120);
}

function beginProductEdit(product) {
  setActiveSection("add-product");
  editingProduct.value = product;
  hydrateProductFormFromProduct(productForm, {
    ...product,
    imageGallery: getProductImageGallery(product),
  });
  selectedFiles.value = [];
  revokePreviewUrls();
  syncProductFormCatalogState(productForm);
  productFormStep.value = "details";
  ui.productMessage = `Po editon artikullin "${product.title}".`;
  ui.productTypeMessage = "success";
}

function handleFilesChange(event) {
  revokePreviewUrls();
  selectedFiles.value = Array.from(event.target.files || []);
  previewUrls.value = selectedFiles.value.map((file) => URL.createObjectURL(file));
}

function formatImportFieldLabel(fieldName) {
  return String(fieldName || "")
    .replace(/([a-z])([A-Z])/g, "$1 $2")
    .replace(/[_-]+/g, " ")
    .replace(/\b\w/g, (match) => match.toUpperCase())
    .trim();
}

function replaceImportMapping(nextMapping = {}) {
  const normalizedEntries = importFieldList.value.map((fieldName) => [fieldName, String(nextMapping[fieldName] || "")]);
  Object.keys(importMapping).forEach((key) => {
    delete importMapping[key];
  });
  normalizedEntries.forEach(([fieldName, value]) => {
    importMapping[fieldName] = value;
  });
}

function syncImportSummary(summary = {}) {
  importSummary.totalRows = Number(summary.totalRows || 0);
  importSummary.validRows = Number(summary.validRows || 0);
  importSummary.invalidRows = Number(summary.invalidRows || 0);
  importSummary.parentProducts = Number(summary.parentProducts || 0);
  importSummary.warningsCount = Number(summary.warningsCount || 0);
  importSummary.hardErrorsCount = Number(summary.hardErrorsCount || 0);
  importSummary.warnings = [];
}

function syncImportPreviewState(preview, job = null) {
  importPreview.value = preview || null;
  importCurrentJob.value = job || importCurrentJob.value || null;
  importDetectedHeaders.value = Array.isArray(preview?.headers) ? preview.headers : [];
  importPreviewHeaders.value = importDetectedHeaders.value.slice(0, 8);
  importPreviewRows.value = importPreviewRecords.value.slice(0, 6);
  replaceImportMapping(preview?.fieldMapping || {});
  syncImportSummary(preview?.summary || {});
  importSkippedRowIds.value = [];
  importApprovedGroupKeys.value = importPreviewGroups.value
    .map((group) => String(group.groupKey || "").trim())
    .filter(Boolean);
}

function buildImportFieldMappingPayload() {
  return Object.fromEntries(
    Object.entries(importMapping)
      .map(([fieldName, headerName]) => [fieldName, String(headerName || "").trim()])
      .filter(([, headerName]) => Boolean(headerName)),
  );
}

function parseJsonInput(text, fallbackLabel) {
  const normalized = String(text || "").trim();
  if (!normalized) {
    return {};
  }
  try {
    return JSON.parse(normalized);
  } catch (error) {
    throw new Error(`${fallbackLabel} nuk eshte JSON valid.`);
  }
}

function buildImportSourceConfigPayload() {
  const headers = parseJsonInput(importApiSource.headersText, "Headers");
  const body = String(importApiSource.bodyText || "").trim()
    ? parseJsonInput(importApiSource.bodyText, "Body")
    : null;

  return {
    url: String(importApiSource.url || "").trim(),
    method: String(importApiSource.method || "GET").trim().toUpperCase(),
    recordPath: String(importApiSource.recordPath || "").trim(),
    headers,
    body,
  };
}

async function loadCatalogImportConfig() {
  if (!canManageCatalog.value) {
    return;
  }

  importIsConfigLoading.value = true;
  const result = await fetchBusinessCatalogImportConfig();
  importIsConfigLoading.value = false;

  if (!result.ok) {
    ui.importMessage = result.message;
    ui.importType = "error";
    return;
  }

  importProfiles.value = result.profiles;
  importSources.value = result.sources;
  importRecentJobs.value = result.recentJobs;
  importCanonicalFields.value = result.canonicalFields;
  importCategoryAttributeSets.value = result.categoryAttributeSets;
  replaceImportMapping(selectedImportProfile.value?.fieldMapping || {});
}

function handleImportSourceTypeChange() {
  clearImportSelection({ preserveSourceType: true, preserveProfiles: true });
}

function handleImportFileChange(event) {
  importFile.value = event.target.files?.[0] || null;
  setActiveSection("import");
  if (!importFile.value) {
    ui.importMessage = "";
    ui.importType = "";
    return;
  }

  const nextName = String(importFile.value.name || "").toLowerCase();
  importSourceType.value = nextName.endsWith(".xlsx") ? "xlsx" : "csv";
  ui.importMessage = `U zgjodh skedari ${importFile.value.name}.`;
  ui.importType = "success";
  void prepareImportPreview();
}

async function loadImportJobPreview(jobId) {
  if (!jobId) {
    return;
  }

  importIsPreviewLoading.value = true;
  const result = await createBusinessCatalogImportPreview({
    jobId,
    profileId: importSelectedProfileId.value,
    sourceId: importSelectedSourceId.value,
    fieldMapping: buildImportFieldMappingPayload(),
  });
  importIsPreviewLoading.value = false;
  ui.importMessage = result.message;
  ui.importType = result.ok ? "success" : "error";
  if (!result.ok) {
    return;
  }
  syncImportPreviewState(result.preview, result.job);
  await loadCatalogImportConfig();
}

async function prepareImportPreview() {
  if (!canManageCatalog.value) {
    ui.importMessage = "Biznesi duhet te verifikohet nga admini para se te importosh artikuj.";
    ui.importType = "error";
    return;
  }

  let result;
  importIsPreviewLoading.value = true;
  try {
    if (importSourceType.value === "csv" || importSourceType.value === "xlsx") {
      if (!importFile.value) {
        ui.importMessage = "Zgjidh nje skedar CSV ose XLSX per preview.";
        ui.importType = "error";
        return;
      }

      result = await createBusinessCatalogImportPreview({
        sourceType: importSourceType.value,
        file: importFile.value,
        profileId: importSelectedProfileId.value,
        sourceId: importSelectedSourceId.value,
        profileName: importProfileDraftName.value,
        saveProfile: importSaveProfile.value,
        fieldMapping: buildImportFieldMappingPayload(),
      });
    } else if (importSourceType.value === "json") {
      if (!String(importJsonPayload.value || "").trim()) {
        ui.importMessage = "Vendos payload JSON per preview.";
        ui.importType = "error";
        return;
      }

      result = await createBusinessCatalogImportPreview({
        sourceType: "json",
        payload: parseJsonInput(importJsonPayload.value, "JSON payload"),
        recordPath: importJsonRecordPath.value,
        profileId: importSelectedProfileId.value,
        profileName: importProfileDraftName.value,
        saveProfile: importSaveProfile.value,
        fieldMapping: buildImportFieldMappingPayload(),
      });
    } else if (importSourceType.value === "api-json") {
      const sourceConfig = buildImportSourceConfigPayload();
      if (!sourceConfig.url) {
        ui.importMessage = "Vendos URL-ne e API source para preview.";
        ui.importType = "error";
        return;
      }

      result = await createBusinessCatalogImportPreview({
        sourceType: "api-json",
        sourceId: importSelectedSourceId.value,
        profileId: importSelectedProfileId.value,
        profileName: importProfileDraftName.value,
        saveProfile: importSaveProfile.value,
        sourceConfig,
        fieldMapping: buildImportFieldMappingPayload(),
      });
    }
  } catch (error) {
    console.error(error);
    ui.importMessage = error instanceof Error ? error.message : "Preview i importit deshtoi.";
    ui.importType = "error";
    importIsPreviewLoading.value = false;
    return;
  }

  importIsPreviewLoading.value = false;
  ui.importMessage = result?.message || "";
  ui.importType = result?.ok ? "success" : "error";

  if (!result?.ok) {
    importSummary.warnings = Array.isArray(result?.errors) ? result.errors : [];
    return;
  }

  syncImportPreviewState(result.preview, result.job);
  await loadCatalogImportConfig();
}

async function downloadImportTemplate() {
  const result = await downloadBusinessProductsImportTemplate();
  ui.importMessage = result.message;
  ui.importType = result.ok ? "success" : "error";
}

async function saveCurrentImportProfile() {
  const profileName = String(importProfileDraftName.value || "").trim();
  if (!profileName) {
    ui.importMessage = "Vendos emrin e profilit para ruajtjes.";
    ui.importType = "error";
    return;
  }

  const result = await saveBusinessCatalogImportProfile({
    id: Number(importSelectedProfileId.value || 0) || undefined,
    profileName,
    sourceType: importSourceType.value,
    fieldMapping: buildImportFieldMappingPayload(),
    categoryMappingRules: {},
  });
  ui.importMessage = result.message;
  ui.importType = result.ok ? "success" : "error";
  if (!result.ok) {
    return;
  }

  importSelectedProfileId.value = Number(result.profile?.id || 0);
  await loadCatalogImportConfig();
}

async function saveCurrentImportSource() {
  if (importSourceType.value !== "api-json") {
    ui.importMessage = "Saved source connectors jane te aktivizuar per API / JSON feeds.";
    ui.importType = "error";
    return;
  }

  const sourceName = String(importApiSource.sourceName || "").trim();
  if (!sourceName) {
    ui.importMessage = "Vendos emrin e source connector.";
    ui.importType = "error";
    return;
  }

  const sourceConfig = buildImportSourceConfigPayload();
  if (!sourceConfig.url) {
    ui.importMessage = "Vendos URL-ne e source connector.";
    ui.importType = "error";
    return;
  }

  const result = await saveBusinessCatalogImportSource({
    id: Number(importSelectedSourceId.value || 0) || undefined,
    profileId: Number(importSelectedProfileId.value || 0),
    sourceName,
    sourceType: "api-json",
    sourceConfig,
    syncEnabled: Boolean(importApiSource.syncEnabled),
    syncIntervalMinutes: Number(importApiSource.syncIntervalMinutes || 0),
  });
  ui.importMessage = result.message;
  ui.importType = result.ok ? "success" : "error";
  if (!result.ok) {
    return;
  }

  importSelectedSourceId.value = Number(result.source?.id || 0);
  await loadCatalogImportConfig();
}

async function syncCurrentImportSource(sourceId = importSelectedSourceId.value) {
  if (!sourceId) {
    ui.importMessage = "Zgjidh nje source connector per sync.";
    ui.importType = "error";
    return;
  }

  importIsSyncLoading.value = true;
  const result = await syncBusinessCatalogImportSource(sourceId);
  importIsSyncLoading.value = false;
  ui.importMessage = result.message;
  ui.importType = result.ok ? "success" : "error";
  if (!result.ok) {
    importSummary.warnings = Array.isArray(result.errors) ? result.errors : [];
    return;
  }

  syncImportPreviewState(result.preview, result.job);
  await loadCatalogImportConfig();
}

function toggleImportGroupApproval(groupKey) {
  const normalizedKey = String(groupKey || "").trim();
  if (!normalizedKey) {
    return;
  }
  if (importApprovedGroupKeys.value.includes(normalizedKey)) {
    importApprovedGroupKeys.value = importApprovedGroupKeys.value.filter((value) => value !== normalizedKey);
    return;
  }
  importApprovedGroupKeys.value = [...importApprovedGroupKeys.value, normalizedKey];
}

function toggleImportRowSkip(sourceRowId) {
  const normalizedId = String(sourceRowId || "").trim();
  if (!normalizedId) {
    return;
  }
  if (importSkippedRowIds.value.includes(normalizedId)) {
    importSkippedRowIds.value = importSkippedRowIds.value.filter((value) => value !== normalizedId);
    return;
  }
  importSkippedRowIds.value = [...importSkippedRowIds.value, normalizedId];
}

async function submitImportProducts() {
  if (!canManageCatalog.value) {
    ui.importMessage = "Biznesi duhet te verifikohet nga admini para se te importosh artikuj.";
    ui.importType = "error";
    return;
  }

  if (!importCurrentJob.value?.id || !importPreview.value) {
    ui.importMessage = "Krijo preview para se ta perfundosh importin.";
    ui.importType = "error";
    return;
  }

  importIsCommitLoading.value = true;
  const result = await commitBusinessCatalogImportPreview({
    jobId: importCurrentJob.value.id,
    skipRowIds: importSkippedRowIds.value,
    approvedGroupKeys: importApprovedGroupKeys.value,
  });
  importIsCommitLoading.value = false;
  ui.importMessage = result.message;
  ui.importType = result.ok ? "success" : "error";

  if (!result.ok) {
    return;
  }

  clearImportSelection({ preserveSourceType: true, preserveProfiles: true });
  await Promise.all([
    loadProducts(),
    loadBusinessAnalytics(),
    loadCatalogImportConfig(),
  ]);
}

function clearImportSelection({ preserveSourceType = false, preserveProfiles = false } = {}) {
  importFile.value = null;
  importPreview.value = null;
  importCurrentJob.value = null;
  importPreviewRows.value = [];
  importPreviewHeaders.value = [];
  importDetectedHeaders.value = [];
  importSkippedRowIds.value = [];
  importApprovedGroupKeys.value = [];
  importJsonPayload.value = "";
  importJsonRecordPath.value = "";
  importApiSource.sourceName = "";
  importApiSource.url = "";
  importApiSource.method = "GET";
  importApiSource.recordPath = "";
  importApiSource.headersText = "";
  importApiSource.bodyText = "";
  importApiSource.syncEnabled = true;
  importApiSource.syncIntervalMinutes = "60";
  syncImportSummary({});
  if (!preserveSourceType) {
    importSourceType.value = "csv";
  }
  if (!preserveProfiles) {
    importSelectedProfileId.value = 0;
    importSelectedSourceId.value = 0;
    importProfileDraftName.value = "";
    importSaveProfile.value = false;
  }
  replaceImportMapping(selectedImportProfile.value?.fieldMapping || {});
  if (importFileInput.value) {
    importFileInput.value.value = "";
  }
  ui.importMessage = "";
  ui.importType = "";
}

function triggerImportPicker() {
  setActiveSection("import");
  importFileInput.value?.click?.();
}

async function suggestProductWithAi() {
  if (!canManageCatalog.value) {
    ui.productMessage = "Biznesi duhet te verifikohet nga admini para se te shtosh produkte.";
    ui.productTypeMessage = "error";
    return;
  }

  ui.productMessage = "";
  ui.productTypeMessage = "";
  ui.productAiBusy = true;

  try {
    const payload = new FormData();
    payload.append("title", productForm.title.trim());
    payload.append("description", productForm.description.trim());
    payload.append("pageSection", productForm.pageSection);
    payload.append("audience", productForm.audience);
    payload.append("productType", productForm.productType);
    payload.append("imagePath", productForm.imageGallery[0] || "");
    payload.append("imageGallery", JSON.stringify(productForm.imageGallery));
    selectedFiles.value.forEach((file) => {
      payload.append("images", file);
    });

    const result = await requestProductAIDraft(payload);
    if (!result.ok || !result.draft) {
      ui.productMessage = result.message;
      ui.productTypeMessage = "error";
      return;
    }

    const draft = result.draft;
    const nextSelectedColors = Array.isArray(draft.selectedColors)
      ? draft.selectedColors
      : productForm.selectedColors;

    productForm.title = String(draft.title || productForm.title || "").trim();
    productForm.description = String(draft.description || productForm.description || "").trim();
    productForm.pageSection = String(draft.pageSection || productForm.pageSection || "").trim();
    productForm.audience = String(draft.audience || productForm.audience || "").trim();
    syncProductFormCatalogState(productForm);
    productForm.productType = String(draft.productType || productForm.productType || "").trim();
    productForm.selectedColors = nextSelectedColors;
    productForm.packageAmountValue = String(draft.packageAmountValue || productForm.packageAmountValue || "").trim();
    productForm.packageAmountUnit = String(draft.packageAmountUnit || productForm.packageAmountUnit || "").trim();
    syncProductFormCatalogState(productForm);

    ui.productMessage = result.message;
    ui.productTypeMessage = "success";
  } catch (error) {
    console.error(error);
    ui.productMessage = "AI draft nuk u pergatit. Provoje perseri.";
    ui.productTypeMessage = "error";
  } finally {
    ui.productAiBusy = false;
  }
}

async function submitProduct() {
  ui.productMessage = "";
  await nextTick();
  syncProductFormCatalogState(productForm);

  if (!canManageCatalog.value) {
    ui.productMessage = "Biznesi duhet te verifikohet nga admini para se te shtosh produkte.";
    ui.productTypeMessage = "error";
    return;
  }

  if (!editingProduct.value && selectedFiles.value.length === 0) {
    ui.productMessage = "Zgjidh te pakten nje foto te produktit.";
    ui.productTypeMessage = "error";
    return;
  }

  let imageGallery = [...productForm.imageGallery];
  if (selectedFiles.value.length > 0) {
    const uploadResult = await uploadImages(selectedFiles.value);
    if (!uploadResult.ok) {
      ui.productMessage = uploadResult.message;
      ui.productTypeMessage = "error";
      return;
    }
    imageGallery = uploadResult.paths;
  }

  const payload = {
    articleNumber: productForm.articleNumber.trim(),
    title: productForm.title.trim(),
    price: productForm.price,
    compareAtPrice: productForm.compareAtPrice,
    saleEndsAt: productForm.saleEndsAt,
    description: productForm.description.trim(),
    brand: productForm.brand.trim(),
    gtin: productForm.gtin.trim(),
    mpn: productForm.mpn.trim(),
    material: productForm.material.trim(),
    weightValue: productForm.weightValue,
    weightUnit: productForm.weightUnit,
    metaTitle: productForm.metaTitle.trim(),
    metaDescription: productForm.metaDescription.trim(),
    pageSection: productForm.pageSection,
    audience: productForm.audience,
    category: productForm.category,
    productType: productForm.productType,
    stockQuantity: productForm.simpleStockQuantity,
    packageAmountValue: productForm.packageAmountValue,
    packageAmountUnit: productForm.packageAmountUnit,
    variantInventory: buildVariantInventoryFromForm(productForm),
    imageGallery,
    imagePath: imageGallery[0] || "",
  };

  const endpoint = editingProduct.value ? "/api/products/update" : "/api/products";
  if (editingProduct.value) {
    payload.productId = editingProduct.value.id;
  }

  const { response, data } = await requestJson(endpoint, {
    method: "POST",
    body: JSON.stringify(payload),
  });

  if (!response.ok || !data?.ok) {
    ui.productMessage = resolveApiMessage(data, "Artikulli nuk u ruajt.");
    ui.productTypeMessage = "error";
    return;
  }

  ui.productMessage = data.message || (editingProduct.value ? "Artikulli u perditesua me sukses." : "Artikulli u ruajt me sukses.");
  ui.productTypeMessage = "success";
  resetProductForm();
  await loadProducts();
  await loadBusinessAnalytics();
}

async function savePromotion() {
  if (!canManageCatalog.value) {
    ui.promotionMessage = "Biznesi duhet te verifikohet nga admini para se te ruash promocione.";
    ui.promotionType = "error";
    return;
  }

  if (promotionForm.pageSection && promotionForm.category) {
    const categoryStillMatches = promotionCategoryOptions.value.some((option) => option.value === promotionForm.category);
    if (!categoryStillMatches) {
      ui.promotionMessage = "Kategoria nuk perputhet me seksionin e zgjedhur.";
      ui.promotionType = "error";
      return;
    }
  }

  const payload = {
    ...promotionForm,
  };
  const { response, data } = await requestJson("/api/business/promotions", {
    method: "POST",
    body: JSON.stringify(payload),
  });

  if (!response.ok || !data?.ok) {
    ui.promotionMessage = resolveApiMessage(data, "Promocioni nuk u ruajt.");
    ui.promotionType = "error";
    return;
  }

  promotions.value = Array.isArray(data.promotions) ? data.promotions : promotions.value;
  ui.promotionMessage = data.message || "Promocioni u ruajt.";
  ui.promotionType = "success";
  resetPromotionForm();
  await loadBusinessAnalytics();
}

async function submitProductAction(url, payload, fallbackMessage) {
  const { response, data } = await requestJson(url, {
    method: "POST",
    body: JSON.stringify(payload),
  });

  if (!response.ok || !data?.ok) {
    ui.listMessage = resolveApiMessage(data, fallbackMessage);
    ui.listType = "error";
    return false;
  }

  ui.listMessage = data.message || fallbackMessage;
  ui.listType = "success";
  return true;
}

async function handleDeleteProduct(product) {
  if (!canManageCatalog.value) {
    ui.listMessage = "Katalogu eshte i ngrire deri ne verifikimin e biznesit.";
    ui.listType = "error";
    return;
  }
  if (!window.confirm("A do ta fshish kete produkt?")) {
    return;
  }
  const ok = await submitProductAction("/api/products/delete", { productId: product.id }, "Produkti u fshi me sukses.");
  if (ok) {
    await loadProducts();
  }
}

async function handleToggleVisibility(product) {
  if (!canManageCatalog.value) {
    ui.listMessage = "Katalogu eshte i ngrire deri ne verifikimin e biznesit.";
    ui.listType = "error";
    return;
  }
  const ok = await submitProductAction(
    "/api/products/public-visibility",
    { productId: product.id, isPublic: !product.isPublic },
    "Dukshmeria e produktit u perditesua.",
  );
  if (ok) {
    await loadProducts();
  }
}

async function handleToggleStock(product) {
  if (!canManageCatalog.value) {
    ui.listMessage = "Katalogu eshte i ngrire deri ne verifikimin e biznesit.";
    ui.listType = "error";
    return;
  }
  const ok = await submitProductAction(
    "/api/products/public-stock",
    { productId: product.id, showStockPublic: !(product.showStockPublic && Number(product.stockQuantity) > 0) },
    "Shfaqja e stokut u perditesua.",
  );
  if (ok) {
    await loadProducts();
  }
}

function toggleProductSelection(productId) {
  const normalizedId = Number(productId || 0);
  if (!normalizedId) {
    return;
  }
  if (selectedProductIds.value.includes(normalizedId)) {
    selectedProductIds.value = selectedProductIds.value.filter((id) => id !== normalizedId);
    return;
  }
  selectedProductIds.value = [...selectedProductIds.value, normalizedId];
}

function toggleSelectAllVisibleProducts() {
  const visibleIds = filteredProducts.value.map((product) => Number(product.id || 0)).filter(Boolean);
  const selectedIds = new Set(selectedProductIds.value);
  const allSelected = visibleIds.length > 0 && visibleIds.every((id) => selectedIds.has(id));
  if (allSelected) {
    selectedProductIds.value = selectedProductIds.value.filter((id) => !visibleIds.includes(id));
    return;
  }
  selectedProductIds.value = Array.from(new Set([...selectedProductIds.value, ...visibleIds]));
}

function clearSelectedProducts() {
  selectedProductIds.value = [];
}

function buildProductUpdatePayload(product, overrides = {}) {
  const categoryValue = String(overrides.category ?? product.category ?? "").trim().toLowerCase();
  const pageSection = deriveSectionFromCategory(categoryValue);
  const audience = deriveAudienceFromCategory(categoryValue);
  const productTypeOptions = PRODUCT_TYPE_OPTIONS_BY_CATEGORY[categoryValue] || [];
  const fallbackProductType = productTypeOptions[0]?.value || "";
  const nextProductType = String(overrides.productType ?? product.productType ?? fallbackProductType).trim().toLowerCase()
    || fallbackProductType;

  return {
    productId: Number(product.id || 0),
    articleNumber: String(product.articleNumber || "").trim(),
    title: String(product.title || "").trim(),
    price: Number(product.price || 0),
    compareAtPrice: Number(product.compareAtPrice || 0),
    saleEndsAt: String(product.saleEndsAt || "").trim(),
    description: String(product.description || "").trim(),
    pageSection,
    audience,
    category: categoryValue,
    productType: nextProductType,
    stockQuantity: Number(overrides.stockQuantity ?? product.stockQuantity ?? 0),
    packageAmountValue: Number(product.packageAmountValue || 0),
    packageAmountUnit: String(product.packageAmountUnit || "").trim().toLowerCase(),
    variantInventory: Array.isArray(product.variantInventory) ? product.variantInventory : [],
    imageGallery: getProductImageGallery(product),
    imagePath: getProductImageGallery(product)[0] || String(product.imagePath || "").trim(),
  };
}

async function applyBulkDelete() {
  if (!hasSelectedProducts.value) {
    return;
  }
  if (!window.confirm(`A do t'i fshish ${selectedProducts.value.length} produkte?`)) {
    return;
  }
  let successCount = 0;
  for (const product of selectedProducts.value) {
    const ok = await submitProductAction(
      "/api/products/delete",
      { productId: product.id },
      "Bulk delete deshtoi per disa produkte.",
    );
    if (ok) {
      successCount += 1;
    }
  }
  ui.listMessage = successCount > 0
    ? `${successCount} produkte u fshine me sukses.`
    : "Asnje produkt nuk u fshi.";
  ui.listType = successCount > 0 ? "success" : "error";
  clearSelectedProducts();
  await loadProducts();
}

async function applyBulkVisibility(isPublic) {
  if (!hasSelectedProducts.value) {
    return;
  }
  let successCount = 0;
  for (const product of selectedProducts.value) {
    const ok = await submitProductAction(
      "/api/products/public-visibility",
      { productId: product.id, isPublic },
      "Bulk update i dukshmerise deshtoi.",
    );
    if (ok) {
      successCount += 1;
    }
  }
  ui.listMessage = successCount > 0
    ? `${successCount} produkte u perditesuan.`
    : "Nuk pati ndryshime ne dukshmeri.";
  ui.listType = successCount > 0 ? "success" : "error";
  clearSelectedProducts();
  await loadProducts();
}

async function applyBulkCategory() {
  const nextCategory = String(bulkCategoryValue.value || "").trim().toLowerCase();
  if (!nextCategory || !hasSelectedProducts.value) {
    return;
  }
  let successCount = 0;
  for (const product of selectedProducts.value) {
    const payload = buildProductUpdatePayload(product, { category: nextCategory });
    const { response, data } = await requestJson("/api/products/update", {
      method: "POST",
      body: JSON.stringify(payload),
    });
    if (response.ok && data?.ok) {
      successCount += 1;
    }
  }
  ui.listMessage = successCount > 0
    ? `${successCount} produkte u kaluan ne kategorine e re.`
    : "Nuk u perditesua asnje kategori.";
  ui.listType = successCount > 0 ? "success" : "error";
  bulkCategoryValue.value = "";
  clearSelectedProducts();
  await loadProducts();
}

async function applyBulkStockUpdate() {
  if (!hasSelectedProducts.value) {
    return;
  }
  const nextStock = Math.max(0, Math.trunc(Number(bulkStockValue.value || 0)));
  let successCount = 0;
  let skippedVariants = 0;
  for (const product of selectedProducts.value) {
    const hasMultipleVariants = Array.isArray(product.variantInventory) && product.variantInventory.length > 1;
    if (hasMultipleVariants) {
      skippedVariants += 1;
      continue;
    }
    const payload = buildProductUpdatePayload(product, { stockQuantity: nextStock });
    const { response, data } = await requestJson("/api/products/update", {
      method: "POST",
      body: JSON.stringify(payload),
    });
    if (response.ok && data?.ok) {
      successCount += 1;
    }
  }
  ui.listMessage = successCount > 0
    ? `${successCount} produkte u perditesuan me stokun ${nextStock}.${skippedVariants > 0 ? ` ${skippedVariants} produkte me variante u anashkaluan.` : ""}`
    : "Nuk u perditesua asnje stok.";
  ui.listType = successCount > 0 ? "success" : "error";
  bulkStockValue.value = "";
  clearSelectedProducts();
  await loadProducts();
}

</script>

<template>
  <section class="business-dashboard-page" aria-label="Biznesi juaj">
    <div
      v-if="!shouldShowProfileCard && ui.profileMessage"
      class="form-message"
      :class="ui.profileType"
      role="status"
      aria-live="polite"
    >
      {{ ui.profileMessage }}
    </div>

    <div class="business-dashboard-shell">
      <aside class="card business-dashboard-sidebar" aria-label="Navigimi i dashboard-it">
        <div class="business-dashboard-brand">
          <div class="business-dashboard-brand-mark">T</div>
          <div class="business-dashboard-brand-copy">
            <strong>Tregio Pro</strong>
            <span>Business</span>
          </div>
        </div>

        <div class="business-dashboard-side-menu" role="tablist" aria-label="Seksionet e dashboard-it">
          <button
            v-for="section in dashboardSidebarSections"
            :key="section.key"
            class="business-dashboard-side-button"
            :class="{ 'is-active': activeSection === section.key }"
            type="button"
            role="tab"
            :aria-selected="activeSection === section.key"
            @click="setActiveSection(section.key)"
          >
            <span class="business-dashboard-side-icon"></span>
            <span>{{ section.navLabel || section.label }}</span>
          </button>
        </div>
      </aside>

      <div class="business-dashboard-main">
        <header class="card business-dashboard-toolbar">
          <div class="business-dashboard-toolbar-tabs">
            <button
              v-for="section in dashboardSections"
              :key="`top-tab-${section.key}`"
              class="business-dashboard-toolbar-tab"
              :class="{ 'is-active': activeSection === section.key }"
              type="button"
              @click="setActiveSection(section.key)"
            >
              {{ section.label }}
            </button>
          </div>

          <div class="business-dashboard-toolbar-meta">
            <button class="business-dashboard-toolbar-icon" type="button" aria-label="Njoftime">
              <svg viewBox="0 0 24 24" aria-hidden="true">
                <path d="M12 4a4 4 0 0 0-4 4v2.1c0 .6-.2 1.1-.5 1.6L6 14.5V16h12v-1.5l-1.5-2.8c-.3-.5-.5-1-.5-1.6V8a4 4 0 0 0-4-4Z"></path>
                <path d="M10 18a2 2 0 0 0 4 0"></path>
              </svg>
            </button>
            <div class="business-dashboard-toolbar-range">{{ dashboardDateRangeLabel }}</div>
            <div class="business-dashboard-toolbar-avatar">{{ dashboardAvatarLabel }}</div>
          </div>
        </header>

        <section
          v-show="activeSection === 'analytics'"
          class="business-dashboard-overview"
          aria-label="Analytics e biznesit"
        >
          <div v-if="analytics" class="business-dashboard-overview-grid-stack">
            <div class="business-dashboard-metric-grid">
              <article
                v-for="metric in dashboardMetrics"
                :key="metric.key"
                class="card business-dashboard-metric-card"
                :data-tone="metric.tone"
              >
                <div class="business-dashboard-metric-icon"></div>
                <div class="business-dashboard-metric-copy">
                  <span>{{ metric.label }}</span>
                  <strong>{{ metric.value }}</strong>
                  <small>{{ metric.meta }}</small>
                </div>
              </article>
            </div>

            <div class="business-dashboard-overview-grid">
              <article class="card business-dashboard-chart-card">
                <div class="business-dashboard-card-head">
                  <div>
                    <h2>Sales Overview</h2>
                    <span>{{ activeSectionMeta?.label || "Dashboard" }}</span>
                  </div>
                  <div class="business-dashboard-card-pill">Last 7 Days</div>
                </div>

                <div class="business-dashboard-chart-frame">
                  <svg viewBox="0 0 640 220" class="business-dashboard-chart" role="img" aria-label="Grafiku i overview">
                    <g class="business-dashboard-chart-grid">
                      <line v-for="line in 5" :key="`chart-grid-${line}`" x1="18" :y1="line * 40" x2="622" :y2="line * 40"></line>
                    </g>
                    <path class="business-dashboard-chart-area" :d="dashboardChartAreaPath"></path>
                    <path class="business-dashboard-chart-line" :d="dashboardChartLinePath"></path>
                    <circle
                      v-for="(point, index) in dashboardChartPoints"
                      :key="`chart-point-${index}`"
                      class="business-dashboard-chart-point"
                      :cx="point.x"
                      :cy="point.y"
                      r="5"
                    ></circle>
                  </svg>

                  <div class="business-dashboard-chart-labels">
                    <span v-for="label in dashboardChartLabels" :key="`chart-label-${label}`">{{ label }}</span>
                  </div>
                </div>
              </article>

              <article class="card business-dashboard-actions-card">
                <div class="business-dashboard-card-head">
                  <div>
                    <h2>Quick Actions</h2>
                    <span>Fast access</span>
                  </div>
                </div>

                <div class="business-dashboard-actions-grid">
                  <button
                    v-for="action in dashboardQuickActions"
                    :key="action.key"
                    class="business-dashboard-action-card"
                    :data-tone="action.tone"
                    type="button"
                    @click="handleDashboardQuickAction(action.key)"
                  >
                    <span class="business-dashboard-action-icon">{{ action.label.charAt(0) }}</span>
                    <strong>{{ action.label }}</strong>
                  </button>
                </div>
              </article>
            </div>

            <div class="business-dashboard-overview-grid business-dashboard-overview-grid--bottom">
              <article class="card business-dashboard-list-card">
                <div class="business-dashboard-card-head">
                  <div>
                    <h2>Recent Products</h2>
                    <span>{{ products.length }} total</span>
                  </div>
                  <button class="business-dashboard-link-button" type="button" @click="setActiveSection('products')">View All</button>
                </div>

                <div v-if="recentDashboardProducts.length === 0" class="admin-empty-state">
                  Ende nuk ka produkte.
                </div>
                <div v-else class="business-dashboard-list-stack">
                  <article
                    v-for="product in recentDashboardProducts"
                    :key="`recent-dashboard-product-${product.id}`"
                    class="business-dashboard-product-row"
                  >
                    <img :src="product.imagePath" :alt="product.title" loading="lazy" decoding="async">
                    <div class="business-dashboard-product-copy">
                      <strong>{{ product.title }}</strong>
                      <span>{{ product.articleNumber || `#${product.id}` }}</span>
                    </div>
                    <div class="business-dashboard-row-meta">
                      <span class="business-dashboard-row-status" :class="{ 'is-low': Number(product.stockQuantity || 0) <= STOCK_ALERT_THRESHOLD }">
                        {{ Number(product.stockQuantity || 0) > STOCK_ALERT_THRESHOLD ? "In Stock" : "Low" }}
                      </span>
                      <strong>{{ formatStockQuantity(product.stockQuantity) }}</strong>
                    </div>
                  </article>
                </div>
              </article>

              <article class="card business-dashboard-list-card">
                <div class="business-dashboard-card-head">
                  <div>
                    <h2>Stock Alerts</h2>
                    <span>{{ stockAlertCount }} items</span>
                  </div>
                  <button class="business-dashboard-link-button" type="button" @click="setActiveSection('stock')">View All</button>
                </div>

                <div v-if="stockAlertProducts.length === 0" class="admin-empty-state">
                  Nuk ka alerte ne stok.
                </div>
                <div v-else class="business-dashboard-list-stack">
                  <article
                    v-for="product in stockAlertProducts.slice(0, 4)"
                    :key="`overview-stock-alert-${product.id}`"
                    class="business-dashboard-alert-row"
                  >
                    <span class="business-dashboard-alert-dot"></span>
                    <div class="business-dashboard-alert-copy">
                      <strong>{{ product.title }}</strong>
                      <span>{{ formatCategoryLabel(product.category) }}</span>
                    </div>
                    <strong class="business-dashboard-alert-qty">{{ formatStockQuantity(product.stockQuantity) }}</strong>
                  </article>
                </div>
              </article>

              <article class="card business-dashboard-list-card">
                <div class="business-dashboard-card-head">
                  <div>
                    <h2>Active Discounts</h2>
                    <span>{{ promotions.length }} live</span>
                  </div>
                  <button class="business-dashboard-link-button" type="button" @click="setActiveSection('offers')">View All</button>
                </div>

                <div v-if="recentDiscounts.length === 0" class="admin-empty-state">
                  Nuk ka oferta aktive.
                </div>
                <div v-else class="business-dashboard-list-stack">
                  <article
                    v-for="promotion in recentDiscounts"
                    :key="`overview-discount-${promotion.id}`"
                    class="business-dashboard-discount-row"
                  >
                    <div class="business-dashboard-discount-copy">
                      <span class="business-dashboard-discount-code">{{ promotion.code }}</span>
                      <strong>{{ promotion.title || "Promotion" }}</strong>
                      <small>{{ promotion.discountType === "percent" ? `${promotion.discountValue}% off` : formatPrice(promotion.discountValue) }}</small>
                    </div>
                    <span class="business-dashboard-discount-status">{{ promotion.isActive ? "Active" : "Paused" }}</span>
                  </article>
                </div>

                <button class="business-dashboard-outline-action" type="button" @click="setActiveSection('offers')">
                  Create Discount
                </button>
              </article>
            </div>
          </div>
          <div v-else class="card business-dashboard-panel">
            <div class="admin-empty-state">
              Analytics nuk u ngarkuan ende.
            </div>
          </div>
        </section>

    <section
      v-if="canManageCatalog"
      v-show="activeSection === 'stock'"
      class="card business-stock-alerts-card business-dashboard-panel"
      aria-label="Alertet e stokut"
    >
      <div class="profile-card-header">
        <div>
          <h2>Stoku</h2>
        </div>
        <div class="summary-chip">
          <span>Ne risk</span>
          <strong>{{ stockAlertCount }}</strong>
        </div>
      </div>

      <div v-if="stockAlertCount > 0" class="business-stock-alerts-grid">
        <article
          v-for="product in stockAlertProducts"
          :key="`stock-alert-${product.id}`"
          class="business-stock-alert-card"
          :class="{ 'is-out-of-stock': Number(product.stockQuantity || 0) <= 0 }"
        >
          <div class="business-stock-alert-copy">
            <p class="business-stock-alert-category">{{ formatCategoryLabel(product.category) }}</p>
            <strong>{{ product.title }}</strong>
            <p>{{ getStockAlertLabel(product) }}</p>
          </div>
          <button class="nav-action nav-action-secondary business-stock-alert-action" type="button" @click="beginProductEdit(product)">
            Edito
          </button>
        </article>
      </div>
      <div v-else class="admin-empty-state">
        Nuk ka produkte ne risk.
      </div>
    </section>

    <section
      v-if="canManageCatalog"
      v-show="activeSection === 'shipping'"
      class="card business-shipping-card business-dashboard-panel"
      aria-label="Transporti i biznesit"
    >
      <div class="profile-card-header">
        <div>
          <h2>Transport</h2>
        </div>
      </div>

      <form class="auth-form" @submit.prevent="saveShippingSettings">
        <div class="business-shipping-settings-grid">
          <article class="business-shipping-method-card">
            <div class="business-shipping-method-head">
              <div>
                <strong>Dergese standard</strong>
              </div>
              <label class="business-shipping-toggle">
                <input v-model="shippingForm.standardEnabled" type="checkbox">
                <span>Aktive</span>
              </label>
            </div>
            <div class="field-row">
              <label class="field">
                <span>Kosto baze (€)</span>
                <input v-model="shippingForm.standardFee" :disabled="!shippingForm.standardEnabled" type="number" min="0" step="0.10" placeholder="2.50">
              </label>
              <label class="field">
                <span>Koha e dorezimit</span>
                <input v-model="shippingForm.standardEta" :disabled="!shippingForm.standardEnabled" type="text" placeholder="2-4 dite pune">
              </label>
            </div>
          </article>

          <article class="business-shipping-method-card">
            <div class="business-shipping-method-head">
              <div>
                <strong>Dergese express</strong>
              </div>
              <label class="business-shipping-toggle">
                <input v-model="shippingForm.expressEnabled" type="checkbox">
                <span>Aktive</span>
              </label>
            </div>
            <div class="field-row">
              <label class="field">
                <span>Kosto baze (€)</span>
                <input v-model="shippingForm.expressFee" :disabled="!shippingForm.expressEnabled" type="number" min="0" step="0.10" placeholder="4.90">
              </label>
              <label class="field">
                <span>Koha e dorezimit</span>
                <input v-model="shippingForm.expressEta" :disabled="!shippingForm.expressEnabled" type="text" placeholder="1-2 dite pune">
              </label>
            </div>
          </article>

          <article class="business-shipping-method-card">
            <div class="business-shipping-method-head">
              <div>
                <strong>Terheqje ne biznes</strong>
              </div>
              <label class="business-shipping-toggle">
                <input v-model="shippingForm.pickupEnabled" type="checkbox">
                <span>Aktive</span>
              </label>
            </div>
            <label class="field">
              <span>Koha e gatishmerise</span>
              <input v-model="shippingForm.pickupEta" :disabled="!shippingForm.pickupEnabled" type="text" placeholder="Gati per terheqje brenda 24 oresh">
            </label>
            <label class="field">
              <span>Adresa e terheqjes</span>
              <input
                v-model="shippingForm.pickupAddress"
                :disabled="!shippingForm.pickupEnabled"
                type="text"
                placeholder="Shkruaje adresen ku merret porosia"
              >
            </label>
            <label class="field">
              <span>Orari i terheqjes</span>
              <input
                v-model="shippingForm.pickupHours"
                :disabled="!shippingForm.pickupEnabled"
                type="text"
                placeholder="p.sh. Hene-Shtune, 09:00 - 18:00"
              >
            </label>
            <label class="field">
              <span>Pickup map location</span>
              <input
                v-model="shippingForm.pickupMapUrl"
                :disabled="!shippingForm.pickupEnabled"
                type="url"
                placeholder="https://maps.google.com/..."
              >
            </label>
          </article>
        </div>

        <div class="field-row">
          <label class="field">
            <span>Pragu per 50% zbritje transporti (€)</span>
            <input v-model="shippingForm.halfOffThreshold" type="number" min="0" step="0.10" placeholder="120">
          </label>

          <label class="field">
            <span>Pragu per transport falas (€)</span>
            <input v-model="shippingForm.freeShippingThreshold" type="number" min="0" step="0.10" placeholder="180">
          </label>
        </div>

        <div class="business-shipping-city-rates">
          <div class="business-shipping-city-rates-head">
            <div>
              <strong>Tarifa sipas qytetit</strong>
            </div>
            <button type="button" class="business-shipping-city-add" @click="addShippingCityRate">
              Shto qytet
            </button>
          </div>

          <div class="business-shipping-city-list">
            <div
              v-for="(cityRate, index) in shippingForm.cityRates"
              :key="`shipping-city-rate-${index}`"
              class="business-shipping-city-row"
            >
              <label class="field">
                <span>Qyteti</span>
                <input
                  v-model="cityRate.city"
                  type="text"
                  placeholder="p.sh. Prishtine"
                >
              </label>

              <label class="field">
                <span>Shtesa (€)</span>
                <input
                  v-model="cityRate.surcharge"
                  type="number"
                  min="0"
                  step="0.10"
                  placeholder="0.00"
                >
              </label>

              <button type="button" class="business-shipping-city-remove" @click="removeShippingCityRate(index)">
                Hiq
              </button>
            </div>
          </div>
        </div>

        <div class="auth-form-actions">
          <button type="submit">Ruaj</button>
        </div>
      </form>

      <div class="form-message" :class="ui.shippingType" role="status" aria-live="polite">
        {{ ui.shippingMessage }}
      </div>
    </section>

    <section
      v-if="shouldShowProfileCard"
      v-show="activeSection === 'profile'"
      class="card business-profile-card business-dashboard-panel"
    >
        <h2>{{ businessProfile && isBusinessVerified ? "Edito biznesin" : "Regjistrimi i biznesit" }}</h2>

        <form class="auth-form" @submit.prevent="saveBusinessProfile">
          <label class="field">
            <span>Emri i biznesit</span>
            <input v-model="profileForm.businessName" type="text" placeholder="p.sh. Agro Market Rinia" required>
          </label>

          <label class="field">
            <span>Pershkrimi i biznesit</span>
            <textarea v-model="profileForm.businessDescription" rows="4" placeholder="Shkruaje pershkrimin e biznesit" required></textarea>
          </label>

          <div class="field-row">
            <label class="field">
              <span>Nr. i biznesit</span>
              <input v-model="profileForm.businessNumber" type="text" placeholder="p.sh. BR-204-55" required>
            </label>

            <label class="field">
              <span>Numri i telefonit</span>
              <input v-model="profileForm.phoneNumber" type="text" placeholder="p.sh. +383 44 123 456" required>
            </label>
          </div>

          <div class="field-row">
            <label class="field">
              <span>Email per support</span>
              <input v-model="profileForm.supportEmail" type="email" placeholder="p.sh. support@biznesi.com">
            </label>

            <label class="field">
              <span>Website</span>
              <input v-model="profileForm.websiteUrl" type="url" placeholder="p.sh. https://biznesi.com">
            </label>
          </div>

          <div class="field-row">
            <label class="field">
              <span>Orari i support-it</span>
              <input v-model="profileForm.supportHours" type="text" placeholder="p.sh. Hene - Shtune, 09:00 - 18:00">
            </label>
            <label class="field">
              <span>Qyteti</span>
              <input v-model="profileForm.city" type="text" placeholder="p.sh. Prishtine" required>
            </label>
          </div>

          <label class="field">
            <span>Politika e kthimit</span>
            <textarea
              v-model="profileForm.returnPolicySummary"
              rows="3"
              placeholder="p.sh. Kthimi pranohet brenda 14 diteve per produktet e pademtuara."
            ></textarea>
          </label>

          <label class="field">
            <span>Adresa e biznesit</span>
            <input v-model="profileForm.addressLine" type="text" placeholder="Shkruaje adresen e biznesit" required>
          </label>

          <label class="field">
            <span>Logo e biznesit (opsionale)</span>
            <input type="file" accept="image/*" @change="handleLogoChange">
          </label>

          <p class="product-upload-help">
            Logo opsionale.
          </p>

          <div class="product-upload-preview" aria-live="polite">
            <div v-if="!businessLogoPreview" class="product-upload-empty">
              Nuk eshte zgjedhur asnje logo ende.
            </div>
            <figure v-else class="product-upload-preview-item business-logo-preview-item">
              <img class="product-upload-preview-image business-logo-preview-image" :src="businessLogoPreview" alt="Logo e biznesit">
              <figcaption class="product-upload-preview-name">Logo e biznesit</figcaption>
            </figure>
          </div>

          <div v-if="businessProfile" class="marketplace-status-card">
            <div>
              <strong>{{ formatVerificationStatusLabel(businessProfile.verificationStatus) }}</strong>
            </div>
            <button
              v-if="['unverified', 'rejected'].includes(String(businessProfile.verificationStatus || ''))"
              class="nav-action nav-action-secondary"
              type="button"
              @click="requestVerificationReview"
            >
              Verifiko
            </button>
          </div>

          <div class="auth-form-actions">
            <button type="submit">Ruaj</button>
          </div>
        </form>

        <div class="form-message" :class="ui.profileType" role="status" aria-live="polite">
          {{ ui.profileMessage }}
        </div>
    </section>

    <section
      v-if="canManageCatalog"
      v-show="activeSection === 'add-product'"
      class="card admin-form-card product-builder-card business-dashboard-panel"
    >
        <div class="product-builder-head">
          <div>
            <h2>{{ editingProduct ? "Edito artikullin" : "Shto artikull te ri" }}</h2>
          </div>
          <button class="button-secondary" type="button" @click="resetProductForm">Reset</button>
        </div>

        <p v-if="editingProduct" class="admin-edit-state">
          Nese nuk zgjedh foto te reja, ruhen fotot aktuale.
        </p>

        <div class="product-builder-shell">
          <form class="auth-form product-builder-form" @submit.prevent="submitProduct">
            <div class="product-builder-steps" role="tablist" aria-label="Hapat e produktit">
              <button
                v-for="step in productFormSteps"
                :key="step.id"
                class="product-builder-step"
                :class="{ 'is-active': productFormStep === step.id, 'is-done': step.done }"
                type="button"
                @click="focusProductFormStep(step.id)"
              >
                <strong>{{ step.label }}</strong>
              </button>
            </div>

            <section
              id="business-product-step-details"
              class="product-builder-block"
              :class="{ 'is-active': productFormStep === 'details' }"
            >
              <div class="product-builder-block-head">
                <div>
                  <h3>Emri, kodi dhe pershkrimi</h3>
                </div>
                <button class="button-secondary" type="button" :disabled="ui.productAiBusy" @click="suggestProductWithAi">
                  {{ ui.productAiBusy ? "AI..." : "AI" }}
                </button>
              </div>

              <div class="field-row">
                <label class="field">
                  <span>Numri i artikullit</span>
                  <input
                    v-model="productForm.articleNumber"
                    type="text"
                    inputmode="numeric"
                    placeholder="p.sh. 10025"
                  >
                </label>

              <label class="field">
                <span>Titulli</span>
                <input ref="productTitleInput" v-model="productForm.title" type="text" placeholder="p.sh. Produkt i ri" required>
              </label>
            </div>

            <div class="field-row field-row-3">
              <label class="field">
                <span>Brand</span>
                <input v-model="productForm.brand" type="text" placeholder="p.sh. Nike">
              </label>
              <label class="field">
                <span>GTIN / Barcode</span>
                <input v-model="productForm.gtin" type="text" inputmode="numeric" placeholder="p.sh. 0123456789012">
              </label>
              <label class="field">
                <span>MPN</span>
                <input v-model="productForm.mpn" type="text" placeholder="p.sh. NK-2026-RED">
              </label>
            </div>

            <div class="field-row field-row-3">
              <label class="field">
                <span>Materiali</span>
                <input v-model="productForm.material" type="text" placeholder="p.sh. Lekure natyrale">
              </label>
              <label class="field">
                <span>Pesha</span>
                <input v-model="productForm.weightValue" type="number" min="0" step="0.01" placeholder="p.sh. 0.45">
              </label>
              <label class="field">
                <span>Njesia e peshes</span>
                <select v-model="productForm.weightUnit">
                  <option
                    v-for="option in PRODUCT_WEIGHT_UNIT_OPTIONS"
                    :key="option.value"
                    :value="option.value"
                  >
                    {{ option.label }}
                  </option>
                </select>
              </label>
            </div>

              <label class="field">
                <span>Pershkrimi</span>
                <textarea v-model="productForm.description" rows="4" placeholder="Shkruaje pershkrimin e produktit" required></textarea>
              </label>

              <div class="field-row">
                <label class="field">
                  <span>SEO title</span>
                  <input v-model="productForm.metaTitle" type="text" maxlength="160" placeholder="Titull me i shkurter per Google">
                </label>
                <label class="field">
                  <span>SEO description</span>
                  <textarea
                    v-model="productForm.metaDescription"
                    rows="3"
                    maxlength="320"
                    placeholder="Pershkrim i shkurter per rezultatet e kerkimit"
                  ></textarea>
                </label>
              </div>

              <div class="auth-form-actions">
                <button class="button-secondary" type="button" @click="focusProductFormStep('pricing')">Tjetra</button>
              </div>
            </section>

            <section
              id="business-product-step-pricing"
              class="product-builder-block"
              :class="{ 'is-active': productFormStep === 'pricing' }"
            >
              <div class="product-builder-block-head">
                <div>
                  <h3>Regular price, sale dhe afati</h3>
                </div>
              </div>

              <div class="field-row field-row-3">
                <label class="field">
                  <span>Cmimi aktual (€)</span>
                  <input v-model="productForm.price" type="number" min="0.01" step="0.01" placeholder="p.sh. 13.99" required>
                </label>
                <label class="field">
                  <span>Cmimi para zbritjes</span>
                  <input v-model="productForm.compareAtPrice" type="number" min="0" step="0.01" placeholder="p.sh. 18.99">
                </label>
                <label class="field">
                  <span>Zbritja vlen deri</span>
                  <input v-model="productForm.saleEndsAt" type="datetime-local">
                </label>
              </div>

              <p class="product-builder-note" :class="{ 'is-warning': !productPricingReady && (productForm.price || productForm.compareAtPrice || productForm.saleEndsAt) }">
                <template v-if="productDiscountPercent > 0">
                  Produkti do te shfaqet me rreth {{ productDiscountPercent }}% zbritje.
                </template>
                <template v-else>
                  Nese vendos cmim para zbritjes, ai duhet te jete me i madh se cmimi aktual.
                </template>
              </p>

              <div class="auth-form-actions">
                <button class="button-secondary" type="button" @click="focusProductFormStep('details')">Kthehu</button>
                <button class="button-secondary" type="button" @click="focusProductFormStep('variants')">Tjetra</button>
              </div>
            </section>

            <section
              id="business-product-step-variants"
              class="product-builder-block"
              :class="{ 'is-active': productFormStep === 'variants' }"
            >
              <div class="product-builder-block-head">
                <div>
                  <h3>Ngjyra, madhesia, tipi dhe stoku</h3>
                  <p class="product-builder-note">Ruaj cmim ose foto specifike per variant.</p>
                </div>
                <div class="product-builder-inline-summary">
                  <span class="summary-chip">
                    <span>Variante</span>
                    <strong>{{ productVariantEntries.length }}</strong>
                  </span>
                  <span class="summary-chip">
                    <span>Stok total</span>
                    <strong>{{ formatStockQuantity(productStockTotal) }}</strong>
                  </span>
                </div>
              </div>

              <ProductVariantConfigurator :form="productForm" />

              <div class="auth-form-actions">
                <button class="button-secondary" type="button" @click="focusProductFormStep('pricing')">Kthehu</button>
                <button class="button-secondary" type="button" @click="focusProductFormStep('media')">Tjetra</button>
              </div>
            </section>

            <section
              id="business-product-step-media"
              class="product-builder-block"
              :class="{ 'is-active': productFormStep === 'media' }"
            >
              <div class="product-builder-block-head">
                <div>
                  <h3>Cover dhe galeria e produktit</h3>
                </div>
                <span class="summary-chip">
                  <span>Foto</span>
                  <strong>{{ productMediaCount }}</strong>
                </span>
              </div>

              <label class="field">
                <span>Upload photo</span>
                <input type="file" accept="image/*" multiple :required="!editingProduct" @change="handleFilesChange">
              </label>

              <p class="product-upload-help">
                Cover dhe foto shtese.
              </p>

              <div class="product-upload-preview" aria-live="polite">
                <div v-if="productPreviewItems.length === 0" class="product-upload-empty">
                  Asnje foto nuk eshte zgjedhur ende.
                </div>
                <figure
                  v-for="(item, index) in productPreviewItems"
                  v-else
                  :key="`${item.path}-${index}`"
                  class="product-upload-preview-item"
                >
                  <img class="product-upload-preview-image" :src="item.path" :alt="item.label">
                  <figcaption class="product-upload-preview-name">{{ item.label }}</figcaption>
                </figure>
              </div>

              <div class="auth-form-actions">
                <button class="button-secondary" type="button" @click="focusProductFormStep('variants')">Kthehu</button>
                <button class="button-secondary" type="button" @click="focusProductFormStep('review')">Tjetra</button>
              </div>
            </section>

            <section
              id="business-product-step-review"
              class="product-builder-block"
              :class="{ 'is-active': productFormStep === 'review' }"
            >
              <div class="product-builder-block-head">
                <div>
                  <h3>Kontroll final</h3>
                </div>
              </div>

              <div class="product-builder-review-card">
                <div class="product-builder-review-media">
                  <img v-if="productPreviewCover" :src="productPreviewCover" :alt="productForm.title || 'Preview i produktit'">
                  <div v-else class="product-builder-review-empty">Pa cover</div>
                </div>
                <div class="product-builder-review-copy">
                  <h3>{{ productForm.title || "Titulli i produktit" }}</h3>
                  <p>{{ productForm.description || "Pershkrimi do te shfaqet ketu sapo ta plotesosh." }}</p>
                  <div class="product-builder-price-preview">
                    <strong>{{ productPriceValue > 0 ? formatPrice(productPriceValue) : "Vendos cmimin" }}</strong>
                    <span v-if="productCompareAtPriceValue > productPriceValue">{{ formatPrice(productCompareAtPriceValue) }}</span>
                    <mark v-if="productDiscountPercent > 0">-{{ productDiscountPercent }}%</mark>
                  </div>
                  <div class="product-detail-tags product-detail-tags-admin">
                    <span v-if="productForm.brand" class="product-detail-tag">Brand: {{ productForm.brand }}</span>
                    <span v-if="productForm.material" class="product-detail-tag">Material: {{ productForm.material }}</span>
                    <span
                      v-if="productForm.weightValue"
                      class="product-detail-tag"
                    >
                      Pesha: {{ productForm.weightValue }} {{ productForm.weightUnit }}
                    </span>
                    <span v-if="productForm.gtin" class="product-detail-tag">GTIN: {{ productForm.gtin }}</span>
                  </div>
                  <div class="product-builder-inline-summary">
                    <span class="summary-chip">
                      <span>Stok total</span>
                      <strong>{{ formatStockQuantity(productStockTotal) }}</strong>
                    </span>
                    <span class="summary-chip">
                      <span>Variante</span>
                      <strong>{{ productVariantEntries.length || 1 }}</strong>
                    </span>
                    <span class="summary-chip">
                      <span>Media</span>
                      <strong>{{ productMediaCount }}</strong>
                    </span>
                  </div>
                </div>
              </div>

              <ul class="product-builder-checklist" aria-label="Kontrolli final i produktit">
                <li
                  v-for="item in productChecklist"
                  :key="item.key"
                  class="product-builder-checklist-item"
                  :class="{ 'is-done': item.done }"
                >
                  <span class="product-builder-checklist-dot"></span>
                  <strong>{{ item.label }}</strong>
                  <small>{{ item.done ? "OK" : "Plotesoje para ruajtjes" }}</small>
                </li>
              </ul>

              <div class="auth-form-actions">
                <button class="button-secondary" type="button" @click="focusProductFormStep('media')">Kthehu</button>
                <button type="submit">{{ editingProduct ? "Ruaj ndryshimet" : "Ruaje artikullin" }}</button>
                <button v-if="editingProduct" class="button-secondary" type="button" @click="resetProductForm">Anulo editimin</button>
              </div>
            </section>
          </form>

          <aside class="product-builder-aside">
            <article class="product-builder-aside-card">
              <h3>{{ editingProduct ? "Artikull ne editim" : "Artikull i ri" }}</h3>
              <div class="product-builder-aside-grid">
                <div class="summary-chip">
                  <span>Detajet</span>
                  <strong>{{ productChecklist[0]?.done ? "Gati" : "Hape" }}</strong>
                </div>
                <div class="summary-chip">
                  <span>Cmimi</span>
                  <strong>{{ productChecklist[1]?.done ? "Gati" : "Kontrollo" }}</strong>
                </div>
                <div class="summary-chip">
                  <span>Variantet</span>
                  <strong>{{ productVariantEntries.length || 1 }}</strong>
                </div>
                <div class="summary-chip">
                  <span>Media</span>
                  <strong>{{ productMediaCount }}</strong>
                </div>
              </div>
            </article>

            <article class="product-builder-aside-card">
              <h3>{{ productReadyToSave ? "Produkti duket gati" : "Mungojne disa hapa" }}</h3>
            </article>
          </aside>
        </div>

        <div class="form-message" :class="ui.productTypeMessage" role="status" aria-live="polite">
          {{ ui.productMessage }}
        </div>
    </section>

    <section
      v-if="businessProfile && !canManageCatalog"
      v-show="activeSection === 'profile'"
      class="card business-dashboard-freeze-card business-dashboard-panel"
      aria-label="Katalogu i ngrire"
    >
      <h2>Produktet hapen pasi admini ta verifikoje biznesin</h2>
    </section>

    <section
      v-if="canManageCatalog"
      v-show="activeSection === 'import'"
      class="card admin-list-card bulk-import-surface business-dashboard-panel"
      aria-label="Flexible catalog import"
    >
      <div class="admin-list-header">
        <div>
          <h2>Import</h2>
        </div>
      </div>

      <div class="bulk-import-shell">
        <article class="bulk-import-panel glass-strong">
          <div class="bulk-import-section-head">
            <div>
              <h3>Source setup</h3>
            </div>
            <span class="summary-chip">{{ importIsConfigLoading ? "Loading..." : `${importProfiles.length} profiles • ${importSources.length} sources` }}</span>
          </div>

          <div class="bulk-import-toolbar">
            <label class="field">
              <span>Source type</span>
              <select v-model="importSourceType" @change="handleImportSourceTypeChange">
                <option value="csv">CSV</option>
                <option value="xlsx">XLSX</option>
                <option value="json">JSON payload</option>
                <option value="api-json">API / JSON feed</option>
              </select>
            </label>

            <label class="field">
              <span>Mapping profile</span>
              <select v-model.number="importSelectedProfileId">
                <option :value="0">No saved profile</option>
                <option
                  v-for="profile in importProfiles"
                  :key="`import-profile-${profile.id}`"
                  :value="profile.id"
                >
                  {{ profile.profileName }} · {{ profile.sourceType }}
                </option>
              </select>
            </label>

            <label class="field">
              <span>Saved source</span>
              <select v-model.number="importSelectedSourceId">
                <option :value="0">No saved source</option>
                <option
                  v-for="source in importSources"
                  :key="`import-source-${source.id}`"
                  :value="source.id"
                >
                  {{ source.sourceName }} · {{ source.sourceType }}
                </option>
              </select>
            </label>
          </div>

          <div v-if="importSourceType === 'csv' || importSourceType === 'xlsx'" class="bulk-import-source-card">
            <label class="bulk-import-dropzone">
              <input
                ref="importFileInput"
                type="file"
                accept=".xlsx,.csv,text/csv,application/vnd.ms-excel,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
                @change="handleImportFileChange"
              >
              <strong>{{ importFile ? importFile.name : "Zgjidh skedarin e katalogut" }}</strong>
              <span>{{ importFile ? "Skedari eshte gati per preview." : "CSV ose XLSX nga furnitori ose nga biznesi yt." }}</span>
            </label>
          </div>

          <div v-else-if="importSourceType === 'json'" class="bulk-import-source-card bulk-import-source-card--stack">
            <label class="field">
              <span>Record path</span>
              <input v-model="importJsonRecordPath" type="text" placeholder="products.items" />
            </label>
            <label class="field">
              <span>JSON payload</span>
              <textarea
                v-model="importJsonPayload"
                rows="8"
                placeholder='[{"Product Name":"Basic Tee","Qty":5,"Price":12.99}]'
              />
            </label>
          </div>

          <div v-else class="bulk-import-source-card bulk-import-source-card--stack">
            <div class="bulk-import-toolbar">
              <label class="field">
                <span>Source name</span>
                <input v-model="importApiSource.sourceName" type="text" placeholder="Wholesale feed" />
              </label>
              <label class="field">
                <span>Method</span>
                <select v-model="importApiSource.method">
                  <option value="GET">GET</option>
                  <option value="POST">POST</option>
                  <option value="PUT">PUT</option>
                </select>
              </label>
              <label class="field">
                <span>Record path</span>
                <input v-model="importApiSource.recordPath" type="text" placeholder="data.products" />
              </label>
            </div>

            <label class="field">
              <span>API URL</span>
              <input v-model="importApiSource.url" type="url" placeholder="https://supplier.example.com/feed.json" />
            </label>

            <div class="bulk-import-toolbar">
              <label class="field">
                <span>Headers JSON</span>
                <textarea v-model="importApiSource.headersText" rows="5" placeholder='{"Authorization":"Bearer token"}' />
              </label>
              <label class="field">
                <span>Body JSON</span>
                <textarea v-model="importApiSource.bodyText" rows="5" placeholder='{"include":"products"}' />
              </label>
            </div>

            <div class="bulk-import-toolbar">
              <label class="field">
                <span>Sync interval (minutes)</span>
                <input v-model="importApiSource.syncIntervalMinutes" type="number" min="15" step="15" />
              </label>
              <label class="field field-checkbox">
                <span>Sync enabled</span>
                <input v-model="importApiSource.syncEnabled" type="checkbox" />
              </label>
            </div>
          </div>

          <div class="bulk-import-toolbar">
            <label class="field">
              <span>Profile name</span>
              <input v-model="importProfileDraftName" type="text" placeholder="Boutique CSV profile" />
            </label>
            <label class="field field-checkbox">
              <span>Save profile on preview</span>
              <input v-model="importSaveProfile" type="checkbox" />
            </label>
          </div>

          <div class="auth-form-actions bulk-import-actions">
            <button type="button" :disabled="importIsPreviewLoading" @click="prepareImportPreview">
              {{ importIsPreviewLoading ? "..." : "Preview" }}
            </button>
            <button
              class="button-secondary"
              type="button"
              :disabled="!importPreviewHasChanges || importIsPreviewLoading"
              @click="loadImportJobPreview(importCurrentJob?.id)"
            >
              Refresh
            </button>
            <button class="button-secondary" type="button" @click="saveCurrentImportProfile">
              Ruaj profil
            </button>
            <button
              v-if="importSourceType === 'api-json'"
              class="button-secondary"
              type="button"
              @click="saveCurrentImportSource"
            >
              Ruaj source
            </button>
            <button
              v-if="importSourceType === 'api-json'"
              class="button-secondary"
              type="button"
              :disabled="!importSelectedSourceId || importIsSyncLoading"
              @click="syncCurrentImportSource()"
            >
              {{ importIsSyncLoading ? "..." : "Sync" }}
            </button>
            <button class="button-secondary" type="button" @click="downloadImportTemplate">
              Template
            </button>
          </div>
        </article>

        <aside class="bulk-import-side">
          <article class="bulk-import-panel glass-soft">
            <div class="bulk-import-section-head">
              <div>
                <h3>Summary</h3>
              </div>
            </div>

            <div class="bulk-import-summary-grid">
              <div class="summary-chip glass-soft">
                <span>Total rows</span>
                <strong>{{ importSummary.totalRows }}</strong>
              </div>
              <div class="summary-chip glass-soft">
                <span>Valid rows</span>
                <strong>{{ importSummary.validRows }}</strong>
              </div>
              <div class="summary-chip glass-soft">
                <span>Invalid rows</span>
                <strong>{{ importSummary.invalidRows }}</strong>
              </div>
              <div class="summary-chip glass-soft">
                <span>Parent groups</span>
                <strong>{{ importSummary.parentProducts }}</strong>
              </div>
              <div class="summary-chip glass-soft">
                <span>Warnings</span>
                <strong>{{ importSummary.warningsCount }}</strong>
              </div>
              <div class="summary-chip glass-soft">
                <span>Hard errors</span>
                <strong>{{ importSummary.hardErrorsCount }}</strong>
              </div>
            </div>
          </article>

          <article class="bulk-import-panel glass-soft">
            <div class="bulk-import-section-head">
              <div>
                <h3>Recent jobs</h3>
              </div>
            </div>

            <div v-if="importRecentJobs.length === 0" class="admin-empty-state">
              Ende nuk ka import jobs te ruajtur.
            </div>
            <div v-else class="bulk-import-job-list">
              <button
                v-for="job in importRecentJobs.slice(0, 6)"
                :key="`import-job-${job.id}`"
                class="bulk-import-job-card"
                type="button"
                @click="loadImportJobPreview(job.id)"
              >
                <strong>#{{ job.id }} · {{ job.sourceType }}</strong>
                <span>{{ job.originalFilename || "Manual preview" }}</span>
                <small>{{ job.summary?.validRows || 0 }} valid · {{ job.summary?.parentProducts || 0 }} groups</small>
              </button>
            </div>
          </article>
        </aside>
      </div>

      <article v-if="importDetectedHeaders.length > 0" class="bulk-import-panel bulk-import-mapping glass-strong">
        <div class="bulk-import-section-head">
          <div>
            <h3>Field mapping</h3>
          </div>
        </div>

        <div class="bulk-import-mapping-grid">
          <label
            v-for="fieldName in importFieldList"
            :key="`mapping-${fieldName}`"
            class="field"
          >
            <span>{{ formatImportFieldLabel(fieldName) }}</span>
            <select v-model="importMapping[fieldName]">
              <option value="">Skip / not provided</option>
              <option
                v-for="header in importDetectedHeaders"
                :key="`map-${fieldName}-${header}`"
                :value="header"
              >
                {{ header }}
              </option>
            </select>
          </label>
        </div>
      </article>

      <div v-if="importSummary.warnings.length > 0" class="form-message error" role="status" aria-live="polite">
        {{ importSummary.warnings.join(" ") }}
      </div>

      <article class="bulk-import-shell bulk-import-shell--review">
        <div class="bulk-import-panel glass-soft">
          <div class="bulk-import-section-head">
            <div>
              <h3>Grouping preview</h3>
            </div>
          </div>

          <div v-if="importIsPreviewLoading" class="admin-empty-state">Duke pergatitur preview...</div>
          <div v-else-if="importPreviewGroups.length === 0" class="admin-empty-state">
            Krijo nje preview per te pare grouping-un e varianteve.
          </div>
          <div v-else class="bulk-import-group-list">
            <article
              v-for="group in importPreviewGroups.slice(0, 8)"
              :key="`import-group-${group.groupKey}`"
              class="bulk-import-group-card"
            >
              <div class="bulk-import-group-head">
                <div>
                  <h4>{{ group.parent?.title || "Untitled group" }}</h4>
                  <p>{{ group.parent?.canonicalCategory || "uncategorized" }} · {{ group.variants?.length || 0 }} variants</p>
                </div>
                <label class="field-checkbox bulk-import-check">
                  <span>Approve</span>
                  <input
                    type="checkbox"
                    :checked="importApprovedGroupKeys.includes(group.groupKey)"
                    @change="toggleImportGroupApproval(group.groupKey)"
                  >
                </label>
              </div>

              <div class="product-detail-tags product-detail-tags-admin">
                <span class="product-detail-tag">Group key: {{ group.groupKey }}</span>
                <span class="product-detail-tag">Price: {{ formatPrice(group.parent?.priceRange?.min || 0) }}</span>
                <span class="product-detail-tag">Stock: {{ group.parent?.stock || 0 }}</span>
              </div>

              <p v-if="group.warnings?.length" class="bulk-import-inline-warning">{{ group.warnings.join(" ") }}</p>
              <p v-if="group.errors?.length" class="bulk-import-inline-error">{{ group.errors.join(" ") }}</p>

              <div class="bulk-import-variant-list">
                <div
                  v-for="variant in group.variants?.slice(0, 4)"
                  :key="`${group.groupKey}-${variant.key}`"
                  class="bulk-import-variant-row"
                >
                  <strong>{{ variant.label || variant.key }}</strong>
                  <span>{{ variant.sku || "No SKU" }}</span>
                  <span>{{ formatPrice(variant.price || 0) }} · {{ variant.stock || 0 }} pcs</span>
                </div>
              </div>
            </article>
          </div>
        </div>

        <div class="bulk-import-panel glass-soft">
          <div class="bulk-import-section-head">
            <div>
              <h3>Row preview</h3>
            </div>
          </div>

          <div v-if="importIsPreviewLoading" class="admin-empty-state">Duke pergatitur rreshtat...</div>
          <div v-else-if="importPreviewRecords.length === 0" class="admin-empty-state">
            Ende nuk ka rreshta preview.
          </div>
          <div v-else class="bulk-import-record-list">
            <article
              v-for="record in importPreviewRecords.slice(0, 10)"
              :key="`import-record-${record.sourceRowId}`"
              class="bulk-import-record-card"
              :class="{
                'is-error': record.errors?.length,
                'is-skipped': importSkippedRowIds.includes(record.sourceRowId),
              }"
            >
              <div class="bulk-import-record-head">
                <div>
                  <strong>#{{ record.sourceRowId }}</strong>
                  <span>{{ record.normalizedData?.title || record.mappedData?.title || "Untitled row" }}</span>
                </div>
                <label class="field-checkbox bulk-import-check">
                  <span>Skip</span>
                  <input
                    type="checkbox"
                    :checked="importSkippedRowIds.includes(record.sourceRowId)"
                    @change="toggleImportRowSkip(record.sourceRowId)"
                  >
                </label>
              </div>

              <div class="product-detail-tags product-detail-tags-admin">
                <span class="product-detail-tag">Category: {{ record.normalizedData?.category || "—" }}</span>
                <span class="product-detail-tag">Group: {{ record.normalizedData?.groupKey || "—" }}</span>
                <span class="product-detail-tag">Price: {{ formatPrice(record.normalizedData?.price || 0) }}</span>
                <span class="product-detail-tag">Stock: {{ record.normalizedData?.stock || 0 }}</span>
              </div>

              <div class="bulk-import-record-grid">
                <div>
                  <h5>Mapped</h5>
                  <p>{{ record.mappedData?.title || "—" }}</p>
                </div>
                <div>
                  <h5>Normalized</h5>
                  <p>{{ record.normalizedData?.normalizedTitle || record.normalizedData?.title || "—" }}</p>
                </div>
                <div>
                  <h5>Attributes</h5>
                  <p>{{ Object.keys(record.normalizedData?.attributes || {}).length ? Object.entries(record.normalizedData.attributes).map(([key, value]) => `${formatImportFieldLabel(key)}: ${value}`).join(" · ") : "No variant attributes" }}</p>
                </div>
              </div>

              <p v-if="record.warnings?.length" class="bulk-import-inline-warning">{{ record.warnings.join(" ") }}</p>
              <p v-if="record.errors?.length" class="bulk-import-inline-error">{{ record.errors.join(" ") }}</p>
            </article>
          </div>
        </div>
      </article>

      <form class="auth-form" @submit.prevent="submitImportProducts">
        <div class="auth-form-actions">
          <button type="submit" :disabled="importIsCommitLoading || !importCurrentJob?.id">
            {{ importIsCommitLoading ? "..." : "Import" }}
          </button>
          <button class="button-secondary" type="button" @click="clearImportSelection()">Reset</button>
          <button class="button-secondary" type="button" @click="triggerImportPicker">File</button>
        </div>
      </form>

      <div class="form-message" :class="ui.importType" role="status" aria-live="polite">
        {{ ui.importMessage }}
      </div>
    </section>

    <section
      v-if="canManageCatalog"
      v-show="activeSection === 'offers'"
      class="card admin-list-card business-dashboard-panel"
      aria-label="Promocionet e biznesit"
    >
      <div class="admin-list-header">
        <div>
          <h2>Oferta</h2>
        </div>
      </div>

      <form class="auth-form" @submit.prevent="savePromotion">
        <div class="field-row">
          <label class="field">
            <span>Kodi</span>
            <input v-model="promotionForm.code" type="text" placeholder="p.sh. TREGO10" required>
          </label>
          <label class="field">
            <span>Lloji</span>
            <select v-model="promotionForm.discountType">
              <option value="percent">Perqindje</option>
              <option value="fixed">Vlere fikse</option>
            </select>
          </label>
          <label class="field">
            <span>Vlera</span>
            <input v-model="promotionForm.discountValue" type="number" min="0.01" step="0.01" placeholder="10" required>
          </label>
        </div>

        <div class="field-row">
          <label class="field">
            <span>Titulli</span>
            <input v-model="promotionForm.title" type="text" placeholder="Oferta e javes">
          </label>
          <label class="field">
            <span>Minimumi i shportes</span>
            <input v-model="promotionForm.minimumSubtotal" type="number" min="0" step="0.01" placeholder="0">
          </label>
          <label class="field">
            <span>Limit total</span>
            <input v-model="promotionForm.usageLimit" type="number" min="0" step="1" placeholder="0 = pa limit">
          </label>
        </div>

        <div class="field-row">
          <label class="field">
            <span>Limit per user</span>
            <input v-model="promotionForm.perUserLimit" type="number" min="1" step="1" placeholder="1">
          </label>
          <label class="field">
            <span>Seksioni</span>
            <select v-model="promotionForm.pageSection">
              <option value="">Te gjitha</option>
              <option
                v-for="option in PRODUCT_PAGE_SECTION_OPTIONS"
                :key="option.value"
                :value="option.value"
              >
                {{ option.label }}
              </option>
            </select>
          </label>
          <label class="field">
            <span>Kategoria</span>
            <select v-model="promotionForm.category">
              <option value="">Te gjitha</option>
              <option
                v-for="option in promotionCategoryOptions"
                :key="option.value"
                :value="option.value"
              >
                {{ option.label }}
              </option>
            </select>
          </label>
        </div>

        <div class="field-row">
          <label class="field">
            <span>Aktiv nga</span>
            <input v-model="promotionForm.startsAt" type="datetime-local">
          </label>
          <label class="field">
            <span>Aktiv deri</span>
            <input v-model="promotionForm.endsAt" type="datetime-local">
          </label>
          <label class="field">
            <span>Statusi</span>
            <select v-model="promotionForm.isActive">
              <option :value="true">Aktiv</option>
              <option :value="false">Pauzuar</option>
            </select>
          </label>
        </div>

        <label class="field">
          <span>Pershkrimi</span>
          <input v-model="promotionForm.description" type="text" placeholder="Pershkrim i shkurter per kete oferte">
        </label>

        <div class="auth-form-actions">
          <button type="submit">Ruaj</button>
        </div>
      </form>

      <div class="form-message" :class="ui.promotionType" role="status" aria-live="polite">
        {{ ui.promotionMessage }}
      </div>

      <div v-if="promotions.length > 0" class="notifications-list">
        <article v-for="promotion in promotions" :key="promotion.id" class="card account-section notification-card">
          <div class="notification-card-head">
            <div>
              <h2>{{ promotion.title || "Promocion" }}</h2>
            </div>
            <strong>
              {{ promotion.discountType === "percent" ? `${promotion.discountValue}%` : formatPrice(promotion.discountValue) }}
            </strong>
          </div>
          <div class="order-item-marketplace-meta">
            <span class="summary-chip">
              <span>Statusi</span>
              <strong>{{ promotion.isActive ? "Aktiv" : "Pauzuar" }}</strong>
            </span>
            <span class="summary-chip">
              <span>Perdorime</span>
              <strong>{{ promotion.usageLimit || "Pa limit" }}</strong>
            </span>
            <span class="summary-chip">
              <span>Per user</span>
              <strong>{{ promotion.perUserLimit || 1 }}</strong>
            </span>
          </div>
          <div class="order-item-marketplace-meta">
            <span v-if="promotion.pageSection" class="section-text">
              Seksioni: <strong>{{ formatPromotionSectionLabel(promotion.pageSection) }}</strong>
            </span>
            <span v-if="promotion.category" class="section-text">
              Kategoria: <strong>{{ formatCategoryLabel(promotion.category) }}</strong>
            </span>
            <span v-if="promotion.startsAt" class="section-text">
              Nga: <strong>{{ formatDateLabel(promotion.startsAt) }}</strong>
            </span>
            <span v-if="promotion.endsAt" class="section-text">
              Deri: <strong>{{ formatDateLabel(promotion.endsAt) }}</strong>
            </span>
          </div>
        </article>
      </div>
    </section>

    <section
      v-if="canManageCatalog"
      v-show="activeSection === 'products'"
      class="card admin-list-card products-management-surface business-dashboard-panel"
    >
      <div class="admin-list-header">
        <div>
          <h2>Produktet</h2>
        </div>
        <div class="auth-form-actions">
          <button type="button" @click="openAddProductForm">Shto</button>
          <button class="button-secondary" type="button" @click="triggerImportPicker">Import</button>
        </div>
      </div>

      <div class="products-controls glass-strong">
        <label class="admin-compact-search" aria-label="Kerko produktin e biznesit">
          <svg class="admin-compact-search-icon" viewBox="0 0 24 24" aria-hidden="true">
            <circle cx="11" cy="11" r="7"></circle>
            <path d="m20 20-3.5-3.5"></path>
          </svg>
          <input
            v-model="productSearchQuery"
            type="search"
            placeholder="Kerko produkt me numer, emer, kategori..."
          >
        </label>
        <label class="field">
          <span>Kategoria</span>
          <select v-model="productCategoryFilter">
            <option value="">Te gjitha</option>
            <option v-for="option in productCategoryOptions" :key="`filter-category-${option.value}`" :value="option.value">
              {{ option.label }}
            </option>
          </select>
        </label>
        <label class="field">
          <span>Stoku</span>
          <select v-model="productStockFilter">
            <option value="all">Te gjitha</option>
            <option value="in-stock">Ne stok</option>
            <option value="low-stock">Stok i ulet</option>
            <option value="out-of-stock">Pa stok</option>
          </select>
        </label>
        <label class="field">
          <span>Sort</span>
          <select v-model="productSort">
            <option value="updated-desc">Me te rejat</option>
            <option value="title-asc">Titulli A-Z</option>
            <option value="title-desc">Titulli Z-A</option>
            <option value="price-asc">Cmimi ne rritje</option>
            <option value="price-desc">Cmimi ne ulje</option>
            <option value="stock-asc">Stoku ne rritje</option>
            <option value="stock-desc">Stoku ne ulje</option>
          </select>
        </label>
      </div>

      <div v-if="hasSelectedProducts" class="products-bulk-actions glass-medium">
        <div class="products-bulk-actions-grid">
          <button class="button-secondary" type="button" @click="applyBulkVisibility(true)">Aktivo</button>
          <button class="button-secondary" type="button" @click="applyBulkVisibility(false)">Caktivizo</button>
          <label class="field">
            <span>Kategori</span>
            <select v-model="bulkCategoryValue">
              <option value="">Zgjidh kategorine</option>
              <option v-for="option in productCategoryOptions" :key="`bulk-category-${option.value}`" :value="option.value">
                {{ option.label }}
              </option>
            </select>
          </label>
          <button class="button-secondary" type="button" :disabled="!bulkCategoryValue" @click="applyBulkCategory">Ruaj</button>
          <label class="field">
            <span>Stok</span>
            <input v-model="bulkStockValue" type="number" min="0" step="1" placeholder="0">
          </label>
          <button class="button-secondary" type="button" :disabled="bulkStockValue === ''" @click="applyBulkStockUpdate">Ruaj</button>
          <button class="button-danger" type="button" @click="applyBulkDelete">Fshi</button>
          <button class="button-secondary" type="button" @click="clearSelectedProducts">Pastro</button>
        </div>
      </div>

      <div class="form-message" :class="ui.listType" role="status" aria-live="polite">
        {{ ui.listMessage }}
      </div>

      <div class="admin-products-list admin-products-list-scroll is-row-view">
        <div v-if="products.length === 0" class="admin-empty-state">
          Ende nuk ke artikuj. Shto nje produkt ose importo nje skedar.
        </div>

        <div v-else-if="filteredProducts.length === 0" class="admin-empty-state">
          Nuk u gjet asnje produkt per kete kerkim.
        </div>

        <template v-else>
          <article class="products-table-shell">
            <table class="products-table">
              <thead>
                <tr>
                  <th>
                    <input
                      type="checkbox"
                      :checked="filteredProducts.length > 0 && filteredProducts.every((item) => selectedProductIds.includes(item.id))"
                      @change="toggleSelectAllVisibleProducts"
                    >
                  </th>
                  <th>Produkti</th>
                  <th>Cmimi</th>
                  <th>Stoku</th>
                  <th>Kategoria</th>
                  <th>Statusi</th>
                  <th>Insights</th>
                  <th>Aksione</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="product in filteredProducts" :key="`row-${product.id}`">
                  <td>
                    <input
                      type="checkbox"
                      :checked="selectedProductIds.includes(product.id)"
                      @change="toggleProductSelection(product.id)"
                    >
                  </td>
                  <td class="products-table-product">
                    <img :src="product.imagePath" :alt="product.title" loading="lazy" decoding="async">
                    <div>
                      <strong>{{ product.title }}</strong>
                      <p>{{ product.description }}</p>
                    </div>
                  </td>
                  <td><strong>{{ formatPrice(product.price) }}</strong></td>
                  <td>{{ formatStockQuantity(product.stockQuantity) }}</td>
                  <td>{{ formatCategoryLabel(product.category) }}</td>
                  <td>
                    <span class="summary-chip">
                      <strong>{{ product.isPublic ? "Publik" : "I fshehur" }}</strong>
                    </span>
                  </td>
                  <td>
                    <div class="products-row-metrics" aria-label="Statistikat e produktit">
                      <span class="products-row-metric">
                        <small>Views</small>
                        <strong>{{ formatCount(product.viewsCount || 0) }}</strong>
                      </span>
                      <span class="products-row-metric">
                        <small>Wishlist</small>
                        <strong>{{ formatCount(product.wishlistCount || 0) }}</strong>
                      </span>
                      <span class="products-row-metric">
                        <small>Cart</small>
                        <strong>{{ formatCount(product.cartCount || 0) }}</strong>
                      </span>
                      <span class="products-row-metric">
                        <small>Share</small>
                        <strong>{{ formatCount(product.shareCount || 0) }}</strong>
                      </span>
                    </div>
                  </td>
                  <td>
                    <div class="products-row-actions">
                      <button class="button-secondary" type="button" @click="beginProductEdit(product)">Edito</button>
                      <button class="button-secondary" type="button" @click="handleToggleVisibility(product)">
                        {{ product.isPublic ? "Fsheh" : "Publiko" }}
                      </button>
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </article>
        </template>
      </div>
    </section>
      </div>
    </div>
  </section>
</template>

<style scoped>
:global(body[data-page="business-dashboard"] .page-main-admin) {
  padding: calc(var(--page-nav-clearance) + 12px) 0 20px;
  background: #ffffff;
}

:global(body[data-page="business-dashboard"]) {
  background: #ffffff;
}

.business-dashboard-page {
  --dashboard-gap: 8px;
  --dashboard-gap-tight: 6px;
  --dashboard-radius: 14px;
  --dashboard-radius-lg: 18px;
  --dashboard-pad: 10px;
  --dashboard-pad-tight: 8px;
  width: 100%;
  margin: 0 auto;
  display: grid;
  gap: var(--dashboard-gap);
  align-content: start;
  grid-auto-rows: min-content;
}

.business-dashboard-page > .admin-list-card,
.business-dashboard-sidebar,
.business-dashboard-tab-shell,
.business-dashboard-panel,
.business-dashboard-workspace-card,
.business-stock-alerts-card,
.business-shipping-card,
.business-profile-card,
.product-builder-card,
.business-dashboard-freeze-card {
  padding: var(--dashboard-pad);
  border-radius: var(--dashboard-radius-lg);
  background: #ffffff;
  border: 1px solid rgba(15, 23, 42, 0.18);
  box-shadow: 0 1px 1px rgba(15, 23, 42, 0.03);
}

.business-dashboard-tab-shell {
  padding: 6px;
}

.business-dashboard-shell {
  display: grid;
  grid-template-columns: 170px minmax(0, 1fr);
  gap: 12px;
  align-items: start;
}

.business-dashboard-sidebar {
  padding: 12px 10px;
  align-self: start;
  min-height: calc(100vh - var(--page-nav-clearance) - 40px);
  display: grid;
  gap: 18px;
  align-content: start;
}

.business-dashboard-main {
  min-width: 0;
  display: grid;
  gap: 10px;
  align-content: start;
}

.business-dashboard-brand {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 2px 4px;
}

.business-dashboard-brand-mark {
  width: 34px;
  height: 34px;
  border-radius: 12px;
  display: grid;
  place-items: center;
  background: linear-gradient(180deg, #7968ff 0%, #6558ea 100%);
  color: #ffffff;
  font-size: 0.95rem;
  font-weight: 700;
}

.business-dashboard-brand-copy {
  min-width: 0;
  display: grid;
  gap: 2px;
}

.business-dashboard-brand-copy strong {
  font-size: 1.02rem;
  color: #1f2937;
}

.business-dashboard-brand-copy span {
  font-size: 0.72rem;
  color: #94a3b8;
}

.business-dashboard-side-menu {
  display: grid;
  gap: 4px;
}

.business-dashboard-side-button {
  width: 100%;
  min-height: 38px;
  padding: 0 10px;
  border-radius: 12px;
  border: 1px solid transparent;
  background: transparent;
  color: #64748b;
  display: inline-flex;
  align-items: center;
  gap: 10px;
  font-size: 0.84rem;
  font-weight: 600;
  text-align: left;
}

.business-dashboard-side-button.is-active {
  background: #f3f0ff;
  color: #6d5df6;
  border-color: rgba(109, 93, 246, 0.08);
}

.business-dashboard-side-icon {
  width: 10px;
  height: 10px;
  border-radius: 999px;
  background: rgba(148, 163, 184, 0.45);
  flex: 0 0 auto;
}

.business-dashboard-side-button.is-active .business-dashboard-side-icon {
  background: #6d5df6;
}

.business-dashboard-toolbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 10px 12px;
}

.business-dashboard-toolbar-tabs {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 8px;
}

.business-dashboard-toolbar-tab {
  min-height: 38px;
  padding: 0 14px;
  border-radius: 12px;
  border: 1px solid #ececf3;
  background: #ffffff;
  color: #6b7280;
  font-size: 0.82rem;
  font-weight: 600;
  box-shadow: 0 1px 2px rgba(15, 23, 42, 0.03);
}

.business-dashboard-toolbar-tab.is-active {
  background: linear-gradient(180deg, #6f62f6 0%, #6356e8 100%);
  border-color: transparent;
  color: #ffffff;
  box-shadow: 0 10px 20px rgba(99, 86, 232, 0.18);
}

.business-dashboard-toolbar-meta {
  display: flex;
  align-items: center;
  gap: 10px;
}

.business-dashboard-toolbar-icon,
.business-dashboard-toolbar-range,
.business-dashboard-toolbar-avatar {
  border: 1px solid #ececf3;
  background: #ffffff;
  box-shadow: 0 1px 2px rgba(15, 23, 42, 0.03);
}

.business-dashboard-toolbar-icon {
  width: 38px;
  height: 38px;
  border-radius: 12px;
  display: grid;
  place-items: center;
  color: #6b7280;
  cursor: pointer;
}

.business-dashboard-toolbar-icon svg {
  width: 16px;
  height: 16px;
  stroke: currentColor;
  stroke-width: 1.8;
  stroke-linecap: round;
  stroke-linejoin: round;
  fill: none;
}

.business-dashboard-toolbar-range {
  min-height: 38px;
  padding: 0 12px;
  border-radius: 12px;
  display: inline-flex;
  align-items: center;
  color: #6b7280;
  font-size: 0.8rem;
  font-weight: 600;
}

.business-dashboard-toolbar-avatar {
  width: 38px;
  height: 38px;
  border-radius: 999px;
  display: grid;
  place-items: center;
  color: #8b83d9;
  font-size: 0.76rem;
  font-weight: 700;
}

.business-dashboard-overview {
  display: grid;
  gap: 10px;
}

.business-dashboard-overview-grid-stack {
  display: grid;
  gap: 10px;
}

.business-dashboard-metric-grid {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 10px;
}

.business-dashboard-metric-card {
  padding: 14px;
  display: grid;
  grid-template-columns: 40px minmax(0, 1fr);
  gap: 12px;
  align-items: center;
}

.business-dashboard-metric-icon {
  width: 40px;
  height: 40px;
  border-radius: 14px;
  background: #f3f0ff;
}

.business-dashboard-metric-card[data-tone="mint"] .business-dashboard-metric-icon {
  background: #e9fbf1;
}

.business-dashboard-metric-card[data-tone="amber"] .business-dashboard-metric-icon {
  background: #fff4db;
}

.business-dashboard-metric-card[data-tone="blue"] .business-dashboard-metric-icon {
  background: #eaf4ff;
}

.business-dashboard-metric-copy {
  display: grid;
  gap: 2px;
}

.business-dashboard-metric-copy span {
  font-size: 0.76rem;
  color: #8b93a7;
  font-weight: 600;
}

.business-dashboard-metric-copy strong {
  font-size: 1.45rem;
  line-height: 1;
  color: #1f2937;
}

.business-dashboard-metric-copy small {
  font-size: 0.74rem;
  color: #6dba8b;
  font-weight: 600;
}

.business-dashboard-overview-grid {
  display: grid;
  grid-template-columns: minmax(0, 1.9fr) minmax(260px, 0.86fr);
  gap: 10px;
}

.business-dashboard-overview-grid--bottom {
  grid-template-columns: repeat(3, minmax(0, 1fr));
}

.business-dashboard-chart-card,
.business-dashboard-actions-card,
.business-dashboard-list-card {
  padding: 14px;
  display: grid;
  gap: 12px;
}

.business-dashboard-card-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
}

.business-dashboard-card-head h2 {
  margin: 0;
  font-size: 1rem;
  color: #1f2937;
}

.business-dashboard-card-head span {
  font-size: 0.74rem;
  color: #9aa3b5;
}

.business-dashboard-card-pill {
  min-height: 30px;
  padding: 0 10px;
  border-radius: 10px;
  border: 1px solid #ececf3;
  display: inline-flex;
  align-items: center;
  color: #6b7280;
  font-size: 0.76rem;
  font-weight: 600;
}

.business-dashboard-chart-frame {
  display: grid;
  gap: 8px;
}

.business-dashboard-chart {
  width: 100%;
  height: auto;
  overflow: visible;
}

.business-dashboard-chart-grid line {
  stroke: #edf0f7;
  stroke-width: 1;
  stroke-dasharray: 4 6;
}

.business-dashboard-chart-area {
  fill: rgba(111, 98, 246, 0.1);
}

.business-dashboard-chart-line {
  fill: none;
  stroke: #6f62f6;
  stroke-width: 3;
  stroke-linecap: round;
  stroke-linejoin: round;
}

.business-dashboard-chart-point {
  fill: #6f62f6;
  stroke: #ffffff;
  stroke-width: 3;
}

.business-dashboard-chart-labels {
  display: grid;
  grid-template-columns: repeat(7, minmax(0, 1fr));
  gap: 6px;
}

.business-dashboard-chart-labels span {
  text-align: center;
  font-size: 0.72rem;
  color: #9aa3b5;
}

.business-dashboard-actions-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 10px;
}

.business-dashboard-action-card {
  min-height: 86px;
  padding: 12px;
  border-radius: 16px;
  border: 1px solid #eff1f7;
  background: #ffffff;
  display: grid;
  gap: 12px;
  align-content: start;
  text-align: left;
  color: #374151;
  cursor: pointer;
}

.business-dashboard-action-icon {
  width: 34px;
  height: 34px;
  border-radius: 12px;
  display: grid;
  place-items: center;
  background: #f3f0ff;
  color: #6f62f6;
  font-size: 0.92rem;
  font-weight: 700;
}

.business-dashboard-action-card[data-tone="mint"] .business-dashboard-action-icon {
  background: #e9fbf1;
  color: #20a464;
}

.business-dashboard-action-card[data-tone="amber"] .business-dashboard-action-icon {
  background: #fff4db;
  color: #e99527;
}

.business-dashboard-action-card[data-tone="pink"] .business-dashboard-action-icon {
  background: #ffe9f5;
  color: #eb5ea8;
}

.business-dashboard-action-card strong {
  font-size: 0.86rem;
  line-height: 1.2;
}

.business-dashboard-list-stack {
  display: grid;
  gap: 10px;
}

.business-dashboard-product-row,
.business-dashboard-alert-row,
.business-dashboard-discount-row {
  display: grid;
  align-items: center;
  gap: 10px;
}

.business-dashboard-product-row {
  grid-template-columns: 44px minmax(0, 1fr) auto;
}

.business-dashboard-product-row img {
  width: 44px;
  height: 44px;
  border-radius: 12px;
  object-fit: cover;
  background: #f8fafc;
}

.business-dashboard-product-copy,
.business-dashboard-alert-copy,
.business-dashboard-discount-copy {
  min-width: 0;
  display: grid;
  gap: 2px;
}

.business-dashboard-product-copy strong,
.business-dashboard-alert-copy strong,
.business-dashboard-discount-copy strong {
  font-size: 0.86rem;
  line-height: 1.2;
  color: #1f2937;
}

.business-dashboard-product-copy span,
.business-dashboard-alert-copy span,
.business-dashboard-discount-copy small {
  font-size: 0.72rem;
  color: #98a2b3;
}

.business-dashboard-row-meta {
  display: grid;
  justify-items: end;
  gap: 4px;
}

.business-dashboard-row-meta strong {
  font-size: 0.82rem;
  color: #1f2937;
}

.business-dashboard-row-status {
  min-height: 24px;
  padding: 0 8px;
  border-radius: 999px;
  display: inline-flex;
  align-items: center;
  background: #ebfbf2;
  color: #2aa76a;
  font-size: 0.68rem;
  font-weight: 700;
}

.business-dashboard-row-status.is-low {
  background: #fff4db;
  color: #e99527;
}

.business-dashboard-alert-row {
  grid-template-columns: 10px minmax(0, 1fr) auto;
}

.business-dashboard-alert-dot {
  width: 8px;
  height: 8px;
  border-radius: 999px;
  background: #ef4444;
}

.business-dashboard-alert-qty {
  font-size: 0.8rem;
  color: #ef4444;
}

.business-dashboard-discount-row {
  grid-template-columns: minmax(0, 1fr) auto;
  padding-bottom: 10px;
  border-bottom: 1px solid #f1f3f8;
}

.business-dashboard-discount-row:last-child {
  padding-bottom: 0;
  border-bottom: none;
}

.business-dashboard-discount-code {
  display: inline-flex;
  align-items: center;
  min-height: 22px;
  width: fit-content;
  padding: 0 8px;
  border-radius: 999px;
  background: #ffe9f5;
  color: #eb5ea8;
  font-size: 0.66rem;
  font-weight: 700;
  letter-spacing: 0.04em;
}

.business-dashboard-discount-status {
  font-size: 0.72rem;
  color: #20a464;
  font-weight: 700;
}

.business-dashboard-outline-action,
.business-dashboard-link-button {
  min-height: 34px;
  padding: 0 12px;
  border-radius: 12px;
  border: 1px solid #dcd8ff;
  background: #ffffff;
  color: #6f62f6;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  font-size: 0.76rem;
  font-weight: 700;
  cursor: pointer;
}

.business-dashboard-link-button {
  min-height: auto;
  padding: 0;
  border: none;
  box-shadow: none;
}

.business-dashboard-tab-list {
  display: grid;
  gap: 4px;
}

.business-dashboard-tab-button {
  width: 100%;
  min-height: 30px;
  padding: 0 9px;
  border-radius: 10px;
  border: 1px solid rgba(15, 23, 42, 0.14);
  background: #f7f8fb;
  color: #475569;
  display: inline-flex;
  align-items: center;
  justify-content: flex-start;
  text-align: left;
  font-size: 0.74rem;
  font-weight: 600;
}

.business-dashboard-tab-button.is-active {
  background: #ffffff;
  color: #111827;
  border-color: rgba(255, 106, 43, 0.35);
  box-shadow: inset 0 0 0 1px rgba(255, 106, 43, 0.12);
}

.business-dashboard-panel {
  margin: 0;
  display: grid;
  gap: 8px;
}

.admin-products-header,
.admin-list-header,
.profile-card-header,
.product-builder-head,
.product-builder-block-head,
.bulk-import-section-head {
  gap: 6px;
}

.admin-products-header {
  align-items: center;
  margin-bottom: 0;
}

.admin-products-header h1 {
  font-size: clamp(1.12rem, 1.55vw, 1.5rem);
  line-height: 1.05;
  margin: 0;
}

.business-dashboard-page h2 {
  margin: 0;
  font-size: 0.98rem;
  line-height: 1.1;
}

.business-dashboard-page h3 {
  margin: 0;
  font-size: 0.86rem;
  line-height: 1.15;
}

.admin-compact-copy,
.section-text,
.product-builder-note,
.product-upload-help {
  font-size: 0.72rem;
  line-height: 1.28;
}

.admin-compact-copy,
.section-text,
.product-upload-help,
.product-builder-note {
  margin: 0;
}

.business-dashboard-header-actions {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  flex-wrap: nowrap;
  gap: 5px;
}

.business-dashboard-header-meta {
  min-width: 0;
}

.business-dashboard-header-chip {
  min-width: 64px;
}

.business-dashboard-edit-access {
  display: inline-flex;
  align-items: center;
  gap: 0;
  max-width: none;
}

.business-dashboard-icon-button {
  width: 28px;
  min-width: 28px;
  height: 28px;
  min-height: 28px;
  padding: 0;
  border-radius: 9px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
}

.business-dashboard-icon-button svg {
  width: 13px;
  height: 13px;
  stroke: currentColor;
  stroke-width: 1.8;
  stroke-linecap: round;
  stroke-linejoin: round;
  fill: none;
}

.business-dashboard-page :deep(.section-label) {
  display: none;
}

.business-dashboard-page :deep(.summary-chip),
.business-dashboard-page .summary-chip {
  min-width: 0;
  padding: 5px 7px;
  border-radius: 9px;
  background: #ffffff;
  border: 1px solid rgba(15, 23, 42, 0.18);
  box-shadow: none;
}

.business-dashboard-page :deep(.summary-chip span),
.business-dashboard-page .summary-chip span {
  margin-bottom: 2px;
  font-size: 0.61rem;
  letter-spacing: 0.08em;
}

.business-dashboard-page :deep(.summary-chip strong),
.business-dashboard-page .summary-chip strong {
  font-size: 0.82rem;
}

.business-dashboard-analytics-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(96px, 1fr));
  gap: 6px;
  margin: 0;
}

.business-dashboard-workspace-card {
  display: grid;
  gap: 5px;
  margin: 0;
}

.business-dashboard-workspace-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(78px, 1fr));
  gap: 4px;
}

.business-dashboard-workspace-action,
.business-dashboard-next-card {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-height: 30px;
  padding: 0 7px;
  border-radius: 9px;
  border: 1px solid rgba(15, 23, 42, 0.16);
  background: #ffffff;
  color: inherit;
  text-align: center;
  box-shadow: none;
}

.business-dashboard-workspace-action strong,
.business-dashboard-next-card strong {
  color: #1f2937;
  font-size: 0.72rem;
  line-height: 1;
}

.business-dashboard-workspace-action:disabled {
  opacity: 0.58;
  cursor: not-allowed;
}

.business-dashboard-layout {
  display: grid;
  grid-template-columns: minmax(260px, 300px) minmax(0, 1fr);
  gap: 8px;
  align-items: start;
}

.business-dashboard-layout--single {
  grid-template-columns: minmax(0, 1fr);
}

.business-shipping-card {
  margin: 0;
}

.business-shipping-settings-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 5px;
}

.business-shipping-method-card {
  padding: 7px;
  border-radius: 9px;
  border: 1px solid rgba(15, 23, 42, 0.18);
  background: #ffffff;
  box-shadow: none;
}

.business-shipping-method-head {
  display: flex;
  align-items: start;
  justify-content: space-between;
  gap: 8px;
  margin-bottom: 6px;
}

.business-shipping-method-head strong {
  display: block;
  color: #2d4334;
  font-size: 0.84rem;
}

.business-shipping-toggle {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  color: #5c7061;
  font-size: 0.72rem;
  white-space: nowrap;
}

.business-shipping-toggle input {
  accent-color: #4f7c63;
}

.business-shipping-city-rates {
  display: grid;
  gap: 5px;
  margin-top: 4px;
  padding: 7px;
  border-radius: 9px;
  border: 1px solid rgba(15, 23, 42, 0.18);
  background: #ffffff;
  box-shadow: none;
}

.business-shipping-city-rates-head {
  display: flex;
  align-items: start;
  justify-content: space-between;
  gap: 8px;
}

.business-shipping-city-rates-head strong {
  display: block;
  color: #2d4334;
  font-size: 0.82rem;
}

.business-shipping-city-list {
  display: grid;
  gap: 6px;
}

.business-shipping-city-row {
  display: grid;
  grid-template-columns: minmax(0, 1.35fr) minmax(100px, 0.7fr) auto;
  gap: 8px;
  align-items: end;
}

.business-shipping-city-add,
.business-shipping-city-remove,
.business-stock-alert-action {
  min-height: 28px;
  padding: 0 8px;
  border-radius: 9px;
  font-size: 0.72rem;
}

.marketplace-status-card {
  display: flex;
  align-items: start;
  justify-content: space-between;
  gap: 6px;
  padding: 8px;
  border-radius: 10px;
  border: 1px solid rgba(15, 23, 42, 0.18);
  background: #ffffff;
}

.admin-edit-state {
  margin: 0;
  padding: 8px 10px;
  border-radius: 10px;
  line-height: 1.2;
  font-size: 0.74rem;
}

.field-row {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 6px;
}

.field-row-3 {
  grid-template-columns: repeat(3, minmax(0, 1fr));
}

.business-dashboard-page :deep(.field) {
  margin: 0;
}

.business-dashboard-page :deep(.field span) {
  font-size: 0.68rem;
  margin-bottom: 2px;
}

.business-dashboard-page :deep(.field input),
.business-dashboard-page :deep(.field select),
.business-dashboard-page :deep(.field textarea) {
  min-height: 32px;
  padding: 5px 8px;
  font-size: 0.78rem;
  border-radius: 9px;
  background: #ffffff;
  border: 1px solid rgba(15, 23, 42, 0.18);
}

.business-dashboard-page :deep(.field textarea) {
  min-height: 64px;
  resize: vertical;
}

.business-dashboard-page :deep(.auth-form) {
  gap: 5px;
  margin-top: 6px;
}

.business-dashboard-page :deep(.auth-form-actions) {
  display: flex;
  flex-wrap: wrap;
  gap: 5px;
}

.business-dashboard-page :deep(.auth-form-actions > button),
.business-dashboard-page :deep(.button-secondary),
.business-dashboard-page :deep(.button-danger),
.business-dashboard-page .nav-action,
.business-dashboard-page .products-row-actions button {
  width: auto;
  min-height: 28px;
  padding: 0 8px;
  border-radius: 9px;
  font-size: 0.72rem;
}

.product-builder-card {
  display: grid;
  gap: 6px;
}

.product-builder-head,
.product-builder-block-head {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
}

.product-builder-shell {
  display: grid;
  grid-template-columns: minmax(0, 2.35fr) minmax(176px, 0.62fr);
  gap: 6px;
  align-items: start;
}

.product-builder-form,
.product-builder-aside {
  display: grid;
  gap: 5px;
}

.product-builder-steps {
  display: grid;
  grid-template-columns: repeat(5, minmax(0, 1fr));
  gap: 3px;
}

.product-builder-step {
  display: grid;
  gap: 1px;
  padding: 6px 7px;
  border-radius: 9px;
  border: 1px solid rgba(15, 23, 42, 0.18);
  background: #ffffff;
  color: inherit;
  text-align: left;
  box-shadow: none;
}

.product-builder-step strong {
  font-size: 0.72rem;
}

.product-builder-step span,
.product-builder-step small {
  display: none;
}

.product-builder-step.is-active {
  border-color: rgba(255, 106, 43, 0.4);
  box-shadow: none;
}

.product-builder-step.is-done small {
  color: #ff6a2b;
}

.product-builder-block,
.product-builder-aside-card {
  display: grid;
  gap: 5px;
  padding: 7px;
  border-radius: 9px;
  border: 1px solid rgba(15, 23, 42, 0.18);
  background: #ffffff;
  box-shadow: none;
}

.product-builder-block.is-active {
  border-color: rgba(255, 106, 43, 0.22);
}

.product-builder-inline-summary {
  display: flex;
  flex-wrap: wrap;
  gap: 5px;
}

.product-builder-note.is-warning {
  color: #b45309;
}

.product-builder-review-card {
  display: grid;
  grid-template-columns: minmax(112px, 148px) minmax(0, 1fr);
  gap: 8px;
  align-items: stretch;
}

.product-builder-review-media {
  min-height: 118px;
  overflow: hidden;
  border-radius: 10px;
  background: #f8fafc;
}

.product-builder-review-media img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
}

.product-builder-review-empty {
  width: 100%;
  height: 100%;
  min-height: 118px;
  display: grid;
  place-items: center;
  color: #6b7280;
  font-weight: 700;
}

.product-builder-review-copy {
  display: grid;
  gap: 6px;
}

.product-builder-review-copy h3,
.product-builder-aside-card h3 {
  margin: 0;
  color: #1f2937;
}

.product-builder-review-copy p,
.product-builder-aside-copy {
  margin: 0;
}

.product-builder-price-preview {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 6px;
}

.product-builder-price-preview strong {
  font-size: 0.9rem;
  color: #1f2937;
}

.product-builder-price-preview span {
  color: #6b7280;
  text-decoration: line-through;
}

.product-builder-price-preview mark {
  padding: 4px 7px;
  border-radius: 999px;
  background: rgba(255, 106, 43, 0.14);
  color: #c2410c;
}

.product-builder-checklist {
  list-style: none;
  margin: 0;
  padding: 0;
  display: grid;
  gap: 4px;
}

.product-builder-checklist-item {
  display: grid;
  grid-template-columns: 12px minmax(0, 1fr) auto;
  align-items: center;
  gap: 5px;
  padding: 6px 7px;
  border-radius: 9px;
  background: #ffffff;
  border: 1px solid rgba(15, 23, 42, 0.14);
}

.product-builder-checklist-item strong {
  color: #1f2937;
  font-size: 0.8rem;
}

.product-builder-checklist-item small {
  color: #6b7280;
  font-size: 0.7rem;
}

.product-builder-checklist-dot {
  width: 9px;
  height: 9px;
  border-radius: 999px;
  background: rgba(47, 52, 70, 0.18);
}

.product-builder-checklist-item.is-done .product-builder-checklist-dot {
  background: #ff6a2b;
}

.product-builder-aside-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 6px;
}

.business-dashboard-page :deep(.product-upload-preview) {
  gap: 6px;
}

.business-dashboard-page :deep(.product-upload-preview-item) {
  padding: 5px;
  border-radius: 9px;
  background: #ffffff;
  border: 1px solid rgba(15, 23, 42, 0.14);
}

.business-dashboard-page :deep(.product-upload-preview-image) {
  border-radius: 8px;
}

.business-dashboard-page :deep(.product-upload-empty) {
  min-height: 78px;
  padding: 10px;
  border-radius: 9px;
  font-size: 0.72rem;
  background: #ffffff;
  border: 1px solid rgba(15, 23, 42, 0.14);
}

.bulk-import-shell {
  display: grid;
  grid-template-columns: minmax(0, 1.65fr) minmax(230px, 0.72fr);
  gap: 6px;
  align-items: start;
}

.bulk-import-shell--review {
  grid-template-columns: minmax(0, 1.2fr) minmax(0, 1fr);
  margin-top: 0;
}

.bulk-import-panel {
  display: grid;
  gap: 5px;
  padding: 7px;
  border-radius: 9px;
  border: 1px solid rgba(15, 23, 42, 0.18);
  background: #ffffff;
  box-shadow: none;
}

.bulk-import-side,
.bulk-import-source-card,
.bulk-import-job-list,
.bulk-import-group-list,
.bulk-import-record-list,
.bulk-import-variant-list {
  display: grid;
  gap: 6px;
}

.bulk-import-source-card--stack {
  gap: 6px;
}

.bulk-import-toolbar {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 6px;
}

.bulk-import-toolbar .field textarea,
.bulk-import-source-card textarea {
  min-height: 72px;
}

.field-checkbox {
  display: grid;
  gap: 6px;
  align-content: start;
}

.field-checkbox input {
  width: 16px;
  height: 16px;
  margin: 0;
}

.bulk-import-actions {
  flex-wrap: wrap;
}

.bulk-import-summary-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 5px;
}

.bulk-import-job-card,
.bulk-import-group-card,
.bulk-import-record-card {
  display: grid;
  gap: 5px;
  padding: 7px 8px;
  border-radius: 9px;
  border: 1px solid rgba(15, 23, 42, 0.18);
  background: #ffffff;
  text-align: left;
  color: inherit;
}

.bulk-import-job-card strong,
.bulk-import-group-card h4,
.bulk-import-record-head strong {
  color: #111827;
}

.bulk-import-job-card span,
.bulk-import-group-head p,
.bulk-import-record-head span,
.bulk-import-record-grid p,
.bulk-import-variant-row span {
  color: #64748b;
}

.bulk-import-group-head,
.bulk-import-record-head {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 8px;
}

.bulk-import-group-head h4,
.bulk-import-record-grid h5 {
  margin: 0;
}

.bulk-import-group-head p,
.bulk-import-record-grid p {
  margin: 0;
}

.bulk-import-check {
  justify-items: end;
}

.bulk-import-mapping-grid {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 6px;
}

.bulk-import-variant-row,
.bulk-import-record-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 5px;
}

.bulk-import-record-card.is-error {
  border-color: rgba(220, 38, 38, 0.24);
  background: rgba(254, 242, 242, 0.92);
}

.bulk-import-record-card.is-skipped {
  opacity: 0.72;
}

.bulk-import-inline-warning,
.bulk-import-inline-error {
  margin: 0;
  font-size: 0.72rem;
  line-height: 1.32;
}

.bulk-import-inline-warning {
  color: #b45309;
}

.bulk-import-inline-error {
  color: #b91c1c;
}

.bulk-import-section-head p {
  margin: 0;
}

.notifications-list {
  display: grid;
  gap: 5px;
  grid-template-columns: repeat(auto-fit, minmax(190px, 1fr));
}

.business-stock-alerts-card {
  display: grid;
  gap: 5px;
  margin: 0;
}

.business-stock-alerts-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(170px, 1fr));
  gap: 5px;
}

.business-stock-alert-card {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto;
  gap: 5px;
  align-items: center;
  padding: 6px 7px;
  border-radius: 9px;
  border: 1px solid rgba(15, 23, 42, 0.18);
  background: #ffffff;
}

.business-stock-alert-copy {
  display: grid;
  gap: 2px;
}

.business-stock-alert-copy strong {
  color: #2f3a4d;
  font-size: 0.82rem;
}

.business-stock-alert-copy p {
  margin: 0;
  color: #6c7285;
  font-size: 0.72rem;
  line-height: 1.25;
}

.business-stock-alert-category {
  font-size: 0.62rem;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.business-stock-alerts-note {
  margin: 0;
  color: #6b5d76;
  font-size: 0.82rem;
  line-height: 1.4;
}

.products-management-surface {
  gap: 6px;
}

.products-controls {
  grid-template-columns: minmax(220px, 1.65fr) repeat(3, minmax(94px, 0.72fr));
  gap: 4px;
  align-items: end;
  padding: 4px 5px;
  border-radius: 9px;
  margin-bottom: 4px;
  background: #ffffff;
  border: 1px solid rgba(15, 23, 42, 0.18);
  box-shadow: none;
}

.products-controls .field,
.products-bulk-actions-grid .field {
  margin: 0;
}

.products-controls .admin-compact-search {
  margin: 0;
}

.products-bulk-actions {
  margin: 0;
  padding: 4px 5px;
  border-radius: 9px;
  background: #ffffff;
  border: 1px solid rgba(15, 23, 42, 0.18);
  box-shadow: none;
}

.products-bulk-actions p {
  margin: 0 0 3px;
  font-size: 0.72rem;
}

.products-bulk-actions-grid {
  display: grid;
  gap: 5px;
  grid-template-columns: repeat(8, minmax(72px, 1fr));
  align-items: end;
}

.products-table-shell {
  border-radius: 9px;
  background: #ffffff;
  border: 1px solid rgba(15, 23, 42, 0.18);
  box-shadow: none;
}

.products-table th,
.products-table td {
  padding: 5px 4px;
  font-size: 0.72rem;
}

.products-table-product {
  min-width: 172px;
}

.products-table-product img {
  width: 28px;
  height: 28px;
  border-radius: 6px;
}

.products-table-product p {
  margin: 1px 0 0;
  font-size: 0.62rem;
  line-height: 1.1;
  display: -webkit-box;
  -webkit-line-clamp: 1;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.products-row-actions {
  display: inline-flex;
  gap: 3px;
}

.products-row-metrics {
  min-width: 98px;
  gap: 3px;
}

.products-row-metric {
  padding: 3px 4px;
  border-radius: 7px;
  background: #ffffff;
  border: 1px solid rgba(15, 23, 42, 0.14);
}

.products-row-metric small {
  font-size: 0.5rem;
}

.products-row-metric strong {
  font-size: 0.64rem;
}

@media (max-width: 1240px) {
  .business-dashboard-shell {
    grid-template-columns: 150px minmax(0, 1fr);
  }

  .business-dashboard-metric-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }

  .business-dashboard-overview-grid,
  .business-dashboard-overview-grid--bottom {
    grid-template-columns: 1fr;
  }

  .business-dashboard-layout,
  .bulk-import-shell,
  .bulk-import-shell--review,
  .product-builder-shell {
    grid-template-columns: 1fr;
  }

  .products-controls {
    grid-template-columns: repeat(3, minmax(0, 1fr));
  }

  .products-bulk-actions-grid {
    grid-template-columns: repeat(4, minmax(0, 1fr));
  }

  .business-dashboard-header-actions {
    justify-content: flex-start;
  }
}

@media (max-width: 980px) {
  .business-dashboard-shell {
    grid-template-columns: 1fr;
  }

  .business-dashboard-sidebar {
    padding: 10px;
    min-height: auto;
  }

  .business-dashboard-side-menu {
    grid-template-columns: repeat(3, minmax(0, 1fr));
    display: grid;
  }

  .business-dashboard-toolbar {
    flex-direction: column;
    align-items: stretch;
  }

  .business-dashboard-toolbar-meta {
    justify-content: space-between;
  }

  .business-dashboard-toolbar-tabs {
    width: 100%;
  }

  .business-dashboard-analytics-grid,
  .business-shipping-settings-grid,
  .bulk-import-toolbar,
  .bulk-import-summary-grid,
  .bulk-import-mapping-grid,
  .bulk-import-variant-row,
  .bulk-import-record-grid,
  .product-builder-aside-grid,
  .field-row-3,
  .product-builder-steps,
  .products-controls,
  .products-bulk-actions-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

@media (max-width: 720px) {
  .business-dashboard-page {
    width: min(100%, calc(100vw - 16px));
    gap: 8px;
  }

  .business-dashboard-metric-grid,
  .business-dashboard-actions-grid,
  .business-dashboard-side-menu {
    grid-template-columns: 1fr;
  }

  .admin-products-header,
  .admin-list-header,
  .profile-card-header,
  .product-builder-head,
  .product-builder-block-head,
  .bulk-import-section-head,
  .field-row,
  .field-row-3,
  .business-dashboard-workspace-grid,
  .business-stock-alerts-grid,
  .business-shipping-settings-grid,
  .product-builder-steps,
  .product-builder-review-card,
  .bulk-import-toolbar,
  .bulk-import-summary-grid,
  .bulk-import-mapping-grid,
  .bulk-import-variant-row,
  .bulk-import-record-grid,
  .products-controls,
  .products-bulk-actions-grid {
    grid-template-columns: 1fr;
    display: grid;
  }

  .business-dashboard-header-actions,
  .business-dashboard-edit-access {
    width: 100%;
    align-items: flex-start;
  }

  .business-dashboard-edit-access {
    display: flex;
    flex-direction: column;
  }

  .business-dashboard-analytics-grid {
    grid-template-columns: 1fr;
  }

  .business-dashboard-toolbar-range,
  .business-dashboard-toolbar-avatar,
  .business-dashboard-toolbar-icon,
  .business-dashboard-toolbar-tab {
    width: 100%;
    justify-content: center;
  }

  .business-dashboard-product-row,
  .business-dashboard-alert-row,
  .business-dashboard-discount-row {
    grid-template-columns: 1fr;
    align-items: start;
  }

  .business-dashboard-row-meta {
    justify-items: start;
  }

  .marketplace-status-card,
  .business-stock-alert-card,
  .business-shipping-city-row {
    grid-template-columns: 1fr;
    display: grid;
  }

  .business-shipping-city-rates-head {
    flex-direction: column;
    align-items: stretch;
  }

  .products-row-actions {
    flex-wrap: wrap;
  }
}
</style>
