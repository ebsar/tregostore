<script setup lang="ts">
import { IonButton, IonContent, IonIcon, IonPage } from "@ionic/vue";
import { alertCircleOutline, chatbubbleEllipsesOutline, cloudDownloadOutline, cubeOutline, pricetagOutline, receiptOutline, refreshOutline, storefrontOutline } from "ionicons/icons";
import { computed, onBeforeUnmount, onMounted, reactive, ref } from "vue";
import { useRouter } from "vue-router";
import AppPageHeader from "../components/AppPageHeader.vue";
import EmptyStatePanel from "../components/EmptyStatePanel.vue";
import ProductCardMobile from "../components/ProductCardMobile.vue";
import ProductVariantConfiguratorMobile from "../components/ProductVariantConfiguratorMobile.vue";
import {
  createDownloadUrl,
  createOrUpdateProduct,
  deleteBusinessPromotion,
  deleteProduct,
  fetchBusinessAnalytics,
  fetchBusinessOrders,
  fetchBusinessProducts,
  fetchBusinessProfile,
  fetchBusinessPromotions,
  fetchReturnRequests,
  importBusinessProductsFile,
  requestBusinessProfileEditAccess,
  requestBusinessVerification,
  saveBusinessPromotion,
  updateOrderItemStatus,
  updateProductPublicStock,
  updateProductVisibility,
  updateReturnRequestStatus,
  uploadImages,
} from "../lib/api";
import { buildFulfillmentTimeline, formatCount, formatDateLabel, formatOrderStatusBadgeLabel, formatPrice } from "../lib/format";
import { createEmptyProductFormState, deriveAudienceFromCategory, deriveSectionFromCategory, buildVariantInventoryFromForm, syncProductFormCatalogState } from "../lib/productCatalog";
import type { OrderItem, ProductItem, PromotionItem, ReturnRequestItem } from "../types/models";
import { ensureSession, sessionState } from "../stores/session";

const router = useRouter();
const loading = ref(true);
const activeSection = ref<"catalog" | "orders" | "promotions" | "returns" | "profile">("catalog");
const businessProfile = ref<any>(null);
const businessAnalytics = ref<any>(null);
const products = ref<ProductItem[]>([]);
const orders = ref<OrderItem[]>([]);
const promotions = ref<PromotionItem[]>([]);
const returnRequests = ref<ReturnRequestItem[]>([]);
const editingProductId = ref(0);
const importFile = ref<File | null>(null);
const productFlowStep = ref<"details" | "pricing" | "variants" | "media" | "review">("details");
const orderDrafts = reactive<Record<number, { fulfillmentStatus: string; trackingCode: string; trackingUrl: string }>>({});
const productForm = reactive(createEmptyProductFormState() as Record<string, any>);
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
const selectedFiles = ref<File[]>([]);
const selectedFilePreviewUrls = ref<string[]>([]);
const ui = reactive({
  message: "",
  type: "",
});

const canAccess = computed(() => sessionState.user?.role === "business");
const canManageCatalog = computed(() => String(businessProfile.value?.verificationStatus || "").trim().toLowerCase() === "verified");
const publicStorePath = computed(() => {
  const businessId = Number(businessProfile.value?.id || 0);
  return businessId > 0 ? `/business/public/${businessId}` : "";
});
const summaryCards = computed(() => [
  { label: "Produkte", value: formatCount(products.value.length), icon: cubeOutline },
  { label: "Porosi", value: formatCount(orders.value.length), icon: receiptOutline },
  { label: "Promo", value: formatCount(promotions.value.length), icon: pricetagOutline },
  { label: "Kthime", value: formatCount(returnRequests.value.length), icon: refreshOutline },
]);
const studioQuickActions = computed(() => [
  {
    key: "catalog",
    title: "Katalogu",
    copy: "Artikujt dhe builder-i",
    icon: cubeOutline,
    section: "catalog",
  },
  {
    key: "orders",
    title: "Porosite",
    copy: `${formatCount(orders.value.length)} ne monitorim`,
    icon: receiptOutline,
    section: "orders",
  },
  {
    key: "promotions",
    title: "Promocione",
    copy: promotions.value.length ? `${formatCount(promotions.value.length)} oferta` : "Krijo te paren",
    icon: pricetagOutline,
    section: "promotions",
  },
  {
    key: "returns",
    title: "Kthime",
    copy: returnRequests.value.length ? `${formatCount(returnRequests.value.length)} raste` : "Pa kerkesa",
    icon: refreshOutline,
    section: "returns",
  },
  {
    key: "messages",
    title: "Mesazhet",
    copy: "Inbox me klientet",
    icon: chatbubbleEllipsesOutline,
    route: "/messages",
  },
  {
    key: "store",
    title: publicStorePath.value ? "Dyqani" : "Profili",
    copy: publicStorePath.value ? "Shiko faqen publike" : "Perditeso te dhenat",
    icon: storefrontOutline,
    route: publicStorePath.value || "",
    section: publicStorePath.value ? undefined : "profile",
  },
]);
const studioFocusCards = computed(() => {
  const items = [];

  if (!canManageCatalog.value) {
    items.push({
      key: "verify",
      title: "Zhblloko katalogun",
      copy: "Kerko verifikimin e biznesit qe te hapet shtimi, importi dhe publikimi i artikujve.",
    });
  }

  if (canManageCatalog.value && !products.value.length) {
    items.push({
      key: "catalog",
      title: "Shto artikullin e pare",
      copy: "Fillimi me nje produkt cover e ben dyqanin gati per vizitoret e pare.",
    });
  }

  if (canManageCatalog.value && promotions.value.length === 0) {
    items.push({
      key: "promotions",
      title: "Krijo oferten e pare",
      copy: "Zbritjet e para e bejne storefront-in me bindes dhe me aktiv.",
    });
  }

  if (returnRequests.value.length > 0) {
    items.push({
      key: "returns",
      title: "Kontrollo kthimet",
      copy: `${formatCount(returnRequests.value.length)} kerkesa duan pergjigje ose perditesim statusi.`,
    });
  }

  return items.slice(0, 3);
});
const salePreview = computed(() => {
  const price = Number(productForm.price || 0);
  const compareAtPrice = Number(productForm.compareAtPrice || 0);
  if (!Number.isFinite(price) || !Number.isFinite(compareAtPrice) || price <= 0 || compareAtPrice <= price) {
    return 0;
  }

  return Math.max(0, Math.round(((compareAtPrice - price) / compareAtPrice) * 100));
});
const productVariantEntries = computed(() => buildVariantInventoryFromForm(productForm));
const productStockTotal = computed(() =>
  productVariantEntries.value.reduce((total, entry) => total + Math.max(0, Number(entry.quantity || 0)), 0),
);
const productPreviewImages = computed(() =>
  selectedFilePreviewUrls.value.length > 0
    ? selectedFilePreviewUrls.value
    : (Array.isArray(productForm.imageGallery) ? productForm.imageGallery : []),
);
const productChecklist = computed(() => ([
  {
    key: "details",
    label: "Titulli dhe pershkrimi",
    done: Boolean(String(productForm.title || "").trim() && String(productForm.description || "").trim()),
  },
  {
    key: "pricing",
    label: "Cmimi dhe oferta",
    done: Number(productForm.price || 0) > 0
      && (!Number(productForm.compareAtPrice || 0) || Number(productForm.compareAtPrice || 0) > Number(productForm.price || 0)),
  },
  {
    key: "variants",
    label: "Kategori, variante dhe stok",
    done: productStockTotal.value > 0,
  },
  {
    key: "media",
    label: "Foto te produktit",
    done: productPreviewImages.value.length > 0,
  },
]));
const productReadyToSave = computed(() => productChecklist.value.every((item) => item.done));
const productFlowSteps = computed(() => ([
  {
    id: "details",
    label: "Detajet",
    caption: "Titulli dhe copy",
    done: productChecklist.value.find((item) => item.key === "details")?.done,
  },
  {
    id: "pricing",
    label: "Cmimi",
    caption: "Regular dhe sale",
    done: productChecklist.value.find((item) => item.key === "pricing")?.done,
  },
  {
    id: "variants",
    label: "Variantet",
    caption: "Kategoria dhe stoku",
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
    caption: "Kontrolli final",
    done: productReadyToSave.value,
  },
]));
const productCoverPreview = computed(() => productPreviewImages.value[0] || "");

function revokeSelectedFilePreviews() {
  selectedFilePreviewUrls.value.forEach((value) => {
    if (value.startsWith("blob:")) {
      URL.revokeObjectURL(value);
    }
  });
  selectedFilePreviewUrls.value = [];
}

function setUiMessage(message: string, type = "info") {
  ui.message = message;
  ui.type = type;
}

function resetProductForm() {
  Object.assign(productForm, createEmptyProductFormState());
  editingProductId.value = 0;
  selectedFiles.value = [];
  productFlowStep.value = "details";
  revokeSelectedFilePreviews();
}

function hydrateProductForm(product: ProductItem) {
  resetProductForm();
  editingProductId.value = Number(product.id || 0);
  productForm.articleNumber = String(product.articleNumber || "");
  productForm.title = String(product.title || "");
  productForm.price = String(product.price ?? "");
  productForm.compareAtPrice = Number(product.compareAtPrice || 0) > Number(product.price || 0)
    ? String(product.compareAtPrice ?? "")
    : "";
  productForm.saleEndsAt = String(product.saleEndsAt || "");
  productForm.description = String(product.description || "");
  productForm.pageSection = deriveSectionFromCategory(String(product.category || ""));
  productForm.audience = deriveAudienceFromCategory(String(product.category || ""));
  syncProductFormCatalogState(productForm);
  productForm.productType = String(product.productType || productForm.productType || "");
  productForm.packageAmountValue = String(product.packageAmountValue || "");
  productForm.packageAmountUnit = String(product.packageAmountUnit || "ml");
  productForm.simpleStockQuantity = String(product.stockQuantity ?? 0);
  productForm.imageGallery = Array.isArray(product.imageGallery) ? [...product.imageGallery] : (product.imagePath ? [product.imagePath] : []);

  const variants = Array.isArray(product.variantInventory) ? product.variantInventory : [];
  const selectedColors = [...new Set(variants.map((entry) => String(entry.color || "").trim().toLowerCase()).filter(Boolean))];
  productForm.selectedColors = selectedColors;
  syncProductFormCatalogState(productForm);

  if (productForm.pageSection === "clothing") {
    productForm.clothingColorVariants = selectedColors.map((color: string) => ({
      color,
      sizeEntries: ["XS", "S", "M", "L", "XL", "XXL", "XXXL"].map((size) => {
        const existing = variants.find((entry) => String(entry.color || "").trim().toLowerCase() === color && String(entry.size || "").trim().toUpperCase() === size);
        return {
          size,
          enabled: Boolean(existing),
          quantity: String(existing?.quantity ?? 0),
          price: String(existing?.price ?? ""),
          imagePath: String(existing?.imagePath || ""),
        };
      }),
    }));
  } else if (selectedColors.length) {
    productForm.colorStockVariants = selectedColors.map((color: string) => {
      const existing = variants.find((entry) => String(entry.color || "").trim().toLowerCase() === color);
      return {
        color,
        quantity: String(existing?.quantity ?? 0),
        price: String(existing?.price ?? ""),
        imagePath: String(existing?.imagePath || ""),
      };
    });
  }
  productFlowStep.value = "details";
}

function handleSelectedFilesChange(event: Event) {
  const input = event.target as HTMLInputElement;
  selectedFiles.value = Array.from(input?.files || []);
  revokeSelectedFilePreviews();
  selectedFilePreviewUrls.value = selectedFiles.value.map((file) => URL.createObjectURL(file));
}

function openProductFlowStep(step: "details" | "pricing" | "variants" | "media" | "review") {
  productFlowStep.value = step;
}

function handleStudioAction(item: { route?: string; section?: "catalog" | "orders" | "promotions" | "returns" | "profile" }) {
  if (item.route) {
    router.push(item.route);
    return;
  }

  if (item.section) {
    activeSection.value = item.section;
  }
}

function moveProductFlow(direction: 1 | -1) {
  const sequence = ["details", "pricing", "variants", "media", "review"] as const;
  const currentIndex = sequence.indexOf(productFlowStep.value);
  const nextIndex = Math.min(sequence.length - 1, Math.max(0, currentIndex + direction));
  productFlowStep.value = sequence[nextIndex];
}

function draftForOrderItem(item: any) {
  const itemId = Number(item?.id || 0);
  if (!orderDrafts[itemId]) {
    orderDrafts[itemId] = {
      fulfillmentStatus: String(item?.fulfillmentStatus || "pending_confirmation"),
      trackingCode: String(item?.trackingCode || ""),
      trackingUrl: String(item?.trackingUrl || ""),
    };
  }
  return orderDrafts[itemId];
}

async function loadAll() {
  loading.value = true;
  try {
    const [profilePayload, analyticsPayload, nextProducts, nextOrders, nextPromotions, nextReturns] = await Promise.all([
      fetchBusinessProfile(),
      fetchBusinessAnalytics(),
      fetchBusinessProducts(),
      fetchBusinessOrders(),
      fetchBusinessPromotions(),
      fetchReturnRequests(),
    ]);
    businessProfile.value = profilePayload.data?.profile || null;
    businessAnalytics.value = analyticsPayload.data?.analytics || null;
    products.value = nextProducts;
    orders.value = nextOrders;
    promotions.value = nextPromotions;
    returnRequests.value = nextReturns;
  } finally {
    loading.value = false;
  }
}

onMounted(async () => {
  await ensureSession();
  if (!canAccess.value) {
    loading.value = false;
    return;
  }
  await loadAll();
});

onBeforeUnmount(() => {
  revokeSelectedFilePreviews();
});

async function handleSaveProduct() {
  if (!canManageCatalog.value) {
    setUiMessage("Biznesi duhet te verifikohet para se te menaxhosh katalogun.", "error");
    return;
  }

  let imageGallery = Array.isArray(productForm.imageGallery) ? [...productForm.imageGallery] : [];
  if (selectedFiles.value.length > 0) {
    const uploadResult = await uploadImages(selectedFiles.value);
    if (!uploadResult.ok) {
      setUiMessage(uploadResult.message, "error");
      return;
    }
    imageGallery = uploadResult.paths;
  }

  const payload = {
    articleNumber: String(productForm.articleNumber || "").trim(),
    title: String(productForm.title || "").trim(),
    price: String(productForm.price || "").trim(),
    description: String(productForm.description || "").trim(),
    pageSection: String(productForm.pageSection || "").trim(),
    audience: String(productForm.audience || "").trim(),
    category: String(productForm.category || "").trim(),
    productType: String(productForm.productType || "").trim(),
    stockQuantity: String(productForm.simpleStockQuantity || "").trim(),
    packageAmountValue: String(productForm.packageAmountValue || "").trim(),
    packageAmountUnit: String(productForm.packageAmountUnit || "").trim(),
    variantInventory: buildVariantInventoryFromForm(productForm),
    imageGallery,
    imagePath: imageGallery[0] || "",
    compareAtPrice: String(productForm.compareAtPrice || "").trim(),
    saleEndsAt: String(productForm.saleEndsAt || "").trim(),
  };

  const { response, data } = await createOrUpdateProduct(payload, editingProductId.value || undefined);
  if (!response.ok || !data?.ok) {
    setUiMessage(String(data?.errors?.join?.(" ") || data?.message || "Produkti nuk u ruajt."), "error");
    return;
  }

  setUiMessage(String(data.message || "Produkti u ruajt."), "success");
  resetProductForm();
  await loadAll();
}

async function handleDeleteProduct(product: ProductItem) {
  const { response, data } = await deleteProduct(Number(product.id));
  if (!response.ok || !data?.ok) {
    setUiMessage(String(data?.message || "Produkti nuk u fshi."), "error");
    return;
  }
  setUiMessage(String(data.message || "Produkti u fshi."), "success");
  await loadAll();
}

async function handleToggleVisibility(product: ProductItem) {
  const { response, data } = await updateProductVisibility(Number(product.id), !Boolean(product.isPublic));
  if (!response.ok || !data?.ok) {
    setUiMessage(String(data?.message || "Dukshmeria nuk u ruajt."), "error");
    return;
  }
  setUiMessage(String(data.message || "Dukshmeria u ruajt."), "success");
  await loadAll();
}

async function handleToggleStock(product: ProductItem) {
  const { response, data } = await updateProductPublicStock(Number(product.id), !Boolean(product.showStockPublic));
  if (!response.ok || !data?.ok) {
    setUiMessage(String(data?.message || "Shfaqja e stokut nuk u ruajt."), "error");
    return;
  }
  setUiMessage(String(data.message || "Shfaqja e stokut u ruajt."), "success");
  await loadAll();
}

async function handleImportProducts() {
  if (!importFile.value) {
    setUiMessage("Zgjidh nje file CSV ose XLSX per import.", "error");
    return;
  }
  const result = await importBusinessProductsFile(importFile.value);
  setUiMessage(result.message, result.ok ? "success" : "error");
  if (result.ok) {
    importFile.value = null;
    await loadAll();
  }
}

async function handleSavePromotion() {
  const { response, data } = await saveBusinessPromotion({ ...promotionForm });
  if (!response.ok || !data?.ok) {
    setUiMessage(String(data?.message || "Promocioni nuk u ruajt."), "error");
    return;
  }
  Object.assign(promotionForm, {
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
  setUiMessage(String(data.message || "Promocioni u ruajt."), "success");
  await loadAll();
}

async function handleDeletePromotion(promotion: PromotionItem) {
  const { response, data } = await deleteBusinessPromotion(Number(promotion.id || 0), String(promotion.code || ""));
  if (!response.ok || !data?.ok) {
    setUiMessage(String(data?.message || "Promocioni nuk u fshi."), "error");
    return;
  }
  setUiMessage(String(data.message || "Promocioni u fshi."), "success");
  await loadAll();
}

async function handleUpdateOrderItem(item: any) {
  const draft = draftForOrderItem(item);
  const { response, data } = await updateOrderItemStatus({
    orderItemId: Number(item.id),
    fulfillmentStatus: draft.fulfillmentStatus,
    trackingCode: draft.trackingCode,
    trackingUrl: draft.trackingUrl,
  });
  if (!response.ok || !data?.ok) {
    setUiMessage(String(data?.message || "Statusi nuk u ruajt."), "error");
    return;
  }
  setUiMessage(String(data.message || "Statusi u ruajt."), "success");
  await loadAll();
}

async function handleUpdateReturn(request: ReturnRequestItem, status: string) {
  const { response, data } = await updateReturnRequestStatus(Number(request.id), status);
  if (!response.ok || !data?.ok) {
    setUiMessage(String(data?.message || "Kerkesa nuk u perditesua."), "error");
    return;
  }
  setUiMessage(String(data.message || "Kerkesa u perditesua."), "success");
  await loadAll();
}

async function handleRequestVerification() {
  const { response, data } = await requestBusinessVerification();
  if (!response.ok || !data?.ok) {
    setUiMessage(String(data?.message || "Kerkesa per verifikim nuk u dergua."), "error");
    return;
  }
  setUiMessage(String(data.message || "Kerkesa per verifikim u dergua."), "success");
  await loadAll();
}

async function handleRequestEditAccess() {
  const { response, data } = await requestBusinessProfileEditAccess();
  if (!response.ok || !data?.ok) {
    setUiMessage(String(data?.message || "Kerkesa per editim nuk u dergua."), "error");
    return;
  }
  setUiMessage(String(data.message || "Kerkesa per editim u dergua."), "success");
  await loadAll();
}
</script>

<template>
  <IonPage>
    <IonContent class="app-gradient" :fullscreen="true">
      <div class="mobile-page">
        <AppPageHeader
          kicker="Business Studio"
          title="Menaxho produktet, porosite dhe promocionet nga telefoni."
          subtitle="I njejti backend i biznesit, por i organizuar ne seksione te qarta per mobile."
          back-to="/tabs/account"
        />

        <EmptyStatePanel
          v-if="!sessionState.user"
          title="Kyçu si biznes"
          copy="Business Studio aktivizohet kur hyn me llogari biznesi."
        >
          <IonButton class="cta-button" style="margin-top: 14px;" @click="router.push('/login?redirect=/business/studio')">
            Login
          </IonButton>
        </EmptyStatePanel>

        <EmptyStatePanel
          v-else-if="!canAccess"
          title="Ky ekran eshte vetem per bizneset"
          copy="Per administrim te users dhe bizneseve, perdor panelin admin."
        >
          <IonButton class="ghost-button" style="margin-top: 14px;" @click="router.push('/admin/control')">
            Hap Admin panel
          </IonButton>
        </EmptyStatePanel>

        <template v-else>
          <section class="surface-card surface-card--strong section-card">
            <div class="section-head">
              <div>
                <p class="section-kicker">Profili</p>
                <h2>{{ businessProfile?.businessName || sessionState.user?.businessName || "Business Studio" }}</h2>
                <p class="section-copy">
                  {{ businessProfile?.businessDescription || "Menaxho katalogun, porosite dhe komunikimin pa kaluar ne desktop." }}
                </p>
              </div>
              <span class="meta-pill">{{ businessProfile?.verificationStatus || "locked" }}</span>
            </div>

            <div class="mini-stat-grid" style="margin-top: 16px;">
              <article v-for="item in summaryCards" :key="item.label" class="mini-stat">
                <IonIcon :icon="item.icon" />
                <strong>{{ item.value }}</strong>
                <span>{{ item.label }}</span>
              </article>
            </div>
          </section>

          <section class="studio-quick-actions-grid">
            <button
              v-for="item in studioQuickActions"
              :key="item.key"
              class="studio-quick-action-card"
              type="button"
              @click="handleStudioAction(item)"
            >
              <IonIcon :icon="item.icon" />
              <div>
                <strong>{{ item.title }}</strong>
                <span>{{ item.copy }}</span>
              </div>
            </button>
          </section>

          <section v-if="studioFocusCards.length > 0" class="studio-focus-grid">
            <button
              v-for="item in studioFocusCards"
              :key="item.key"
              class="studio-focus-card"
              type="button"
              @click="item.key === 'verify' ? handleRequestVerification() : handleStudioAction(item)"
            >
              <p class="section-kicker">Next step</p>
              <strong>{{ item.title }}</strong>
              <span>{{ item.copy }}</span>
            </button>
          </section>

          <section class="chip-row">
            <button class="chip" :class="{ 'chip--active': activeSection === 'catalog' }" type="button" @click="activeSection = 'catalog'">Katalogu</button>
            <button class="chip" :class="{ 'chip--active': activeSection === 'orders' }" type="button" @click="activeSection = 'orders'">Porosite</button>
            <button class="chip" :class="{ 'chip--active': activeSection === 'promotions' }" type="button" @click="activeSection = 'promotions'">Promocione</button>
            <button class="chip" :class="{ 'chip--active': activeSection === 'returns' }" type="button" @click="activeSection = 'returns'">Kthime</button>
            <button class="chip" :class="{ 'chip--active': activeSection === 'profile' }" type="button" @click="activeSection = 'profile'">Profili</button>
          </section>

          <p v-if="ui.message" class="checkout-message" :class="ui.type">{{ ui.message }}</p>

          <section v-if="loading" class="surface-card empty-panel">
            <p>Po ngarkohet studio-ja e biznesit...</p>
          </section>

          <template v-else-if="activeSection === 'catalog'">
            <section class="surface-card section-card stack-list product-studio-builder">
              <div class="section-head">
                <div>
                  <p class="section-kicker">Shto produkt</p>
                  <h2>{{ editingProductId ? "Perditeso artikullin" : "Krijo artikull te ri" }}</h2>
                  <p class="section-copy">Hapat jane ndare per mobile: detajet, cmimi, variantet, media dhe preview final.</p>
                </div>
                <IonButton class="ghost-button" @click="resetProductForm">Reset</IonButton>
              </div>

              <div v-if="!canManageCatalog" class="inline-alert">
                <IonIcon :icon="alertCircleOutline" />
                <span>Verifiko biznesin para se te shtosh ose importosh produkte.</span>
              </div>

              <div class="builder-step-row">
                <button
                  v-for="step in productFlowSteps"
                  :key="step.id"
                  class="builder-step-chip"
                  :class="{ 'is-active': productFlowStep === step.id, 'is-done': step.done }"
                  type="button"
                  @click="openProductFlowStep(step.id)"
                >
                  <strong>{{ step.label }}</strong>
                  <span>{{ step.caption }}</span>
                </button>
              </div>

              <section v-show="productFlowStep === 'details'" class="builder-panel">
                <div class="builder-panel-head">
                  <div>
                    <p class="section-kicker">1. Detajet baze</p>
                    <h3>Emri, kodi dhe pershkrimi</h3>
                  </div>
                </div>
                <div class="checkout-grid">
                  <label class="checkout-field"><span>SKU / Article</span><input v-model="productForm.articleNumber" class="promo-input" type="text" placeholder="ART-10025" /></label>
                  <label class="checkout-field"><span>Titulli</span><input v-model="productForm.title" class="promo-input" type="text" placeholder="Titulli i produktit" /></label>
                </div>
                <label class="checkout-field"><span>Pershkrimi</span><textarea v-model="productForm.description" class="mobile-textarea" rows="4" /></label>
                <div class="action-row builder-nav-row">
                  <IonButton class="ghost-button" @click="moveProductFlow(1)">Vazhdo te cmimi</IonButton>
                </div>
              </section>

              <section v-show="productFlowStep === 'pricing'" class="builder-panel">
                <div class="builder-panel-head">
                  <div>
                    <p class="section-kicker">2. Cmimi</p>
                    <h3>Regular price dhe sale</h3>
                  </div>
                </div>
                <div class="checkout-grid">
                  <label class="checkout-field"><span>Cmimi</span><input v-model="productForm.price" class="promo-input" type="number" min="0" step="0.01" placeholder="29.90" /></label>
                  <label class="checkout-field">
                    <span>Cmimi para zbritjes</span>
                    <input v-model="productForm.compareAtPrice" class="promo-input" type="number" min="0" step="0.01" placeholder="39.90" />
                  </label>
                </div>
                <label class="checkout-field">
                  <span>Zgjat deri</span>
                  <input v-model="productForm.saleEndsAt" class="promo-input" type="datetime-local" />
                </label>
                <p class="section-copy">{{ salePreview > 0 ? `Ky produkt do te shfaqet me zbritje rreth ${salePreview}%.` : "Per sale, vendos cmimin para zbritjes me te larte se cmimi aktual." }}</p>
                <div class="action-row builder-nav-row">
                  <IonButton class="ghost-button" @click="moveProductFlow(-1)">Kthehu</IonButton>
                  <IonButton class="ghost-button" @click="moveProductFlow(1)">Vazhdo te variantet</IonButton>
                </div>
              </section>

              <section v-show="productFlowStep === 'variants'" class="builder-panel">
                <div class="builder-panel-head">
                  <div>
                    <p class="section-kicker">3. Kategoria dhe variantet</p>
                    <h3>Ngjyra, madhesia, tipi dhe stoku</h3>
                    <p class="section-copy">Mund te japesh edhe cmim ose foto specifike per secilin variant qe product page te reagoje sakte kur useri zgjedh ngjyren ose madhesine.</p>
                  </div>
                  <div class="meta-pill-row">
                    <span class="meta-pill">{{ productVariantEntries.length }} variante</span>
                    <span class="meta-pill">{{ productStockTotal }} cope</span>
                  </div>
                </div>

                <ProductVariantConfiguratorMobile :form="productForm" />

                <div class="action-row builder-nav-row">
                  <IonButton class="ghost-button" @click="moveProductFlow(-1)">Kthehu</IonButton>
                  <IonButton class="ghost-button" @click="moveProductFlow(1)">Vazhdo te media</IonButton>
                </div>
              </section>

              <section v-show="productFlowStep === 'media'" class="builder-panel">
                <div class="builder-panel-head">
                  <div>
                    <p class="section-kicker">4. Media</p>
                    <h3>Cover dhe galeria</h3>
                  </div>
                </div>
                <label class="checkout-field">
                  <span>Foto e produktit</span>
                  <input type="file" accept="image/*" multiple @change="handleSelectedFilesChange" />
                </label>

                <div v-if="productPreviewImages.length > 0" class="builder-media-grid">
                  <figure v-for="image in productPreviewImages.slice(0, 4)" :key="image" class="builder-media-card">
                    <img :src="image" alt="Preview e medias se produktit" />
                  </figure>
                </div>
                <p v-else class="section-copy">Ngarko te pakten nje cover te produktit. Mund te shtosh edhe foto te tjera per me shume besim para blerjes.</p>

                <div class="action-row builder-nav-row">
                  <IonButton class="ghost-button" @click="moveProductFlow(-1)">Kthehu</IonButton>
                  <IonButton class="ghost-button" @click="moveProductFlow(1)">Preview final</IonButton>
                </div>
              </section>

              <section v-show="productFlowStep === 'review'" class="builder-panel">
                <div class="builder-panel-head">
                  <div>
                    <p class="section-kicker">5. Preview final</p>
                    <h3>Kontrolloje artikullin para ruajtjes</h3>
                  </div>
                </div>

                <article class="builder-review-card">
                  <div class="builder-review-cover">
                    <img v-if="productCoverPreview" :src="productCoverPreview" :alt="productForm.title || 'Preview i produktit'" />
                    <div v-else class="builder-review-empty">Pa cover</div>
                  </div>
                  <div class="builder-review-copy">
                    <p class="section-kicker">{{ productForm.category || "Kategoria e produktit" }}</p>
                    <h3>{{ productForm.title || "Titulli i produktit" }}</h3>
                    <p>{{ productForm.description || "Pershkrimi i produktit do te shfaqet ketu." }}</p>
                    <div class="meta-pill-row">
                      <span class="meta-pill">{{ Number(productForm.price || 0) > 0 ? formatPrice(Number(productForm.price || 0)) : "Vendos cmimin" }}</span>
                      <span v-if="Number(productForm.compareAtPrice || 0) > Number(productForm.price || 0)" class="meta-pill meta-pill--sale">
                        {{ formatPrice(Number(productForm.compareAtPrice || 0)) }} · -{{ salePreview }}%
                      </span>
                      <span class="meta-pill">{{ productStockTotal }} cope</span>
                    </div>
                  </div>
                </article>

                <div class="builder-checklist">
                  <article
                    v-for="item in productChecklist"
                    :key="item.key"
                    class="builder-checklist-item"
                    :class="{ 'is-done': item.done }"
                  >
                    <span class="builder-checklist-dot"></span>
                    <strong>{{ item.label }}</strong>
                    <small>{{ item.done ? "OK" : "Plotesoje para ruajtjes" }}</small>
                  </article>
                </div>

                <div class="action-row">
                  <IonButton class="ghost-button" @click="moveProductFlow(-1)">Kthehu</IonButton>
                  <IonButton class="cta-button" @click="handleSaveProduct">{{ editingProductId ? "Ruaje ndryshimet" : "Ruaje produktin" }}</IonButton>
                  <IonButton class="ghost-button" :href="createDownloadUrl('/api/business/products/import-template')" target="_blank">
                    <IonIcon slot="start" :icon="cloudDownloadOutline" />
                    Template
                  </IonButton>
                </div>
              </section>

              <div class="promo-row">
                <input type="file" accept=".csv,.xlsx" @change="importFile = (($event.target as HTMLInputElement).files || [])[0] || null" />
                <IonButton class="ghost-button" @click="handleImportProducts">Importo</IonButton>
              </div>
            </section>

            <section class="stack-list">
              <article v-for="product in products" :key="product.id" class="surface-card section-card stack-list">
                <ProductCardMobile :product="product" analytics-mode @open="(id) => router.push(`/product/${id}`)" />
                <div class="action-row">
                  <IonButton class="ghost-button" @click="hydrateProductForm(product)">Edito</IonButton>
                  <IonButton class="ghost-button" @click="handleToggleVisibility(product)">{{ product.isPublic ? "Hiqe nga publiku" : "Beje publike" }}</IonButton>
                  <IonButton class="ghost-button" @click="handleToggleStock(product)">{{ product.showStockPublic ? "Fshih stokun" : "Shfaq stokun" }}</IonButton>
                  <IonButton class="ghost-button danger-button" @click="handleDeleteProduct(product)">Fshije</IonButton>
                </div>
              </article>
            </section>
          </template>

          <template v-else-if="activeSection === 'orders'">
            <section class="stack-list">
              <article v-for="order in orders" :key="order.id" class="surface-card section-card stack-list">
                <div class="section-head">
                  <div>
                    <p class="section-kicker">Order #{{ order.id }}</p>
                    <h2>{{ order.customerName || "Klient" }}</h2>
                    <p class="section-copy">{{ order.customerEmail || "-" }}</p>
                  </div>
                  <span class="meta-pill">{{ formatOrderStatusBadgeLabel(order.fulfillmentStatus || order.status) }}</span>
                </div>

                <div class="meta-pill-row">
                  <span class="meta-pill">{{ formatDateLabel(order.createdAt) }}</span>
                  <span class="meta-pill">{{ formatPrice(order.totalAmount || order.totalPrice) }}</span>
                  <span class="meta-pill">{{ order.deliveryLabel || order.deliveryMethod || "standard" }}</span>
                </div>

                <div v-for="item in order.items || []" :key="item.id" class="mini-order-item">
                  <div class="section-head">
                    <div>
                      <strong>{{ item.title || item.productTitle || "Produkt" }}</strong>
                      <p class="section-copy">{{ item.fulfillmentStatus || "pending_confirmation" }}</p>
                    </div>
                    <span class="meta-pill">{{ formatPrice(item.totalPrice || item.price) }}</span>
                  </div>

                  <div class="order-timeline compact">
                    <div
                      v-for="step in buildFulfillmentTimeline(item)"
                      :key="`${item.id}-${step.key}`"
                      class="order-timeline-step"
                      :class="{ 'is-completed': step.isCompleted, 'is-current': step.isCurrent, 'is-delivered': step.isDelivered }"
                    >
                      <span class="order-timeline-dot" />
                      <div class="order-timeline-copy">
                        <strong>{{ step.label }}</strong>
                        <small v-if="step.meta">{{ step.meta }}</small>
                      </div>
                    </div>
                  </div>

                  <div class="checkout-grid">
                    <label class="checkout-field">
                      <span>Statusi</span>
                      <select v-model="draftForOrderItem(item).fulfillmentStatus" class="mobile-select">
                        <option value="confirmed">Confirmed</option>
                        <option value="packed">Packed</option>
                        <option value="shipped">Shipped</option>
                        <option value="delivered">Delivered</option>
                        <option value="cancelled">Cancelled</option>
                        <option value="returned">Returned</option>
                      </select>
                    </label>
                    <label class="checkout-field">
                      <span>Tracking code</span>
                      <input v-model="draftForOrderItem(item).trackingCode" class="promo-input" type="text" placeholder="TRK-2048" />
                    </label>
                  </div>

                  <label class="checkout-field">
                    <span>Tracking link</span>
                    <input v-model="draftForOrderItem(item).trackingUrl" class="promo-input" type="url" placeholder="https://..." />
                  </label>

                  <IonButton class="ghost-button" @click="handleUpdateOrderItem(item)">Ruaje statusin</IonButton>
                </div>
              </article>
            </section>
          </template>

          <template v-else-if="activeSection === 'promotions'">
            <section class="surface-card section-card stack-list">
              <div>
                <p class="section-kicker">Promo code</p>
                <h2>Krijo ose perditeso ofertat</h2>
              </div>

              <div class="checkout-grid">
                <label class="checkout-field"><span>Kodi</span><input v-model="promotionForm.code" class="promo-input" type="text" placeholder="TREGO10" /></label>
                <label class="checkout-field"><span>Titulli</span><input v-model="promotionForm.title" class="promo-input" type="text" placeholder="Spring campaign" /></label>
              </div>
              <label class="checkout-field"><span>Pershkrimi</span><textarea v-model="promotionForm.description" class="mobile-textarea" rows="3" /></label>
              <div class="checkout-grid">
                <label class="checkout-field">
                  <span>Lloji i zbritjes</span>
                  <select v-model="promotionForm.discountType" class="mobile-select">
                    <option value="percent">Percent</option>
                    <option value="fixed">Fixed</option>
                  </select>
                </label>
                <label class="checkout-field"><span>Vlera</span><input v-model="promotionForm.discountValue" class="promo-input" type="number" min="0" step="0.01" /></label>
              </div>
              <div class="checkout-grid">
                <label class="checkout-field"><span>Minimum subtotal</span><input v-model="promotionForm.minimumSubtotal" class="promo-input" type="number" min="0" step="0.01" /></label>
                <label class="checkout-field"><span>Limit total</span><input v-model="promotionForm.usageLimit" class="promo-input" type="number" min="0" step="1" /></label>
              </div>
              <IonButton class="cta-button" @click="handleSavePromotion">Ruaje promocionin</IonButton>
            </section>

            <section class="stack-list">
              <article v-for="promotion in promotions" :key="promotion.id || promotion.code" class="surface-card section-card stack-list">
                <div class="section-head">
                  <div>
                    <p class="section-kicker">Promo</p>
                    <h2>{{ promotion.code || "-" }}</h2>
                    <p class="section-copy">{{ promotion.title || promotion.description || "Pa pershkrim." }}</p>
                  </div>
                  <span class="meta-pill">{{ promotion.isActive ? "active" : "paused" }}</span>
                </div>
                <div class="meta-pill-row">
                  <span class="meta-pill">{{ promotion.discountType }} · {{ promotion.discountValue }}</span>
                  <span class="meta-pill">min {{ promotion.minimumSubtotal || 0 }}</span>
                  <span class="meta-pill">per user {{ promotion.perUserLimit || 1 }}</span>
                </div>
                <div class="action-row">
                  <IonButton class="ghost-button danger-button" @click="handleDeletePromotion(promotion)">Fshije</IonButton>
                </div>
              </article>
            </section>
          </template>

          <template v-else-if="activeSection === 'returns'">
            <section class="stack-list">
              <article v-for="request in returnRequests" :key="request.id" class="surface-card section-card stack-list">
                <div class="section-head">
                  <div>
                    <p class="section-kicker">Kthimi #{{ request.id }}</p>
                    <h2>{{ request.productTitle || "Produkt" }}</h2>
                    <p class="section-copy">{{ request.reason || "-" }}</p>
                  </div>
                  <span class="meta-pill">{{ request.status || "requested" }}</span>
                </div>
                <p class="section-copy">{{ request.details || "Pa detaje shtese." }}</p>
                <div class="action-row">
                  <IonButton class="ghost-button" @click="handleUpdateReturn(request, 'approved')">Aprovo</IonButton>
                  <IonButton class="ghost-button" @click="handleUpdateReturn(request, 'received')">Pranuar</IonButton>
                  <IonButton class="ghost-button" @click="handleUpdateReturn(request, 'refunded')">Refund</IonButton>
                  <IonButton class="ghost-button danger-button" @click="handleUpdateReturn(request, 'rejected')">Refuzo</IonButton>
                </div>
              </article>
            </section>
          </template>

          <template v-else>
            <section class="surface-card section-card stack-list">
              <div>
                <p class="section-kicker">Verifikimi</p>
                <h2>{{ businessProfile?.verificationStatus || "locked" }}</h2>
                <p class="section-copy">Kur biznesi verifikohet, katalogu, promocionet dhe importi hapen plotesisht edhe ne mobile.</p>
              </div>
              <div class="action-row">
                <IonButton class="ghost-button" @click="handleRequestVerification">Kerko verifikim</IonButton>
                <IonButton class="ghost-button" @click="handleRequestEditAccess">Kerko editim profili</IonButton>
              </div>
            </section>

            <section class="surface-card section-card stack-list">
              <div>
                <p class="section-kicker">Analytics</p>
                <h2>Pulse i biznesit</h2>
              </div>
              <div class="mini-stat-grid">
                <article class="mini-stat"><strong>{{ formatCount(businessAnalytics?.viewsCount || 0) }}</strong><span>views</span></article>
                <article class="mini-stat"><strong>{{ formatCount(businessAnalytics?.wishlistCount || 0) }}</strong><span>wishlist</span></article>
                <article class="mini-stat"><strong>{{ formatCount(businessAnalytics?.cartCount || 0) }}</strong><span>cart</span></article>
                <article class="mini-stat"><strong>{{ formatCount(businessAnalytics?.shareCount || 0) }}</strong><span>share</span></article>
              </div>
            </section>
          </template>
        </template>
      </div>
    </IonContent>
  </IonPage>
</template>

<style scoped>
.checkout-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 12px;
}

.checkout-field {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.checkout-field span {
  color: var(--trego-dark);
  font-size: 0.82rem;
  font-weight: 700;
}

.mobile-select,
.promo-input,
.mobile-textarea {
  width: 100%;
  border: 1px solid var(--trego-input-border);
  border-radius: 18px;
  background: var(--trego-input-bg);
  color: var(--trego-dark);
}

.mobile-select,
.promo-input {
  min-height: 48px;
  padding: 0 14px;
}

.mobile-textarea {
  padding: 12px 14px;
}

.chip--active {
  background: rgba(255, 106, 43, 0.14);
  border-color: rgba(255, 106, 43, 0.3);
}

.action-row {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
}

.danger-button {
  --color: var(--trego-danger);
}

.inline-alert {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  padding: 12px 14px;
  border-radius: 16px;
  background: rgba(255, 106, 43, 0.12);
  color: var(--trego-dark);
}

.studio-quick-actions-grid,
.studio-focus-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 10px;
}

.studio-quick-action-card,
.studio-focus-card {
  display: grid;
  gap: 8px;
  min-height: 94px;
  padding: 14px;
  border-radius: 22px;
  border: 1px solid var(--trego-input-border);
  background: var(--trego-surface);
  color: var(--trego-dark);
  text-align: left;
  box-shadow: var(--trego-shadow-soft);
}

.studio-quick-action-card {
  grid-template-columns: auto minmax(0, 1fr);
  align-items: start;
  gap: 12px;
}

.studio-quick-action-card ion-icon {
  margin-top: 2px;
  font-size: 1.18rem;
  color: var(--trego-accent);
}

.studio-quick-action-card div,
.studio-focus-card {
  align-content: start;
}

.studio-quick-action-card strong,
.studio-focus-card strong {
  font-size: 0.88rem;
}

.studio-quick-action-card span,
.studio-focus-card span {
  color: var(--trego-muted);
  font-size: 0.74rem;
  line-height: 1.45;
}

.mini-order-item {
  padding: 14px;
  border-radius: 20px;
  border: 1px solid var(--trego-input-border);
  background: var(--trego-interactive-bg);
}

.product-studio-builder {
  gap: 18px;
}

.builder-step-row {
  display: grid;
  grid-template-columns: repeat(5, minmax(0, 1fr));
  gap: 8px;
  overflow-x: auto;
}

.builder-step-chip {
  display: grid;
  gap: 4px;
  min-width: 108px;
  padding: 12px 13px;
  border-radius: 18px;
  border: 1px solid var(--trego-input-border);
  background: var(--trego-interactive-bg);
  color: var(--trego-dark);
  text-align: left;
  box-shadow: 0 12px 26px rgba(31, 41, 55, 0.06);
}

.builder-step-chip span {
  color: var(--trego-muted);
  font-size: 0.73rem;
}

.builder-step-chip.is-active {
  border-color: rgba(255, 106, 43, 0.34);
  background: rgba(255, 255, 255, 0.96);
}

.builder-step-chip.is-done strong {
  color: var(--trego-accent);
}

.builder-panel {
  display: grid;
  gap: 14px;
  padding: 16px;
  border-radius: 22px;
  border: 1px solid var(--trego-input-border);
  background: rgba(255, 255, 255, 0.86);
}

.builder-panel-head {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: 12px;
}

.builder-panel-head h3,
.builder-review-copy h3 {
  margin: 0;
  color: var(--trego-dark);
}

.builder-nav-row {
  justify-content: space-between;
}

.builder-media-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 10px;
}

.builder-media-card {
  margin: 0;
  aspect-ratio: 1 / 1;
  border-radius: 18px;
  overflow: hidden;
  background: var(--trego-shell-soft);
}

.builder-media-card img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
}

.builder-review-card {
  display: grid;
  gap: 14px;
  align-items: stretch;
}

.builder-review-cover {
  min-height: 180px;
  border-radius: 22px;
  overflow: hidden;
  background: var(--trego-shell-soft);
}

.builder-review-cover img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
}

.builder-review-empty {
  min-height: 180px;
  display: grid;
  place-items: center;
  color: var(--trego-muted);
  font-weight: 700;
}

.builder-review-copy {
  display: grid;
  gap: 10px;
}

.meta-pill--sale {
  color: #c2410c;
  background: rgba(255, 106, 43, 0.12);
}

.builder-checklist {
  display: grid;
  gap: 10px;
}

.builder-checklist-item {
  display: grid;
  grid-template-columns: 14px minmax(0, 1fr) auto;
  gap: 8px;
  align-items: center;
  padding: 12px 14px;
  border-radius: 16px;
  background: var(--trego-shell-soft);
}

.builder-checklist-item strong {
  color: var(--trego-dark);
  font-size: 0.88rem;
}

.builder-checklist-item small {
  color: var(--trego-muted);
  font-size: 0.72rem;
}

.builder-checklist-dot {
  width: 10px;
  height: 10px;
  border-radius: 999px;
  background: rgba(47, 52, 70, 0.18);
}

.builder-checklist-item.is-done .builder-checklist-dot {
  background: var(--trego-accent);
}

.order-timeline.compact {
  display: grid;
  gap: 10px;
}

.order-timeline-step {
  display: grid;
  grid-template-columns: 14px minmax(0, 1fr);
  gap: 8px;
  align-items: start;
  opacity: 0.65;
}

.order-timeline-step.is-completed,
.order-timeline-step.is-current,
.order-timeline-step.is-delivered {
  opacity: 1;
}

.order-timeline-dot {
  width: 10px;
  height: 10px;
  margin-top: 3px;
  border-radius: 999px;
  background: rgba(47, 52, 70, 0.14);
}

.order-timeline-step.is-completed .order-timeline-dot,
.order-timeline-step.is-current .order-timeline-dot,
.order-timeline-step.is-delivered .order-timeline-dot {
  background: var(--trego-accent);
}

.order-timeline-copy {
  display: grid;
  gap: 2px;
}

.order-timeline-copy strong {
  color: var(--trego-dark);
  font-size: 0.84rem;
}

.order-timeline-copy small {
  color: var(--trego-muted);
}

@media (max-width: 420px) {
  .checkout-grid {
    grid-template-columns: 1fr;
  }

  .studio-quick-actions-grid,
  .studio-focus-grid {
    grid-template-columns: 1fr;
  }

  .builder-step-row {
    grid-template-columns: repeat(5, minmax(108px, 1fr));
  }

  .builder-panel-head {
    flex-direction: column;
  }
}
</style>
