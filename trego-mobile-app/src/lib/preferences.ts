const STORAGE_KEY = "trego-mobile-preferences";

export interface MobilePreferences {
  language: string;
  currency: string;
  notificationMode: string;
  privacyMode: string;
}

const DEFAULT_PREFERENCES: MobilePreferences = {
  language: "sq",
  currency: "EUR",
  notificationMode: "all",
  privacyMode: "standard",
};

export function readMobilePreferences(): MobilePreferences {
  if (typeof window === "undefined") {
    return { ...DEFAULT_PREFERENCES };
  }

  try {
    const parsed = JSON.parse(window.localStorage.getItem(STORAGE_KEY) || "{}");
    return {
      ...DEFAULT_PREFERENCES,
      ...(parsed && typeof parsed === "object" ? parsed : {}),
    };
  } catch {
    return { ...DEFAULT_PREFERENCES };
  }
}

export function writeMobilePreferences(nextPreferences: Partial<MobilePreferences>) {
  if (typeof window === "undefined") {
    return { ...DEFAULT_PREFERENCES, ...nextPreferences };
  }

  const merged = {
    ...readMobilePreferences(),
    ...nextPreferences,
  };
  window.localStorage.setItem(STORAGE_KEY, JSON.stringify(merged));
  return merged;
}
