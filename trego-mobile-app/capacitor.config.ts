import type { CapacitorConfig } from "@capacitor/cli";

const config: CapacitorConfig = {
  appId: "store.trego.mobile",
  appName: "Trego Mobile",
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
      backgroundColor: "#f5f3f1",
      showSpinner: false,
    },
    StatusBar: {
      style: "dark",
      backgroundColor: "#f5f3f1"
    }
  }
};

export default config;
