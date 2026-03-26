export const LOGIN_GREETING_KEY = "trego_login_greeting";
export const CHECKOUT_ADDRESS_DRAFT_KEY = "trego_checkout_address_draft";
export const CHECKOUT_PAYMENT_METHOD_KEY = "trego_checkout_payment_method";
export const CHECKOUT_SELECTED_CART_IDS_KEY = "trego_checkout_selected_cart_ids";
export const ORDER_CONFIRMATION_MESSAGE_KEY = "trego_order_confirmation_message";
export const APP_LOADER_MIN_DURATION_MS = 700;

export const PRIMARY_NAVIGATION = [
  {
    key: "clothing",
    label: "Veshje",
    items: [
      { label: "Meshkuj", href: "/kerko?category=clothing-men" },
      { label: "Femra", href: "/kerko?category=clothing-women" },
      { label: "Femije", href: "/kerko?category=clothing-kids" },
    ],
  },
  {
    key: "cosmetics",
    label: "Kozmetik",
    items: [
      { label: "Meshkuj", href: "/kerko?category=cosmetics-men" },
      { label: "Femra", href: "/kerko?category=cosmetics-women" },
      { label: "Femije", href: "/kerko?category=cosmetics-kids" },
    ],
  },
  { key: "home", label: "Shtepi", href: "/kerko?category=home" },
  { key: "sport", label: "Sport", href: "/kerko?category=sport" },
  { key: "technology", label: "Teknologji", href: "/kerko?category=technology" },
];

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

export const PRODUCT_SECTION_OPTIONS = [
  { value: "clothing-men", label: "Veshje per meshkuj" },
  { value: "clothing-women", label: "Veshje per femra" },
  { value: "clothing-kids", label: "Veshje per femije" },
  { value: "cosmetics-men", label: "Kozmetik per meshkuj" },
  { value: "cosmetics-women", label: "Kozmetik per femra" },
  { value: "cosmetics-kids", label: "Kozmetik per femije" },
  { value: "home", label: "Shtepi" },
  { value: "sport", label: "Sport" },
  { value: "technology", label: "Teknologji" },
];

export const SECTION_PRODUCT_TYPE_OPTIONS = {
  "clothing-men": [
    { value: "tshirt", label: "Maica" },
    { value: "undershirt", label: "Maica e brendshme" },
    { value: "pants", label: "Pantallona" },
    { value: "hoodie", label: "Duks" },
    { value: "turtleneck", label: "Rollke" },
    { value: "jacket", label: "Jakne" },
    { value: "underwear", label: "Te brendshme" },
    { value: "pajamas", label: "Pixhama" },
  ],
  "clothing-women": [
    { value: "tshirt", label: "Maica" },
    { value: "undershirt", label: "Maica e brendshme" },
    { value: "pants", label: "Pantallona" },
    { value: "hoodie", label: "Duks" },
    { value: "turtleneck", label: "Rollke" },
    { value: "jacket", label: "Jakne" },
    { value: "underwear", label: "Te brendshme" },
    { value: "pajamas", label: "Pixhama" },
  ],
  "clothing-kids": [
    { value: "tshirt", label: "Maica" },
    { value: "undershirt", label: "Maica e brendshme" },
    { value: "pants", label: "Pantallona" },
    { value: "hoodie", label: "Duks" },
    { value: "turtleneck", label: "Rollke" },
    { value: "jacket", label: "Jakne" },
    { value: "underwear", label: "Te brendshme" },
    { value: "pajamas", label: "Pixhama" },
  ],
  "cosmetics-men": [
    { value: "perfumes", label: "Parfume" },
    { value: "hygiene", label: "Higjiena" },
    { value: "creams", label: "Kremerat" },
  ],
  "cosmetics-women": [
    { value: "perfumes", label: "Parfume" },
    { value: "hygiene", label: "Higjiena" },
    { value: "creams", label: "Kremerat" },
    { value: "makeup", label: "Makup" },
    { value: "nails", label: "Thonjet" },
    { value: "hair-colors", label: "Ngjyrat e flokeve" },
  ],
  "cosmetics-kids": [
    { value: "hygiene", label: "Higjiena" },
    { value: "creams", label: "Kremerat" },
    { value: "kids-care", label: "Kujdes per femije" },
  ],
  home: [
    { value: "room-decor", label: "Dekorim per dhome" },
    { value: "bathroom-items", label: "Pjeset per banjo" },
    { value: "bedroom-items", label: "Pjeset per dhome te gjumit" },
    { value: "kids-room-items", label: "Pjese per dhomat e femijeve" },
  ],
  sport: [
    { value: "sports-equipment", label: "Pajisje sportive" },
    { value: "sportswear", label: "Veshje sportive" },
    { value: "sports-accessories", label: "Aksesor sportiv" },
  ],
  technology: [
    { value: "phone-cases", label: "Mbrojtese per telefon" },
    { value: "headphones", label: "Ndegjuesit" },
    { value: "phone-parts", label: "Pjese per telefon" },
    { value: "phone-accessories", label: "Aksesor te telefonave" },
  ],
};

export const PRODUCT_COLOR_OPTIONS = [
  { value: "", label: "Pa ngjyre specifike" },
  { value: "bardhe", label: "Bardhe" },
  { value: "zeze", label: "Zeze" },
  { value: "gri", label: "Gri" },
  { value: "beige", label: "Beige" },
  { value: "kafe", label: "Kafe" },
  { value: "kuqe", label: "Kuqe" },
  { value: "roze", label: "Roze" },
  { value: "vjollce", label: "Vjollce" },
  { value: "blu", label: "Blu" },
  { value: "gjelber", label: "Gjelber" },
  { value: "verdhe", label: "Verdhe" },
  { value: "portokalli", label: "Portokalli" },
  { value: "shume-ngjyra", label: "Shume ngjyra" },
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
    "clothing-men": "Veshje per meshkuj",
    "clothing-women": "Veshje per femra",
    "clothing-kids": "Veshje per femije",
    "cosmetics-men": "Kozmetik per meshkuj",
    "cosmetics-women": "Kozmetik per femra",
    "cosmetics-kids": "Kozmetik per femije",
    pets: "Kafshet shtepiake",
    agriculture: "Bujqesi",
    medicine: "Barnat",
    home: "Shtepi",
    sport: "Sport",
    technology: "Teknologji",
  };

  return labels[category] || humanizeSlug(category);
}

export function formatProductTypeLabel(productType) {
  const labels = {
    clothing: "Veshje",
    cream: "Kremera",
    food: "Ushqim",
    tools: "Vegla",
    other: "Tjera",
    tshirt: "Maica",
    undershirt: "Maica e brendshme",
    pants: "Pantallona",
    hoodie: "Duks",
    turtleneck: "Rollke",
    jacket: "Jakne",
    underwear: "Te brendshme",
    pajamas: "Pixhama",
    perfumes: "Parfume",
    hygiene: "Higjiena",
    creams: "Kremerat",
    makeup: "Makup",
    nails: "Thonjet",
    "hair-colors": "Ngjyrat e flokeve",
    "kids-care": "Kujdes per femije",
    "room-decor": "Dekorim per dhome",
    "bathroom-items": "Pjeset per banjo",
    "bedroom-items": "Pjeset per dhome te gjumit",
    "kids-room-items": "Pjese per dhomat e femijeve",
    "sports-equipment": "Pajisje sportive",
    sportswear: "Veshje sportive",
    "sports-accessories": "Aksesor sportiv",
    "phone-cases": "Mbrojtese per telefon",
    headphones: "Ndegjuesit",
    "phone-parts": "Pjese per telefon",
    "phone-accessories": "Aksesor te telefonave",
  };

  return labels[productType] || humanizeSlug(productType);
}

export function formatProductColorLabel(color) {
  const labels = {
    bardhe: "Bardhe",
    zeze: "Zeze",
    gri: "Gri",
    beige: "Beige",
    kafe: "Kafe",
    kuqe: "Kuqe",
    roze: "Roze",
    vjollce: "Vjollce",
    blu: "Blu",
    gjelber: "Gjelber",
    verdhe: "Verdhe",
    portokalli: "Portokalli",
    "shume-ngjyra": "Shume ngjyra",
  };

  return labels[color] || color;
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

export function getProductDetailUrl(productId) {
  return `/produkti?id=${encodeURIComponent(productId)}`;
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
  return String(sectionValue || "").startsWith("clothing-");
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
