import { reactive } from "vue";

export const COMPARE_PRODUCTS_KEY = "trego_compare_products";
export const MAX_COMPARE_PRODUCTS = 4;

export const compareState = reactive({
  items: [],
  loaded: false,
});

function normalizeCompareText(value) {
  return String(value || "").trim();
}

function getCompareProductId(product) {
  const productId = Number(product?.id ?? product?.productId ?? 0);
  if (!Number.isFinite(productId) || productId <= 0) {
    return 0;
  }

  return productId;
}

function createCompareSnapshot(product) {
  const productId = getCompareProductId(product);
  if (!productId) {
    return null;
  }

  return {
    id: productId,
    productId,
    title: normalizeCompareText(product?.title) || "Produkt",
    description: normalizeCompareText(product?.description),
    imagePath: normalizeCompareText(product?.imagePath || product?.image_path || product?.image) || "/bujqesia.webp",
    price: Number(product?.price || 0),
    compareAtPrice: Number(product?.compareAtPrice ?? product?.originalPrice ?? 0),
    businessName: normalizeCompareText(product?.businessName),
    category: normalizeCompareText(product?.category),
    productType: normalizeCompareText(product?.productType),
    averageRating: Number(product?.averageRating ?? product?.ratingAverage ?? 0),
    reviewCount: Number(product?.reviewCount || 0),
    buyersCount: Number(product?.buyersCount || 0),
    stockQuantity: Number(product?.stockQuantity || 0),
    showStockPublic: Boolean(product?.showStockPublic),
    requiresVariantSelection: Boolean(product?.requiresVariantSelection),
    size: normalizeCompareText(product?.size).toUpperCase(),
    color: normalizeCompareText(product?.color).toLowerCase(),
  };
}

function buildCompareKey(item = {}) {
  const productId = getCompareProductId(item);
  return productId ? String(productId) : "";
}

function normalizeCompareItems(items = []) {
  if (!Array.isArray(items)) {
    return [];
  }

  const nextItems = [];
  const seenIds = new Set();

  items.forEach((item) => {
    const snapshot = createCompareSnapshot(item);
    if (!snapshot) {
      return;
    }

    const compareKey = buildCompareKey(snapshot);
    if (!compareKey || seenIds.has(compareKey)) {
      return;
    }

    seenIds.add(compareKey);
    nextItems.push(snapshot);
  });

  return nextItems.slice(0, MAX_COMPARE_PRODUCTS);
}

function persistCompareItems(items) {
  const normalizedItems = normalizeCompareItems(items);

  try {
    window.localStorage.setItem(COMPARE_PRODUCTS_KEY, JSON.stringify(normalizedItems));
  } catch (error) {
    console.error(error);
  }

  compareState.items = normalizedItems;
  compareState.loaded = true;
  return normalizedItems;
}

function readCompareItems() {
  if (typeof window === "undefined") {
    return [];
  }

  try {
    const rawValue = window.localStorage.getItem(COMPARE_PRODUCTS_KEY);
    if (!rawValue) {
      return [];
    }

    const parsedValue = JSON.parse(rawValue);
    return normalizeCompareItems(parsedValue);
  } catch (error) {
    console.error(error);
    return [];
  }
}

function dispatchCompareToast(message, type = "info") {
  if (typeof window === "undefined") {
    return;
  }

  window.dispatchEvent(
    new CustomEvent("trego:toast", {
      detail: {
        message,
        type,
      },
    }),
  );
}

export function loadCompareItems() {
  const nextItems = readCompareItems();
  compareState.items = nextItems;
  compareState.loaded = true;
  return nextItems;
}

export function ensureCompareItemsLoaded() {
  if (!compareState.loaded) {
    return loadCompareItems();
  }

  return compareState.items;
}

export function hasComparedProduct(productId) {
  return compareState.items.some((item) => Number(item.id || item.productId || 0) === Number(productId));
}

export function toggleComparedProduct(product) {
  const snapshot = createCompareSnapshot(product);
  if (!snapshot) {
    return compareState.items;
  }

  const snapshotKey = buildCompareKey(snapshot);
  const existingIndex = compareState.items.findIndex(
    (item) => buildCompareKey(item) === snapshotKey,
  );

  if (existingIndex >= 0) {
    const nextItems = [...compareState.items];
    nextItems.splice(existingIndex, 1);
    return persistCompareItems(nextItems);
  }

  if (compareState.items.length >= MAX_COMPARE_PRODUCTS) {
    dispatchCompareToast(`Mund te krahasosh deri ${MAX_COMPARE_PRODUCTS} produkte njeheresh.`, "info");
    return compareState.items;
  }

  return persistCompareItems([snapshot, ...compareState.items]);
}

export function removeComparedProduct(productOrId) {
  const productId = Number(
    typeof productOrId === "object"
      ? productOrId?.id ?? productOrId?.productId ?? 0
      : productOrId,
  );

  if (!Number.isFinite(productId) || productId <= 0) {
    return compareState.items;
  }

  const nextItems = compareState.items.filter((item) => Number(item.id || item.productId || 0) !== productId);
  return persistCompareItems(nextItems);
}

export function clearComparedProducts() {
  try {
    window.localStorage.removeItem(COMPARE_PRODUCTS_KEY);
  } catch (error) {
    console.error(error);
  }

  compareState.items = [];
  compareState.loaded = true;
  return [];
}

export function getComparedProductsCount() {
  return compareState.items.length;
}

