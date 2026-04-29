import { Capacitor } from "@capacitor/core";
import { PushNotifications } from "@capacitor/push-notifications";
import type {
  ActionPerformed,
  PushNotificationSchema,
  Token,
} from "@capacitor/push-notifications";
import type { Router } from "vue-router";
import type { SessionUser } from "../types/models";
import { refreshCounts } from "../stores/session";
import { requestJson } from "./api";

const PUSH_PERMISSION_PROMPT_KEY = "trego-mobile-push-permission-prompted";
const PUSH_DEVICE_ID_KEY = "trego-mobile-push-device-id";

export interface PushClientStatus {
  configured: boolean;
  nativeRuntime: boolean;
  initialized: boolean;
  permission: "granted" | "denied" | "prompt" | "unavailable";
  subscribed: boolean;
  platform: string;
}

let initialized = false;
let registering = false;
let lastRegisteredToken = "";
let currentUser: SessionUser | null = null;

function isNativePushRuntime() {
  try {
    return Capacitor.isNativePlatform() && typeof window !== "undefined";
  } catch {
    return false;
  }
}

function getDeviceId() {
  try {
    const existing = window.localStorage.getItem(PUSH_DEVICE_ID_KEY);
    if (existing) {
      return existing;
    }
    const generated = `native-${Capacitor.getPlatform()}-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 12)}`;
    window.localStorage.setItem(PUSH_DEVICE_ID_KEY, generated);
    return generated;
  } catch {
    return "";
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
    if (normalizedValue && !searchParams.has(key)) {
      searchParams.set(key, normalizedValue);
    }
  });

  const nextQuery = searchParams.toString();
  return `${basePath}${nextQuery ? `?${nextQuery}` : ""}${hashValue ? `#${hashValue}` : ""}`;
}

function extractNotificationData(notification: PushNotificationSchema | undefined): Record<string, unknown> {
  const data = notification?.data;
  return data && typeof data === "object" ? data as Record<string, unknown> : {};
}

function buildNotificationRouteFromData(data: Record<string, unknown>): string {
  const type = normalizeNotificationValue(data.type).toLowerCase();
  const conversationId = normalizeNotificationValue(data.conversationId);
  const messageId = normalizeNotificationValue(data.messageId);
  const orderId = normalizeNotificationValue(data.orderId);
  const orderItemId = normalizeNotificationValue(data.orderItemId);
  const productId = normalizeNotificationValue(data.productId);
  const status = normalizeNotificationValue(data.status).toLowerCase();

  if (type === "chat_message" && conversationId) {
    return appendNotificationQuery(`/messages/${conversationId}`, { messageId, fromPush: 1 });
  }

  if (type === "order_status" && orderId) {
    return appendNotificationQuery("/orders", { orderId, orderItemId, status, fromPush: 1 });
  }

  if (type === "order_created") {
    return appendNotificationQuery("/business", { orderId, fromPush: 1 });
  }

  if ((type === "sale_product" || type === "sale_ending") && productId) {
    return appendNotificationQuery(`/product/${productId}`, {
      fromPush: 1,
      alertKind: normalizeNotificationValue(data.alertKind),
    });
  }

  return appendNotificationQuery(
    normalizeNotificationPath(data.path)
      || normalizeNotificationPath(data.href)
      || "/tabs/account/notifications",
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

function buildNotificationRoute(event: ActionPerformed): string {
  return buildNotificationRouteFromData(extractNotificationData(event.notification));
}

function getNativeProvider() {
  const platform = Capacitor.getPlatform();
  return platform === "ios" ? "apns" : "fcm";
}

async function saveNativeToken(token: string) {
  if (!currentUser?.id || !token) {
    return;
  }

  try {
    await requestJson("/api/push/subscribe", {
      method: "POST",
      body: JSON.stringify({
        provider: getNativeProvider(),
        platform: Capacitor.getPlatform(),
        token,
        deviceId: getDeviceId(),
        userAgent: `TREGIO Capacitor ${Capacitor.getPlatform()}`,
      }),
    });
  } catch (error) {
    console.warn("Push token sync skipped", error);
  }
}

export function isPushConfigured() {
  return isNativePushRuntime();
}

export async function getPushClientStatus(router?: Router | null): Promise<PushClientStatus> {
  const nativeRuntime = isNativePushRuntime();
  const platform = nativeRuntime ? Capacitor.getPlatform() : "web";
  if (!nativeRuntime) {
    return {
      configured: false,
      nativeRuntime,
      initialized,
      permission: "unavailable",
      subscribed: false,
      platform,
    };
  }

  await ensurePushClient(router);

  let permission: PushClientStatus["permission"] = "unavailable";
  try {
    const permissions = await PushNotifications.checkPermissions();
    permission = permissions.receive === "granted"
      ? "granted"
      : permissions.receive === "denied"
        ? "denied"
        : "prompt";
  } catch {
    permission = "unavailable";
  }

  return {
    configured: true,
    nativeRuntime,
    initialized,
    permission,
    subscribed: Boolean(lastRegisteredToken),
    platform,
  };
}

export async function ensurePushClient(router?: Router | null) {
  if (!isNativePushRuntime()) {
    return null;
  }

  if (initialized) {
    return PushNotifications;
  }

  try {
    await PushNotifications.addListener("registration", async (token: Token) => {
      lastRegisteredToken = String(token.value || "").trim();
      await saveNativeToken(lastRegisteredToken);
    });
    await PushNotifications.addListener("registrationError", (error) => {
      console.warn("Push registration failed", error);
    });
    await PushNotifications.addListener("pushNotificationReceived", (notification) => {
      void refreshCounts();
      const data = extractNotificationData(notification);
      if (data?.type) {
        void requestJson("/api/notifications/count", {}, { cacheTtlMs: 500 });
      }
    });
    await PushNotifications.addListener("pushNotificationActionPerformed", (event) => {
      const nextPath = buildNotificationRoute(event);
      if (!nextPath || !router) {
        return;
      }
      void refreshCounts();
      void router.push(nextPath).catch(() => {});
    });
    initialized = true;
  } catch (error) {
    console.warn("Push client initialization skipped", error);
    return null;
  }

  return PushNotifications;
}

export async function syncPushIdentity(
  user: SessionUser | null,
  router?: Router | null,
) {
  currentUser = user;
  await ensurePushClient(router);
  if (user?.id && lastRegisteredToken) {
    await saveNativeToken(lastRegisteredToken);
  }
}

export async function requestPushPermissionIfNeeded(
  force = false,
  router?: Router | null,
) {
  const client = await ensurePushClient(router);
  if (!client || typeof window === "undefined") {
    return false;
  }

  if (!force) {
    return false;
  }

  try {
    const permission = await PushNotifications.requestPermissions();
    window.localStorage.setItem(PUSH_PERMISSION_PROMPT_KEY, "1");
    if (permission.receive !== "granted") {
      return false;
    }

    if (!registering) {
      registering = true;
      await PushNotifications.register();
      registering = false;
    }
    return true;
  } catch (error) {
    registering = false;
    console.warn("Push permission request skipped", error);
    return false;
  }
}
