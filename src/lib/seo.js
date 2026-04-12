const MANAGED_SEO_ATTR = "data-tregio-seo-managed";

function normalizeText(value, maxLength = 320) {
  return String(value || "")
    .replace(/<[^>]*>/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, maxLength);
}

function findHeadTag(tagName, keyAttr, keyValue) {
  if (typeof document === "undefined") {
    return null;
  }

  return Array.from(document.head.querySelectorAll(tagName))
    .find((node) => node.getAttribute(keyAttr) === keyValue) || null;
}

function upsertHeadTag(tagName, keyAttr, keyValue, attributes = {}) {
  if (typeof document === "undefined") {
    return null;
  }

  let node = findHeadTag(tagName, keyAttr, keyValue);
  if (!node) {
    node = document.createElement(tagName);
    document.head.appendChild(node);
  }

  Object.entries(attributes).forEach(([attributeName, attributeValue]) => {
    if (attributeValue === null || attributeValue === undefined || attributeValue === "") {
      node.removeAttribute(attributeName);
      return;
    }

    node.setAttribute(attributeName, String(attributeValue));
  });

  node.setAttribute(MANAGED_SEO_ATTR, "true");
  return node;
}

function removeManagedHeadTag(tagName, keyAttr, keyValue) {
  const node = findHeadTag(tagName, keyAttr, keyValue);
  if (!node) {
    return;
  }

  if (node.getAttribute(MANAGED_SEO_ATTR) === "true") {
    node.remove();
  }
}

export function buildAbsoluteUrl(value = "") {
  const rawValue = String(value || "").trim();
  if (!rawValue) {
    return "";
  }

  if (/^https?:\/\//i.test(rawValue)) {
    return rawValue;
  }

  if (typeof window === "undefined") {
    return rawValue.startsWith("/") ? rawValue : `/${rawValue}`;
  }

  return new URL(rawValue.startsWith("/") ? rawValue : `/${rawValue}`, window.location.origin).toString();
}

export function buildBreadcrumbJsonLd(items = []) {
  const normalizedItems = items
    .map((item, index) => ({
      name: normalizeText(item?.name || item?.label || ""),
      item: buildAbsoluteUrl(item?.item || item?.to || item?.url || ""),
      position: index + 1,
    }))
    .filter((item) => item.name && item.item);

  if (normalizedItems.length === 0) {
    return null;
  }

  return {
    "@context": "https://schema.org",
    "@type": "BreadcrumbList",
    itemListElement: normalizedItems.map((item) => ({
      "@type": "ListItem",
      position: item.position,
      name: item.name,
      item: item.item,
    })),
  };
}

export function clearManagedSeo() {
  if (typeof document === "undefined") {
    return;
  }

  document.head
    .querySelectorAll(`[${MANAGED_SEO_ATTR}="true"]`)
    .forEach((node) => node.remove());
}

export function applyDocumentSeo(config = {}) {
  if (typeof document === "undefined") {
    return;
  }

  const title = normalizeText(config.title || "TREGIO", 120) || "TREGIO";
  const description = normalizeText(config.description || "", 320);
  const canonicalUrl = buildAbsoluteUrl(config.canonicalPath || config.canonicalUrl || window.location.href);
  const imageUrl = buildAbsoluteUrl(config.image || "");
  const type = normalizeText(config.type || "website", 40) || "website";
  const robots = normalizeText(config.robots || "index,follow", 120) || "index,follow";
  const twitterCard = normalizeText(
    config.twitterCard || (imageUrl ? "summary_large_image" : "summary"),
    40,
  ) || "summary";
  const jsonLdEntries = Array.isArray(config.jsonLd)
    ? config.jsonLd.filter(Boolean)
    : (config.jsonLd ? [config.jsonLd] : []);

  document.title = title;

  if (description) {
    upsertHeadTag("meta", "name", "description", {
      name: "description",
      content: description,
    });
  } else {
    removeManagedHeadTag("meta", "name", "description");
  }

  if (canonicalUrl) {
    upsertHeadTag("link", "rel", "canonical", {
      rel: "canonical",
      href: canonicalUrl,
    });
  }

  upsertHeadTag("meta", "name", "robots", {
    name: "robots",
    content: robots,
  });
  upsertHeadTag("meta", "property", "og:title", {
    property: "og:title",
    content: title,
  });
  upsertHeadTag("meta", "property", "og:description", {
    property: "og:description",
    content: description || title,
  });
  upsertHeadTag("meta", "property", "og:type", {
    property: "og:type",
    content: type,
  });
  upsertHeadTag("meta", "property", "og:site_name", {
    property: "og:site_name",
    content: "TREGIO",
  });
  if (canonicalUrl) {
    upsertHeadTag("meta", "property", "og:url", {
      property: "og:url",
      content: canonicalUrl,
    });
  }

  if (imageUrl) {
    upsertHeadTag("meta", "property", "og:image", {
      property: "og:image",
      content: imageUrl,
    });
    upsertHeadTag("meta", "name", "twitter:image", {
      name: "twitter:image",
      content: imageUrl,
    });
  } else {
    removeManagedHeadTag("meta", "property", "og:image");
    removeManagedHeadTag("meta", "name", "twitter:image");
  }

  upsertHeadTag("meta", "name", "twitter:card", {
    name: "twitter:card",
    content: twitterCard,
  });
  upsertHeadTag("meta", "name", "twitter:title", {
    name: "twitter:title",
    content: title,
  });
  upsertHeadTag("meta", "name", "twitter:description", {
    name: "twitter:description",
    content: description || title,
  });

  document.head
    .querySelectorAll(`script[type="application/ld+json"][${MANAGED_SEO_ATTR}="true"]`)
    .forEach((node) => node.remove());

  jsonLdEntries.forEach((entry) => {
    const scriptNode = document.createElement("script");
    scriptNode.type = "application/ld+json";
    scriptNode.setAttribute(MANAGED_SEO_ATTR, "true");
    scriptNode.textContent = JSON.stringify(entry);
    document.head.appendChild(scriptNode);
  });
}
