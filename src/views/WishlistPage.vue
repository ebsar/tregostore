<script setup>
import { computed, onMounted, reactive, ref } from "vue";
import { RouterLink } from "vue-router";
import { useRouter } from "vue-router";
import SavedProductCard from "../components/SavedProductCard.vue";
import { requestJson, resolveApiMessage } from "../lib/api";
import { getProductDetailUrl } from "../lib/shop";
import { appState, ensureSessionLoaded, markRouteReady, setCartItems } from "../stores/app-state";

const router = useRouter();
const items = ref([]);
const selectedIds = ref([]);
const selectionInitialized = ref(false);
const ui = reactive({
  message: "",
  type: "",
  guest: false,
});

const selectionEnabled = computed(() => items.value.length > 2);
const selectedItems = computed(() => {
  if (!selectionEnabled.value) {
    return [...items.value];
  }

  return items.value.filter((item) => selectedIds.value.includes(item.id));
});

const allSelected = computed(() =>
  items.value.length > 0 && selectedItems.value.length === items.value.length,
);

const isIndeterminate = computed(
  () => selectedItems.value.length > 0 && selectedItems.value.length < items.value.length,
);

onMounted(async () => {
  try {
    const user = await ensureSessionLoaded();
    if (!user) {
      ui.guest = true;
      ui.message = "Per te perdorur wishlist duhet te kyçesh ose te krijosh llogari.";
      ui.type = "error";
      return;
    }

    await loadItems();
  } finally {
    markRouteReady();
  }
});

async function loadItems() {
  const { response, data } = await requestJson("/api/wishlist");
  if (!response.ok || !data?.ok) {
    ui.message = resolveApiMessage(data, "Lista nuk u ngarkua.");
    ui.type = "error";
    items.value = [];
    return;
  }

  items.value = Array.isArray(data.items) ? data.items : [];
  syncSelectionState();
  ui.message = "";
  ui.type = "";
}

function syncSelectionState() {
  const availableIds = new Set(items.value.map((item) => item.id));

  if (!selectionEnabled.value) {
    selectedIds.value = items.value.map((item) => item.id);
    selectionInitialized.value = false;
    return;
  }

  if (!selectionInitialized.value) {
    selectedIds.value = items.value.map((item) => item.id);
    selectionInitialized.value = true;
    return;
  }

  selectedIds.value = selectedIds.value.filter((id) => availableIds.has(id));
}

function toggleItem(productId) {
  if (!selectionEnabled.value) {
    return;
  }

  selectedIds.value = selectedIds.value.includes(productId)
    ? selectedIds.value.filter((id) => id !== productId)
    : [...selectedIds.value, productId];
}

function toggleAll(event) {
  if (!selectionEnabled.value) {
    return;
  }

  selectedIds.value = event.target.checked ? items.value.map((item) => item.id) : [];
}

async function removeItem(productId) {
  const { response, data } = await requestJson("/api/wishlist/toggle", {
    method: "POST",
    body: JSON.stringify({ productId }),
  });

  if (!response.ok || !data?.ok) {
    ui.message = resolveApiMessage(data, "Nuk u perditesua lista.");
    ui.type = "error";
    return;
  }

  ui.message = data.message || "Lista u perditesua.";
  ui.type = "success";
  await loadItems();
}

async function addToCart(productId) {
  const product = items.value.find((item) => Number(item.id) === Number(productId));
  if (product?.requiresVariantSelection) {
    router.push(getProductDetailUrl(productId, "/wishlist"));
    return;
  }

  const { response, data } = await requestJson("/api/cart/add", {
    method: "POST",
    body: JSON.stringify({ productId }),
  });

  if (!response.ok || !data?.ok) {
    ui.message = resolveApiMessage(data, "Shporta nuk u perditesua.");
    ui.type = "error";
    return;
  }

  setCartItems(Array.isArray(data.items) ? data.items : []);
  ui.message = data.message || "Produkti u shtua ne shporte.";
  ui.type = "success";
  await loadItems();
}

async function bulkAddToCart() {
  if (selectedItems.value.length === 0) {
    ui.message = "Zgjidh te pakten nje produkt per te vazhduar me blerje.";
    ui.type = "error";
    return;
  }

  let lastItems = [];

  for (const item of selectedItems.value) {
    if (item?.requiresVariantSelection) {
      ui.message = "Per produktet me variante, zgjidhe ngjyren ose madhesine nga faqja e produktit.";
      ui.type = "error";
      return;
    }

    const { response, data } = await requestJson("/api/cart/add", {
      method: "POST",
      body: JSON.stringify({ productId: item.id }),
    });

    if (!response.ok || !data?.ok) {
      ui.message = resolveApiMessage(data, "Shporta nuk u perditesua.");
      ui.type = "error";
      return;
    }

    lastItems = Array.isArray(data.items) ? data.items : lastItems;
  }

  setCartItems(lastItems);
  router.push("/cart");
}
</script>

<template>
  <section class="collection-page" aria-label="Wishlist products">
    <header class="collection-page-header">
      <p class="section-label">Wishlist</p>
      <h1>Produktet e ruajtura</h1>
      <p>
        Ketu shfaqen produktet qe i ruan me zemren nga kartat e produkteve. Duhet te jesh i kyçur qe t'i perdorësh.
      </p>
    </header>

    <div class="form-message" :class="ui.type" role="status" aria-live="polite">
      {{ ui.message }}
    </div>

    <div v-if="ui.guest" class="collection-empty-state collection-guest-gate">
      <h2>Per te perdorur wishlist duhet te kyçesh.</h2>
      <p>Krijo llogari ose hyni ne llogarine tende per te ruajtur produktet e preferuara dhe per t'i gjetur me vone.</p>
      <div class="collection-guest-gate-actions">
        <RouterLink class="nav-action nav-action-secondary" to="/login?redirect=%2Fwishlist">
          Login
        </RouterLink>
        <RouterLink class="nav-action nav-action-primary" to="/signup?redirect=%2Fwishlist">
          Sign Up
        </RouterLink>
      </div>
    </div>

    <div v-else-if="selectionEnabled" class="saved-products-toolbar">
      <div class="saved-products-toolbar-left">
        <label class="saved-products-select-all" for="wishlist-select-all">
          <input
            id="wishlist-select-all"
            type="checkbox"
            :checked="allSelected"
            :indeterminate.prop="isIndeterminate"
            @change="toggleAll"
          >
          <span>Zgjidh produktet per blerje</span>
        </label>
        <span class="saved-products-selected-count">
          {{ selectedItems.length }} produkte te zgjedhura
        </span>
      </div>
      <button
        class="product-action-button cart-action saved-products-toolbar-button"
        type="button"
        :disabled="selectedItems.length === 0"
        @click="bulkAddToCart"
      >
        <span>Vazhdo me blerje</span>
      </button>
    </div>

    <section v-if="items.length > 0" class="saved-products-grid" aria-label="Wishlist grid">
      <SavedProductCard
        v-for="item in items"
        :key="item.id"
        :product="item"
        mode="wishlist"
        :selection-enabled="selectionEnabled"
        :selected="selectedIds.includes(item.id)"
        @toggle-select="toggleItem"
        @remove="removeItem"
        @add-to-cart="addToCart"
      />
    </section>

    <div v-else class="collection-empty-state">
      Wishlist-i yt eshte bosh. Shto produkte nga faqet e dyqanit dhe ruaji me zemren.
    </div>
  </section>
</template>
