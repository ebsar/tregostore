import { defineConfig } from "vite";
import vue from "@vitejs/plugin-vue";

export default defineConfig({
  plugins: [vue()],
  publicDir: "public",
  build: {
    target: "es2020",
    cssCodeSplit: true,
    assetsInlineLimit: 4096,
    sourcemap: false,
    rollupOptions: {
      output: {
        manualChunks(id) {
          if (id.includes("@vercel/speed-insights")) {
            return "observability";
          }
          if (id.includes("node_modules")) {
            if (id.includes("vue") || id.includes("vue-router")) {
              return "vendor-core";
            }
            return "vendor-lib";
          }
          return undefined;
        },
      },
    },
  },
  server: {
    proxy: {
      "/api": {
        target: "http://127.0.0.1:8000",
        changeOrigin: true,
      },
      "/uploads": {
        target: "http://127.0.0.1:8000",
        changeOrigin: true,
      },
    },
  },
});
