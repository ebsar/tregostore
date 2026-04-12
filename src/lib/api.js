const GET_REQUEST_CACHE = new Map();
const INFLIGHT_GET_REQUESTS = new Map();
const VISITOR_TOKEN_STORAGE_KEY = "trego-visitor-token";
const DEBUG_SESSION_TOKEN_STORAGE_KEY = "tregio-debug-session-token";
const AUTH_INVALIDATION_EVENT_NAME = "tregio:auth-invalidated";
const MIN_REQUEST_TIMEOUT_MS = 1200;
const DEFAULT_GET_TIMEOUT_MS = 12000;
const DEFAULT_MUTATION_TIMEOUT_MS = 15000;
const DEFAULT_RETRY_TIMEOUT_MS = 12000;
const AUTH_INVALIDATION_EXCLUDED_PATHS = new Set([
  "/api/login",
  "/api/signup",
  "/api/logout",
  "/api/me",
  "/api/auth/google",
]);

function generateVisitorToken() {
  return `visitor-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 12)}`;
}

function getVisitorToken() {
  if (typeof window === "undefined") {
    return "";
  }

  try {
    const storedToken = String(window.localStorage.getItem(VISITOR_TOKEN_STORAGE_KEY) || "").trim();
    if (storedToken) {
      return storedToken;
    }

    const nextToken = generateVisitorToken();
    window.localStorage.setItem(VISITOR_TOKEN_STORAGE_KEY, nextToken);
    return nextToken;
  } catch (error) {
    console.error(error);
    return "";
  }
}

function cloneJsonPayload(value) {
  return JSON.parse(JSON.stringify(value ?? {}));
}

function createResponseMeta(response) {
  return {
    ok: Boolean(response?.ok),
    status: Number(response?.status || 0),
    statusText: String(response?.statusText || ""),
  };
}

function normalizeMethod(options = {}) {
  return String(options.method || "GET").trim().toUpperCase();
}

function invalidateRequestCache() {
  GET_REQUEST_CACHE.clear();
  INFLIGHT_GET_REQUESTS.clear();
}

function getRequestPathname(url) {
  const rawUrl = String(url || "").trim();
  if (!rawUrl) {
    return "";
  }

  try {
    const baseOrigin = typeof window !== "undefined" ? window.location.origin : "http://localhost";
    return new URL(rawUrl, baseOrigin).pathname;
  } catch (error) {
    return rawUrl.split("?")[0] || rawUrl;
  }
}

function maybeDispatchAuthInvalidation(url, method, response) {
  const status = Number(response?.status || 0);
  if (![401, 403].includes(status)) {
    return;
  }

  const normalizedMethod = String(method || "GET").trim().toUpperCase();
  const pathname = getRequestPathname(url);
  if (!pathname.startsWith("/api/") || AUTH_INVALIDATION_EXCLUDED_PATHS.has(pathname)) {
    return;
  }

  clearDebugSessionToken();
  invalidateRequestCache();

  if (typeof window === "undefined") {
    return;
  }

  window.dispatchEvent(new CustomEvent(AUTH_INVALIDATION_EVENT_NAME, {
    detail: {
      method: normalizedMethod,
      pathname,
      status,
    },
  }));
}

function canUseDebugSessionFallback() {
  if (typeof window === "undefined") {
    return false;
  }

  const hostname = String(window.location.hostname || "").trim().toLowerCase();
  return hostname === "localhost" || hostname === "127.0.0.1" || hostname === "::1";
}

function readDebugSessionToken() {
  if (!canUseDebugSessionFallback()) {
    return "";
  }

  try {
    return String(window.sessionStorage.getItem(DEBUG_SESSION_TOKEN_STORAGE_KEY) || "").trim();
  } catch (error) {
    console.error(error);
    return "";
  }
}

export function persistDebugSessionToken(token) {
  if (!canUseDebugSessionFallback()) {
    return;
  }

  try {
    const normalizedToken = String(token || "").trim();
    if (!normalizedToken) {
      window.sessionStorage.removeItem(DEBUG_SESSION_TOKEN_STORAGE_KEY);
      return;
    }

    window.sessionStorage.setItem(DEBUG_SESSION_TOKEN_STORAGE_KEY, normalizedToken);
  } catch (error) {
    console.error(error);
  }
}

export function clearDebugSessionToken() {
  if (!canUseDebugSessionFallback()) {
    return;
  }

  try {
    window.sessionStorage.removeItem(DEBUG_SESSION_TOKEN_STORAGE_KEY);
  } catch (error) {
    console.error(error);
  }
}

export async function requestJson(url, options = {}, runtime = {}) {
  const config = { ...options };
  config.headers = { ...(options.headers || {}) };
  if (!config.credentials) {
    config.credentials = "same-origin";
  }
  const method = normalizeMethod(config);
  const cacheTtlMs = Math.max(0, Number(runtime.cacheTtlMs || 0));
  const allowRetry = runtime.allowRetry !== false;
  const timeoutMs = Math.max(
    MIN_REQUEST_TIMEOUT_MS,
    Number(runtime.timeoutMs || (method === "GET" ? DEFAULT_GET_TIMEOUT_MS : DEFAULT_MUTATION_TIMEOUT_MS)),
  );
  const retryTimeoutMs = Math.max(
    MIN_REQUEST_TIMEOUT_MS,
    Number(
      runtime.retryTimeoutMs
      || Math.max(timeoutMs, DEFAULT_RETRY_TIMEOUT_MS),
    ),
  );
  const cacheKey = runtime.cacheKey || `${method}:${url}`;
  const canUseCache = method === "GET" && !config.body && cacheTtlMs > 0;

  if (
    config.body &&
    !(config.body instanceof FormData) &&
    !config.headers["Content-Type"]
  ) {
    config.headers["Content-Type"] = "application/json";
  }

  const visitorToken = getVisitorToken();
  if (visitorToken && !config.headers["X-Trego-Visitor"]) {
    config.headers["X-Trego-Visitor"] = visitorToken;
  }

  const debugSessionToken = readDebugSessionToken();
  if (debugSessionToken && !config.headers["X-Tregio-Session"]) {
    config.headers["X-Tregio-Session"] = debugSessionToken;
  }

  if (canUseCache) {
    const cachedEntry = GET_REQUEST_CACHE.get(cacheKey);
    if (cachedEntry && cachedEntry.expiresAt > Date.now()) {
      return {
        response: { ...cachedEntry.response },
        data: cloneJsonPayload(cachedEntry.data),
      };
    }

    const inflightRequest = INFLIGHT_GET_REQUESTS.get(cacheKey);
    if (inflightRequest) {
      const result = await inflightRequest;
      return {
        response: { ...result.response },
        data: cloneJsonPayload(result.data),
      };
    }
  }

  async function performRequestOnce(activeTimeoutMs) {
    const controller = new AbortController();
    const timeoutId = window.setTimeout(() => {
      controller.abort();
    }, activeTimeoutMs);

    let response = null;
    let data = {};

    try {
      response = await fetch(url, {
        ...config,
        signal: controller.signal,
      });

      try {
        const rawBody = await response.text();
        if (rawBody) {
          data = JSON.parse(rawBody);
        } else if (!response.ok) {
          data = {
            ok: false,
            message: `Serveri ktheu gabim ${response.status || 500}.`,
          };
        }
      } catch (error) {
        data = {
          ok: false,
          message: response?.ok
            ? "Pergjigjja e serverit nuk ishte ne formatin e pritur."
            : `Serveri ktheu gabim ${response?.status || 500}.`,
        };
      }
    } catch (error) {
      const isAbortError = error?.name === "AbortError";
      if (!isAbortError) {
        console.error(error);
      }
      data = {
        ok: false,
        message:
          isAbortError
            ? "Serveri po vonon shume. Provoje perseri pas pak."
            : "Lidhja me serverin deshtoi.",
      };
    } finally {
      window.clearTimeout(timeoutId);
    }

    return {
      response: createResponseMeta(response),
      data,
    };
  }

  const pendingRequest = (async () => {
    let result = await performRequestOnce(timeoutMs);

    const shouldRetryGetRequest = (
      allowRetry
      && method === "GET"
      && !result.response.ok
      && (
        result.data?.message === "Serveri po vonon shume. Provoje perseri pas pak."
        || result.data?.message === "Lidhja me serverin deshtoi."
      )
    );

    if (shouldRetryGetRequest) {
      result = await performRequestOnce(retryTimeoutMs);
    }

    if (canUseCache && result.response.ok) {
      GET_REQUEST_CACHE.set(cacheKey, {
        expiresAt: Date.now() + cacheTtlMs,
        response: result.response,
        data: cloneJsonPayload(result.data),
      });
    }

    if (result.response.ok && String(result.data?.sessionToken || "").trim()) {
      persistDebugSessionToken(result.data.sessionToken);
    }

    maybeDispatchAuthInvalidation(url, method, result.response);

    if (method !== "GET" && result.response.ok) {
      invalidateRequestCache();
    }

    return result;
  })();

  if (canUseCache) {
    INFLIGHT_GET_REQUESTS.set(cacheKey, pendingRequest);
  }

  try {
    const result = await pendingRequest;
    return {
      response: { ...result.response },
      data: result.data,
    };
  } finally {
    if (canUseCache) {
      INFLIGHT_GET_REQUESTS.delete(cacheKey);
    }
  }
}

export async function fetchCurrentUserSession() {
  try {
    const { response, data } = await requestJson("/api/me", {}, {
      cacheTtlMs: 1500,
      timeoutMs: 10000,
      retryTimeoutMs: 8000,
    });
    if (response.ok && data?.ok && data?.user) {
      return {
        status: "authenticated",
        user: data.user,
      };
    }

    if (response.status === 401 || response.status === 403) {
      clearDebugSessionToken();
      return {
        status: "guest",
        user: null,
      };
    }

    return {
      status: "unreachable",
      user: null,
      message: resolveApiMessage(data, "Serveri po vonon shume. Provoje perseri pas pak."),
    };
  } catch (error) {
    console.error(error);
    return {
      status: "unreachable",
      user: null,
      message: "Serveri po vonon shume. Provoje perseri pas pak.",
    };
  }
}

export async function fetchCurrentUserOptional() {
  const session = await fetchCurrentUserSession();
  return session.status === "authenticated" ? session.user : null;
}

export function getAuthInvalidationEventName() {
  return AUTH_INVALIDATION_EVENT_NAME;
}

function normalizeRecommendationSections(data, fallbackLimit = 8) {
  if (!Array.isArray(data?.sections)) {
    return [];
  }

  return data.sections
    .map((section, index) => ({
      key: String(section?.key || `recommendation-${index}`),
      title: String(section?.title || "Recommended"),
      subtitle: String(section?.subtitle || ""),
      products: Array.isArray(section?.products)
        ? section.products.slice(0, Math.max(1, Number(fallbackLimit || 8)))
        : [],
    }))
    .filter((section) => section.products.length > 0);
}

export async function fetchHomeRecommendations(limit = 8) {
  const params = new URLSearchParams();
  params.set("limit", String(limit));

  const { response, data } = await requestJson(
    `/api/recommendations/home?${params.toString()}`,
    {},
    { cacheTtlMs: 5000 },
  );

  if (!response.ok || !data?.ok) {
    return {
      sections: [],
      personalized: false,
      limit,
    };
  }

  return {
    sections: normalizeRecommendationSections(data, limit),
    personalized: Boolean(data.personalized),
    limit: Math.max(1, Number(data.limit || limit)),
  };
}

export async function fetchProductRecommendations(productId, limit = 8) {
  const params = new URLSearchParams();
  params.set("id", String(productId));
  params.set("limit", String(limit));

  const { response, data } = await requestJson(
    `/api/recommendations/product?${params.toString()}`,
    {},
    { cacheTtlMs: 5000 },
  );

  if (!response.ok || !data?.ok) {
    return {
      sections: [],
      personalized: false,
      limit,
    };
  }

  return {
    sections: normalizeRecommendationSections(data, limit),
    personalized: Boolean(data.personalized),
    limit: Math.max(1, Number(data.limit || limit)),
  };
}

export async function fetchProtectedCollection(url, runtime = {}) {
  try {
    const { response, data } = await requestJson(
      url,
      {},
      {
        cacheTtlMs: 2000,
        ...runtime,
      },
    );
    if (!response.ok || !data.ok) {
      return [];
    }

    return Array.isArray(data.items) ? data.items : [];
  } catch (error) {
    console.error(error);
    return [];
  }
}

export function resolveApiMessage(data, fallbackMessage) {
  return (
    data?.errors?.join(" ") ||
    data?.message ||
    fallbackMessage
  );
}

export async function uploadImages(files = []) {
  const uploadData = new FormData();
  files.forEach((file) => {
    uploadData.append("images", file);
  });

  const { response, data } = await requestJson("/api/uploads", {
    method: "POST",
    body: uploadData,
  });

  if (!response.ok || !data?.ok || !Array.isArray(data.paths) || data.paths.length === 0) {
    return {
      ok: false,
      paths: [],
      message: resolveApiMessage(data, "Fotot nuk u ngarkuan."),
    };
  }

  return {
    ok: true,
    paths: data.paths,
    message: data.message || "Fotot u ngarkuan me sukses.",
  };
}

export async function uploadProfilePhoto(file) {
  const uploadData = new FormData();
  uploadData.append("image", file);

  const { response, data } = await requestJson("/api/profile/photo", {
    method: "POST",
    body: uploadData,
  });

  if (!response.ok || !data?.ok || !data.path) {
    return {
      ok: false,
      path: "",
      message: resolveApiMessage(data, "Fotoja e profilit nuk u ngarkua."),
    };
  }

  return {
    ok: true,
    path: String(data.path).trim(),
    message: data.message || "Fotoja e profilit u ngarkua me sukses.",
  };
}

export async function trackProductShare(productId) {
  return requestJson("/api/products/share", {
    method: "POST",
    body: JSON.stringify({ productId }),
  });
}

export async function searchProductsByImage(file, options = {}) {
  const uploadData = new FormData();
  uploadData.append("image", file);

  if (options.pageSection) {
    uploadData.append("pageSection", String(options.pageSection).trim());
  }

  if (options.category) {
    uploadData.append("category", String(options.category).trim());
  }

  if (options.categoryGroup) {
    uploadData.append("categoryGroup", String(options.categoryGroup).trim());
  }

  if (options.productType) {
    uploadData.append("productType", String(options.productType).trim());
  }

  if (options.size) {
    uploadData.append("size", String(options.size).trim());
  }

  if (options.color) {
    uploadData.append("color", String(options.color).trim());
  }

  if (Number.isFinite(Number(options.limit))) {
    uploadData.append("limit", String(options.limit));
  }

  if (Number.isFinite(Number(options.offset))) {
    uploadData.append("offset", String(options.offset));
  }

  if (options.includeFacets) {
    uploadData.append("includeFacets", "1");
  }

  const { response, data } = await requestJson("/api/products/visual-search", {
    method: "POST",
    body: uploadData,
  });

  if (!response.ok || !data?.ok) {
    return {
      ok: false,
      products: [],
      total: 0,
      hasMore: false,
      message: resolveApiMessage(data, "Kerkimi me foto nuk u krye."),
    };
  }

  return {
    ok: true,
    products: Array.isArray(data.products) ? data.products : [],
    facets: data.facets || null,
    activeFilters: data.activeFilters || null,
    total: Number(data.total || 0),
    hasMore: Boolean(data.hasMore),
    message: data.message || "U gjeten produkte te ngjashme sipas fotos.",
  };
}

export async function fetchChatReplySuggestions(conversationId) {
  const { response, data } = await requestJson(
    `/api/chat/reply-suggestions?conversationId=${encodeURIComponent(conversationId)}`,
  );

  if (!response.ok || !data?.ok) {
    return {
      ok: false,
      suggestions: [],
      message: resolveApiMessage(data, "Sugjerimet e bisedes nuk u pergatiten."),
    };
  }

  return {
    ok: true,
    suggestions: Array.isArray(data.suggestions) ? data.suggestions : [],
    message: data.message || "Sugjerimet e bisedes u pergatiten.",
  };
}

export async function requestProductAIDraft(formData) {
  const { response, data } = await requestJson("/api/products/ai-draft", {
    method: "POST",
    body: formData,
  });

  if (!response.ok || !data?.ok || !data?.draft) {
    return {
      ok: false,
      draft: null,
      message: resolveApiMessage(data, "AI draft nuk u pergatit."),
    };
  }

  return {
    ok: true,
    draft: data.draft,
    message: data.message || "Drafti i produktit u pergatit.",
  };
}

export async function downloadBusinessProductsImportTemplate() {
  const response = await fetch("/api/business/products/import-template");
  if (!response.ok) {
    let data = {};
    try {
      data = await response.json();
    } catch (error) {
      console.error(error);
    }
    return {
      ok: false,
      message: resolveApiMessage(data, "Template-i nuk u shkarkua."),
    };
  }

  const blob = await response.blob();
  const objectUrl = URL.createObjectURL(blob);
  try {
    const anchor = document.createElement("a");
    anchor.href = objectUrl;
    anchor.download = "trego-products-template.xlsx";
    document.body.appendChild(anchor);
    anchor.click();
    anchor.remove();
  } finally {
    window.setTimeout(() => URL.revokeObjectURL(objectUrl), 0);
  }

  return {
    ok: true,
    message: "Template-i XLSX u shkarkua me sukses.",
  };
}

export async function fetchBusinessCatalogImportConfig() {
  const { response, data } = await requestJson("/api/business/catalog-import/config");

  if (!response.ok || !data?.ok) {
    return {
      ok: false,
      profiles: [],
      sources: [],
      recentJobs: [],
      canonicalFields: [],
      categoryAttributeSets: {},
      message: resolveApiMessage(data, "Konfigurimi i importit nuk u lexua."),
    };
  }

  return {
    ok: true,
    profiles: Array.isArray(data.profiles) ? data.profiles : [],
    sources: Array.isArray(data.sources) ? data.sources : [],
    recentJobs: Array.isArray(data.recentJobs) ? data.recentJobs : [],
    canonicalFields: Array.isArray(data.canonicalFields) ? data.canonicalFields : [],
    categoryAttributeSets: data.categoryAttributeSets && typeof data.categoryAttributeSets === "object"
      ? data.categoryAttributeSets
      : {},
    message: data.message || "Konfigurimi i importit u lexua me sukses.",
  };
}

export async function createBusinessCatalogImportPreview({
  sourceType,
  file = null,
  jobId = 0,
  sourceId = 0,
  profileId = 0,
  profileName = "",
  saveProfile = false,
  fieldMapping = {},
  categoryMappingRules = {},
  records = null,
  payload = null,
  recordPath = "",
  sourceConfig = {},
} = {}) {
  let requestOptions;

  if (file) {
    const formData = new FormData();
    formData.append("file", file);
    formData.append("sourceType", String(sourceType || "").trim().toLowerCase());
    if (sourceId) {
      formData.append("sourceId", String(sourceId));
    }
    if (profileId) {
      formData.append("profileId", String(profileId));
    }
    if (profileName) {
      formData.append("profileName", profileName);
    }
    if (saveProfile) {
      formData.append("saveProfile", "true");
    }
    formData.append("fieldMapping", JSON.stringify(fieldMapping || {}));
    formData.append("categoryMappingRules", JSON.stringify(categoryMappingRules || {}));
    requestOptions = {
      method: "POST",
      body: formData,
    };
  } else {
    requestOptions = {
      method: "POST",
      body: JSON.stringify({
        sourceType,
        jobId,
        sourceId,
        profileId,
        profileName,
        saveProfile,
        fieldMapping,
        categoryMappingRules,
        records,
        payload,
        recordPath,
        sourceConfig,
      }),
    };
  }

  const { response, data } = await requestJson("/api/business/catalog-import/preview", requestOptions);

  if (!response.ok || !data?.ok || !data?.preview) {
    return {
      ok: false,
      job: null,
      preview: null,
      errors: Array.isArray(data?.errors) ? data.errors : [],
      message: resolveApiMessage(data, "Preview i importit nuk u krijua."),
    };
  }

  return {
    ok: true,
    job: data.job || null,
    preview: data.preview || null,
    errors: [],
    message: data.message || "Preview i importit u krijua.",
  };
}

export async function commitBusinessCatalogImportPreview({
  jobId,
  skipRowIds = [],
  approvedGroupKeys = [],
} = {}) {
  const { response, data } = await requestJson("/api/business/catalog-import/commit", {
    method: "POST",
    body: JSON.stringify({
      jobId,
      skipRowIds,
      approvedGroupKeys,
    }),
  });

  if (!response.ok || !data?.ok) {
    return {
      ok: false,
      count: 0,
      products: [],
      message: resolveApiMessage(data, "Importi final nuk u krye."),
    };
  }

  return {
    ok: true,
    count: Number(data.count || 0),
    products: Array.isArray(data.products) ? data.products : [],
    message: data.message || "Importi final u krye me sukses.",
  };
}

export async function saveBusinessCatalogImportProfile(payload) {
  const { response, data } = await requestJson("/api/business/catalog-import/profile", {
    method: "POST",
    body: JSON.stringify(payload || {}),
  });

  if (!response.ok || !data?.ok) {
    return {
      ok: false,
      profile: null,
      message: resolveApiMessage(data, "Profili i importit nuk u ruajt."),
    };
  }

  return {
    ok: true,
    profile: data.profile || null,
    message: data.message || "Profili i importit u ruajt.",
  };
}

export async function saveBusinessCatalogImportSource(payload) {
  const { response, data } = await requestJson("/api/business/catalog-import/source", {
    method: "POST",
    body: JSON.stringify(payload || {}),
  });

  if (!response.ok || !data?.ok) {
    return {
      ok: false,
      source: null,
      message: resolveApiMessage(data, "Burimi i importit nuk u ruajt."),
    };
  }

  return {
    ok: true,
    source: data.source || null,
    message: data.message || "Burimi i importit u ruajt.",
  };
}

export async function syncBusinessCatalogImportSource(sourceId) {
  const { response, data } = await requestJson("/api/business/catalog-import/sync", {
    method: "POST",
    body: JSON.stringify({ sourceId }),
  });

  if (!response.ok || !data?.ok || !data?.preview) {
    return {
      ok: false,
      job: null,
      preview: null,
      errors: Array.isArray(data?.errors) ? data.errors : [],
      message: resolveApiMessage(data, "Sinkronizimi i burimit nuk u pergatit."),
    };
  }

  return {
    ok: true,
    job: data.job || null,
    preview: data.preview || null,
    errors: [],
    message: data.message || "Sinkronizimi i burimit u pergatit.",
  };
}
