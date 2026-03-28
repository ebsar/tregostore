<script setup>
import { computed, watch } from "vue";
import {
  CLOTHING_SIZE_OPTIONS,
  PRODUCT_AMOUNT_UNIT_OPTIONS,
  PRODUCT_COLOR_LABELS,
  PRODUCT_PAGE_SECTION_OPTIONS,
  PRODUCT_REQUIRED_COLOR_OPTIONS,
  getAudienceOptionsForSection,
  getProductTypeOptions,
  isClothingSection,
  supportsColorInventory,
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
const colorInventorySection = computed(() => supportsColorInventory(props.form.pageSection));
const packageAmountSection = computed(() => supportsPackageAmount(props.form.pageSection));
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
  () => props.form.selectedColors.slice(),
  () => {
    syncVariantCollections();
  },
  { deep: true },
);

function syncVariantCollections() {
  if (!Array.isArray(props.form.selectedColors)) {
    props.form.selectedColors = [];
  }

  if (clothingSection.value) {
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
          };
        }),
      };
    });
    props.form.colorStockVariants = [];
    return;
  }

  if (colorInventorySection.value) {
    const existingRows = Array.isArray(props.form.colorStockVariants)
      ? props.form.colorStockVariants
      : [];
    props.form.colorStockVariants = props.form.selectedColors.map((color) => {
      const existingRow = existingRows.find((row) => row.color === color);
      return {
        color,
        quantity: String(existingRow?.quantity ?? "0"),
      };
    });
    props.form.clothingColorVariants = [];
    return;
  }

  props.form.clothingColorVariants = [];
  props.form.colorStockVariants = [];
  props.form.selectedColors = [];
}

function handleSectionChange() {
  syncProductFormCatalogState(props.form);
  syncVariantCollections();
}

function toggleColor(colorValue, event) {
  const checked = Boolean(event?.target?.checked);
  const nextColors = new Set(Array.isArray(props.form.selectedColors) ? props.form.selectedColors : []);
  if (checked) {
    nextColors.add(colorValue);
  } else {
    nextColors.delete(colorValue);
  }

  props.form.selectedColors = [...nextColors];
  syncVariantCollections();
}

function getColorSwatchStyle(colorValue) {
  const normalizedColor = String(colorValue || "").trim().toLowerCase();
  return {
    background: COLOR_SWATCH_STYLES[normalizedColor] || "linear-gradient(135deg, #f2ece5, #d7c9bd)",
  };
}
</script>

<template>
  <label class="field">
    <span>Kategoria e faqes</span>
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

  <label v-if="audienceOptions.length > 0" class="field">
    <span>Nenkategoria</span>
    <select v-model="form.audience" required @change="handleSectionChange">
      <option
        v-for="option in audienceOptions"
        :key="option.value"
        :value="option.value"
      >
        {{ option.label }}
      </option>
    </select>
  </label>

  <label class="field">
    <span>Lloji i produktit</span>
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

  <div v-if="packageAmountSection" class="field-row">
    <label class="field">
      <span>Sasia e produktit</span>
      <input
        v-model="form.packageAmountValue"
        type="number"
        min="0.01"
        step="0.01"
        placeholder="p.sh. 250"
      >
    </label>

    <label class="field">
      <span>Njesia</span>
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

  <div v-if="colorInventorySection" class="field">
    <span>Ngjyrat ne dispozicion</span>
    <div class="product-color-selector-grid">
      <label
        v-for="option in PRODUCT_REQUIRED_COLOR_OPTIONS"
        :key="option.value"
        class="product-color-selector-chip"
        :class="{ 'is-selected': form.selectedColors.includes(option.value) }"
      >
        <input
          class="product-color-selector-input"
          type="checkbox"
          :checked="form.selectedColors.includes(option.value)"
          @change="toggleColor(option.value, $event)"
        >
        <span
          class="product-color-selector-swatch"
          :style="getColorSwatchStyle(option.value)"
          aria-hidden="true"
        ></span>
        <span class="product-color-selector-copy">
          <strong>{{ option.label }}</strong>
          <small>{{ form.selectedColors.includes(option.value) ? "E zgjedhur" : "Kliko per zgjedhje" }}</small>
        </span>
      </label>
    </div>
  </div>

  <div v-if="clothingSection && form.clothingColorVariants.length > 0" class="product-variant-editor">
    <div
      v-for="colorVariant in form.clothingColorVariants"
      :key="colorVariant.color"
      class="product-variant-color-card"
    >
      <p class="product-variant-color-title">{{ PRODUCT_COLOR_LABELS[colorVariant.color] || colorVariant.color }}</p>
      <div class="product-variant-size-grid">
        <label
          v-for="sizeEntry in colorVariant.sizeEntries"
          :key="`${colorVariant.color}-${sizeEntry.size}`"
          class="product-variant-size-row"
        >
          <span class="product-variant-size-check">
            <input v-model="sizeEntry.enabled" type="checkbox">
            <strong>{{ sizeEntry.size }}</strong>
          </span>
          <input
            v-model="sizeEntry.quantity"
            type="number"
            min="0"
            step="1"
            :disabled="!sizeEntry.enabled"
            placeholder="0"
          >
        </label>
      </div>
    </div>
  </div>

  <div
    v-else-if="colorInventorySection && form.colorStockVariants.length > 0"
    class="product-variant-editor product-variant-editor-compact"
  >
    <label
      v-for="colorEntry in form.colorStockVariants"
      :key="colorEntry.color"
      class="product-variant-color-row"
    >
      <strong>{{ PRODUCT_COLOR_LABELS[colorEntry.color] || colorEntry.color }}</strong>
      <input v-model="colorEntry.quantity" type="number" min="0" step="1" placeholder="0">
    </label>
  </div>

  <label
    v-if="!clothingSection && (!colorInventorySection || form.colorStockVariants.length === 0)"
    class="field"
  >
    <span>Sasia ne stok</span>
    <input v-model="form.simpleStockQuantity" type="number" min="0" step="1" required>
  </label>
</template>
