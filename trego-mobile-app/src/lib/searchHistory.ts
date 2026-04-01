const SEARCH_HISTORY_KEY = "trego_mobile_recent_searches";
const MAX_RECENT_SEARCHES = 8;

export function readMobileRecentSearches(): string[] {
  if (typeof window === "undefined") {
    return [];
  }

  try {
    const parsed = JSON.parse(window.localStorage.getItem(SEARCH_HISTORY_KEY) || "[]");
    if (!Array.isArray(parsed)) {
      return [];
    }
    return parsed
      .map((value) => String(value || "").trim())
      .filter(Boolean)
      .slice(0, MAX_RECENT_SEARCHES);
  } catch {
    return [];
  }
}

export function writeMobileRecentSearches(items: string[]) {
  const next = items
    .map((value) => String(value || "").trim())
    .filter(Boolean)
    .slice(0, MAX_RECENT_SEARCHES);

  if (typeof window !== "undefined") {
    window.localStorage.setItem(SEARCH_HISTORY_KEY, JSON.stringify(next));
  }

  return next;
}

export function pushMobileRecentSearch(value: string) {
  const normalized = String(value || "").trim();
  if (!normalized) {
    return readMobileRecentSearches();
  }

  const current = readMobileRecentSearches();
  return writeMobileRecentSearches([normalized, ...current.filter((item) => item !== normalized)]);
}
