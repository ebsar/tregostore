<script setup lang="ts">
import { IonButton, IonContent, IonIcon, IonPage, IonSpinner } from "@ionic/vue";
import { heart } from "ionicons/icons";
import { onMounted, ref } from "vue";
import { useRouter } from "vue-router";
import EmptyStatePanel from "../components/EmptyStatePanel.vue";
import ProductCardMobile from "../components/ProductCardMobile.vue";
import { addToCart, fetchWishlist, toggleWishlist } from "../lib/api";
import type { ProductItem } from "../types/models";
import { ensureSession, refreshCounts, sessionState } from "../stores/session";

const router = useRouter();
const items = ref<ProductItem[]>([]);

onMounted(async () => {
  await ensureSession();
  if (sessionState.user) {
    items.value = await fetchWishlist();
  }
});

async function reload() {
  items.value = await fetchWishlist();
  await refreshCounts();
}

async function handleWishlist(productId: number) {
  await toggleWishlist(productId);
  await reload();
}

async function handleAddToCart(productId: number) {
  await addToCart(productId, 1);
  await refreshCounts();
}
</script>

<template>
  <IonPage>
    <IonContent class="app-gradient" :fullscreen="true">
      <div class="mobile-page mobile-page--tabbed mobile-page--edge wishlist-page">
        <section v-if="!sessionState.sessionLoaded" class="surface-card empty-panel wishlist-loading-panel">
          <IonSpinner name="crescent" />
        </section>

        <EmptyStatePanel
          v-else-if="!sessionState.user"
          title="Kyçu per te pare wishlist"
          copy="App-i përdor po të njëjtin account dhe po të njëjtin koleksion si webfaqja."
          class="guest-tab-empty"
        >
          <div class="guest-tab-actions">
            <IonButton class="cta-button" @click="router.push('/login?redirect=/tabs/wishlist')">
              Login
            </IonButton>
            <IonButton class="ghost-button" @click="router.push('/signup')">
              Sign up
            </IonButton>
          </div>
        </EmptyStatePanel>

        <template v-else-if="items.length">
          <div class="wishlist-inline-head">
            <span class="wishlist-inline-title">Wishlist</span>
          </div>

          <div class="product-grid">
            <ProductCardMobile
              v-for="product in items"
              :key="product.id"
              :product="product"
              @open="(id) => router.push(`/product/${id}`)"
              @cart="handleAddToCart"
              @wishlist="handleWishlist"
            />
          </div>
        </template>

        <section v-else class="surface-card empty-panel wishlist-empty-shell">
          <IonIcon :icon="heart" />
          <h3>Wishlist eshte bosh</h3>
          <p>Sapo te ruash produkte, ato do te shfaqen ketu nga e njejta databaze.</p>
        </section>
      </div>
    </IonContent>
  </IonPage>
</template>

<style scoped>
.wishlist-page {
  gap: 14px;
}

.wishlist-loading-panel {
  display: grid;
  place-items: center;
  min-height: 180px;
}

.wishlist-inline-head {
  display: flex;
  justify-content: center;
}

.wishlist-inline-title {
  color: var(--trego-muted);
  font-size: 0.76rem;
  font-weight: 800;
  letter-spacing: 0.14em;
  text-transform: uppercase;
}

.wishlist-empty-shell {
  min-height: 260px;
  justify-items: center;
  align-content: center;
  text-align: center;
}

.wishlist-empty-shell ion-icon {
  color: #d64d63;
  font-size: 1.6rem;
}
</style>
