<script setup>
import { computed, nextTick, onMounted, onUnmounted, reactive, ref } from "vue";
import { useRouter } from "vue-router";
import SavedProductCard from "../components/SavedProductCard.vue";
import { requestJson, resolveApiMessage } from "../lib/api";
import { formatPrice, persistCheckoutSelectedCartIds } from "../lib/shop";
import { appState, ensureSessionLoaded, markRouteReady, setCartItems } from "../stores/app-state";

const router = useRouter();
const productsPanel = ref(null);
const summaryCard = ref(null);
const items = ref([]);
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

const totalItems = computed(() =>
  selectedItems.value.reduce((total, item) => total + Math.max(0, Number(item.quantity) || 0), 0),
);

const totalPrice = computed(() =>
  selectedItems.value.reduce(
    (total, item) => total + (Math.max(0, Number(item.quantity) || 0) * (Number(item.price) || 0)),
    0,
  ),
);

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

function handleCheckout() {
  if (selectedItems.value.length === 0) {
    ui.message = "Zgjidh te pakten nje produkt per te vazhduar me porosi.";
    ui.type = "error";
    return;
  }

  persistCheckoutSelectedCartIds(selectedItems.value.map((item) => item.id));
  window.location.href = "/adresa-e-porosise";
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

    <div class="cart-layout">
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
            @increase-quantity="increaseQuantity"
            @decrease-quantity="decreaseQuantity"
          />
        </section>

        <div v-else class="collection-empty-state">
          {{ ui.guest ? "Per te perdorur shporten duhet te kyçesh ose te krijosh llogari." : "Shporta jote eshte bosh. Shto produkte nga faqet e dyqanit dhe pastaj vazhdo me porosine." }}
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
          :disabled="selectedItems.length === 0"
          @click="handleCheckout"
        >
          Vazhdo me porosi
        </button>
      </aside>
    </div>
  </section>
</template>
