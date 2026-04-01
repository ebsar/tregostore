<script setup lang="ts">
import { IonIcon } from "@ionic/vue";
import { arrowBackOutline } from "ionicons/icons";
import { useRouter } from "vue-router";

const props = withDefaults(defineProps<{
  backTo?: string;
}>(), {
  backTo: "/tabs/home",
});

const router = useRouter();

function handleBack() {
  if (typeof window !== "undefined" && window.history.length > 1) {
    router.back();
    return;
  }

  router.replace(props.backTo);
}
</script>

<template>
  <button class="app-back-button" type="button" @click="handleBack">
    <IonIcon :icon="arrowBackOutline" />
  </button>
</template>

<style scoped>
.app-back-button {
  position: relative;
  z-index: 5;
  display: inline-flex;
  width: 46px;
  height: 46px;
  align-items: center;
  justify-content: center;
  margin-left: -2px;
  border: 1px solid rgba(255, 255, 255, 0.74);
  border-radius: 999px;
  background:
    linear-gradient(180deg, rgba(255, 255, 255, 0.34), rgba(255, 255, 255, 0.12)),
    radial-gradient(circle at 18% 0%, rgba(255, 255, 255, 0.42), transparent 30%),
    radial-gradient(circle at 100% 100%, rgba(161, 222, 255, 0.12), transparent 34%);
  box-shadow:
    0 14px 32px rgba(31, 41, 55, 0.1),
    inset 0 1px 0 rgba(255, 255, 255, 0.9),
    inset 0 -12px 18px rgba(255, 255, 255, 0.04);
  backdrop-filter: blur(24px) saturate(175%);
  -webkit-backdrop-filter: blur(24px) saturate(175%);
  color: var(--trego-dark);
}

.app-back-button ion-icon {
  font-size: 1.12rem;
}

body[data-theme="dark"] .app-back-button {
  border-color: rgba(255, 255, 255, 0.14);
  background:
    linear-gradient(180deg, rgba(18, 18, 20, 0.8), rgba(10, 10, 12, 0.44)),
    radial-gradient(circle at 18% 0%, rgba(255, 255, 255, 0.08), transparent 30%);
  color: var(--trego-text);
}
</style>
