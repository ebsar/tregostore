<script setup lang="ts">
import { IonButton, IonContent, IonPage } from "@ionic/vue";
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
      <div class="mobile-page mobile-page--tabbed">
        <div class="compact-page-title">Wishlist</div>

        <EmptyStatePanel
          v-if="!sessionState.user"
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

        <div v-else-if="items.length" class="product-grid">
          <ProductCardMobile
            v-for="product in items"
            :key="product.id"
            :product="product"
            @open="(id) => router.push(`/product/${id}`)"
            @cart="handleAddToCart"
            @wishlist="handleWishlist"
          />
        </div>

        <EmptyStatePanel
          v-else
          title="Wishlist eshte bosh"
          copy="Sapo te ruash produkte, ato do te shfaqen ketu nga e njejta databaze."
        />
      </div>
    </IonContent>
  </IonPage>
</template>

<style scoped></style>
