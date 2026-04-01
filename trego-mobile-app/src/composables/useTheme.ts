import { computed, ref } from "vue";

export type ThemePreference = "system" | "light" | "dark";

const THEME_STORAGE_KEY = "trego_mobile_theme_preference";
const preference = ref<ThemePreference>("system");
const activeTheme = ref<"light" | "dark">("light");
let themeMediaQuery: MediaQueryList | null = null;
let initialized = false;

function readStoredPreference(): ThemePreference {
  if (typeof window === "undefined") {
    return "system";
  }

  try {
    const value = String(window.localStorage.getItem(THEME_STORAGE_KEY) || "").trim().toLowerCase();
    if (value === "light" || value === "dark" || value === "system") {
      return value;
    }
  } catch (error) {
    console.error(error);
  }

  return "system";
}

function resolveSystemTheme(): "light" | "dark" {
  if (typeof window === "undefined") {
    return "light";
  }

  if (!themeMediaQuery) {
    themeMediaQuery = window.matchMedia("(prefers-color-scheme: dark)");
  }

  return themeMediaQuery.matches ? "dark" : "light";
}

function applyTheme() {
  const nextTheme = preference.value === "system" ? resolveSystemTheme() : preference.value;
  activeTheme.value = nextTheme;

  if (typeof document === "undefined") {
    return;
  }

  document.documentElement.dataset.theme = nextTheme;
  document.body.dataset.theme = nextTheme;
  document.documentElement.style.colorScheme = nextTheme;
}

function handleSystemThemeChange() {
  if (preference.value === "system") {
    applyTheme();
  }
}

export function initTheme() {
  if (initialized || typeof window === "undefined") {
    return;
  }

  initialized = true;
  themeMediaQuery = window.matchMedia("(prefers-color-scheme: dark)");
  preference.value = readStoredPreference();
  applyTheme();
  themeMediaQuery.addEventListener("change", handleSystemThemeChange);
}

export function useTheme() {
  initTheme();

  const setThemePreference = (nextPreference: ThemePreference) => {
    preference.value = nextPreference;
    try {
      window.localStorage.setItem(THEME_STORAGE_KEY, nextPreference);
    } catch (error) {
      console.error(error);
    }
    applyTheme();
  };

  return {
    themePreference: computed(() => preference.value),
    activeTheme: computed(() => activeTheme.value),
    setThemePreference,
  };
}
