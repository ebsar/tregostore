import productCatalog from "../../../src/data/product-catalog.json";

export const PRODUCT_PAGE_SECTION_OPTIONS = (productCatalog.sections || []).map((section: any) => ({
  value: section.value,
  label: section.label,
}));

export const PRODUCT_AUDIENCE_OPTIONS = Object.fromEntries(
  (productCatalog.sections || []).map((section: any) => [
    section.value,
    Array.isArray(section.audiences)
      ? section.audiences.map((audience: any) => ({
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
      ? items.map((item: any) => ({ value: item.value, label: item.label }))
      : [],
  ]),
);

export const PRODUCT_REQUIRED_COLOR_OPTIONS = productCatalog.colorOptions || [];
export const PRODUCT_COLOR_LABELS = Object.fromEntries(
  (productCatalog.colorOptions || []).map((option: any) => [option.value, option.label]),
);
export const CLOTHING_SIZE_OPTIONS = (productCatalog.clothingSizes || []).map((size: string) => ({
  value: size,
  label: size,
}));
export const PRODUCT_AMOUNT_UNIT_OPTIONS = productCatalog.amountUnits || [];

export function buildCategoryFromSelection(section: string, audience: string) {
  const normalizedSection = String(section || "").trim().toLowerCase();
  const normalizedAudience = String(audience || "").trim().toLowerCase();
  const sectionConfig = (productCatalog.sections || []).find((entry: any) => entry.value === normalizedSection);
  if (!sectionConfig) {
    return "clothing-men";
  }

  if (!Array.isArray(sectionConfig.audiences) || sectionConfig.audiences.length === 0) {
    return sectionConfig.value;
  }

  const audienceConfig = sectionConfig.audiences.find((entry: any) => entry.value === normalizedAudience);
  return audienceConfig?.category || sectionConfig.audiences[0]?.category || "clothing-men";
}

export function deriveSectionFromCategory(category: string) {
  const normalizedCategory = String(category || "").trim().toLowerCase();
  if (normalizedCategory === "cosmetics-kids") {
    return "cosmetics";
  }

  const matchingSection = (productCatalog.sections || []).find((section: any) =>
    section.value === normalizedCategory
    || (Array.isArray(section.audiences)
      && section.audiences.some((audience: any) => audience.category === normalizedCategory)),
  );

  return matchingSection?.value || "clothing";
}

export function deriveAudienceFromCategory(category: string) {
  const normalizedCategory = String(category || "").trim().toLowerCase();
  if (normalizedCategory === "cosmetics-kids") {
    return "women";
  }

  for (const section of productCatalog.sections || []) {
    const matchingAudience = Array.isArray(section.audiences)
      ? section.audiences.find((audience: any) => audience.category === normalizedCategory)
      : null;
    if (matchingAudience) {
      return matchingAudience.value;
    }
  }

  return "";
}

export function getAudienceOptionsForSection(section: string) {
  return PRODUCT_AUDIENCE_OPTIONS[String(section || "").trim().toLowerCase()] || [];
}

export function getProductTypeOptions(section: string, audience: string) {
  return PRODUCT_TYPE_OPTIONS_BY_CATEGORY[buildCategoryFromSelection(section, audience)] || [];
}

export function isClothingSection(sectionValue: string) {
  const normalizedSection = String(sectionValue || "").trim().toLowerCase();
  return normalizedSection === "clothing" || normalizedSection.startsWith("clothing-");
}

export function supportsColorInventory(sectionValue: string) {
  const normalizedSection = String(sectionValue || "").trim().toLowerCase();
  return ["clothing", "home", "sport", "technology"].includes(normalizedSection) || normalizedSection.startsWith("clothing-");
}

export function supportsPackageAmount(sectionValue: string) {
  const normalizedSection = String(sectionValue || "").trim().toLowerCase();
  return normalizedSection === "cosmetics" || normalizedSection.startsWith("cosmetics-");
}

export function createEmptyProductFormState() {
  const defaultSection = PRODUCT_PAGE_SECTION_OPTIONS[0]?.value || "clothing";
  const defaultAudience = getAudienceOptionsForSection(defaultSection)[0]?.value || "";
  return {
    articleNumber: "",
    title: "",
    price: "",
    compareAtPrice: "",
    saleEndsAt: "",
    description: "",
    pageSection: defaultSection,
    audience: defaultAudience,
    category: buildCategoryFromSelection(defaultSection, defaultAudience),
    productType: getProductTypeOptions(defaultSection, defaultAudience)[0]?.value || "",
    packageAmountValue: "",
    packageAmountUnit: "ml",
    simpleStockQuantity: "1",
    selectedColors: [] as string[],
    clothingColorVariants: [] as Array<{ color: string; sizeEntries: Array<{ size: string; enabled: boolean; quantity: string }> }>,
    colorStockVariants: [] as Array<{ color: string; quantity: string }>,
    imageGallery: [] as string[],
  };
}

export function syncProductFormCatalogState(form: any) {
  const section = String(form.pageSection || "").trim().toLowerCase() || "clothing";
  form.pageSection = section;

  const audienceOptions = getAudienceOptionsForSection(section);
  if (audienceOptions.length > 0) {
    if (!audienceOptions.some((option: any) => option.value === form.audience)) {
      form.audience = audienceOptions[0]?.value || "";
    }
  } else {
    form.audience = "";
  }

  form.category = buildCategoryFromSelection(section, form.audience);

  const typeOptions = getProductTypeOptions(section, form.audience);
  if (!typeOptions.some((option: any) => option.value === form.productType)) {
    form.productType = typeOptions[0]?.value || "";
  }

  if (!supportsPackageAmount(section)) {
    form.packageAmountValue = "";
    form.packageAmountUnit = "ml";
  } else if (!PRODUCT_AMOUNT_UNIT_OPTIONS.some((option: any) => option.value === form.packageAmountUnit)) {
    form.packageAmountUnit = PRODUCT_AMOUNT_UNIT_OPTIONS[0]?.value || "ml";
  }
}

export function formatVariantLabel(variant: Record<string, unknown> = {}) {
  const parts: string[] = [];
  if (variant.color) {
    parts.push(PRODUCT_COLOR_LABELS[String(variant.color)] || String(variant.color));
  }
  if (variant.size) {
    parts.push(String(variant.size).trim().toUpperCase());
  }
  return parts.join(" / ") || "Standard";
}

export function buildVariantKey({ color = "", size = "" }: { color?: string; size?: string } = {}) {
  const parts: string[] = [];
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

export function buildVariantInventoryFromForm(form: any) {
  const section = String(form.pageSection || "").trim().toLowerCase();

  if (isClothingSection(section)) {
    return (Array.isArray(form.clothingColorVariants) ? form.clothingColorVariants : []).flatMap((colorVariant: any) =>
      (Array.isArray(colorVariant.sizeEntries) ? colorVariant.sizeEntries : [])
        .filter((entry: any) => entry.enabled)
        .map((entry: any) => ({
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
    return (Array.isArray(form.colorStockVariants) ? form.colorStockVariants : []).map((entry: any) => ({
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
