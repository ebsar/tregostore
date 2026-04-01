import type { ProductItem } from "../types/models";

const RECENTLY_VIEWED_PRODUCTS_KEY = "recently_viewed_products";
const MAX_RECENTLY_VIEWED_PRODUCTS = 10;

function sanitizeProductSnapshot(product: Partial<ProductItem> | null | undefined): ProductItem | null {
  const productId = Number(product?.id || 0);
  if (!Number.isFinite(productId) || productId <= 0) {
    return null;
  }

  return {
    id: productId,
    title: String(product?.title || "").trim() || "Produkt",
    imagePath: String(product?.imagePath || "").trim() || "",
    description: String(product?.description || "").trim(),
    price: Number(product?.price || 0),
    compareAtPrice: Number(product?.compareAtPrice ?? 0),
    businessName: String(product?.businessName || "").trim(),
    averageRating: Number(product?.averageRating ?? 0),
    reviewCount: Number(product?.reviewCount || 0),
    buyersCount: Number(product?.buyersCount || 0),
    category: String(product?.category || "").trim(),
    productType: String(product?.productType || "").trim(),
    requiresVariantSelection: Boolean(product?.requiresVariantSelection),
    availableSizes: Array.isArray(product?.availableSizes) ? [...product!.availableSizes!] : [],
    availableColors: Array.isArray(product?.availableColors) ? [...product!.availableColors!] : [],
    variantInventory: Array.isArray(product?.variantInventory) ? [...product!.variantInventory!] : [],
    stockQuantity: Number(product?.stockQuantity || 0),
  };
}

export function readRecentlyViewedProducts(): ProductItem[] {
  if (typeof window === "undefined") {
    return [];
  }

  try {
    const rawValue = window.localStorage.getItem(RECENTLY_VIEWED_PRODUCTS_KEY) || "[]";
    const parsed = JSON.parse(rawValue);
    if (!Array.isArray(parsed)) {
      return [];
    }

    return parsed
      .map((entry) => sanitizeProductSnapshot(entry))
      .filter((entry): entry is ProductItem => Boolean(entry))
      .slice(0, MAX_RECENTLY_VIEWED_PRODUCTS);
  } catch (error) {
    console.error(error);
    return [];
  }
}

export function rememberRecentlyViewedProduct(product: Partial<ProductItem> | null | undefined): ProductItem[] {
  if (typeof window === "undefined") {
    return [];
  }

  const snapshot = sanitizeProductSnapshot(product);
  if (!snapshot) {
    return readRecentlyViewedProducts();
  }

  const nextProducts = [
    snapshot,
    ...readRecentlyViewedProducts().filter((entry) => Number(entry.id || 0) !== snapshot.id),
  ].slice(0, MAX_RECENTLY_VIEWED_PRODUCTS);

  try {
    window.localStorage.setItem(RECENTLY_VIEWED_PRODUCTS_KEY, JSON.stringify(nextProducts));
  } catch (error) {
    console.error(error);
  }

  return nextProducts;
}

export function clearRecentlyViewedProducts() {
  if (typeof window === "undefined") {
    return;
  }

  try {
    window.localStorage.removeItem(RECENTLY_VIEWED_PRODUCTS_KEY);
  } catch (error) {
    console.error(error);
  }
}
