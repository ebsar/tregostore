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
  <div class="header-wishlist-overlay" @click.stop>
    <div class="header-wishlist-card">
      <button
        type="button"
        class="header-wishlist-close"
        aria-label="Close wishlist"
        @click="$emit('close')"
      >
        ×
      </button>

      <template v-if="!isAuthenticated">
        <div class="header-wishlist-empty">
          <h3>Wishlist</h3>
          <p>Per ta perdorur wishlist, duhet te kyçesh ose të krijosh llogari.</p>
          <button type="button" class="header-wishlist-primary" @click="$emit('request-login')">
            HAP LOGIN
          </button>
        </div>
      </template>

      <template v-else>
        <div class="header-wishlist-head">
          <div>
            <p class="header-wishlist-eyebrow">Saved products</p>
            <h3>{{ totalItems }} item{{ totalItems === 1 ? "" : "s" }}</h3>
          </div>
          <button
            v-if="!props.modalOnly"
            type="button"
            class="header-wishlist-link"
            @click="openWishlistPage"
          >
            Open wishlist
          </button>
        </div>

        <p v-if="ui.message" class="header-wishlist-message" :class="`is-${ui.type}`">
          {{ ui.message }}
        </p>

        <div v-if="ui.loading" class="header-wishlist-state">Duke ngarkuar wishlist...</div>

        <div v-else-if="items.length === 0" class="header-wishlist-empty">
          <p>Wishlist-i yt eshte bosh.</p>
        </div>

        <div v-else class="header-wishlist-list">
          <article
            v-for="item in items"
            :key="item.id"
            class="header-wishlist-item"
          >
            <img
              class="header-wishlist-item-image"
              :src="item.imagePath"
              :alt="item.title"
              width="640"
              height="640"
              loading="lazy"
              decoding="async"
            >

            <div class="header-wishlist-item-copy">
              <strong>{{ item.title }}</strong>
              <p>{{ formatPrice(item.price) }} / per item</p>
              <span :class="{ 'is-unavailable': !hasProductAvailableStock(item) }">
                {{ hasProductAvailableStock(item) ? "Ne stok" : "Nuk ka ne stok" }}
              </span>
            </div>

            <div class="header-wishlist-item-side">
              <strong class="header-wishlist-line-total">{{ formatPrice(item.price) }}</strong>
              <button type="button" class="header-wishlist-add" @click="addToCart(item)">
                Add to cart
              </button>
              <button type="button" class="header-wishlist-remove" @click="removeItem(item.id)">
                Remove
              </button>
            </div>
          </article>
        </div>

        <div v-if="items.length > 0 && !props.modalOnly" class="header-wishlist-actions">
          <button type="button" class="header-wishlist-secondary" @click="openWishlistPage">
            OPEN WISHLIST
          </button>
        </div>
      </template>
    </div>
  </div>
</template>

<style scoped>
.header-wishlist-overlay {
  width: min(760px, calc(100vw - 32px));
}

.header-wishlist-card {
  position: relative;
  display: grid;
  gap: 18px;
  padding: 28px;
  border-radius: 18px;
  background: #fff;
  border: 1px solid rgba(15, 23, 42, 0.08);
  box-shadow: 0 26px 60px rgba(15, 23, 42, 0.18);
}

.header-wishlist-close {
  position: absolute;
  top: 18px;
  right: 18px;
  display: inline-flex;
  width: 38px;
  height: 38px;
  align-items: center;
  justify-content: center;
  border: 0;
  border-radius: 999px;
  background: rgba(15, 23, 42, 0.06);
  color: #0f172a;
  font-size: 1.4rem;
  line-height: 1;
  cursor: pointer;
}

.header-wishlist-head {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 16px;
  padding-right: 44px;
}

.header-wishlist-head h3,
.header-wishlist-empty h3 {
  margin: 4px 0 0;
  color: #111827;
  font-size: 2rem;
  line-height: 1;
  letter-spacing: -0.04em;
}

.header-wishlist-eyebrow {
  margin: 0;
  color: #163b67;
  font-size: 0.8rem;
  font-weight: 800;
  letter-spacing: 0.12em;
  text-transform: uppercase;
}

.header-wishlist-link {
  padding: 0;
  border: 0;
  background: transparent;
  color: #163b67;
  font-weight: 800;
  cursor: pointer;
}

.header-wishlist-state,
.header-wishlist-empty p {
  margin: 0;
  color: #64748b;
  line-height: 1.6;
}

.header-wishlist-empty {
  display: grid;
  gap: 16px;
}

.header-wishlist-list {
  display: grid;
  gap: 14px;
  max-height: min(52vh, 520px);
  overflow-y: auto;
  padding-right: 4px;
}

.header-wishlist-item {
  display: grid;
  grid-template-columns: 92px minmax(0, 1fr) auto;
  gap: 14px;
  align-items: center;
  padding: 14px;
  border-radius: 16px;
  background: #f8fafc;
  border: 1px solid rgba(15, 23, 42, 0.06);
}

.header-wishlist-item-image {
  width: 92px;
  height: 92px;
  object-fit: cover;
  border-radius: 12px;
  background: #fff;
}

.header-wishlist-item-copy {
  display: grid;
  gap: 6px;
}

.header-wishlist-item-copy strong {
  color: #111827;
  line-height: 1.35;
}

.header-wishlist-item-copy p,
.header-wishlist-item-copy span {
  margin: 0;
  color: #64748b;
  font-size: 0.92rem;
}

.header-wishlist-item-copy span.is-unavailable {
  color: #dc2626;
}

.header-wishlist-item-side {
  display: grid;
  justify-items: end;
  gap: 8px;
}

.header-wishlist-line-total {
  color: #111827;
  font-size: 1rem;
}

.header-wishlist-add,
.header-wishlist-primary,
.header-wishlist-secondary {
  min-height: 48px;
  border-radius: 0;
  font-size: 0.95rem;
  font-weight: 800;
  letter-spacing: 0.02em;
  cursor: pointer;
}

.header-wishlist-add,
.header-wishlist-primary {
  border: 0;
  background: #163b67;
  color: #fff;
  padding: 0 16px;
}

.header-wishlist-secondary {
  width: 100%;
  border: 1px solid rgba(22, 59, 103, 0.2);
  background: #eef4fb;
  color: #163b67;
}

.header-wishlist-remove {
  padding: 0;
  border: 0;
  background: transparent;
  color: #dc2626;
  font-weight: 700;
  cursor: pointer;
}

.header-wishlist-actions {
  display: grid;
  padding-top: 6px;
  border-top: 1px solid rgba(15, 23, 42, 0.08);
}

.header-wishlist-message {
  margin: 0;
  font-size: 0.9rem;
}

.header-wishlist-message.is-error {
  color: #dc2626;
}

.header-wishlist-message.is-success {
  color: #059669;
}

@media (max-width: 760px) {
  .header-wishlist-overlay {
    width: min(100vw - 24px, 760px);
  }

  .header-wishlist-card {
    padding: 22px 18px;
  }

  .header-wishlist-item {
    grid-template-columns: 74px minmax(0, 1fr);
  }

  .header-wishlist-item-image {
    width: 74px;
    height: 74px;
  }

  .header-wishlist-item-side {
    grid-column: 1 / -1;
    grid-template-columns: repeat(3, auto);
    align-items: center;
    justify-content: space-between;
  }
}
</style>
