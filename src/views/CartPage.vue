<script setup>
import { computed, nextTick, onMounted, onUnmounted, reactive, ref } from "vue";
import { RouterLink } from "vue-router";
import { useRouter } from "vue-router";
import SavedProductCard from "../components/SavedProductCard.vue";
import { requestJson, resolveApiMessage } from "../lib/api";
import {
  clearSavedForLaterItems,
  formatPrice,
  persistCheckoutSelectedCartIds,
  readSavedForLaterItems,
  rememberSavedForLaterItem,
  removeSavedForLaterItem,
  getProductStockMessage,
  hasProductAvailableStock,
} from "../lib/shop";
import { appState, ensureSessionLoaded, markRouteReady, setCartItems } from "../stores/app-state";

const router = useRouter();
const productsPanel = ref(null);
const summaryCard = ref(null);
const items = ref([]);
const savedLaterItems = ref([]);
const selectedIds = ref([]);
const selectionInitialized = ref(false);
const ui = reactive({
  message: "",
  type: "",
  guest: false,
});

let resizeObserver = null;
let resizeFrame = 0;

const selectionEnabled = computed(() => items.value.length > 2);
const selectedItems = computed(() => {
  if (!selectionEnabled.value) {
    return [...items.value];
  }

  return items.value.filter((item) => selectedIds.value.includes(item.id));
});
const unavailableItems = computed(() => items.value.filter((item) => !hasProductAvailableStock(item)));
const selectedUnavailableItems = computed(() =>
  selectedItems.value.filter((item) => !hasProductAvailableStock(item)),
);

const totalItems = computed(() =>
  selectedItems.value.reduce((total, item) => total + Math.max(0, Number(item.quantity) || 0), 0),
);

const totalPrice = computed(() =>
  selectedItems.value.reduce(
    (total, item) => total + (Math.max(0, Number(item.quantity) || 0) * (Number(item.price) || 0)),
    0,
  ),
);

const savedLaterCount = computed(() => savedLaterItems.value.length);

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
      ui.message = "Per te perdorur shporten duhet te kyçesh ose te krijosh llogari.";
      ui.type = "error";
      return;
    }

    await loadItems();
    loadSavedLaterItems();
    setupHeightSync();
  } finally {
    markRouteReady();
  }
});

onUnmounted(() => {
  if (resizeObserver) {
    resizeObserver.disconnect();
  }
  if (resizeFrame) {
    window.cancelAnimationFrame(resizeFrame);
  }
  window.removeEventListener("resize", scheduleHeightSync);
});

async function loadItems() {
  const { response, data } = await requestJson("/api/cart");
  if (!response.ok || !data?.ok) {
    ui.message = resolveApiMessage(data, "Shporta nuk u ngarkua.");
    ui.type = "error";
    items.value = [];
    setCartItems([]);
    return;
  }

  items.value = Array.isArray(data.items) ? data.items : [];
  setCartItems(items.value);
  syncSelectionState();
  ui.message = "";
  ui.type = "";
  await nextTick();
  scheduleHeightSync();
}

function loadSavedLaterItems() {
  savedLaterItems.value = readSavedForLaterItems();
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
  const { response, data } = await requestJson("/api/cart/remove", {
    method: "POST",
    body: JSON.stringify({ productId }),
  });

  if (!response.ok || !data?.ok) {
    ui.message = resolveApiMessage(data, "Shporta nuk u perditesua.");
    ui.type = "error";
    return;
  }

  ui.message = data.message || "Shporta u perditesua.";
  ui.type = "success";
  await loadItems();
}

async function saveForLater(cartLine) {
  const currentItem =
    cartLine && typeof cartLine === "object"
      ? cartLine
      : items.value.find((item) => item.id === Number(cartLine));
  if (!currentItem) {
    return;
  }

  const { response, data } = await requestJson("/api/cart/remove", {
    method: "POST",
    body: JSON.stringify({ productId: currentItem.id }),
  });

  if (!response.ok || !data?.ok) {
    ui.message = resolveApiMessage(data, "Shporta nuk u perditesua.");
    ui.type = "error";
    return;
  }

  savedLaterItems.value = rememberSavedForLaterItem(currentItem);
  ui.message = "Artikulli u ruajt per me vone.";
  ui.type = "success";
  await loadItems();
}

async function increaseQuantity(productId) {
  const { response, data } = await requestJson("/api/cart/add", {
    method: "POST",
    body: JSON.stringify({ productId }),
  });

  if (!response.ok || !data?.ok) {
    ui.message = resolveApiMessage(data, "Shporta nuk u perditesua.");
    ui.type = "error";
    return;
  }

  ui.message = data.message || "Sasia u perditesua.";
  ui.type = "success";
  await loadItems();
}

async function decreaseQuantity(productId) {
  const currentItem = items.value.find((item) => item.id === productId);
  const currentQuantity = Number(currentItem?.quantity || 0);
  const nextQuantity = currentQuantity - 1;
  if (nextQuantity < 1) {
    return;
  }

  const { response, data } = await requestJson("/api/cart/quantity", {
    method: "POST",
    body: JSON.stringify({ productId, quantity: nextQuantity }),
  });

  if (!response.ok || !data?.ok) {
    ui.message = resolveApiMessage(data, "Shporta nuk u perditesua.");
    ui.type = "error";
    return;
  }

  ui.message = data.message || "Sasia u perditesua.";
  ui.type = "success";
  await loadItems();
}

async function restoreSavedLaterItem(savedItem) {
  const item =
    savedItem && typeof savedItem === "object"
      ? savedItem
      : savedLaterItems.value.find((entry) => entry.id === Number(savedItem));

  if (!item) {
    return;
  }

  if (!hasProductAvailableStock(item)) {
    ui.message = getProductStockMessage(item);
    ui.type = "error";
    return;
  }

  const { response, data } = await requestJson("/api/cart/add", {
    method: "POST",
    body: JSON.stringify({
      productId: item.productId || item.id,
      quantity: Math.max(1, Number(item.quantity) || 1),
      variantKey: item.variantKey || "",
      selectedSize: item.selectedSize || "",
      selectedColor: item.selectedColor || "",
    }),
  });

  if (!response.ok || !data?.ok) {
    ui.message = resolveApiMessage(data, "Produkti nuk u rikthye ne shporte.");
    ui.type = "error";
    return;
  }

  savedLaterItems.value = removeSavedForLaterItem(item);
  ui.message = "Artikulli u rikthye ne shporte.";
  ui.type = "success";
  await loadItems();
}

function removeSavedLaterItem(savedItem) {
  savedLaterItems.value = removeSavedForLaterItem(savedItem);
  ui.message = "Artikulli u hoq nga te ruajturat per me vone.";
  ui.type = "success";
}

function clearSavedLater() {
  if (savedLaterCount.value <= 0) {
    return;
  }

  savedLaterItems.value = clearSavedForLaterItems();
  ui.message = "U pastruan artikujt e ruajtur per me vone.";
  ui.type = "success";
}

function handleCheckout() {
  if (selectedItems.value.length === 0) {
    ui.message = "Zgjidh te pakten nje produkt per te vazhduar me porosi.";
    ui.type = "error";
    return;
  }

  if (selectedUnavailableItems.value.length > 0) {
    const firstUnavailable = selectedUnavailableItems.value[0];
    ui.message =
      getProductStockMessage(firstUnavailable)
      || "Na vjen keq, disa produkte ne shporte nuk jane me ne stok. Hiqi ose ruaji per me vone.";
    ui.type = "error";
    return;
  }

  persistCheckoutSelectedCartIds(selectedItems.value.map((item) => item.id));
  router.push("/adresa-e-porosise");
}

function setupHeightSync() {
  scheduleHeightSync();
  window.addEventListener("resize", scheduleHeightSync);

  if (!("ResizeObserver" in window) || !summaryCard.value) {
    return;
  }

  resizeObserver = new window.ResizeObserver(() => {
    scheduleHeightSync();
  });
  resizeObserver.observe(summaryCard.value);
}

function scheduleHeightSync() {
  if (resizeFrame) {
    window.cancelAnimationFrame(resizeFrame);
  }

  resizeFrame = window.requestAnimationFrame(() => {
    resizeFrame = 0;
    syncHeight();
  });
}

function syncHeight() {
  if (!productsPanel.value) {
    return;
  }

  if (window.innerWidth <= 780 || !summaryCard.value) {
    productsPanel.value.style.removeProperty("--cart-panel-height");
    return;
  }

  const summaryHeight = Math.ceil(summaryCard.value.getBoundingClientRect().height);
  if (summaryHeight > 0) {
    productsPanel.value.style.setProperty("--cart-panel-height", `${summaryHeight}px`);
  }
}
</script>

<template>
  <section class="collection-page" aria-label="Cart products">
    <header class="collection-page-header">
      <p class="section-label">Cart</p>
      <h1>Shporta ime</h1>
      <p>
        Ketu shfaqen produktet qe shtohen nga kartat e produkteve. Duhet te jesh i kyçur qe t'i përdorësh.
      </p>
    </header>

    <div class="form-message" :class="ui.type" role="status" aria-live="polite">
      {{ ui.message }}
    </div>

    <div v-if="ui.guest" class="collection-empty-state collection-guest-gate">
      <h2>Per te perdorur shporten duhet te kyçesh.</h2>
      <p>Krijo llogari ose hyni ne llogarine tende per te ruajtur produktet dhe per te vazhduar me porosite.</p>
      <div class="collection-guest-gate-actions">
        <RouterLink class="nav-action nav-action-secondary" to="/login?redirect=%2Fcart">
          Login
        </RouterLink>
        <RouterLink class="nav-action nav-action-primary" to="/signup?redirect=%2Fcart">
          Sign Up
        </RouterLink>
      </div>
    </div>

    <div v-else class="cart-layout">
      <div ref="productsPanel" class="cart-products-panel">
        <div v-if="selectionEnabled" class="saved-products-toolbar">
          <div class="saved-products-toolbar-left">
            <label class="saved-products-select-all" for="cart-select-all">
              <input
                id="cart-select-all"
                type="checkbox"
                :checked="allSelected"
                :indeterminate.prop="isIndeterminate"
                @change="toggleAll"
              >
              <span>Zgjidh produktet per porosi</span>
            </label>
            <span class="saved-products-selected-count">
              {{ selectedItems.length }} produkte te zgjedhura
            </span>
          </div>
        </div>

        <div v-if="unavailableItems.length > 0" class="cart-stock-warning" role="status" aria-live="polite">
          <strong>{{ unavailableItems.length }} produkte ne shporte nuk jane me ne stok.</strong>
          <p>Artikujt e prekur jane zbehur. Hiqi ose ruaji per me vone para se te vazhdosh me porosi.</p>
        </div>

        <section v-if="items.length > 0" id="cart-products-grid" class="saved-products-grid" aria-label="Cart grid">
          <SavedProductCard
            v-for="item in items"
            :key="item.id"
            :product="item"
            mode="cart"
            :selection-enabled="selectionEnabled"
            :selected="selectedIds.includes(item.id)"
            @toggle-select="toggleItem"
            @remove="removeItem"
            @save-for-later="saveForLater"
            @increase-quantity="increaseQuantity"
            @decrease-quantity="decreaseQuantity"
          />
        </section>

        <div v-else class="collection-empty-state">
          Shporta jote eshte bosh. Shto produkte nga faqet e dyqanit dhe pastaj vazhdo me porosine.
        </div>
      </div>

      <aside ref="summaryCard" class="card cart-summary-card" aria-label="Cart summary">
        <div class="profile-card-header">
          <div>
            <p class="section-label">Pagesa</p>
            <h2>Permbledhja e porosise</h2>
          </div>
        </div>

        <div class="cart-summary-grid">
          <div class="summary-chip">
            <span>Produktet ne shporte</span>
            <strong>{{ totalItems }}</strong>
          </div>
          <div class="summary-chip">
            <span>Shuma totale</span>
            <strong>{{ formatPrice(totalPrice) }}</strong>
          </div>
        </div>

        <p class="cart-summary-note">
          Pasi te vazhdosh me porosine, hapi i ardhshem eshte vendosja e adreses se dergeses.
        </p>

        <button
          class="cart-checkout-button"
          type="button"
          :disabled="selectedItems.length === 0 || selectedUnavailableItems.length > 0"
          @click="handleCheckout"
        >
          Vazhdo me porosi
        </button>
      </aside>
    </div>

    <section v-if="savedLaterItems.length > 0" class="cart-saved-later-section" aria-label="Saved for later">
      <div class="saved-products-toolbar cart-saved-later-toolbar">
        <div class="saved-products-toolbar-left">
          <div>
            <p class="section-label">Ruajtur</p>
            <h2>Per me vone</h2>
          </div>
          <span class="saved-products-selected-count">
            {{ savedLaterCount }} produkte te ruajtura
          </span>
        </div>

        <button class="saved-products-toolbar-button cart-saved-later-clear" type="button" @click="clearSavedLater">
          Pastro te gjitha
        </button>
      </div>

      <section class="saved-products-grid cart-saved-later-grid" aria-label="Saved for later grid">
        <SavedProductCard
          v-for="item in savedLaterItems"
          :key="`${item.productId}-${item.variantKey || item.selectedSize || 'default'}-${item.selectedColor || 'default'}`"
          :product="item"
          mode="later"
          @add-to-cart="restoreSavedLaterItem"
          @remove="removeSavedLaterItem"
        />
      </section>
    </section>
  </section>
</template>
