import { requestJson, resolveApiMessage } from "./api";

const DEVICE_ID_STORAGE_KEY = "trego-push-device-id";

function getStoredDeviceId() {
  try {
    const existing = window.localStorage.getItem(DEVICE_ID_STORAGE_KEY);
    if (existing) {
      return existing;
    }
    const generated = `web-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 12)}`;
    window.localStorage.setItem(DEVICE_ID_STORAGE_KEY, generated);
    return generated;
  } catch {
    return "";
  }
}

function urlBase64ToUint8Array(base64String) {
  const padding = "=".repeat((4 - (base64String.length % 4)) % 4);
  const base64 = `${base64String}${padding}`.replace(/-/g, "+").replace(/_/g, "/");
  const rawData = window.atob(base64);
  const outputArray = new Uint8Array(rawData.length);
  for (let index = 0; index < rawData.length; index += 1) {
    outputArray[index] = rawData.charCodeAt(index);
  }
  return outputArray;
}

export function detectPushPlatform() {
  if (typeof window === "undefined" || typeof navigator === "undefined") {
    return { platform: "web", isIOS: false, isAndroid: false, isStandalone: false };
  }

  const userAgent = String(navigator.userAgent || "");
  const isIOS = /iPad|iPhone|iPod/i.test(userAgent)
    || (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1);
  const isAndroid = /Android/i.test(userAgent);
  const isStandalone = Boolean(
    window.matchMedia?.("(display-mode: standalone)")?.matches
      || window.navigator.standalone,
  );

  return {
    platform: isIOS ? "ios" : isAndroid ? "android" : "web",
    isIOS,
    isAndroid,
    isStandalone,
  };
}

export async function getPushCapability() {
  const platform = detectPushPlatform();
  const hasBrowserSupport = typeof window !== "undefined"
    && "Notification" in window
    && "serviceWorker" in navigator
    && "PushManager" in window;

  if (!hasBrowserSupport) {
    return {
      ...platform,
      supported: false,
      configured: false,
      permission: "unsupported",
      reason: "Ky browser nuk i mbeshtet push notifications.",
    };
  }

  if (platform.isIOS && !platform.isStandalone) {
    return {
      ...platform,
      supported: false,
      configured: false,
      permission: Notification.permission,
      requiresInstall: true,
      reason: "Shto TREGIO ne Home Screen per te aktivizuar njoftimet ne iPhone.",
    };
  }

  const { response, data } = await requestJson("/api/push/public-key", {}, { cacheTtlMs: 5 * 60 * 1000 });
  const pushConfig = data?.push || {};
  return {
    ...platform,
    supported: true,
    configured: Boolean(response.ok && data?.ok && pushConfig.webPushConfigured && pushConfig.vapidPublicKey),
    permission: Notification.permission,
    vapidPublicKey: String(pushConfig.vapidPublicKey || ""),
    reason: response.ok && data?.ok ? "" : resolveApiMessage(data, "Push notifications nuk jane konfiguruar."),
  };
}

async function registerServiceWorker() {
  const registration = await navigator.serviceWorker.register("/trego-service-worker.js", { scope: "/" });
  await navigator.serviceWorker.ready;
  return registration;
}

async function saveSubscription(subscription, capability) {
  const subscriptionJson = subscription.toJSON ? subscription.toJSON() : {};
  const { response, data } = await requestJson("/api/push/subscribe", {
    method: "POST",
    body: JSON.stringify({
      provider: "webpush",
      platform: capability.platform,
      endpoint: subscription.endpoint,
      subscription: subscriptionJson,
      deviceId: getStoredDeviceId(),
      userAgent: navigator.userAgent || "",
    }),
  });

  if (!response.ok || !data?.ok) {
    throw new Error(resolveApiMessage(data, "Njoftimet nuk u ruajten ne server."));
  }

  return data;
}

export async function enableWebPushNotifications() {
  const capability = await getPushCapability();
  if (capability.requiresInstall) {
    return { ok: false, requiresInstall: true, message: capability.reason };
  }
  if (!capability.supported) {
    return { ok: false, message: capability.reason };
  }
  if (!capability.configured) {
    return { ok: false, message: "Serveri nuk ka ende VAPID keys per Web Push." };
  }

  let permission = Notification.permission;
  if (permission === "default") {
    permission = await Notification.requestPermission();
  }
  if (permission !== "granted") {
    return { ok: false, permission, message: "Njoftimet nuk u lejuan nga browseri." };
  }

  const registration = await registerServiceWorker();
  const existingSubscription = await registration.pushManager.getSubscription();
  const subscription = existingSubscription || await registration.pushManager.subscribe({
    userVisibleOnly: true,
    applicationServerKey: urlBase64ToUint8Array(capability.vapidPublicKey),
  });

  await saveSubscription(subscription, capability);
  return { ok: true, permission, message: "Njoftimet u aktivizuan." };
}

export async function disableWebPushNotifications() {
  const registration = await navigator.serviceWorker?.getRegistration?.("/");
  const subscription = await registration?.pushManager?.getSubscription?.();
  if (subscription) {
    await requestJson("/api/push/unsubscribe", {
      method: "POST",
      body: JSON.stringify({
        endpoint: subscription.endpoint,
        deviceId: getStoredDeviceId(),
      }),
    });
    await subscription.unsubscribe();
  }
  return { ok: true };
}

export async function sendPushTestNotification() {
  const { response, data } = await requestJson("/api/push/test", { method: "POST" });
  return {
    ok: Boolean(response.ok && data?.ok),
    message: resolveApiMessage(data, "Njoftimi test u dergua."),
  };
}
