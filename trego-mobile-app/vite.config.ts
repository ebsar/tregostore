import { defineConfig, loadEnv } from "vite";
import vue from "@vitejs/plugin-vue";

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), "");
  const target = String(env.VITE_API_BASE_URL || "https://www.tregos.store").trim().replace(/\/+$/, "");

  return {
    plugins: [vue()],
    build: {
      chunkSizeWarningLimit: 750,
      rollupOptions: {
        output: {
          manualChunks(id) {
            if (!id.includes("node_modules")) {
              return undefined;
            }

            if (id.includes("/node_modules/ionicons/")) {
              return "ionicons";
            }

            if (id.includes("/node_modules/@ionic/core/")) {
              const ionicPath = id.split("/node_modules/@ionic/core/")[1] || "";

              if (
                /ion-(tab|tabs|router|route|nav|back-button)|swipe-back|framework-delegate/.test(ionicPath)
              ) {
                return "ionic-navigation";
              }

              if (
                /ion-(input|searchbar|select|textarea|radio|checkbox|toggle|range|segment|picker)|keyboard|validity|compare-with-utils/.test(
                  ionicPath,
                )
              ) {
                return "ionic-forms";
              }

              if (/ion-(modal|popover|toast|alert|action-sheet|loading)|overlays|lock-controller/.test(ionicPath)) {
                return "ionic-overlays";
              }

              if (
                /ion-(content|header|footer|toolbar|buttons|button|page|app|item|list|label|text|card|grid|row|col|badge|chip|icon|spinner|refresher|infinite-scroll|split-pane)/.test(
                  ionicPath,
                )
              ) {
                return "ionic-ui";
              }

              return "ionic-core";
            }

            if (id.includes("/node_modules/@ionic/vue-router/")) {
              return "ionic-router";
            }

            if (id.includes("/node_modules/@ionic/vue/")) {
              return "ionic-vue";
            }

            if (id.includes("/node_modules/vue-router/")) {
              return "vue-router";
            }

            if (id.includes("/node_modules/vue/")) {
              return "vue-core";
            }

            if (id.includes("/node_modules/@capacitor/")) {
              return "capacitor-core";
            }

            if (id.includes("/node_modules/onesignal-cordova-plugin/")) {
              return "push-vendor";
            }

            return undefined;
          },
        },
      },
    },
    server: {
      host: true,
      port: 5178,
      proxy: {
        "/api": {
          target,
          changeOrigin: true,
          secure: true,
        },
      },
    },
  };
});
