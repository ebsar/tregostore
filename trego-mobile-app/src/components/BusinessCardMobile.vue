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
  <article class="trego-business-card">
    <div class="trego-business-card__header">
      <button class="trego-business-card__identity" type="button" @click="emit('open')">
        <div class="trego-business-card__logo">
          <SmartImageMobile v-if="logoUrl" :src="logoUrl" :alt="business.businessName" />
          <IonIcon v-else :icon="storefrontOutline" />
          <span v-if="isVerified" class="trego-business-card__verified">
            <IonIcon :icon="checkmarkCircle" />
          </span>
        </div>

        <div class="trego-business-card__copy">
          <h3>{{ business.businessName }}</h3>
          <p>{{ businessCity }}</p>
        </div>
      </button>

      <div class="trego-business-card__actions">
        <button
          class="trego-business-card__follow"
          data-testid="business-follow-button"
          type="button"
          :disabled="followBusy"
          @click="emit('follow')"
        >
          {{ business.isFollowed ? "Following" : "Follow" }}
        </button>

        <button class="trego-business-card__message" data-testid="business-message-button" type="button" @click="emit('message')">
          <IonIcon :icon="chatbubbleEllipsesOutline" />
        </button>
      </div>
    </div>

    <div v-if="previewProducts.length" class="trego-business-card__products">
      <button
        v-for="product in previewProducts"
        :key="product.id"
        class="trego-business-card__product"
        type="button"
        @click="emit('open-product', product.id)"
      >
        <SmartImageMobile :src="getProductImage(product)" :alt="product.title" fit="contain" />
        <span>{{ formatPrice(product.price) }}</span>
      </button>
    </div>

  </article>
</template>
