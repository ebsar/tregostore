const GOOGLE_IDENTITY_SCRIPT_URL = "https://accounts.google.com/gsi/client";
const GOOGLE_WEB_CLIENT_ID = String(import.meta.env.VITE_GOOGLE_WEB_CLIENT_ID || "").trim();

let googleIdentityScriptPromise = null;

export function isGoogleWebAuthEnabled() {
  return Boolean(GOOGLE_WEB_CLIENT_ID);
}

export function getGoogleWebClientId() {
  return GOOGLE_WEB_CLIENT_ID;
}

export async function loadGoogleIdentityScript() {
  if (typeof window === "undefined" || !isGoogleWebAuthEnabled()) {
    return null;
  }

  if (window.google?.accounts?.id) {
    return window.google;
  }

  if (!googleIdentityScriptPromise) {
    googleIdentityScriptPromise = new Promise((resolve, reject) => {
      const existingScript = document.querySelector('script[data-google-identity-script="1"]');
      if (existingScript) {
        existingScript.addEventListener("load", () => resolve(window.google || null), { once: true });
        existingScript.addEventListener("error", () => reject(new Error("Google Identity script failed")), { once: true });
        return;
      }

      const script = document.createElement("script");
      script.src = GOOGLE_IDENTITY_SCRIPT_URL;
      script.async = true;
      script.defer = true;
      script.dataset.googleIdentityScript = "1";
      script.onload = () => resolve(window.google || null);
      script.onerror = () => reject(new Error("Google Identity script failed"));
      document.head.appendChild(script);
    });
  }

  return googleIdentityScriptPromise;
}

export async function renderGoogleAuthButton(
  targetElement,
  callback,
  options = {},
) {
  if (!targetElement || typeof callback !== "function" || !isGoogleWebAuthEnabled()) {
    return false;
  }

  const google = await loadGoogleIdentityScript();
  if (!google?.accounts?.id) {
    return false;
  }

  google.accounts.id.initialize({
    client_id: GOOGLE_WEB_CLIENT_ID,
    callback,
    auto_select: false,
    cancel_on_tap_outside: true,
    context: "signin",
    ux_mode: "popup",
  });

  targetElement.innerHTML = "";
  google.accounts.id.renderButton(targetElement, {
    theme: "outline",
    size: "large",
    shape: "pill",
    logo_alignment: "left",
    text: options.text || "continue_with",
    width: options.width || 320,
  });

  return true;
}
