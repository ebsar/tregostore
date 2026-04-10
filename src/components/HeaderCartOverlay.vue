<script setup>
import { computed, onMounted, reactive, ref } from "vue";
import { useRouter } from "vue-router";
import { requestJson, resolveApiMessage } from "../lib/api";
import { formatPrice, hasProductAvailableStock } from "../lib/shop";
import { appState, setCartItems } from "../stores/app-state";

const emit = defineEmits(["close", "request-login"]);

const router = useRouter();
const items = ref([]);
const ui = reactive({
  loading: false,
  message: "",
  type: "",
});

const isAuthenticated = computed(() => Boolean(appState.user));
const subtotal = computed(() =>
  items.value.reduce((total, item) => total + ((Number(item.price) || 0) * Math.max(1, Number(item.quantity) || 1)), 0),
);
const totalItems = computed(() =>
  items.value.reduce((total, item) => total + Math.max(1, Number(item.quantity) || 1), 0),
);

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
  } catch (error) {
    ui.message = "Serveri nuk po pergjigjet. Provoje perseri.";
    ui.type = "error";
    console.error(error);
  } finally {
    ui.loading = false;
  }
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

  ui.message = data.message || "Produkti u hoq nga shporta.";
  ui.type = "success";
  await loadItems();
}

async function changeQuantity(productId, nextQuantity) {
  const quantity = Math.max(1, Number(nextQuantity) || 1);
  const { response, data } = await requestJson("/api/cart/quantity", {
    method: "POST",
    body: JSON.stringify({ productId, quantity }),
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

function handleQuantityInput(productId, event) {
  void changeQuantity(productId, event?.target?.value || 1);
}

async function openCartPage() {
  emit("close");
  await router.push("/cart");
}

async function continueToCheckout() {
  emit("close");
  await router.push("/cart");
}
</script>

<template>
  <div class="header-cart-overlay" @click.stop>
    <div class="header-cart-card">
      <button
        type="button"
        class="header-cart-close"
        aria-label="Close cart"
        @click="$emit('close')"
      >
        ×
      </button>

      <template v-if="!isAuthenticated">
        <div class="header-cart-empty">
          <h3>Cart</h3>
          <p>Per ta perdorur shporten, duhet te kyçesh ose të krijosh llogari.</p>
          <button type="button" class="header-cart-primary" @click="$emit('request-login')">
            HAP LOGIN
          </button>
        </div>
      </template>

      <template v-else>
        <div class="header-cart-head">
          <div>
            <p class="header-cart-eyebrow">Your cart</p>
            <h3>{{ totalItems }} item{{ totalItems === 1 ? "" : "s" }}</h3>
          </div>
          <button type="button" class="header-cart-link" @click="openCartPage">
            Open cart
          </button>
        </div>

        <p v-if="ui.message" class="header-cart-message" :class="`is-${ui.type}`">
          {{ ui.message }}
        </p>

        <div v-if="ui.loading" class="header-cart-state">Duke ngarkuar shporten...</div>

        <div v-else-if="items.length === 0" class="header-cart-empty">
          <p>Shporta jote eshte bosh.</p>
        </div>

        <div v-else class="header-cart-list">
          <article
            v-for="item in items"
            :key="item.id"
            class="header-cart-item"
          >
            <img
              class="header-cart-item-image"
              :src="item.imagePath"
              :alt="item.title"
              width="640"
              height="640"
              loading="lazy"
              decoding="async"
            >

            <div class="header-cart-item-copy">
              <strong>{{ item.title }}</strong>
              <p>{{ formatPrice(item.price) }} / per item</p>
              <span :class="{ 'is-unavailable': !hasProductAvailableStock(item) }">
                {{ hasProductAvailableStock(item) ? "Ne stok" : "Nuk ka ne stok" }}
              </span>
            </div>

            <div class="header-cart-item-side">
              <label class="header-cart-qty">
                <span>Qty</span>
                <select
                  class="header-cart-qty-input"
                  :value="Math.max(1, Number(item.quantity) || 1)"
                  @change="handleQuantityInput(item.id, $event)"
                >
                  <option v-for="qty in 10" :key="`${item.id}-${qty}`" :value="qty">
                    {{ qty }}
                  </option>
                </select>
              </label>
              <strong class="header-cart-line-total">
                {{ formatPrice((Number(item.price) || 0) * Math.max(1, Number(item.quantity) || 1)) }}
              </strong>
              <button type="button" class="header-cart-remove" @click="removeItem(item.id)">
                Remove
              </button>
            </div>
          </article>
        </div>

        <div v-if="items.length > 0" class="header-cart-summary">
          <div class="header-cart-summary-row">
            <span>Subtotal</span>
            <strong>{{ formatPrice(subtotal) }}</strong>
          </div>

          <div class="header-cart-actions">
            <button type="button" class="header-cart-secondary" @click="openCartPage">
              OPEN CART
            </button>
            <button type="button" class="header-cart-primary" @click="continueToCheckout">
              CHECKOUT
            </button>
          </div>
        </div>
      </template>
    </div>
  </div>
</template>

<style scoped>
.header-cart-overlay {
  width: min(760px, calc(100vw - 32px));
}

.header-cart-card {
  position: relative;
  display: grid;
  gap: 18px;
  padding: 28px;
  border-radius: 18px;
  background: #fff;
  border: 1px solid rgba(15, 23, 42, 0.08);
  box-shadow: 0 26px 60px rgba(15, 23, 42, 0.18);
}

.header-cart-close {
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

.header-cart-head {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 16px;
  padding-right: 44px;
}

.header-cart-head h3,
.header-cart-empty h3 {
  margin: 4px 0 0;
  color: #111827;
  font-size: 2rem;
  line-height: 1;
  letter-spacing: -0.04em;
}

.header-cart-eyebrow {
  margin: 0;
  color: #163b67;
  font-size: 0.8rem;
  font-weight: 800;
  letter-spacing: 0.12em;
  text-transform: uppercase;
}

.header-cart-link {
  padding: 0;
  border: 0;
  background: transparent;
  color: #163b67;
  font-weight: 800;
  cursor: pointer;
}

.header-cart-state,
.header-cart-empty p {
  margin: 0;
  color: #64748b;
  line-height: 1.6;
}

.header-cart-empty {
  display: grid;
  gap: 16px;
}

.header-cart-list {
  display: grid;
  gap: 14px;
  max-height: min(52vh, 520px);
  overflow-y: auto;
  padding-right: 4px;
}

.header-cart-item {
  display: grid;
  grid-template-columns: 92px minmax(0, 1fr) auto;
  gap: 14px;
  align-items: center;
  padding: 14px;
  border-radius: 16px;
  background: #f8fafc;
  border: 1px solid rgba(15, 23, 42, 0.06);
}

.header-cart-item-image {
  width: 92px;
  height: 92px;
  object-fit: cover;
  border-radius: 12px;
  background: #fff;
}

.header-cart-item-copy {
  display: grid;
  gap: 6px;
}

.header-cart-item-copy strong {
  color: #111827;
  line-height: 1.35;
}

.header-cart-item-copy p,
.header-cart-item-copy span {
  margin: 0;
  color: #64748b;
  font-size: 0.92rem;
}

.header-cart-item-copy span.is-unavailable {
  color: #dc2626;
}

.header-cart-item-side {
  display: grid;
  justify-items: end;
  gap: 8px;
}

.header-cart-qty {
  display: grid;
  gap: 6px;
  color: #64748b;
  font-size: 0.8rem;
  font-weight: 700;
}

.header-cart-qty-input {
  min-height: 40px;
  min-width: 86px;
  padding: 0 10px;
  border-radius: 10px;
  border: 1px solid rgba(15, 23, 42, 0.12);
  background: #fff;
}

.header-cart-line-total {
  color: #111827;
  font-size: 1rem;
}

.header-cart-remove {
  padding: 0;
  border: 0;
  background: transparent;
  color: #dc2626;
  font-weight: 700;
  cursor: pointer;
}

.header-cart-summary {
  display: grid;
  gap: 16px;
  padding-top: 6px;
  border-top: 1px solid rgba(15, 23, 42, 0.08);
}

.header-cart-summary-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  color: #334155;
}

.header-cart-summary-row strong {
  color: #111827;
  font-size: 1.05rem;
}

.header-cart-actions {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 10px;
}

.header-cart-primary,
.header-cart-secondary {
  min-height: 50px;
  width: 100%;
  border-radius: 0;
  font-size: 0.95rem;
  font-weight: 800;
  letter-spacing: 0.02em;
  cursor: pointer;
}

.header-cart-primary {
  border: 0;
  background: #163b67;
  color: #fff;
}

.header-cart-secondary {
  border: 1px solid rgba(22, 59, 103, 0.2);
  background: #eef4fb;
  color: #163b67;
}

.header-cart-message {
  margin: 0;
  font-size: 0.9rem;
}

.header-cart-message.is-error {
  color: #dc2626;
}

.header-cart-message.is-success {
  color: #059669;
}

@media (max-width: 760px) {
  .header-cart-overlay {
    width: min(100vw - 24px, 760px);
  }

  .header-cart-card {
    padding: 22px 18px;
  }

  .header-cart-item {
    grid-template-columns: 74px minmax(0, 1fr);
  }

  .header-cart-item-image {
    width: 74px;
    height: 74px;
  }

  .header-cart-item-side {
    grid-column: 1 / -1;
    grid-template-columns: repeat(3, auto);
    align-items: center;
    justify-content: space-between;
  }

  .header-cart-actions {
    grid-template-columns: 1fr;
  }
}
</style>
