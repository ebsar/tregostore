<script setup>
import { computed, onBeforeUnmount, onMounted, reactive, ref } from "vue";
import { useRouter } from "vue-router";
import AdminUserCard from "../components/AdminUserCard.vue";
import ManagedProductCard from "../components/ManagedProductCard.vue";
import { requestJson, resolveApiMessage, uploadImages } from "../lib/api";
import {
  PRODUCT_COLOR_OPTIONS,
  PRODUCT_SECTION_OPTIONS,
  SECTION_PRODUCT_TYPE_OPTIONS,
  formatRoleLabel,
  getProductImageGallery,
  isClothingSection,
} from "../lib/shop";
import { appState, ensureSessionLoaded, markRouteReady } from "../stores/app-state";

const router = useRouter();
const products = ref([]);
const users = ref([]);
const selectedFiles = ref([]);
const previewUrls = ref([]);
const editingProduct = ref(null);

const productForm = reactive(createEmptyProductState());
const ui = reactive({
  accessNote: "Po kontrollohet aksesimi administrativ...",
  formMessage: "",
  formType: "",
  listMessage: "",
  listType: "",
  usersMessage: "",
  usersType: "",
});

const productTypeOptions = computed(() => SECTION_PRODUCT_TYPE_OPTIONS[productForm.category] || []);
const clothingSection = computed(() => isClothingSection(productForm.category));
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
    await Promise.all([loadProducts(), loadUsers()]);
  } finally {
    markRouteReady();
  }
});

onBeforeUnmount(() => {
  revokePreviewUrls();
});

function createEmptyProductState() {
  const defaultCategory = PRODUCT_SECTION_OPTIONS[0]?.value || "clothing-men";
  return {
    title: "",
    price: "",
    description: "",
    category: defaultCategory,
    productType: SECTION_PRODUCT_TYPE_OPTIONS[defaultCategory]?.[0]?.value || "",
    size: "",
    color: "",
    stockQuantity: "1",
    imageGallery: [],
  };
}

function revokePreviewUrls() {
  previewUrls.value.forEach((url) => URL.revokeObjectURL(url));
  previewUrls.value = [];
}

function syncProductType() {
  const options = SECTION_PRODUCT_TYPE_OPTIONS[productForm.category] || [];
  if (!options.some((option) => option.value === productForm.productType)) {
    productForm.productType = options[0]?.value || "";
  }

  if (!clothingSection.value) {
    productForm.size = "";
  }
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

function resetProductForm() {
  Object.assign(productForm, createEmptyProductState());
  editingProduct.value = null;
  selectedFiles.value = [];
  revokePreviewUrls();
  ui.formMessage = "";
  ui.formType = "";
}

function beginProductEdit(product) {
  editingProduct.value = product;
  productForm.title = String(product.title || "");
  productForm.price = String(product.price ?? "");
  productForm.description = String(product.description || "");
  productForm.category = String(product.category || PRODUCT_SECTION_OPTIONS[0]?.value || "clothing-men");
  productForm.productType = String(product.productType || "");
  productForm.size = String(product.size || "");
  productForm.color = String(product.color || "");
  productForm.stockQuantity = String(product.stockQuantity ?? 0);
  productForm.imageGallery = getProductImageGallery(product);
  selectedFiles.value = [];
  revokePreviewUrls();
  syncProductType();
  ui.formMessage = `Po editon artikullin "${product.title}".`;
  ui.formType = "success";
}

function handleFilesChange(event) {
  revokePreviewUrls();
  selectedFiles.value = Array.from(event.target.files || []);
  previewUrls.value = selectedFiles.value.map((file) => URL.createObjectURL(file));
}

async function submitProduct() {
  ui.formMessage = "";

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
    title: productForm.title.trim(),
    price: productForm.price,
    description: productForm.description.trim(),
    category: productForm.category,
    productType: productForm.productType,
    size: clothingSection.value ? productForm.size : "",
    color: productForm.color,
    stockQuantity: productForm.stockQuantity,
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

async function handleRestockProduct({ productId, quantity }) {
  const ok = await submitProductAction(
    "/api/products/restock",
    { productId, quantity },
    "Stoku u perditesua me sukses.",
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

    <div class="admin-products-layout">
      <section class="card admin-form-card">
        <h2>{{ editingProduct ? "Edito artikullin" : "Shto artikull te ri" }}</h2>
        <p class="section-text">
          Zgjidh seksionin sipas menus se faqes, pastaj kategorine e produktit. Madhesia shfaqet vetem per veshjet. Fotoja e pare do te dale si cover ne kartat e produktit.
        </p>
        <p v-if="editingProduct" class="admin-edit-state">
          Po editon nje artikull ekzistues. Nese nuk zgjedh foto te reja, ruhen fotot aktuale.
        </p>

        <form class="auth-form" @submit.prevent="submitProduct">
          <label class="field">
            <span>Titulli</span>
            <input v-model="productForm.title" type="text" placeholder="p.sh. Krem per kqent" required>
          </label>

          <label class="field">
            <span>Cmimi (€)</span>
            <input v-model="productForm.price" type="number" min="0.01" step="0.01" placeholder="p.sh. 13.99" required>
          </label>

          <label class="field">
            <span>Seksioni i faqes</span>
            <select v-model="productForm.category" required @change="syncProductType">
              <option
                v-for="option in PRODUCT_SECTION_OPTIONS"
                :key="option.value"
                :value="option.value"
              >
                {{ option.label }}
              </option>
            </select>
          </label>

          <label class="field">
            <span>Kategoria e produktit</span>
            <select v-model="productForm.productType" required>
              <option
                v-for="option in productTypeOptions"
                :key="option.value"
                :value="option.value"
              >
                {{ option.label }}
              </option>
            </select>
          </label>

          <div class="field-row">
            <label v-if="clothingSection" class="field">
              <span>Madhesia e produktit</span>
              <select v-model="productForm.size">
                <option value="">Pa madhesi</option>
                <option value="XS">XS</option>
                <option value="S">S</option>
                <option value="M">M</option>
                <option value="L">L</option>
                <option value="XL">XL</option>
              </select>
            </label>

            <label class="field">
              <span>Sasia ne stok</span>
              <input v-model="productForm.stockQuantity" type="number" min="0" step="1" required>
            </label>
          </div>

          <label class="field">
            <span>Ngjyra e produktit</span>
            <select v-model="productForm.color">
              <option
                v-for="option in PRODUCT_COLOR_OPTIONS"
                :key="option.value || 'empty'"
                :value="option.value"
              >
                {{ option.label }}
              </option>
            </select>
          </label>

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
            <button type="submit">{{ editingProduct ? "Ruaj ndryshimet" : "Ruaje artikullin" }}</button>
            <button v-if="editingProduct" class="button-secondary" type="button" @click="resetProductForm">Anulo editimin</button>
          </div>
        </form>

        <div class="form-message" :class="ui.formType" role="status" aria-live="polite">
          {{ ui.formMessage }}
        </div>
      </section>

      <section class="card admin-list-card">
        <div class="admin-list-header">
          <div>
            <p class="section-label">Artikujt</p>
            <h2>Lista aktuale e produkteve</h2>
          </div>
        </div>

        <div class="form-message" :class="ui.listType" role="status" aria-live="polite">
          {{ ui.listMessage }}
        </div>

        <div class="admin-products-list">
          <div v-if="products.length === 0" class="admin-empty-state">
            Ende nuk ka produkte ne sistem.
          </div>

          <ManagedProductCard
            v-for="product in products"
            :key="product.id"
            :product="product"
            @edit="beginProductEdit"
            @delete="handleDeleteProduct"
            @toggle-visibility="handleToggleVisibility"
            @toggle-stock-public="handleToggleStock"
            @restock="handleRestockProduct"
          />
        </div>
      </section>
    </div>

    <section class="card admin-users-card">
      <div class="admin-list-header">
        <div>
          <p class="section-label">Perdoruesit</p>
          <h2>Menaxho rolet e llogarive</h2>
        </div>
      </div>

      <p class="section-text">
        Cdo llogari e re krijohet si user normal. Nga kjo pjese mund te vendosesh kush behet admin, kush behet biznes, dhe kush kthehet prape ne user.
      </p>

      <div class="form-message" :class="ui.usersType" role="status" aria-live="polite">
        {{ ui.usersMessage }}
      </div>

      <div class="admin-users-list">
        <div v-if="users.length === 0" class="admin-empty-state">
          Nuk ka perdorues per t'u shfaqur.
        </div>

        <AdminUserCard
          v-for="user in users"
          :key="user.id"
          :user="user"
          :current-user-id="Number(appState.user?.id || 0)"
          @change-role="handleRoleChange"
          @delete="handleDeleteUser"
          @set-password="handleSetUserPassword"
        />
      </div>
    </section>
  </section>
</template>
