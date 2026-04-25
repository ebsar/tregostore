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
  .product-compact-config__variant-group-head {
    align-items: flex-start;
    flex-direction: column;
  }
}
</style>
