<script setup>
import { computed, onBeforeUnmount, onMounted, reactive, ref } from "vue";
import { useRouter } from "vue-router";
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
const businessProfile = ref(null);
const products = ref([]);
const logoFile = ref(null);
const logoPreviewUrl = ref("");
const selectedFiles = ref([]);
const previewUrls = ref([]);
const editingProduct = ref(null);

const profileForm = reactive({
  businessName: "",
  businessDescription: "",
  businessNumber: "",
  phoneNumber: "",
  city: "",
  addressLine: "",
  businessLogoPath: "",
});

const productForm = reactive(createEmptyProductState());
const ui = reactive({
  accessNote: "Po kontrollohet aksesimi i biznesit...",
  profileMessage: "",
  profileType: "",
  productMessage: "",
  productTypeMessage: "",
  listMessage: "",
  listType: "",
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
const businessLogoPreview = computed(() => logoPreviewUrl.value || profileForm.businessLogoPath || "");

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

    ui.accessNote = "Je kyçur si biznes. Ketu mund ta regjistrosh biznesin dhe t'i menaxhosh vetem artikujt e tu.";
    await Promise.all([loadBusinessProfile(), loadProducts()]);
  } finally {
    markRouteReady();
  }
});

onBeforeUnmount(() => {
  revokeLogoPreview();
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

function syncProductType() {
  const options = SECTION_PRODUCT_TYPE_OPTIONS[productForm.category] || [];
  if (!options.some((option) => option.value === productForm.productType)) {
    productForm.productType = options[0]?.value || "";
  }

  if (!clothingSection.value) {
    productForm.size = "";
  }
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
  ui.profileMessage = data.message || "Biznesi u ruajt me sukses.";
  ui.profileType = "success";
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

function resetProductForm() {
  Object.assign(productForm, createEmptyProductState());
  editingProduct.value = null;
  selectedFiles.value = [];
  revokePreviewUrls();
  ui.productMessage = "";
  ui.productTypeMessage = "";
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
  ui.productMessage = `Po editon artikullin "${product.title}".`;
  ui.productTypeMessage = "success";
}

function handleFilesChange(event) {
  revokePreviewUrls();
  selectedFiles.value = Array.from(event.target.files || []);
  previewUrls.value = selectedFiles.value.map((file) => URL.createObjectURL(file));
}

async function submitProduct() {
  ui.productMessage = "";

  if (!businessProfile.value) {
    ui.productMessage = "Regjistroje fillimisht biznesin para se te shtosh artikuj.";
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
    ui.productMessage = resolveApiMessage(data, "Artikulli nuk u ruajt.");
    ui.productTypeMessage = "error";
    return;
  }

  ui.productMessage = data.message || (editingProduct.value ? "Artikulli u perditesua me sukses." : "Artikulli u ruajt me sukses.");
  ui.productTypeMessage = "success";
  resetProductForm();
  await loadProducts();
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
  if (!window.confirm("A do ta fshish kete produkt?")) {
    return;
  }
  const ok = await submitProductAction("/api/products/delete", { productId: product.id }, "Produkti u fshi me sukses.");
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
    { productId: product.id, showStockPublic: !(product.showStockPublic && Number(product.stockQuantity) > 0) },
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
</script>

<template>
  <section class="business-dashboard-page" aria-label="Biznesi juaj">
    <header class="admin-products-header">
      <div>
        <p class="section-label">Paneli i biznesit</p>
        <h1>Biznesi juaj</h1>
        <p class="admin-products-intro">
          Nga kjo faqe mund ta regjistrosh biznesin, te shtosh artikuj dhe te kontrollosh vetem artikujt qe i ke publikuar ti.
        </p>
      </div>
      <div class="admin-user-chip">
        <span>Sesioni aktiv</span>
        <strong>{{ appState.user ? `${appState.user.fullName} • ${formatRoleLabel(appState.user.role)}` : "Duke u kontrolluar..." }}</strong>
      </div>
    </header>

    <p class="admin-access-note">{{ ui.accessNote }}</p>

    <div class="business-dashboard-layout">
      <section class="card business-profile-card">
        <h2>Regjistrimi i biznesit</h2>
        <p class="section-text">
          Ploteso te dhenat e biznesit. Pasi ta ruash, do te kesh akses per t'i shtuar dhe menaxhuar artikujt e biznesit tend.
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

          <button type="submit">Ruaje biznesin</button>
        </form>

        <div class="form-message" :class="ui.profileType" role="status" aria-live="polite">
          {{ ui.profileMessage }}
        </div>
      </section>

      <section v-if="businessProfile" class="card admin-form-card">
        <h2>{{ editingProduct ? "Edito artikullin" : "Shto artikull te ri" }}</h2>
        <p class="section-text">
          Artikujt qe shton ketu lidhen vetem me biznesin tend. Madhesia shfaqet vetem per veshjet.
        </p>
        <p v-if="editingProduct" class="admin-edit-state">
          Po editon nje artikull te biznesit tend. Nese nuk zgjedh foto te reja, ruhen fotot aktuale.
        </p>

        <form class="auth-form" @submit.prevent="submitProduct">
          <label class="field">
            <span>Titulli</span>
            <input v-model="productForm.title" type="text" placeholder="p.sh. Produkt i ri" required>
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
            <button type="submit">{{ editingProduct ? "Ruaj ndryshimet" : "Ruaje artikullin" }}</button>
            <button v-if="editingProduct" class="button-secondary" type="button" @click="resetProductForm">Anulo editimin</button>
          </div>
        </form>

        <div class="form-message" :class="ui.productTypeMessage" role="status" aria-live="polite">
          {{ ui.productMessage }}
        </div>
      </section>
    </div>

    <section class="card admin-list-card">
      <div class="admin-list-header">
        <div>
          <p class="section-label">Artikujt e biznesit tend</p>
          <h2>Lista e artikujve</h2>
        </div>
      </div>

      <div class="form-message" :class="ui.listType" role="status" aria-live="polite">
        {{ ui.listMessage }}
      </div>

      <div class="admin-products-list">
        <div v-if="products.length === 0" class="admin-empty-state">
          Ende nuk ke artikuj te publikuar nga ky biznes.
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
  </section>
</template>
