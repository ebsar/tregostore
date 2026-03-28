import {
  PRODUCT_COLOR_LABELS,
  PRODUCT_COLOR_OPTIONS,
  PRODUCT_PAGE_SECTION_OPTIONS,
  PRODUCT_AUDIENCE_OPTIONS,
  PRODUCT_SECTION_OPTIONS,
  PRODUCT_TYPE_LABELS,
  PRODUCT_TYPE_OPTIONS_BY_CATEGORY,
  SECTION_PRODUCT_TYPE_OPTIONS,
  buildCategoryFromSelection,
  deriveSectionFromCategory,
  isClothingSection as isCatalogClothingSection,
} from "./product-catalog";

export const LOGIN_GREETING_KEY = "trego_login_greeting";
export const CHECKOUT_ADDRESS_DRAFT_KEY = "trego_checkout_address_draft";
export const CHECKOUT_PAYMENT_METHOD_KEY = "trego_checkout_payment_method";
export const CHECKOUT_SELECTED_CART_IDS_KEY = "trego_checkout_selected_cart_ids";
export const ORDER_CONFIRMATION_MESSAGE_KEY = "trego_order_confirmation_message";
export const APP_LOADER_MIN_DURATION_MS = 160;

function createSearchHref({ categoryGroup = "", category = "", productType = "" } = {}) {
  const params = new URLSearchParams();
  if (categoryGroup) {
    params.set("categoryGroup", categoryGroup);
  }
  if (category) {
    params.set("category", category);
  }
  if (productType) {
    params.set("productType", productType);
  }

  return `/kerko?${params.toString()}`;
}

function createNavigationGroups(sectionValue) {
  const audiences = PRODUCT_AUDIENCE_OPTIONS[sectionValue] || [];

  if (audiences.length > 0) {
    return audiences.map((audience) => {
      const category = buildCategoryFromSelection(sectionValue, audience.value);
      const productTypes = PRODUCT_TYPE_OPTIONS_BY_CATEGORY[category] || [];

      return {
        key: `${sectionValue}-${audience.value}`,
        label: audience.label,
        href: createSearchHref({ category }),
        items: productTypes.map((productType) => ({
          key: `${category}-${productType.value}`,
          label: productType.label,
          href: createSearchHref({ category, productType: productType.value }),
        })),
      };
    });
  }

  const productTypes = PRODUCT_TYPE_OPTIONS_BY_CATEGORY[sectionValue] || [];

  return [{
    key: `${sectionValue}-group`,
    label: `Te gjitha ${PRODUCT_PAGE_SECTION_OPTIONS.find((option) => option.value === sectionValue)?.label || sectionValue}`,
    href: createSearchHref({ category: sectionValue }),
    items: productTypes.map((productType) => ({
      key: `${sectionValue}-${productType.value}`,
      label: productType.label,
      href: createSearchHref({ category: sectionValue, productType: productType.value }),
    })),
  }];
}

export const PRIMARY_NAVIGATION = PRODUCT_PAGE_SECTION_OPTIONS.map((section) => {
  const hasAudiences = (PRODUCT_AUDIENCE_OPTIONS[section.value] || []).length > 0;

  return {
    key: section.value,
    label: section.label,
    href: hasAudiences
      ? createSearchHref({ categoryGroup: section.value })
      : createSearchHref({ category: section.value }),
    groups: createNavigationGroups(section.value),
  };
});

export const HOME_PROMO_SLIDES = [
  {
    title: "Oferta te reja cdo jave",
    description:
      "Zbulo produktet me te kerkuara per shtepi, bukuri dhe stil ne nje vend te vetem.",
    badge: "Reklame 01",
    ctaLabel: "Shiko produktet",
    ctaHref: "/kerko",
    imagePath: "/bujqesia.jpg",
  },
  {
    title: "Veshje dhe kozmetike ne trend",
    description:
      "Nga veshjet per meshkuj e femra deri te kozmetika e perditshme, tash i gjen me shpejt.",
    badge: "Reklame 02",
    ctaLabel: "Kerko koleksionin",
    ctaHref: "/kerko?category=clothing-women",
    imagePath: "/gjelbert.jpeg",
  },
  {
    title: "Teknologji dhe shtepi me oferta",
    description:
      "Aksesor per telefon, dekor dhe produkte praktike per perditshmeri ne nje katalog te vetem.",
    badge: "Reklame 03",
    ctaLabel: "Hap kategorite",
    ctaHref: "/kerko?category=technology",
    imagePath: "/gruri.webp",
  },
];

export function calculateCartItemsCount(items = []) {
  if (!Array.isArray(items)) {
    return 0;
  }

  return items.reduce((total, item) => {
    const quantity = Number(item?.quantity);
    if (Number.isFinite(quantity) && quantity > 0) {
      return total + Math.trunc(quantity);
    }

    return total + 1;
  }, 0);
}

export function persistLoginGreeting(value) {
  try {
    const nextValue = String(value || "").trim() || "User";
    window.sessionStorage.setItem(LOGIN_GREETING_KEY, nextValue);
  } catch (error) {
    console.error(error);
  }
}

export function consumeLoginGreeting() {
  try {
    const value = String(window.sessionStorage.getItem(LOGIN_GREETING_KEY) || "").trim();
    if (!value) {
      return "";
    }

    window.sessionStorage.removeItem(LOGIN_GREETING_KEY);
    return value;
  } catch (error) {
    console.error(error);
    return "";
  }
}

export function persistCheckoutSelectedCartIds(ids) {
  try {
    window.sessionStorage.setItem(
      CHECKOUT_SELECTED_CART_IDS_KEY,
      JSON.stringify(
        Array.isArray(ids)
          ? ids
              .map((id) => Number(id))
              .filter((id) => Number.isFinite(id) && id > 0)
          : [],
      ),
    );
  } catch (error) {
    console.error(error);
  }
}

export function readCheckoutSelectedCartIds() {
  try {
    const rawValue = window.sessionStorage.getItem(CHECKOUT_SELECTED_CART_IDS_KEY);
    if (!rawValue) {
      return [];
    }

    const parsedValue = JSON.parse(rawValue);
    if (!Array.isArray(parsedValue)) {
      return [];
    }

    return parsedValue
      .map((id) => Number(id))
      .filter((id) => Number.isFinite(id) && id > 0);
  } catch (error) {
    console.error(error);
    return [];
  }
}

export function persistCheckoutAddressDraft(address) {
  try {
    window.sessionStorage.setItem(
      CHECKOUT_ADDRESS_DRAFT_KEY,
      JSON.stringify(normalizeAddress(address)),
    );
  } catch (error) {
    console.error(error);
  }
}

export function readCheckoutAddressDraft() {
  try {
    const rawValue = window.sessionStorage.getItem(CHECKOUT_ADDRESS_DRAFT_KEY);
    if (!rawValue) {
      return null;
    }

    return normalizeAddress(JSON.parse(rawValue));
  } catch (error) {
    console.error(error);
    return null;
  }
}

export function persistCheckoutPaymentMethod(method) {
  try {
    window.sessionStorage.setItem(
      CHECKOUT_PAYMENT_METHOD_KEY,
      String(method || "").trim(),
    );
  } catch (error) {
    console.error(error);
  }
}

export function readCheckoutPaymentMethod() {
  try {
    return String(window.sessionStorage.getItem(CHECKOUT_PAYMENT_METHOD_KEY) || "").trim();
  } catch (error) {
    console.error(error);
    return "";
  }
}

export function persistOrderConfirmationMessage(message) {
  try {
    const nextValue = String(message || "").trim();
    if (!nextValue) {
      return;
    }

    window.sessionStorage.setItem(ORDER_CONFIRMATION_MESSAGE_KEY, nextValue);
  } catch (error) {
    console.error(error);
  }
}

export function consumeOrderConfirmationMessage() {
  try {
    const value = String(window.sessionStorage.getItem(ORDER_CONFIRMATION_MESSAGE_KEY) || "").trim();
    if (!value) {
      return "";
    }

    window.sessionStorage.removeItem(ORDER_CONFIRMATION_MESSAGE_KEY);
    return value;
  } catch (error) {
    console.error(error);
    return "";
  }
}

export function clearCheckoutFlowState() {
  try {
    window.sessionStorage.removeItem(CHECKOUT_ADDRESS_DRAFT_KEY);
    window.sessionStorage.removeItem(CHECKOUT_PAYMENT_METHOD_KEY);
    window.sessionStorage.removeItem(CHECKOUT_SELECTED_CART_IDS_KEY);
  } catch (error) {
    console.error(error);
  }
}

export function formatPrice(value) {
  const number = Number(value);
  if (Number.isNaN(number)) {
    return "€0";
  }

  return `€${number.toFixed(2).replace(/\.?0+$/, "")}`;
}

export function formatCategoryLabel(category) {
  const labels = {
    "clothing-babies": "Veshje per beba",
    "cosmetics-kids": "Kozmetike per femije",
    pets: "Kafshet shtepiake",
    agriculture: "Bujqesi",
    medicine: "Barnat",
  };

  return labels[category] || PRODUCT_SECTION_OPTIONS.find((option) => option.value === category)?.label || humanizeSlug(category);
}

export function formatCategoryGroupLabel(group) {
  const labels = {
    clothing: "Veshje",
    cosmetics: "Kozmetika",
  };

  return labels[String(group || "").trim().toLowerCase()] || humanizeSlug(group);
}

export function formatProductTypeLabel(productType) {
  const labels = {
    clothing: "Veshje",
    cream: "Kremera",
    food: "Ushqim",
    tools: "Vegla",
    other: "Tjera",
  };

  return labels[productType] || PRODUCT_TYPE_LABELS[productType] || humanizeSlug(productType);
}

export function formatProductColorLabel(color) {
  return PRODUCT_COLOR_LABELS[color] || color;
}

export function formatStockQuantity(value) {
  const number = Number(value);
  if (!Number.isFinite(number)) {
    return "0 cope";
  }

  return `${Math.max(0, Math.trunc(number))} cope`;
}

export function formatDateLabel(value) {
  if (!value) {
    return "-";
  }

  const parsedDate = new Date(String(value).replace(" ", "T"));
  if (Number.isNaN(parsedDate.getTime())) {
    return String(value);
  }

  return parsedDate.toLocaleDateString("sq-AL", {
    year: "numeric",
    month: "long",
    day: "numeric",
  });
}

export function getProductDetailUrl(productId, backPath = "") {
  const cleanBackPath = String(backPath || "").trim();
  const baseUrl = `/produkti?id=${encodeURIComponent(productId)}`;
  if (!cleanBackPath) {
    return baseUrl;
  }

  return `${baseUrl}&back=${encodeURIComponent(cleanBackPath)}`;
}

export function getBusinessProfileUrl(businessId) {
  return `/profili-biznesit?id=${encodeURIComponent(businessId)}`;
}

export function getVerifyEmailUrl(email = "") {
  const cleanEmail = String(email || "").trim();
  if (!cleanEmail) {
    return "/verifiko-email";
  }

  return `/verifiko-email?email=${encodeURIComponent(cleanEmail)}`;
}

export function getCategoryUrl(category) {
  const urls = {
    "clothing-men": "/kerko?category=clothing-men",
    "clothing-women": "/kerko?category=clothing-women",
    "clothing-kids": "/kerko?category=clothing-kids",
    "clothing-babies": "/kerko?category=clothing-babies",
    "cosmetics-men": "/kerko?category=cosmetics-men",
    "cosmetics-women": "/kerko?category=cosmetics-women",
    "cosmetics-kids": "/kerko?category=cosmetics-kids",
    pets: "/kerko?category=pets",
    agriculture: "/kerko?category=agriculture",
    medicine: "/kerko?category=medicine",
    home: "/kerko?category=home",
    sport: "/kerko?category=sport",
    technology: "/kerko?category=technology",
  };

  return urls[category] || "/";
}

export function getProductImageGallery(product) {
  const gallery = [];
  const rawGallery = Array.isArray(product?.imageGallery) ? product.imageGallery : [];

  rawGallery.forEach((path) => {
    const normalizedPath = String(path || "").trim();
    if (normalizedPath && !gallery.includes(normalizedPath)) {
      gallery.push(normalizedPath);
    }
  });

  const coverImage = String(product?.imagePath || "").trim();
  if (coverImage && !gallery.includes(coverImage)) {
    gallery.unshift(coverImage);
  }

  return gallery;
}

export function getSafeGalleryIndex(index, totalImages) {
  const total = Number(totalImages);
  if (!Number.isFinite(total) || total <= 0) {
    return 0;
  }

  const current = Number(index);
  if (!Number.isFinite(current) || current < 0) {
    return 0;
  }

  return Math.min(total - 1, Math.trunc(current));
}

export function getBusinessInitials(value) {
  const parts = String(value || "")
    .trim()
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2);

  if (parts.length === 0) {
    return "TR";
  }

  return parts
    .map((part) => part.charAt(0).toUpperCase())
    .join("");
}

export function formatRoleLabel(role) {
  const labels = {
    admin: "Admin",
    business: "Biznes",
    client: "User",
  };

  return labels[String(role || "").trim()] || "User";
}

export function formatPaymentMethodLabel(paymentMethod) {
  const labels = {
    cash: "Pages cash",
    "card-online": "Pages me kartel online",
  };

  return labels[String(paymentMethod || "").trim()] || "Pagesa";
}

export function formatOrderStatusLabel(status) {
  const labels = {
    confirmed: "Porosia u konfirmua",
    pending: "Ne pritje",
  };

  return labels[String(status || "").trim()] || "Porosia";
}

export function humanizeSlug(value) {
  return String(value || "")
    .replace(/-/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .replace(/\b\w/g, (character) => character.toUpperCase());
}

export function normalizeAddress(address) {
  return {
    addressLine: String(address?.addressLine || ""),
    city: String(address?.city || ""),
    country: String(address?.country || ""),
    zipCode: String(address?.zipCode || ""),
    phoneNumber: String(address?.phoneNumber || ""),
  };
}

export function createEmptyAddress() {
  return {
    addressLine: "",
    city: "",
    country: "",
    zipCode: "",
    phoneNumber: "",
  };
}

export function isClothingSection(sectionValue) {
  return isCatalogClothingSection(sectionValue);
}

export function getProfileValuesFromUser(user) {
  const firstName = String(user?.firstName || "").trim();
  const lastName = String(user?.lastName || "").trim();
  const profileImagePath = String(user?.profileImagePath || "").trim();

  if (firstName || lastName) {
    return {
      firstName,
      lastName,
      birthDate: String(user?.birthDate || ""),
      gender: String(user?.gender || ""),
      profileImagePath,
    };
  }

  const nameParts = String(user?.fullName || "")
    .trim()
    .split(/\s+/)
    .filter(Boolean);

  return {
    firstName: nameParts[0] || "",
    lastName: nameParts.slice(1).join(" "),
    birthDate: String(user?.birthDate || ""),
    gender: String(user?.gender || ""),
    profileImagePath,
  };
}
