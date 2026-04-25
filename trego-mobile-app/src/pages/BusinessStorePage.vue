<script setup lang="ts">
import { IonButton, IonContent, IonIcon, IonPage, IonSpinner } from "@ionic/vue";
import { chatbubbleEllipsesOutline, checkmarkCircle, locationOutline, star } from "ionicons/icons";
import { computed, onMounted, ref, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import AppBackButton from "../components/AppBackButton.vue";
import EmptyStatePanel from "../components/EmptyStatePanel.vue";
import ProductCardMobile from "../components/ProductCardMobile.vue";
import {
  addToCart,
  fetchPublicBusinessDetail,
  fetchPublicBusinessProducts,
  openBusinessConversation,
  toggleWishlist,
} from "../lib/api";
import { createApiUrl } from "../lib/config";
import { formatCount } from "../lib/format";
import type { BusinessItem, ProductItem } from "../types/models";
import { refreshCounts } from "../stores/session";

const route = useRoute();
const router = useRouter();
const loading = ref(true);
const business = ref<BusinessItem | null>(null);
const products = ref<ProductItem[]>([]);
const messageError = ref("");

const businessId = computed(() => {
  const value = Number(route.params.id || 0);
  return Number.isFinite(value) ? Math.max(0, value) : 0;
});

const heroImage = computed(() => {
  const rawValue = String(business.value?.logoPath || "").trim();
  if (!rawValue) {
    return "https://images.unsplash.com/photo-1556740749-887f6717d7e4?auto=format&fit=crop&w=1200&q=80";
  }
  return /^https?:\/\//i.test(rawValue)
    ? rawValue
    : createApiUrl(rawValue);
});

async function loadStore() {
  loading.value = true;
  messageError.value = "";
  try {
    const [detail, productList] = await Promise.all([
      fetchPublicBusinessDetail(businessId.value),
      fetchPublicBusinessProducts(businessId.value, 18, 0),
    ]);
    business.value = detail;
    products.value = productList;
  } finally {
    loading.value = false;
  }
}

async function handleAddToCart(productId: number) {
  await addToCart(productId, 1);
  await refreshCounts();
}

async function handleWishlist(productId: number) {
  await toggleWishlist(productId);
  await refreshCounts();
}

async function handleMessageBusiness() {
  if (!business.value) {
    return;
  }

  const { response, data } = await openBusinessConversation(Number(business.value.id));
  if (!response.ok || !data?.ok || !data?.conversation?.id) {
    messageError.value = String(data?.message || "Biseda nuk u hap.");
    return;
  }

  router.push(`/messages/${data.conversation.id}`);
}

onMounted(() => {
  void loadStore();
});

watch(
  () => route.params.id,
  () => {
    void loadStore();
  },
);
</script>

<template>
  <IonPage>
    <IonContent :fullscreen="true">
      <div>
        <section v-if="loading">
          <IonSpinner name="crescent" />
        </section>

        <template v-else-if="business">
          <div>
            <AppBackButton back-to="/tabs/home" />
          </div>
          <section>
            <div>
              <img :src="heroImage" :alt="business.businessName" />
            </div>

            <div>
              <div>
                <h1>{{ business.businessName }}</h1>
                <IonIcon
                  v-if="String(business.verificationStatus || '').trim().toLowerCase() === 'verified'"
                  :icon="checkmarkCircle"
                />
              </div>
              <p>
                {{ business.businessDescription || business.description || "Dyqan aktiv ne TREGIO marketplace." }}
              </p>

              <div>
                <span>
                  <IonIcon :icon="star" />
                  {{ Number(business.sellerRating || 0).toFixed(1) }}
                </span>
                <span>{{ formatCount(business.productsCount || products.length) }} produkte</span>
                <span v-if="business.city">
                  <IonIcon :icon="locationOutline" />
                  {{ business.city }}
                </span>
              </div>

              <p v-if="messageError">{{ messageError }}</p>

              <div>
                <IonButton @click="handleMessageBusiness">
                  <IonIcon slot="start" :icon="chatbubbleEllipsesOutline" />
                  Mesazh
                </IonButton>
              </div>
            </div>
          </section>

          <section>
            <div>
              <h2>Produktet e dyqanit</h2>
            </div>

            <div>
              <ProductCardMobile
                v-for="product in products"
                :key="product.id"
                :product="product"
                @open="(id) => router.push(`/product/${id}`)"
                @cart="handleAddToCart"
                @wishlist="handleWishlist"
              />
            </div>
          </section>
        </template>

        <EmptyStatePanel
          v-else
          title="Dyqani nuk u gjet"
          copy="Ky biznes mund te mos jete me publik ose lidhja me serverin deshtoi."
        />
      </div>
    </IonContent>
  </IonPage>
</template>

