import { createApp } from "vue";
import { IonicVue } from "@ionic/vue";
import { Capacitor } from "@capacitor/core";
import { StatusBar } from "@capacitor/status-bar";
import App from "./App.vue";
import router from "./router";
import { initTheme } from "./composables/useTheme";
import "./theme/tregio-mobile-system.css";

async function setupNativeChrome() {
  if (!Capacitor.isNativePlatform()) {
    return;
  }

  if (typeof document !== "undefined") {
    document.documentElement.dataset.platform = Capacitor.getPlatform();
    document.body.dataset.platform = Capacitor.getPlatform();
    document.documentElement.dataset.nativeAppShell = "1";
    document.body.dataset.nativeAppShell = "1";
  }

  try {
    await StatusBar.setOverlaysWebView({ overlay: true });
  } catch (error) {
    console.warn("Status bar setup skipped", error);
  }
}

initTheme();

function warmCriticalRoutes() {
  const warm = () => {
    void import("./pages/SearchPage.vue");
    void import("./pages/CartPage.vue");
    void import("./pages/AccountPage.vue");
  };

  if (typeof window !== "undefined" && "requestIdleCallback" in window) {
    window.requestIdleCallback(warm, { timeout: 1200 });
  } else {
    window.setTimeout(warm, 450);
  }
}

const app = createApp(App)
  .use(IonicVue)
  .use(router);

setupNativeChrome().finally(() => {
  app.mount("#app");
  void router.isReady().finally(() => {
    warmCriticalRoutes();
  });
});
