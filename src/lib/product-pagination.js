const MOBILE_PRODUCTS_MEDIA_QUERY = "(max-width: 640px)";
const MOBILE_PRODUCTS_PAGE_SIZE = 5;
const DEFAULT_PRODUCTS_PAGE_SIZE = 10;

export function getProductsPageSize() {
  if (typeof window === "undefined") {
    return DEFAULT_PRODUCTS_PAGE_SIZE;
  }

  return window.matchMedia(MOBILE_PRODUCTS_MEDIA_QUERY).matches
    ? MOBILE_PRODUCTS_PAGE_SIZE
    : DEFAULT_PRODUCTS_PAGE_SIZE;
}

export function subscribeProductsPageSize(callback) {
  if (typeof window === "undefined") {
    return () => {};
  }

  const mediaQuery = window.matchMedia(MOBILE_PRODUCTS_MEDIA_QUERY);
  const handleChange = () => {
    callback(getProductsPageSize());
  };

  if (typeof mediaQuery.addEventListener === "function") {
    mediaQuery.addEventListener("change", handleChange);
    return () => mediaQuery.removeEventListener("change", handleChange);
  }

  mediaQuery.addListener(handleChange);
  return () => mediaQuery.removeListener(handleChange);
}
