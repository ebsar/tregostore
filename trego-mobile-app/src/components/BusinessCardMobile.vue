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
  <article>
    <div>
      <button type="button" @click="emit('open')">
        <div>
          <SmartImageMobile v-if="logoUrl" :src="logoUrl" :alt="business.businessName" />
          <IonIcon v-else :icon="storefrontOutline" />
          <span v-if="isVerified">
            <IonIcon :icon="checkmarkCircle" />
          </span>
        </div>

        <div>
          <h3>{{ business.businessName }}</h3>
          <p>{{ businessCity }}</p>
        </div>
      </button>

      <div>
        <button
         
          data-testid="business-follow-button"
         
          type="button"
          :disabled="followBusy"
          @click="emit('follow')"
        >
          {{ business.isFollowed ? "Following" : "Follow" }}
        </button>

        <button data-testid="business-message-button" type="button" @click="emit('message')">
          <IonIcon :icon="chatbubbleEllipsesOutline" />
        </button>
      </div>
    </div>

    <div v-if="previewProducts.length">
      <button
        v-for="product in previewProducts"
        :key="product.id"
       
        type="button"
        @click="emit('open-product', product.id)"
      >
        <SmartImageMobile :src="getProductImage(product)" :alt="product.title" fit="contain" />
        <span>{{ formatPrice(product.price) }}</span>
      </button>
    </div>

  </article>
</template>

