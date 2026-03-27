<script setup>
import { computed, onBeforeUnmount, onMounted, reactive, ref, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import ProductCard from "../components/ProductCard.vue";
import { fetchProtectedCollection, requestJson, resolveApiMessage, searchProductsByImage } from "../lib/api";
import { formatCategoryGroupLabel, formatCategoryLabel } from "../lib/shop";
import { appState, ensureSessionLoaded, markRouteReady, setCartItems } from "../stores/app-state";

const route = useRoute();
const router = useRouter();
const PRODUCTS_PAGE_SIZE = 12;
const SEARCH_INPUT_DEBOUNCE_MS = 320;

const draftQuery = ref("");
const products = ref([]);
const wishlistIds = ref([]);
const cartIds = ref([]);
const busyWishlistIds = ref([]);
const busyCartIds = ref([]);
const totalProductsCount = ref(0);
const hasMoreProducts = ref(false);
const loadingMoreProducts = ref(false);
const filtersVisible = ref(false);
const visualSearchInputElement = ref(null);
const visualSearchFile = ref(null);
const visualSearchPreviewUrl = ref("");
const visualSearchFileName = ref("");
const visualSearchActive = ref(false);
const visualSearchBusy = ref(false);
const filters = reactive({
  size: "",
  color: "",
  sort: "",
});
const ui = reactive({
  message: "",
  type: "",
});
let searchDebounceTimeoutId = 0;

const categoryFilter = computed(() => String(route.query.category || "").trim().toLowerCase());
const categoryGroupFilter = computed(() => String(route.query.categoryGroup || "").trim().toLowerCase());
const productTypeFilter = computed(() => String(route.query.productType || "").trim().toLowerCase());
const activeQuery = computed(() => String(route.query.q || "").trim());

const filteredProducts = computed(() => {
  let nextProducts = [...products.value];

  if (categoryGroupFilter.value) {
    nextProducts = nextProducts.filter((product) =>
      String(product.category || "").startsWith(`${categoryGroupFilter.value}-`),
    );
  }

  if (categoryFilter.value) {
    nextProducts = nextProducts.filter((product) => String(product.category || "") === categoryFilter.value);
  }

  if (productTypeFilter.value) {
    nextProducts = nextProducts.filter((product) => product.productType === productTypeFilter.value);
  }

  if (filters.size) {
    nextProducts = nextProducts.filter((product) => String(product.size || "") === filters.size);
  }

  if (filters.color) {
    nextProducts = nextProducts.filter((product) => String(product.color || "") === filters.color);
  }

  if (filters.sort === "price-asc") {
    nextProducts.sort((left, right) => Number(left.price || 0) - Number(right.price || 0));
  } else if (filters.sort === "price-desc") {
    nextProducts.sort((left, right) => Number(right.price || 0) - Number(left.price || 0));
  }

  return nextProducts;
});

const resultsLabel = computed(() => {
  if (visualSearchActive.value) {
    if (!products.value.length) {
      return "Nuk u gjet asnje produkt i ngjashem sipas fotos.";
    }

    return totalProductsCount.value > products.value.length
      ? `Po shfaqen ${products.value.length} nga ${totalProductsCount.value} produkte te ngjashme sipas fotos.`
      : `Po shfaqen ${products.value.length} produkte te ngjashme sipas fotos.`;
  }

  if (!products.value.length) {
    return "Nuk u gjet asnje produkt per kete kerkim.";
  }

  const scopeParts = [];
  if (activeQuery.value) {
    scopeParts.push(`kerkimin "${activeQuery.value}"`);
  }
  if (categoryFilter.value) {
    scopeParts.push(formatCategoryLabel(categoryFilter.value));
  }
  if (categoryGroupFilter.value) {
    scopeParts.push(formatCategoryGroupLabel(categoryGroupFilter.value));
  }

  const scopeLabel = scopeParts.length ? ` per ${scopeParts.join(" • ")}` : "";

  if (!filters.size && !filters.color && !filters.sort) {
    return totalProductsCount.value > products.value.length
      ? `Po shfaqen ${products.value.length} nga ${totalProductsCount.value} produkte${scopeLabel}.`
      : `Po shfaqen ${products.value.length} produkte${scopeLabel}.`;
  }

  return totalProductsCount.value > 0
    ? `Po shfaqen ${filteredProducts.value.length} nga ${products.value.length} produkte te ngarkuara (${totalProductsCount.value} gjithsej)${scopeLabel}.`
    : `Po shfaqen ${filteredProducts.value.length} produkte${scopeLabel}.`;
});

watch(
  () => route.fullPath,
  async () => {
    draftQuery.value = activeQuery.value;
    clearVisualSearchState();
    await bootstrap();
  },
);

watch(draftQuery, (nextValue) => {
  window.clearTimeout(searchDebounceTimeoutId);
  const normalizedDraft = String(nextValue || "").trim();
  if (normalizedDraft === activeQuery.value) {
    return;
  }

  searchDebounceTimeoutId = window.setTimeout(() => {
    submitSearch();
  }, SEARCH_INPUT_DEBOUNCE_MS);
});

onMounted(async () => {
  draftQuery.value = activeQuery.value;
  await bootstrap();
});

onBeforeUnmount(() => {
  window.clearTimeout(searchDebounceTimeoutId);
  clearVisualSearchState();
});

async function bootstrap() {
  try {
    await Promise.all([
      ensureSessionLoaded().then(() => refreshCollectionState()),
      loadProducts(),
    ]);
  } catch (error) {
    ui.message = "Produktet nuk u ngarkuan. Provoje perseri.";
    ui.type = "error";
    console.error(error);
  } finally {
    markRouteReady();
  }
}

async function refreshCollectionState() {
  if (!appState.user) {
    wishlistIds.value = [];
    cartIds.value = [];
    return;
  }

  const [wishlistItems, cartItems] = await Promise.all([
    fetchProtectedCollection("/api/wishlist"),
    fetchProtectedCollection("/api/cart"),
  ]);

  wishlistIds.value = wishlistItems.map((item) => item.id);
  cartIds.value = cartItems.map((item) => item.id);
  setCartItems(cartItems);
}

async function loadProducts(options = {}) {
  const { append = false } = options;
  const params = new URLSearchParams();
  params.set("limit", String(PRODUCTS_PAGE_SIZE));
  params.set("offset", String(append ? products.value.length : 0));

  if (activeQuery.value) {
    params.set("q", activeQuery.value);
  }

  if (categoryFilter.value) {
    params.set("category", categoryFilter.value);
  }

  if (categoryGroupFilter.value) {
    params.set("categoryGroup", categoryGroupFilter.value);
  }

  const requestUrl = activeQuery.value
    ? `/api/products/search?${params.toString()}`
    : `/api/products?${params.toString()}`;

  const { response, data } = await requestJson(requestUrl, {}, { cacheTtlMs: 8000 });
  if (!response.ok || !data?.ok) {
    ui.message = resolveApiMessage(data, "Produktet nuk u ngarkuan.");
    ui.type = "error";
    if (!append) {
      products.value = [];
      totalProductsCount.value = 0;
      hasMoreProducts.value = false;
    }
    return;
  }

  const nextProducts = Array.isArray(data.products) ? data.products : [];
  products.value = append ? [...products.value, ...nextProducts] : nextProducts;
  totalProductsCount.value = Number(data.total || products.value.length || 0);
  hasMoreProducts.value = Boolean(data.hasMore);
  ui.message = "";
  ui.type = "";
}

async function loadMoreProducts() {
  if (loadingMoreProducts.value || !hasMoreProducts.value) {
    return;
  }

  loadingMoreProducts.value = true;
  try {
    if (visualSearchActive.value && visualSearchFile.value) {
      await runVisualSearch({ append: true });
    } else {
      await loadProducts({ append: true });
    }
  } finally {
    loadingMoreProducts.value = false;
  }
}

function submitSearch() {
  window.clearTimeout(searchDebounceTimeoutId);
  const normalizedQuery = String(draftQuery.value || "").trim();
  clearVisualSearchState();
  router.replace({
    path: "/kerko",
    query: {
      ...(categoryGroupFilter.value ? { categoryGroup: categoryGroupFilter.value } : {}),
      ...(categoryFilter.value ? { category: categoryFilter.value } : {}),
      ...(productTypeFilter.value ? { productType: productTypeFilter.value } : {}),
      ...(normalizedQuery ? { q: normalizedQuery } : {}),
    },
  });
}

function openVisualSearchPicker() {
  visualSearchInputElement.value?.click();
}

function clearVisualSearchState() {
  visualSearchActive.value = false;
  visualSearchFile.value = null;
  visualSearchFileName.value = "";
  if (visualSearchPreviewUrl.value) {
    URL.revokeObjectURL(visualSearchPreviewUrl.value);
    visualSearchPreviewUrl.value = "";
  }
}

async function clearVisualSearchAndReload() {
  clearVisualSearchState();
  await loadProducts();
}

async function handleVisualSearchSelection(event) {
  const nextFile = event.target?.files?.[0] || null;
  if (!nextFile) {
    return;
  }

  clearVisualSearchState();
  visualSearchFile.value = nextFile;
  visualSearchFileName.value = String(nextFile.name || "").trim();
  visualSearchPreviewUrl.value = URL.createObjectURL(nextFile);
  await runVisualSearch();

  if (event.target) {
    event.target.value = "";
  }
}

async function runVisualSearch(options = {}) {
  if (!visualSearchFile.value) {
    return;
  }

  const { append = false } = options;
  visualSearchBusy.value = true;

  const result = await searchProductsByImage(visualSearchFile.value, {
    category: categoryFilter.value,
    categoryGroup: categoryGroupFilter.value,
    limit: PRODUCTS_PAGE_SIZE,
    offset: append ? products.value.length : 0,
  });

  visualSearchBusy.value = false;

  if (!result.ok) {
    if (!append) {
      products.value = [];
      totalProductsCount.value = 0;
      hasMoreProducts.value = false;
    }
    ui.message = result.message;
    ui.type = "error";
    return;
  }

  visualSearchActive.value = true;
  const nextProducts = Array.isArray(result.products) ? result.products : [];
  products.value = append ? [...products.value, ...nextProducts] : nextProducts;
  totalProductsCount.value = Number(result.total || products.value.length || 0);
  hasMoreProducts.value = Boolean(result.hasMore);
  ui.message = result.message || "U gjeten produkte te ngjashme sipas fotos.";
  ui.type = "success";
}

function resetFilters() {
  filters.size = "";
  filters.color = "";
  filters.sort = "";
}

async function handleWishlist(productId) {
  if (!appState.user) {
    ui.message = "Duhet te kyçesh ose te krijosh llogari para se te perdoresh wishlist ose cart.";
    ui.type = "error";
    return;
  }

  busyWishlistIds.value = [...busyWishlistIds.value, productId];
  const currentHas = wishlistIds.value.includes(productId);
  wishlistIds.value = currentHas
    ? wishlistIds.value.filter((id) => id !== productId)
    : [...wishlistIds.value, productId];

  const { response, data } = await requestJson("/api/wishlist/toggle", {
    method: "POST",
    body: JSON.stringify({ productId }),
  });

  busyWishlistIds.value = busyWishlistIds.value.filter((id) => id !== productId);

  if (!response.ok || !data?.ok) {
    wishlistIds.value = currentHas
      ? [...wishlistIds.value, productId]
      : wishlistIds.value.filter((id) => id !== productId);
    ui.message = resolveApiMessage(data, "Wishlist nuk u perditesua.");
    ui.type = "error";
    return;
  }

  wishlistIds.value = Array.isArray(data.items) ? data.items.map((item) => item.id) : [];
  ui.message = data.message || "Wishlist u perditesua.";
  ui.type = "success";
}

async function handleCart(productId) {
  if (!appState.user) {
    ui.message = "Duhet te kyçesh ose te krijosh llogari para se te perdoresh wishlist ose cart.";
    ui.type = "error";
    return;
  }

  busyCartIds.value = [...busyCartIds.value, productId];
  if (!cartIds.value.includes(productId)) {
    cartIds.value = [...cartIds.value, productId];
  }

  const { response, data } = await requestJson("/api/cart/add", {
    method: "POST",
    body: JSON.stringify({ productId }),
  });

  busyCartIds.value = busyCartIds.value.filter((id) => id !== productId);

  if (!response.ok || !data?.ok) {
    cartIds.value = cartIds.value.filter((id) => id !== productId);
    ui.message = resolveApiMessage(data, "Shporta nuk u perditesua.");
    ui.type = "error";
    return;
  }

  const items = Array.isArray(data.items) ? data.items : [];
  cartIds.value = items.map((item) => item.id);
  setCartItems(items);
  ui.message = data.message || "Produkti u shtua ne shporte.";
  ui.type = "success";
}
</script>

<template>
  <section class="collection-page search-page" aria-label="Kerko produkte">
    <header class="collection-page-header">
      <p class="section-label">Kerko</p>
      <h1>Kerko produktet</h1>
      <p>
        Shkruaj p.sh. `shampon` ose fotografo produktin me kamerë dhe do te dalin produktet me te aferta.
      </p>
    </header>

    <form class="search-form" role="search" @submit.prevent="submitSearch">
      <input
        v-model="draftQuery"
        class="search-input"
        name="q"
        type="search"
        placeholder="Kerko p.sh. shampon"
        autocomplete="off"
      >
      <button class="search-submit-button" type="submit">Kerko</button>
    </form>

    <div class="collection-toolbar">
      <div class="collection-toolbar-group">
        <button
          class="filter-toggle-button"
          type="button"
          :aria-expanded="filtersVisible ? 'true' : 'false'"
          @click="filtersVisible = !filtersVisible"
        >
          Filtro
        </button>

        <button
          class="filter-toggle-button"
          type="button"
          :disabled="visualSearchBusy"
          @click="openVisualSearchPicker"
        >
          {{ visualSearchBusy ? "Duke analizuar..." : "Kerko me foto" }}
        </button>

        <input
          ref="visualSearchInputElement"
          class="sr-only"
          type="file"
          accept="image/*"
          capture="environment"
          @change="handleVisualSearchSelection"
        >
      </div>
    </div>

    <section v-if="visualSearchFileName" class="visual-search-panel" aria-label="Kerkimi me foto">
      <div class="visual-search-chip">
        <img
          v-if="visualSearchPreviewUrl"
          class="visual-search-chip-image"
          :src="visualSearchPreviewUrl"
          alt="Fotoja e zgjedhur per kerkimin vizual"
          width="120"
          height="120"
        >
        <div class="visual-search-chip-copy">
          <strong>Po kerkohet sipas fotos</strong>
          <span>{{ visualSearchFileName }}</span>
        </div>
        <button class="search-reset-button" type="button" @click="clearVisualSearchAndReload">
          Hiqe foton
        </button>
      </div>
    </section>

    <section v-if="filtersVisible" class="search-filters-panel" aria-label="Filtro produktet">
      <div class="search-filters-grid">
        <label class="field">
          <span>Madhesia</span>
          <select v-model="filters.size" class="search-filter-select">
            <option value="">Te gjitha madhesite</option>
            <option value="XS">XS</option>
            <option value="S">S</option>
            <option value="M">M</option>
            <option value="L">L</option>
            <option value="XL">XL</option>
          </select>
        </label>

        <label class="field">
          <span>Ngjyra</span>
          <select v-model="filters.color" class="search-filter-select">
            <option value="">Te gjitha ngjyrat</option>
            <option value="bardhe">Bardhe</option>
            <option value="zeze">Zeze</option>
            <option value="gri">Gri</option>
            <option value="beige">Beige</option>
            <option value="kafe">Kafe</option>
            <option value="kuqe">Kuqe</option>
            <option value="roze">Roze</option>
            <option value="vjollce">Vjollce</option>
            <option value="blu">Blu</option>
            <option value="gjelber">Gjelber</option>
            <option value="verdhe">Verdhe</option>
            <option value="portokalli">Portokalli</option>
            <option value="shume-ngjyra">Shume ngjyra</option>
          </select>
        </label>

        <label class="field">
          <span>Cmimi</span>
          <select v-model="filters.sort" class="search-filter-select">
            <option value="">Renditja standarde</option>
            <option value="price-asc">Nga me i uleti</option>
            <option value="price-desc">Nga me i larti</option>
          </select>
        </label>
      </div>

      <div class="search-filter-actions">
        <button class="search-reset-button" type="button" @click="resetFilters">Pastro filtrat</button>
      </div>
    </section>

    <p class="search-results-label">{{ resultsLabel }}</p>
    <div class="form-message" :class="ui.type" role="status" aria-live="polite">
      {{ ui.message }}
    </div>

    <section v-if="filteredProducts.length > 0" class="pet-products-grid" aria-label="Rezultatet e kerkimit">
      <ProductCard
        v-for="product in filteredProducts"
        :key="product.id"
        :product="product"
        :is-wishlisted="wishlistIds.includes(product.id)"
        :is-in-cart="cartIds.includes(product.id)"
        :wishlist-busy="busyWishlistIds.includes(product.id)"
        :cart-busy="busyCartIds.includes(product.id)"
        @wishlist="handleWishlist"
        @cart="handleCart"
      />
    </section>

    <div v-if="products.length > 0 && hasMoreProducts" class="collection-load-more">
      <button class="search-reset-button collection-load-more-button" type="button" :disabled="loadingMoreProducts" @click="loadMoreProducts">
        {{ loadingMoreProducts ? "Duke ngarkuar..." : "Shfaq me shume" }}
      </button>
    </div>

    <div v-if="products.length === 0" class="collection-empty-state">
      {{ visualSearchActive ? "Nuk u gjet asnje produkt i ngjashem sipas fotos." : "Nuk u gjet asnje produkt per kete kerkim." }}
    </div>
  </section>
</template>
