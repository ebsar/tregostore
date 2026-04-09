<script setup lang="ts">
import { IonIcon } from "@ionic/vue";
import { chatbubbleEllipsesOutline, checkmarkCircle, storefrontOutline } from "ionicons/icons";
import { computed } from "vue";
import type { BusinessItem, ProductItem } from "../types/models";
import { API_BASE_URL } from "../lib/config";
import { formatPrice, getProductImage } from "../lib/format";
import SmartImageMobile from "./SmartImageMobile.vue";

const props = withDefaults(defineProps<{
  business: BusinessItem;
  previewProducts?: ProductItem[];
  followBusy?: boolean;
}>(), {
  previewProducts: () => [],
  followBusy: false,
});

const emit = defineEmits<{
  (event: "open"): void;
  (event: "follow"): void;
  (event: "message"): void;
  (event: "open-product", productId: number): void;
}>();

const logoUrl = computed(() => {
  const path = String(props.business.logoPath || "").trim();
  if (!path) {
    return "";
  }

  if (/^https?:\/\//i.test(path)) {
    return path;
  }

  return `${API_BASE_URL}${path.startsWith("/") ? path : `/${path}`}`;
});

const businessCity = computed(() =>
  String(props.business.city || props.business.category || "Marketplace business").trim(),
);

const isVerified = computed(() =>
  String(props.business.verificationStatus || "").trim().toLowerCase() === "verified",
);
</script>

<template>
  <article class="business-card-mobile surface-card">
    <div class="business-card-mobile-head">
      <button class="business-card-mobile-profile" type="button" @click="emit('open')">
        <div class="business-card-mobile-avatar">
          <SmartImageMobile v-if="logoUrl" :src="logoUrl" :alt="business.businessName" />
          <IonIcon v-else :icon="storefrontOutline" />
          <span v-if="isVerified" class="business-card-mobile-verified">
            <IonIcon :icon="checkmarkCircle" />
          </span>
        </div>

        <div class="business-card-mobile-copy">
          <h3>{{ business.businessName }}</h3>
          <p>{{ businessCity }}</p>
        </div>
      </button>

      <div class="business-card-mobile-actions">
        <button
          class="business-card-mobile-follow"
          data-testid="business-follow-button"
          :class="{ 'is-active': business.isFollowed }"
          type="button"
          :disabled="followBusy"
          @click="emit('follow')"
        >
          {{ business.isFollowed ? "Following" : "Follow" }}
        </button>

        <button class="business-card-mobile-message" data-testid="business-message-button" type="button" @click="emit('message')">
          <IonIcon :icon="chatbubbleEllipsesOutline" />
        </button>
      </div>
    </div>

    <div v-if="previewProducts.length" class="business-card-mobile-rail">
      <button
        v-for="product in previewProducts"
        :key="product.id"
        class="business-card-mobile-product"
        type="button"
        @click="emit('open-product', product.id)"
      >
        <SmartImageMobile :src="getProductImage(product)" :alt="product.title" fit="contain" />
        <span>{{ formatPrice(product.price) }}</span>
      </button>
    </div>

  </article>
</template>

<style scoped>
.business-card-mobile {
  display: grid;
  gap: 14px;
  padding: 14px;
  border-radius: 28px;
  background:
    linear-gradient(180deg, rgba(255, 255, 255, 0.94), rgba(255, 255, 255, 0.82)),
    radial-gradient(circle at top right, rgba(255, 255, 255, 0.56), transparent 26%);
  box-shadow:
    0 18px 36px rgba(31, 41, 55, 0.08),
    inset 0 1px 0 rgba(255, 255, 255, 0.84);
}

.business-card-mobile-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

.business-card-mobile-profile {
  min-width: 0;
  display: grid;
  grid-template-columns: 70px minmax(0, 1fr);
  gap: 12px;
  align-items: center;
  border: 0;
  padding: 0;
  background: transparent;
  text-align: left;
}

.business-card-mobile-avatar {
  position: relative;
  display: flex;
  width: 70px;
  height: 70px;
  align-items: center;
  justify-content: center;
  overflow: hidden;
  border-radius: 24px;
  background:
    linear-gradient(180deg, rgba(255, 255, 255, 0.36), rgba(255, 255, 255, 0.12)),
    linear-gradient(135deg, rgba(255, 106, 43, 0.22), rgba(47, 52, 70, 0.08));
  border: 1px solid var(--trego-input-border);
  box-shadow: 0 14px 30px rgba(31, 41, 55, 0.1);
}

.business-card-mobile-avatar img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.business-card-mobile-avatar ion-icon {
  color: var(--trego-accent);
  font-size: 1.8rem;
}

.business-card-mobile-verified {
  position: absolute;
  right: 6px;
  bottom: 6px;
  display: inline-flex;
  width: 20px;
  height: 20px;
  align-items: center;
  justify-content: center;
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.9);
  box-shadow: 0 8px 16px rgba(31, 41, 55, 0.16);
}

.business-card-mobile-verified ion-icon {
  color: #22c55e;
  font-size: 0.88rem;
}

.business-card-mobile-copy {
  display: grid;
  gap: 5px;
}

.business-card-mobile-copy h3,
.business-card-mobile-copy p {
  margin: 0;
}

.business-card-mobile-copy h3 {
  color: var(--trego-dark);
  font-size: 1rem;
  line-height: 1.1;
  font-weight: 800;
}

.business-card-mobile-copy p {
  color: var(--trego-muted);
  font-size: 0.8rem;
}

.business-card-mobile-actions {
  display: flex;
  align-items: center;
  gap: 8px;
}

.business-card-mobile-follow,
.business-card-mobile-message,
.business-card-mobile-product {
  border: 0;
  font: inherit;
}

.business-card-mobile-follow,
.business-card-mobile-message {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-height: 38px;
  border-radius: 999px;
  border: 1px solid var(--trego-input-border);
  background:
    linear-gradient(180deg, rgba(255, 255, 255, 0.34), rgba(255, 255, 255, 0.16));
  color: var(--trego-dark);
  box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.72);
}

.business-card-mobile-follow {
  min-width: 84px;
  padding: 0 14px;
  font-size: 0.76rem;
  font-weight: 800;
}

.business-card-mobile-follow.is-active {
  background: linear-gradient(135deg, rgba(255, 126, 64, 0.96), rgba(255, 106, 43, 0.88));
  border-color: rgba(255, 140, 89, 0.42);
  color: #fffef9;
}

.business-card-mobile-message {
  width: 38px;
  padding: 0;
}

.business-card-mobile-message ion-icon {
  font-size: 1rem;
}

.business-card-mobile-rail {
  display: grid;
  grid-auto-flow: column;
  grid-auto-columns: 110px;
  gap: 10px;
  overflow-x: auto;
  padding-bottom: 2px;
  scrollbar-width: none;
}

.business-card-mobile-rail::-webkit-scrollbar {
  display: none;
}

.business-card-mobile-product {
  display: grid;
  gap: 8px;
  padding: 8px;
  border-radius: 18px;
  background: rgba(255, 255, 255, 0.58);
  text-align: left;
}

.business-card-mobile-product img {
  width: 100%;
  height: 88px;
  border-radius: 14px;
  object-fit: cover;
}

.business-card-mobile-product span {
  color: var(--trego-accent);
  font-size: 0.76rem;
  font-weight: 800;
}
</style>
