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
    <IonContent :fullscreen="true">
      <div>
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
          <IonButton @click="router.push('/login?redirect=/business/studio')">
            Login
          </IonButton>
        </EmptyStatePanel>

        <EmptyStatePanel
          v-else-if="!canAccess"
          title="Ky ekran eshte vetem per bizneset"
          copy="Per administrim te users dhe bizneseve, perdor panelin admin."
        >
          <IonButton @click="router.push('/admin/control')">
            Hap Admin panel
          </IonButton>
        </EmptyStatePanel>

        <template v-else>
          <section>
            <div>
              <div>
                <p>Profili</p>
                <h2>{{ businessProfile?.businessName || sessionState.user?.businessName || "Business Studio" }}</h2>
                <p>
                  {{ businessProfile?.businessDescription || "Menaxho katalogun, porosite dhe komunikimin pa kaluar ne desktop." }}
                </p>
              </div>
              <span>{{ businessProfile?.verificationStatus || "locked" }}</span>
            </div>

            <div>
              <article v-for="item in summaryCards" :key="item.label">
                <IonIcon :icon="item.icon" />
                <strong>{{ item.value }}</strong>
                <span>{{ item.label }}</span>
              </article>
            </div>
          </section>

          <section>
            <button
              v-for="item in studioQuickActions"
              :key="item.key"
             
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

          <section v-if="studioFocusCards.length > 0">
            <button
              v-for="item in studioFocusCards"
              :key="item.key"
             
              type="button"
              @click="item.key === 'verify' ? handleRequestVerification() : handleStudioAction(item)"
            >
              <p>Next step</p>
              <strong>{{ item.title }}</strong>
              <span>{{ item.copy }}</span>
            </button>
          </section>

          <section>
            <button type="button" @click="activeSection = 'catalog'">Katalogu</button>
            <button type="button" @click="activeSection = 'orders'">Porosite</button>
            <button type="button" @click="activeSection = 'promotions'">Promocione</button>
            <button type="button" @click="activeSection = 'returns'">Kthime</button>
            <button type="button" @click="activeSection = 'profile'">Profili</button>
          </section>

          <p v-if="ui.message">{{ ui.message }}</p>

          <section v-if="loading">
            <p>Po ngarkohet studio-ja e biznesit...</p>
          </section>

          <template v-else-if="activeSection === 'catalog'">
            <section>
              <div>
                <div>
                  <p>Shto produkt</p>
                  <h2>{{ editingProductId ? "Perditeso artikullin" : "Krijo artikull te ri" }}</h2>
                  <p>Hapat jane ndare per mobile: detajet, cmimi, variantet, media dhe preview final.</p>
                </div>
                <IonButton @click="resetProductForm">Reset</IonButton>
              </div>

              <div v-if="!canManageCatalog">
                <IonIcon :icon="alertCircleOutline" />
                <span>Verifiko biznesin para se te shtosh ose importosh produkte.</span>
              </div>

              <div>
                <button
                  v-for="step in productFlowSteps"
                  :key="step.id"
                 
                 
                  type="button"
                  @click="openProductFlowStep(step.id)"
                >
                  <strong>{{ step.label }}</strong>
                  <span>{{ step.caption }}</span>
                </button>
              </div>

              <section v-show="productFlowStep === 'details'">
                <div>
                  <div>
                    <p>1. Detajet baze</p>
                    <h3>Emri, kodi dhe pershkrimi</h3>
                  </div>
                </div>
                <div>
                  <label><span>SKU / Article</span><input v-model="productForm.articleNumber" type="text" placeholder="ART-10025" /></label>
                  <label><span>Titulli</span><input v-model="productForm.title" type="text" placeholder="Titulli i produktit" /></label>
                </div>
                <label><span>Pershkrimi</span><textarea v-model="productForm.description" rows="4" /></label>
                <div>
                  <IonButton @click="moveProductFlow(1)">Vazhdo te cmimi</IonButton>
                </div>
              </section>

              <section v-show="productFlowStep === 'pricing'">
                <div>
                  <div>
                    <p>2. Cmimi</p>
                    <h3>Regular price dhe sale</h3>
                  </div>
                </div>
                <div>
                  <label><span>Cmimi</span><input v-model="productForm.price" type="number" min="0" step="0.01" placeholder="29.90" /></label>
                  <label>
                    <span>Cmimi para zbritjes</span>
                    <input v-model="productForm.compareAtPrice" type="number" min="0" step="0.01" placeholder="39.90" />
                  </label>
                </div>
                <label>
                  <span>Zgjat deri</span>
                  <input v-model="productForm.saleEndsAt" type="datetime-local" />
                </label>
                <p>{{ salePreview > 0 ? `Ky produkt do te shfaqet me zbritje rreth ${salePreview}%.` : "Per sale, vendos cmimin para zbritjes me te larte se cmimi aktual." }}</p>
                <div>
                  <IonButton @click="moveProductFlow(-1)">Kthehu</IonButton>
                  <IonButton @click="moveProductFlow(1)">Vazhdo te variantet</IonButton>
                </div>
              </section>

              <section v-show="productFlowStep === 'variants'">
                <div>
                  <div>
                    <p>3. Kategoria dhe variantet</p>
                    <h3>Ngjyra, madhesia, tipi dhe stoku</h3>
                    <p>Mund te japesh edhe cmim ose foto specifike per secilin variant qe product page te reagoje sakte kur useri zgjedh ngjyren ose madhesine.</p>
                  </div>
                  <div>
                    <span>{{ productVariantEntries.length }} variante</span>
                    <span>{{ productStockTotal }} cope</span>
                  </div>
                </div>

                <ProductVariantConfiguratorMobile :form="productForm" />

                <div>
                  <IonButton @click="moveProductFlow(-1)">Kthehu</IonButton>
                  <IonButton @click="moveProductFlow(1)">Vazhdo te media</IonButton>
                </div>
              </section>

              <section v-show="productFlowStep === 'media'">
                <div>
                  <div>
                    <p>4. Media</p>
                    <h3>Cover dhe galeria</h3>
                  </div>
                </div>
                <label>
                  <span>Foto e produktit</span>
                  <input type="file" accept="image/*" multiple @change="handleSelectedFilesChange" />
                </label>

                <div v-if="productPreviewImages.length > 0">
                  <figure v-for="image in productPreviewImages.slice(0, 4)" :key="image">
                    <img :src="image" alt="Preview e medias se produktit" />
                  </figure>
                </div>
                <p v-else>Ngarko te pakten nje cover te produktit. Mund te shtosh edhe foto te tjera per me shume besim para blerjes.</p>

                <div>
                  <IonButton @click="moveProductFlow(-1)">Kthehu</IonButton>
                  <IonButton @click="moveProductFlow(1)">Preview final</IonButton>
                </div>
              </section>

              <section v-show="productFlowStep === 'review'">
                <div>
                  <div>
                    <p>5. Preview final</p>
                    <h3>Kontrolloje artikullin para ruajtjes</h3>
                  </div>
                </div>

                <article>
                  <div>
                    <img v-if="productCoverPreview" :src="productCoverPreview" :alt="productForm.title || 'Preview i produktit'" />
                    <div v-else>Pa cover</div>
                  </div>
                  <div>
                    <p>{{ productForm.category || "Kategoria e produktit" }}</p>
                    <h3>{{ productForm.title || "Titulli i produktit" }}</h3>
                    <p>{{ productForm.description || "Pershkrimi i produktit do te shfaqet ketu." }}</p>
                    <div>
                      <span>{{ Number(productForm.price || 0) > 0 ? formatPrice(Number(productForm.price || 0)) : "Vendos cmimin" }}</span>
                      <span v-if="Number(productForm.compareAtPrice || 0) > Number(productForm.price || 0)">
                        {{ formatPrice(Number(productForm.compareAtPrice || 0)) }} · -{{ salePreview }}%
                      </span>
                      <span>{{ productStockTotal }} cope</span>
                    </div>
                  </div>
                </article>

                <div>
                  <article
                    v-for="item in productChecklist"
                    :key="item.key"
                   
                   
                  >
                    <span></span>
                    <strong>{{ item.label }}</strong>
                    <small>{{ item.done ? "OK" : "Plotesoje para ruajtjes" }}</small>
                  </article>
                </div>

                <div>
                  <IonButton @click="moveProductFlow(-1)">Kthehu</IonButton>
                  <IonButton @click="handleSaveProduct">{{ editingProductId ? "Ruaje ndryshimet" : "Ruaje produktin" }}</IonButton>
                  <IonButton :href="createDownloadUrl('/api/business/products/import-template')" target="_blank">
                    <IonIcon slot="start" :icon="cloudDownloadOutline" />
                    Template
                  </IonButton>
                </div>
              </section>

              <div>
                <input type="file" accept=".csv,.xlsx" @change="importFile = (($event.target as HTMLInputElement).files || [])[0] || null" />
                <IonButton @click="handleImportProducts">Importo</IonButton>
              </div>
            </section>

            <section>
              <article v-for="product in products" :key="product.id">
                <ProductCardMobile :product="product" analytics-mode @open="(id) => router.push(`/product/${id}`)" />
                <div>
                  <IonButton @click="hydrateProductForm(product)">Edito</IonButton>
                  <IonButton @click="handleToggleVisibility(product)">{{ product.isPublic ? "Hiqe nga publiku" : "Beje publike" }}</IonButton>
                  <IonButton @click="handleToggleStock(product)">{{ product.showStockPublic ? "Fshih stokun" : "Shfaq stokun" }}</IonButton>
                  <IonButton @click="handleDeleteProduct(product)">Fshije</IonButton>
                </div>
              </article>
            </section>
          </template>

          <template v-else-if="activeSection === 'orders'">
            <section>
              <article v-for="order in orders" :key="order.id">
                <div>
                  <div>
                    <p>Order #{{ order.id }}</p>
                    <h2>{{ order.customerName || "Klient" }}</h2>
                    <p>{{ order.customerEmail || "-" }}</p>
                  </div>
                  <span>{{ formatOrderStatusBadgeLabel(order.fulfillmentStatus || order.status) }}</span>
                </div>

                <div>
                  <span>{{ formatDateLabel(order.createdAt) }}</span>
                  <span>{{ formatPrice(order.totalAmount || order.totalPrice) }}</span>
                  <span>{{ order.deliveryLabel || order.deliveryMethod || "standard" }}</span>
                </div>

                <div v-for="item in order.items || []" :key="item.id">
                  <div>
                    <div>
                      <strong>{{ item.title || item.productTitle || "Produkt" }}</strong>
                      <p>{{ item.fulfillmentStatus || "pending_confirmation" }}</p>
                    </div>
                    <span>{{ formatPrice(item.totalPrice || item.price) }}</span>
                  </div>

                  <div>
                    <div
                      v-for="step in buildFulfillmentTimeline(item)"
                      :key="`${item.id}-${step.key}`"
                     
                     
                    >
                      <span />
                      <div>
                        <strong>{{ step.label }}</strong>
                        <small v-if="step.meta">{{ step.meta }}</small>
                      </div>
                    </div>
                  </div>

                  <div>
                    <label>
                      <span>Statusi</span>
                      <select v-model="draftForOrderItem(item).fulfillmentStatus">
                        <option value="confirmed">Confirmed</option>
                        <option value="packed">Packed</option>
                        <option value="shipped">Shipped</option>
                        <option value="delivered">Delivered</option>
                        <option value="cancelled">Cancelled</option>
                        <option value="returned">Returned</option>
                      </select>
                    </label>
                    <label>
                      <span>Tracking code</span>
                      <input v-model="draftForOrderItem(item).trackingCode" type="text" placeholder="TRK-2048" />
                    </label>
                  </div>

                  <label>
                    <span>Tracking link</span>
                    <input v-model="draftForOrderItem(item).trackingUrl" type="url" placeholder="https://..." />
                  </label>

                  <IonButton @click="handleUpdateOrderItem(item)">Ruaje statusin</IonButton>
                </div>
              </article>
            </section>
          </template>

          <template v-else-if="activeSection === 'promotions'">
            <section>
              <div>
                <p>Promo code</p>
                <h2>Krijo ose perditeso ofertat</h2>
              </div>

              <div>
                <label><span>Kodi</span><input v-model="promotionForm.code" type="text" placeholder="TREGO10" /></label>
                <label><span>Titulli</span><input v-model="promotionForm.title" type="text" placeholder="Spring campaign" /></label>
              </div>
              <label><span>Pershkrimi</span><textarea v-model="promotionForm.description" rows="3" /></label>
              <div>
                <label>
                  <span>Lloji i zbritjes</span>
                  <select v-model="promotionForm.discountType">
                    <option value="percent">Percent</option>
                    <option value="fixed">Fixed</option>
                  </select>
                </label>
                <label><span>Vlera</span><input v-model="promotionForm.discountValue" type="number" min="0" step="0.01" /></label>
              </div>
              <div>
                <label><span>Minimum subtotal</span><input v-model="promotionForm.minimumSubtotal" type="number" min="0" step="0.01" /></label>
                <label><span>Limit total</span><input v-model="promotionForm.usageLimit" type="number" min="0" step="1" /></label>
              </div>
              <IonButton @click="handleSavePromotion">Ruaje promocionin</IonButton>
            </section>

            <section>
              <article v-for="promotion in promotions" :key="promotion.id || promotion.code">
                <div>
                  <div>
                    <p>Promo</p>
                    <h2>{{ promotion.code || "-" }}</h2>
                    <p>{{ promotion.title || promotion.description || "Pa pershkrim." }}</p>
                  </div>
                  <span>{{ promotion.isActive ? "active" : "paused" }}</span>
                </div>
                <div>
                  <span>{{ promotion.discountType }} · {{ promotion.discountValue }}</span>
                  <span>min {{ promotion.minimumSubtotal || 0 }}</span>
                  <span>per user {{ promotion.perUserLimit || 1 }}</span>
                </div>
                <div>
                  <IonButton @click="handleDeletePromotion(promotion)">Fshije</IonButton>
                </div>
              </article>
            </section>
          </template>

          <template v-else-if="activeSection === 'returns'">
            <section>
              <article v-for="request in returnRequests" :key="request.id">
                <div>
                  <div>
                    <p>Kthimi #{{ request.id }}</p>
                    <h2>{{ request.productTitle || "Produkt" }}</h2>
                    <p>{{ request.reason || "-" }}</p>
                  </div>
                  <span>{{ request.status || "requested" }}</span>
                </div>
                <p>{{ request.details || "Pa detaje shtese." }}</p>
                <div>
                  <IonButton @click="handleUpdateReturn(request, 'approved')">Aprovo</IonButton>
                  <IonButton @click="handleUpdateReturn(request, 'received')">Pranuar</IonButton>
                  <IonButton @click="handleUpdateReturn(request, 'refunded')">Refund</IonButton>
                  <IonButton @click="handleUpdateReturn(request, 'rejected')">Refuzo</IonButton>
                </div>
              </article>
            </section>
          </template>

          <template v-else>
            <section>
              <div>
                <p>Verifikimi</p>
                <h2>{{ businessProfile?.verificationStatus || "locked" }}</h2>
                <p>Kur biznesi verifikohet, katalogu, promocionet dhe importi hapen plotesisht edhe ne mobile.</p>
              </div>
              <div>
                <IonButton @click="handleRequestVerification">Kerko verifikim</IonButton>
                <IonButton @click="handleRequestEditAccess">Kerko editim profili</IonButton>
              </div>
            </section>

            <section>
              <div>
                <p>Analytics</p>
                <h2>Pulse i biznesit</h2>
              </div>
              <div>
                <article><strong>{{ formatCount(businessAnalytics?.viewsCount || 0) }}</strong><span>views</span></article>
                <article><strong>{{ formatCount(businessAnalytics?.wishlistCount || 0) }}</strong><span>wishlist</span></article>
                <article><strong>{{ formatCount(businessAnalytics?.cartCount || 0) }}</strong><span>cart</span></article>
                <article><strong>{{ formatCount(businessAnalytics?.shareCount || 0) }}</strong><span>share</span></article>
              </div>
            </section>
          </template>
        </template>
      </div>
    </IonContent>
  </IonPage>
</template>

