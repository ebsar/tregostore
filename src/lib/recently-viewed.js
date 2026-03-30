const RECENTLY_VIEWED_PRODUCTS_KEY = "recently_viewed_products";
const LEGACY_RECENTLY_VIEWED_PRODUCTS_KEY = "trego-recently-viewed-products";
const MAX_RECENTLY_VIEWED_PRODUCTS = 10;

function sanitizeProductSnapshot(product) {
  const productId = Number(product?.id || 0);
  if (!Number.isFinite(productId) || productId <= 0) {
    return null;
  }

  return {
    id: productId,
    title: String(product?.title || product?.productName || "").trim() || "Produkt",
    imagePath: String(product?.imagePath || product?.image_path || product?.image || "").trim() || "/bujqesia.webp",
    price: Number(product?.price || 0),
    compareAtPrice: Number(product?.compareAtPrice ?? product?.originalPrice ?? 0),
    businessName: String(product?.businessName || "").trim(),
    averageRating: Number(product?.averageRating ?? product?.ratingAverage ?? 0),
    reviewCount: Number(product?.reviewCount || 0),
    buyersCount: Number(product?.buyersCount || 0),
    category: String(product?.category || "").trim(),
    requiresVariantSelection: Boolean(product?.requiresVariantSelection),
  };
}

export function readRecentlyViewedProducts() {
  if (typeof window === "undefined") {
    return [];
  }

  try {
    const rawValue = window.localStorage.getItem(RECENTLY_VIEWED_PRODUCTS_KEY)
      || window.localStorage.getItem(LEGACY_RECENTLY_VIEWED_PRODUCTS_KEY)
      || "[]";
    const parsed = JSON.parse(rawValue);
    if (!Array.isArray(parsed)) {
      return [];
    }

    return parsed
      .map((entry) => sanitizeProductSnapshot(entry))
      .filter(Boolean)
      .slice(0, MAX_RECENTLY_VIEWED_PRODUCTS);
  } catch (error) {
    console.error(error);
    return [];
  }
}

export function rememberRecentlyViewedProduct(product) {
  if (typeof window === "undefined") {
    return [];
  }

  const snapshot = sanitizeProductSnapshot(product);
  if (!snapshot) {
    return readRecentlyViewedProducts();
  }

  const nextProducts = [
    snapshot,
    ...readRecentlyViewedProducts().filter((entry) => Number(entry?.id || 0) !== snapshot.id),
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
    window.localStorage.removeItem(LEGACY_RECENTLY_VIEWED_PRODUCTS_KEY);
  } catch (error) {
    console.error(error);
  }
}
