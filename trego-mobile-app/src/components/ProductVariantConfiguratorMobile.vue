<script setup lang="ts">
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
} from "../lib/productCatalog";

const props = defineProps<{
  form: Record<string, any>;
}>();

const sectionOptions = PRODUCT_PAGE_SECTION_OPTIONS;
const audienceOptions = computed(() => getAudienceOptionsForSection(String(props.form.pageSection || "")));
const productTypeOptions = computed(() => getProductTypeOptions(String(props.form.pageSection || ""), String(props.form.audience || "")));
const clothingSection = computed(() => isClothingSection(String(props.form.pageSection || "")));
const colorInventorySection = computed(() => supportsColorInventory(String(props.form.pageSection || "")));
const packageAmountSection = computed(() => supportsPackageAmount(String(props.form.pageSection || "")));

const COLOR_SWATCH_STYLES: Record<string, string> = {
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
  () => (Array.isArray(props.form.selectedColors) ? [...props.form.selectedColors] : []),
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
    const existingRows = Array.isArray(props.form.clothingColorVariants) ? props.form.clothingColorVariants : [];
    props.form.clothingColorVariants = props.form.selectedColors.map((color: string) => {
      const existingRow = existingRows.find((row: any) => row.color === color);
      return {
        color,
        sizeEntries: CLOTHING_SIZE_OPTIONS.map((option) => {
          const existingEntry = existingRow?.sizeEntries?.find((entry: any) => entry.size === option.value);
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
    props.form.colorStockVariants = [];
    return;
  }

  if (colorInventorySection.value) {
    const existingRows = Array.isArray(props.form.colorStockVariants) ? props.form.colorStockVariants : [];
    props.form.colorStockVariants = props.form.selectedColors.map((color: string) => {
      const existingRow = existingRows.find((row: any) => row.color === color);
      return {
        color,
        quantity: String(existingRow?.quantity ?? "0"),
        price: String(existingRow?.price ?? ""),
        imagePath: String(existingRow?.imagePath || ""),
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

function toggleColor(colorValue: string, event: Event) {
  const checked = Boolean((event.target as HTMLInputElement | null)?.checked);
  const nextColors = new Set(Array.isArray(props.form.selectedColors) ? props.form.selectedColors : []);
  if (checked) {
    nextColors.add(colorValue);
  } else {
    nextColors.delete(colorValue);
  }

  props.form.selectedColors = [...nextColors];
  syncVariantCollections();
}

function getColorSwatchStyle(colorValue: string) {
  const normalizedColor = String(colorValue || "").trim().toLowerCase();
  return {
    background: COLOR_SWATCH_STYLES[normalizedColor] || "linear-gradient(135deg, #f2ece5, #d7c9bd)",
  };
}
</script>

<template>
  <label class="checkout-field">
    <span>Kategoria e faqes</span>
    <select v-model="form.pageSection" class="mobile-select" @change="handleSectionChange">
      <option v-for="option in sectionOptions" :key="option.value" :value="option.value">
        {{ option.label }}
      </option>
    </select>
  </label>

  <label v-if="audienceOptions.length > 0" class="checkout-field">
    <span>Nenkategoria</span>
    <select v-model="form.audience" class="mobile-select" @change="handleSectionChange">
      <option v-for="option in audienceOptions" :key="option.value" :value="option.value">
        {{ option.label }}
      </option>
    </select>
  </label>

  <label class="checkout-field">
    <span>Lloji i produktit</span>
    <select v-model="form.productType" class="mobile-select">
      <option v-for="option in productTypeOptions" :key="option.value" :value="option.value">
        {{ option.label }}
      </option>
    </select>
  </label>

  <div v-if="packageAmountSection" class="checkout-grid">
    <label class="checkout-field">
      <span>Sasia e produktit</span>
      <input v-model="form.packageAmountValue" class="promo-input" type="number" min="0.01" step="0.01" placeholder="250" />
    </label>

    <label class="checkout-field">
      <span>Njesia</span>
      <select v-model="form.packageAmountUnit" class="mobile-select">
        <option v-for="option in PRODUCT_AMOUNT_UNIT_OPTIONS" :key="option.value" :value="option.value">
          {{ option.label }}
        </option>
      </select>
    </label>
  </div>

  <div v-if="colorInventorySection" class="checkout-field">
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
        <span class="product-color-selector-swatch" :style="getColorSwatchStyle(option.value)" aria-hidden="true" />
        <span class="product-color-selector-copy">
          <strong>{{ option.label }}</strong>
          <small>{{ form.selectedColors.includes(option.value) ? "E zgjedhur" : "Aktivizo" }}</small>
        </span>
      </label>
    </div>
  </div>

  <div v-if="clothingSection && form.clothingColorVariants.length > 0" class="variant-stack">
    <div v-for="colorVariant in form.clothingColorVariants" :key="colorVariant.color" class="variant-card">
      <p class="variant-title">{{ PRODUCT_COLOR_LABELS[colorVariant.color] || colorVariant.color }}</p>
      <div class="variant-size-grid">
        <label v-for="sizeEntry in colorVariant.sizeEntries" :key="`${colorVariant.color}-${sizeEntry.size}`" class="variant-size-row">
          <span class="variant-size-check">
            <input v-model="sizeEntry.enabled" type="checkbox">
            <strong>{{ sizeEntry.size }}</strong>
          </span>
          <div class="variant-field-grid">
            <input v-model="sizeEntry.quantity" class="promo-input" type="number" min="0" step="1" :disabled="!sizeEntry.enabled" placeholder="Stok" />
            <input v-model="sizeEntry.price" class="promo-input" type="number" min="0" step="0.01" :disabled="!sizeEntry.enabled" placeholder="Cmimi" />
            <input v-model="sizeEntry.imagePath" class="promo-input" type="text" :disabled="!sizeEntry.enabled" placeholder="Foto e variantit" />
          </div>
        </label>
      </div>
    </div>
  </div>

  <div v-else-if="colorInventorySection && form.colorStockVariants.length > 0" class="variant-stack">
    <label v-for="colorEntry in form.colorStockVariants" :key="colorEntry.color" class="variant-color-row">
      <strong>{{ PRODUCT_COLOR_LABELS[colorEntry.color] || colorEntry.color }}</strong>
      <div class="variant-field-grid">
        <input v-model="colorEntry.quantity" class="promo-input" type="number" min="0" step="1" placeholder="Stok" />
        <input v-model="colorEntry.price" class="promo-input" type="number" min="0" step="0.01" placeholder="Cmimi" />
        <input v-model="colorEntry.imagePath" class="promo-input" type="text" placeholder="Foto e variantit" />
      </div>
    </label>
  </div>

  <label v-if="!clothingSection && (!colorInventorySection || form.colorStockVariants.length === 0)" class="checkout-field">
    <span>Sasia ne stok</span>
    <input v-model="form.simpleStockQuantity" class="promo-input" type="number" min="0" step="1" />
  </label>
</template>

<style scoped>
.mobile-select {
  width: 100%;
  min-height: 48px;
  padding: 0 14px;
  border: 1px solid var(--trego-input-border);
  border-radius: 18px;
  background: var(--trego-input-bg);
  color: var(--trego-dark);
}

.product-color-selector-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 10px;
}

.product-color-selector-chip {
  display: grid;
  grid-template-columns: 34px minmax(0, 1fr);
  align-items: center;
  gap: 10px;
  padding: 12px;
  border: 1px solid var(--trego-input-border);
  border-radius: 18px;
  background: var(--trego-interactive-bg);
}

.product-color-selector-chip.is-selected {
  border-color: var(--trego-selection-border);
  box-shadow: var(--trego-selection-shadow);
}

.product-color-selector-input {
  position: absolute;
  opacity: 0;
  pointer-events: none;
}

.product-color-selector-swatch {
  width: 34px;
  height: 34px;
  border-radius: 14px;
  box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.72);
}

.product-color-selector-copy {
  display: grid;
  gap: 2px;
}

.product-color-selector-copy strong,
.product-color-selector-copy small {
  margin: 0;
}

.product-color-selector-copy small {
  color: var(--trego-muted);
}

.variant-stack {
  display: grid;
  gap: 12px;
}

.variant-card {
  padding: 14px;
  border-radius: 20px;
  border: 1px solid var(--trego-input-border);
  background: var(--trego-interactive-bg);
}

.variant-title {
  margin: 0 0 10px;
  color: var(--trego-dark);
  font-weight: 800;
}

.variant-size-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 10px;
}

.variant-size-row,
.variant-color-row {
  display: grid;
  gap: 8px;
}

.variant-field-grid {
  display: grid;
  grid-template-columns: 84px 104px minmax(0, 1fr);
  gap: 8px;
}

.variant-size-check {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  color: var(--trego-dark);
}

@media (max-width: 420px) {
  .product-color-selector-grid,
  .variant-size-grid {
    grid-template-columns: 1fr;
  }

  .variant-field-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }

  .variant-field-grid :last-child {
    grid-column: 1 / -1;
  }
}
</style>
