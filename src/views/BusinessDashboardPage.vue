<script setup>
import { computed, nextTick, onBeforeUnmount, onMounted, reactive, ref, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import ManagedProductCard from "../components/ManagedProductCard.vue";
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
  formatPrice,
  formatRoleLabel,
  formatVerificationStatusLabel,
  formatStockQuantity,
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
const productFormSection = ref(null);
const productTitleInput = ref(null);
const profileCardSection = ref(null);
const shippingSection = ref(null);
const promotionsSection = ref(null);
const productsManagementSection = ref(null);
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
const productViewMode = ref("rows");
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
    label: "Titull dhe pershkrim",
    done: Boolean(String(productForm.title || "").trim() && String(productForm.description || "").trim()),
  },
  {
    key: "pricing",
    label: "Cmim dhe zbritje valide",
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
    caption: "Titull, kategori dhe pershkrim",
    done: productChecklist.value.find((item) => item.key === "title")?.done,
  },
  {
    id: "pricing",
    label: "Cmimi",
    caption: "Regular, sale dhe afati",
    done: productChecklist.value.find((item) => item.key === "pricing")?.done,
  },
  {
    id: "variants",
    label: "Variantet",
    caption: "Ngjyra, madhesia dhe stoku",
    done: productChecklist.value.find((item) => item.key === "variants")?.done,
  },
  {
    id: "media",
    label: "Media",
    caption: "Cover dhe galeria",
    done: productChecklist.value.find((item) => item.key === "media")?.done,
  },
  {
    id: "review",
    label: "Preview",
    caption: "Kontroll para ruajtjes",
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
const dashboardSingleColumn = computed(
  () => !canManageCatalog.value || !shouldShowProfileCard.value,
);
const editBusinessHelperText = computed(() => {
  if (!businessProfile.value || !isBusinessVerified.value) {
    return "";
  }

  if (profileEditAccessStatus.value === "approved") {
    return "Admini e ka aprovuar editimin. Kliko butonin per ta hapur formen.";
  }

  if (profileEditAccessStatus.value === "pending") {
    return "Kerkesa per editim eshte ne pritje te admini.";
  }

  return "Klikimi dergon kerkese te admini. Pasi te aprovohet, forma hapet vetem kur ta klikosh perseri.";
});
const businessWorkspaceActions = computed(() => ([
  {
    key: "add-product",
    title: "Shto artikull",
    copy: "Hape builder-in dhe vazhdo direkt me produktin e ardhshem.",
    disabled: !canManageCatalog.value,
  },
  {
    key: "messages",
    title: "Mesazhet",
    copy: "Shko te inbox-i per pyetje, porosi dhe support.",
    route: "/mesazhet",
  },
  {
    key: "orders",
    title: "Porosite e biznesit",
    copy: "Kontrollo porosite pa dale nga fluksi ditor i punes.",
    route: "/porosite-e-biznesit",
  },
  {
    key: "shipping",
    title: "Transporti",
    copy: "Perditeso standard, express dhe pickup ne nje vend.",
    disabled: !canManageCatalog.value,
  },
  {
    key: "promotions",
    title: "Promocionet",
    copy: promotions.value.length
      ? `${promotions.value.length} oferta aktive ose te ruajtura.`
      : "Krijo kuponin ose zbritjen e pare per biznesin.",
    disabled: !canManageCatalog.value,
  },
  {
    key: "products",
    title: "Produktet",
    copy: products.value.length
      ? `${products.value.length} artikuj jane gati per menaxhim.`
      : "Sapo te shtosh artikujt, menaxhimi del ketu.",
    disabled: !canManageCatalog.value,
  },
  {
    key: "profile",
    title: "Profili",
    copy: isBusinessVerified.value
      ? "Edito biznesin, logon dhe informacionin publik."
      : "Ploteso profilin dhe vazhdo me verifikimin.",
  },
]));
const businessNextSteps = computed(() => {
  const items = [];

  if (!businessProfile.value) {
    items.push({
      key: "profile",
      title: "Ploteso profilin e biznesit",
      copy: "Pa te dhena baze, biznesi nuk mund te kaloje ne verifikim ose katalog.",
    });
  } else if (!isBusinessVerified.value) {
    items.push({
      key: "verify",
      title: "Kerko verifikim",
      copy: "Pasi verifikohet biznesi, hapen katalogu, publikimi dhe importi i artikujve.",
    });
  }

  if (canManageCatalog.value && !products.value.length) {
    items.push({
      key: "add-product",
      title: "Shto produktin e pare",
      copy: "Nis me nje artikull cover qe ta besh dyqanin gati per vizitore.",
    });
  }

  if (canManageCatalog.value && stockAlertCount.value > 0) {
    items.push({
      key: "products",
      title: "Kontrollo stokun",
      copy: `${stockAlertCount.value} artikuj kerkojne vemendje para se te humben shitjet.`,
    });
  }

  if (canManageCatalog.value && promotions.value.length === 0) {
    items.push({
      key: "promotions",
      title: "Krijo oferten e pare",
      copy: "Promocionet e qarta e bejne faqen dhe checkout-in me bindes.",
    });
  }

  return items.slice(0, 4);
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

function scrollToDashboardSection(sectionRef) {
  sectionRef.value?.scrollIntoView?.({ behavior: "smooth", block: "start" });
}

function handleBusinessWorkspaceAction(action) {
  if (!action || action.disabled) {
    return;
  }

  if (action.route) {
    router.push(action.route);
    return;
  }

  if (action.key === "add-product") {
    void openAddProductForm();
    return;
  }

  if (action.key === "shipping") {
    scrollToDashboardSection(shippingSection);
    return;
  }

  if (action.key === "promotions") {
    scrollToDashboardSection(promotionsSection);
    return;
  }

  if (action.key === "products") {
    scrollToDashboardSection(productsManagementSection);
    return;
  }

  if (action.key === "verify") {
    void requestVerificationReview();
    return;
  }

  if (action.key === "profile") {
    if (shouldShowProfileCard.value) {
      scrollToDashboardSection(profileCardSection);
      return;
    }

    void handleBusinessEditButton();
  }
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
    await handleRouteView();
  } finally {
    markRouteReady();
  }
});

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
    ui.profileMessage = "Admini e ka aprovuar editimin. Tani mund t'i ruash ndryshimet.";
    ui.profileType = "success";
    await nextTick();
    window.scrollTo({ top: 0, behavior: "smooth" });
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

  resetProductForm();
  await nextTick();

  if (businessProfile.value && productFormSection.value) {
    productFormSection.value.scrollIntoView({ behavior: "smooth", block: "start" });
    window.setTimeout(() => {
      focusProductFormStep("details");
      productTitleInput.value?.focus?.();
    }, 220);
    return;
  }

  window.scrollTo({ top: 0, behavior: "smooth" });
}

async function openAddProductForm() {
  if (!canManageCatalog.value) {
    return;
  }

  resetProductForm();
  await nextTick();

  if (productFormSection.value) {
    productFormSection.value.scrollIntoView({ behavior: "smooth", block: "start" });
    window.setTimeout(() => {
      focusProductFormStep("details");
      productTitleInput.value?.focus?.();
    }, 220);
  }
}

function beginProductEdit(product) {
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
    <header class="admin-products-header">
      <div>
        <p class="section-label">Paneli i biznesit</p>
        <h1>Biznesi juaj</h1>
        <p class="admin-products-intro">
          Nga kjo faqe mund ta menaxhosh profilin e biznesit dhe katalogun vetem pasi biznesi te verifikohet nga admini.
        </p>
      </div>
      <div class="business-dashboard-header-actions">
        <div v-if="businessProfile && isBusinessVerified" class="business-dashboard-edit-access">
          <button class="nav-action nav-action-secondary" type="button" @click="handleBusinessEditButton">
            Edito biznesin
          </button>
          <p class="business-dashboard-edit-copy">{{ editBusinessHelperText }}</p>
        </div>
        <div class="admin-user-chip">
          <span>Sesioni aktiv</span>
          <strong>{{ appState.user ? `${appState.user.fullName} • ${formatRoleLabel(appState.user.role)}` : "Duke u kontrolluar..." }}</strong>
        </div>
      </div>
    </header>

    <p class="admin-access-note">{{ ui.accessNote }}</p>
    <div
      v-if="!shouldShowProfileCard && ui.profileMessage"
      class="form-message"
      :class="ui.profileType"
      role="status"
      aria-live="polite"
    >
      {{ ui.profileMessage }}
    </div>

    <section v-if="analytics" class="business-dashboard-analytics-grid" aria-label="Analytics e biznesit">
      <article class="summary-chip">
        <span>Artikuj publik</span>
        <strong>{{ analytics.publicProducts }} / {{ analytics.totalProducts }}</strong>
      </article>
      <article class="summary-chip">
        <span>Njesi te shitura</span>
        <strong>{{ analytics.unitsSold }}</strong>
      </article>
      <article class="summary-chip">
        <span>Qarkullimi</span>
        <strong>{{ formatPrice(analytics.grossSales) }}</strong>
      </article>
      <article class="summary-chip">
        <span>Fitimi i biznesit</span>
        <strong>{{ formatPrice(analytics.sellerEarnings) }}</strong>
      </article>
      <article class="summary-chip">
        <span>Payout gati</span>
        <strong>{{ formatPrice(analytics.readyPayout) }}</strong>
      </article>
      <article class="summary-chip">
        <span>Payout ne pritje</span>
        <strong>{{ formatPrice(analytics.pendingPayout) }}</strong>
      </article>
      <article class="summary-chip">
        <span>Promocione aktive</span>
        <strong>{{ analytics.activePromotions }}</strong>
      </article>
      <article class="summary-chip">
        <span>Rating mesatar</span>
        <strong>{{ Number(analytics.averageRating || 0).toFixed(1) }}/5</strong>
      </article>
      <article class="summary-chip">
        <span>Review / Returne</span>
        <strong>{{ analytics.reviewCount }} / {{ analytics.openReturns }}</strong>
      </article>
      <article
        v-for="item in engagementSummaryItems"
        :key="`business-engagement-${item.label}`"
        class="summary-chip"
      >
        <span>{{ item.label }}</span>
        <strong>{{ item.value }}</strong>
      </article>
    </section>

    <section class="card business-dashboard-workspace-card" aria-label="Veprimet kryesore te panelit">
      <div class="profile-card-header">
        <div>
          <p class="section-label">Workspace i biznesit</p>
          <h2>Hyrje te shpejta per punen e dites</h2>
          <p class="section-text">
            Keto hyrje jane menduar per hapat qe biznesi i perdor me shpesh: produktet, porosite, mesazhet, transporti dhe promocionet.
          </p>
        </div>
      </div>

      <div class="business-dashboard-workspace-grid">
        <button
          v-for="item in businessWorkspaceActions"
          :key="item.key"
          class="business-dashboard-workspace-action"
          type="button"
          :disabled="item.disabled"
          @click="handleBusinessWorkspaceAction(item)"
        >
          <strong>{{ item.title }}</strong>
          <span>{{ item.copy }}</span>
        </button>
      </div>
    </section>

    <section
      v-if="businessNextSteps.length > 0"
      class="business-dashboard-next-grid"
      aria-label="Hapat e rekomanduar per biznesin"
    >
      <button
        v-for="item in businessNextSteps"
        :key="item.key"
        class="business-dashboard-next-card"
        type="button"
        @click="handleBusinessWorkspaceAction(item)"
      >
        <p class="section-label">Next step</p>
        <strong>{{ item.title }}</strong>
        <span>{{ item.copy }}</span>
      </button>
    </section>

    <section v-if="stockAlertCount > 0" class="card business-stock-alerts-card" aria-label="Alertet e stokut">
      <div class="profile-card-header">
        <div>
          <p class="section-label">Stock alerts</p>
          <h2>Produktet qe kerkojne vemendje</h2>
          <p class="section-text">
            Ketu shfaqen artikujt me stok te ulet ose te mbaruar qe te mos mbeten pa u kontrolluar.
          </p>
        </div>
        <div class="summary-chip">
          <span>Ne veshtrim</span>
          <strong>{{ stockAlertCount }}</strong>
        </div>
      </div>

      <div class="business-stock-alerts-grid">
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
            Edito artikullin
          </button>
        </article>
      </div>

      <p v-if="stockAlertCount > stockAlertProducts.length" class="business-stock-alerts-note">
        Po shfaqen {{ stockAlertProducts.length }} nga {{ stockAlertCount }} produkte me stok te ulet ose te mbaruar.
      </p>
    </section>

    <section
      v-if="canManageCatalog"
      ref="shippingSection"
      class="card business-shipping-card"
      aria-label="Transporti i biznesit"
    >
      <div class="profile-card-header">
        <div>
          <p class="section-label">Transporti i biznesit</p>
          <h2>Rregullat e dergeses</h2>
          <p class="section-text">
            Klienti vazhdon te shohe `Standard`, `Express` dhe `Pickup`, por checkout-i llogarit koston sipas rregullave qe vendos ky biznes.
          </p>
        </div>
      </div>

      <form class="auth-form" @submit.prevent="saveShippingSettings">
        <div class="business-shipping-settings-grid">
          <article class="business-shipping-method-card">
            <div class="business-shipping-method-head">
              <div>
                <strong>Dergese standard</strong>
                <p class="section-text">Opsioni i balancuar per shumicen e porosive.</p>
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
                <p class="section-text">Per porosi me urgjence dhe ritem me te shpejte.</p>
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
                <p class="section-text">Lejoje kur klienti mund ta marre porosine direkt te biznesi yt.</p>
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
              <p class="section-text">
                Vendos shtesat e qyteteve vetem per biznesin tend. Nese nje qytet mungon, checkout-i bie te rregulli i pergjithshem.
              </p>
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

        <p class="section-text business-shipping-footnote">
          Pickup merr adresen dhe orarin tend, ndersa dergesat me transport perdorin fillimisht tarifat qe vendos ti per qytetet specifike.
        </p>

        <div class="auth-form-actions">
          <button type="submit">Ruaj transportin</button>
        </div>
      </form>

      <div class="form-message" :class="ui.shippingType" role="status" aria-live="polite">
        {{ ui.shippingMessage }}
      </div>
    </section>

    <div class="business-dashboard-layout" :class="{ 'business-dashboard-layout--single': dashboardSingleColumn }">
      <section v-if="shouldShowProfileCard" ref="profileCardSection" class="card business-profile-card">
        <h2>{{ businessProfile && isBusinessVerified ? "Edito biznesin" : "Regjistrimi i biznesit" }}</h2>
        <p class="section-text">
          {{
            businessProfile && isBusinessVerified
              ? "Admini e ka hapur perkohesisht editimin. Pasi t'i ruash ndryshimet, forma mbyllet perseri."
              : "Ploteso te dhenat e biznesit. Katalogu i produkteve aktivizohet vetem pasi admini ta verifikoje biznesin."
          }}
        </p>

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
            Nese biznesi yt ka logo, mund ta ngarkosh ketu. Ne te kunderten mund ta lesh bosh.
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
              <p class="section-label">Verifikimi</p>
              <strong>{{ formatVerificationStatusLabel(businessProfile.verificationStatus) }}</strong>
              <p class="section-text">
                {{
                  isBusinessVerified
                    ? "Biznesi eshte i verifikuar. Editimi i ketij profili hapet vetem me aprovimin e adminit."
                    : "Pasi verifikohet biznesi, hapet katalogu i produkteve dhe profili shfaqet me badge me te besueshme."
                }}
              </p>
            </div>
            <button
              v-if="['unverified', 'rejected'].includes(String(businessProfile.verificationStatus || ''))"
              class="nav-action nav-action-secondary"
              type="button"
              @click="requestVerificationReview"
            >
              Kerko verifikim
            </button>
          </div>

          <div class="auth-form-actions">
            <button type="submit">{{ businessProfile && isBusinessVerified ? "Ruaj ndryshimet" : "Ruaje biznesin" }}</button>
            <button
              v-if="businessProfile && isBusinessVerified"
              class="button-secondary"
              type="button"
              @click="showVerifiedProfileEditor = false"
            >
              Mbylle
            </button>
          </div>
        </form>

        <div class="form-message" :class="ui.profileType" role="status" aria-live="polite">
          {{ ui.profileMessage }}
        </div>
      </section>

      <section v-if="canManageCatalog" ref="productFormSection" class="card admin-form-card product-builder-card">
        <div class="product-builder-head">
          <div>
            <p class="section-label">Product builder</p>
            <h2>{{ editingProduct ? "Edito artikullin" : "Shto artikull te ri" }}</h2>
            <p class="section-text">
              Organizoje produktin me hapa te qarte: detajet, cmimi, variantet, media dhe preview final para ruajtjes.
            </p>
          </div>
          <button class="button-secondary" type="button" @click="resetProductForm">Reset</button>
        </div>

        <p v-if="editingProduct" class="admin-edit-state">
          Po editon nje artikull te biznesit tend. Nese nuk zgjedh foto te reja, ruhen fotot aktuale.
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
                <span>{{ step.caption }}</span>
                <small>{{ step.done ? "Gati" : "Ne pritje" }}</small>
              </button>
            </div>

            <section
              id="business-product-step-details"
              class="product-builder-block"
              :class="{ 'is-active': productFormStep === 'details' }"
            >
              <div class="product-builder-block-head">
                <div>
                  <p class="section-label">1. Detajet baze</p>
                  <h3>Emri, kodi dhe pershkrimi</h3>
                </div>
                <button class="button-secondary" type="button" :disabled="ui.productAiBusy" @click="suggestProductWithAi">
                  {{ ui.productAiBusy ? "Duke analizuar..." : "Sugjero me AI" }}
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
                <button class="button-secondary" type="button" @click="focusProductFormStep('pricing')">Vazhdo te cmimi</button>
              </div>
            </section>

            <section
              id="business-product-step-pricing"
              class="product-builder-block"
              :class="{ 'is-active': productFormStep === 'pricing' }"
            >
              <div class="product-builder-block-head">
                <div>
                  <p class="section-label">2. Cmimi</p>
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
                <button class="button-secondary" type="button" @click="focusProductFormStep('variants')">Vazhdo te variantet</button>
              </div>
            </section>

            <section
              id="business-product-step-variants"
              class="product-builder-block"
              :class="{ 'is-active': productFormStep === 'variants' }"
            >
              <div class="product-builder-block-head">
                <div>
                  <p class="section-label">3. Kategoria dhe variantet</p>
                  <h3>Ngjyra, madhesia, tipi dhe stoku</h3>
                  <p class="product-builder-note">Per secilin variant mund te ruash cmim ose foto specifike qe zgjedhja ne product page te ndryshoje sakte sipas ngjyres ose madhesise.</p>
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
                <button class="button-secondary" type="button" @click="focusProductFormStep('media')">Vazhdo te media</button>
              </div>
            </section>

            <section
              id="business-product-step-media"
              class="product-builder-block"
              :class="{ 'is-active': productFormStep === 'media' }"
            >
              <div class="product-builder-block-head">
                <div>
                  <p class="section-label">4. Media</p>
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
                Ngarko cover-in e produktit dhe disa foto shtese. Nese po editon produktin, fotot ekzistuese ruhen derisa te zgjedhesh te reja.
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
                <button class="button-secondary" type="button" @click="focusProductFormStep('review')">Preview final</button>
              </div>
            </section>

            <section
              id="business-product-step-review"
              class="product-builder-block"
              :class="{ 'is-active': productFormStep === 'review' }"
            >
              <div class="product-builder-block-head">
                <div>
                  <p class="section-label">5. Preview final</p>
                  <h3>Kontrolloje artikullin para ruajtjes</h3>
                </div>
              </div>

              <div class="product-builder-review-card">
                <div class="product-builder-review-media">
                  <img v-if="productPreviewCover" :src="productPreviewCover" :alt="productForm.title || 'Preview i produktit'">
                  <div v-else class="product-builder-review-empty">Pa cover</div>
                </div>
                <div class="product-builder-review-copy">
                  <p class="section-label">{{ formatCategoryLabel(productForm.category) || "Kategoria e produktit" }}</p>
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
              <p class="section-label">Quick summary</p>
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
              <p class="section-text product-builder-aside-copy">
                Preview anash te ndihmon ta kuptosh shpejt nese produkti eshte gati per publikim.
              </p>
            </article>

            <article class="product-builder-aside-card">
              <p class="section-label">Ruajtja</p>
              <h3>{{ productReadyToSave ? "Produkti duket gati" : "Mungojne disa hapa" }}</h3>
              <p class="section-text">
                {{ productReadyToSave
                  ? "Titulli, cmimi, stoku dhe media jane plotesuar. Mund ta ruash produktin."
                  : "Ploteso te pakten titullin, pershkrimin, cmimin, stokun dhe nje foto para ruajtjes." }}
              </p>
            </article>
          </aside>
        </div>

        <div class="form-message" :class="ui.productTypeMessage" role="status" aria-live="polite">
          {{ ui.productMessage }}
        </div>
      </section>
    </div>

    <section v-if="businessProfile && !canManageCatalog" class="card business-dashboard-freeze-card" aria-label="Katalogu i ngrire">
      <p class="section-label">Katalogu i ngrire</p>
      <h2>Produktet hapen pasi admini ta verifikoje biznesin</h2>
      <p class="section-text">
        Deri atehere nuk mund te shtosh, editosh, importosh apo publikosh produkte. Ploteso profilin dhe dergo kerkese per verifikim.
      </p>
    </section>

    <section v-if="canManageCatalog" class="card admin-list-card bulk-import-surface" aria-label="Flexible catalog import">
      <div class="admin-list-header">
        <div>
          <p class="section-label">Catalog import</p>
          <h2>Flexible import pipeline</h2>
          <p class="admin-compact-copy">Ngarko CSV / XLSX, lidhe JSON / API feeds, bej mapping, kontrollo parent + variants dhe pastaj kryeje importin.</p>
        </div>
      </div>

      <div class="bulk-import-shell">
        <article class="bulk-import-panel glass-strong">
          <div class="bulk-import-section-head">
            <div>
              <h3>Source setup</h3>
              <p class="section-text">Pipeline-i i ri nuk shkruan direkt ne produkte. Cdo burim kalon ne preview, mapping, normalizim dhe grouping.</p>
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
              {{ importIsPreviewLoading ? "Preparing..." : "Create preview" }}
            </button>
            <button
              class="button-secondary"
              type="button"
              :disabled="!importPreviewHasChanges || importIsPreviewLoading"
              @click="loadImportJobPreview(importCurrentJob?.id)"
            >
              Refresh preview
            </button>
            <button class="button-secondary" type="button" @click="saveCurrentImportProfile">
              Save profile
            </button>
            <button
              v-if="importSourceType === 'api-json'"
              class="button-secondary"
              type="button"
              @click="saveCurrentImportSource"
            >
              Save source
            </button>
            <button
              v-if="importSourceType === 'api-json'"
              class="button-secondary"
              type="button"
              :disabled="!importSelectedSourceId || importIsSyncLoading"
              @click="syncCurrentImportSource()"
            >
              {{ importIsSyncLoading ? "Syncing..." : "Sync source" }}
            </button>
            <button class="button-secondary" type="button" @click="downloadImportTemplate">
              Quick-start template
            </button>
          </div>
        </article>

        <aside class="bulk-import-side">
          <article class="bulk-import-panel glass-soft">
            <div class="bulk-import-section-head">
              <div>
                <h3>Summary</h3>
                <p class="section-text">Kontroll i shpejte perpara commit.</p>
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
                <p class="section-text">Rihap preview-t e fundit pa e ngarkuar skedarin nga e para.</p>
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
            <p class="section-text">Mapo kolonat e biznesit me modelin e brendshem kanonik. Vlerat jo-standarde kalojne si warnings, jo si bllokim i menjehershem.</p>
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
              <p class="section-text">Ketu kontrollohen parent products dhe variants para shkrimit ne katalog.</p>
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
              <p class="section-text">Shfaqen rreshtat e normalizuar me warnings dhe errors per review manual.</p>
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
            {{ importIsCommitLoading ? "Importing..." : "Commit import" }}
          </button>
          <button class="button-secondary" type="button" @click="clearImportSelection()">Reset</button>
          <button class="button-secondary" type="button" @click="triggerImportPicker">Choose file</button>
        </div>
      </form>

      <div class="form-message" :class="ui.importType" role="status" aria-live="polite">
        {{ ui.importMessage }}
      </div>
    </section>

    <section
      v-if="canManageCatalog"
      ref="promotionsSection"
      class="card admin-list-card"
      aria-label="Promocionet e biznesit"
    >
      <div class="admin-list-header">
        <div>
          <p class="section-label">Promocionet</p>
          <h2>Kuponet dhe ofertat</h2>
          <p class="admin-compact-copy">{{ promotions.length }} aktive ose te ruajtura</p>
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
          <button type="submit">Ruaje promocionin</button>
        </div>
      </form>

      <div class="form-message" :class="ui.promotionType" role="status" aria-live="polite">
        {{ ui.promotionMessage }}
      </div>

      <div v-if="promotions.length > 0" class="notifications-list">
        <article v-for="promotion in promotions" :key="promotion.id" class="card account-section notification-card">
          <div class="notification-card-head">
            <div>
              <p class="section-label">{{ promotion.code }}</p>
              <h2>{{ promotion.title || "Promocion" }}</h2>
            </div>
            <strong>
              {{ promotion.discountType === "percent" ? `${promotion.discountValue}%` : formatPrice(promotion.discountValue) }}
            </strong>
          </div>
          <p class="section-text">{{ promotion.description || "Pa pershkrim shtese." }}</p>
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
      ref="productsManagementSection"
      class="card admin-list-card products-management-surface"
    >
      <div class="admin-list-header">
        <div>
          <p class="section-label">Products</p>
          <h2>Products Management</h2>
          <p class="admin-compact-copy">{{ filteredProducts.length }} / {{ products.length }} artikuj</p>
        </div>
        <div class="auth-form-actions">
          <button type="button" @click="openAddProductForm">Add Product</button>
          <button class="button-secondary" type="button" @click="triggerImportPicker">Import Products</button>
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
          <span>Statusi</span>
          <select v-model="productStatusFilter">
            <option value="all">Te gjitha</option>
            <option value="public">Publik</option>
            <option value="hidden">I fshehur</option>
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
        <div class="products-view-toggle">
          <button type="button" :class="{ active: productViewMode === 'rows' }" @click="productViewMode = 'rows'">Rows</button>
          <button type="button" :class="{ active: productViewMode === 'cards' }" @click="productViewMode = 'cards'">Cards</button>
        </div>
      </div>

      <div v-if="hasSelectedProducts" class="products-bulk-actions glass-medium">
        <p>{{ selectedProducts.length }} produkte te zgjedhura</p>
        <div class="products-bulk-actions-grid">
          <button class="button-secondary" type="button" @click="applyBulkVisibility(true)">Bulk activate</button>
          <button class="button-secondary" type="button" @click="applyBulkVisibility(false)">Bulk deactivate</button>
          <label class="field">
            <span>Bulk category</span>
            <select v-model="bulkCategoryValue">
              <option value="">Zgjidh kategorine</option>
              <option v-for="option in productCategoryOptions" :key="`bulk-category-${option.value}`" :value="option.value">
                {{ option.label }}
              </option>
            </select>
          </label>
          <button class="button-secondary" type="button" :disabled="!bulkCategoryValue" @click="applyBulkCategory">Bulk change category</button>
          <label class="field">
            <span>Bulk stock</span>
            <input v-model="bulkStockValue" type="number" min="0" step="1" placeholder="0">
          </label>
          <button class="button-secondary" type="button" :disabled="bulkStockValue === ''" @click="applyBulkStockUpdate">Bulk stock update</button>
          <button class="button-danger" type="button" @click="applyBulkDelete">Bulk delete</button>
          <button class="button-secondary" type="button" @click="clearSelectedProducts">Clear</button>
        </div>
      </div>

      <div class="form-message" :class="ui.listType" role="status" aria-live="polite">
        {{ ui.listMessage }}
      </div>

      <div class="admin-products-list admin-products-list-scroll" :class="{ 'is-row-view': productViewMode === 'rows' }">
        <div v-if="products.length === 0" class="admin-empty-state">
          Ende nuk ke artikuj. Shto nje produkt ose importo nje skedar.
        </div>

        <div v-else-if="filteredProducts.length === 0" class="admin-empty-state">
          Nuk u gjet asnje produkt per kete kerkim.
        </div>

        <template v-else>
          <article v-if="productViewMode === 'rows'" class="products-table-shell">
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

          <template v-else>
            <ManagedProductCard
              v-for="product in filteredProducts"
              :key="product.id"
              :product="product"
              @edit="beginProductEdit"
              @delete="handleDeleteProduct"
              @toggle-visibility="handleToggleVisibility"
              @toggle-stock-public="handleToggleStock"
            />
          </template>
        </template>
      </div>
    </section>
  </section>
</template>

<style scoped>
.business-dashboard-workspace-card {
  display: grid;
  gap: 16px;
  margin-bottom: 18px;
}

.business-dashboard-workspace-grid,
.business-dashboard-next-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
  gap: 12px;
}

.business-dashboard-workspace-action,
.business-dashboard-next-card {
  display: grid;
  gap: 8px;
  padding: 18px 20px;
  border-radius: 22px;
  border: 1px solid rgba(47, 52, 70, 0.08);
  background: rgba(255, 255, 255, 0.8);
  color: inherit;
  text-align: left;
  box-shadow: 0 14px 30px rgba(31, 41, 55, 0.06);
}

.business-dashboard-workspace-action strong,
.business-dashboard-next-card strong {
  color: #1f2937;
  font-size: 1rem;
}

.business-dashboard-workspace-action span,
.business-dashboard-next-card span {
  color: #6b7280;
  line-height: 1.55;
}

.business-dashboard-workspace-action:disabled {
  opacity: 0.58;
  cursor: not-allowed;
}

.product-builder-card {
  display: grid;
  gap: 20px;
}

.product-builder-head,
.product-builder-block-head {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 16px;
}

.product-builder-shell {
  display: grid;
  grid-template-columns: minmax(0, 1.7fr) minmax(280px, 0.9fr);
  gap: 22px;
  align-items: start;
}

.bulk-import-shell {
  display: grid;
  grid-template-columns: minmax(0, 1.6fr) minmax(300px, 0.8fr);
  gap: 18px;
  align-items: start;
}

.bulk-import-shell--review {
  grid-template-columns: minmax(0, 1.2fr) minmax(0, 1fr);
  margin-top: 18px;
}

.bulk-import-panel {
  display: grid;
  gap: 16px;
  padding: 22px;
  border-radius: 24px;
  border: 1px solid rgba(47, 52, 70, 0.08);
  background: rgba(255, 255, 255, 0.84);
  box-shadow: 0 16px 36px rgba(15, 23, 42, 0.06);
}

.bulk-import-side {
  display: grid;
  gap: 18px;
}

.bulk-import-toolbar {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 12px;
}

.bulk-import-toolbar .field textarea,
.bulk-import-source-card textarea {
  min-height: 132px;
  resize: vertical;
}

.field-checkbox {
  display: grid;
  gap: 10px;
  align-content: start;
}

.field-checkbox input {
  width: 18px;
  height: 18px;
  margin: 0;
}

.bulk-import-source-card {
  display: grid;
  gap: 14px;
}

.bulk-import-source-card--stack {
  gap: 16px;
}

.bulk-import-actions {
  flex-wrap: wrap;
}

.bulk-import-summary-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 10px;
}

.bulk-import-job-list,
.bulk-import-group-list,
.bulk-import-record-list,
.bulk-import-variant-list {
  display: grid;
  gap: 12px;
}

.bulk-import-job-card,
.bulk-import-group-card,
.bulk-import-record-card {
  display: grid;
  gap: 10px;
  padding: 16px;
  border-radius: 20px;
  border: 1px solid rgba(47, 52, 70, 0.08);
  background: rgba(248, 250, 252, 0.92);
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
  gap: 12px;
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

.bulk-import-variant-row,
.bulk-import-record-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 10px;
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
  font-size: 0.9rem;
  line-height: 1.55;
}

.bulk-import-inline-warning {
  color: #b45309;
}

.bulk-import-inline-error {
  color: #b91c1c;
}

.product-builder-form,
.product-builder-aside {
  display: grid;
  gap: 18px;
}

.product-builder-steps {
  display: grid;
  grid-template-columns: repeat(5, minmax(0, 1fr));
  gap: 10px;
}

.product-builder-step {
  display: grid;
  gap: 6px;
  padding: 14px 16px;
  border-radius: 18px;
  border: 1px solid rgba(47, 52, 70, 0.08);
  background: rgba(255, 255, 255, 0.76);
  color: inherit;
  text-align: left;
  box-shadow: 0 12px 30px rgba(31, 41, 55, 0.06);
}

.product-builder-step strong {
  font-size: 0.95rem;
}

.product-builder-step span,
.product-builder-step small {
  color: #6b7280;
}

.product-builder-step.is-active {
  border-color: rgba(255, 106, 43, 0.28);
  box-shadow: 0 16px 34px rgba(255, 106, 43, 0.12);
}

.product-builder-step.is-done small {
  color: #ff6a2b;
}

.product-builder-block,
.product-builder-aside-card {
  display: grid;
  gap: 16px;
  padding: 22px;
  border-radius: 24px;
  border: 1px solid rgba(47, 52, 70, 0.08);
  background: rgba(255, 255, 255, 0.82);
  box-shadow: 0 16px 36px rgba(31, 41, 55, 0.07);
}

.product-builder-block.is-active {
  border-color: rgba(255, 106, 43, 0.24);
}

.product-builder-inline-summary {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
}

.product-builder-note {
  margin: 0;
  font-size: 0.94rem;
  color: #556070;
}

.product-builder-note.is-warning {
  color: #b45309;
}

.field-row-3 {
  grid-template-columns: repeat(3, minmax(0, 1fr));
}

.product-builder-review-card {
  display: grid;
  grid-template-columns: minmax(180px, 240px) minmax(0, 1fr);
  gap: 18px;
  align-items: stretch;
}

.product-builder-review-media {
  min-height: 220px;
  overflow: hidden;
  border-radius: 22px;
  background: rgba(245, 243, 241, 0.92);
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
  min-height: 220px;
  display: grid;
  place-items: center;
  color: #6b7280;
  font-weight: 700;
}

.product-builder-review-copy {
  display: grid;
  gap: 12px;
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
  gap: 10px;
}

.product-builder-price-preview strong {
  font-size: 1.35rem;
  color: #1f2937;
}

.product-builder-price-preview span {
  color: #6b7280;
  text-decoration: line-through;
}

.product-builder-price-preview mark {
  padding: 6px 10px;
  border-radius: 999px;
  background: rgba(255, 106, 43, 0.14);
  color: #c2410c;
}

.product-builder-checklist {
  list-style: none;
  margin: 0;
  padding: 0;
  display: grid;
  gap: 10px;
}

.product-builder-checklist-item {
  display: grid;
  grid-template-columns: 14px minmax(0, 1fr) auto;
  align-items: center;
  gap: 10px;
  padding: 12px 14px;
  border-radius: 18px;
  background: rgba(245, 243, 241, 0.9);
}

.product-builder-checklist-item strong {
  color: #1f2937;
}

.product-builder-checklist-item small {
  color: #6b7280;
}

.product-builder-checklist-dot {
  width: 10px;
  height: 10px;
  border-radius: 999px;
  background: rgba(47, 52, 70, 0.18);
}

.product-builder-checklist-item.is-done .product-builder-checklist-dot {
  background: #ff6a2b;
}

.product-builder-aside-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 10px;
}

@media (max-width: 1100px) {
  .bulk-import-shell,
  .bulk-import-shell--review,
  .product-builder-shell {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 840px) {
  .bulk-import-toolbar,
  .bulk-import-summary-grid,
  .bulk-import-variant-row,
  .bulk-import-record-grid,
  .business-dashboard-workspace-grid,
  .business-dashboard-next-grid,
  .product-builder-steps,
  .field-row-3,
  .product-builder-review-card {
    grid-template-columns: 1fr;
  }

  .product-builder-head,
  .product-builder-block-head {
    flex-direction: column;
  }
}
</style>
