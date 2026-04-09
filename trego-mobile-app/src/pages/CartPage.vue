<script setup lang="ts">
import { IonButton, IonContent, IonIcon, IonPage, IonSpinner } from "@ionic/vue";
import { arrowForwardOutline, heartOutline, trashOutline } from "ionicons/icons";
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

async function handleRemove(cartLineId: number) {
  await removeFromCart(cartLineId);
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
      <div class="mobile-page mobile-page--tabbed mobile-page--edge cart-page">
        <section class="surface-card cart-page-hero">
          <div class="cart-page-hero-copy">
            <p class="section-kicker">Cart</p>
            <h1>Shporta juaj ne format mobile.</h1>
          </div>

          <button class="cart-page-wishlist" data-testid="cart-wishlist-link" type="button" @click="router.push('/tabs/wishlist')">
            <IonIcon :icon="heartOutline" />
            <span>Wishlist</span>
          </button>
        </section>

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
            <IonButton class="cta-button" data-testid="cart-login-button" @click="router.push('/login?redirect=/tabs/cart')">
              Login
            </IonButton>
            <IonButton class="ghost-button" data-testid="cart-signup-button" @click="router.push('/signup?redirect=/tabs/cart')">
              Sign up
            </IonButton>
          </div>
        </EmptyStatePanel>

        <template v-else-if="items.length">
          <section class="stack-list">
            <article v-for="item in items" :key="item.id" class="surface-card cart-line">
              <img :src="getProductImage(item)" :alt="item.title">

              <div class="cart-line-copy">
                <p>{{ item.businessName || "TREGIO" }}</p>
                <h3>{{ item.title }}</h3>
                <strong>{{ formatPrice(item.price) }}</strong>
                <span>Sasia: {{ item.quantity || 1 }}</span>
              </div>

              <button class="cart-line-remove" type="button" @click="handleRemove(item.id)">
                <IonIcon :icon="trashOutline" />
              </button>
            </article>
          </section>

          <section class="surface-card surface-card--strong summary-surface-card cart-summary-card">
            <div>
              <p class="section-kicker">Subtotal</p>
              <h2>{{ formatPrice(subtotal) }}</h2>
            </div>

          <IonButton class="cta-button cart-summary-button" data-testid="cart-checkout-button" @click="handleCheckout">
            Checkout
            <IonIcon slot="end" :icon="arrowForwardOutline" />
          </IonButton>
          </section>
        </template>

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
.cart-page {
  gap: 14px;
}

.cart-page-hero {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 14px;
}

.cart-page-hero-copy {
  display: grid;
  gap: 5px;
}

.cart-page-hero-copy h1 {
  margin: 0;
  color: var(--trego-dark);
  font-size: 1.18rem;
  line-height: 1.06;
}

.cart-page-wishlist {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  min-height: 40px;
  padding: 0 14px;
  border: 1px solid rgba(255, 255, 255, 0.56);
  border-radius: 999px;
  background:
    linear-gradient(180deg, rgba(255, 255, 255, 0.24), rgba(255, 255, 255, 0.08));
  color: var(--trego-dark);
  font-size: 0.78rem;
  font-weight: 800;
  box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.72);
}

.cart-page-wishlist ion-icon {
  color: var(--trego-accent);
  font-size: 0.95rem;
}

.cart-loading-panel {
  display: grid;
  place-items: center;
  min-height: 180px;
}

.cart-line {
  position: relative;
  display: grid;
  grid-template-columns: 88px minmax(0, 1fr) auto;
  gap: 12px;
  padding: 12px;
  align-items: start;
}

.cart-line img {
  width: 88px;
  height: 88px;
  border-radius: 22px;
  object-fit: cover;
}

.cart-line-copy {
  display: grid;
  gap: 4px;
}

.cart-line-copy h3,
.cart-line-copy p,
.cart-line-copy strong,
.cart-line-copy span {
  margin: 0;
}

.cart-line-copy p,
.cart-line-copy span {
  color: var(--trego-muted);
  font-size: 0.76rem;
}

.cart-line-copy h3 {
  color: var(--trego-dark);
  font-size: 0.95rem;
  line-height: 1.18;
}

.cart-line-copy strong {
  color: var(--trego-accent);
  font-size: 0.95rem;
}

.cart-line-remove {
  display: inline-flex;
  width: 34px;
  height: 34px;
  align-items: center;
  justify-content: center;
  border: 1px solid var(--trego-input-border);
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.72);
  color: #d15a52;
}

.cart-summary-card {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 14px;
}

.cart-summary-card h2 {
  margin: 0;
  color: var(--trego-dark);
}

.cart-summary-button {
  min-width: 144px;
}
</style>
