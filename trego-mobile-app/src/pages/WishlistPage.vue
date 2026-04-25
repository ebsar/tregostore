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
    <IonContent :fullscreen="true">
      <div>
        <section v-if="!sessionState.sessionLoaded">
          <IonSpinner name="crescent" />
        </section>

        <EmptyStatePanel
          v-else-if="!sessionState.user"
          title="Kyçu per te pare wishlist"
          copy="App-i përdor po të njëjtin account dhe po të njëjtin koleksion si webfaqja."
         
        >
          <div>
            <IonButton @click="router.push('/login?redirect=/tabs/wishlist')">
              Login
            </IonButton>
            <IonButton @click="router.push('/signup?redirect=/tabs/wishlist')">
              Sign up
            </IonButton>
          </div>
        </EmptyStatePanel>

        <template v-else-if="items.length">
          <div>
            <span>Wishlist</span>
          </div>

          <div>
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

        <section v-else>
          <IonIcon :icon="heart" />
          <h3>Wishlist eshte bosh</h3>
          <p>Sapo te ruash produkte, ato do te shfaqen ketu nga e njejta databaze.</p>
        </section>
      </div>
    </IonContent>
  </IonPage>
</template>

