import { computed, ref, toValue, watch } from "vue";
import { requestJson, resolveApiMessage, searchProductsByImage } from "./api";

export const PRODUCTS_PAGE_SIZE = 10;

function normalizePaginationNumber(value, fallback = 0) {
  const nextValue = Number(value);
  return Number.isFinite(nextValue) ? nextValue : fallback;
}

function buildQueryString(params = {}) {
  const searchParams = new URLSearchParams();

  Object.entries(params).forEach(([key, value]) => {
    if (value === null || value === undefined || value === "") {
      return;
    }

    searchParams.set(key, String(value));
  });

  return searchParams.toString();
}

function normalizeProductsPage(page = {}) {
  const items = Array.isArray(page.items)
    ? page.items
    : Array.isArray(page.products)
      ? page.products
      : [];

  return {
    items,
    total: normalizePaginationNumber(page.total, items.length),
    limit: normalizePaginationNumber(page.limit, PRODUCTS_PAGE_SIZE),
    offset: normalizePaginationNumber(page.offset, 0),
    hasMore: Boolean(page.hasMore),
  };
}

async function fetchPaginatedProductsJson(url, fallbackMessage) {
  const { response, data } = await requestJson(url);
  if (!response.ok || !data?.ok) {
    throw new Error(resolveApiMessage(data, fallbackMessage));
  }

  return normalizeProductsPage({
    products: data.products,
    total: data.total,
    limit: data.limit,
    offset: data.offset,
    hasMore: data.hasMore,
  });
}

export async function fetchCatalogProductsPage({
  offset = 0,
  limit = PRODUCTS_PAGE_SIZE,
  category = "",
  categoryGroup = "",
} = {}) {
  const queryString = buildQueryString({
    limit,
    offset,
    category,
    categoryGroup,
  });

  return fetchPaginatedProductsJson(
    `/api/products?${queryString}`,
    "Produktet nuk u ngarkuan.",
  );
}

export async function fetchSearchProductsPage({
  offset = 0,
  limit = PRODUCTS_PAGE_SIZE,
  query = "",
  category = "",
  categoryGroup = "",
} = {}) {
  const queryString = buildQueryString({
    q: query,
    limit,
    offset,
    category,
    categoryGroup,
  });

  return fetchPaginatedProductsJson(
    `/api/products/search?${queryString}`,
    "Produktet nuk u ngarkuan.",
  );
}

export async function fetchBusinessPublicProductsPage({
  businessId,
  offset = 0,
  limit = PRODUCTS_PAGE_SIZE,
} = {}) {
  const queryString = buildQueryString({
    id: businessId,
    limit,
    offset,
  });

  return fetchPaginatedProductsJson(
    `/api/business/public-products?${queryString}`,
    "Produktet e biznesit nuk u ngarkuan.",
  );
}

export async function fetchAdminProductsPage({
  offset = 0,
  limit = PRODUCTS_PAGE_SIZE,
} = {}) {
  const queryString = buildQueryString({ limit, offset });
  return fetchPaginatedProductsJson(
    `/api/admin/products?${queryString}`,
    "Lista e artikujve nuk u ngarkua.",
  );
}

export async function fetchBusinessProductsPage({
  offset = 0,
  limit = PRODUCTS_PAGE_SIZE,
} = {}) {
  const queryString = buildQueryString({ limit, offset });
  return fetchPaginatedProductsJson(
    `/api/business/products?${queryString}`,
    "Lista e artikujve nuk u ngarkua.",
  );
}

export async function fetchVisualSearchProductsPage({
  file,
  offset = 0,
  limit = PRODUCTS_PAGE_SIZE,
  category = "",
  categoryGroup = "",
} = {}) {
  const result = await searchProductsByImage(file, {
    category,
    categoryGroup,
    limit,
    offset,
  });

  if (!result.ok) {
    throw new Error(result.message || "Kerkimi me foto nuk u krye.");
  }

  return normalizeProductsPage({
    products: result.products,
    total: result.total,
    limit,
    offset,
    hasMore: result.hasMore,
  });
}

function resolveErrorMessage(error, fallbackMessage) {
  return error instanceof Error && error.message
    ? error.message
    : fallbackMessage;
}

export function usePaginatedProductsQuery(options = {}) {
  const pageSize = Math.max(1, Number(options.pageSize || PRODUCTS_PAGE_SIZE));
  const initialErrorMessage = options.errorMessage || "Produktet nuk u ngarkuan.";
  const nextPageErrorMessage =
    options.loadMoreErrorMessage || "Produktet e tjera nuk u ngarkuan.";
  const products = ref([]);
  const total = ref(0);
  const hasMore = ref(false);
  const isInitialLoading = ref(false);
  const isLoadingMore = ref(false);
  const error = ref(null);
  const loadMoreErrorMessage = ref("");
  const enabled = computed(() => Boolean(toValue(options.enabled ?? true)));
  const queryKeySignature = computed(() => JSON.stringify(toValue(options.queryKey) || []));
  const isEmpty = computed(() => !isInitialLoading.value && !error.value && products.value.length === 0);
  const errorMessage = computed(() =>
    error.value ? resolveErrorMessage(error.value, initialErrorMessage) : "",
  );
  let activeRequestToken = 0;

  function resetState() {
    products.value = [];
    total.value = 0;
    hasMore.value = false;
    isInitialLoading.value = false;
    isLoadingMore.value = false;
    error.value = null;
    loadMoreErrorMessage.value = "";
  }

  async function loadInitialPage() {
    const requestToken = activeRequestToken;
    loadMoreErrorMessage.value = "";
    error.value = null;
    isInitialLoading.value = true;
    isLoadingMore.value = false;

    try {
      const page = normalizeProductsPage(
        await options.fetchPage({
          offset: 0,
          limit: pageSize,
        }),
      );

      if (requestToken !== activeRequestToken) {
        return;
      }

      products.value = Array.isArray(page.items) ? page.items : [];
      total.value = normalizePaginationNumber(page.total, products.value.length);
      hasMore.value = Boolean(page.hasMore);
    } catch (nextError) {
      if (requestToken !== activeRequestToken) {
        return;
      }

      products.value = [];
      total.value = 0;
      hasMore.value = false;
      error.value = nextError;
    } finally {
      if (requestToken === activeRequestToken) {
        isInitialLoading.value = false;
      }
    }
  }

  watch(
    queryKeySignature,
    () => {
      loadMoreErrorMessage.value = "";
    },
  );

  watch(
    enabled,
    (isEnabled) => {
      if (!isEnabled) {
        activeRequestToken += 1;
        resetState();
      }
    },
  );

  watch(
    [queryKeySignature, enabled],
    async ([, isEnabled]) => {
      activeRequestToken += 1;

      if (!isEnabled) {
        resetState();
        return;
      }

      await loadInitialPage();
    },
    { immediate: true },
  );

  async function loadMore() {
    if (!enabled.value || !hasMore.value || isLoadingMore.value || isInitialLoading.value) {
      return;
    }

    loadMoreErrorMessage.value = "";
    const requestToken = activeRequestToken;
    const currentOffset = products.value.length;
    isLoadingMore.value = true;

    try {
      const page = normalizeProductsPage(
        await options.fetchPage({
          offset: currentOffset,
          limit: pageSize,
        }),
      );

      if (requestToken !== activeRequestToken) {
        return;
      }

      const existingIds = new Set(products.value.map((item) => Number(item?.id)));
      const nextItems = Array.isArray(page.items)
        ? page.items.filter((item) => !existingIds.has(Number(item?.id)))
        : [];

      products.value = [...products.value, ...nextItems];
      total.value = normalizePaginationNumber(page.total, products.value.length);
      hasMore.value = Boolean(page.hasMore);
    } catch (nextError) {
      if (requestToken !== activeRequestToken) {
        return;
      }

      loadMoreErrorMessage.value = resolveErrorMessage(nextError, nextPageErrorMessage);
    } finally {
      if (requestToken === activeRequestToken) {
        isLoadingMore.value = false;
      }
    }
  }

  async function refetch() {
    if (!enabled.value) {
      resetState();
      return;
    }

    activeRequestToken += 1;
    await loadInitialPage();
  }

  return {
    products,
    total,
    hasMore,
    isEmpty,
    isInitialLoading,
    isLoadingMore,
    isError: computed(() => Boolean(error.value)),
    error,
    errorMessage,
    loadMoreErrorMessage,
    loadMore,
    refetch,
  };
}
