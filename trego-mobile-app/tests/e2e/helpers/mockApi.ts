import type { Page, Route } from "@playwright/test";

interface MockApiOptions {
  authenticated?: boolean;
  cartItems?: any[];
  businesses?: any[];
  businessProducts?: Record<number, any[]>;
  address?: Record<string, unknown> | null;
}

export async function installMockApi(page: Page, options: MockApiOptions = {}) {
  const state = {
    authenticated: Boolean(options.authenticated),
    user: {
      id: 101,
      role: "client",
      fullName: "Trego Test",
      email: "test@tregos.store",
    },
    cartItems: options.cartItems || [],
    wishlistItems: [] as any[],
    businesses: options.businesses || [],
    businessProducts: options.businessProducts || {},
    address: options.address === undefined
      ? {
          addressLine: "Rruga B",
          city: "Prishtine",
          country: "Kosove",
          zipCode: "10000",
          phoneNumber: "+38344111222",
        }
      : options.address,
  };

  await page.route("**/api/**", async (route: Route) => {
    const request = route.request();
    const url = new URL(request.url());
    const path = url.pathname;
    const method = request.method().toUpperCase();
    const body = request.postDataJSON?.() || {};

    const json = (payload: any, status = 200) =>
      route.fulfill({
        status,
        contentType: "application/json",
        body: JSON.stringify(payload),
      });

    if (path === "/api/me" && method === "GET") {
      return state.authenticated
        ? json({ ok: true, user: state.user })
        : json({ ok: false, message: "Nuk ka user." }, 401);
    }

    if (path === "/api/login" && method === "POST") {
      state.authenticated = true;
      return json({ ok: true, user: state.user, message: "Kyçja u krye." });
    }

    if (path === "/api/wishlist" && method === "GET") {
      return json({ ok: true, items: state.wishlistItems });
    }

    if (path === "/api/wishlist/toggle" && method === "POST") {
      return json({ ok: true, message: "Wishlist u perditesua." });
    }

    if (path === "/api/cart" && method === "GET") {
      return json({ ok: true, items: state.cartItems });
    }

    if (path === "/api/cart/add" && method === "POST") {
      return json({ ok: true, message: "Artikulli u shtua." });
    }

    if (path === "/api/cart/remove" && method === "POST") {
      state.cartItems = state.cartItems.filter((item) => Number(item.id) !== Number(body.cartLineId));
      return json({ ok: true, message: "Artikulli u largua." });
    }

    if (path === "/api/chat/conversations" && method === "GET") {
      return json({ ok: true, conversations: [] });
    }

    if (path === "/api/notifications/count" && method === "GET") {
      return json({ ok: true, unreadCount: 0 });
    }

    if (path === "/api/address" && method === "GET") {
      return json({ ok: true, address: state.address });
    }

    if (path === "/api/address" && method === "POST") {
      state.address = body;
      return json({ ok: true, address: state.address });
    }

    if (path === "/api/checkout/reserve" && method === "POST") {
      return json({ ok: true, reservedUntil: "2026-04-04T16:00:00Z" });
    }

    if (path === "/api/promotions/apply" && method === "POST") {
      return json({
        ok: true,
        pricing: {
          subtotal: 24,
          discountAmount: 3,
          shippingAmount: 2,
          total: 23,
        },
        message: "Pricing u rifreskua.",
      });
    }

    if (path === "/api/orders/create" && method === "POST") {
      state.cartItems = [];
      return json({ ok: true, message: "Porosia u krijua." });
    }

    if (path === "/api/orders" && method === "GET") {
      return json({ ok: true, orders: [] });
    }

    if (path === "/api/businesses/public" && method === "GET") {
      return json({ ok: true, businesses: state.businesses });
    }

    if (path === "/api/businesses/public/products" && method === "GET") {
      const businessId = Number(url.searchParams.get("id") || 0);
      return json({
        ok: true,
        products: state.businessProducts[businessId] || [],
        limit: 6,
        offset: 0,
        total: (state.businessProducts[businessId] || []).length,
        hasMore: false,
      });
    }

    if (path === "/api/chat/open" && method === "POST") {
      return json({
        ok: true,
        conversation: {
          id: 9001,
          counterpartName: "Support",
          unreadCount: 0,
        },
      });
    }

    if (path === "/api/business/follow-toggle" && method === "POST") {
      return json({
        ok: true,
        business: {
          isFollowed: true,
          followersCount: 12,
        },
      });
    }

    if (path === "/api/products" && method === "GET") {
      return json({
        ok: true,
        products: [],
        limit: 24,
        offset: 0,
        total: 0,
        hasMore: false,
      });
    }

    if (path === "/api/products/search" && method === "GET") {
      return json({
        ok: true,
        products: [],
        limit: 18,
        offset: 0,
        total: 0,
        hasMore: false,
      });
    }

    return json({ ok: true });
  });
}
