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
    <IonContent :fullscreen="true">
      <div>
        <section>
          <div>
            <p>Cart</p>
            <h1>Shporta juaj ne format mobile.</h1>
          </div>

          <button data-testid="cart-wishlist-link" type="button" @click="router.push('/tabs/wishlist')">
            <IonIcon :icon="heartOutline" />
            <span>Wishlist</span>
          </button>
        </section>

        <section v-if="!sessionState.sessionLoaded">
          <IonSpinner name="crescent" />
        </section>

        <EmptyStatePanel
          v-else-if="!sessionState.user"
          title="Kyçu per te pare cart"
          copy="Per te vazhduar blerjen ne app, hyni me account-in ekzistues."
         
        >
          <div>
            <IonButton data-testid="cart-login-button" @click="router.push('/login?redirect=/tabs/cart')">
              Login
            </IonButton>
            <IonButton data-testid="cart-signup-button" @click="router.push('/signup?redirect=/tabs/cart')">
              Sign up
            </IonButton>
          </div>
        </EmptyStatePanel>

        <template v-else-if="items.length">
          <section>
            <article v-for="item in items" :key="item.id">
              <img :src="getProductImage(item)" :alt="item.title">

              <div>
                <p>{{ item.businessName || "TREGIO" }}</p>
                <h3>{{ item.title }}</h3>
                <strong>{{ formatPrice(item.price) }}</strong>
                <span>Sasia: {{ item.quantity || 1 }}</span>
              </div>

              <button type="button" @click="handleRemove(item.id)">
                <IonIcon :icon="trashOutline" />
              </button>
            </article>
          </section>

          <section>
            <div>
              <p>Subtotal</p>
              <h2>{{ formatPrice(subtotal) }}</h2>
            </div>

          <IonButton data-testid="cart-checkout-button" @click="handleCheckout">
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

