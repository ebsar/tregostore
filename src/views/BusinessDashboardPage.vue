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
  deriveSectionFromCategory,
  hydrateProductFormFromProduct,
  PRODUCT_PAGE_SECTION_OPTIONS,
  PRODUCT_SECTION_OPTIONS,
  syncProductFormCatalogState,
} from "../lib/product-catalog";
import {
  DELIVERY_METHOD_OPTIONS,
  formatCategoryLabel,
  formatPrice,
  formatRoleLabel,
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
const productFormSection = ref(null);
const productTitleInput = ref(null);
const importFileInput = ref(null);
const importFile = ref(null);
const showVerifiedProfileEditor = ref(false);
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
  shippingMessage: "",
  shippingType: "",
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
  const nextProducts = [...products.value];
  if (!normalizedQuery) {
    return nextProducts;
  }

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

  return nextProducts
    .map((product) => ({ product, score: scoreProductMatch(product) }))
    .filter((entry) => entry.score < 99)
    .sort((left, right) =>
      left.score - right.score
      || String(left.product.title || "").localeCompare(String(right.product.title || ""))
    )
    .map((entry) => entry.product);
});

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

  importFile.value = null;
  if (importFileInput.value) {
    importFileInput.value.value = "";
  }
  await loadProducts();
  await loadBusinessAnalytics();
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

    <section v-if="canManageCatalog" class="card admin-list-card" aria-label="Importo artikuj nga Excel">
      <div class="admin-list-header">
        <div>
          <p class="section-label">Import ne Excel</p>
          <h2>Ngarko liste artikujsh</h2>
        </div>
      </div>

      <p class="section-text">
        Shkarko template-n XLSX, hape ne Excel, ploteso artikujt dhe pastaj ngarkoje prape ketu.
        Kolonat e kerkuara jane te perfshira ne template, perfshire kategorine, llojin, ngjyren,
        stokun, numrin e artikullit dhe fotot. Per fotot perdor path-et ekzistuese si <code>/uploads/...</code>.
      </p>

      <div class="auth-form-actions">
        <button type="button" @click="downloadImportTemplate">Shkarko template XLSX per Excel</button>
      </div>

      <form class="auth-form" @submit.prevent="submitImportProducts">
        <label class="field">
          <span>Skedari CSV i artikujve</span>
          <input
            ref="importFileInput"
            type="file"
            accept=".xlsx,.csv,text/csv,application/vnd.ms-excel,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
            @change="handleImportFileChange"
          >
        </label>

        <p class="product-upload-help">
          XLSX ose CSV hapen direkt ne Excel. Kolona <code>imageGallery</code> pranon disa foto te ndara me <code>;</code>,
          ndersa <code>articleNumber</code> ruan numrin unik te artikullit.
        </p>

        <div class="auth-form-actions">
          <button type="submit">Importo artikujt</button>
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

    <section v-if="canManageCatalog" class="card admin-list-card">
      <div class="admin-list-header">
        <div>
          <p class="section-label">Artikujt e biznesit tend</p>
          <h2>Lista e artikujve</h2>
          <p class="admin-compact-copy">{{ filteredProducts.length }} / {{ products.length }} artikuj</p>
        </div>
      </div>

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

      <div class="form-message" :class="ui.listType" role="status" aria-live="polite">
        {{ ui.listMessage }}
      </div>

      <div class="admin-products-list admin-products-list-scroll">
        <div v-if="products.length === 0" class="admin-empty-state">
          Ende nuk ke artikuj te publikuar nga ky biznes.
        </div>

        <div v-else-if="filteredProducts.length === 0" class="admin-empty-state">
          Nuk u gjet asnje produkt per kete kerkim.
        </div>

        <ManagedProductCard
          v-for="product in filteredProducts"
          :key="product.id"
          :product="product"
          @edit="beginProductEdit"
          @delete="handleDeleteProduct"
          @toggle-visibility="handleToggleVisibility"
          @toggle-stock-public="handleToggleStock"
        />
      </div>
    </section>
  </section>
</template>
