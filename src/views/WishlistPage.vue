<script setup>
import { computed, onMounted, reactive, ref } from "vue";
import { RouterLink, useRouter } from "vue-router";
import SavedProductCard from "../components/SavedProductCard.vue";
import { requestJson, resolveApiMessage } from "../lib/api";
import { getProductDetailUrl, getProductStockMessage, hasProductAvailableStock } from "../lib/shop";
import { ensureSessionLoaded, markRouteReady, setCartItems } from "../stores/app-state";

const router = useRouter();
const items = ref([]);
const selectedIds = ref([]);
const selectionInitialized = ref(false);
const ui = reactive({
  message: "",
  type: "",
  guest: false,
});

const availableItems = computed(() => items.value.filter((item) => hasProductAvailableStock(item)));
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
      ui.message = "Per te perdorur wishlist duhet te kycesh ose te krijosh llogari.";
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
  if (product && !hasProductAvailableStock(product)) {
    ui.message = getProductStockMessage(product);
    ui.type = "error";
    return;
  }

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

  if (selectedUnavailableItems.value.length > 0) {
    const firstUnavailable = selectedUnavailableItems.value[0];
    ui.message =
      getProductStockMessage(firstUnavailable)
      || "Na vjen keq, disa produkte ne wishlist nuk jane me ne stok.";
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
  <section class="market-page market-page--wide wishlist-page" aria-label="Wishlist products">
    <nav class="market-page__crumbs" aria-label="Breadcrumb">
      <RouterLink to="/">Home</RouterLink>
      <span aria-hidden="true">/</span>
      <strong>Wishlist</strong>
    </nav>

    <header class="wishlist-hero">
      <div class="market-page__header-copy">
        <p class="market-page__eyebrow">Wishlist</p>
        <h1>Produktet e ruajtura</h1>
        <p>
          Ruaj produktet qe te pelqejne, kontrollo stokun, dhe ktheji shpejt ne cart kur je gati per porosi.
        </p>
      </div>

      <div class="wishlist-summary" aria-label="Wishlist summary">
        <article>
          <span>Total</span>
          <strong>{{ items.length }}</strong>
        </article>
        <article>
          <span>Ne stok</span>
          <strong>{{ availableItems.length }}</strong>
        </article>
        <article>
          <span>Pa stok</span>
          <strong>{{ unavailableItems.length }}</strong>
        </article>
      </div>
    </header>

    <div
      v-if="ui.message && !ui.guest"
      class="market-status wishlist-status"
      :class="{ 'market-status--error': ui.type === 'error', 'wishlist-status--success': ui.type === 'success' }"
      role="status"
      aria-live="polite"
    >
      {{ ui.message }}
    </div>

    <div v-if="ui.guest" class="market-empty wishlist-gate">
      <h2>Per te perdorur wishlist duhet te kycesh.</h2>
      <p>Krijo llogari ose hyr ne llogarine tende per te ruajtur produktet e preferuara dhe per t'i gjetur me vone.</p>
      <div class="market-empty__actions">
        <RouterLink class="market-button market-button--primary" to="/login?redirect=%2Fwishlist">
          Login
        </RouterLink>
        <RouterLink class="market-button market-button--secondary" to="/signup?redirect=%2Fwishlist">
          Sign Up
        </RouterLink>
      </div>
    </div>

    <template v-else>
      <div v-if="unavailableItems.length > 0" class="market-status market-status--error wishlist-alert" role="status" aria-live="polite">
        <strong>{{ unavailableItems.length }} produkte ne wishlist nuk jane me ne stok.</strong>
        <span>Produktet e zbehura nuk mund te shtohen ne cart derisa biznesi t'i riktheje ne stok.</span>
      </div>

      <section v-if="selectionEnabled" class="wishlist-toolbar" aria-label="Wishlist bulk actions">
        <label for="wishlist-select-all" class="wishlist-toolbar__select">
          <input
            id="wishlist-select-all"
            type="checkbox"
            :checked="allSelected"
            :indeterminate.prop="isIndeterminate"
            @change="toggleAll"
          >
          <span>Zgjidh produktet per blerje</span>
        </label>

        <div class="wishlist-toolbar__meta">
          <span>{{ selectedItems.length }} nga {{ items.length }} te zgjedhura</span>
          <button
            class="market-button market-button--primary"
            type="button"
            :disabled="selectedItems.length === 0 || selectedUnavailableItems.length > 0"
            @click="bulkAddToCart"
          >
            Vazhdo me blerje
          </button>
        </div>
      </section>

      <section v-if="items.length > 0" class="wishlist-grid" aria-label="Wishlist grid">
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

      <div v-else class="market-empty wishlist-empty">
        <h2>Wishlist-i yt eshte bosh.</h2>
        <p>Shto produkte nga katalogu dhe ruaji me zemren per t'i krahasuar ose blere me vone.</p>
        <div class="market-empty__actions">
          <RouterLink class="market-button market-button--primary" to="/kerko">
            Shiko katalogun
          </RouterLink>
        </div>
      </div>
    </template>
  </section>
</template>

<style scoped>
.wishlist-page {
  display: grid;
  gap: 18px;
}

.wishlist-hero {
  display: grid;
  grid-template-columns: minmax(0, 1fr) minmax(300px, 420px);
  gap: 20px;
  align-items: stretch;
  padding: 22px;
  border: 1px solid var(--dashboard-border);
  border-radius: var(--dashboard-radius);
  background:
    linear-gradient(135deg, rgba(37, 99, 235, 0.08), transparent 42%),
    linear-gradient(315deg, rgba(31, 138, 87, 0.08), transparent 38%),
    #ffffff;
}

.wishlist-hero p {
  max-width: 680px;
  margin: 10px 0 0;
  color: var(--dashboard-muted);
  line-height: 1.55;
}

.wishlist-summary {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 10px;
  align-self: end;
}

.wishlist-summary article {
  min-height: 92px;
  display: grid;
  align-content: center;
  gap: 8px;
  padding: 14px;
  border: 1px solid #e8eefb;
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.82);
}

.wishlist-summary span,
.wishlist-toolbar__meta span {
  color: var(--dashboard-muted);
  font-size: 12px;
  font-weight: 650;
  text-transform: uppercase;
}

.wishlist-summary strong {
  color: var(--dashboard-text);
  font-size: 28px;
  line-height: 1;
}

.wishlist-status--success {
  border-color: var(--dashboard-green-border);
  background: var(--dashboard-green-soft);
  color: var(--dashboard-green);
}

.wishlist-alert {
  display: grid;
  gap: 4px;
}

.wishlist-toolbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 14px;
  padding: 14px 16px;
  border: 1px solid var(--dashboard-border);
  border-radius: var(--dashboard-radius);
  background: #ffffff;
}

.wishlist-toolbar__select,
.wishlist-toolbar__meta {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 12px;
}

.wishlist-toolbar__select {
  color: var(--dashboard-text);
  font-size: 14px;
  font-weight: 700;
}

.wishlist-grid {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 14px;
}

.wishlist-gate,
.wishlist-empty {
  background: #ffffff;
}

@media (max-width: 1100px) {
  .wishlist-hero {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 900px) {
  .wishlist-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

@media (max-width: 640px) {
  .wishlist-hero {
    padding: 18px;
  }

  .wishlist-summary,
  .wishlist-grid {
    grid-template-columns: 1fr;
  }

  .wishlist-toolbar,
  .wishlist-toolbar__meta {
    align-items: stretch;
    flex-direction: column;
  }

  .wishlist-toolbar__meta .market-button {
    width: 100%;
  }
}
</style>
