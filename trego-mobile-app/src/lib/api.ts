import { Capacitor, CapacitorHttp } from "@capacitor/core";
import type {
  AdminUserItem,
  BusinessItem,
  CartItem,
  ChatMessage,
  ConversationItem,
  OrderItem,
  ProductItem,
  ProductReview,
  PromotionItem,
  ReportItem,
  ReturnRequestItem,
  SessionUser,
} from "../types/models";
import { markConnectionUnstable } from "../composables/useConnectivity";
import { createApiUrl } from "./config";

interface ResponseMeta {
  ok: boolean;
  status: number;
  statusText: string;
}

interface JsonResult<T = Record<string, unknown>> {
  response: ResponseMeta;
  data: T;
}

interface RequestRuntimeOptions {
  cacheTtlMs?: number;
  cacheKey?: string;
}

const GET_REQUEST_CACHE = new Map<string, { expiresAt: number; response: ResponseMeta; data: any }>();
const INFLIGHT_GET_REQUESTS = new Map<string, Promise<JsonResult<any>>>();
const VISITOR_TOKEN_STORAGE_KEY = "trego-mobile-visitor-token";

function generateVisitorToken() {
  return `visitor-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 12)}`;
}

function getVisitorToken(): string {
  try {
    const storedToken = String(globalThis?.localStorage?.getItem(VISITOR_TOKEN_STORAGE_KEY) || "").trim();
    if (storedToken) {
      return storedToken;
    }

    const nextToken = generateVisitorToken();
    globalThis?.localStorage?.setItem(VISITOR_TOKEN_STORAGE_KEY, nextToken);
    return nextToken;
  } catch {
    return "";
  }
}

function createResponseMeta(response?: Response | null): ResponseMeta {
  return {
    ok: Boolean(response?.ok),
    status: Number(response?.status || 0),
    statusText: String(response?.statusText || ""),
  };
}

function normalizeMethod(options: RequestInit = {}): string {
  return String(options.method || "GET").trim().toUpperCase();
}

function isNativePlatform() {
  try {
    return Capacitor.isNativePlatform();
  } catch {
    return false;
  }
}

export function resolveApiMessage(data: any, fallbackMessage: string): string {
  return String(data?.errors?.join?.(" ") || data?.message || fallbackMessage);
}

export async function requestJson<T = any>(
  path: string,
  options: RequestInit = {},
  runtime: RequestRuntimeOptions = {},
): Promise<JsonResult<T>> {
  const config: RequestInit = { ...options };
  const headers = new Headers(options.headers || {});
  const method = normalizeMethod(config);
  const cacheTtlMs = Math.max(0, Number(runtime.cacheTtlMs || 0));
  const cacheKey = runtime.cacheKey || `${method}:${path}`;
  const canUseCache = method === "GET" && cacheTtlMs > 0 && !config.body;

  if (config.body && !(config.body instanceof FormData) && !headers.has("Content-Type")) {
    headers.set("Content-Type", "application/json");
  }

  const visitorToken = getVisitorToken();
  if (visitorToken && !headers.has("X-Trego-Visitor")) {
    headers.set("X-Trego-Visitor", visitorToken);
  }

  config.headers = headers;

  if (canUseCache) {
    const cached = GET_REQUEST_CACHE.get(cacheKey);
    if (cached && cached.expiresAt > Date.now()) {
      return {
        response: { ...cached.response },
        data: JSON.parse(JSON.stringify(cached.data)),
      };
    }

    const inflight = INFLIGHT_GET_REQUESTS.get(cacheKey);
    if (inflight) {
      const result = await inflight;
      return {
        response: { ...result.response },
        data: JSON.parse(JSON.stringify(result.data)),
      };
    }
  }

  const pendingRequest = (async (): Promise<JsonResult<T>> => {
    let response: Response | null = null;
    let data: T = {} as T;

    try {
      if (isNativePlatform()) {
        const nativeHeaders = Object.fromEntries(headers.entries());
        const parsedBody =
          typeof config.body === "string"
            ? JSON.parse(config.body)
            : config.body;

        const nativeResponse = await CapacitorHttp.request({
          url: createApiUrl(path),
          method,
          headers: nativeHeaders,
          data: parsedBody,
          responseType: "json",
          webFetchExtra: {
            credentials: "include",
          },
        });

        data = (nativeResponse.data || {}) as T;
        response = {
          ok: nativeResponse.status >= 200 && nativeResponse.status < 300,
          status: nativeResponse.status,
          statusText: "",
        } as Response;
      } else {
        response = await fetch(createApiUrl(path), {
          ...config,
          credentials: "include",
          mode: "cors",
        });

        try {
          data = await response.json();
        } catch {
          data = {} as T;
        }
      }
    } catch (error) {
      console.error(error);
      markConnectionUnstable();
      data = {
        ok: false,
        message: "Lidhja me serverin deshtoi.",
      } as T;
    }

    const result = {
      response: createResponseMeta(response),
      data,
    };

    if (canUseCache && result.response.ok) {
      GET_REQUEST_CACHE.set(cacheKey, {
        expiresAt: Date.now() + cacheTtlMs,
        response: result.response,
        data: JSON.parse(JSON.stringify(result.data)),
      });
    }

    if (method !== "GET" && result.response.ok) {
      GET_REQUEST_CACHE.clear();
      INFLIGHT_GET_REQUESTS.clear();
    }

    return result;
  })();

  if (canUseCache) {
    INFLIGHT_GET_REQUESTS.set(cacheKey, pendingRequest);
  }

  try {
    return await pendingRequest;
  } finally {
    if (canUseCache) {
      INFLIGHT_GET_REQUESTS.delete(cacheKey);
    }
  }
}

export async function fetchCurrentUserOptional(): Promise<SessionUser | null> {
  const { response, data } = await requestJson<any>("/api/me", {}, { cacheTtlMs: 2500 });
  if (!response.ok || !data?.ok || !data?.user) {
    return null;
  }

  return data.user as SessionUser;
}

export async function loginUser(identifier: string, password: string) {
  return requestJson("/api/login", {
    method: "POST",
    body: JSON.stringify({ identifier, password }),
  });
}

export async function forgotPassword(email: string) {
  return requestJson("/api/forgot-password", {
    method: "POST",
    body: JSON.stringify({ email }),
  });
}

export async function confirmPasswordReset(payload: {
  email: string;
  code: string;
  newPassword: string;
  confirmPassword: string;
}) {
  return requestJson("/api/password-reset/confirm", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export async function registerUser(payload: {
  fullName: string;
  email: string;
  phoneNumber: string;
  password: string;
  birthDate: string;
  gender: string;
}) {
  return requestJson("/api/register", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export async function logoutUser() {
  return requestJson("/api/logout", { method: "POST" });
}

export async function fetchMarketplaceProducts(limit = 24, offset = 0): Promise<ProductItem[]> {
  const { response, data } = await requestJson<any>(
    `/api/products?limit=${limit}&offset=${offset}`,
    {},
    { cacheTtlMs: 30000 },
  );
  if (!response.ok || !data?.ok) {
    return [];
  }

  return Array.isArray(data.products) ? data.products : [];
}

export async function searchMarketplaceProducts(query: string): Promise<ProductItem[]> {
  const params = new URLSearchParams();
  params.set("query", query);
  params.set("limit", "30");
  const { response, data } = await requestJson<any>(
    `/api/products/search?${params.toString()}`,
    {},
    { cacheTtlMs: 12000 },
  );
  if (!response.ok || !data?.ok) {
    return [];
  }

  return Array.isArray(data.products) ? data.products : [];
}

export async function fetchProductDetail(productId: string | number): Promise<ProductItem | null> {
  const { response, data } = await requestJson<any>(
    `/api/product?id=${encodeURIComponent(String(productId))}`,
    {},
    { cacheTtlMs: 20000 },
  );
  if (!response.ok || !data?.ok || !data?.product) {
    return null;
  }

  return data.product as ProductItem;
}

export async function trackProductShare(productId: number | string) {
  return requestJson("/api/products/share", {
    method: "POST",
    body: JSON.stringify({ productId }),
  });
}

export async function openBusinessConversation(businessId: number | string) {
  return requestJson<any>("/api/chat/open", {
    method: "POST",
    body: JSON.stringify({ businessId }),
  });
}

export async function openSupportConversation() {
  return requestJson<any>("/api/chat/open", {
    method: "POST",
    body: JSON.stringify({ target: "support" }),
  });
}

export async function fetchPublicBusinesses(): Promise<BusinessItem[]> {
  const { response, data } = await requestJson<any>("/api/businesses/public", {}, { cacheTtlMs: 30000 });
  if (!response.ok || !data?.ok) {
    return [];
  }

  return Array.isArray(data.businesses) ? data.businesses : [];
}

export async function fetchPublicBusinessDetail(businessId: number | string): Promise<BusinessItem | null> {
  const params = new URLSearchParams();
  params.set("id", String(businessId));
  const { response, data } = await requestJson<any>(
    `/api/businesses/public/detail?${params.toString()}`,
    {},
    { cacheTtlMs: 18000 },
  );
  if (!response.ok || !data?.ok || !data?.business) {
    return null;
  }

  return data.business as BusinessItem;
}

export async function fetchPublicBusinessProducts(
  businessId: number | string,
  limit = 24,
  offset = 0,
): Promise<ProductItem[]> {
  const params = new URLSearchParams();
  params.set("id", String(businessId));
  params.set("limit", String(limit));
  params.set("offset", String(offset));
  const { response, data } = await requestJson<any>(
    `/api/businesses/public/products?${params.toString()}`,
    {},
    { cacheTtlMs: 18000 },
  );
  if (!response.ok || !data?.ok) {
    return [];
  }

  return Array.isArray(data.products) ? data.products : [];
}

export async function fetchWishlist(): Promise<ProductItem[]> {
  const { response, data } = await requestJson<any>("/api/wishlist", {}, { cacheTtlMs: 4000 });
  if (!response.ok || !data?.ok) {
    return [];
  }

  return Array.isArray(data.items) ? data.items : [];
}

export async function fetchBusinessAnalytics() {
  return requestJson<any>("/api/business/analytics");
}

export async function fetchAdminProducts(): Promise<ProductItem[]> {
  const { response, data } = await requestJson<any>("/api/admin/products");
  if (!response.ok || !data?.ok) {
    return [];
  }

  return Array.isArray(data.products) ? data.products : [];
}

export async function toggleWishlist(productId: number | string) {
  return requestJson("/api/wishlist/toggle", {
    method: "POST",
    body: JSON.stringify({ productId }),
  });
}

export async function fetchCart(): Promise<CartItem[]> {
  const { response, data } = await requestJson<any>("/api/cart", {}, { cacheTtlMs: 4000 });
  if (!response.ok || !data?.ok) {
    return [];
  }

  return Array.isArray(data.items) ? data.items : [];
}

export async function addToCart(
  productId: number | string,
  quantity = 1,
  options: {
    variantKey?: string;
    selectedSize?: string;
    selectedColor?: string;
  } = {},
) {
  return requestJson("/api/cart/add", {
    method: "POST",
    body: JSON.stringify({
      productId,
      quantity,
      variantKey: options.variantKey || "",
      selectedSize: options.selectedSize || "",
      selectedColor: options.selectedColor || "",
    }),
  });
}

export async function fetchProductReviews(
  productId: string | number,
): Promise<{ reviews: ProductReview[]; canSubmitReview: boolean; stats?: { averageRating?: number; reviewCount?: number } }> {
  const { response, data } = await requestJson<any>(
    `/api/product/reviews?id=${encodeURIComponent(String(productId))}`,
    {},
    { cacheTtlMs: 20000 },
  );
  if (!response.ok || !data?.ok) {
    return { reviews: [], canSubmitReview: false, stats: { averageRating: 0, reviewCount: 0 } };
  }

  return {
    reviews: Array.isArray(data.reviews) ? data.reviews : [],
    canSubmitReview: Boolean(data.canSubmitReview),
    stats: data.stats || { averageRating: 0, reviewCount: 0 },
  };
}

export async function removeFromCart(productId: number | string) {
  return requestJson("/api/cart/remove", {
    method: "POST",
    body: JSON.stringify({ productId }),
  });
}

export async function fetchOrders(): Promise<OrderItem[]> {
  const { response, data } = await requestJson<any>("/api/orders", {}, { cacheTtlMs: 5000 });
  if (!response.ok || !data?.ok) {
    return [];
  }

  return Array.isArray(data.orders) ? data.orders : [];
}

export async function fetchConversations(): Promise<ConversationItem[]> {
  const { response, data } = await requestJson<any>("/api/chat/conversations", {}, { cacheTtlMs: 5000 });
  if (!response.ok || !data?.ok) {
    return [];
  }

  return Array.isArray(data.conversations) ? data.conversations : [];
}

export async function fetchNotificationsCount(): Promise<number> {
  const { response, data } = await requestJson<any>("/api/notifications/count", {}, { cacheTtlMs: 5000 });
  if (!response.ok || !data?.ok) {
    return 0;
  }

  return Math.max(0, Number(data.unreadCount || 0));
}

export async function fetchConversationDetail(
  conversationId: number | string,
): Promise<{ conversation: ConversationItem | null; messages: ChatMessage[]; counterpartTyping: boolean }> {
  const params = new URLSearchParams();
  params.set("conversationId", String(conversationId));
  const { response, data } = await requestJson<any>(
    `/api/chat/messages?${params.toString()}`,
    {},
    { cacheTtlMs: 0, cacheKey: `GET:/api/chat/messages:${conversationId}` },
  );
  if (!response.ok || !data?.ok) {
    return { conversation: null, messages: [], counterpartTyping: false };
  }

  return {
    conversation: (data.conversation || null) as ConversationItem | null,
    messages: Array.isArray(data.messages) ? data.messages : [],
    counterpartTyping: Boolean(data.counterpartTyping),
  };
}

export async function sendConversationMessage(
  conversationId: number | string,
  body: string,
): Promise<{ ok: boolean; message?: ChatMessage; conversation?: ConversationItem | null; data: any }> {
  const { response, data } = await requestJson<any>("/api/chat/messages", {
    method: "POST",
    body: JSON.stringify({
      conversationId,
      body,
    }),
  });

  return {
    ok: Boolean(response.ok && data?.ok),
    message: (data?.message || undefined) as ChatMessage | undefined,
    conversation: (data?.conversation || null) as ConversationItem | null,
    data,
  };
}

export async function fetchBusinessProfile() {
  return requestJson<any>("/api/business-profile", {}, { cacheTtlMs: 12000 });
}

export async function fetchBusinessProducts(): Promise<ProductItem[]> {
  const { response, data } = await requestJson<any>("/api/business/products", {}, { cacheTtlMs: 12000 });
  if (!response.ok || !data?.ok) {
    return [];
  }

  return Array.isArray(data.products) ? data.products : [];
}

export async function uploadImages(files: File[] = []) {
  const uploadData = new FormData();
  files.forEach((file) => {
    uploadData.append("images", file);
  });

  const { response, data } = await requestJson<any>("/api/uploads", {
    method: "POST",
    body: uploadData,
  });

  if (!response.ok || !data?.ok || !Array.isArray(data.paths) || data.paths.length === 0) {
    return {
      ok: false,
      paths: [] as string[],
      message: resolveApiMessage(data, "Fotot nuk u ngarkuan."),
    };
  }

  return {
    ok: true,
    paths: data.paths as string[],
    message: String(data.message || "Fotot u ngarkuan me sukses."),
  };
}

export async function searchProductsByImage(file: File, options: Record<string, unknown> = {}) {
  const uploadData = new FormData();
  uploadData.append("image", file);

  Object.entries(options).forEach(([key, value]) => {
    if (value === undefined || value === null || value === "") {
      return;
    }
    uploadData.append(key, String(value));
  });

  const { response, data } = await requestJson<any>("/api/products/visual-search", {
    method: "POST",
    body: uploadData,
  });

  if (!response.ok || !data?.ok) {
    return {
      ok: false,
      products: [] as ProductItem[],
      total: 0,
      hasMore: false,
      message: resolveApiMessage(data, "Kerkimi me foto nuk u krye."),
    };
  }

  return {
    ok: true,
    products: Array.isArray(data.products) ? (data.products as ProductItem[]) : [],
    total: Number(data.total || 0),
    hasMore: Boolean(data.hasMore),
    message: String(data.message || "U gjeten produkte te ngjashme."),
  };
}

export async function fetchAdminUsers(): Promise<AdminUserItem[]> {
  const { response, data } = await requestJson<any>("/api/admin/users");
  if (!response.ok || !data?.ok) {
    return [];
  }
  return Array.isArray(data.users) ? data.users : [];
}

export async function fetchAdminBusinesses(): Promise<BusinessItem[]> {
  const { response, data } = await requestJson<any>("/api/admin/businesses");
  if (!response.ok || !data?.ok) {
    return [];
  }
  return Array.isArray(data.businesses) ? data.businesses : [];
}

export async function fetchAdminReports(): Promise<ReportItem[]> {
  const { response, data } = await requestJson<any>("/api/admin/reports");
  if (!response.ok || !data?.ok) {
    return [];
  }
  return Array.isArray(data.reports) ? data.reports : [];
}

export async function fetchAdminOrders(): Promise<OrderItem[]> {
  const { response, data } = await requestJson<any>("/api/admin/orders");
  if (!response.ok || !data?.ok) {
    return [];
  }
  return Array.isArray(data.orders) ? data.orders : [];
}

export async function updateAdminUserRole(userId: number | string, role: string) {
  return requestJson("/api/admin/users/role", {
    method: "POST",
    body: JSON.stringify({ userId, role }),
  });
}

export async function deleteAdminUser(userId: number | string) {
  return requestJson("/api/admin/users/delete", {
    method: "POST",
    body: JSON.stringify({ userId }),
  });
}

export async function setAdminUserPassword(userId: number | string, newPassword: string) {
  return requestJson("/api/admin/users/set-password", {
    method: "POST",
    body: JSON.stringify({ userId, newPassword }),
  });
}

export async function createAdminBusiness(payload: Record<string, unknown>) {
  return requestJson("/api/admin/businesses/create", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export async function updateAdminBusiness(payload: Record<string, unknown>) {
  return requestJson("/api/admin/businesses/update", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export async function updateAdminBusinessVerification(businessId: number | string, verificationStatus: string) {
  return requestJson("/api/admin/businesses/verification", {
    method: "POST",
    body: JSON.stringify({ businessId, verificationStatus }),
  });
}

export async function updateAdminBusinessEditAccess(businessId: number | string, editAccessStatus: string) {
  return requestJson("/api/admin/businesses/edit-access", {
    method: "POST",
    body: JSON.stringify({ businessId, editAccessStatus }),
  });
}

export async function updateAdminReportStatus(reportId: number | string, status: string, adminNotes = "") {
  return requestJson("/api/admin/reports/status", {
    method: "POST",
    body: JSON.stringify({ reportId, status, adminNotes }),
  });
}

export async function fetchBusinessOrders(): Promise<OrderItem[]> {
  const { response, data } = await requestJson<any>("/api/business/orders");
  if (!response.ok || !data?.ok) {
    return [];
  }
  return Array.isArray(data.orders) ? data.orders : [];
}

export async function updateOrderItemStatus(payload: Record<string, unknown>) {
  return requestJson("/api/orders/status", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export async function fetchReturnRequests(): Promise<ReturnRequestItem[]> {
  const { response, data } = await requestJson<any>("/api/returns");
  if (!response.ok || !data?.ok) {
    return [];
  }
  return Array.isArray(data.requests) ? data.requests : [];
}

export async function updateReturnRequestStatus(returnRequestId: number | string, status: string, resolutionNotes = "") {
  return requestJson("/api/returns/status", {
    method: "POST",
    body: JSON.stringify({ returnRequestId, status, resolutionNotes }),
  });
}

export async function createReturnRequest(orderItemId: number | string, reason: string, details = "") {
  return requestJson("/api/returns/request", {
    method: "POST",
    body: JSON.stringify({ orderItemId, reason, details }),
  });
}

export async function fetchBusinessPromotions(): Promise<PromotionItem[]> {
  const { response, data } = await requestJson<any>("/api/business/promotions");
  if (!response.ok || !data?.ok) {
    return [];
  }
  return Array.isArray(data.promotions) ? data.promotions : [];
}

export async function saveBusinessPromotion(payload: Record<string, unknown>) {
  return requestJson("/api/business/promotions", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export async function deleteBusinessPromotion(promotionId: number | string, code = "") {
  return requestJson("/api/business/promotions", {
    method: "POST",
    body: JSON.stringify({ promotionId, code, action: "delete" }),
  });
}

export async function createOrUpdateProduct(payload: Record<string, unknown>, productId?: number | string) {
  const endpoint = productId ? "/api/products/update" : "/api/products";
  return requestJson(endpoint, {
    method: "POST",
    body: JSON.stringify(productId ? { ...payload, productId } : payload),
  });
}

export async function deleteProduct(productId: number | string) {
  return requestJson("/api/products/delete", {
    method: "POST",
    body: JSON.stringify({ productId }),
  });
}

export async function updateProductVisibility(productId: number | string, isPublic: boolean) {
  return requestJson("/api/products/public-visibility", {
    method: "POST",
    body: JSON.stringify({ productId, isPublic }),
  });
}

export async function updateProductPublicStock(productId: number | string, showStockPublic: boolean) {
  return requestJson("/api/products/public-stock", {
    method: "POST",
    body: JSON.stringify({ productId, showStockPublic }),
  });
}

export async function requestBusinessVerification() {
  return requestJson("/api/business-profile/verification-request", {
    method: "POST",
  });
}

export async function requestBusinessProfileEditAccess() {
  return requestJson("/api/business-profile/edit-request", {
    method: "POST",
  });
}

export function createDownloadUrl(path: string) {
  return createApiUrl(path);
}

export async function importBusinessProductsFile(file: File) {
  const formData = new FormData();
  formData.append("file", file);

  const { response, data } = await requestJson<any>("/api/business/products/import", {
    method: "POST",
    body: formData,
  });

  return {
    ok: Boolean(response.ok && data?.ok),
    count: Number(data?.count || 0),
    message: resolveApiMessage(data, "Importi i produkteve nuk u krye."),
  };
}
