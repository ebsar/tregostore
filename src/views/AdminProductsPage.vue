<script setup>
import { computed, nextTick, onBeforeUnmount, onMounted, reactive, ref } from "vue";
import { useRouter } from "vue-router";
import AdminUserCard from "../components/AdminUserCard.vue";
import ManagedProductCard from "../components/ManagedProductCard.vue";
import ProductVariantConfigurator from "../components/ProductVariantConfigurator.vue";
import { requestJson, requestProductAIDraft, resolveApiMessage, uploadImages } from "../lib/api";
import {
  buildVariantInventoryFromForm,
  createEmptyProductFormState,
  hydrateProductFormFromProduct,
  syncProductFormCatalogState,
} from "../lib/product-catalog";
import { formatCount, formatDateLabel, formatRoleLabel, getProductImageGallery } from "../lib/shop";
import { appState, ensureSessionLoaded, markRouteReady } from "../stores/app-state";

const router = useRouter();
const products = ref([]);
const users = ref([]);
const reports = ref([]);
const userSearchQuery = ref("");
const productSearchQuery = ref("");
const selectedFiles = ref([]);
const previewUrls = ref([]);
const editingProduct = ref(null);

const productForm = reactive(createEmptyProductFormState());
const ui = reactive({
  accessNote: "Po kontrollohet aksesimi administrativ...",
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
const adminEngagementSummary = computed(() => {
  const totals = products.value.reduce((accumulator, product) => {
    accumulator.viewsCount += Number(product.viewsCount || 0);
    accumulator.wishlistCount += Number(product.wishlistCount || 0);
    accumulator.cartCount += Number(product.cartCount || 0);
    accumulator.shareCount += Number(product.shareCount || 0);
    return accumulator;
  }, {
    viewsCount: 0,
    wishlistCount: 0,
    cartCount: 0,
    shareCount: 0,
  });

  return [
    { label: "Views", value: formatCount(totals.viewsCount) },
    { label: "Wishlist", value: formatCount(totals.wishlistCount) },
    { label: "Cart", value: formatCount(totals.cartCount) },
    { label: "Share", value: formatCount(totals.shareCount) },
  ];
});

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

    ui.accessNote = "Je kyçur si admin. Ketu mund t'i menaxhosh artikujt dhe rolet.";
    await Promise.all([loadProducts(), loadUsers(), loadReports()]);
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
  editingProduct.value = null;
  selectedFiles.value = [];
  revokePreviewUrls();
  ui.formMessage = "";
  ui.formType = "";
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
  ui.formMessage = `Po editon artikullin "${product.title}".`;
  ui.formType = "success";
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
  <section class="admin-products-page" aria-label="Paneli admin i produkteve">
    <header class="admin-products-header">
      <div>
        <p class="section-label">Paneli admin</p>
        <h1>Menaxho artikujt</h1>
        <p class="admin-products-intro">
          Shto artikuj te rinj dhe ata do te dalin automatikisht ne seksionin perkates te faqes sipas menus se navigimit.
        </p>
      </div>
      <div class="admin-user-chip">
        <span>Sesioni aktiv</span>
        <strong>{{ appState.user ? `${appState.user.fullName} • ${formatRoleLabel(appState.user.role)}` : "Duke u kontrolluar..." }}</strong>
      </div>
    </header>

    <p class="admin-access-note">{{ ui.accessNote }}</p>

    <section v-if="products.length > 0" class="business-dashboard-analytics-grid" aria-label="Engagement i produkteve">
      <article
        v-for="item in adminEngagementSummary"
        :key="`admin-engagement-${item.label}`"
        class="summary-chip"
      >
        <span>{{ item.label }}</span>
        <strong>{{ item.value }}</strong>
      </article>
    </section>

    <div class="admin-products-shell">
      <section class="card admin-form-card admin-form-card-compact">
        <h2>{{ editingProduct ? "Edito artikullin" : "Shto artikull te ri" }}</h2>
        <p class="section-text admin-compact-copy">
          Zgjidh seksionin dhe ruaje artikullin me format me kompakte.
        </p>
        <p v-if="editingProduct" class="admin-edit-state">
          Po editon nje artikull ekzistues. Nese nuk zgjedh foto te reja, ruhen fotot aktuale.
        </p>

        <form class="auth-form admin-form-compact" @submit.prevent="submitProduct">
          <div class="admin-form-row admin-form-row-primary">
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
            <input v-model="productForm.title" type="text" placeholder="p.sh. Krem per kqent" required>
            </label>

            <label class="field">
            <span>Cmimi (€)</span>
            <input v-model="productForm.price" type="number" min="0.01" step="0.01" placeholder="p.sh. 13.99" required>
            </label>
          </div>

          <ProductVariantConfigurator :form="productForm" />

          <label class="field">
            <span>Upload photo</span>
            <input type="file" accept="image/*" multiple :required="!editingProduct" @change="handleFilesChange">
          </label>

          <p class="product-upload-help">
            Mund te zgjedhesh disa foto njeheresh. Te faqja e produktit ato shfaqen me butonin `Next`.
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

        <div class="form-message" :class="ui.formType" role="status" aria-live="polite">
          {{ ui.formMessage }}
        </div>
      </section>

      <section class="card admin-list-card admin-list-card-products">
        <div class="admin-list-header">
          <div>
            <p class="section-label">Artikujt</p>
            <h2>Lista aktuale e produkteve</h2>
            <p class="admin-compact-copy">{{ filteredProducts.length }} / {{ products.length }} artikuj</p>
          </div>
        </div>

        <label class="admin-compact-search" aria-label="Kerko produkt">
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
            Ende nuk ka produkte ne sistem.
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
    </div>

    <section class="card admin-users-card">
      <div class="admin-list-header">
        <div>
          <p class="section-label">Perdoruesit</p>
          <h2>Menaxho rolet e llogarive</h2>
          <p class="admin-compact-copy">{{ filteredUsers.length }} rezultate</p>
        </div>
      </div>

      <label class="admin-compact-search" aria-label="Kerko user">
        <svg class="admin-compact-search-icon" viewBox="0 0 24 24" aria-hidden="true">
          <circle cx="11" cy="11" r="7"></circle>
          <path d="m20 20-3.5-3.5"></path>
        </svg>
        <input
          v-model="userSearchQuery"
          type="search"
          placeholder="Kerko user me emer, email ose rol..."
        >
      </label>

      <div class="form-message" :class="ui.usersType" role="status" aria-live="polite">
        {{ ui.usersMessage }}
      </div>

      <div class="admin-users-list admin-users-list-scroll">
        <div v-if="users.length === 0" class="admin-empty-state">
          Nuk ka perdorues per t'u shfaqur.
        </div>

        <div v-else-if="filteredUsers.length === 0" class="admin-empty-state">
          Nuk u gjet asnje user per kete kerkim.
        </div>

        <AdminUserCard
          v-for="user in filteredUsers"
          :key="user.id"
          :user="user"
          :current-user-id="Number(appState.user?.id || 0)"
          @change-role="handleRoleChange"
          @delete="handleDeleteUser"
          @set-password="handleSetUserPassword"
        />
      </div>
    </section>

    <section class="card admin-users-card">
      <div class="admin-list-header">
        <div>
          <p class="section-label">Raportimet</p>
          <h2>Moderimi i marketplace-it</h2>
          <p class="admin-compact-copy">{{ reports.length }} raportime</p>
        </div>
      </div>

      <div class="form-message" :class="ui.reportsType" role="status" aria-live="polite">
        {{ ui.reportsMessage }}
      </div>

      <div class="admin-users-list admin-users-list-scroll">
        <div v-if="reports.length === 0" class="admin-empty-state">
          Nuk ka raportime aktive.
        </div>

        <article v-for="report in reports" :key="report.id" class="card account-section notification-card">
          <div class="notification-card-head">
            <div>
              <p class="section-label">{{ report.targetType }} • {{ formatDateLabel(report.createdAt) }}</p>
              <h2>{{ report.targetLabel || "Raportim" }}</h2>
            </div>
            <strong>{{ report.status }}</strong>
          </div>
          <p class="section-text"><strong>Arsye:</strong> {{ report.reason }}</p>
          <p v-if="report.details" class="section-text">{{ report.details }}</p>
          <div class="auth-form-actions">
            <button class="button-secondary" type="button" @click="handleReportStatus(report, 'reviewing')">Ne shqyrtim</button>
            <button type="button" @click="handleReportStatus(report, 'resolved')">Zgjidhe</button>
            <button class="button-secondary" type="button" @click="handleReportStatus(report, 'dismissed')">Mbylle</button>
          </div>
        </article>
      </div>
    </section>
  </section>
</template>
