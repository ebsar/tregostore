<script setup>
import { computed, onMounted, watch } from "vue";
import { useRoute } from "vue-router";
import LoaderOverlay from "./components/LoaderOverlay.vue";
import LoginGreetingToast from "./components/LoginGreetingToast.vue";
import SiteNav from "./components/SiteNav.vue";
import { appState, ensureSessionLoaded, syncGreetingToastFromSession } from "./stores/app-state";

const route = useRoute();

const shellClass = computed(() => route.meta.shellClass || "page-shell");
const mainClass = computed(() => route.meta.mainClass || "page-main");

watch(
  () => route.meta.pageKey,
  (pageKey) => {
    if (pageKey) {
      document.body.dataset.page = String(pageKey);
    } else {
      delete document.body.dataset.page;
    }
    document.body.classList.remove("dialog-open");
  },
  { immediate: true },
);

watch(
  () => route.meta.title,
  (title) => {
    document.title = String(title || "TREGO");
  },
  { immediate: true },
);

watch(
  () => route.fullPath,
  () => {
    syncGreetingToastFromSession();
  },
);

onMounted(async () => {
  syncGreetingToastFromSession();
  await ensureSessionLoaded();
});
</script>

<template>
  <LoaderOverlay v-if="appState.loaderVisible" />
  <LoginGreetingToast v-if="appState.loginGreeting" :message="appState.loginGreeting" />

  <div class="background-orb orb-left"></div>
  <div class="background-orb orb-right"></div>

  <div :class="shellClass">
    <SiteNav />

    <main :class="mainClass">
      <RouterView />
    </main>
  </div>
</template>
