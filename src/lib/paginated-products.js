import { computed, ref, toValue, watch } from "vue";
import { useInfiniteQuery } from "@tanstack/vue-query";
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
  const loadMoreErrorMessage = ref("");

  const query = useInfiniteQuery({
    queryKey: options.queryKey,
    enabled: options.enabled ?? true,
    initialPageParam: 0,
    queryFn: async ({ pageParam = 0 }) =>
      normalizeProductsPage(
        await options.fetchPage({
          offset: normalizePaginationNumber(pageParam, 0),
          limit: pageSize,
        }),
      ),
    getNextPageParam: (lastPage) =>
      lastPage.hasMore ? lastPage.offset + lastPage.items.length : undefined,
    staleTime: options.staleTime ?? 15000,
    gcTime: options.gcTime ?? 5 * 60 * 1000,
    retry: options.retry ?? 1,
    refetchOnWindowFocus: false,
    refetchOnReconnect: false,
  });

  const products = computed(() =>
    Array.isArray(query.data.value?.pages)
      ? query.data.value.pages.flatMap((page) => page.items)
      : [],
  );

  const total = computed(() => {
    const pages = Array.isArray(query.data.value?.pages) ? query.data.value.pages : [];
    if (!pages.length) {
      return 0;
    }

    return normalizePaginationNumber(pages[pages.length - 1]?.total, products.value.length);
  });

  const hasMore = computed(() => Boolean(query.hasNextPage.value));
  const isLoadingMore = computed(() => Boolean(query.isFetchingNextPage.value));
  const isInitialLoading = computed(() => Boolean(query.isPending.value) && products.value.length === 0);
  const isEmpty = computed(() => !isInitialLoading.value && !query.isError.value && products.value.length === 0);
  const errorMessage = computed(() =>
    query.isError.value ? resolveErrorMessage(query.error.value, initialErrorMessage) : "",
  );

  watch(
    () => JSON.stringify(toValue(options.queryKey) || []),
    () => {
      loadMoreErrorMessage.value = "";
    },
  );

  watch(
    () => Boolean(toValue(options.enabled)),
    (isEnabled) => {
      if (!isEnabled) {
        loadMoreErrorMessage.value = "";
      }
    },
  );

  async function loadMore() {
    if (!hasMore.value || isLoadingMore.value) {
      return;
    }

    loadMoreErrorMessage.value = "";

    try {
      await query.fetchNextPage();
    } catch (error) {
      loadMoreErrorMessage.value = resolveErrorMessage(error, nextPageErrorMessage);
    }
  }

  return {
    ...query,
    products,
    total,
    hasMore,
    isEmpty,
    isInitialLoading,
    isLoadingMore,
    errorMessage,
    loadMoreErrorMessage,
    loadMore,
  };
}
