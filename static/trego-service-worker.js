const DEFAULT_ICON = "/trego-logo.png";
const DEFAULT_BADGE = "/apple-touch-icon.png";

self.addEventListener("install", (event) => {
  event.waitUntil(self.skipWaiting());
});

self.addEventListener("activate", (event) => {
  event.waitUntil(self.clients.claim());
});

function normalizeNotificationPayload(event) {
  if (!event.data) {
    return {
      title: "TREGIO",
      body: "You have a new notification.",
      href: "/notifications",
      data: {},
    };
  }

  try {
    const payload = event.data.json();
    return {
      title: String(payload.title || "TREGIO"),
      body: String(payload.body || ""),
      href: String(payload.href || payload.path || payload?.data?.href || "/notifications"),
      icon: String(payload.icon || DEFAULT_ICON),
      badge: String(payload.badge || DEFAULT_BADGE),
      tag: String(payload.tag || payload?.data?.type || "trego-notification"),
      data: payload.data || {},
    };
  } catch {
    return {
      title: "TREGIO",
      body: event.data.text(),
      href: "/notifications",
      icon: DEFAULT_ICON,
      badge: DEFAULT_BADGE,
      tag: "trego-notification",
      data: {},
    };
  }
}

self.addEventListener("push", (event) => {
  const payload = normalizeNotificationPayload(event);
  event.waitUntil(
    self.registration.showNotification(payload.title, {
      body: payload.body,
      icon: payload.icon || DEFAULT_ICON,
      badge: payload.badge || DEFAULT_BADGE,
      tag: payload.tag,
      renotify: true,
      requireInteraction: false,
      data: {
        ...payload.data,
        href: payload.href || "/notifications",
      },
      actions: [
        {
          action: "open",
          title: "Open",
        },
      ],
    }),
  );
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  const targetHref = String(event.notification?.data?.href || "/notifications");
  const targetUrl = new URL(targetHref, self.location.origin).href;

  event.waitUntil((async () => {
    const windowClients = await self.clients.matchAll({ type: "window", includeUncontrolled: true });
    for (const client of windowClients) {
      const clientUrl = new URL(client.url);
      if (clientUrl.origin === self.location.origin) {
        await client.focus();
        if ("navigate" in client) {
          await client.navigate(targetUrl);
        }
        return;
      }
    }

    await self.clients.openWindow(targetUrl);
  })());
});
