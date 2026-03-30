const RECENT_SEARCHES_KEY = "trego-recent-searches";
const MAX_RECENT_SEARCHES = 8;

function normalizeSearchTerm(value) {
  return String(value || "")
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/\s+/g, " ")
    .trim();
}

export function readRecentSearches() {
  if (typeof window === "undefined") {
    return [];
  }

  try {
    const parsed = JSON.parse(window.localStorage.getItem(RECENT_SEARCHES_KEY) || "[]");
    if (!Array.isArray(parsed)) {
      return [];
    }

    return parsed
      .map((item) => String(item || "").trim())
      .filter(Boolean)
      .slice(0, MAX_RECENT_SEARCHES);
  } catch (error) {
    console.error(error);
    return [];
  }
}

export function rememberRecentSearch(value) {
  if (typeof window === "undefined") {
    return [];
  }

  const nextValue = String(value || "").trim();
  if (!nextValue) {
    return readRecentSearches();
  }

  const nextSearches = [
    nextValue,
    ...readRecentSearches().filter((item) => normalizeSearchTerm(item) !== normalizeSearchTerm(nextValue)),
  ].slice(0, MAX_RECENT_SEARCHES);

  try {
    window.localStorage.setItem(RECENT_SEARCHES_KEY, JSON.stringify(nextSearches));
  } catch (error) {
    console.error(error);
  }

  return nextSearches;
}

export function clearRecentSearches() {
  if (typeof window === "undefined") {
    return [];
  }

  try {
    window.localStorage.removeItem(RECENT_SEARCHES_KEY);
  } catch (error) {
    console.error(error);
  }

  return [];
}

export function removeRecentSearch(value) {
  if (typeof window === "undefined") {
    return [];
  }

  const normalizedValue = normalizeSearchTerm(value);
  const nextSearches = readRecentSearches().filter(
    (item) => normalizeSearchTerm(item) !== normalizedValue,
  );

  try {
    window.localStorage.setItem(RECENT_SEARCHES_KEY, JSON.stringify(nextSearches));
  } catch (error) {
    console.error(error);
  }

  return nextSearches;
}
