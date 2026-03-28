const GET_REQUEST_CACHE = new Map();
const INFLIGHT_GET_REQUESTS = new Map();

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

export async function requestJson(url, options = {}, runtime = {}) {
  const config = { ...options };
  config.headers = { ...(options.headers || {}) };
  const method = normalizeMethod(config);
  const cacheTtlMs = Math.max(0, Number(runtime.cacheTtlMs || 0));
  const cacheKey = runtime.cacheKey || `${method}:${url}`;
  const canUseCache = method === "GET" && !config.body && cacheTtlMs > 0;

  if (
    config.body &&
    !(config.body instanceof FormData) &&
    !config.headers["Content-Type"]
  ) {
    config.headers["Content-Type"] = "application/json";
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

  const pendingRequest = (async () => {
    const response = await fetch(url, config);
    let data = {};

    try {
      data = await response.json();
    } catch (error) {
      console.error(error);
    }

    const result = {
      response: createResponseMeta(response),
      data,
    };

    if (canUseCache && response.ok) {
      GET_REQUEST_CACHE.set(cacheKey, {
        expiresAt: Date.now() + cacheTtlMs,
        response: result.response,
        data: cloneJsonPayload(result.data),
      });
    }

    if (method !== "GET" && response.ok) {
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

export async function fetchCurrentUserOptional() {
  try {
    const { response, data } = await requestJson("/api/me", {}, { cacheTtlMs: 1500 });
    if (!response.ok || !data.ok || !data.user) {
      return null;
    }

    return data.user;
  } catch (error) {
    console.error(error);
    return null;
  }
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

export async function searchProductsByImage(file, options = {}) {
  const uploadData = new FormData();
  uploadData.append("image", file);

  if (options.category) {
    uploadData.append("category", String(options.category).trim());
  }

  if (options.categoryGroup) {
    uploadData.append("categoryGroup", String(options.categoryGroup).trim());
  }

  if (Number.isFinite(Number(options.limit))) {
    uploadData.append("limit", String(options.limit));
  }

  if (Number.isFinite(Number(options.offset))) {
    uploadData.append("offset", String(options.offset));
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
    total: Number(data.total || 0),
    hasMore: Boolean(data.hasMore),
    message: data.message || "U gjeten produkte te ngjashme sipas fotos.",
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
    anchor.download = "trego-products-template.csv";
    document.body.appendChild(anchor);
    anchor.click();
    anchor.remove();
  } finally {
    window.setTimeout(() => URL.revokeObjectURL(objectUrl), 0);
  }

  return {
    ok: true,
    message: "Template-i u shkarkua me sukses.",
  };
}

export async function importBusinessProductsFile(file) {
  const formData = new FormData();
  formData.append("file", file);

  const { response, data } = await requestJson("/api/business/products/import", {
    method: "POST",
    body: formData,
  });

  if (!response.ok || !data?.ok) {
    return {
      ok: false,
      count: 0,
      products: [],
      message: resolveApiMessage(data, "Importi i artikujve nuk u krye."),
    };
  }

  return {
    ok: true,
    count: Number(data.count || 0),
    products: Array.isArray(data.products) ? data.products : [],
    message: data.message || "Artikujt u importuan me sukses.",
  };
}
