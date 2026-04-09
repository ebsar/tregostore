import type { CapacitorConfig } from "@capacitor/cli";

const config: CapacitorConfig = {
  appId: "store.trego.mobile",
  appName: "Tregio",
  webDir: "dist",
  bundledWebRuntime: false,
  ios: {
    handleApplicationNotifications: false,
  },
  server: {
    androidScheme: "https",
  },
  plugins: {
    CapacitorHttp: {
      enabled: true,
    },
    CapacitorCookies: {
      enabled: true,
    },
    Keyboard: {
      resize: "none",
      resizeOnFullScreen: false,
    },
    SplashScreen: {
      launchShowDuration: 1400,
      backgroundColor: "#ffffff",
      showSpinner: false,
    },
    StatusBar: {
      style: "dark",
      backgroundColor: "#ffffff"
    }
  }
};

export default config;
