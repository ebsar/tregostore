<script setup>
import { computed, onMounted, reactive, ref, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import ProductCard from "../components/ProductCard.vue";
import { fetchProtectedCollection, requestJson, resolveApiMessage } from "../lib/api";
import { formatCategoryLabel } from "../lib/shop";
import { appState, ensureSessionLoaded, markRouteReady, setCartItems } from "../stores/app-state";

const route = useRoute();
const router = useRouter();

const query = ref("");
const products = ref([]);
const wishlistIds = ref([]);
const cartIds = ref([]);
const busyWishlistIds = ref([]);
const busyCartIds = ref([]);
const filters = reactive({
  size: "",
  color: "",
  sort: "",
});
const ui = reactive({
  message: "",
  type: "",
});

const categoryFilter = computed(() => String(route.query.category || "").trim().toLowerCase());
const productTypeFilter = computed(() => String(route.query.productType || "").trim().toLowerCase());

const filteredProducts = computed(() => {
  let nextProducts = [...products.value];

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
  if (!products.value.length) {
    return "Nuk u gjet asnje produkt per kete kerkim.";
  }

  const scopeParts = [];
  if (query.value) {
    scopeParts.push(`kerkimin "${query.value}"`);
  }
  if (categoryFilter.value) {
    scopeParts.push(formatCategoryLabel(categoryFilter.value));
  }

  return `Po shfaqen ${filteredProducts.value.length} produkte${
    scopeParts.length ? ` per ${scopeParts.join(" • ")}` : ""
  }.`;
});

watch(
  () => route.fullPath,
  async () => {
    query.value = String(route.query.q || "").trim();
    await bootstrap();
  },
);

onMounted(async () => {
  query.value = String(route.query.q || "").trim();
  await bootstrap();
});

async function bootstrap() {
  try {
    await ensureSessionLoaded();
    await refreshCollectionState();
    await loadProducts();
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

async function loadProducts() {
  const requestUrl = query.value
    ? `/api/products/search?q=${encodeURIComponent(query.value)}`
    : `/api/products${categoryFilter.value ? `?category=${encodeURIComponent(categoryFilter.value)}` : ""}`;

  const { response, data } = await requestJson(requestUrl);
  if (!response.ok || !data?.ok) {
    ui.message = resolveApiMessage(data, "Produktet nuk u ngarkuan.");
    ui.type = "error";
    products.value = [];
    return;
  }

  products.value = Array.isArray(data.products) ? data.products : [];
  ui.message = "";
  ui.type = "";
}

function submitSearch() {
  router.replace({
    path: "/kerko",
    query: {
      ...(categoryFilter.value ? { category: categoryFilter.value } : {}),
      ...(productTypeFilter.value ? { productType: productTypeFilter.value } : {}),
      ...(query.value.trim() ? { q: query.value.trim() } : {}),
    },
  });
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
        Shkruaj p.sh. `shampon` dhe do te dalin te gjitha produktet qe perputhen me kerkimin tend.
      </p>
    </header>

    <form class="search-form" role="search" @submit.prevent="submitSearch">
      <input
        v-model="query"
        class="search-input"
        name="q"
        type="search"
        placeholder="Kerko p.sh. shampon"
        autocomplete="off"
      >
      <button class="search-submit-button" type="submit">Kerko</button>
    </form>

    <section class="search-filters-panel" aria-label="Filtro produktet">
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

    <div v-else class="collection-empty-state">
      Nuk u gjet asnje produkt per kete kerkim.
    </div>
  </section>
</template>
