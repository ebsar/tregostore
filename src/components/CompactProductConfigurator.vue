<script setup>
import { computed, watch } from "vue";
import {
  CLOTHING_SIZE_OPTIONS,
  PRODUCT_AMOUNT_UNIT_OPTIONS,
  PRODUCT_COLOR_LABELS,
  PRODUCT_PAGE_SECTION_OPTIONS,
  PRODUCT_REQUIRED_COLOR_OPTIONS,
  createDefaultClothingSizeEntries,
  createEmptyCustomVariantRow,
  createEmptyTechnologyVariant,
  getAudienceOptionsForSection,
  getProductTypeOptions,
  isClothingSection,
  isTechnologySection,
  supportsPackageAmount,
  syncProductFormCatalogState,
} from "../lib/product-catalog";

const props = defineProps({
  form: {
    type: Object,
    required: true,
  },
});

const sectionOptions = PRODUCT_PAGE_SECTION_OPTIONS;
const audienceOptions = computed(() => getAudienceOptionsForSection(props.form.pageSection));
const productTypeOptions = computed(() => getProductTypeOptions(props.form.pageSection, props.form.audience));
const clothingSection = computed(() => isClothingSection(props.form.pageSection));
const technologySection = computed(() => isTechnologySection(props.form.pageSection));
const customAttributesSection = computed(() => !clothingSection.value && !technologySection.value);
const packageAmountSection = computed(() => supportsPackageAmount(props.form.pageSection));
const selectedColorCount = computed(() => Array.isArray(props.form.selectedColors) ? props.form.selectedColors.length : 0);
const aiContextText = computed(() => normalizeSuggestionText([
  props.form.title,
  props.form.metaDescription,
  props.form.description,
  props.form.brand,
  props.form.material,
  props.form.productType,
].filter(Boolean).join(" ")));
const subcategorySuggestions = computed(() =>
  rankSuggestionOptions(audienceOptions.value, AUDIENCE_KEYWORDS, audienceOptions.value.length),
);
const productTypeSuggestions = computed(() =>
  rankSuggestionOptions(productTypeOptions.value, PRODUCT_TYPE_KEYWORDS, Math.min(7, productTypeOptions.value.length)),
);
const colorSuggestions = computed(() => buildColorSuggestions());
const detailSuggestionGroups = computed(() => {
  const groups = [];

  if (clothingSection.value) {
    groups.push({
      key: "color",
      label: "Colors",
      options: colorSuggestions.value,
    });
    groups.push({
      key: "sizePreset",
      label: "Sizes",
      options: getClothingSizePresetSuggestions(),
    });
  }

  if (packageAmountSection.value) {
    groups.push({
      key: "package",
      label: "Package",
      options: getPackageSuggestionOptions(),
    });
  }

  if (technologySection.value) {
    groups.push({
      key: "technologyPreset",
      label: "Tech details",
      options: getTechnologyPresetSuggestions(),
    });
  }

  if (customAttributesSection.value) {
    groups.push({
      key: "customAttribute",
      label: "Details",
      options: getCustomAttributeSuggestions(),
    });
  }

  return groups.filter((group) => Array.isArray(group.options) && group.options.length > 0);
});
const hasAiCatalogSuggestions = computed(() =>
  subcategorySuggestions.value.length > 0
  || productTypeSuggestions.value.length > 0
  || detailSuggestionGroups.value.length > 0,
);
const aiGuidanceSummary = computed(() => {
  if (subcategorySuggestions.value.length > 0) {
    return "Category selected. Pick the best subcategory, then choose product type.";
  }
  if (productTypeSuggestions.value.length > 0) {
    return "Subcategory selected. Product type recommendations are ready.";
  }
  return "Product details are ready for this category.";
});
const enabledClothingVariantCount = computed(() =>
  (Array.isArray(props.form.clothingColorVariants) ? props.form.clothingColorVariants : []).reduce(
    (total, colorVariant) =>
      total + (Array.isArray(colorVariant.sizeEntries) ? colorVariant.sizeEntries.filter((entry) => entry.enabled).length : 0),
    0,
  ),
);
const variantSummary = computed(() => {
  if (clothingSection.value) {
    if (!selectedColorCount.value) {
      return "Select colors first, then keep only the sizes you will sell.";
    }
    return `${selectedColorCount.value} colors · ${enabledClothingVariantCount.value} active size rows`;
  }

  if (technologySection.value) {
    return `${props.form.technologyVariants?.length || 0} technology variants ready`;
  }

  return `${props.form.customVariantRows?.length || 0} custom option rows ready`;
});

const COLOR_SWATCH_STYLES = {
  bardhe: "linear-gradient(135deg, #ffffff, #f1ede7)",
  zeze: "linear-gradient(135deg, #2f2a28, #0f0c0b)",
  gri: "linear-gradient(135deg, #c2c5cc, #7f8794)",
  beige: "linear-gradient(135deg, #efe3d0, #cdb79d)",
  kafe: "linear-gradient(135deg, #8a664d, #5e3f2f)",
  kuqe: "linear-gradient(135deg, #f45a63, #ba1f36)",
  roze: "linear-gradient(135deg, #ffbdd2, #ef6ca4)",
  vjollce: "linear-gradient(135deg, #b791ff, #7344c8)",
  blu: "linear-gradient(135deg, #78b7ff, #2a64d6)",
  gjelber: "linear-gradient(135deg, #92db88, #3c8b47)",
  verdhe: "linear-gradient(135deg, #ffe57b, #f2b632)",
  portokalli: "linear-gradient(135deg, #ffc48a, #f07f2f)",
  argjend: "linear-gradient(135deg, #eef2f7, #aab5c2)",
  ari: "linear-gradient(135deg, #ffe49b, #c89a2c)",
  krem: "linear-gradient(135deg, #fff6eb, #e2c9ae)",
  "shume-ngjyra": "linear-gradient(135deg, #ff6f91 0%, #ffd36e 32%, #8bd97c 64%, #66a9ff 100%)",
};

const AUDIENCE_KEYWORDS = {
  men: ["men", "man", "male", "meshkuj", "burra", "mashkull", "djem"],
  women: ["women", "woman", "female", "femra", "grua", "vajza", "zonja"],
  kids: ["kids", "children", "femije", "djem", "vajza"],
  babies: ["baby", "babies", "bebe", "foshnje"],
};

const PRODUCT_TYPE_KEYWORDS = {
  tshirt: ["tshirt", "t shirt", "maice", "maic"],
  shirt: ["shirt", "kemishe"],
  blouse: ["blouse", "bluze"],
  pants: ["pants", "pantallona"],
  jeans: ["jeans", "xhinse", "denim"],
  shorts: ["shorts", "pantallona te shkurta"],
  hoodie: ["hoodie", "duks"],
  sweater: ["sweater", "pulover"],
  jacket: ["jacket", "jakne"],
  coat: ["coat", "pallto"],
  tracksuit: ["tracksuit", "trenerke"],
  shoes: ["shoes", "kepuce"],
  sneakers: ["sneakers", "patika"],
  dress: ["dress", "fustan"],
  skirt: ["skirt", "fund"],
  perfume: ["perfume", "parfum"],
  shampoo: ["shampoo", "shampo"],
  "face-cream": ["face cream", "krem fytyre", "krem per fytyre"],
  "body-cream": ["body cream", "krem trup", "krem per trup"],
  "hand-cream": ["hand cream", "krem duar", "krem per duar"],
  "hair-cream": ["hair cream", "krem floke"],
  makeup: ["makeup", "kozmetike"],
  lipstick: ["lipstick", "buzekuq"],
  table: ["table", "tavoline"],
  chair: ["chair", "karrige"],
  sofa: ["sofa", "divan"],
  bed: ["bed", "krevat"],
  lamp: ["lamp", "llambe"],
  phone: ["phone", "telefon", "iphone", "android"],
  laptop: ["laptop"],
  tablet: ["tablet"],
  headphones: ["headphones", "degjuese"],
  smartwatch: ["smartwatch", "ore"],
};

const COLOR_KEYWORDS = {
  bardhe: ["white", "bardhe", "e bardhe"],
  zeze: ["black", "zeze", "e zeze"],
  gri: ["gray", "grey", "gri"],
  beige: ["beige", "bezh"],
  kafe: ["brown", "kafe"],
  kuqe: ["red", "kuqe", "e kuqe"],
  roze: ["pink", "roze"],
  vjollce: ["purple", "vjollce"],
  blu: ["blue", "blu", "kalter"],
  gjelber: ["green", "gjelber"],
  verdhe: ["yellow", "verdhe"],
  portokalli: ["orange", "portokalli"],
  argjend: ["silver", "argjend"],
  ari: ["gold", "ari"],
  krem: ["cream", "krem"],
};

const DETAIL_RECOMMENDATIONS_BY_TYPE = {
  tshirt: { colors: ["bardhe", "zeze", "blu", "gri"], material: "Cotton" },
  shirt: { colors: ["bardhe", "blu", "zeze"], material: "Cotton" },
  blouse: { colors: ["bardhe", "roze", "zeze"], material: "Cotton blend" },
  pants: { colors: ["zeze", "gri", "beige"], material: "Cotton blend" },
  jeans: { colors: ["blu", "zeze", "gri"], material: "Denim" },
  hoodie: { colors: ["zeze", "gri", "blu"], material: "Fleece cotton" },
  jacket: { colors: ["zeze", "gri", "kafe"], material: "Polyester" },
  shoes: { colors: ["zeze", "bardhe", "kafe"], material: "Leather" },
  sneakers: { colors: ["bardhe", "zeze", "blu"], material: "Mesh" },
  perfume: { packages: [{ label: "50 ml", value: "50", unit: "ml" }, { label: "100 ml", value: "100", unit: "ml" }] },
  shampoo: { packages: [{ label: "250 ml", value: "250", unit: "ml" }, { label: "500 ml", value: "500", unit: "ml" }] },
  "face-cream": { packages: [{ label: "50 ml", value: "50", unit: "ml" }, { label: "100 ml", value: "100", unit: "ml" }] },
  "body-cream": { packages: [{ label: "200 ml", value: "200", unit: "ml" }, { label: "250 ml", value: "250", unit: "ml" }] },
  "hand-cream": { packages: [{ label: "75 ml", value: "75", unit: "ml" }, { label: "100 ml", value: "100", unit: "ml" }] },
};

const SECTION_FALLBACK_COLORS = {
  clothing: ["zeze", "bardhe", "blu", "gri", "beige"],
  sport: ["zeze", "blu", "bardhe", "gri"],
  technology: ["zeze", "argjend", "bardhe", "gri"],
  home: ["kafe", "beige", "bardhe", "gri"],
};

const TECHNOLOGY_PRESETS_BY_TYPE = {
  phone: [
    { label: "8GB / 256GB", values: { ram: "8 GB", storage: "256 GB", camera: "48 MP", displaySize: "6.5 inch", batteryCapacity: "4500 mAh", color: "zeze" } },
    { label: "12GB / 512GB", values: { ram: "12 GB", storage: "512 GB", camera: "50 MP", displaySize: "6.7 inch", batteryCapacity: "5000 mAh", color: "argjend" } },
  ],
  laptop: [
    { label: "16GB / 512GB SSD", values: { ram: "16 GB", storage: "512 GB SSD", processor: "Intel i7 / Ryzen 7", displaySize: "15.6 inch", color: "gri" } },
    { label: "8GB / 256GB SSD", values: { ram: "8 GB", storage: "256 GB SSD", processor: "Intel i5 / Ryzen 5", displaySize: "14 inch", color: "argjend" } },
  ],
  tablet: [
    { label: "8GB / 128GB", values: { ram: "8 GB", storage: "128 GB", displaySize: "10.9 inch", batteryCapacity: "7000 mAh", color: "gri" } },
  ],
  smartwatch: [
    { label: "Bluetooth / 44mm", values: { storage: "32 GB", displaySize: "44 mm", batteryCapacity: "Up to 18h", color: "zeze" } },
  ],
  headphones: [
    { label: "Wireless", values: { batteryCapacity: "Up to 30h", color: "zeze" } },
  ],
};

const CUSTOM_ATTRIBUTE_PRESETS_BY_TYPE = {
  table: [{ label: "Wood", key: "material", value: "Wood" }, { label: "120 x 70 cm", key: "dimensions", value: "120 x 70 cm" }],
  chair: [{ label: "Fabric", key: "material", value: "Fabric" }, { label: "Matte finish", key: "finish", value: "Matte" }],
  sofa: [{ label: "3-seat", key: "model", value: "3-seat" }, { label: "Fabric", key: "material", value: "Fabric" }],
  bed: [{ label: "160 x 200 cm", key: "dimensions", value: "160 x 200 cm" }, { label: "Wood", key: "material", value: "Wood" }],
  lamp: [{ label: "LED", key: "model", value: "LED" }, { label: "Metal", key: "material", value: "Metal" }],
  sneakers: [{ label: "Mesh", key: "material", value: "Mesh" }, { label: "EU 42", key: "size", value: "EU 42" }],
  ball: [{ label: "Size 5", key: "size", value: "5" }, { label: "PU leather", key: "material", value: "PU leather" }],
  "sports-bag": [{ label: "30 L", key: "volume", value: "30 L" }, { label: "Polyester", key: "material", value: "Polyester" }],
};

const SECTION_CUSTOM_ATTRIBUTE_FALLBACKS = {
  home: [{ label: "Material", key: "material", value: "Wood" }, { label: "Dimensions", key: "dimensions", value: "Standard" }],
  sport: [{ label: "Material", key: "material", value: "Polyester" }, { label: "Size", key: "size", value: "Standard" }],
};

watch(
  () => [props.form.pageSection, props.form.audience],
  () => {
    syncProductFormCatalogState(props.form);
    syncVariantCollections();
  },
  { immediate: true },
);

watch(
  () => (Array.isArray(props.form.selectedColors) ? props.form.selectedColors.join("|") : ""),
  () => {
    if (clothingSection.value) {
      syncClothingColorVariants();
    }
  },
);

function handleSectionChange() {
  syncProductFormCatalogState(props.form);
  syncVariantCollections();
}

function syncVariantCollections() {
  if (!Array.isArray(props.form.selectedColors)) {
    props.form.selectedColors = [];
  }

  if (clothingSection.value) {
    syncClothingColorVariants();
    return;
  }

  if (technologySection.value) {
    if (!Array.isArray(props.form.technologyVariants) || props.form.technologyVariants.length === 0) {
      props.form.technologyVariants = [createEmptyTechnologyVariant()];
    }
    return;
  }

  if (!Array.isArray(props.form.customVariantRows) || props.form.customVariantRows.length === 0) {
    props.form.customVariantRows = [createEmptyCustomVariantRow()];
  }
}

function syncClothingColorVariants() {
  const existingRows = Array.isArray(props.form.clothingColorVariants)
    ? props.form.clothingColorVariants
    : [];
  props.form.clothingColorVariants = props.form.selectedColors.map((color) => {
    const existingRow = existingRows.find((row) => row.color === color);
    return {
      color,
      sizeEntries: CLOTHING_SIZE_OPTIONS.map((option) => {
        const existingEntry = existingRow?.sizeEntries?.find((entry) => entry.size === option.value);
        return {
          size: option.value,
          enabled: Boolean(existingEntry?.enabled),
          quantity: String(existingEntry?.quantity ?? "0"),
          price: String(existingEntry?.price ?? ""),
          imagePath: String(existingEntry?.imagePath || ""),
        };
      }),
    };
  });
}

function toggleColor(colorValue) {
  const currentColors = new Set(Array.isArray(props.form.selectedColors) ? props.form.selectedColors : []);
  if (currentColors.has(colorValue)) {
    currentColors.delete(colorValue);
  } else {
    currentColors.add(colorValue);
  }
  props.form.selectedColors = [...currentColors];
}

function isColorSelected(colorValue) {
  return Array.isArray(props.form.selectedColors) && props.form.selectedColors.includes(colorValue);
}

function addNextColor() {
  const nextOption = PRODUCT_REQUIRED_COLOR_OPTIONS.find((option) => !isColorSelected(option.value));
  if (!nextOption) {
    return;
  }
  toggleColor(nextOption.value);
}

function getColorSwatchStyle(colorValue) {
  const normalizedColor = String(colorValue || "").trim().toLowerCase();
  return {
    background: COLOR_SWATCH_STYLES[normalizedColor] || "linear-gradient(135deg, #f2ece5, #d7c9bd)",
  };
}

function getColorLabel(colorValue) {
  return PRODUCT_COLOR_LABELS[colorValue] || colorValue;
}

function normalizeSuggestionText(value) {
  return String(value || "")
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .trim();
}

function scoreSuggestionValue(value, aliases = []) {
  const context = aiContextText.value;
  if (!context) {
    return 0;
  }

  const candidateTokens = normalizeSuggestionText([value, ...aliases].join(" "))
    .split(" ")
    .filter((token) => token.length > 1);

  return candidateTokens.reduce((score, token) => {
    if (!context.includes(token)) {
      return score;
    }
    return score + (token.length > 3 ? 4 : 2);
  }, 0);
}

function rankSuggestionOptions(options = [], keywordMap = {}, limit = 6) {
  return options
    .map((option, index) => {
      const aliases = keywordMap[String(option.value || "").trim().toLowerCase()] || [];
      const score = scoreSuggestionValue(`${option.label} ${option.value}`, aliases);
      return {
        ...option,
        score,
        index,
      };
    })
    .sort((left, right) => right.score - left.score || left.index - right.index)
    .slice(0, limit);
}

function getRecommendedColorValues() {
  const productType = String(props.form.productType || "").trim().toLowerCase();
  const section = String(props.form.pageSection || "").trim().toLowerCase();
  return DETAIL_RECOMMENDATIONS_BY_TYPE[productType]?.colors
    || SECTION_FALLBACK_COLORS[section]
    || [];
}

function buildColorSuggestions() {
  const recommendedColors = getRecommendedColorValues();
  const recommendedSet = new Set(recommendedColors);
  return PRODUCT_REQUIRED_COLOR_OPTIONS
    .map((option, index) => {
      const aliases = COLOR_KEYWORDS[String(option.value || "").trim().toLowerCase()] || [];
      const score = scoreSuggestionValue(`${option.label} ${option.value}`, aliases)
        + (recommendedSet.has(option.value) ? 6 - Math.max(0, recommendedColors.indexOf(option.value)) : 0)
        + (isColorSelected(option.value) ? 1 : 0);
      return {
        ...option,
        score,
        index,
      };
    })
    .sort((left, right) => right.score - left.score || left.index - right.index)
    .slice(0, 6);
}

function getClothingSizePresetSuggestions() {
  const audience = String(props.form.audience || "").trim().toLowerCase();
  if (audience === "babies") {
    return [
      { label: "0-3 / 3-6", sizes: ["XS", "S"] },
      { label: "6-12 / 12-18", sizes: ["M", "L"] },
    ];
  }
  if (audience === "kids") {
    return [
      { label: "Kids core", sizes: ["XS", "S", "M"] },
      { label: "Kids full", sizes: ["XS", "S", "M", "L"] },
    ];
  }
  return [
    { label: "Core sizes", sizes: ["S", "M", "L"] },
    { label: "Full range", sizes: ["XS", "S", "M", "L", "XL", "XXL"] },
    { label: "Plus sizes", sizes: ["XL", "XXL", "XXXL"] },
  ];
}

function getPackageSuggestionOptions() {
  const productType = String(props.form.productType || "").trim().toLowerCase();
  return DETAIL_RECOMMENDATIONS_BY_TYPE[productType]?.packages || [
    { label: "50 ml", value: "50", unit: "ml" },
    { label: "100 ml", value: "100", unit: "ml" },
    { label: "250 ml", value: "250", unit: "ml" },
  ];
}

function getTechnologyPresetSuggestions() {
  const productType = String(props.form.productType || "").trim().toLowerCase();
  return TECHNOLOGY_PRESETS_BY_TYPE[productType] || [
    { label: "Standard tech", values: { ram: "8 GB", storage: "256 GB", color: "zeze" } },
  ];
}

function getCustomAttributeSuggestions() {
  const productType = String(props.form.productType || "").trim().toLowerCase();
  const section = String(props.form.pageSection || "").trim().toLowerCase();
  return CUSTOM_ATTRIBUTE_PRESETS_BY_TYPE[productType]
    || SECTION_CUSTOM_ATTRIBUTE_FALLBACKS[section]
    || [{ label: "Material", key: "material", value: "Standard" }];
}

function selectAudienceSuggestion(audienceValue) {
  props.form.audience = String(audienceValue || "").trim().toLowerCase();
  handleSectionChange();
}

function selectProductTypeSuggestion(productTypeValue) {
  props.form.productType = String(productTypeValue || "").trim().toLowerCase();
  syncVariantCollections();
}

function applyDetailSuggestion(groupKey, option) {
  if (groupKey === "color") {
    toggleColor(option.value);
    return;
  }

  if (groupKey === "sizePreset") {
    applySizePresetSuggestion(option.sizes || []);
    return;
  }

  if (groupKey === "package") {
    props.form.packageAmountValue = String(option.value || "");
    props.form.packageAmountUnit = String(option.unit || "ml");
    return;
  }

  if (groupKey === "technologyPreset") {
    applyTechnologyPresetSuggestion(option.values || {});
    return;
  }

  if (groupKey === "customAttribute") {
    applyCustomAttributeSuggestion(option);
  }
}

function applySizePresetSuggestion(sizes = []) {
  const normalizedSizes = new Set(
    sizes.map((size) => String(size || "").trim().toUpperCase()).filter(Boolean),
  );
  if (normalizedSizes.size === 0) {
    return;
  }

  if (!selectedColorCount.value) {
    const firstColor = colorSuggestions.value[0]?.value || PRODUCT_REQUIRED_COLOR_OPTIONS[0]?.value || "";
    if (firstColor) {
      props.form.selectedColors = [firstColor];
    }
  }

  syncClothingColorVariants();
  props.form.clothingColorVariants = props.form.clothingColorVariants.map((row) => ({
    ...row,
    sizeEntries: row.sizeEntries.map((entry) => ({
      ...entry,
      enabled: entry.enabled || normalizedSizes.has(String(entry.size || "").trim().toUpperCase()),
    })),
  }));
}

function applyTechnologyPresetSuggestion(values = {}) {
  if (!Array.isArray(props.form.technologyVariants) || props.form.technologyVariants.length === 0) {
    props.form.technologyVariants = [createEmptyTechnologyVariant()];
  }

  props.form.technologyVariants[0] = {
    ...props.form.technologyVariants[0],
    ...Object.fromEntries(
      Object.entries(values).filter(([, value]) => String(value || "").trim()),
    ),
  };
}

function applyCustomAttributeSuggestion(option = {}) {
  if (!Array.isArray(props.form.customVariantRows) || props.form.customVariantRows.length === 0) {
    props.form.customVariantRows = [createEmptyCustomVariantRow()];
  }

  const targetIndex = props.form.customVariantRows.findIndex((row) =>
    !String(row.attributeKey || "").trim() && !String(row.attributeValue || "").trim(),
  );
  const nextRow = {
    attributeKey: String(option.key || "").trim(),
    attributeValue: String(option.value || "").trim(),
    quantity: "0",
    price: "",
    imagePath: "",
  };

  if (targetIndex >= 0) {
    props.form.customVariantRows[targetIndex] = {
      ...props.form.customVariantRows[targetIndex],
      ...nextRow,
    };
    return;
  }

  props.form.customVariantRows = [
    ...props.form.customVariantRows,
    nextRow,
  ];
}

function enabledSizeEntries(colorVariant) {
  return Array.isArray(colorVariant?.sizeEntries)
    ? colorVariant.sizeEntries.filter((entry) => entry.enabled)
    : [];
}

function enableAllSizes() {
  const currentRows = Array.isArray(props.form.clothingColorVariants) ? props.form.clothingColorVariants : [];
  props.form.clothingColorVariants = currentRows.map((row) => ({
    ...row,
    sizeEntries: (Array.isArray(row.sizeEntries) ? row.sizeEntries : createDefaultClothingSizeEntries()).map((entry) => ({
      ...entry,
      enabled: true,
    })),
  }));
}

function addTechnologyVariantRow() {
  props.form.technologyVariants = [
    ...(Array.isArray(props.form.technologyVariants) ? props.form.technologyVariants : []),
    createEmptyTechnologyVariant(),
  ];
}

function removeTechnologyVariantRow(index) {
  const nextRows = (Array.isArray(props.form.technologyVariants) ? props.form.technologyVariants : [])
    .filter((_, rowIndex) => rowIndex !== index);
  props.form.technologyVariants = nextRows.length > 0 ? nextRows : [createEmptyTechnologyVariant()];
}

function addCustomVariantRow() {
  props.form.customVariantRows = [
    ...(Array.isArray(props.form.customVariantRows) ? props.form.customVariantRows : []),
    createEmptyCustomVariantRow(),
  ];
}

function removeCustomVariantRow(index) {
  const nextRows = (Array.isArray(props.form.customVariantRows) ? props.form.customVariantRows : [])
    .filter((_, rowIndex) => rowIndex !== index);
  props.form.customVariantRows = nextRows.length > 0 ? nextRows : [createEmptyCustomVariantRow()];
}
</script>

<template>
  <div class="product-compact-config">
    <section class="product-compact-config__section">
      <div class="product-compact-config__section-head">
        <div>
          <h3>Catalog setup</h3>
          <p>Pick the main placement, product family, and the correct type before you add variants.</p>
        </div>
      </div>

      <div class="product-compact-config__grid product-compact-config__grid--catalog">
        <label class="product-compact-config__field">
          <span>Main category</span>
          <select v-model="form.pageSection" required @change="handleSectionChange">
            <option
              v-for="option in sectionOptions"
              :key="option.value"
              :value="option.value"
            >
              {{ option.label }}
            </option>
          </select>
        </label>

        <label class="product-compact-config__field">
          <span>Subcategory</span>
          <select
            v-if="audienceOptions.length > 0"
            v-model="form.audience"
            required
            @change="handleSectionChange"
          >
            <option
              v-for="option in audienceOptions"
              :key="option.value"
              :value="option.value"
            >
              {{ option.label }}
            </option>
          </select>
          <input v-else type="text" value="No subcategory" disabled>
        </label>

        <label class="product-compact-config__field">
          <span>Product type</span>
          <select v-model="form.productType" required>
            <option
              v-for="option in productTypeOptions"
              :key="option.value"
              :value="option.value"
            >
              {{ option.label }}
            </option>
          </select>
        </label>

        <div
          v-if="packageAmountSection"
          class="product-compact-config__grid product-compact-config__grid--package"
        >
          <label class="product-compact-config__field">
            <span>Package amount</span>
            <input
              v-model="form.packageAmountValue"
              type="number"
              min="0.01"
              step="0.01"
              placeholder="250"
            >
          </label>

          <label class="product-compact-config__field">
            <span>Unit</span>
            <select v-model="form.packageAmountUnit">
              <option
                v-for="option in PRODUCT_AMOUNT_UNIT_OPTIONS"
                :key="option.value"
                :value="option.value"
              >
                {{ option.label }}
              </option>
            </select>
          </label>
        </div>

        <div v-else class="product-compact-config__stock-note">
          <span>Quick note</span>
          <small>Use the stock field above if this product does not need detailed variant rows.</small>
        </div>
      </div>

      <div v-if="hasAiCatalogSuggestions" class="product-compact-config__ai-panel">
        <div class="product-compact-config__ai-head">
          <span>AI recommendations</span>
          <small>{{ aiGuidanceSummary }}</small>
        </div>

        <div v-if="subcategorySuggestions.length > 0" class="product-compact-config__ai-group">
          <p>Subcategory</p>
          <div class="product-compact-config__ai-chips">
            <button
              v-for="option in subcategorySuggestions"
              :key="`ai-audience-${option.value}`"
              type="button"
              :class="{ 'is-selected': form.audience === option.value }"
              @click="selectAudienceSuggestion(option.value)"
            >
              {{ option.label }}
            </button>
          </div>
        </div>

        <div v-if="productTypeSuggestions.length > 0" class="product-compact-config__ai-group">
          <p>Product type</p>
          <div class="product-compact-config__ai-chips">
            <button
              v-for="option in productTypeSuggestions"
              :key="`ai-type-${option.value}`"
              type="button"
              :class="{ 'is-selected': form.productType === option.value }"
              @click="selectProductTypeSuggestion(option.value)"
            >
              {{ option.label }}
            </button>
          </div>
        </div>

        <div
          v-for="group in detailSuggestionGroups"
          :key="`ai-detail-${group.key}`"
          class="product-compact-config__ai-group"
        >
          <p>{{ group.label }}</p>
          <div class="product-compact-config__ai-chips">
            <button
              v-for="option in group.options"
              :key="`${group.key}-${option.value || option.label}`"
              type="button"
              :class="{ 'is-selected': group.key === 'color' && isColorSelected(option.value) }"
              @click="applyDetailSuggestion(group.key, option)"
            >
              <span
                v-if="group.key === 'color'"
                class="product-compact-config__swatch-dot"
                :style="getColorSwatchStyle(option.value)"
                aria-hidden="true"
              ></span>
              {{ option.label }}
            </button>
          </div>
        </div>
      </div>
    </section>

    <section class="product-compact-config__section">
      <div class="product-compact-config__section-head">
        <div>
          <h3>Variant setup</h3>
          <p>{{ variantSummary }}</p>
        </div>

        <div class="product-compact-config__actions">
          <button
            v-if="clothingSection && selectedColorCount > 0"
            type="button"
            class="product-compact-config__link-action"
            @click="enableAllSizes"
          >
            Enable all sizes
          </button>
          <button
            v-else-if="technologySection"
            type="button"
            class="product-compact-config__link-action"
            @click="addTechnologyVariantRow"
          >
            Add tech row
          </button>
          <button
            v-else-if="customAttributesSection"
            type="button"
            class="product-compact-config__link-action"
            @click="addCustomVariantRow"
          >
            Add option row
          </button>
        </div>
      </div>

      <template v-if="clothingSection">
        <div class="product-compact-config__colors">
          <div class="product-compact-config__colors-head">
            <span>Available colors</span>
            <div class="product-compact-config__colors-actions">
              <small>{{ selectedColorCount ? `${selectedColorCount} selected` : "Choose at least one" }}</small>
              <button type="button" @click="addNextColor">Add color</button>
            </div>
          </div>

          <div class="product-compact-config__swatches">
            <button
              v-for="option in PRODUCT_REQUIRED_COLOR_OPTIONS"
              :key="option.value"
              class="product-compact-config__swatch"
              :class="{ 'is-selected': isColorSelected(option.value) }"
              type="button"
              @click="toggleColor(option.value)"
            >
              <span
                class="product-compact-config__swatch-dot"
                :style="getColorSwatchStyle(option.value)"
                aria-hidden="true"
              ></span>
              <span class="product-compact-config__swatch-label">{{ option.label }}</span>
            </button>
          </div>
        </div>

        <div
          v-if="form.clothingColorVariants.length > 0"
          class="product-compact-config__variant-groups"
        >
          <article
            v-for="colorVariant in form.clothingColorVariants"
            :key="colorVariant.color"
            class="product-compact-config__variant-group"
          >
            <div class="product-compact-config__variant-group-head">
              <div class="product-compact-config__variant-group-color">
                <span
                  class="product-compact-config__swatch-dot"
                  :style="getColorSwatchStyle(colorVariant.color)"
                  aria-hidden="true"
                ></span>
                <strong>{{ getColorLabel(colorVariant.color) }}</strong>
              </div>
              <small>{{ enabledSizeEntries(colorVariant).length }} active rows</small>
            </div>

            <div class="product-compact-config__size-grid">
              <label
                v-for="sizeEntry in colorVariant.sizeEntries"
                :key="`${colorVariant.color}-${sizeEntry.size}`"
                class="product-compact-config__size-toggle"
                :class="{ 'is-selected': sizeEntry.enabled }"
              >
                <input v-model="sizeEntry.enabled" type="checkbox">
                <span>{{ sizeEntry.size }}</span>
              </label>
            </div>

            <div v-if="enabledSizeEntries(colorVariant).length > 0" class="product-compact-config__table-wrap">
              <div class="product-compact-config__variant-table product-compact-config__variant-table--clothing">
                <div class="product-compact-config__variant-head">
                  <span>Size</span>
                  <span>Qty</span>
                  <span>Price</span>
                  <span>Variant image</span>
                </div>

                <div
                  v-for="sizeEntry in enabledSizeEntries(colorVariant)"
                  :key="`${colorVariant.color}-${sizeEntry.size}-row`"
                  class="product-compact-config__variant-row"
                >
                  <strong class="product-compact-config__variant-cell product-compact-config__variant-cell--key">
                    {{ sizeEntry.size }}
                  </strong>
                  <input
                    v-model="sizeEntry.quantity"
                    type="number"
                    min="0"
                    step="1"
                    placeholder="Qty"
                  >
                  <input
                    v-model="sizeEntry.price"
                    type="number"
                    min="0"
                    step="0.01"
                    placeholder="Price"
                  >
                  <input
                    v-model="sizeEntry.imagePath"
                    type="text"
                    placeholder="Variant image path"
                  >
                </div>
              </div>
            </div>

            <p v-else class="product-compact-config__empty-note">
              Enable the exact sizes you want to keep live for this color.
            </p>
          </article>
        </div>

        <p
          v-else
          class="product-compact-config__empty-note"
        >
          Select colors to unlock size rows.
        </p>
      </template>

      <div v-else-if="technologySection" class="product-compact-config__table-wrap">
        <div class="product-compact-config__variant-table product-compact-config__variant-table--technology">
          <div class="product-compact-config__variant-head product-compact-config__variant-head--technology">
            <span>RAM</span>
            <span>Storage</span>
            <span>Processor</span>
            <span>Battery</span>
            <span>Display</span>
            <span>Camera</span>
            <span>Color</span>
            <span>Qty</span>
            <span>Price</span>
            <span>Variant image</span>
            <span class="sr-only">Remove</span>
          </div>

          <div
            v-for="(variant, index) in form.technologyVariants"
            :key="`technology-row-${index}`"
            class="product-compact-config__variant-row product-compact-config__variant-row--technology"
          >
            <input v-model="variant.ram" type="text" placeholder="8 GB">
            <input v-model="variant.storage" type="text" placeholder="256 GB">
            <input v-model="variant.processor" type="text" placeholder="A17 Pro">
            <input v-model="variant.batteryCapacity" type="text" placeholder="4200 mAh">
            <input v-model="variant.displaySize" type="text" placeholder="6.7 inch">
            <input v-model="variant.camera" type="text" placeholder="48 MP">
            <select v-model="variant.color">
              <option value="">Color</option>
              <option
                v-for="option in PRODUCT_REQUIRED_COLOR_OPTIONS"
                :key="`technology-color-${index}-${option.value}`"
                :value="option.value"
              >
                {{ option.label }}
              </option>
            </select>
            <input v-model="variant.quantity" type="number" min="0" step="1" placeholder="Qty">
            <input v-model="variant.price" type="number" min="0" step="0.01" placeholder="Price">
            <input v-model="variant.imagePath" type="text" placeholder="Variant image path">
            <button type="button" class="product-compact-config__row-remove" @click="removeTechnologyVariantRow(index)">
              Remove
            </button>
          </div>
        </div>
      </div>

      <div v-else-if="customAttributesSection" class="product-compact-config__table-wrap">
        <div class="product-compact-config__variant-table product-compact-config__variant-table--custom">
          <div class="product-compact-config__variant-head product-compact-config__variant-head--custom">
            <span>Attribute</span>
            <span>Value</span>
            <span>Qty</span>
            <span>Price</span>
            <span>Variant image</span>
            <span class="sr-only">Remove</span>
          </div>

          <div
            v-for="(variant, index) in form.customVariantRows"
            :key="`custom-row-${index}`"
            class="product-compact-config__variant-row product-compact-config__variant-row--custom"
          >
            <input v-model="variant.attributeKey" type="text" placeholder="Material / Finish / Model">
            <input v-model="variant.attributeValue" type="text" placeholder="Cotton / Matte / Standard">
            <input v-model="variant.quantity" type="number" min="0" step="1" placeholder="Qty">
            <input v-model="variant.price" type="number" min="0" step="0.01" placeholder="Price">
            <input v-model="variant.imagePath" type="text" placeholder="Variant image path">
            <button type="button" class="product-compact-config__row-remove" @click="removeCustomVariantRow(index)">
              Remove
            </button>
          </div>
        </div>
      </div>
    </section>
  </div>
</template>

<style scoped>
.product-compact-config {
  display: grid;
  gap: 12px;
}

.product-compact-config__section {
  display: grid;
  gap: 12px;
  padding: 14px;
  border: 1px solid #ececec;
  border-radius: 12px;
  background: #fcfcfc;
}

.product-compact-config__section-head {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 12px;
}

.product-compact-config__section-head h3,
.product-compact-config__section-head p {
  margin: 0;
}

.product-compact-config__section-head h3 {
  color: #111111;
  font-size: 14px;
  font-weight: 700;
  line-height: 1.35;
}

.product-compact-config__section-head p {
  margin-top: 3px;
  color: #737373;
  font-size: 12px;
  line-height: 1.45;
}

.product-compact-config__actions {
  display: inline-flex;
  align-items: center;
  gap: 8px;
}

.product-compact-config__link-action {
  min-height: 32px;
  padding: 0 12px;
  border: 1px solid #e5e5e5;
  border-radius: 10px;
  background: #ffffff;
  color: #444444;
  font-size: 12px;
  font-weight: 600;
  cursor: pointer;
  transition: border-color 160ms ease, background-color 160ms ease, color 160ms ease;
}

.product-compact-config__link-action:hover,
.product-compact-config__row-remove:hover,
.product-compact-config__colors-actions button:hover {
  border-color: #d7d7d7;
  background: #fafafa;
  color: #111111;
}

.product-compact-config__grid {
  display: grid;
  gap: 10px;
}

.product-compact-config__grid--catalog {
  grid-template-columns: repeat(2, minmax(0, 1fr));
}

.product-compact-config__grid--package {
  grid-template-columns: minmax(0, 1fr) 112px;
}

.product-compact-config__field {
  min-width: 0;
  display: grid;
  gap: 5px;
}

.product-compact-config__field span,
.product-compact-config__colors-head span {
  color: #111111;
  font-size: 12px;
  font-weight: 600;
  line-height: 1.35;
}

.product-compact-config__stock-note {
  min-height: 44px;
  display: grid;
  align-content: center;
  gap: 2px;
  padding: 0 12px;
  border: 1px solid #ececec;
  border-radius: 10px;
  background: #ffffff;
}

.product-compact-config__stock-note span {
  color: #111111;
  font-size: 12px;
  font-weight: 600;
}

.product-compact-config__stock-note small,
.product-compact-config__colors-head small,
.product-compact-config__variant-group-head small {
  color: #7d7d7d;
  font-size: 11px;
  line-height: 1.4;
}

.product-compact-config__ai-panel {
  display: grid;
  gap: 10px;
  padding: 12px;
  border: 1px solid #dbe7ff;
  border-radius: 12px;
  background: #f7fbff;
}

.product-compact-config__ai-head {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 12px;
}

.product-compact-config__ai-head span,
.product-compact-config__ai-group p {
  margin: 0;
  color: #111111;
  font-size: 12px;
  font-weight: 700;
  line-height: 1.35;
}

.product-compact-config__ai-head small {
  max-width: 520px;
  color: #5b6f95;
  font-size: 11px;
  line-height: 1.45;
  text-align: right;
}

.product-compact-config__ai-group {
  display: grid;
  gap: 7px;
}

.product-compact-config__ai-chips {
  display: flex;
  flex-wrap: wrap;
  gap: 7px;
}

.product-compact-config__ai-chips button {
  min-height: 30px;
  display: inline-flex;
  align-items: center;
  gap: 7px;
  padding: 0 10px;
  border: 1px solid #cfe0ff;
  border-radius: 999px;
  background: #ffffff;
  color: #1f4f8f;
  font-size: 11px;
  font-weight: 700;
  line-height: 1;
  cursor: pointer;
  transition:
    border-color 160ms ease,
    background-color 160ms ease,
    color 160ms ease;
}

.product-compact-config__ai-chips button:hover,
.product-compact-config__ai-chips button.is-selected {
  border-color: #2563eb;
  background: #eff6ff;
  color: #1d4ed8;
}

.product-compact-config__colors {
  display: grid;
  gap: 10px;
}

.product-compact-config__colors-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
}

.product-compact-config__colors-actions {
  display: inline-flex;
  align-items: center;
  gap: 8px;
}

.product-compact-config__colors-actions button,
.product-compact-config__row-remove {
  min-height: 32px;
  padding: 0 10px;
  border: 1px solid #e5e5e5;
  border-radius: 10px;
  background: #ffffff;
  color: #555555;
  font-size: 11px;
  font-weight: 700;
  cursor: pointer;
  transition: border-color 160ms ease, background-color 160ms ease, color 160ms ease;
}

.product-compact-config__swatches {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.product-compact-config__swatch {
  min-height: 34px;
  display: inline-flex;
  align-items: center;
  gap: 8px;
  padding: 0 10px 0 8px;
  border: 1px solid #eaeaea;
  border-radius: 999px;
  background: #ffffff;
  color: #555555;
  cursor: pointer;
  transition: border-color 160ms ease, background-color 160ms ease, color 160ms ease;
}

.product-compact-config__swatch:hover {
  border-color: #d8d8d8;
  color: #111111;
}

.product-compact-config__swatch.is-selected {
  border-color: #111111;
  background: #111111;
  color: #ffffff;
}

.product-compact-config__swatch-dot {
  width: 14px;
  height: 14px;
  flex-shrink: 0;
  border-radius: 999px;
  border: 1px solid rgba(17, 17, 17, 0.08);
}

.product-compact-config__swatch-label {
  font-size: 12px;
  font-weight: 600;
  line-height: 1;
}

.product-compact-config__variant-groups {
  display: grid;
  gap: 10px;
}

.product-compact-config__variant-group {
  display: grid;
  gap: 10px;
  padding: 12px;
  border: 1px solid #ececec;
  border-radius: 12px;
  background: #ffffff;
}

.product-compact-config__variant-group-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
}

.product-compact-config__variant-group-color {
  display: inline-flex;
  align-items: center;
  gap: 8px;
}

.product-compact-config__variant-group-color strong,
.product-compact-config__variant-cell--key {
  color: #111111;
  font-size: 12px;
  font-weight: 700;
  line-height: 1.35;
}

.product-compact-config__size-grid {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.product-compact-config__size-toggle {
  position: relative;
  display: inline-flex;
  align-items: center;
  min-height: 30px;
  padding: 0 10px;
  border: 1px solid #e6e6e6;
  border-radius: 999px;
  background: #fafafa;
  color: #555555;
  cursor: pointer;
  transition: border-color 160ms ease, background-color 160ms ease, color 160ms ease;
}

.product-compact-config__size-toggle input {
  position: absolute;
  inset: 0;
  opacity: 0;
  margin: 0;
  cursor: pointer;
}

.product-compact-config__size-toggle span {
  font-size: 11px;
  font-weight: 700;
  line-height: 1;
}

.product-compact-config__size-toggle.is-selected {
  border-color: #111111;
  background: #111111;
  color: #ffffff;
}

.product-compact-config__table-wrap {
  overflow-x: auto;
}

.product-compact-config__variant-table {
  min-width: 100%;
  display: grid;
  gap: 8px;
}

.product-compact-config__variant-head,
.product-compact-config__variant-row {
  display: grid;
  align-items: center;
  gap: 8px;
}

.product-compact-config__variant-head {
  padding: 0 4px;
}

.product-compact-config__variant-head span {
  color: #737373;
  font-size: 11px;
  font-weight: 700;
  line-height: 1.2;
  text-transform: uppercase;
  letter-spacing: 0.04em;
}

.product-compact-config__variant-row {
  padding: 8px;
  border: 1px solid #ececec;
  border-radius: 12px;
  background: #ffffff;
}

.product-compact-config__variant-table--clothing .product-compact-config__variant-head,
.product-compact-config__variant-table--clothing .product-compact-config__variant-row {
  grid-template-columns: 68px 92px 112px minmax(220px, 1fr);
}

.product-compact-config__variant-table--technology .product-compact-config__variant-head,
.product-compact-config__variant-table--technology .product-compact-config__variant-row {
  grid-template-columns: 96px 108px 124px 110px 104px 108px 104px 82px 96px minmax(180px, 1fr) 78px;
}

.product-compact-config__variant-table--custom .product-compact-config__variant-head,
.product-compact-config__variant-table--custom .product-compact-config__variant-row {
  grid-template-columns: 164px minmax(180px, 1fr) 84px 96px minmax(180px, 1fr) 78px;
}

.product-compact-config__variant-cell {
  min-height: 42px;
  display: inline-flex;
  align-items: center;
  padding: 0 12px;
  border: 1px solid #ececec;
  border-radius: 10px;
  background: #fafafa;
}

.product-compact-config__empty-note {
  margin: 0;
  color: #7d7d7d;
  font-size: 12px;
  line-height: 1.5;
}

@media (max-width: 900px) {
  .product-compact-config__grid--catalog,
  .product-compact-config__grid--package {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 720px) {
  .product-compact-config__section-head,
  .product-compact-config__colors-head,
  .product-compact-config__ai-head,
  .product-compact-config__variant-group-head {
    align-items: flex-start;
    flex-direction: column;
  }

  .product-compact-config__ai-head small {
    text-align: left;
  }
}
</style>
