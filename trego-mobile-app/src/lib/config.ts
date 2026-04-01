const rawApiBaseUrl = String(import.meta.env.VITE_API_BASE_URL || "https://www.tregos.store").trim();

export const API_BASE_URL = rawApiBaseUrl.replace(/\/+$/, "");

export function createApiUrl(path: string): string {
  if (/^https?:\/\//i.test(path)) {
    return path;
  }

  const normalizedPath = path.startsWith("/") ? path : `/${path}`;

  if (
    import.meta.env.DEV &&
    typeof window !== "undefined" &&
    /^(localhost|127\.0\.0\.1|0\.0\.0\.0)$/i.test(window.location.hostname)
  ) {
    return normalizedPath;
  }

  return `${API_BASE_URL}${normalizedPath}`;
}
