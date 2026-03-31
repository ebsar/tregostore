export const NAV_LIQUID_SETTINGS_STORAGE_KEY = "trego-nav-liquid-settings";
export const NAV_LIQUID_SETTINGS_CHANGE_EVENT = "trego:nav-liquid-settings-change";

export const NAV_LIQUID_DEFAULTS = Object.freeze({
  mode: "standard",
  displacementScale: 64,
});

export const NAV_LIQUID_MODE_OPTIONS = Object.freeze([
  { value: "standard", label: "Standard" },
  { value: "polar", label: "Polar" },
  { value: "prominent", label: "Prominent" },
  { value: "shader", label: "Shader" },
]);

function normalizeMode(value) {
  const nextValue = String(value || "").trim().toLowerCase();
  return NAV_LIQUID_MODE_OPTIONS.some((option) => option.value === nextValue)
    ? nextValue
    : NAV_LIQUID_DEFAULTS.mode;
}

function normalizeDisplacementScale(value) {
  const numericValue = Number(value);
  if (!Number.isFinite(numericValue)) {
    return NAV_LIQUID_DEFAULTS.displacementScale;
  }

  return Math.max(0, Math.min(1000, Math.round(numericValue)));
}

function canUseStorage() {
  return typeof window !== "undefined" && !!window.localStorage;
}

export function sanitizeNavLiquidSettings(value) {
  return {
    mode: normalizeMode(value?.mode),
    displacementScale: normalizeDisplacementScale(value?.displacementScale),
  };
}

export function readNavLiquidSettings() {
  if (!canUseStorage()) {
    return { ...NAV_LIQUID_DEFAULTS };
  }

  try {
    const rawValue = window.localStorage.getItem(NAV_LIQUID_SETTINGS_STORAGE_KEY);
    if (!rawValue) {
      return { ...NAV_LIQUID_DEFAULTS };
    }

    return sanitizeNavLiquidSettings(JSON.parse(rawValue));
  } catch (error) {
    console.error(error);
    return { ...NAV_LIQUID_DEFAULTS };
  }
}

export function writeNavLiquidSettings(partialSettings = {}) {
  const nextSettings = sanitizeNavLiquidSettings({
    ...readNavLiquidSettings(),
    ...partialSettings,
  });

  if (canUseStorage()) {
    try {
      window.localStorage.setItem(
        NAV_LIQUID_SETTINGS_STORAGE_KEY,
        JSON.stringify(nextSettings),
      );
      window.dispatchEvent(
        new CustomEvent(NAV_LIQUID_SETTINGS_CHANGE_EVENT, {
          detail: nextSettings,
        }),
      );
    } catch (error) {
      console.error(error);
    }
  }

  return nextSettings;
}
