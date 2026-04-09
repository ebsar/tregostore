<script setup lang="ts">
import { IonIcon } from "@ionic/vue";
import { imageOutline } from "ionicons/icons";
import { ref, watch } from "vue";

const props = withDefaults(defineProps<{
  src: string;
  alt: string;
  fit?: "cover" | "contain";
}>(), {
  fit: "cover",
});

const loaded = ref(false);
const failed = ref(false);

watch(
  () => props.src,
  () => {
    loaded.value = false;
    failed.value = false;
  },
  { immediate: true },
);

function handleLoad() {
  loaded.value = true;
}

function handleError() {
  loaded.value = true;
  failed.value = true;
}
</script>

<template>
  <div class="smart-image-mobile" :class="[`fit-${fit}`, { 'is-loaded': loaded, 'has-error': failed }]">
    <div v-if="!loaded" class="smart-image-mobile-placeholder mobile-shimmer" />

    <img
      v-show="!failed"
      :src="src"
      :alt="alt"
      loading="lazy"
      decoding="async"
      @load="handleLoad"
      @error="handleError"
    >

    <div v-if="failed" class="smart-image-mobile-fallback">
      <IonIcon :icon="imageOutline" />
    </div>
  </div>
</template>

<style scoped>
.smart-image-mobile {
  position: relative;
  width: 100%;
  height: 100%;
  overflow: hidden;
  background: rgba(255, 255, 255, 0.92);
}

.smart-image-mobile img,
.smart-image-mobile-placeholder,
.smart-image-mobile-fallback {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
}

.smart-image-mobile img {
  display: block;
}

.smart-image-mobile.fit-cover img {
  object-fit: cover;
}

.smart-image-mobile.fit-contain img {
  object-fit: contain;
  padding: 8px;
}

.smart-image-mobile-fallback {
  display: grid;
  place-items: center;
  color: rgba(148, 163, 184, 0.82);
}

.smart-image-mobile-fallback ion-icon {
  font-size: 1.4rem;
}

body[data-theme="dark"] .smart-image-mobile {
  background: rgba(15, 23, 42, 0.94);
}

body[data-theme="dark"] .smart-image-mobile-fallback {
  color: rgba(203, 213, 225, 0.68);
}
</style>
