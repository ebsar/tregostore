<script setup>
import { computed, nextTick, onBeforeUnmount, onMounted, reactive, ref, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import CompactProductConfigurator from "../components/CompactProductConfigurator.vue";
import DashboardShell from "../components/dashboard/DashboardShell.vue";
import ManagedProductCard from "../components/ManagedProductCard.vue";
import { requestJson, requestProductAIDraft, resolveApiMessage, uploadImages } from "../lib/api";
import { getAdminDashboardNavItems } from "../lib/dashboard-ui";
import {
  buildVariantInventoryFromForm,
  createEmptyProductFormState,
  hydrateProductFormFromProduct,
  syncProductFormCatalogState,
} from "../lib/product-catalog";
import { formatCount, formatPrice, formatRoleLabel, getBusinessInitials, getProductImageGallery } from "../lib/shop";
import { appState, ensureSessionLoaded, markRouteReady } from "../stores/app-state";

const router = useRouter();
const route = useRoute();
const ADMIN_ADD_PRODUCT_PATH = "/admin-products";
const ADMIN_INVENTORY_PATH = "/admin-products/inventory";
const products = ref([]);
const users = ref([]);
const reports = ref([]);
const userSearchQuery = ref("");
const productSearchQuery = ref(readRouteSearchQuery(route.query.q));
const selectedFiles = ref([]);
const previewUrls = ref([]);
const editingProduct = ref(null);
const productFormCollapsed = ref(false);
const productTitleInput = ref(null);

const productForm = reactive(createEmptyProductFormState());
const ui = reactive({
  formMessage: "",
  formType: "",
  listMessage: "",
  listType: "",
  usersMessage: "",
  usersType: "",
  reportsMessage: "",
  reportsType: "",
  productAiBusy: false,
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
const productVariantEntries = computed(() => buildVariantInventoryFromForm(productForm));
const productMediaCount = computed(() => productPreviewItems.value.length);
const productStockTotal = computed(() =>
  productVariantEntries.value.reduce((total, entry) => total + Math.max(0, Number(entry.quantity || 0)), 0),
);
const productPriceValue = computed(() => Number(productForm.price || 0));
const productPricingReady = computed(() => Number.isFinite(productPriceValue.value) && productPriceValue.value > 0);
const productChecklist = computed(() => ([
  {
    key: "title",
    done: Boolean(String(productForm.title || "").trim() && String(productForm.description || "").trim()),
  },
  {
    key: "pricing",
    done: productPricingReady.value,
  },
  {
    key: "variants",
    done: productStockTotal.value > 0,
  },
  {
    key: "media",
    done: productMediaCount.value > 0,
  },
]));
const isInventoryView = computed(() => route.path === ADMIN_INVENTORY_PATH || route.path === "/admin-products/lista");
const isAddProductView = computed(() => !isInventoryView.value);
const activeAdminNavKey = computed(() => (isInventoryView.value ? "inventory" : "products"));
const adminSearchPlaceholder = computed(() => (isInventoryView.value ? "Search inventory" : "Search products"));

const filteredUsers = computed(() => {
  const normalizedQuery = String(userSearchQuery.value || "").trim().toLowerCase();
  const nextUsers = [...users.value];
  if (!normalizedQuery) {
    return nextUsers;
  }

  const scoreUserMatch = (user) => {
    const fullName = String(user.fullName || "").trim().toLowerCase();
    const email = String(user.email || "").trim().toLowerCase();
    const role = String(user.role || "").trim().toLowerCase();

    if (fullName.startsWith(normalizedQuery)) {
      return 0;
    }
    if (email.startsWith(normalizedQuery)) {
      return 1;
    }
    if (fullName.includes(normalizedQuery)) {
      return 2;
    }
    if (email.includes(normalizedQuery)) {
      return 3;
    }
    if (role.includes(normalizedQuery)) {
      return 4;
    }
    return 99;
  };

  return nextUsers
    .map((user) => ({ user, score: scoreUserMatch(user) }))
    .filter((entry) => entry.score < 99)
    .sort((left, right) =>
      left.score - right.score
      || String(left.user.fullName || "").localeCompare(String(right.user.fullName || ""))
    )
    .map((entry) => entry.user);
});

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
const businessUsersCount = computed(() =>
  users.value.filter((user) => String(user.role || "").trim().toLowerCase() === "business").length,
);
const openReportsCount = computed(() =>
  reports.value.filter((report) =>
    !["resolved", "dismissed"].includes(String(report.status || "").trim().toLowerCase()),
  ).length,
);
const publicProductsCount = computed(() => products.value.filter((product) => Boolean(product.isPublic)).length);
const inStockProductsCount = computed(() => products.value.filter((product) => Number(product.stockQuantity || 0) > 0).length);
const adminShellNavItems = computed(() => getAdminDashboardNavItems(appState.user));
const adminNotificationCount = computed(() => openReportsCount.value);
const adminAvatarLabel = computed(() => getBusinessInitials(appState.user?.fullName || "Admin"));

function handleAdminProductSearch() {
  productSearchQuery.value = String(productSearchQuery.value || "").trim();
  if (!isInventoryView.value) {
    router.push({
      path: ADMIN_INVENTORY_PATH,
      query: productSearchQuery.value ? { q: productSearchQuery.value } : {},
    });
    return;
  }
  syncRouteSearchQuery(productSearchQuery.value);
}

watch(
  () => route.query.q,
  (value) => {
    productSearchQuery.value = readRouteSearchQuery(value);
  },
);

onMounted(async () => {
  try {
    const user = await ensureSessionLoaded();
    if (!user) {
      router.replace("/login");
      return;
    }

    if (user.role !== "admin") {
      router.replace("/");
      return;
    }

    await Promise.all([loadProducts(), loadReports()]);
  } finally {
    markRouteReady();
  }
});

onBeforeUnmount(() => {
  revokePreviewUrls();
});

function revokePreviewUrls() {
  previewUrls.value.forEach((url) => URL.revokeObjectURL(url));
  previewUrls.value = [];
}

async function loadProducts() {
  const { response, data } = await requestJson("/api/admin/products");
  if (!response.ok || !data?.ok) {
    ui.listMessage = resolveApiMessage(data, "Lista e artikujve nuk u ngarkua.");
    ui.listType = "error";
    products.value = [];
    return;
  }

  ui.listMessage = "";
  ui.listType = "";
  products.value = Array.isArray(data.products) ? data.products : [];
}

function readRouteSearchQuery(value) {
  if (Array.isArray(value)) {
    return String(value[0] || "").trim();
  }

  return String(value || "").trim();
}

async function syncRouteSearchQuery(query) {
  const normalizedQuery = String(query || "").trim();
  if (readRouteSearchQuery(route.query.q) === normalizedQuery) {
    return;
  }

  await router.replace({
    path: route.path,
    query: {
      ...route.query,
      ...(normalizedQuery ? { q: normalizedQuery } : { q: undefined }),
    },
  });
}

async function loadUsers() {
  const { response, data } = await requestJson("/api/admin/users");
  if (!response.ok || !data?.ok) {
    ui.usersMessage = resolveApiMessage(data, "Perdoruesit nuk u ngarkuan.");
    ui.usersType = "error";
    users.value = [];
    return;
  }

  ui.usersMessage = "";
  ui.usersType = "";
  users.value = Array.isArray(data.users) ? data.users : [];
}

async function loadReports() {
  const { response, data } = await requestJson("/api/admin/reports");
  if (!response.ok || !data?.ok) {
    ui.reportsMessage = resolveApiMessage(data, "Raportimet nuk u ngarkuan.");
    ui.reportsType = "error";
    reports.value = [];
    return;
  }

  ui.reportsMessage = "";
  ui.reportsType = "";
  reports.value = Array.isArray(data.reports) ? data.reports : [];
}

function resetProductForm() {
  Object.assign(productForm, createEmptyProductFormState());
  productFormCollapsed.value = false;
  editingProduct.value = null;
  selectedFiles.value = [];
  revokePreviewUrls();
  ui.formMessage = "";
  ui.formType = "";
}

async function beginProductEdit(product) {
  editingProduct.value = product;
  hydrateProductFormFromProduct(productForm, {
    ...product,
    imageGallery: getProductImageGallery(product),
  });
  selectedFiles.value = [];
  revokePreviewUrls();
  syncProductFormCatalogState(productForm);
  productFormCollapsed.value = false;
  ui.formMessage = `Po editon artikullin "${product.title}".`;
  ui.formType = "success";
  if (isInventoryView.value) {
    await router.push({
      path: ADMIN_ADD_PRODUCT_PATH,
      query: productSearchQuery.value ? { q: productSearchQuery.value } : {},
    });
  }
  await nextTick();
  productTitleInput.value?.focus?.();
}

function changeProductQuantity(delta) {
  const currentQuantity = Math.max(0, Number.parseInt(String(productForm.simpleStockQuantity || "0"), 10) || 0);
  productForm.simpleStockQuantity = String(Math.max(0, currentQuantity + delta));
}

function toggleProductFormCollapsed() {
  productFormCollapsed.value = !productFormCollapsed.value;
}

async function openAdminInventoryView() {
  await router.push({
    path: ADMIN_INVENTORY_PATH,
    query: productSearchQuery.value ? { q: productSearchQuery.value } : {},
  });
}

async function openAdminAddProductView() {
  await router.push({
    path: ADMIN_ADD_PRODUCT_PATH,
    query: productSearchQuery.value ? { q: productSearchQuery.value } : {},
  });
}

function handleFilesChange(event) {
  revokePreviewUrls();
  selectedFiles.value = Array.from(event.target.files || []);
  previewUrls.value = selectedFiles.value.map((file) => URL.createObjectURL(file));
}

async function suggestProductWithAi() {
  ui.formMessage = "";
  ui.formType = "";
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
      ui.formMessage = result.message;
      ui.formType = "error";
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

    ui.formMessage = result.message;
    ui.formType = "success";
  } catch (error) {
    console.error(error);
    ui.formMessage = "AI draft nuk u pergatit. Provoje perseri.";
    ui.formType = "error";
  } finally {
    ui.productAiBusy = false;
  }
}

async function submitProduct() {
  ui.formMessage = "";
  await nextTick();
  syncProductFormCatalogState(productForm);

  if (!editingProduct.value && selectedFiles.value.length === 0) {
    ui.formMessage = "Zgjidh te pakten nje foto te produktit.";
    ui.formType = "error";
    return;
  }

  let imageGallery = [...productForm.imageGallery];
  if (selectedFiles.value.length > 0) {
    const uploadResult = await uploadImages(selectedFiles.value);
    if (!uploadResult.ok) {
      ui.formMessage = uploadResult.message;
      ui.formType = "error";
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
    ui.formMessage = resolveApiMessage(data, "Artikulli nuk u ruajt.");
    ui.formType = "error";
    return;
  }

  ui.formMessage = data.message || (editingProduct.value ? "Artikulli u perditesua me sukses." : "Artikulli u ruajt me sukses.");
  ui.formType = "success";
  resetProductForm();
  await loadProducts();
}

async function submitProductAction(url, payload, fallbackMessage, target = "list") {
  const { response, data } = await requestJson(url, {
    method: "POST",
    body: JSON.stringify(payload),
  });

  if (!response.ok || !data?.ok) {
    ui[`${target}Message`] = resolveApiMessage(data, fallbackMessage);
    ui[`${target}Type`] = "error";
    return false;
  }

  ui[`${target}Message`] = data.message || fallbackMessage;
  ui[`${target}Type`] = "success";
  return true;
}

async function handleDeleteProduct(product) {
  if (!window.confirm("A do ta fshish kete produkt?")) {
    return;
  }

  const ok = await submitProductAction(
    "/api/products/delete",
    { productId: product.id },
    "Produkti u fshi me sukses.",
  );
  if (ok) {
    await loadProducts();
  }
}

async function handleToggleVisibility(product) {
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
  const ok = await submitProductAction(
    "/api/products/public-stock",
    {
      productId: product.id,
      showStockPublic: !(product.showStockPublic && Number(product.stockQuantity) > 0),
    },
    "Shfaqja e stokut u perditesua.",
  );
  if (ok) {
    await loadProducts();
  }
}

async function handleRoleChange({ userId, role }) {
  const ok = await submitProductAction(
    "/api/admin/users/role",
    { userId, role },
    "Roli u perditesua.",
    "users",
  );
  if (ok) {
    await loadUsers();
  }
}

async function handleDeleteUser(user) {
  if (!window.confirm(`A do ta fshish user-in ${user.fullName}?`)) {
    return;
  }

  const ok = await submitProductAction(
    "/api/admin/users/delete",
    { userId: user.id },
    "Perdoruesi u fshi me sukses.",
    "users",
  );
  if (ok) {
    await loadUsers();
  }
}

async function handleSetUserPassword({ userId, newPassword, reset }) {
  if (!String(newPassword || "").trim()) {
    ui.usersMessage = "Shkruaje nje fjalekalim te ri per user-in.";
    ui.usersType = "error";
    return;
  }

  const ok = await submitProductAction(
    "/api/admin/users/set-password",
    { userId, newPassword },
    "Fjalekalimi i perdoruesit u ndryshua me sukses.",
    "users",
  );
  if (ok && typeof reset === "function") {
    reset();
  }
}

async function handleReportStatus(report, status) {
  const { response, data } = await requestJson("/api/admin/reports/status", {
    method: "POST",
    body: JSON.stringify({
      reportId: report.id,
      status,
    }),
  });

  if (!response.ok || !data?.ok) {
    ui.reportsMessage = resolveApiMessage(data, "Raportimi nuk u perditesua.");
    ui.reportsType = "error";
    return;
  }

  ui.reportsMessage = data.message || "Raportimi u perditesua.";
  ui.reportsType = "success";
  await loadReports();
}
</script>

<template>
  <section class="market-page market-page--wide dashboard-page admin-dashboard-page" aria-label="Paneli admin i produkteve">
    <DashboardShell
      :nav-items="adminShellNavItems"
      :active-key="activeAdminNavKey"
      :brand-initial="adminAvatarLabel"
      brand-title="Tregio Admin"
      brand-subtitle="Marketplace control"
      :brand-image-path="appState.user?.profileImagePath || ''"
      brand-fallback-icon="users"
      :profile-image-path="appState.user?.profileImagePath || ''"
      profile-fallback-icon="users"
      :profile-name="appState.user?.fullName || 'Admin'"
      :profile-subtitle="appState.user ? formatRoleLabel(appState.user.role) : 'Checking access...'"
      :search-query="productSearchQuery"
      :search-placeholder="adminSearchPlaceholder"
      :notification-count="adminNotificationCount"
      @update:search-query="productSearchQuery = $event"
      @submit-search="handleAdminProductSearch"
    >
      <div class="dashboard-admin-grid dashboard-admin-grid--single">
        <section
          v-if="isAddProductView"
          class="market-card dashboard-section product-quick-create"
        >
          <div class="product-quick-create__header">
            <div>
              <h2>{{ editingProduct ? "Edit product" : "Add product" }}</h2>
              <p>{{ editingProduct ? "Update the product quickly from one compact card." : "Fast product setup for marketplace inventory." }}</p>
            </div>
            <div class="product-quick-create__header-actions">
              <button type="button" @click="openAdminInventoryView">
                Go to Inventory
              </button>
              <button
                type="button"
                class="product-quick-create__toggle"
                :aria-expanded="(!productFormCollapsed).toString()"
                @click="toggleProductFormCollapsed"
              >
                {{ productFormCollapsed ? "+" : "-" }}
              </button>
              <button type="button" @click="resetProductForm">
                {{ editingProduct ? "Cancel" : "Reset" }}
              </button>
            </div>
          </div>

          <div v-if="productFormCollapsed" class="product-quick-create__collapsed">
            <span>{{ productForm.title || "Add product" }}</span>
            <strong>{{ productPriceValue > 0 ? formatPrice(productPriceValue) : "Set price" }}</strong>
          </div>

          <form v-show="!productFormCollapsed" class="product-quick-form" @submit.prevent="submitProduct">
            <div class="product-quick-form__grid product-quick-form__grid--top">
              <div class="product-quick-form__field product-quick-form__field--quantity">
                <span class="product-quick-form__label">Stock</span>
                <div class="product-quick-form__stepper">
                  <button type="button" aria-label="Ule sasine" @click="changeProductQuantity(-1)">-</button>
                  <input
                    v-model="productForm.simpleStockQuantity"
                    type="number"
                    min="0"
                    step="1"
                    inputmode="numeric"
                    aria-label="Sasia e produktit"
                  >
                  <button type="button" aria-label="Rrite sasine" @click="changeProductQuantity(1)">+</button>
                </div>
              </div>

              <label class="product-quick-form__field product-quick-form__field--article">
                <span class="product-quick-form__label">Article / SKU</span>
                <input
                  v-model="productForm.articleNumber"
                  type="text"
                  inputmode="numeric"
                  placeholder="p.sh. 10025"
                >
              </label>

              <label class="product-quick-form__field product-quick-form__field--title">
                <span class="product-quick-form__label">Product title</span>
                <input
                  ref="productTitleInput"
                  v-model="productForm.title"
                  type="text"
                  placeholder="p.sh. White cotton t-shirt"
                  required
                >
              </label>

              <label class="product-quick-form__field product-quick-form__field--price">
                <span class="product-quick-form__label">Price</span>
                <div class="product-quick-form__price-control">
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
            </div>

            <CompactProductConfigurator :form="productForm" />

            <div class="product-quick-form__utility-grid">
              <label class="product-quick-form__upload">
                <span class="product-quick-form__label">Upload photo</span>
                <span class="product-quick-form__upload-drop">
                  <input
                    class="product-quick-form__upload-input"
                    type="file"
                    accept="image/*"
                    multiple
                    :required="!editingProduct && productMediaCount === 0"
                    @change="handleFilesChange"
                  >
                  <strong>Click to upload</strong>
                  <small>{{ editingProduct ? "New photos are optional while editing." : "Choose a cover photo and a few supporting images." }}</small>
                </span>
              </label>

              <div class="product-quick-form__preview" aria-live="polite">
                <span class="product-quick-form__label">Preview</span>
                <div v-if="productPreviewItems.length === 0" class="product-quick-form__preview-empty">
                  No photos added yet.
                </div>
                <div v-else class="product-quick-form__preview-list">
                  <figure
                    v-for="(item, index) in productPreviewItems.slice(0, 4)"
                    :key="`${item.path}-${index}`"
                    class="product-quick-form__preview-item"
                  >
                    <img :src="item.path" :alt="item.label">
                    <figcaption>{{ item.label }}</figcaption>
                  </figure>
                </div>
                <small v-if="productMediaCount > 4" class="product-quick-form__preview-note">
                  +{{ productMediaCount - 4 }} more images
                </small>
              </div>

              <label class="product-quick-form__field product-quick-form__field--description">
                <span class="product-quick-form__label">Description</span>
                <textarea
                  v-model="productForm.description"
                  rows="4"
                  placeholder="Write a short, clear product description."
                  required
                ></textarea>
              </label>
            </div>

            <div class="product-quick-form__footer">
              <div class="product-quick-form__summary">
                <span :class="{ 'is-ready': productChecklist[0]?.done }">Title ready</span>
                <span :class="{ 'is-ready': productChecklist[1]?.done }">Price ready</span>
                <span :class="{ 'is-ready': productChecklist[2]?.done }">Stock {{ formatCount(productStockTotal) }}</span>
                <span :class="{ 'is-ready': productChecklist[3]?.done }">Photos {{ productMediaCount }}</span>
              </div>

              <div class="product-quick-form__actions">
                <button type="button" class="market-button market-button--secondary" @click="resetProductForm">
                  {{ editingProduct ? "Cancel" : "Clear" }}
                </button>
                <button type="submit" class="market-button market-button--primary">
                  {{ editingProduct ? "Save changes" : "Save product" }}
                </button>
              </div>
            </div>
          </form>

          <div
            v-if="ui.formMessage"
            class="product-quick-form__feedback"
            :class="{
              'is-error': ui.formType === 'error',
              'is-success': ui.formType === 'success',
            }"
            role="status"
            aria-live="polite"
          >
            {{ ui.formMessage }}
          </div>
        </section>

        <section v-if="isInventoryView" class="market-card dashboard-section">
          <div class="dashboard-section__head">
            <div>
              <p class="market-page__eyebrow">Inventory</p>
              <h2>All products</h2>
              <p class="dashboard-note">
                {{ filteredProducts.length }} shown
                <template v-if="filteredProducts.length !== products.length">
                  • {{ products.length }} total
                </template>
              </p>
            </div>
            <div class="product-quick-form__actions">
              <button
                type="button"
                class="market-button market-button--secondary"
                @click="openAdminAddProductView"
              >
                Add product
              </button>
            </div>
          </div>

          <label class="dashboard-search" aria-label="Kerko produkt">
            <input
              v-model="productSearchQuery"
              type="search"
              placeholder="Kerko produkt me numer, emer, kategori..."
            >
          </label>

          <div
            v-if="ui.listMessage"
            class="market-status"
            :class="{ 'market-status--error': ui.listType === 'error', 'market-status--success': ui.listType === 'success' }"
            role="status"
            aria-live="polite"
          >
            {{ ui.listMessage }}
          </div>

          <div v-if="products.length === 0" class="market-empty">
            <h3>No products in system</h3>
            <p>Ende nuk ka produkte ne sistem.</p>
          </div>

          <div v-else-if="filteredProducts.length === 0" class="market-empty">
            <h3>No matching products</h3>
            <p>Nuk u gjet asnje produkt per kete kerkim.</p>
          </div>

          <div v-else class="dashboard-card-list">
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
      </div>
    </DashboardShell>
  </section>
</template>
