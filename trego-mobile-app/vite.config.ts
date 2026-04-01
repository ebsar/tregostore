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
          manualChunks: {
            "ionic-vendor": ["@ionic/vue", "@ionic/vue-router", "ionicons"],
            "vue-vendor": ["vue", "vue-router"],
            "capacitor-vendor": ["@capacitor/core", "@capacitor/app", "@capacitor/status-bar"],
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
