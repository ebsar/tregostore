<script setup>
import { computed, onBeforeUnmount, onMounted, watch } from "vue";
import { useRoute } from "vue-router";
import LoaderOverlay from "./components/LoaderOverlay.vue";
import LoginGreetingToast from "./components/LoginGreetingToast.vue";
import SiteNav from "./components/SiteNav.vue";
import { appState, ensureSessionLoaded, syncGreetingToastFromSession } from "./stores/app-state";

const route = useRoute();
let lockedScrollY = 0;

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

watch(
  () => appState.loaderVisible,
  (isVisible) => {
    if (isVisible) {
      lockedScrollY = window.scrollY || window.pageYOffset || 0;
      document.body.classList.add("app-loading");
      document.body.style.top = `-${lockedScrollY}px`;
      document.body.style.left = "0";
      document.body.style.right = "0";
      document.body.style.width = "100%";
      document.body.style.position = "fixed";
      return;
    }

    document.body.classList.remove("app-loading");
    document.body.style.position = "";
    document.body.style.top = "";
    document.body.style.left = "";
    document.body.style.right = "";
    document.body.style.width = "";
    window.scrollTo(0, lockedScrollY);
  },
  { immediate: true },
);

onMounted(async () => {
  syncGreetingToastFromSession();
  await ensureSessionLoaded();
});

onBeforeUnmount(() => {
  document.body.classList.remove("app-loading");
  document.body.style.position = "";
  document.body.style.top = "";
  document.body.style.left = "";
  document.body.style.right = "";
  document.body.style.width = "";
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
