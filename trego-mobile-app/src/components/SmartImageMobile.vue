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
  <div>
    <div v-if="!loaded" />

    <img
      v-show="!failed"
      :src="src"
      :alt="alt"
      loading="lazy"
      decoding="async"
      @load="handleLoad"
      @error="handleError"
    >

    <div v-if="failed">
      <IonIcon :icon="imageOutline" />
    </div>
  </div>
</template>

