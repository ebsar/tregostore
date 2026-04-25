<script setup lang="ts">
import { IonIcon } from "@ionic/vue";
import { arrowBackOutline } from "ionicons/icons";
import { useRoute, useRouter } from "vue-router";

const props = withDefaults(defineProps<{
  backTo?: string;
}>(), {
  backTo: "/tabs/home",
});

const router = useRouter();
const route = useRoute();

function handleBack() {
  const fallbackTarget = props.backTo;
  const currentPath = route.fullPath;
  const canUseHistory =
    typeof window !== "undefined" &&
    window.history.length > 1 &&
    Boolean(window.history.state?.back);

  if (canUseHistory) {
    void router.back();
    window.setTimeout(() => {
      if (route.fullPath === currentPath) {
        void router.replace(fallbackTarget);
      }
    }, 360);
    return;
  }

  void router.replace(fallbackTarget);
}
</script>

<template>
  <button type="button" @click="handleBack">
    <IonIcon :icon="arrowBackOutline" />
  </button>
</template>

