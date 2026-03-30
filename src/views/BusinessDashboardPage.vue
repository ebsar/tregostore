<script setup>
import { computed, nextTick, onBeforeUnmount, onMounted, reactive, ref, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import ManagedProductCard from "../components/ManagedProductCard.vue";
import ProductVariantConfigurator from "../components/ProductVariantConfigurator.vue";
import {
  downloadBusinessProductsImportTemplate,
  importBusinessProductsFile,
  requestProductAIDraft,
  requestJson,
  resolveApiMessage,
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
const importFileInput = ref(null);
const importFile = ref(null);
const importPreviewRows = ref([]);
const importPreviewHeaders = ref([]);
const importDetectedHeaders = ref([]);
const importIsPreviewLoading = ref(false);
const importMapping = reactive({
  productName: "",
  description: "",
  price: "",
  sku: "",
  stock: "",
  category: "",
  imageUrl: "",
  size: "",
  color: "",
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
  promotionBusy: false,
  shippingMessage: "",
  shippingType: "",
});
const importSummary = reactive({
  totalRows: 0,
  validRows: 0,
  invalidRows: 0,
  warnings: [],
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

onMounted(async () => {
  try {
    let user = await ensureSessionLoaded();
    if (!user) {
      await new Promise((resolve) => window.setTimeout(resolve, 250));
      user = await ensureSessionLoaded({ force: true });
    }
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
  editingProduct.value = null;
  selectedFiles.value = [];
  revokePreviewUrls();
  ui.productMessage = "";
  ui.productTypeMessage = "";
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
  ui.productMessage = `Po editon artikullin "${product.title}".`;
  ui.productTypeMessage = "success";
}

function handleFilesChange(event) {
  revokePreviewUrls();
  selectedFiles.value = Array.from(event.target.files || []);
  previewUrls.value = selectedFiles.value.map((file) => URL.createObjectURL(file));
}

function handleImportFileChange(event) {
  importFile.value = event.target.files?.[0] || null;
  ui.importMessage = importFile.value
    ? `U zgjodh skedari ${importFile.value.name}.`
    : "";
  ui.importType = importFile.value ? "success" : "";
  importPreviewRows.value = [];
  importPreviewHeaders.value = [];
  importDetectedHeaders.value = [];
  importSummary.totalRows = 0;
  importSummary.validRows = 0;
  importSummary.invalidRows = 0;
  importSummary.warnings = [];
  if (!importFile.value) {
    return;
  }
  void prepareImportPreview(importFile.value);
}

function normalizeHeaderKey(value) {
  return String(value || "")
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "");
}

function autoMapImportColumns(headers = []) {
  const normalized = headers.map((header) => ({
    original: header,
    key: normalizeHeaderKey(header),
  }));
  const pick = (...patterns) => {
    const match = normalized.find((header) => patterns.some((pattern) => header.key.includes(pattern)));
    return match?.original || "";
  };
  importMapping.productName = pick("title", "name", "productname", "emri");
  importMapping.description = pick("description", "pershkrim", "desc");
  importMapping.price = pick("price", "cmim");
  importMapping.sku = pick("articlenumber", "sku", "productcode", "kod");
  importMapping.stock = pick("stock", "quantity", "sasia");
  importMapping.category = pick("category", "kategori");
  importMapping.imageUrl = pick("imagegallery", "imagepath", "imageurl", "foto");
  importMapping.size = pick("size", "madhesia");
  importMapping.color = pick("color", "ngjyra");
}

function parseCsvLine(line = "") {
  const result = [];
  let value = "";
  let quoteOpen = false;
  for (let index = 0; index < line.length; index += 1) {
    const character = line[index];
    if (character === '"') {
      const escaped = quoteOpen && line[index + 1] === '"';
      if (escaped) {
        value += '"';
        index += 1;
      } else {
        quoteOpen = !quoteOpen;
      }
      continue;
    }
    if (character === "," && !quoteOpen) {
      result.push(value.trim());
      value = "";
      continue;
    }
    value += character;
  }
  result.push(value.trim());
  return result;
}

async function prepareImportPreview(file) {
  const fileName = String(file?.name || "").trim().toLowerCase();
  const isCsvFile = fileName.endsWith(".csv") || String(file?.type || "").includes("csv");
  if (!isCsvFile) {
    importSummary.warnings = ["Preview automatik dhe column mapping jane aktive per CSV. Per XLSX mund ta importosh direkt."];
    return;
  }

  importIsPreviewLoading.value = true;
  try {
    const content = await file.text();
    const rows = String(content || "")
      .split(/\r?\n/)
      .map((line) => line.trim())
      .filter(Boolean);
    if (rows.length === 0) {
      importSummary.warnings = ["Skedari CSV duket bosh."];
      return;
    }

    const headers = parseCsvLine(rows[0]);
    importDetectedHeaders.value = headers;
    importPreviewHeaders.value = headers.slice(0, 9);
    autoMapImportColumns(headers);
    const dataRows = rows.slice(1).map((line) => parseCsvLine(line));
    importPreviewRows.value = dataRows.slice(0, 6).map((row) => {
      const mapped = {};
      importPreviewHeaders.value.forEach((header, index) => {
        mapped[header] = String(row[index] || "").trim();
      });
      return mapped;
    });
    importSummary.totalRows = dataRows.length;
    importSummary.validRows = dataRows.filter((row) =>
      String(row[headers.indexOf(importMapping.productName)] || "").trim()
      && String(row[headers.indexOf(importMapping.price)] || "").trim(),
    ).length;
    importSummary.invalidRows = Math.max(0, importSummary.totalRows - importSummary.validRows);
    importSummary.warnings = importSummary.invalidRows > 0
      ? ["Disa rreshta duken pa emer produkti ose pa cmim. Backend-i do i ktheje si gabime ne import."]
      : [];
  } catch (error) {
    console.error(error);
    importSummary.warnings = ["Preview nuk u lexua. Mund ta importosh direkt dhe sistemi do ta validoje."];
  } finally {
    importIsPreviewLoading.value = false;
  }
}

async function downloadImportTemplate() {
  const result = await downloadBusinessProductsImportTemplate();
  ui.importMessage = result.message;
  ui.importType = result.ok ? "success" : "error";
}

async function submitImportProducts() {
  if (!canManageCatalog.value) {
    ui.importMessage = "Biznesi duhet te verifikohet nga admini para se te importosh artikuj.";
    ui.importType = "error";
    return;
  }

  if (!importFile.value) {
    ui.importMessage = "Zgjidh nje skedar CSV per import.";
    ui.importType = "error";
    return;
  }

  const result = await importBusinessProductsFile(importFile.value);
  ui.importMessage = result.message;
  ui.importType = result.ok ? "success" : "error";

  if (!result.ok) {
    return;
  }

  importSummary.totalRows = Math.max(importSummary.totalRows, Number(result.count || 0));
  importSummary.validRows = Number(result.count || 0);
  importSummary.invalidRows = Math.max(0, importSummary.totalRows - importSummary.validRows);
  importFile.value = null;
  if (importFileInput.value) {
    importFileInput.value.value = "";
  }
  importPreviewRows.value = [];
  importPreviewHeaders.value = [];
  importDetectedHeaders.value = [];
  await loadProducts();
  await loadBusinessAnalytics();
}

function clearImportSelection() {
  importFile.value = null;
  importPreviewRows.value = [];
  importPreviewHeaders.value = [];
  importDetectedHeaders.value = [];
  importSummary.totalRows = 0;
  importSummary.validRows = 0;
  importSummary.invalidRows = 0;
  importSummary.warnings = [];
  Object.keys(importMapping).forEach((key) => {
    importMapping[key] = "";
  });
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
    description: productForm.description.trim(),
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
  if (ui.promotionBusy) {
    return;
  }

  if (!canManageCatalog.value) {
    ui.promotionMessage = "Biznesi duhet te verifikohet nga admini para se te ruash promocione.";
    ui.promotionType = "error";
    return;
  }

  const promoCode = String(promotionForm.code || "").trim().toUpperCase();
  const discountValue = Number(promotionForm.discountValue || 0);
  if (promoCode.length < 3) {
    ui.promotionMessage = "Kodi i promocionit duhet te kete te pakten 3 karaktere.";
    ui.promotionType = "error";
    return;
  }
  if (!Number.isFinite(discountValue) || discountValue <= 0) {
    ui.promotionMessage = "Vendos nje vlere zbritjeje me te madhe se 0.";
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

  ui.promotionBusy = true;
  try {
    const payload = {
      ...promotionForm,
      code: promoCode,
      discountValue,
    };
    const { response, data } = await requestJson("/api/business/promotions", {
      method: "POST",
      body: JSON.stringify(payload),
    });

    if (!response.ok || !data?.ok) {
      if (Number(response?.status || 0) === 401) {
        ui.promotionMessage = "Sesioni skadoi. Kyçu perseri dhe provoje.";
      } else {
        ui.promotionMessage = resolveApiMessage(data, "Promocioni nuk u ruajt.");
      }
      ui.promotionType = "error";
      return;
    }

    promotions.value = Array.isArray(data.promotions) ? data.promotions : promotions.value;
    ui.promotionMessage = data.message || "Promocioni u ruajt.";
    ui.promotionType = "success";
    resetPromotionForm();
    await loadBusinessAnalytics();
  } finally {
    ui.promotionBusy = false;
  }
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

    <section v-if="canManageCatalog" class="card business-shipping-card" aria-label="Transporti i biznesit">
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
      <section v-if="shouldShowProfileCard" class="card business-profile-card">
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
              <span>Qyteti</span>
              <input v-model="profileForm.city" type="text" placeholder="p.sh. Prishtine" required>
            </label>
          </div>

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

      <section v-if="canManageCatalog" ref="productFormSection" class="card admin-form-card">
        <h2>{{ editingProduct ? "Edito artikullin" : "Shto artikull te ri" }}</h2>
        <p class="section-text">
          Artikujt qe shton ketu lidhen vetem me biznesin tend. Madhesia shfaqet vetem per veshjet.
        </p>
        <p v-if="editingProduct" class="admin-edit-state">
          Po editon nje artikull te biznesit tend. Nese nuk zgjedh foto te reja, ruhen fotot aktuale.
        </p>

        <form class="auth-form" @submit.prevent="submitProduct">
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

          <label class="field">
            <span>Cmimi (€)</span>
            <input v-model="productForm.price" type="number" min="0.01" step="0.01" placeholder="p.sh. 13.99" required>
          </label>

          <ProductVariantConfigurator :form="productForm" />

          <label class="field">
            <span>Upload photo</span>
            <input type="file" accept="image/*" multiple :required="!editingProduct" @change="handleFilesChange">
          </label>

          <p class="product-upload-help">
            Mund te ngarkosh disa foto per te njejtin artikull. Ato shfaqen vetem te artikulli yt.
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

          <label class="field">
            <span>Pershkrimi</span>
            <textarea v-model="productForm.description" rows="4" placeholder="Shkruaje pershkrimin e produktit" required></textarea>
          </label>

          <div class="auth-form-actions">
            <button class="button-secondary" type="button" :disabled="ui.productAiBusy" @click="suggestProductWithAi">
              {{ ui.productAiBusy ? "Duke analizuar..." : "Sugjero me AI" }}
            </button>
            <button type="submit">{{ editingProduct ? "Ruaj ndryshimet" : "Ruaje artikullin" }}</button>
            <button v-if="editingProduct" class="button-secondary" type="button" @click="resetProductForm">Anulo editimin</button>
          </div>
        </form>

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

    <section v-if="canManageCatalog" class="card admin-list-card bulk-import-surface" aria-label="Importo artikuj nga Excel">
      <div class="admin-list-header">
        <div>
          <p class="section-label">Bulk import</p>
          <h2>Import Products</h2>
          <p class="admin-compact-copy">Ngarko CSV / Excel dhe shto produkte ne katalog me nje proces te qarte.</p>
        </div>
      </div>

      <div class="bulk-import-grid">
        <article class="bulk-import-upload glass-strong">
          <h3>Upload file</h3>
          <p class="section-text">Formatet e lejuara: CSV, XLSX. Ne CSV mund te shohesh preview dhe mapping para importit.</p>
          <label class="bulk-import-dropzone">
            <input
              ref="importFileInput"
              type="file"
              accept=".xlsx,.csv,text/csv,application/vnd.ms-excel,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
              @change="handleImportFileChange"
            >
            <strong>{{ importFile ? importFile.name : "Zvarrit skedarin ketu ose kliko per upload" }}</strong>
            <span>{{ importFile ? "Skedari eshte gati per import." : "CSV / Excel per artikujt e biznesit" }}</span>
          </label>
          <div class="auth-form-actions">
            <button type="button" @click="downloadImportTemplate">Download Template</button>
          </div>
        </article>

        <article class="bulk-import-instructions glass-soft">
          <h3>Kolonat e rekomanduara</h3>
          <p class="section-text">Sigurohu qe skedari te kete te pakten emrin e produktit dhe cmimin.</p>
          <div class="product-detail-tags product-detail-tags-admin">
            <span class="product-detail-tag">Product Name</span>
            <span class="product-detail-tag">Description</span>
            <span class="product-detail-tag">Price</span>
            <span class="product-detail-tag">SKU</span>
            <span class="product-detail-tag">Stock</span>
            <span class="product-detail-tag">Category</span>
            <span class="product-detail-tag">Image URL</span>
            <span class="product-detail-tag">Size</span>
            <span class="product-detail-tag">Color</span>
          </div>
        </article>
      </div>

      <article v-if="importDetectedHeaders.length > 0" class="bulk-import-mapping glass-strong">
        <div class="bulk-import-section-head">
          <h3>Column mapping</h3>
          <p class="section-text">Përshtat kolonat e skedarit me fushat e produktit.</p>
        </div>
        <div class="bulk-import-mapping-grid">
          <label class="field">
            <span>Product Name</span>
            <select v-model="importMapping.productName">
              <option value="">Zgjidh kolonen</option>
              <option v-for="header in importDetectedHeaders" :key="`map-name-${header}`" :value="header">{{ header }}</option>
            </select>
          </label>
          <label class="field">
            <span>Description</span>
            <select v-model="importMapping.description">
              <option value="">Zgjidh kolonen</option>
              <option v-for="header in importDetectedHeaders" :key="`map-desc-${header}`" :value="header">{{ header }}</option>
            </select>
          </label>
          <label class="field">
            <span>Price</span>
            <select v-model="importMapping.price">
              <option value="">Zgjidh kolonen</option>
              <option v-for="header in importDetectedHeaders" :key="`map-price-${header}`" :value="header">{{ header }}</option>
            </select>
          </label>
          <label class="field">
            <span>SKU</span>
            <select v-model="importMapping.sku">
              <option value="">Zgjidh kolonen</option>
              <option v-for="header in importDetectedHeaders" :key="`map-sku-${header}`" :value="header">{{ header }}</option>
            </select>
          </label>
          <label class="field">
            <span>Stock</span>
            <select v-model="importMapping.stock">
              <option value="">Zgjidh kolonen</option>
              <option v-for="header in importDetectedHeaders" :key="`map-stock-${header}`" :value="header">{{ header }}</option>
            </select>
          </label>
          <label class="field">
            <span>Category</span>
            <select v-model="importMapping.category">
              <option value="">Zgjidh kolonen</option>
              <option v-for="header in importDetectedHeaders" :key="`map-category-${header}`" :value="header">{{ header }}</option>
            </select>
          </label>
        </div>
      </article>

      <article class="bulk-import-summary">
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
      </article>

      <article class="bulk-import-preview glass-soft">
        <div class="bulk-import-section-head">
          <h3>Preview</h3>
          <p class="section-text">Shfaqen rreshtat e pare per kontroll para importit.</p>
        </div>
        <div v-if="importIsPreviewLoading" class="admin-empty-state">Duke lexuar skedarin...</div>
        <div v-else-if="importPreviewRows.length === 0" class="admin-empty-state">
          Nuk ka preview. Ngarko nje skedar CSV per te pare rreshtat para importit.
        </div>
        <div v-else class="bulk-import-table-wrap">
          <table class="bulk-import-table">
            <thead>
              <tr>
                <th v-for="header in importPreviewHeaders" :key="`head-${header}`">{{ header }}</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(row, rowIndex) in importPreviewRows" :key="`row-${rowIndex}`">
                <td v-for="header in importPreviewHeaders" :key="`cell-${rowIndex}-${header}`">{{ row[header] || "—" }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </article>

      <div v-if="importSummary.warnings.length > 0" class="form-message error" role="status" aria-live="polite">
        {{ importSummary.warnings.join(" ") }}
      </div>

      <form class="auth-form" @submit.prevent="submitImportProducts">
        <div class="auth-form-actions">
          <button type="submit">Import Products</button>
          <button class="button-secondary" type="button" @click="clearImportSelection">Cancel</button>
          <button class="button-secondary" type="button" @click="downloadImportTemplate">Download Template</button>
        </div>
      </form>

      <div class="form-message" :class="ui.importType" role="status" aria-live="polite">
        {{ ui.importMessage }}
      </div>
    </section>

    <section v-if="canManageCatalog" class="card admin-list-card" aria-label="Promocionet e biznesit">
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
          <button type="submit" :disabled="ui.promotionBusy">
            {{ ui.promotionBusy ? "Duke ruajtur..." : "Ruaje promocionin" }}
          </button>
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

    <section v-if="canManageCatalog" class="card admin-list-card products-management-surface">
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
