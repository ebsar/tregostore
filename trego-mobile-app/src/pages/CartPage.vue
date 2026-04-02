<script setup lang="ts">
import { IonButton, IonContent, IonPage, IonSpinner } from "@ionic/vue";
import { computed, onMounted, ref } from "vue";
import { useRouter } from "vue-router";
import EmptyStatePanel from "../components/EmptyStatePanel.vue";
import { persistCheckoutSelectedCartIds } from "../lib/checkout";
import { fetchCart, removeFromCart } from "../lib/api";
import { formatPrice, getProductImage } from "../lib/format";
import type { CartItem } from "../types/models";
import { ensureSession, refreshCounts, sessionState } from "../stores/session";

const router = useRouter();
const items = ref<CartItem[]>([]);

const subtotal = computed(() =>
  items.value.reduce(
    (total, item) => total + (Number(item.price || 0) * Math.max(1, Number(item.quantity || 1))),
    0,
  ),
);

onMounted(async () => {
  await ensureSession();
  if (sessionState.user) {
    items.value = await fetchCart();
  }
});

async function handleRemove(productId: number) {
  await removeFromCart(productId);
  items.value = await fetchCart();
  await refreshCounts();
}

function handleCheckout() {
  if (!items.value.length) {
    return;
  }

  persistCheckoutSelectedCartIds(items.value.map((item) => item.id));
  router.push("/checkout/address");
}
</script>

<template>
  <IonPage>
    <IonContent class="app-gradient" :fullscreen="true">
      <div class="mobile-page mobile-page--tabbed">
        <div class="compact-page-title">Cart</div>

        <section v-if="!sessionState.sessionLoaded" class="surface-card empty-panel cart-loading-panel">
          <IonSpinner name="crescent" />
        </section>

        <EmptyStatePanel
          v-else-if="!sessionState.user"
          title="Kyçu per te pare cart"
          copy="Per te vazhduar blerjen ne app, hyni me account-in ekzistues."
          class="guest-tab-empty"
        >
          <div class="guest-tab-actions">
            <IonButton class="cta-button" @click="router.push('/login?redirect=/tabs/cart')">
              Login
            </IonButton>
            <IonButton class="ghost-button" @click="router.push('/signup')">
              Sign up
            </IonButton>
          </div>
        </EmptyStatePanel>

        <section v-else-if="items.length" class="stack-list">
          <article v-for="item in items" :key="item.id" class="surface-card cart-line">
            <img :src="getProductImage(item)" :alt="item.title" />
            <div class="cart-line-copy">
              <h3>{{ item.title }}</h3>
              <p>{{ item.businessName || "TREGO" }}</p>
              <strong>{{ formatPrice(item.price) }}</strong>
              <span>Sasia: {{ item.quantity || 1 }}</span>
            </div>
            <IonButton fill="clear" @click="handleRemove(item.productId || item.id)">Hiqe</IonButton>
          </article>

          <section class="surface-card surface-card--strong summary-surface-card">
            <div class="section-head">
              <div>
                <p class="section-kicker">Subtotal</p>
                <h2>{{ formatPrice(subtotal) }}</h2>
              </div>
              <IonButton class="cta-button" @click="handleCheckout">Checkout</IonButton>
            </div>
          </section>
        </section>

        <EmptyStatePanel
          v-else
          title="Cart eshte bosh"
          copy="Sapo te shtosh artikuj ne web ose app, ato do te shfaqen ketu automatikisht."
        />
      </div>
    </IonContent>
  </IonPage>
</template>

<style scoped>
.cart-loading-panel {
  display: grid;
  place-items: center;
  min-height: 180px;
}

.cart-line {
  display: grid;
  grid-template-columns: 84px minmax(0, 1fr);
  gap: 14px;
  padding: 12px;
}

.cart-line img {
  width: 84px;
  height: 84px;
  border-radius: 20px;
  object-fit: cover;
}

.cart-line-copy {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.cart-line-copy h3,
.cart-line-copy p,
.cart-line-copy strong,
.cart-line-copy span {
  margin: 0;
}

.cart-line-copy h3 {
  color: var(--trego-dark);
  font-size: 1rem;
}

.cart-line-copy p,
.cart-line-copy span {
  color: var(--trego-muted);
}
</style>
