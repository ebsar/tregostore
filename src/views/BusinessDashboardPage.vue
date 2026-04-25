<script setup>
import { computed, nextTick, onBeforeUnmount, onMounted, reactive, ref, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import DashboardBarChart from "../components/dashboard/DashboardBarChart.vue";
import DashboardDonutChart from "../components/dashboard/DashboardDonutChart.vue";
import DashboardLineChart from "../components/dashboard/DashboardLineChart.vue";
import DashboardShell from "../components/dashboard/DashboardShell.vue";
import CompactProductConfigurator from "../components/CompactProductConfigurator.vue";
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
const businessOrders = ref([]);
const productSearchQuery = ref(readRouteSearchQuery(route.query.q));
const logoFile = ref(null);
const logoPreviewUrl = ref("");
const productMediaItems = ref([]);
const editingProduct = ref(null);
const productFormCollapsed = ref(false);
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
  return productMediaItems.value.map((item, index) => ({
    id: item.id,
    kind: item.kind,
    path: item.path,
    label: index === 0 ? "Main image" : `Image ${index + 1}`,
  }));
});
const businessLogoPreview = computed(() => logoPreviewUrl.value || profileForm.businessLogoPath || "");
const productVariantEntries = computed(() => buildVariantInventoryFromForm(productForm));
const productMediaCount = computed(() => productPreviewItems.value.length);
const productStockTotal = computed(() =>
  productVariantEntries.value.reduce((total, entry) => total + Math.max(0, Number(entry.quantity || 0)), 0),
);
const productPreviewImage = computed(() => productPreviewItems.value[0]?.path || "");
const productPreviewVariant = computed(() =>
  productVariantEntries.value.find((entry) => Number(entry.quantity || 0) > 0)
  || productVariantEntries.value[0]
  || null,
);
const productPreviewPrice = computed(() => {
  const variantPrice = Number(productPreviewVariant.value?.price || 0);
  if (variantPrice > 0) {
    return variantPrice;
  }
  return Number(productForm.price || 0);
});
const productPreviewSummary = computed(() => {
  const attributes = productPreviewVariant.value?.attributes && typeof productPreviewVariant.value.attributes === "object"
    ? Object.entries(productPreviewVariant.value.attributes)
      .filter(([, value]) => String(value || "").trim())
      .map(([key, value]) => ({
        key,
        label: String(key || "")
          .replace(/([a-z])([A-Z])/g, "$1 $2")
          .replace(/[_-]+/g, " ")
          .replace(/\b\w/g, (match) => match.toUpperCase())
          .trim(),
        value: String(value || "").trim(),
      }))
    : [];

  return [
    { label: "Category", value: formatCategoryLabel(productForm.category) || "Choose category" },
    { label: "SKU", value: String(productForm.articleNumber || "").trim() || "Set article / SKU" },
    { label: "Stock", value: formatStockQuantity(productStockTotal.value) || "0" },
    {
      label: "Variant",
      value: String(productPreviewVariant.value?.label || "").trim() || "No variant configured",
    },
    ...attributes.slice(0, 4),
  ];
});
const productPriceValue = computed(() => Number(productForm.price || 0));
const productPricingReady = computed(() => {
  if (!Number.isFinite(productPriceValue.value) || productPriceValue.value <= 0) {
    return false;
  }
  const compareAtPriceValue = Number(productForm.compareAtPrice || 0);
  if (!compareAtPriceValue) {
    return true;
  }
  if (compareAtPriceValue <= productPriceValue.value) {
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
const inventorySummaryCards = computed(() => ([
  {
    label: "All products",
    value: formatCount(products.value.length),
    meta: `${formatCount(products.value.filter((product) => Boolean(product.isPublic)).length)} active`,
  },
  {
    label: "Low stock",
    value: formatCount(lowStockProducts.value.length),
    meta: `${STOCK_ALERT_THRESHOLD} units or fewer`,
  },
  {
    label: "Out of stock",
    value: formatCount(outOfStockProducts.value.length),
    meta: "Needs restock",
  },
  {
    label: "Hidden",
    value: formatCount(products.value.filter((product) => !product.isPublic).length),
    meta: "Not visible to users",
  },
]));
const engagementSummaryItems = computed(() => ([
  { label: "Views", value: formatCount(analytics.value?.viewsCount || 0) },
  { label: "Wishlist", value: formatCount(analytics.value?.wishlistCount || 0) },
  { label: "Cart", value: formatCount(analytics.value?.cartCount || 0) },
  { label: "Share", value: formatCount(analytics.value?.shareCount || 0) },
]));
const businessOrderCounts = computed(() => ({
  pending: businessOrders.value.filter((order) =>
    ["pending_confirmation", "confirmed", "packed", "shipped", "partially_confirmed"]
      .includes(String(order.fulfillmentStatus || order.status || "").trim().toLowerCase()),
  ).length,
  completed: businessOrders.value.filter((order) =>
    ["delivered", "returned"].includes(String(order.fulfillmentStatus || order.status || "").trim().toLowerCase()),
  ).length,
}));
const businessOrderSummary = computed(() => ([
  { label: "Total orders", value: formatCount(businessOrders.value.length), meta: "Across your store" },
  { label: "Need action", value: formatCount(businessOrderCounts.value.pending), meta: "Pending or in progress" },
  { label: "Completed", value: formatCount(businessOrderCounts.value.completed), meta: "Delivered or returned" },
]));
const businessOrderBars = computed(() => ([
  { label: "Need action", value: businessOrderCounts.value.pending },
  { label: "Completed", value: businessOrderCounts.value.completed },
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
    label: "Overview",
    navLabel: "Overview",
    visible: true,
  },
  {
    key: "stock",
    label: "Stock",
    navLabel: "Stock",
    visible: canManageCatalog.value,
  },
  {
    key: "shipping",
    label: "Shipping",
    navLabel: "Shipping",
    visible: canManageCatalog.value,
  },
  {
    key: "products",
    label: "Add product",
    navLabel: "Add Product",
    visible: canManageCatalog.value,
  },
  {
    key: "inventory",
    label: "Products",
    navLabel: "Products",
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
    label: "Discounts",
    navLabel: "Discounts",
    visible: canManageCatalog.value,
  },
  {
    key: "payouts",
    label: "Payouts",
    navLabel: "Payouts",
    visible: canManageCatalog.value,
  },
  {
    key: "profile",
    label: "Store settings",
    navLabel: "Store Settings",
    visible: shouldShowProfileCard.value,
  },
]).filter((section) => section.visible));
const activeSectionMeta = computed(() =>
  dashboardSections.value.find((section) => section.key === activeSection.value) || dashboardSections.value[0] || null,
);
const dashboardSidebarSections = computed(() => dashboardSections.value.filter((section) =>
  ["analytics", "products", "inventory", "stock", "import", "offers", "payouts", "profile"].includes(section.key),
));
const businessShellNavItems = computed(() => {
  const routeItems = [
    { key: "analytics", label: "Overview", icon: "dashboard", to: "/biznesi-juaj?view=analytics", group: "Core" },
    { key: "orders", label: "Orders", icon: "orders", to: "/porosite-e-biznesit", group: "Core" },
    { key: "inventory", label: "Products", icon: "products", to: "/biznesi-juaj?view=inventory", badge: stockAlertCount.value > 0 ? String(stockAlertCount.value) : "", group: "Inventory" },
    { key: "products", label: "Add Product", icon: "bag", to: "/biznesi-juaj?view=products", group: "Inventory" },
    { key: "stock", label: "Stock", icon: "stock", to: "/biznesi-juaj?view=stock", badge: stockAlertCount.value > 0 ? String(stockAlertCount.value) : "", group: "Inventory" },
    { key: "import", label: "Import", icon: "import", to: "/biznesi-juaj?view=import", group: "Inventory" },
    { key: "offers", label: "Discounts", icon: "offers", to: "/biznesi-juaj?view=offers", group: "Growth" },
    { key: "payouts", label: "Payouts", icon: "shipping", to: "/biznesi-juaj?view=payouts", group: "Growth" },
    { key: "shipping", label: "Shipping", icon: "shipping", to: "/biznesi-juaj?view=shipping", group: "Store" },
    { key: "profile", label: "Store Settings", icon: "settings", to: "/biznesi-juaj?view=profile", group: "Store" },
    { key: "support", label: "Support", icon: "messages", to: "/mesazhet", group: "Store" },
  ];

  return routeItems.filter((item) => {
    if (item.key === "orders" || item.key === "analytics") {
      return true;
    }
    if (item.key === "profile") {
      return shouldShowProfileCard.value;
    }
    return canManageCatalog.value;
  });
});
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
  { key: "products", label: "Add Product", tone: "violet" },
  { key: "inventory", label: "Inventory", tone: "mint" },
  { key: "import", label: "Import", tone: "amber" },
  { key: "offers", label: "Discounts", tone: "pink" },
]);
const businessNotificationCount = computed(() => stockAlertCount.value);
const recentDashboardProducts = computed(() => products.value.slice(0, 4));
const recentDiscounts = computed(() => promotions.value.slice(0, 3));
const payoutRows = computed(() =>
  businessOrders.value
    .flatMap((order) =>
      (Array.isArray(order?.items) ? order.items : []).map((item) => ({
        orderId: Number(order.id || 0),
        orderCreatedAt: String(order.createdAt || ""),
        productTitle: String(item?.title || item?.productTitle || "Product").trim(),
        variantLabel: String(item?.variantLabel || "").trim(),
        payoutStatus: String(item?.payoutStatus || "pending").trim().toLowerCase(),
        payoutDueAt: String(item?.payoutDueAt || "").trim(),
        sellerEarningsAmount: Number(item?.sellerEarningsAmount || 0),
        commissionAmount: Number(item?.commissionAmount || 0),
        fulfillmentStatus: String(item?.fulfillmentStatus || "").trim().toLowerCase(),
      })),
    )
    .sort((left, right) =>
      new Date(String(right.orderCreatedAt || "").replace(" ", "T")).getTime()
      - new Date(String(left.orderCreatedAt || "").replace(" ", "T")).getTime()
    ),
);
const payoutSummaryCards = computed(() => {
  const totals = payoutRows.value.reduce((accumulator, row) => {
    const earnings = Number(row.sellerEarningsAmount || 0);
    accumulator.total += earnings;
    if (row.payoutStatus === "ready") {
      accumulator.ready += earnings;
    } else if (row.payoutStatus === "paid") {
      accumulator.paid += earnings;
    } else if (row.payoutStatus === "on_hold") {
      accumulator.onHold += earnings;
    } else {
      accumulator.pending += earnings;
    }
    return accumulator;
  }, {
    total: 0,
    ready: 0,
    pending: 0,
    paid: 0,
    onHold: 0,
  });

  return [
    { label: "Available balance", value: formatPrice(totals.ready), meta: "Ready for payout" },
    { label: "Pending balance", value: formatPrice(totals.pending), meta: "Waiting for release" },
    { label: "Paid balance", value: formatPrice(totals.paid), meta: "Already settled" },
    { label: "On hold", value: formatPrice(totals.onHold), meta: "Returns or issues" },
  ];
});

function formatPayoutStatusLabel(status) {
  const labels = {
    pending: "Pending",
    ready: "Ready",
    paid: "Paid",
    on_hold: "On hold",
  };

  return labels[String(status || "").trim().toLowerCase()] || "Pending";
}

function getPayoutStatusClass(status) {
  const normalizedStatus = String(status || "").trim().toLowerCase();
  if (normalizedStatus === "paid") {
    return "is-paid";
  }
  if (normalizedStatus === "ready") {
    return "is-ready";
  }
  if (normalizedStatus === "on_hold") {
    return "is-hold";
  }
  return "is-pending";
}
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
const dashboardPerformanceBars = computed(() => ([
  { label: "Views", value: Number(analytics.value?.viewsCount || 0) },
  { label: "Wishlist", value: Number(analytics.value?.wishlistCount || 0) },
  { label: "Cart", value: Number(analytics.value?.cartCount || 0) },
  { label: "Units sold", value: Number(analytics.value?.unitsSold || 0) },
]));
const dashboardCatalogDistribution = computed(() => ([
  { label: "Live", value: products.value.filter((product) => Boolean(product.isPublic)).length },
  { label: "Low stock", value: lowStockProducts.value.length },
  { label: "Out of stock", value: outOfStockProducts.value.length },
]));
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
  if (actionKey === "products") {
    openAddProductForm();
    return;
  }
  setActiveSection(actionKey);
}

function handleBusinessDashboardSearch() {
  const query = String(productSearchQuery.value || "").trim();
  productSearchQuery.value = query;
  syncRouteSearchQuery(query);
  if (canManageCatalog.value) {
    setActiveSection("inventory");
  }
}

function readRouteSearchQuery(value) {
  return Array.isArray(value) ? String(value[0] || "") : String(value || "");
}

async function syncRouteSearchQuery(query) {
  const nextQuery = {
    ...route.query,
    q: query || undefined,
  };

  await router.replace({
    path: route.path,
    query: nextQuery,
  });
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
      loadBusinessOrders(),
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
    if (view) {
      await handleRouteView();
    }
  },
);

watch(
  () => route.query.q,
  (query) => {
    const nextQuery = readRouteSearchQuery(query);
    if (nextQuery !== productSearchQuery.value) {
      productSearchQuery.value = nextQuery;
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

function createProductMediaId() {
  return `product-media-${Date.now()}-${Math.random().toString(36).slice(2, 9)}`;
}

function createProductMediaItem({ path = "", file = null, kind = "existing" } = {}) {
  if (kind === "local" && file) {
    const previewPath = URL.createObjectURL(file);
    return {
      id: createProductMediaId(),
      kind,
      file,
      path: previewPath,
    };
  }

  return {
    id: createProductMediaId(),
    kind: "existing",
    file: null,
    path: String(path || "").trim(),
  };
}

function syncProductMediaItemsFromGallery(paths = []) {
  revokePreviewUrls();
  productMediaItems.value = paths
    .map((path) => String(path || "").trim())
    .filter(Boolean)
    .map((path) => createProductMediaItem({ path, kind: "existing" }));
}

function revokePreviewUrls() {
  productMediaItems.value.forEach((item) => {
    if (item.kind === "local" && item.path) {
      URL.revokeObjectURL(item.path);
    }
  });
}

function appendProductMediaFiles(fileList = []) {
  const nextFiles = Array.from(fileList || []).filter(Boolean);
  if (!nextFiles.length) {
    return;
  }
  productMediaItems.value = [
    ...productMediaItems.value,
    ...nextFiles.map((file) => createProductMediaItem({ file, kind: "local" })),
  ];
}

function setPrimaryProductMedia(index) {
  const normalizedIndex = Number(index);
  if (!Number.isInteger(normalizedIndex) || normalizedIndex < 0 || normalizedIndex >= productMediaItems.value.length) {
    return;
  }
  const [selectedItem] = productMediaItems.value.splice(normalizedIndex, 1);
  productMediaItems.value = [selectedItem, ...productMediaItems.value];
}

function removeProductMedia(index) {
  const normalizedIndex = Number(index);
  if (!Number.isInteger(normalizedIndex) || normalizedIndex < 0 || normalizedIndex >= productMediaItems.value.length) {
    return;
  }
  const [removedItem] = productMediaItems.value.splice(normalizedIndex, 1);
  if (removedItem?.kind === "local" && removedItem.path) {
    URL.revokeObjectURL(removedItem.path);
  }
  productMediaItems.value = [...productMediaItems.value];
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

async function loadBusinessOrders() {
  const { response, data } = await requestJson("/api/business/orders");
  if (!response.ok || !data?.ok) {
    businessOrders.value = [];
    return;
  }

  businessOrders.value = Array.isArray(data.orders) ? data.orders : [];
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
  productFormCollapsed.value = false;
  editingProduct.value = null;
  revokePreviewUrls();
  productMediaItems.value = [];
  ui.productMessage = "";
  ui.productTypeMessage = "";
}

function changeProductQuantity(delta) {
  const currentQuantity = Math.max(0, Number.parseInt(String(productForm.simpleStockQuantity || "0"), 10) || 0);
  productForm.simpleStockQuantity = String(Math.max(0, currentQuantity + delta));
}

function toggleProductFormCollapsed() {
  productFormCollapsed.value = !productFormCollapsed.value;
}

async function handleRouteView() {
  const requestedView = String(route.query.view || "").trim();
  if (!requestedView) {
    return;
  }

  if (requestedView === "add-product") {
    if (!canManageCatalog.value) {
      return;
    }

    setActiveSection("products");
    resetProductForm();
    await nextTick();
    window.setTimeout(() => {
      productTitleInput.value?.focus?.();
    }, 120);
    return;
  }

  if (!dashboardSections.value.some((section) => section.key === requestedView)) {
    return;
  }

  setActiveSection(requestedView);
}

async function openAddProductForm() {
  if (!canManageCatalog.value) {
    return;
  }

  setActiveSection("products");
  resetProductForm();
  await nextTick();
  window.setTimeout(() => {
    productFormCollapsed.value = false;
    productTitleInput.value?.focus?.();
  }, 120);
}

function beginProductEdit(product) {
  setActiveSection("products");
  editingProduct.value = product;
  hydrateProductFormFromProduct(productForm, {
    ...product,
    imageGallery: getProductImageGallery(product),
  });
  syncProductMediaItemsFromGallery(getProductImageGallery(product));
  syncProductFormCatalogState(productForm);
  productFormCollapsed.value = false;
  ui.productMessage = `Po editon artikullin "${product.title}".`;
  ui.productTypeMessage = "success";
}

function handleFilesChange(event) {
  appendProductMediaFiles(event?.target?.files || []);
  if (event?.target) {
    event.target.value = "";
  }
}

function handleDroppedFiles(event) {
  appendProductMediaFiles(event?.dataTransfer?.files || []);
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
    const existingGallery = productMediaItems.value
      .filter((item) => item.kind === "existing")
      .map((item) => item.path)
      .filter(Boolean);
    const localFiles = productMediaItems.value
      .filter((item) => item.kind === "local" && item.file)
      .map((item) => item.file);
    const payload = new FormData();
    payload.append("title", productForm.title.trim());
    payload.append("description", productForm.description.trim());
    payload.append("pageSection", productForm.pageSection);
    payload.append("audience", productForm.audience);
    payload.append("productType", productForm.productType);
    payload.append("imagePath", existingGallery[0] || "");
    payload.append("imageGallery", JSON.stringify(existingGallery));
    localFiles.forEach((file) => {
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

async function resolveProductMediaGallery() {
  const localMediaItems = productMediaItems.value.filter((item) => item.kind === "local" && item.file);
  if (localMediaItems.length === 0) {
    return {
      ok: true,
      imageGallery: productMediaItems.value.map((item) => item.path).filter(Boolean),
    };
  }

  const uploadResult = await uploadImages(localMediaItems.map((item) => item.file));
  if (!uploadResult.ok) {
    return {
      ok: false,
      message: uploadResult.message,
      imageGallery: [],
    };
  }

  const uploadedPathById = new Map(
    localMediaItems.map((item, index) => [item.id, String(uploadResult.paths[index] || "").trim()]),
  );

  return {
    ok: true,
    imageGallery: productMediaItems.value
      .map((item) => item.kind === "local" ? uploadedPathById.get(item.id) || "" : item.path)
      .filter(Boolean),
  };
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

  if (productMediaItems.value.length === 0) {
    ui.productMessage = "Zgjidh te pakten nje foto te produktit.";
    ui.productTypeMessage = "error";
    return;
  }

  const mediaResult = await resolveProductMediaGallery();
  if (!mediaResult.ok) {
    ui.productMessage = mediaResult.message;
    ui.productTypeMessage = "error";
    return;
  }
  const imageGallery = mediaResult.imageGallery;

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

function createDuplicateArticleNumber(product) {
  const baseValue = String(product?.articleNumber || product?.id || "sku").trim() || "sku";
  const normalizedBase = `${baseValue}-copy`;
  const existingValues = new Set(
    products.value
      .map((entry) => String(entry.articleNumber || "").trim().toLowerCase())
      .filter(Boolean),
  );
  let nextValue = normalizedBase;
  let counter = 2;
  while (existingValues.has(nextValue.toLowerCase())) {
    nextValue = `${normalizedBase}-${counter}`;
    counter += 1;
  }
  return nextValue;
}

async function handleDuplicateProduct(product) {
  if (!canManageCatalog.value) {
    ui.listMessage = "Katalogu eshte i ngrire deri ne verifikimin e biznesit.";
    ui.listType = "error";
    return;
  }

  const duplicatedPayload = {
    ...buildProductUpdatePayload(product),
    productId: undefined,
    articleNumber: createDuplicateArticleNumber(product),
    title: `${String(product.title || "").trim()} Copy`.trim(),
  };

  const { response, data } = await requestJson("/api/products", {
    method: "POST",
    body: JSON.stringify(duplicatedPayload),
  });

  if (!response.ok || !data?.ok) {
    ui.listMessage = resolveApiMessage(data, "Produkti nuk u duplikua.");
    ui.listType = "error";
    return;
  }

  ui.listMessage = data.message || "Produkti u duplikua me sukses.";
  ui.listType = "success";
  await Promise.all([
    loadProducts(),
    loadBusinessAnalytics(),
  ]);
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
    brand: String(product.brand || "").trim(),
    gtin: String(product.gtin || "").trim(),
    mpn: String(product.mpn || "").trim(),
    material: String(product.material || "").trim(),
    weightValue: Number(product.weightValue || 0),
    weightUnit: String(product.weightUnit || "kg").trim(),
    metaTitle: String(product.metaTitle || "").trim(),
    metaDescription: String(product.metaDescription || "").trim(),
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
  <section class="market-page market-page--wide dashboard-page business-dashboard-page" aria-label="Biznesi juaj">
    <div
      v-if="!shouldShowProfileCard && ui.profileMessage"
      class="market-status"
      :class="{ 'market-status--error': ui.profileType === 'error', 'market-status--success': ui.profileType === 'success' }"
      role="status"
      aria-live="polite"
    >
      {{ ui.profileMessage }}
    </div>

    <DashboardShell
      :nav-items="businessShellNavItems"
      :active-key="activeSection"
      :brand-initial="dashboardAvatarLabel"
      :brand-title="profileForm.businessName || businessProfile?.businessName || 'Tregio Pro'"
      brand-subtitle="Business dashboard"
      :brand-image-path="businessLogoPreview"
      brand-fallback-icon="store"
      :profile-image-path="businessLogoPreview"
      profile-fallback-icon="store"
      :profile-name="profileForm.businessName || businessProfile?.businessName || 'Tregio Pro'"
      :profile-subtitle="isBusinessVerified ? 'Verified store' : 'Verification pending'"
      :search-query="productSearchQuery"
      search-placeholder="Search inventory"
      :notification-count="businessNotificationCount"
      @update:search-query="productSearchQuery = $event"
      @submit-search="handleBusinessDashboardSearch"
    >
      <template #sidebar-footer>
        <RouterLink to="/llogaria">
          <svg viewBox="0 0 24 24" aria-hidden="true">
            <path d="M12 8.2a3.8 3.8 0 1 1 0 7.6 3.8 3.8 0 0 1 0-7.6Zm8 4-1.7.8c-.1.4-.3.8-.5 1.2l.7 1.8-1.7 1.7-1.8-.7c-.4.2-.8.4-1.2.5L12 20l-2.4-.7c-.4-.1-.8-.3-1.2-.5l-1.8.7-1.7-1.7.7-1.8c-.2-.4-.4-.8-.5-1.2L4 12.2l.8-2.2c.1-.4.3-.8.5-1.2l-.7-1.8L6.3 5l1.8.7c.4-.2.8-.4 1.2-.5L12 4l2.4.7c.4.1.8.3 1.2.5l1.8-.7 1.7 1.7-.7 1.8c.2.4.4.8.5 1.2Z" />
          </svg>
          <span>Account</span>
        </RouterLink>
      </template>

      <header class="dashboard-section dashboard-page__hero">
          <div class="dashboard-section__head">
            <div class="market-page__header-copy">
              <p class="market-page__eyebrow">Business dashboard</p>
              <h1>{{ profileForm.businessName || businessProfile?.businessName || "Your workspace" }}</h1>
              <p>
                Keep the overview simple: track sales, watch stock pressure, and jump into the tasks that move the business forward.
              </p>
            </div>

            <div class="dashboard-inline-meta">
              <span class="market-pill">{{ activeSectionMeta?.label || "Dashboard" }}</span>
              <span class="market-pill">{{ dashboardDateRangeLabel }}</span>
              <span class="market-pill market-pill--accent">{{ dashboardAvatarLabel }}</span>
            </div>
          </div>

          <div class="dashboard-shortcuts">
            <button
              v-for="action in dashboardQuickActions"
              :key="action.key"
              class="dashboard-shortcut"
              type="button"
              @click="handleDashboardQuickAction(action.key)"
            >
              <strong>{{ action.label }}</strong>
              <span>Open {{ action.label.toLowerCase() }}</span>
            </button>
          </div>
      </header>

      <section
        v-show="activeSection === 'analytics'"
        aria-label="Analytics e biznesit"
      >
          <div v-if="analytics" class="dashboard-main">
            <section class="dashboard-section-group">
              <div class="dashboard-section__head">
                <div>
                  <p class="market-page__eyebrow">Overview</p>
                  <h2>Business overview</h2>
                  <p class="dashboard-note">Sales, stock pressure, and the main actions stay together here.</p>
                </div>
              </div>

              <div class="metric-grid">
                <article v-for="metric in dashboardMetrics" :key="metric.key" class="metric-card">
                  <p class="metric-card__label">{{ metric.label }}</p>
                  <strong>{{ metric.value }}</strong>
                  <span class="section-heading__copy">{{ metric.meta }}</span>
                </article>
              </div>

              <div class="market-grid market-grid--split">
                <article class="dashboard-section dashboard-chart-card">
                  <div class="dashboard-section__head">
                    <div>
                      <p class="market-page__eyebrow">Sales overview</p>
                      <h2>Last 7 days</h2>
                    </div>
                    <span class="market-pill">{{ activeSectionMeta?.label || "Dashboard" }}</span>
                  </div>

                  <DashboardLineChart :labels="dashboardChartLabels" :values="dashboardChartValues" />
                </article>

                <article class="dashboard-section">
                  <div class="dashboard-section__head">
                    <div>
                      <p class="market-page__eyebrow">Quick actions</p>
                      <h2>Most used tasks</h2>
                    </div>
                  </div>

                  <div class="dashboard-quick-grid">
                    <button
                      v-for="action in dashboardQuickActions"
                      :key="`analytics-${action.key}`"
                      class="market-button market-button--secondary"
                      type="button"
                      @click="handleDashboardQuickAction(action.key)"
                    >
                      {{ action.label }}
                    </button>
                  </div>
                </article>
              </div>
            </section>

            <section class="dashboard-section-group">
              <div class="dashboard-section__head">
                <div>
                  <p class="market-page__eyebrow">Orders</p>
                  <h2>Order history metrics</h2>
                  <p class="dashboard-note">Need-action and completed order signals are now visible in the dashboard tab.</p>
                </div>
                <RouterLink class="market-button market-button--ghost" to="/porosite-e-biznesit">
                  View orders
                </RouterLink>
              </div>

              <div class="metric-grid metric-grid--compact">
                <article v-for="item in businessOrderSummary" :key="`business-order-${item.label}`" class="metric-card">
                  <p class="metric-card__label">{{ item.label }}</p>
                  <strong>{{ item.value }}</strong>
                  <span class="section-heading__copy">{{ item.meta }}</span>
                </article>
              </div>

              <section class="dashboard-section dashboard-chart-card">
                <div class="dashboard-section__head">
                  <div>
                    <p class="market-page__eyebrow">Orders</p>
                    <h2>Fulfillment focus</h2>
                  </div>
                </div>

                <DashboardBarChart :items="businessOrderBars" />
              </section>
            </section>

            <section class="dashboard-section-group">
              <div class="dashboard-section__head">
                <div>
                  <p class="market-page__eyebrow">Engagement</p>
                  <h2>Traffic and customer signals</h2>
                  <p class="dashboard-note">Views, saves, carts, and shares are grouped together for faster reading.</p>
                </div>
              </div>

              <div class="metric-grid">
                <article v-for="item in engagementSummaryItems" :key="`engagement-${item.label}`" class="metric-card">
                  <p class="metric-card__label">{{ item.label }}</p>
                  <strong>{{ item.value }}</strong>
                </article>
              </div>

              <div class="dashboard-chart-grid">
                <article class="dashboard-section dashboard-chart-card">
                  <div class="dashboard-section__head">
                    <div>
                      <p class="market-page__eyebrow">Performance</p>
                      <h2>Traffic signals</h2>
                    </div>
                  </div>

                  <DashboardBarChart :items="dashboardPerformanceBars" />
                </article>

                <article class="dashboard-section dashboard-chart-card">
                  <div class="dashboard-section__head">
                    <div>
                      <p class="market-page__eyebrow">Catalog mix</p>
                      <h2>Inventory state</h2>
                    </div>
                  </div>

                  <DashboardDonutChart :items="dashboardCatalogDistribution" />
                </article>
              </div>
            </section>

            <section class="dashboard-section-group">
              <div class="dashboard-section__head">
                <div>
                  <p class="market-page__eyebrow">Catalog</p>
                  <h2>Products, stock, and offers</h2>
                  <p class="dashboard-note">Catalog items that need action stay grouped in one place.</p>
                </div>
              </div>

              <div class="dashboard-admin-grid">
                <article class="market-card dashboard-section">
                  <div class="dashboard-section__head">
                    <div>
                      <p class="market-page__eyebrow">Catalog</p>
                      <h2>Recent products</h2>
                    </div>
                    <button class="market-button market-button--ghost" type="button" @click="setActiveSection('inventory')">
                      View all
                    </button>
                  </div>

                  <div v-if="recentDashboardProducts.length === 0" class="market-empty">
                    <h3>No products yet</h3>
                    <p>Ende nuk ka produkte.</p>
                  </div>
                  <div v-else class="dashboard-simple-list">
                    <article
                      v-for="product in recentDashboardProducts"
                      :key="`recent-dashboard-product-${product.id}`"
                    >
                      <strong>{{ product.title }}</strong>
                      <span>{{ product.articleNumber || `#${product.id}` }}</span>
                      <span>
                        {{ Number(product.stockQuantity || 0) > STOCK_ALERT_THRESHOLD ? "In stock" : "Low stock" }} •
                        {{ formatStockQuantity(product.stockQuantity) }}
                      </span>
                    </article>
                  </div>
                </article>

                <article class="market-card dashboard-section">
                  <div class="dashboard-section__head">
                    <div>
                      <p class="market-page__eyebrow">Stock</p>
                      <h2>Items that need attention</h2>
                    </div>
                    <button class="market-button market-button--ghost" type="button" @click="setActiveSection('stock')">
                      View all
                    </button>
                  </div>

                  <div v-if="stockAlertProducts.length === 0" class="market-empty">
                    <h3>No stock alerts</h3>
                    <p>Nuk ka alerte ne stok.</p>
                  </div>
                  <div v-else class="dashboard-simple-list">
                    <article
                      v-for="product in stockAlertProducts.slice(0, 4)"
                      :key="`overview-stock-alert-${product.id}`"
                    >
                      <strong>{{ product.title }}</strong>
                      <span>{{ formatCategoryLabel(product.category) }}</span>
                      <span>{{ formatStockQuantity(product.stockQuantity) }}</span>
                    </article>
                  </div>
                </article>

                <article class="market-card dashboard-section">
                  <div class="dashboard-section__head">
                    <div>
                      <p class="market-page__eyebrow">Offers</p>
                      <h2>Active discounts</h2>
                    </div>
                    <button class="market-button market-button--ghost" type="button" @click="setActiveSection('offers')">
                      View all
                    </button>
                  </div>

                  <div v-if="recentDiscounts.length === 0" class="market-empty">
                    <h3>No active offers</h3>
                    <p>Nuk ka oferta aktive.</p>
                  </div>
                  <div v-else class="dashboard-simple-list">
                    <article
                      v-for="promotion in recentDiscounts"
                      :key="`overview-discount-${promotion.id}`"
                    >
                      <strong>{{ promotion.title || "Promotion" }}</strong>
                      <span>{{ promotion.code }}</span>
                      <span>{{ promotion.discountType === "percent" ? `${promotion.discountValue}% off` : formatPrice(promotion.discountValue) }}</span>
                    </article>
                  </div>
                </article>
              </div>
            </section>
          </div>
          <div v-else class="market-empty">
            <h3>Analytics unavailable</h3>
            <p>Analytics nuk u ngarkuan ende.</p>
          </div>
        </section>

    <section
      v-if="canManageCatalog"
      v-show="activeSection === 'stock'"
      class="market-card dashboard-section"
      aria-label="Alertet e stokut"
    >
      <div class="dashboard-section__head">
        <div>
          <p class="market-page__eyebrow">Stock</p>
          <h2>Items at risk</h2>
        </div>
        <span class="market-pill">{{ stockAlertCount }} at risk</span>
      </div>

      <div v-if="stockAlertCount > 0" class="dashboard-simple-list">
        <article
          v-for="product in stockAlertProducts"
          :key="`stock-alert-${product.id}`"
        >
          <strong>{{ product.title }}</strong>
          <span>{{ formatCategoryLabel(product.category) }}</span>
          <span>{{ getStockAlertLabel(product) }}</span>
          <button class="market-button market-button--ghost" type="button" @click="beginProductEdit(product)">
            Edit
          </button>
        </article>
      </div>
      <div v-else class="market-empty">
        <h3>No stock alerts</h3>
        <p>Nuk ka produkte ne risk.</p>
      </div>
    </section>

    <section
      v-if="canManageCatalog"
      v-show="activeSection === 'shipping'"
      class="market-card dashboard-section"
      aria-label="Transporti i biznesit"
    >
      <div class="dashboard-section__head">
        <div>
          <p class="market-page__eyebrow">Shipping</p>
          <h2>Transport</h2>
        </div>
      </div>

      <form @submit.prevent="saveShippingSettings">
        <div>
          <article>
            <div>
              <div>
                <strong>Dergese standard</strong>
              </div>
              <label>
                <input v-model="shippingForm.standardEnabled" type="checkbox">
                <span>Aktive</span>
              </label>
            </div>
            <div>
              <label>
                <span>Kosto baze (€)</span>
                <input v-model="shippingForm.standardFee" :disabled="!shippingForm.standardEnabled" type="number" min="0" step="0.10" placeholder="2.50">
              </label>
              <label>
                <span>Koha e dorezimit</span>
                <input v-model="shippingForm.standardEta" :disabled="!shippingForm.standardEnabled" type="text" placeholder="2-4 dite pune">
              </label>
            </div>
          </article>

          <article>
            <div>
              <div>
                <strong>Dergese express</strong>
              </div>
              <label>
                <input v-model="shippingForm.expressEnabled" type="checkbox">
                <span>Aktive</span>
              </label>
            </div>
            <div>
              <label>
                <span>Kosto baze (€)</span>
                <input v-model="shippingForm.expressFee" :disabled="!shippingForm.expressEnabled" type="number" min="0" step="0.10" placeholder="4.90">
              </label>
              <label>
                <span>Koha e dorezimit</span>
                <input v-model="shippingForm.expressEta" :disabled="!shippingForm.expressEnabled" type="text" placeholder="1-2 dite pune">
              </label>
            </div>
          </article>

          <article>
            <div>
              <div>
                <strong>Terheqje ne biznes</strong>
              </div>
              <label>
                <input v-model="shippingForm.pickupEnabled" type="checkbox">
                <span>Aktive</span>
              </label>
            </div>
            <label>
              <span>Koha e gatishmerise</span>
              <input v-model="shippingForm.pickupEta" :disabled="!shippingForm.pickupEnabled" type="text" placeholder="Gati per terheqje brenda 24 oresh">
            </label>
            <label>
              <span>Adresa e terheqjes</span>
              <input
                v-model="shippingForm.pickupAddress"
                :disabled="!shippingForm.pickupEnabled"
                type="text"
                placeholder="Shkruaje adresen ku merret porosia"
              >
            </label>
            <label>
              <span>Orari i terheqjes</span>
              <input
                v-model="shippingForm.pickupHours"
                :disabled="!shippingForm.pickupEnabled"
                type="text"
                placeholder="p.sh. Hene-Shtune, 09:00 - 18:00"
              >
            </label>
            <label>
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

        <div>
          <label>
            <span>Pragu per 50% zbritje transporti (€)</span>
            <input v-model="shippingForm.halfOffThreshold" type="number" min="0" step="0.10" placeholder="120">
          </label>

          <label>
            <span>Pragu per transport falas (€)</span>
            <input v-model="shippingForm.freeShippingThreshold" type="number" min="0" step="0.10" placeholder="180">
          </label>
        </div>

        <div>
          <div>
            <div>
              <strong>Tarifa sipas qytetit</strong>
            </div>
            <button type="button" @click="addShippingCityRate">
              Shto qytet
            </button>
          </div>

          <div>
            <div
              v-for="(cityRate, index) in shippingForm.cityRates"
              :key="`shipping-city-rate-${index}`"
             
            >
              <label>
                <span>Qyteti</span>
                <input
                  v-model="cityRate.city"
                  type="text"
                  placeholder="p.sh. Prishtine"
                >
              </label>

              <label>
                <span>Shtesa (€)</span>
                <input
                  v-model="cityRate.surcharge"
                  type="number"
                  min="0"
                  step="0.10"
                  placeholder="0.00"
                >
              </label>

              <button type="button" @click="removeShippingCityRate(index)">
                Hiq
              </button>
            </div>
          </div>
        </div>

        <div>
          <button type="submit">Ruaj</button>
        </div>
      </form>

      <div role="status" aria-live="polite">
        {{ ui.shippingMessage }}
      </div>
    </section>

    <section
      v-if="shouldShowProfileCard"
      v-show="activeSection === 'profile'"
      class="market-card dashboard-section"
    >
        <h2>{{ businessProfile && isBusinessVerified ? "Edito biznesin" : "Regjistrimi i biznesit" }}</h2>

        <form @submit.prevent="saveBusinessProfile">
          <label>
            <span>Emri i biznesit</span>
            <input v-model="profileForm.businessName" type="text" placeholder="p.sh. Agro Market Rinia" required>
          </label>

          <label>
            <span>Pershkrimi i biznesit</span>
            <textarea v-model="profileForm.businessDescription" rows="4" placeholder="Shkruaje pershkrimin e biznesit" required></textarea>
          </label>

          <div>
            <label>
              <span>Nr. i biznesit</span>
              <input v-model="profileForm.businessNumber" type="text" placeholder="p.sh. BR-204-55" required>
            </label>

            <label>
              <span>Numri i telefonit</span>
              <input v-model="profileForm.phoneNumber" type="text" placeholder="p.sh. +383 44 123 456" required>
            </label>
          </div>

          <div>
            <label>
              <span>Email per support</span>
              <input v-model="profileForm.supportEmail" type="email" placeholder="p.sh. support@biznesi.com">
            </label>

            <label>
              <span>Website</span>
              <input v-model="profileForm.websiteUrl" type="url" placeholder="p.sh. https://biznesi.com">
            </label>
          </div>

          <div>
            <label>
              <span>Orari i support-it</span>
              <input v-model="profileForm.supportHours" type="text" placeholder="p.sh. Hene - Shtune, 09:00 - 18:00">
            </label>
            <label>
              <span>Qyteti</span>
              <input v-model="profileForm.city" type="text" placeholder="p.sh. Prishtine" required>
            </label>
          </div>

          <label>
            <span>Politika e kthimit</span>
            <textarea
              v-model="profileForm.returnPolicySummary"
              rows="3"
              placeholder="p.sh. Kthimi pranohet brenda 14 diteve per produktet e pademtuara."
            ></textarea>
          </label>

          <label>
            <span>Adresa e biznesit</span>
            <input v-model="profileForm.addressLine" type="text" placeholder="Shkruaje adresen e biznesit" required>
          </label>

          <label>
            <span>Logo e biznesit (opsionale)</span>
            <input type="file" accept="image/*" @change="handleLogoChange">
          </label>

          <p>
            Logo opsionale.
          </p>

          <div aria-live="polite">
            <div v-if="!businessLogoPreview">
              Nuk eshte zgjedhur asnje logo ende.
            </div>
            <figure v-else>
              <img :src="businessLogoPreview" alt="Logo e biznesit">
              <figcaption>Logo e biznesit</figcaption>
            </figure>
          </div>

          <div v-if="businessProfile">
            <div>
              <strong>{{ formatVerificationStatusLabel(businessProfile.verificationStatus) }}</strong>
            </div>
            <button
              v-if="['unverified', 'rejected'].includes(String(businessProfile.verificationStatus || ''))"
             
              type="button"
              @click="requestVerificationReview"
            >
              Verifiko
            </button>
          </div>

          <div>
            <button type="submit">Ruaj</button>
          </div>
        </form>

        <div role="status" aria-live="polite">
          {{ ui.profileMessage }}
        </div>
    </section>

    <section
      v-if="canManageCatalog"
      v-show="activeSection === 'products'"
      class="market-card dashboard-section product-workspace"
    >
      <div class="product-workspace__header">
        <div>
          <h2>{{ editingProduct ? "Edit product" : "Add product" }}</h2>
          <p>{{ editingProduct ? "Update product details, media, and variants from one compact workspace." : "Create new products faster with compact inputs, live preview, and category-aware variants." }}</p>
        </div>
        <div class="product-workspace__header-actions">
          <button type="button" class="market-button market-button--ghost" @click="setActiveSection('inventory')">
            Go to Inventory
          </button>
          <button type="button" class="market-button market-button--secondary" @click="resetProductForm">
            {{ editingProduct ? "Cancel edit" : "Clear form" }}
          </button>
        </div>
      </div>

      <div
        v-if="ui.productMessage"
        class="product-workspace__feedback"
        :class="{
          'is-error': ui.productTypeMessage === 'error',
          'is-success': ui.productTypeMessage === 'success',
        }"
        role="status"
        aria-live="polite"
      >
        {{ ui.productMessage }}
      </div>

      <div class="product-workspace__layout">
        <form class="product-workspace__form" @submit.prevent="submitProduct">
          <article class="product-form-card">
            <div class="product-form-card__head">
              <div>
                <h3>Basic information</h3>
                <p>Keep the essentials compact and aligned so you can add products faster.</p>
              </div>
            </div>

            <div class="product-form-card__grid product-form-card__grid--basic">
              <div class="product-form-card__field product-form-card__field--stock">
                <span>Stock</span>
                <div class="product-workspace__stepper">
                  <button type="button" aria-label="Decrease quantity" @click="changeProductQuantity(-1)">-</button>
                  <input
                    v-model="productForm.simpleStockQuantity"
                    type="number"
                    min="0"
                    step="1"
                    inputmode="numeric"
                    aria-label="Product quantity"
                  >
                  <button type="button" aria-label="Increase quantity" @click="changeProductQuantity(1)">+</button>
                </div>
              </div>

              <label class="product-form-card__field">
                <span>Article / SKU</span>
                <input
                  v-model="productForm.articleNumber"
                  type="text"
                  inputmode="text"
                  placeholder="SKU-10025"
                >
              </label>

              <label class="product-form-card__field product-form-card__field--title">
                <span>Product title</span>
                <input
                  ref="productTitleInput"
                  v-model="productForm.title"
                  type="text"
                  placeholder="White cotton t-shirt"
                  required
                >
              </label>

              <label class="product-form-card__field">
                <span>Price</span>
                <div class="product-workspace__price-control">
                  <input
                    v-model="productForm.price"
                    type="number"
                    min="0.01"
                    step="0.01"
                    placeholder="29.00"
                    required
                  >
                  <span>EUR</span>
                </div>
              </label>

              <label class="product-form-card__field product-form-card__field--wide">
                <span>Short description</span>
                <input
                  v-model="productForm.metaDescription"
                  type="text"
                  maxlength="160"
                  placeholder="Short preview line users see first"
                >
              </label>
            </div>
          </article>

          <CompactProductConfigurator :form="productForm" />

          <article class="product-form-card">
            <div class="product-form-card__head">
              <div>
                <h3>Product images</h3>
                <p>Drag files in, pick the main image, and remove extras without leaving the page.</p>
              </div>
            </div>

            <label
              class="product-media-dropzone"
              @dragover.prevent
              @drop.prevent="handleDroppedFiles"
            >
              <input
                class="product-media-dropzone__input"
                type="file"
                accept="image/*"
                multiple
                :required="!editingProduct && productMediaCount === 0"
                @change="handleFilesChange"
              >
              <strong>Drag & drop product images</strong>
              <small>{{ productMediaCount > 0 ? `${productMediaCount} image${productMediaCount === 1 ? '' : 's'} ready` : "Upload cover and gallery images" }}</small>
            </label>

            <div v-if="productPreviewItems.length > 0" class="product-media-grid">
              <article
                v-for="(item, index) in productPreviewItems"
                :key="item.id"
                class="product-media-tile"
                :class="{ 'is-primary': index === 0 }"
              >
                <div class="product-media-tile__frame">
                  <img :src="item.path" :alt="item.label">
                </div>
                <div class="product-media-tile__meta">
                  <strong>{{ index === 0 ? "Main image" : `Image ${index + 1}` }}</strong>
                  <span>{{ item.kind === "local" ? "Ready to upload" : "Saved image" }}</span>
                </div>
                <div class="product-media-tile__actions">
                  <button type="button" @click="setPrimaryProductMedia(index)">Set main</button>
                  <button type="button" @click="removeProductMedia(index)">Remove</button>
                </div>
              </article>
            </div>
          </article>

          <article class="product-form-card">
            <div class="product-form-card__head">
              <div>
                <h3>Description</h3>
                <p>Keep the preview short, then add the full product details below.</p>
              </div>
            </div>

            <div class="product-form-card__grid">
              <label class="product-form-card__field product-form-card__field--wide">
                <span>Full description</span>
                <textarea
                  v-model="productForm.description"
                  rows="5"
                  placeholder="Write a clear product description, materials, sizing notes, or technical details."
                  required
                ></textarea>
              </label>
            </div>
          </article>

          <div class="product-workspace__footer">
            <div class="product-workspace__checklist">
              <span :class="{ 'is-ready': productChecklist[0]?.done }">Title ready</span>
              <span :class="{ 'is-ready': productChecklist[1]?.done }">Price ready</span>
              <span :class="{ 'is-ready': productChecklist[2]?.done }">Stock {{ formatStockQuantity(productStockTotal) }}</span>
              <span :class="{ 'is-ready': productChecklist[3]?.done }">Images {{ productMediaCount }}</span>
            </div>

            <div class="product-workspace__footer-actions">
              <button type="button" class="market-button market-button--secondary" @click="resetProductForm">
                Clear
              </button>
              <button type="submit" class="market-button market-button--primary">
                {{ editingProduct ? "Save changes" : "Save product" }}
              </button>
            </div>
          </div>
        </form>

        <aside class="product-preview-card">
          <div class="product-preview-card__head">
            <div>
              <h3>Live preview</h3>
              <p>See the most important listing details before you save.</p>
            </div>
          </div>

          <div class="product-preview-card__media">
            <img v-if="productPreviewImage" :src="productPreviewImage" :alt="productForm.title || 'Product preview image'">
            <div v-else class="product-preview-card__media-empty">
              Product image preview
            </div>
          </div>

          <div class="product-preview-card__body">
            <div class="product-preview-card__title-row">
              <div>
                <span class="product-preview-card__eyebrow">{{ formatCategoryLabel(productForm.category) || "Category" }}</span>
                <h3>{{ productForm.title || "Product title" }}</h3>
              </div>
              <strong>{{ productPreviewPrice > 0 ? formatPrice(productPreviewPrice) : "Set price" }}</strong>
            </div>

            <p class="product-preview-card__copy">
              {{ productForm.metaDescription || productForm.description || "Your short product preview will appear here." }}
            </p>

            <div class="product-preview-card__facts">
              <div
                v-for="item in productPreviewSummary"
                :key="`${item.label}-${item.value}`"
                class="product-preview-card__fact"
              >
                <span>{{ item.label }}</span>
                <strong>{{ item.value }}</strong>
              </div>
            </div>
          </div>
        </aside>
      </div>
    </section>

    <section
      v-if="businessProfile && !canManageCatalog"
      v-show="activeSection === 'profile'"
      class="market-card dashboard-section"
      aria-label="Katalogu i ngrire"
    >
      <h2>Produktet hapen pasi admini ta verifikoje biznesin</h2>
    </section>

    <section
      v-if="canManageCatalog"
      v-show="activeSection === 'import'"
      class="market-card dashboard-section"
      aria-label="Flexible catalog import"
    >
      <div>
        <div>
          <h2>Import</h2>
        </div>
      </div>

      <div>
        <article>
          <div>
            <div>
              <h3>Source setup</h3>
            </div>
            <span>{{ importIsConfigLoading ? "Loading..." : `${importProfiles.length} profiles • ${importSources.length} sources` }}</span>
          </div>

          <div>
            <label>
              <span>Source type</span>
              <select v-model="importSourceType" @change="handleImportSourceTypeChange">
                <option value="csv">CSV</option>
                <option value="xlsx">XLSX</option>
                <option value="json">JSON payload</option>
                <option value="api-json">API / JSON feed</option>
              </select>
            </label>

            <label>
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

            <label>
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

          <div v-if="importSourceType === 'csv' || importSourceType === 'xlsx'">
            <label>
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

          <div v-else-if="importSourceType === 'json'">
            <label>
              <span>Record path</span>
              <input v-model="importJsonRecordPath" type="text" placeholder="products.items" />
            </label>
            <label>
              <span>JSON payload</span>
              <textarea
                v-model="importJsonPayload"
                rows="8"
                placeholder='[{"Product Name":"Basic Tee","Qty":5,"Price":12.99}]'
              />
            </label>
          </div>

          <div v-else>
            <div>
              <label>
                <span>Source name</span>
                <input v-model="importApiSource.sourceName" type="text" placeholder="Wholesale feed" />
              </label>
              <label>
                <span>Method</span>
                <select v-model="importApiSource.method">
                  <option value="GET">GET</option>
                  <option value="POST">POST</option>
                  <option value="PUT">PUT</option>
                </select>
              </label>
              <label>
                <span>Record path</span>
                <input v-model="importApiSource.recordPath" type="text" placeholder="data.products" />
              </label>
            </div>

            <label>
              <span>API URL</span>
              <input v-model="importApiSource.url" type="url" placeholder="https://supplier.example.com/feed.json" />
            </label>

            <div>
              <label>
                <span>Headers JSON</span>
                <textarea v-model="importApiSource.headersText" rows="5" placeholder='{"Authorization":"Bearer token"}' />
              </label>
              <label>
                <span>Body JSON</span>
                <textarea v-model="importApiSource.bodyText" rows="5" placeholder='{"include":"products"}' />
              </label>
            </div>

            <div>
              <label>
                <span>Sync interval (minutes)</span>
                <input v-model="importApiSource.syncIntervalMinutes" type="number" min="15" step="15" />
              </label>
              <label>
                <span>Sync enabled</span>
                <input v-model="importApiSource.syncEnabled" type="checkbox" />
              </label>
            </div>
          </div>

          <div>
            <label>
              <span>Profile name</span>
              <input v-model="importProfileDraftName" type="text" placeholder="Boutique CSV profile" />
            </label>
            <label>
              <span>Save profile on preview</span>
              <input v-model="importSaveProfile" type="checkbox" />
            </label>
          </div>

          <div>
            <button type="button" :disabled="importIsPreviewLoading" @click="prepareImportPreview">
              {{ importIsPreviewLoading ? "..." : "Preview" }}
            </button>
            <button
             
              type="button"
              :disabled="!importPreviewHasChanges || importIsPreviewLoading"
              @click="loadImportJobPreview(importCurrentJob?.id)"
            >
              Refresh
            </button>
            <button type="button" @click="saveCurrentImportProfile">
              Ruaj profil
            </button>
            <button
              v-if="importSourceType === 'api-json'"
             
              type="button"
              @click="saveCurrentImportSource"
            >
              Ruaj source
            </button>
            <button
              v-if="importSourceType === 'api-json'"
             
              type="button"
              :disabled="!importSelectedSourceId || importIsSyncLoading"
              @click="syncCurrentImportSource()"
            >
              {{ importIsSyncLoading ? "..." : "Sync" }}
            </button>
            <button type="button" @click="downloadImportTemplate">
              Template
            </button>
          </div>
        </article>

        <aside>
          <article>
            <div>
              <div>
                <h3>Summary</h3>
              </div>
            </div>

            <div>
              <div>
                <span>Total rows</span>
                <strong>{{ importSummary.totalRows }}</strong>
              </div>
              <div>
                <span>Valid rows</span>
                <strong>{{ importSummary.validRows }}</strong>
              </div>
              <div>
                <span>Invalid rows</span>
                <strong>{{ importSummary.invalidRows }}</strong>
              </div>
              <div>
                <span>Parent groups</span>
                <strong>{{ importSummary.parentProducts }}</strong>
              </div>
              <div>
                <span>Warnings</span>
                <strong>{{ importSummary.warningsCount }}</strong>
              </div>
              <div>
                <span>Hard errors</span>
                <strong>{{ importSummary.hardErrorsCount }}</strong>
              </div>
            </div>
          </article>

          <article>
            <div>
              <div>
                <h3>Recent jobs</h3>
              </div>
            </div>

            <div v-if="importRecentJobs.length === 0">
              Ende nuk ka import jobs te ruajtur.
            </div>
            <div v-else>
              <button
                v-for="job in importRecentJobs.slice(0, 6)"
                :key="`import-job-${job.id}`"
               
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

      <article v-if="importDetectedHeaders.length > 0">
        <div>
          <div>
            <h3>Field mapping</h3>
          </div>
        </div>

        <div>
          <label
            v-for="fieldName in importFieldList"
            :key="`mapping-${fieldName}`"
           
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

      <div v-if="importSummary.warnings.length > 0" role="status" aria-live="polite">
        {{ importSummary.warnings.join(" ") }}
      </div>

      <article>
        <div>
          <div>
            <div>
              <h3>Grouping preview</h3>
            </div>
          </div>

          <div v-if="importIsPreviewLoading">Duke pergatitur preview...</div>
          <div v-else-if="importPreviewGroups.length === 0">
            Krijo nje preview per te pare grouping-un e varianteve.
          </div>
          <div v-else>
            <article
              v-for="group in importPreviewGroups.slice(0, 8)"
              :key="`import-group-${group.groupKey}`"
             
            >
              <div>
                <div>
                  <h4>{{ group.parent?.title || "Untitled group" }}</h4>
                  <p>{{ group.parent?.canonicalCategory || "uncategorized" }} · {{ group.variants?.length || 0 }} variants</p>
                </div>
                <label>
                  <span>Approve</span>
                  <input
                    type="checkbox"
                    :checked="importApprovedGroupKeys.includes(group.groupKey)"
                    @change="toggleImportGroupApproval(group.groupKey)"
                  >
                </label>
              </div>

              <div>
                <span>Group key: {{ group.groupKey }}</span>
                <span>Price: {{ formatPrice(group.parent?.priceRange?.min || 0) }}</span>
                <span>Stock: {{ group.parent?.stock || 0 }}</span>
              </div>

              <p v-if="group.warnings?.length">{{ group.warnings.join(" ") }}</p>
              <p v-if="group.errors?.length">{{ group.errors.join(" ") }}</p>

              <div>
                <div
                  v-for="variant in group.variants?.slice(0, 4)"
                  :key="`${group.groupKey}-${variant.key}`"
                 
                >
                  <strong>{{ variant.label || variant.key }}</strong>
                  <span>{{ variant.sku || "No SKU" }}</span>
                  <span>{{ formatPrice(variant.price || 0) }} · {{ variant.stock || 0 }} pcs</span>
                </div>
              </div>
            </article>
          </div>
        </div>

        <div>
          <div>
            <div>
              <h3>Row preview</h3>
            </div>
          </div>

          <div v-if="importIsPreviewLoading">Duke pergatitur rreshtat...</div>
          <div v-else-if="importPreviewRecords.length === 0">
            Ende nuk ka rreshta preview.
          </div>
          <div v-else>
            <article
              v-for="record in importPreviewRecords.slice(0, 10)"
              :key="`import-record-${record.sourceRowId}`"
             
             
            >
              <div>
                <div>
                  <strong>#{{ record.sourceRowId }}</strong>
                  <span>{{ record.normalizedData?.title || record.mappedData?.title || "Untitled row" }}</span>
                </div>
                <label>
                  <span>Skip</span>
                  <input
                    type="checkbox"
                    :checked="importSkippedRowIds.includes(record.sourceRowId)"
                    @change="toggleImportRowSkip(record.sourceRowId)"
                  >
                </label>
              </div>

              <div>
                <span>Category: {{ record.normalizedData?.category || "—" }}</span>
                <span>Group: {{ record.normalizedData?.groupKey || "—" }}</span>
                <span>Price: {{ formatPrice(record.normalizedData?.price || 0) }}</span>
                <span>Stock: {{ record.normalizedData?.stock || 0 }}</span>
              </div>

              <div>
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

              <p v-if="record.warnings?.length">{{ record.warnings.join(" ") }}</p>
              <p v-if="record.errors?.length">{{ record.errors.join(" ") }}</p>
            </article>
          </div>
        </div>
      </article>

      <form @submit.prevent="submitImportProducts">
        <div>
          <button type="submit" :disabled="importIsCommitLoading || !importCurrentJob?.id">
            {{ importIsCommitLoading ? "..." : "Import" }}
          </button>
          <button type="button" @click="clearImportSelection()">Reset</button>
          <button type="button" @click="triggerImportPicker">File</button>
        </div>
      </form>

      <div role="status" aria-live="polite">
        {{ ui.importMessage }}
      </div>
    </section>

    <section
      v-if="canManageCatalog"
      v-show="activeSection === 'offers'"
      class="market-card dashboard-section"
      aria-label="Promocionet e biznesit"
    >
      <div>
        <div>
          <h2>Discounts</h2>
        </div>
      </div>

      <form @submit.prevent="savePromotion">
        <div>
          <label>
            <span>Kodi</span>
            <input v-model="promotionForm.code" type="text" placeholder="p.sh. TREGO10" required>
          </label>
          <label>
            <span>Lloji</span>
            <select v-model="promotionForm.discountType">
              <option value="percent">Perqindje</option>
              <option value="fixed">Vlere fikse</option>
            </select>
          </label>
          <label>
            <span>Vlera</span>
            <input v-model="promotionForm.discountValue" type="number" min="0.01" step="0.01" placeholder="10" required>
          </label>
        </div>

        <div>
          <label>
            <span>Titulli</span>
            <input v-model="promotionForm.title" type="text" placeholder="Oferta e javes">
          </label>
          <label>
            <span>Minimumi i shportes</span>
            <input v-model="promotionForm.minimumSubtotal" type="number" min="0" step="0.01" placeholder="0">
          </label>
          <label>
            <span>Limit total</span>
            <input v-model="promotionForm.usageLimit" type="number" min="0" step="1" placeholder="0 = pa limit">
          </label>
        </div>

        <div>
          <label>
            <span>Limit per user</span>
            <input v-model="promotionForm.perUserLimit" type="number" min="1" step="1" placeholder="1">
          </label>
          <label>
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
          <label>
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

        <div>
          <label>
            <span>Aktiv nga</span>
            <input v-model="promotionForm.startsAt" type="datetime-local">
          </label>
          <label>
            <span>Aktiv deri</span>
            <input v-model="promotionForm.endsAt" type="datetime-local">
          </label>
          <label>
            <span>Statusi</span>
            <select v-model="promotionForm.isActive">
              <option :value="true">Aktiv</option>
              <option :value="false">Pauzuar</option>
            </select>
          </label>
        </div>

        <label>
          <span>Pershkrimi</span>
          <input v-model="promotionForm.description" type="text" placeholder="Pershkrim i shkurter per kete oferte">
        </label>

        <div>
          <button type="submit">Ruaj</button>
        </div>
      </form>

      <div role="status" aria-live="polite">
        {{ ui.promotionMessage }}
      </div>

      <div v-if="promotions.length > 0">
        <article v-for="promotion in promotions" :key="promotion.id">
          <div>
            <div>
              <h2>{{ promotion.title || "Promocion" }}</h2>
            </div>
            <strong>
              {{ promotion.discountType === "percent" ? `${promotion.discountValue}%` : formatPrice(promotion.discountValue) }}
            </strong>
          </div>
          <div>
            <span>
              <span>Statusi</span>
              <strong>{{ promotion.isActive ? "Aktiv" : "Pauzuar" }}</strong>
            </span>
            <span>
              <span>Perdorime</span>
              <strong>{{ promotion.usageLimit || "Pa limit" }}</strong>
            </span>
            <span>
              <span>Per user</span>
              <strong>{{ promotion.perUserLimit || 1 }}</strong>
            </span>
          </div>
          <div>
            <span v-if="promotion.pageSection">
              Seksioni: <strong>{{ formatPromotionSectionLabel(promotion.pageSection) }}</strong>
            </span>
            <span v-if="promotion.category">
              Kategoria: <strong>{{ formatCategoryLabel(promotion.category) }}</strong>
            </span>
            <span v-if="promotion.startsAt">
              Nga: <strong>{{ formatDateLabel(promotion.startsAt) }}</strong>
            </span>
            <span v-if="promotion.endsAt">
              Deri: <strong>{{ formatDateLabel(promotion.endsAt) }}</strong>
            </span>
          </div>
        </article>
      </div>
    </section>

    <section
      v-if="canManageCatalog"
      v-show="activeSection === 'payouts'"
      class="market-card dashboard-section payout-workspace"
      aria-label="Payoutet e biznesit"
    >
      <div class="inventory-workspace__header">
        <div>
          <h2>Payouts</h2>
          <p>Review available balance, pending settlement, and payout history derived from your fulfilled order items.</p>
        </div>
      </div>

      <div class="inventory-summary-grid">
        <article v-for="item in payoutSummaryCards" :key="item.label" class="inventory-summary-card">
          <span>{{ item.label }}</span>
          <strong>{{ item.value }}</strong>
          <small>{{ item.meta }}</small>
        </article>
      </div>

      <div v-if="payoutRows.length === 0" class="market-empty">
        <h3>No payout activity yet</h3>
        <p>Payout rows will appear here once your store has order items with settlement data.</p>
      </div>

      <article v-else class="inventory-table-wrap payout-table-wrap">
        <table class="inventory-table payout-table">
          <thead>
            <tr>
              <th>Date</th>
              <th>Order</th>
              <th>Product</th>
              <th>Status</th>
              <th>Vendor earnings</th>
              <th>Commission</th>
              <th>Due</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="row in payoutRows" :key="`payout-row-${row.orderId}-${row.productTitle}-${row.variantLabel}`">
              <td>{{ formatDateLabel(row.orderCreatedAt) }}</td>
              <td>#{{ row.orderId }}</td>
              <td>
                <div class="payout-table__product">
                  <strong>{{ row.productTitle }}</strong>
                  <span v-if="row.variantLabel">{{ row.variantLabel }}</span>
                </div>
              </td>
              <td>
                <span class="inventory-status-pill payout-status-pill" :class="getPayoutStatusClass(row.payoutStatus)">
                  {{ formatPayoutStatusLabel(row.payoutStatus) }}
                </span>
              </td>
              <td><strong>{{ formatPrice(row.sellerEarningsAmount || 0) }}</strong></td>
              <td>{{ formatPrice(row.commissionAmount || 0) }}</td>
              <td>{{ row.payoutDueAt ? formatDateLabel(row.payoutDueAt) : "TBD" }}</td>
            </tr>
          </tbody>
        </table>
      </article>
    </section>

    <section
      v-if="canManageCatalog"
      v-show="activeSection === 'inventory'"
      class="market-card dashboard-section inventory-workspace"
    >
      <div class="inventory-workspace__header">
        <div>
          <h2>Inventory</h2>
          <p>Review stock, search products, and manage edit or delete actions without mixing them into the add-product flow.</p>
        </div>
        <div class="inventory-workspace__header-actions">
          <button type="button" class="market-button market-button--secondary" @click="triggerImportPicker">Import</button>
          <button type="button" class="market-button market-button--primary" @click="openAddProductForm">Add product</button>
        </div>
      </div>

      <div class="inventory-summary-grid">
        <article v-for="item in inventorySummaryCards" :key="item.label" class="inventory-summary-card">
          <span>{{ item.label }}</span>
          <strong>{{ item.value }}</strong>
          <small>{{ item.meta }}</small>
        </article>
      </div>

      <div class="inventory-toolbar">
        <label class="inventory-toolbar__search" aria-label="Search inventory">
          <svg viewBox="0 0 24 24" aria-hidden="true">
            <circle cx="11" cy="11" r="7"></circle>
            <path d="m20 20-3.5-3.5"></path>
          </svg>
          <input
            v-model="productSearchQuery"
            type="search"
            placeholder="Search by title, SKU, category..."
          >
        </label>
        <label class="inventory-toolbar__filter">
          <span>Category</span>
          <select v-model="productCategoryFilter">
            <option value="">All categories</option>
            <option v-for="option in productCategoryOptions" :key="`filter-category-${option.value}`" :value="option.value">
              {{ option.label }}
            </option>
          </select>
        </label>
        <label class="inventory-toolbar__filter">
          <span>Stock</span>
          <select v-model="productStockFilter">
            <option value="all">All stock states</option>
            <option value="in-stock">In stock</option>
            <option value="low-stock">Low stock</option>
            <option value="out-of-stock">Out of stock</option>
          </select>
        </label>
        <label class="inventory-toolbar__filter">
          <span>Status</span>
          <select v-model="productStatusFilter">
            <option value="all">All statuses</option>
            <option value="public">Active</option>
            <option value="hidden">Inactive</option>
          </select>
        </label>
        <label class="inventory-toolbar__filter">
          <span>Sort</span>
          <select v-model="productSort">
            <option value="updated-desc">Newest first</option>
            <option value="title-asc">Title A-Z</option>
            <option value="title-desc">Title Z-A</option>
            <option value="price-asc">Price low-high</option>
            <option value="price-desc">Price high-low</option>
            <option value="stock-asc">Stock low-high</option>
            <option value="stock-desc">Stock high-low</option>
          </select>
        </label>
      </div>

      <div v-if="hasSelectedProducts" class="inventory-bulk-bar">
        <div class="inventory-bulk-bar__actions">
          <button type="button" @click="applyBulkVisibility(true)">Activate</button>
          <button type="button" @click="applyBulkVisibility(false)">Deactivate</button>
          <label>
            <span>Category</span>
            <select v-model="bulkCategoryValue">
              <option value="">Select category</option>
              <option v-for="option in productCategoryOptions" :key="`bulk-category-${option.value}`" :value="option.value">
                {{ option.label }}
              </option>
            </select>
          </label>
          <button type="button" :disabled="!bulkCategoryValue" @click="applyBulkCategory">Save category</button>
          <label>
            <span>Stock</span>
            <input v-model="bulkStockValue" type="number" min="0" step="1" placeholder="0">
          </label>
          <button type="button" :disabled="bulkStockValue === ''" @click="applyBulkStockUpdate">Save stock</button>
          <button type="button" @click="applyBulkDelete">Delete selected</button>
          <button type="button" @click="clearSelectedProducts">Clear</button>
        </div>
      </div>

      <div class="inventory-feedback" role="status" aria-live="polite">
        {{ ui.listMessage }}
      </div>

      <div class="inventory-content">
        <div v-if="products.length === 0">
          You do not have products yet. Add your first product or import a catalog.
        </div>

        <div v-else-if="filteredProducts.length === 0">
          No products matched the current search and filters.
        </div>

        <template v-else>
          <article class="inventory-table-wrap">
            <table class="inventory-table">
              <thead>
                <tr>
                  <th>
                    <input
                      type="checkbox"
                      :checked="filteredProducts.length > 0 && filteredProducts.every((item) => selectedProductIds.includes(item.id))"
                      @change="toggleSelectAllVisibleProducts"
                    >
                  </th>
                  <th>Product</th>
                  <th>SKU</th>
                  <th>Category</th>
                  <th>Total stock</th>
                  <th>Price</th>
                  <th>Status</th>
                  <th>Actions</th>
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
                  <td class="inventory-table__product-cell">
                    <div class="inventory-table__image">
                      <img :src="getProductImageGallery(product)[0] || product.imagePath" :alt="product.title" loading="lazy" decoding="async">
                    </div>
                    <div class="inventory-table__title">
                      <strong>{{ product.title }}</strong>
                      <p>{{ product.description }}</p>
                    </div>
                  </td>
                  <td>{{ product.articleNumber || `#${product.id}` }}</td>
                  <td>{{ formatCategoryLabel(product.category) }}</td>
                  <td class="inventory-table__stock">
                    <strong>{{ formatStockQuantity(product.stockQuantity) }}</strong>
                    <small>{{ getStockAlertLabel(product) }}</small>
                  </td>
                  <td><strong>{{ formatPrice(product.price) }}</strong></td>
                  <td>
                    <div class="inventory-status-stack">
                      <span class="inventory-status-pill" :class="{ 'is-live': product.isPublic }">
                        {{ product.isPublic ? "Active" : "Inactive" }}
                      </span>
                      <span
                        class="inventory-status-pill"
                        :class="{
                          'is-danger': Number(product.stockQuantity || 0) <= 0,
                          'is-warning': Number(product.stockQuantity || 0) > 0 && Number(product.stockQuantity || 0) <= STOCK_ALERT_THRESHOLD,
                        }"
                      >
                        {{ Number(product.stockQuantity || 0) <= 0 ? "Out of stock" : (Number(product.stockQuantity || 0) <= STOCK_ALERT_THRESHOLD ? "Low stock" : "Healthy") }}
                      </span>
                    </div>
                  </td>
                  <td class="inventory-table__actions">
                    <div class="inventory-actions">
                      <button type="button" @click="beginProductEdit(product)">Edit</button>
                      <button type="button" @click="handleDuplicateProduct(product)">Duplicate</button>
                      <button type="button" @click="handleToggleVisibility(product)">
                        {{ product.isPublic ? "Hide" : "Publish" }}
                      </button>
                      <button type="button" class="is-danger" @click="handleDeleteProduct(product)">Delete</button>
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </article>

          <div class="inventory-mobile-list">
            <article
              v-for="product in filteredProducts"
              :key="`mobile-inventory-${product.id}`"
              class="inventory-mobile-card"
            >
              <div class="inventory-mobile-card__top">
                <div class="inventory-mobile-card__image">
                  <img :src="getProductImageGallery(product)[0] || product.imagePath" :alt="product.title" loading="lazy" decoding="async">
                </div>
                <div class="inventory-mobile-card__content">
                  <strong>{{ product.title }}</strong>
                  <span>{{ product.articleNumber || `#${product.id}` }}</span>
                  <small>{{ formatCategoryLabel(product.category) }}</small>
                </div>
                <strong>{{ formatPrice(product.price) }}</strong>
              </div>

              <div class="inventory-mobile-card__meta">
                <span>{{ getStockAlertLabel(product) }}</span>
                <span>{{ product.isPublic ? "Active" : "Inactive" }}</span>
              </div>

              <div class="inventory-actions">
                <button type="button" @click="beginProductEdit(product)">Edit</button>
                <button type="button" @click="handleDuplicateProduct(product)">Duplicate</button>
                <button type="button" @click="handleToggleVisibility(product)">
                  {{ product.isPublic ? "Hide" : "Publish" }}
                </button>
                <button type="button" class="is-danger" @click="handleDeleteProduct(product)">Delete</button>
              </div>
            </article>
          </div>
        </template>
      </div>
    </section>
    </DashboardShell>
  </section>
</template>
