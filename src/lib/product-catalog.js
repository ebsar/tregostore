import productCatalog from "../data/product-catalog.json";

export const PRODUCT_PAGE_SECTION_OPTIONS = productCatalog.sections.map((section) => ({
  value: section.value,
  label: section.label,
}));

export const PRODUCT_SECTION_OPTIONS = productCatalog.sections.flatMap((section) =>
  Array.isArray(section.audiences) && section.audiences.length > 0
    ? section.audiences.map((audience) => ({
        value: audience.category,
        label: audience.label,
      }))
    : [{ value: section.value, label: section.label }],
);

export const PRODUCT_AUDIENCE_OPTIONS = Object.fromEntries(
  productCatalog.sections.map((section) => [
    section.value,
    Array.isArray(section.audiences)
      ? section.audiences.map((audience) => ({
          value: audience.value,
          label: audience.label,
          category: audience.category,
        }))
      : [],
  ]),
);

export const PRODUCT_TYPE_OPTIONS_BY_CATEGORY = Object.fromEntries(
  Object.entries(productCatalog.productTypes || {}).map(([category, items]) => [
    category,
    Array.isArray(items)
      ? items.map((item) => ({ value: item.value, label: item.label }))
      : [],
  ]),
);

export const SECTION_PRODUCT_TYPE_OPTIONS = PRODUCT_TYPE_OPTIONS_BY_CATEGORY;
export const PRODUCT_COLOR_OPTIONS = [
  { value: "", label: "Pa ngjyre specifike" },
  ...(productCatalog.colorOptions || []),
];
export const PRODUCT_REQUIRED_COLOR_OPTIONS = productCatalog.colorOptions || [];
export const CLOTHING_SIZE_OPTIONS = (productCatalog.clothingSizes || []).map((size) => ({
  value: size,
  label: size,
}));
export const PRODUCT_AMOUNT_UNIT_OPTIONS = productCatalog.amountUnits || [];

export const PRODUCT_CATEGORY_LABELS = Object.fromEntries(
  PRODUCT_SECTION_OPTIONS.map((option) => [option.value, option.label]),
);

export const PRODUCT_TYPE_LABELS = Object.fromEntries(
  Object.values(PRODUCT_TYPE_OPTIONS_BY_CATEGORY)
    .flat()
    .map((option) => [option.value, option.label]),
);

export const PRODUCT_COLOR_LABELS = Object.fromEntries(
  (productCatalog.colorOptions || []).map((option) => [option.value, option.label]),
);

export function deriveSectionFromCategory(category) {
  const normalizedCategory = String(category || "").trim().toLowerCase();
  if (normalizedCategory === "cosmetics-kids") {
    return "cosmetics";
  }
  const matchingSection = productCatalog.sections.find((section) => {
    if (section.value === normalizedCategory) {
      return true;
    }

    return Array.isArray(section.audiences)
      && section.audiences.some((audience) => audience.category === normalizedCategory);
  });

  return matchingSection?.value || "clothing";
}

export function deriveAudienceFromCategory(category) {
  const normalizedCategory = String(category || "").trim().toLowerCase();
  if (normalizedCategory === "cosmetics-kids") {
    return "women";
  }
  for (const section of productCatalog.sections) {
    const matchingAudience = Array.isArray(section.audiences)
      ? section.audiences.find((audience) => audience.category === normalizedCategory)
      : null;
    if (matchingAudience) {
      return matchingAudience.value;
    }
  }

  return "";
}

export function buildCategoryFromSelection(section, audience) {
  const normalizedSection = String(section || "").trim().toLowerCase();
  const normalizedAudience = String(audience || "").trim().toLowerCase();
  const sectionConfig = productCatalog.sections.find((entry) => entry.value === normalizedSection);
  if (!sectionConfig) {
    return PRODUCT_SECTION_OPTIONS[0]?.value || "clothing-men";
  }

  if (!Array.isArray(sectionConfig.audiences) || sectionConfig.audiences.length === 0) {
    return sectionConfig.value;
  }

  const audienceConfig = sectionConfig.audiences.find((entry) => entry.value === normalizedAudience);
  return audienceConfig?.category || sectionConfig.audiences[0]?.category || PRODUCT_SECTION_OPTIONS[0]?.value || "clothing-men";
}

export function getAudienceOptionsForSection(section) {
  return PRODUCT_AUDIENCE_OPTIONS[String(section || "").trim().toLowerCase()] || [];
}

export function getProductTypeOptions(section, audience) {
  const category = buildCategoryFromSelection(section, audience);
  return PRODUCT_TYPE_OPTIONS_BY_CATEGORY[category] || [];
}

export function isClothingSection(sectionValue) {
  return String(sectionValue || "").trim().toLowerCase() === "clothing"
    || String(sectionValue || "").trim().toLowerCase().startsWith("clothing-");
}

export function isCosmeticsSection(sectionValue) {
  return String(sectionValue || "").trim().toLowerCase() === "cosmetics"
    || String(sectionValue || "").trim().toLowerCase().startsWith("cosmetics-");
}

export function supportsColorInventory(sectionValue) {
  const normalizedSection = String(sectionValue || "").trim().toLowerCase();
  return ["clothing", "home", "sport", "technology"].includes(normalizedSection)
    || normalizedSection.startsWith("clothing-");
}

export function supportsPackageAmount(sectionValue) {
  const normalizedSection = String(sectionValue || "").trim().toLowerCase();
  return normalizedSection === "cosmetics" || normalizedSection.startsWith("cosmetics-");
}

export function createDefaultClothingSizeEntries() {
  return CLOTHING_SIZE_OPTIONS.map((option) => ({
    size: option.value,
    enabled: false,
    quantity: "0",
  }));
}

export function createEmptyProductFormState() {
  const defaultSection = PRODUCT_PAGE_SECTION_OPTIONS[0]?.value || "clothing";
  const defaultAudience = getAudienceOptionsForSection(defaultSection)[0]?.value || "";
  const defaultCategory = buildCategoryFromSelection(defaultSection, defaultAudience);
  return {
    articleNumber: "",
    title: "",
    price: "",
    compareAtPrice: "",
    saleEndsAt: "",
    description: "",
    pageSection: defaultSection,
    audience: defaultAudience,
    category: defaultCategory,
    productType: getProductTypeOptions(defaultSection, defaultAudience)[0]?.value || "",
    packageAmountValue: "",
    packageAmountUnit: "ml",
    simpleStockQuantity: "1",
    selectedColors: [],
    clothingColorVariants: [],
    colorStockVariants: [],
    imageGallery: [],
  };
}

export function syncProductFormCatalogState(form) {
  const section = String(form.pageSection || "").trim().toLowerCase() || "clothing";
  form.pageSection = section;
  const audienceOptions = getAudienceOptionsForSection(section);
  if (audienceOptions.length > 0) {
    if (!audienceOptions.some((option) => option.value === form.audience)) {
      form.audience = audienceOptions[0]?.value || "";
    }
  } else {
    form.audience = "";
  }

  form.category = buildCategoryFromSelection(section, form.audience);

  const typeOptions = getProductTypeOptions(section, form.audience);
  if (!typeOptions.some((option) => option.value === form.productType)) {
    form.productType = typeOptions[0]?.value || "";
  }

  if (!supportsPackageAmount(section)) {
    form.packageAmountValue = "";
    form.packageAmountUnit = "ml";
  } else if (!PRODUCT_AMOUNT_UNIT_OPTIONS.some((option) => option.value === form.packageAmountUnit)) {
    form.packageAmountUnit = PRODUCT_AMOUNT_UNIT_OPTIONS[0]?.value || "ml";
  }

  if (!Array.isArray(form.selectedColors)) {
    form.selectedColors = [];
  }
  if (!Array.isArray(form.clothingColorVariants)) {
    form.clothingColorVariants = [];
  }
  if (!Array.isArray(form.colorStockVariants)) {
    form.colorStockVariants = [];
  }
}

export function formatVariantLabel(variant = {}) {
  const parts = [];
  if (variant.color) {
    parts.push(PRODUCT_COLOR_LABELS[variant.color] || variant.color);
  }
  if (variant.size) {
    parts.push(String(variant.size).trim().toUpperCase());
  }

  return parts.join(" / ") || "Standard";
}

export function buildVariantKey({ color = "", size = "" } = {}) {
  const parts = [];
  const normalizedColor = String(color || "").trim().toLowerCase();
  const normalizedSize = String(size || "").trim().toUpperCase();
  if (normalizedColor) {
    parts.push(`color:${normalizedColor}`);
  }
  if (normalizedSize) {
    parts.push(`size:${normalizedSize}`);
  }
  return parts.join("|") || "default";
}

export function normalizeVariantInventory(value, fallback = {}) {
  const candidates = Array.isArray(value) ? value : [];
  const normalizedEntries = [];
  const seenKeys = new Set();

  candidates.forEach((candidate) => {
    if (!candidate || typeof candidate !== "object") {
      return;
    }

    const size = String(candidate.size || "").trim().toUpperCase();
    const color = String(candidate.color || "").trim().toLowerCase();
    const quantity = Math.max(0, Number.parseInt(String(candidate.quantity ?? "0"), 10) || 0);
    const rawPrice = Number(candidate.price ?? 0);
    const price = Number.isFinite(rawPrice) && rawPrice > 0 ? Number(rawPrice.toFixed(2)) : 0;
    const imagePath = String(candidate.imagePath || "").trim();
    const key = buildVariantKey({ size, color });
    if (seenKeys.has(key)) {
      return;
    }

    seenKeys.add(key);
    normalizedEntries.push({
      key,
      size,
      color,
      quantity,
      label: formatVariantLabel({ size, color }),
      price,
      imagePath,
    });
  });

  if (normalizedEntries.length > 0) {
    return normalizedEntries;
  }

  const fallbackQuantity = Math.max(0, Number.parseInt(String(fallback.stockQuantity ?? "0"), 10) || 0);
  if (fallbackQuantity <= 0) {
    return [];
  }

  const fallbackSize = String(fallback.size || "").trim().toUpperCase();
  const fallbackColor = String(fallback.color || "").trim().toLowerCase();
  return [{
    key: buildVariantKey({ size: fallbackSize, color: fallbackColor }),
    size: fallbackSize,
    color: fallbackColor,
    quantity: fallbackQuantity,
    label: formatVariantLabel({ size: fallbackSize, color: fallbackColor }),
    price: 0,
    imagePath: "",
  }];
}

export function hydrateProductFormFromProduct(form, product) {
  Object.assign(form, createEmptyProductFormState());
  form.articleNumber = String(product?.articleNumber || "");
  form.title = String(product?.title || "");
  form.price = String(product?.price ?? "");
  form.compareAtPrice = Number(product?.compareAtPrice || 0) > Number(product?.price || 0)
    ? String(product?.compareAtPrice ?? "")
    : "";
  form.saleEndsAt = String(product?.saleEndsAt || "");
  form.description = String(product?.description || "");
  form.pageSection = deriveSectionFromCategory(product?.category);
  form.audience = deriveAudienceFromCategory(product?.category);
  form.category = buildCategoryFromSelection(form.pageSection, form.audience);
  form.productType = String(product?.productType || "");
  form.packageAmountValue = String(product?.packageAmountValue ?? "");
  form.packageAmountUnit = String(product?.packageAmountUnit || "ml");
  form.simpleStockQuantity = String(product?.stockQuantity ?? 0);
  form.imageGallery = Array.isArray(product?.imageGallery) ? [...product.imageGallery] : [];
  syncProductFormCatalogState(form);

  const inventory = normalizeVariantInventory(product?.variantInventory, {
    size: product?.size,
    color: product?.color,
    stockQuantity: product?.stockQuantity,
  });
  const uniqueColors = [...new Set(inventory.map((entry) => entry.color).filter(Boolean))];
  form.selectedColors = uniqueColors;

  if (isClothingSection(form.pageSection)) {
    form.clothingColorVariants = uniqueColors.map((color) => ({
      color,
      sizeEntries: CLOTHING_SIZE_OPTIONS.map((option) => {
        const existingEntry = inventory.find(
          (entry) => entry.color === color && entry.size === option.value,
        );
        return {
          size: option.value,
          enabled: Boolean(existingEntry),
          quantity: String(existingEntry?.quantity ?? 0),
          price: String(existingEntry?.price ?? ""),
          imagePath: String(existingEntry?.imagePath || ""),
        };
      }),
    }));
    return;
  }

  if (supportsColorInventory(form.pageSection)) {
    form.colorStockVariants = uniqueColors.map((color) => {
      const existingEntry = inventory.find((entry) => entry.color === color);
      return {
        color,
        quantity: String(existingEntry?.quantity ?? 0),
        price: String(existingEntry?.price ?? ""),
        imagePath: String(existingEntry?.imagePath || ""),
      };
    });
    return;
  }

  if (inventory.length > 0) {
    form.simpleStockQuantity = String(
      inventory.reduce((total, entry) => total + Math.max(0, Number(entry.quantity) || 0), 0),
    );
  }
}

export function buildVariantInventoryFromForm(form) {
  const section = String(form.pageSection || "").trim().toLowerCase();

  if (isClothingSection(section)) {
    return (Array.isArray(form.clothingColorVariants) ? form.clothingColorVariants : []).flatMap((colorVariant) =>
      (Array.isArray(colorVariant.sizeEntries) ? colorVariant.sizeEntries : [])
        .filter((entry) => entry.enabled)
        .map((entry) => ({
          key: buildVariantKey({ color: colorVariant.color, size: entry.size }),
          color: String(colorVariant.color || "").trim().toLowerCase(),
          size: String(entry.size || "").trim().toUpperCase(),
          quantity: Math.max(0, Number.parseInt(String(entry.quantity ?? "0"), 10) || 0),
          label: formatVariantLabel({ color: colorVariant.color, size: entry.size }),
          price: Math.max(0, Number.parseFloat(String(entry.price ?? "0")) || 0),
          imagePath: String(entry.imagePath || "").trim(),
        })),
    );
  }

  if (supportsColorInventory(section)) {
    return (Array.isArray(form.colorStockVariants) ? form.colorStockVariants : []).map((entry) => ({
      key: buildVariantKey({ color: entry.color }),
      color: String(entry.color || "").trim().toLowerCase(),
      size: "",
      quantity: Math.max(0, Number.parseInt(String(entry.quantity ?? "0"), 10) || 0),
      label: formatVariantLabel({ color: entry.color }),
      price: Math.max(0, Number.parseFloat(String(entry.price ?? "0")) || 0),
      imagePath: String(entry.imagePath || "").trim(),
    }));
  }

  const quantity = Math.max(0, Number.parseInt(String(form.simpleStockQuantity ?? "0"), 10) || 0);
  return quantity > 0
    ? [{
        key: "default",
        color: "",
        size: "",
        quantity,
        label: "Standard",
        price: 0,
        imagePath: "",
      }]
    : [];
}
