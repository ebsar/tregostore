<script setup>
import { computed, onMounted, reactive, ref } from "vue";
import { useRouter } from "vue-router";
import { requestJson, resolveApiMessage } from "../lib/api";
import { formatPrice, getProductDetailUrl, getProductStockMessage, hasProductAvailableStock } from "../lib/shop";
import { appState, setCartItems } from "../stores/app-state";

const props = defineProps({
  modalOnly: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(["close", "request-login"]);

const router = useRouter();
const items = ref([]);
const ui = reactive({
  loading: false,
  message: "",
  type: "",
});

const isAuthenticated = computed(() => Boolean(appState.user));
const totalItems = computed(() => items.value.length);

onMounted(() => {
  if (isAuthenticated.value) {
    void loadItems();
  }
});

async function loadItems() {
  ui.loading = true;
  ui.message = "";
  ui.type = "";

  try {
    const { response, data } = await requestJson("/api/wishlist");
    if (!response.ok || !data?.ok) {
      ui.message = resolveApiMessage(data, "Wishlist nuk u ngarkua.");
      ui.type = "error";
      items.value = [];
      return;
    }

    items.value = Array.isArray(data.items) ? data.items : [];
  } catch (error) {
    ui.message = "Serveri nuk po pergjigjet. Provoje perseri.";
    ui.type = "error";
    console.error(error);
  } finally {
    ui.loading = false;
  }
}

async function removeItem(productId) {
  const { response, data } = await requestJson("/api/wishlist/toggle", {
    method: "POST",
    body: JSON.stringify({ productId }),
  });

  if (!response.ok || !data?.ok) {
    ui.message = resolveApiMessage(data, "Wishlist nuk u perditesua.");
    ui.type = "error";
    return;
  }

  ui.message = data.message || "Produkti u hoq nga wishlist.";
  ui.type = "success";
  await loadItems();
}

async function addToCart(product) {
  if (!hasProductAvailableStock(product)) {
    ui.message = getProductStockMessage(product);
    ui.type = "error";
    return;
  }

  if (product?.requiresVariantSelection) {
    emit("close");
    await router.push(getProductDetailUrl(product.id, "/wishlist"));
    return;
  }

  const { response, data } = await requestJson("/api/cart/add", {
    method: "POST",
    body: JSON.stringify({ productId: product.id }),
  });

  if (!response.ok || !data?.ok) {
    ui.message = resolveApiMessage(data, "Shporta nuk u perditesua.");
    ui.type = "error";
    return;
  }

  setCartItems(Array.isArray(data.items) ? data.items : []);
  ui.message = data.message || "Produkti u shtua ne shporte.";
  ui.type = "success";
}

async function openWishlistPage() {
  emit("close");
  await router.push("/wishlist");
}
</script>

<template>
  <div class="overlay-panel overlay-panel--wide" @click.stop>
    <div class="auth-panel">
      <button
        type="button"
        class="market-icon-button auth-panel__close"
        aria-label="Close wishlist"
        @click="$emit('close')"
      >
        ×
      </button>

      <template v-if="!isAuthenticated">
        <div class="market-empty">
          <h3>Wishlist</h3>
          <p>Per ta perdorur wishlist, duhet te kyçesh ose të krijosh llogari.</p>
          <button class="market-button market-button--primary" type="button" @click="$emit('request-login')">
            HAP LOGIN
          </button>
        </div>
      </template>

      <template v-else>
        <div class="search-toolbar">
          <div>
            <p>Saved products</p>
            <h3>{{ totalItems }} item{{ totalItems === 1 ? "" : "s" }}</h3>
          </div>
          <button
            v-if="!props.modalOnly"
            type="button"
            class="market-button market-button--secondary"
            @click="openWishlistPage"
          >
            Open wishlist
          </button>
        </div>

        <p
          v-if="ui.message"
          :class="['market-status', ui.type === 'error' ? 'market-status--error' : ui.type === 'success' ? 'market-status--success' : '']"
        >
          {{ ui.message }}
        </p>

        <div v-if="ui.loading" class="market-status market-status--compact">Duke ngarkuar wishlist...</div>

        <div v-else-if="items.length === 0" class="market-empty">
          <p>Wishlist-i yt eshte bosh.</p>
        </div>

        <div v-else class="product-collection">
          <article
            v-for="item in items"
            :key="item.id"
            class="cart-item market-card market-card--padded"
          >
            <img
              class="product-card__image"
              :src="item.imagePath"
              :alt="item.title"
              width="640"
              height="640"
              loading="lazy"
              decoding="async"
            >

            <div class="product-card__body">
              <strong>{{ item.title }}</strong>
              <p>{{ formatPrice(item.price) }} / per item</p>
              <span>
                {{ hasProductAvailableStock(item) ? "Ne stok" : "Nuk ka ne stok" }}
              </span>
            </div>

            <div class="search-toolbar">
              <strong>{{ formatPrice(item.price) }}</strong>
              <button class="market-button market-button--secondary" type="button" @click="addToCart(item)">
                Add to cart
              </button>
              <button class="market-button market-button--ghost" type="button" @click="removeItem(item.id)">
                Remove
              </button>
            </div>
          </article>
        </div>

        <div v-if="items.length > 0 && !props.modalOnly">
          <button class="market-button market-button--secondary" type="button" @click="openWishlistPage">
            OPEN WISHLIST
          </button>
        </div>
      </template>
    </div>
  </div>
</template>
