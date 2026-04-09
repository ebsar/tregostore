import { Capacitor } from "@capacitor/core";
import type { Router } from "vue-router";
import type { SessionUser } from "../types/models";
import { refreshCounts } from "../stores/session";

const ONESIGNAL_APP_ID = String(import.meta.env.VITE_ONESIGNAL_APP_ID || "").trim();
const PUSH_PERMISSION_PROMPT_KEY = "trego-mobile-push-permission-prompted";

type OneSignalSdk = typeof import("onesignal-cordova-plugin").default;

export interface PushClientStatus {
  configured: boolean;
  nativeRuntime: boolean;
  initialized: boolean;
  permission: "granted" | "denied" | "prompt" | "unavailable";
  subscribed: boolean;
  platform: string;
}

let sdkPromise: Promise<OneSignalSdk | null> | null = null;
let initialized = false;
let clickListenerRegistered = false;
let foregroundListenerRegistered = false;

function isNativePushRuntime() {
  try {
    return Capacitor.isNativePlatform() && typeof window !== "undefined";
  } catch {
    return false;
  }
}

function normalizeNotificationPath(rawValue: unknown): string {
  const rawText = String(rawValue || "").trim();
  if (!rawText) {
    return "";
  }

  try {
    if (/^https?:\/\//i.test(rawText)) {
      const url = new URL(rawText);
      return `${url.pathname}${url.search}${url.hash}`;
    }
  } catch {
    return "";
  }

  return rawText.startsWith("/") ? rawText : `/${rawText}`;
}

function normalizeNotificationValue(value: unknown): string {
  return String(value ?? "").trim();
}

function appendNotificationQuery(path: string, query: Record<string, unknown>): string {
  const normalizedPath = normalizeNotificationPath(path);
  if (!normalizedPath) {
    return "";
  }

  const [pathname, hashValue = ""] = normalizedPath.split("#");
  const [basePath, existingQuery = ""] = pathname.split("?");
  const searchParams = new URLSearchParams(existingQuery);
  Object.entries(query).forEach(([key, value]) => {
    const normalizedValue = normalizeNotificationValue(value);
    if (!normalizedValue) {
      return;
    }
    if (!searchParams.has(key)) {
      searchParams.set(key, normalizedValue);
    }
  });

  const nextQuery = searchParams.toString();
  return `${basePath}${nextQuery ? `?${nextQuery}` : ""}${hashValue ? `#${hashValue}` : ""}`;
}

function buildNotificationRoute(event: any): string {
  const notification = event?.notification || {};
  const additionalData = notification?.additionalData || {};
  const type = normalizeNotificationValue(additionalData.type).toLowerCase();
  const conversationId = normalizeNotificationValue(additionalData.conversationId);
  const messageId = normalizeNotificationValue(additionalData.messageId);
  const orderId = normalizeNotificationValue(additionalData.orderId);
  const orderItemId = normalizeNotificationValue(additionalData.orderItemId);
  const productId = normalizeNotificationValue(additionalData.productId);
  const status = normalizeNotificationValue(additionalData.status).toLowerCase();

  if (type === "chat_message" && conversationId) {
    return appendNotificationQuery(`/messages/${conversationId}`, {
      messageId,
      fromPush: 1,
    });
  }

  if (type === "order_status" && orderId) {
    return appendNotificationQuery("/orders", {
      orderId,
      orderItemId,
      status,
      fromPush: 1,
    });
  }

  if (type === "order_created") {
    return appendNotificationQuery("/business", {
      orderId,
      fromPush: 1,
    });
  }

  if ((type === "sale_product" || type === "sale_ending") && productId) {
    return appendNotificationQuery(`/product/${productId}`, {
      fromPush: 1,
      alertKind: normalizeNotificationValue(additionalData.alertKind),
    });
  }

  return appendNotificationQuery(
    normalizeNotificationPath(additionalData.path)
      || normalizeNotificationPath(additionalData.href)
      || normalizeNotificationPath(notification.launchURL)
      || normalizeNotificationPath(event?.result?.url),
    {
      conversationId,
      messageId,
      orderId,
      orderItemId,
      productId,
      status,
      fromPush: 1,
    },
  );
}

async function loadOneSignalSdk(): Promise<OneSignalSdk | null> {
  if (!isPushConfigured() || !isNativePushRuntime()) {
    return null;
  }

  if (!sdkPromise) {
    sdkPromise = import("onesignal-cordova-plugin")
      .then((module) => module.default)
      .catch((error) => {
        console.warn("OneSignal SDK load skipped", error);
        return null;
      });
  }

  return sdkPromise;
}

export function isPushConfigured() {
  return Boolean(ONESIGNAL_APP_ID);
}

export async function getPushClientStatus(router?: Router | null): Promise<PushClientStatus> {
  const configured = isPushConfigured();
  const nativeRuntime = isNativePushRuntime();
  const platform = nativeRuntime ? Capacitor.getPlatform() : "web";
  if (!configured || !nativeRuntime) {
    return {
      configured,
      nativeRuntime,
      initialized,
      permission: configured ? "unavailable" : "unavailable",
      subscribed: false,
      platform,
    };
  }

  const OneSignal = await ensurePushClient(router);
  if (!OneSignal) {
    return {
      configured,
      nativeRuntime,
      initialized,
      permission: "unavailable",
      subscribed: false,
      platform,
    };
  }

  let permission: PushClientStatus["permission"] = "unavailable";
  let subscribed = false;

  try {
    const rawPermission = (OneSignal as any)?.Notifications?.permission;
    if (typeof rawPermission === "boolean") {
      permission = rawPermission ? "granted" : "denied";
    } else if (typeof (OneSignal as any)?.Notifications?.canRequestPermission === "function") {
      const canRequest = await (OneSignal as any).Notifications.canRequestPermission();
      permission = canRequest ? "prompt" : "denied";
    }
  } catch {
    permission = "unavailable";
  }

  try {
    const subscription = (OneSignal as any)?.User?.pushSubscription;
    subscribed = Boolean(subscription?.id || subscription?.token || subscription?.optedIn);
  } catch {
    subscribed = false;
  }

  return {
    configured,
    nativeRuntime,
    initialized,
    permission,
    subscribed,
    platform,
  };
}

export async function ensurePushClient(router?: Router | null) {
  const OneSignal = await loadOneSignalSdk();
  if (!OneSignal) {
    return null;
  }

  if (!initialized) {
    try {
      if (import.meta.env.DEV) {
        OneSignal.Debug.setLogLevel(6);
      }
      OneSignal.initialize(ONESIGNAL_APP_ID);
      initialized = true;
    } catch (error) {
      console.warn("OneSignal initialize skipped", error);
      return null;
    }
  }

  if (router && !clickListenerRegistered) {
    OneSignal.Notifications.addEventListener("click", (event) => {
      const nextPath = buildNotificationRoute(event);
      if (!nextPath) {
        return;
      }

      void refreshCounts();
      void router.push(nextPath).catch(() => {});
    });
    clickListenerRegistered = true;
  }

  if (!foregroundListenerRegistered) {
    OneSignal.Notifications.addEventListener("foregroundWillDisplay", () => {
      void refreshCounts();
    });
    foregroundListenerRegistered = true;
  }

  return OneSignal;
}

export async function syncPushIdentity(
  user: SessionUser | null,
  router?: Router | null,
) {
  const OneSignal = await ensurePushClient(router);
  if (!OneSignal) {
    return;
  }

  try {
    if (user?.id) {
      OneSignal.login(String(user.id));
      OneSignal.User.addTags({
        role: String(user.role || "client"),
        platform: Capacitor.getPlatform(),
      });
    } else {
      OneSignal.logout();
    }
  } catch (error) {
    console.warn("OneSignal identity sync skipped", error);
  }
}

export async function requestPushPermissionIfNeeded(
  force = false,
  router?: Router | null,
) {
  const OneSignal = await ensurePushClient(router);
  if (!OneSignal || typeof window === "undefined") {
    return false;
  }

  const alreadyPrompted = window.localStorage.getItem(PUSH_PERMISSION_PROMPT_KEY) === "1";
  if (!force && alreadyPrompted) {
    return false;
  }

  try {
    const canRequestPermission = await OneSignal.Notifications.canRequestPermission();
    const accepted = canRequestPermission
      ? await OneSignal.Notifications.requestPermission(true)
      : false;
    window.localStorage.setItem(PUSH_PERMISSION_PROMPT_KEY, "1");
    return Boolean(accepted);
  } catch (error) {
    console.warn("OneSignal permission request skipped", error);
    return false;
  }
}
