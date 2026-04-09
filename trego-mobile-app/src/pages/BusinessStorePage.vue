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
    <IonContent class="app-gradient" :fullscreen="true">
      <div class="mobile-page">
        <section v-if="loading" class="surface-card empty-panel">
          <IonSpinner name="crescent" />
        </section>

        <template v-else-if="business">
          <div class="page-back-anchor">
            <AppBackButton back-to="/tabs/home" />
          </div>
          <section class="surface-card surface-card--strong store-hero">
            <div class="store-hero-media">
              <img :src="heroImage" :alt="business.businessName" />
            </div>

            <div class="store-hero-copy">
              <div class="store-hero-title">
                <h1>{{ business.businessName }}</h1>
                <IonIcon
                  v-if="String(business.verificationStatus || '').trim().toLowerCase() === 'verified'"
                  :icon="checkmarkCircle"
                />
              </div>
              <p class="section-copy">
                {{ business.businessDescription || business.description || "Dyqan aktiv ne TREGIO marketplace." }}
              </p>

              <div class="meta-pill-row">
                <span class="meta-pill">
                  <IonIcon :icon="star" />
                  {{ Number(business.sellerRating || 0).toFixed(1) }}
                </span>
                <span class="meta-pill">{{ formatCount(business.productsCount || products.length) }} produkte</span>
                <span v-if="business.city" class="meta-pill">
                  <IonIcon :icon="locationOutline" />
                  {{ business.city }}
                </span>
              </div>

              <p v-if="messageError" class="section-copy store-error">{{ messageError }}</p>

              <div class="action-row">
                <IonButton class="cta-button" @click="handleMessageBusiness">
                  <IonIcon slot="start" :icon="chatbubbleEllipsesOutline" />
                  Mesazh
                </IonButton>
              </div>
            </div>
          </section>

          <section class="stack-list">
            <div class="section-head">
              <h2>Produktet e dyqanit</h2>
            </div>

            <div class="catalog-grid">
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

<style scoped>
.store-hero {
  padding: 14px;
}

.store-hero-media {
  overflow: hidden;
  border-radius: 26px;
  aspect-ratio: 1.38;
}

.store-hero-media img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
}

.store-hero-copy {
  display: grid;
  gap: 12px;
  padding-top: 14px;
}

.store-hero-title {
  display: flex;
  align-items: center;
  gap: 8px;
}

.store-hero-title h1 {
  margin: 0;
  color: var(--trego-dark);
  font-size: 1.35rem;
  line-height: 1.05;
}

.store-hero-title ion-icon {
  color: #22c55e;
  font-size: 1rem;
}

.store-error {
  color: var(--trego-danger);
}

.catalog-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 14px;
}
</style>
