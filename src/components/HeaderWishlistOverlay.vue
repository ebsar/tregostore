<script setup>
import { computed, onBeforeUnmount, onMounted, reactive, ref, watch } from "vue";
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
const previousBodyOverflow = ref("");
const ui = reactive({
  loading: false,
  message: "",
  type: "",
});

const isAuthenticated = computed(() => Boolean(appState.user));
const totalItems = computed(() => items.value.length);
const availableItems = computed(() =>
  items.value.filter((item) => hasProductAvailableStock(item)).length,
);

watch(
  () => isAuthenticated.value,
  (nextValue) => {
    if (!nextValue) {
      items.value = [];
      return;
    }

    void loadItems({ preserveMessage: true });
  },
);

onMounted(() => {
  previousBodyOverflow.value = document.body.style.overflow;
  document.body.style.overflow = "hidden";
  window.addEventListener("keydown", handleKeydown);

  if (isAuthenticated.value) {
    void loadItems();
  }
});

onBeforeUnmount(() => {
  document.body.style.overflow = previousBodyOverflow.value;
  window.removeEventListener("keydown", handleKeydown);
});

function handleKeydown(event) {
  if (event.key === "Escape") {
    emit("close");
  }
}

async function loadItems(options = {}) {
  const { preserveMessage = false } = options;
  ui.loading = true;
  if (!preserveMessage) {
    ui.message = "";
    ui.type = "";
  }

  try {
    const { response, data } = await requestJson("/api/wishlist");
    if (!response.ok || !data?.ok) {
      ui.message = resolveApiMessage(data, "Wishlist could not be loaded.");
      ui.type = "error";
      items.value = [];
      return;
    }

    items.value = Array.isArray(data.items) ? data.items : [];
  } catch (error) {
    ui.message = "Wishlist is currently unavailable. Please try again.";
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
    ui.message = resolveApiMessage(data, "Wishlist could not be updated.");
    ui.type = "error";
    return;
  }

  ui.message = data.message || "Item removed from wishlist.";
  ui.type = "success";
  await loadItems({ preserveMessage: true });
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
    ui.message = resolveApiMessage(data, "Cart could not be updated.");
    ui.type = "error";
    return;
  }

  setCartItems(Array.isArray(data.items) ? data.items : []);
  ui.message = data.message || "Item added to cart.";
  ui.type = "success";
}

async function openWishlistPage() {
  emit("close");
  await router.push("/wishlist");
}

function handleLogin() {
  emit("request-login");
}
</script>

<template>
  <div class="wishlist-drawer" role="dialog" aria-modal="true" aria-label="Wishlist" @click="emit('close')">
    <div class="wishlist-drawer__backdrop"></div>

    <aside class="wishlist-drawer__panel" @click.stop>
      <header class="wishlist-drawer__header">
        <h2>Wishlist</h2>
        <button type="button" class="wishlist-drawer__close" aria-label="Close wishlist" @click="emit('close')">
          <svg viewBox="0 0 24 24" aria-hidden="true">
            <path d="M6 6 18 18M18 6 6 18" />
          </svg>
        </button>
      </header>

      <template v-if="!isAuthenticated">
        <div class="wishlist-drawer__content">
          <div class="market-empty wishlist-drawer__empty">
            <h3>Sign in to view your wishlist</h3>
            <p>Your saved products will appear here once you are signed in.</p>
            <button class="market-button market-button--primary wishlist-drawer__auth-button" type="button" @click="handleLogin">
              Sign in
            </button>
          </div>
        </div>
      </template>

      <template v-else>
        <div class="wishlist-drawer__content">
          <div
            v-if="ui.message"
            class="market-status"
            :class="{ 'market-status--error': ui.type === 'error', 'market-status--success': ui.type === 'success' }"
            role="status"
            aria-live="polite"
          >
            {{ ui.message }}
          </div>

          <div v-if="ui.loading" class="market-status" role="status" aria-live="polite">
            Loading wishlist...
          </div>

          <div v-else-if="items.length === 0" class="market-empty wishlist-drawer__empty">
            <h3>Your wishlist is empty</h3>
            <p>Save products you like and review them here before adding them to cart.</p>
          </div>

          <div v-else class="wishlist-drawer__items">
            <article v-for="item in items" :key="item.id" class="wishlist-drawer__item">
              <RouterLink class="wishlist-drawer__item-media" :to="getProductDetailUrl(item.id)" @click="emit('close')">
                <img
                  :src="item.imagePath"
                  :alt="item.title"
                  width="320"
                  height="320"
                  loading="lazy"
                  decoding="async"
                >
              </RouterLink>

              <div class="wishlist-drawer__item-copy">
                <RouterLink class="wishlist-drawer__item-title" :to="getProductDetailUrl(item.id)" @click="emit('close')">
                  {{ item.title }}
                </RouterLink>
                <span class="wishlist-drawer__item-stock">
                  {{ hasProductAvailableStock(item) ? "In stock" : getProductStockMessage(item) }}
                </span>
                <span class="wishlist-drawer__item-price">{{ formatPrice(item.price) }}</span>
              </div>

              <div class="wishlist-drawer__item-controls">
                <button
                  class="wishlist-drawer__add"
                  type="button"
                  :disabled="!hasProductAvailableStock(item)"
                  @click="addToCart(item)"
                >
                  Add
                </button>

                <button
                  type="button"
                  class="wishlist-drawer__remove"
                  aria-label="Remove item"
                  @click="removeItem(item.id)"
                >
                  <svg viewBox="0 0 24 24" aria-hidden="true">
                    <path d="M6 6 18 18M18 6 6 18" />
                  </svg>
                </button>
              </div>
            </article>
          </div>
        </div>

        <footer v-if="!ui.loading && items.length > 0" class="wishlist-drawer__footer">
          <div class="wishlist-drawer__summary">
            <div class="wishlist-drawer__summary-head">
              <h3>Wishlist summary</h3>
              <button v-if="!props.modalOnly" type="button" class="wishlist-drawer__view-list" @click="openWishlistPage">
                View wishlist
              </button>
            </div>

            <div class="wishlist-drawer__summary-row">
              <span>Saved products</span>
              <strong>{{ totalItems }}</strong>
            </div>

            <div class="wishlist-drawer__summary-row">
              <span>Available now</span>
              <strong>{{ availableItems }}</strong>
            </div>
          </div>
        </footer>
      </template>
    </aside>
  </div>
</template>

<style scoped>
.wishlist-drawer {
  position: fixed;
  inset: 0;
  z-index: 1300;
  display: flex;
  justify-content: flex-end;
}

.wishlist-drawer__backdrop {
  position: absolute;
  inset: 0;
  background: rgba(17, 17, 17, 0.42);
  backdrop-filter: blur(4px);
}

.wishlist-drawer__panel {
  position: relative;
  width: min(100vw, 408px);
  height: 100%;
  display: flex;
  flex-direction: column;
  border-left: 1px solid #e5e5e5;
  background: #ffffff;
}

.wishlist-drawer__header {
  flex-shrink: 0;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  padding: 18px 20px;
  border-bottom: 1px solid #ececec;
}

.wishlist-drawer__header h2 {
  margin: 0;
  color: #111111;
  font-size: 22px;
  font-weight: 600;
  line-height: 1.2;
}

.wishlist-drawer__close {
  width: 36px;
  height: 36px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  border: 1px solid #e5e5e5;
  border-radius: 10px;
  background: #ffffff;
  color: #111111;
  cursor: pointer;
}

.wishlist-drawer__close svg,
.wishlist-drawer__remove svg {
  width: 16px;
  height: 16px;
  fill: none;
  stroke: currentColor;
  stroke-width: 1.8;
  stroke-linecap: round;
  stroke-linejoin: round;
}

.wishlist-drawer__content {
  flex: 1;
  min-height: 0;
  overflow-y: auto;
  padding: 16px 20px 20px;
  display: grid;
  align-content: start;
  gap: 14px;
}

.wishlist-drawer__items {
  display: grid;
}

.wishlist-drawer__item {
  display: grid;
  grid-template-columns: 72px minmax(0, 1fr) auto;
  gap: 12px;
  align-items: start;
  padding: 16px 0;
  border-bottom: 1px solid #f0f0f0;
}

.wishlist-drawer__item:first-child {
  padding-top: 0;
}

.wishlist-drawer__item:last-child {
  border-bottom: 0;
  padding-bottom: 0;
}

.wishlist-drawer__item-media {
  width: 72px;
  height: 72px;
  overflow: hidden;
  border-radius: 12px;
  background: #f3f3f3;
}

.wishlist-drawer__item-media img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.wishlist-drawer__item-copy {
  min-width: 0;
  display: grid;
  gap: 6px;
}

.wishlist-drawer__item-title {
  color: #111111;
  font-size: 14px;
  font-weight: 600;
  line-height: 1.45;
  text-decoration: none;
}

.wishlist-drawer__item-title:hover {
  text-decoration: underline;
}

.wishlist-drawer__item-stock {
  color: #777777;
  font-size: 12px;
  line-height: 1.4;
}

.wishlist-drawer__item-price {
  color: #111111;
  font-size: 13px;
  font-weight: 600;
  line-height: 1.4;
}

.wishlist-drawer__item-controls {
  display: grid;
  justify-items: end;
  align-content: start;
  gap: 10px;
}

.wishlist-drawer__add {
  min-height: 34px;
  border: 1px solid #111111;
  border-radius: 10px;
  background: #111111;
  padding: 0 12px;
  color: #ffffff;
  font-size: 12px;
  font-weight: 700;
  cursor: pointer;
}

.wishlist-drawer__add:disabled {
  border-color: #d8d8d8;
  background: #eeeeee;
  color: #8a8a8a;
  cursor: not-allowed;
}

.wishlist-drawer__remove {
  width: 32px;
  height: 32px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  border: 1px solid transparent;
  border-radius: 10px;
  background: transparent;
  color: #9a9a9a;
  cursor: pointer;
  transition: background-color 160ms ease, color 160ms ease;
}

.wishlist-drawer__remove:hover {
  background: #fff3f3;
  color: #d14848;
}

.wishlist-drawer__footer {
  flex-shrink: 0;
  padding: 18px 20px 20px;
  border-top: 1px solid #ececec;
  background: #ffffff;
}

.wishlist-drawer__summary {
  display: grid;
  gap: 12px;
}

.wishlist-drawer__summary-head,
.wishlist-drawer__summary-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
}

.wishlist-drawer__summary-head h3,
.wishlist-drawer__summary-row strong {
  margin: 0;
  color: #111111;
  font-size: 14px;
  font-weight: 600;
  line-height: 1.4;
}

.wishlist-drawer__summary-row span {
  color: #666666;
  font-size: 13px;
  line-height: 1.45;
}

.wishlist-drawer__view-list {
  border: 0;
  background: transparent;
  padding: 0;
  color: #666666;
  font-size: 13px;
  font-weight: 500;
  cursor: pointer;
}

.wishlist-drawer__view-list:hover {
  color: #111111;
}

.wishlist-drawer__empty {
  min-height: 220px;
  display: grid;
  place-items: center;
  align-content: center;
}

.wishlist-drawer__auth-button {
  width: 100%;
  margin-top: 8px;
}

.wishlist-drawer-enter-active,
.wishlist-drawer-leave-active {
  transition: opacity 180ms ease;
}

.wishlist-drawer-enter-active .wishlist-drawer__panel,
.wishlist-drawer-leave-active .wishlist-drawer__panel {
  transition: transform 220ms ease;
}

.wishlist-drawer-enter-from,
.wishlist-drawer-leave-to {
  opacity: 0;
}

.wishlist-drawer-enter-from .wishlist-drawer__panel,
.wishlist-drawer-leave-to .wishlist-drawer__panel {
  transform: translateX(100%);
}

@media (max-width: 720px) {
  .wishlist-drawer__panel {
    width: 100vw;
    border-left: 0;
  }

  .wishlist-drawer__item {
    grid-template-columns: 72px minmax(0, 1fr);
  }

  .wishlist-drawer__item-controls {
    grid-column: 2;
    width: 100%;
    grid-template-columns: minmax(0, 1fr) auto;
    align-items: center;
  }

  .wishlist-drawer__add {
    width: 100%;
  }
}
</style>
