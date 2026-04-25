<script setup>
import { computed, onMounted, reactive, ref, watch } from "vue";
import { RouterLink, useRoute, useRouter } from "vue-router";
import ProductCard from "../components/ProductCard.vue";
import {
  fetchProductRecommendations,
  fetchProtectedCollection,
  requestJson,
  resolveApiMessage,
  trackProductShare,
} from "../lib/api";
import { readRecentlyViewedProducts, rememberRecentlyViewedProduct } from "../lib/recently-viewed";
import { trackAddToCart, trackProductView } from "../lib/tracking";
import {
  formatCategoryLabel,
  formatCount,
  formatDateLabel,
  formatPrice,
  formatProductColorLabel,
  formatProductTypeLabel,
  getBusinessProfileUrl,
  getCategoryUrl,
  getProductDetailUrl,
  getProductImageGallery,
  getProductStockMessage,
  hasProductAvailableStock,
} from "../lib/shop";
import { applyDocumentSeo, buildAbsoluteUrl, buildBreadcrumbJsonLd } from "../lib/seo";
import { compareState, ensureCompareItemsLoaded, toggleComparedProduct } from "../stores/product-compare";
import { appState, ensureSessionLoaded, markRouteReady, setCartItems } from "../stores/app-state";

const route = useRoute();
const router = useRouter();
const currentProduct = ref(null);
const currentImageIndex = ref(0);
const wishlistIds = ref([]);
const cartIds = ref([]);
const selectedColor = ref("");
const selectedSize = ref("");
const selectedVariantAttributes = reactive({});
const selectedQuantity = ref(1);
const productReviews = ref([]);
const productRecommendationSections = ref([]);
const recentlyViewedProducts = ref([]);
const canSubmitReview = ref(false);
const reviewBusy = ref(false);
const activeDetailTab = ref("description");
const showReviewComposer = ref(false);
const reviewForm = reactive({
  rating: 5,
  title: "",
  body: "",
});
const ui = reactive({
  message: "",
  type: "",
});
const isCompared = computed(() =>
  compareState.items.some((item) => Number(item.id || item.productId || 0) === Number(currentProduct.value?.id || 0)),
);
const canSeeProductEngagement = computed(() =>
  appState.user?.role === "business" || appState.user?.role === "admin",
);
const isProductAvailable = computed(() => hasProductAvailableStock(currentProduct.value || {}));
const outOfStockMessage = computed(() => getProductStockMessage(currentProduct.value || {}));
const businessName = computed(() => String(currentProduct.value?.businessName || "").trim());
const sellerSupportEmail = computed(() => String(currentProduct.value?.supportEmail || "").trim());
const sellerWebsiteUrl = computed(() => String(currentProduct.value?.websiteUrl || "").trim());
const sellerSupportHours = computed(() => String(currentProduct.value?.supportHours || "").trim());
const sellerReturnPolicySummary = computed(() => String(currentProduct.value?.returnPolicySummary || "").trim());
const productMetaTitle = computed(() => String(currentProduct.value?.metaTitle || "").trim());
const productMetaDescription = computed(() => String(currentProduct.value?.metaDescription || "").trim());
const sellerShippingSettings = computed(() => normalizeShippingSettings(currentProduct.value?.shippingSettings));

const variantInventory = computed(() => {
  if (!Array.isArray(currentProduct.value?.variantInventory)) {
    return [];
  }

  return currentProduct.value.variantInventory;
});

function getVariantAttributeValue(entry, attributeKey) {
  if (attributeKey === "color") {
    return String(entry?.colorLabel || entry?.attributes?.color || entry?.color || "").trim();
  }
  if (attributeKey === "size") {
    return String(entry?.size || entry?.attributes?.size || "").trim().toUpperCase();
  }
  return String(entry?.attributes?.[attributeKey] || "").trim();
}

function variantEntryMatchesSelections(entry, ignoreKey = "") {
  const colorMatches = ignoreKey === "color"
    || !selectedColor.value
    || String(entry?.color || "").trim().toLowerCase() === selectedColor.value;
  const sizeMatches = ignoreKey === "size"
    || !selectedSize.value
    || String(entry?.size || "").trim().toUpperCase() === selectedSize.value;
  const attributeMatches = Object.entries(selectedVariantAttributes).every(([key, value]) => {
    if (!value || key === ignoreKey) {
      return true;
    }
    return getVariantAttributeValue(entry, key) === String(value || "").trim();
  });
  return colorMatches && sizeMatches && attributeMatches;
}

const colorOptions = computed(() =>
  [...new Set(
    variantInventory.value
      .filter((entry) => variantEntryMatchesSelections(entry, "color"))
      .map((entry) => String(entry.color || "").trim().toLowerCase())
      .filter(Boolean),
  )]
    .map((value) => ({
      value,
      label: formatProductColorLabel(value),
      inStock: variantInventory.value.some((entry) =>
        String(entry.color || "").trim().toLowerCase() === value
        && variantEntryMatchesSelections(entry, "color")
        && Number(entry.quantity || 0) > 0),
    })),
);

const sizeOptions = computed(() => {
  const activeEntries = variantInventory.value.filter((entry) => variantEntryMatchesSelections(entry, "size"));

  return [...new Set(activeEntries.map((entry) => String(entry.size || "").trim().toUpperCase()).filter(Boolean))]
    .map((value) => ({
      value,
      inStock: activeEntries.some((entry) => entry.size === value && Number(entry.quantity || 0) > 0),
    }));
});

const variantAttributeGroups = computed(() => {
  const keys = [];
  const seenKeys = new Set();
  variantInventory.value.forEach((entry) => {
    const attributes = entry?.attributes && typeof entry.attributes === "object" ? entry.attributes : {};
    Object.keys(attributes).forEach((attributeKey) => {
      if (!attributeKey || attributeKey === "color" || attributeKey === "size" || seenKeys.has(attributeKey)) {
        return;
      }
      seenKeys.add(attributeKey);
      keys.push(attributeKey);
    });
  });

  return keys.map((attributeKey) => {
    const options = [...new Set(
      variantInventory.value
        .filter((entry) => variantEntryMatchesSelections(entry, attributeKey))
        .map((entry) => getVariantAttributeValue(entry, attributeKey))
        .filter(Boolean),
    )].map((value) => ({
      value,
      inStock: variantInventory.value.some((entry) =>
        getVariantAttributeValue(entry, attributeKey) === value
        && variantEntryMatchesSelections(entry, attributeKey)
        && Number(entry.quantity || 0) > 0),
    }));

    return {
      key: attributeKey,
      label: humanizeSlug(attributeKey),
      options,
    };
  }).filter((group) => group.options.length > 0);
});

const selectedVariant = computed(() => {
  if (!variantInventory.value.length) {
    return null;
  }

  if (variantInventory.value.length === 1) {
    return variantInventory.value[0];
  }

  return variantInventory.value.find((entry) => variantEntryMatchesSelections(entry)) || null;
});

const details = computed(() => {
  if (!currentProduct.value) {
    return [];
  }

  return [
    formatCategoryLabel(currentProduct.value.category),
    formatProductTypeLabel(currentProduct.value.productType),
    currentProduct.value.brand ? `Brand: ${currentProduct.value.brand}` : "",
    currentProduct.value.size ? `Madhesia: ${currentProduct.value.size}` : "",
    currentProduct.value.color
      ? `Ngjyra: ${formatProductColorLabel(currentProduct.value.color)}`
      : "",
    currentProduct.value.material ? `Materiali: ${currentProduct.value.material}` : "",
    currentProduct.value.weightValue && currentProduct.value.weightUnit
      ? `Pesha: ${currentProduct.value.weightValue} ${currentProduct.value.weightUnit}`
      : "",
    currentProduct.value.packageAmountValue && currentProduct.value.packageAmountUnit
      ? `Permbajtja: ${currentProduct.value.packageAmountValue}${currentProduct.value.packageAmountUnit}`
      : "",
    currentProduct.value.showStockPublic && Number(currentProduct.value.stockQuantity) > 0
      ? "Ne stok"
      : "",
  ].filter(Boolean);
});

const imageGallery = computed(() => getProductImageGallery(currentProduct.value));
const currentImagePath = computed(
  () => imageGallery.value[currentImageIndex.value] || currentProduct.value?.imagePath || "",
);
const currentPrice = computed(() => Number(currentProduct.value?.price || 0));
const compareAtPrice = computed(() => {
  const rawValue = Number(currentProduct.value?.compareAtPrice ?? currentProduct.value?.originalPrice ?? 0);
  if (!Number.isFinite(rawValue) || rawValue <= currentPrice.value) {
    return null;
  }

  return rawValue;
});
const discountPercent = computed(() => {
  if (!compareAtPrice.value) {
    return 0;
  }

  return Math.max(0, Math.round(((compareAtPrice.value - currentPrice.value) / compareAtPrice.value) * 100));
});
const averageRating = computed(() => {
  const rawValue = Number(currentProduct.value?.averageRating ?? currentProduct.value?.ratingAverage ?? 0);
  if (!Number.isFinite(rawValue) || rawValue <= 0) {
    return 0;
  }

  return Math.max(0, Math.min(5, rawValue));
});
const reviewCount = computed(() => {
  const rawValue = Number(currentProduct.value?.reviewCount || productReviews.value.length || 0);
  if (!Number.isFinite(rawValue) || rawValue <= 0) {
    return 0;
  }

  return Math.max(0, Math.trunc(rawValue));
});
const buyersCount = computed(() => {
  const rawValue = Number(currentProduct.value?.buyersCount || 0);
  if (!Number.isFinite(rawValue) || rawValue <= 0) {
    return 0;
  }

  return Math.max(0, Math.trunc(rawValue));
});
const filledStars = computed(() => {
  if (averageRating.value <= 0) {
    return 0;
  }

  return Math.max(0, Math.min(5, Math.round(averageRating.value)));
});
const shortDescription = computed(() => {
  const rawValue = String(currentProduct.value?.description || "").trim();
  if (!rawValue) {
    return "Produkt i perzgjedhur me fokus te qarte ne cilesi, prezantim dhe blerje te shpejte.";
  }

  if (rawValue.length <= 180) {
    return rawValue;
  }

  return `${rawValue.slice(0, 177).trim()}...`;
});
const selectedVariantStock = computed(() => {
  if (selectedVariant.value) {
    return maxAvailableQuantityForSelection(selectedVariant.value);
  }

  if (currentProduct.value?.requiresVariantSelection) {
    return 0;
  }

  return maxAvailableQuantityForSelection(currentProduct.value || {});
});
const quantityMax = computed(() => Math.max(1, Math.min(12, selectedVariantStock.value || 1)));
const detailTabs = [
  { key: "description", label: "Description" },
  { key: "additional", label: "Additional information" },
  { key: "specification", label: "Specification" },
  { key: "review", label: "Review" },
];
const breadcrumbItems = computed(() => ([
  { label: "Home", to: "/" },
  { label: formatCategoryLabel(currentProduct.value?.category || ""), to: getCategoryUrl(currentProduct.value?.category) },
  { label: currentProduct.value?.title || "Produkt", to: "" },
]));
const specificationItems = computed(() => {
  if (!currentProduct.value) {
    return [];
  }

  return [
    { label: "Kategoria", value: formatCategoryLabel(currentProduct.value.category) || "Marketplace" },
    { label: "Lloji", value: formatProductTypeLabel(currentProduct.value.productType) || "Produkt" },
    { label: "Ngjyra", value: currentProduct.value.color ? formatProductColorLabel(currentProduct.value.color) : "" },
    { label: "Madhesia", value: currentProduct.value.size || "" },
    {
      label: "Permbajtja",
      value: currentProduct.value.packageAmountValue && currentProduct.value.packageAmountUnit
        ? `${currentProduct.value.packageAmountValue}${currentProduct.value.packageAmountUnit}`
        : "",
    },
    { label: "Disponueshmeria", value: isProductAvailable.value ? "Ne stok" : "Pa stok" },
  ].filter((item) => String(item.value || "").trim());
});
const trustHighlights = computed(() => ([
  {
    title: "Seller-backed support",
    description: sellerSupportEmail.value
      ? `Support handled by ${businessName.value || "the verified seller"} at ${sellerSupportEmail.value}.`
      : `Managed directly through ${businessName.value || "the verified seller"} and the Tregio order flow.`,
  },
  {
    title: isProductAvailable.value ? "Fast local delivery" : "Restock confirmation",
    description: isProductAvailable.value
      ? buildShippingSummaryLine(
        "Standard",
        sellerShippingSettings.value?.standardFee,
        sellerShippingSettings.value?.standardEta,
      )
      : "Availability is re-checked before payment is finalized.",
  },
  {
    title: "Protected checkout",
    description: "Cart, payment and order tracking stay inside one marketplace flow.",
  },
  {
    title: "Clear return path",
    description: sellerReturnPolicySummary.value || "Issues can be followed through order history and support.",
  },
  {
    title: "Live catalog signals",
    description: "Ratings, buyer activity and availability update from the live product feed.",
  },
]));
const relatedViewedProducts = computed(() =>
  recentlyViewedProducts.value
    .filter((product) => Number(product?.id || 0) !== Number(currentProduct.value?.id || 0))
    .filter((product) => hasProductAvailableStock(product))
    .slice(0, 4),
);
const productSku = computed(() => {
  const explicitSku = String(
    currentProduct.value?.sku
    || currentProduct.value?.articleNumber
    || currentProduct.value?.article_number
    || "",
  ).trim();
  if (explicitSku) {
    return explicitSku;
  }

  const productId = Number(currentProduct.value?.id || 0);
  return productId > 0 ? `TRG-${String(productId).padStart(6, "0")}` : "TRG-000000";
});
const productBrand = computed(() => {
  const explicitBrand = String(
    currentProduct.value?.brand
    || currentProduct.value?.manufacturer
    || currentProduct.value?.maker
    || "",
  ).trim();
  if (explicitBrand) {
    return explicitBrand;
  }

  const titleParts = String(currentProduct.value?.title || "")
    .trim()
    .split(/\s+/)
    .filter(Boolean);
  if (titleParts.length > 0) {
    return titleParts[0];
  }

  return businessName.value || "Tregio";
});
const productAvailabilityLabel = computed(() => (isProductAvailable.value ? "In Stock" : "Out of stock"));
const packageAmountLabel = computed(() => {
  if (currentProduct.value?.packageAmountValue && currentProduct.value?.packageAmountUnit) {
    return `${currentProduct.value.packageAmountValue}${currentProduct.value.packageAmountUnit}`;
  }

  return "Standard unit";
});
const productWeightLabel = computed(() => {
  const rawValue = Number(currentProduct.value?.weightValue || 0);
  const unit = String(currentProduct.value?.weightUnit || "").trim();
  if (!Number.isFinite(rawValue) || rawValue <= 0 || !unit) {
    return "";
  }

  return `${rawValue} ${unit}`;
});
const optionTypeLabel = computed(() => formatProductTypeLabel(currentProduct.value?.productType || "") || "Standard");
const publishedDateLabel = computed(() => {
  const rawDate = String(currentProduct.value?.createdAt || "").trim();
  if (!rawDate) {
    return "Recently added";
  }

  return formatDateLabel(rawDate);
});
const descriptionParagraphs = computed(() => splitDescriptionText(currentProduct.value?.description || shortDescription.value));
const productHighlightBullets = computed(() => {
  if (!currentProduct.value) {
    return [];
  }

  const items = [
    businessName.value ? `Posted by ${businessName.value} with live marketplace visibility.` : "",
    sellerSupportHours.value ? `Support hours: ${sellerSupportHours.value}.` : "",
    currentProduct.value?.showStockPublic && selectedVariantStock.value > 0
      ? `${selectedVariantStock.value} units are currently ready to order.`
      : "Availability is rechecked before checkout is finalized.",
    reviewCount.value > 0 && averageRating.value > 0
      ? `Rated ${averageRating.value.toFixed(1)}/5 from ${formatCount(reviewCount.value)} customer reviews.`
      : "Fresh product listing ready for first customer feedback.",
    buyersCount.value > 0
      ? `${formatCount(buyersCount.value)} buyers have already purchased this product.`
      : "Newer catalog item with room for first demand signals.",
    optionTypeLabel.value ? `Built for ${optionTypeLabel.value.toLowerCase()} shopping in ${formatCategoryLabel(currentProduct.value.category).toLowerCase()}.` : "",
    packageAmountLabel.value !== "Standard unit"
      ? `Ships as ${packageAmountLabel.value.toLowerCase()} from the seller.`
      : "",
    productWeightLabel.value ? `Listed shipping weight: ${productWeightLabel.value}.` : "",
  ].filter(Boolean);

  return [...new Set(items)].slice(0, 5);
});
const shippingInformation = computed(() => {
  const sellerName = businessName.value || "the seller";
  const shippingSettings = sellerShippingSettings.value;
  const items = [];

  if (shippingSettings?.standardEnabled) {
    items.push({
      label: "Standard shipping",
      value: buildShippingSummaryLine("Standard", shippingSettings.standardFee, shippingSettings.standardEta),
    });
  }

  if (shippingSettings?.expressEnabled) {
    items.push({
      label: "Express shipping",
      value: buildShippingSummaryLine("Express", shippingSettings.expressFee, shippingSettings.expressEta),
    });
  }

  if (shippingSettings?.pickupEnabled) {
    items.push({
      label: "Pickup",
      value: [
        shippingSettings.pickupEta || "Ready for pickup after seller confirmation",
        shippingSettings.pickupAddress || currentProduct.value?.addressLine || "",
        shippingSettings.pickupHours || sellerSupportHours.value,
      ].filter(Boolean).join(" • "),
    });
  }

  items.push({
    label: "Returns",
    value: sellerReturnPolicySummary.value || "Managed from order history after delivery confirmation.",
  });

  items.push({
    label: "Payment",
    value: "Protected checkout with order status tracking and support follow-up.",
  });

  if (shippingSettings?.freeShippingThreshold > 0) {
    items.push({
      label: "Free shipping",
      value: `Free delivery starts from ${formatPrice(shippingSettings.freeShippingThreshold)}.`,
    });
  }

  return items.length > 0
    ? items.slice(0, 5)
    : [
        {
          label: "Courier",
          value: "3 - 5 days, confirmation after seller approval",
        },
        {
          label: "Local shipping",
          value: `Handled by ${sellerName} through the Tregio order workflow.`,
        },
        {
          label: "Returns",
          value: "Managed from order history after delivery confirmation.",
        },
        {
          label: "Payment",
          value: "Protected checkout with order status tracking and support follow-up.",
        },
      ];
});
const isTechProduct = computed(() => matchesTechProduct(currentProduct.value));
const additionalOverviewItems = computed(() => {
  if (!currentProduct.value) {
    return [];
  }

  if (isTechProduct.value) {
    return filterKeyValueItems([
      { label: "Model Name", value: currentProduct.value.title },
      { label: "Brand", value: productBrand.value },
      { label: "GTIN", value: currentProduct.value.gtin },
      { label: "MPN", value: currentProduct.value.mpn },
      { label: "Specific Uses", value: inferProductUseCases(currentProduct.value) },
      { label: "Screen Size", value: currentProduct.value.size || joinOptionLabels(sizeOptions.value, "value") || inferDisplaySizeFromTitle(currentProduct.value.title) },
      { label: "Display", value: inferDisplayLabel(currentProduct.value) },
      { label: "Material", value: currentProduct.value.material },
      { label: "Weight", value: productWeightLabel.value },
      { label: "Key-board", value: inferKeyboardLabel(currentProduct.value) },
      { label: "Human Interface Input", value: inferInterfaceInputLabel(currentProduct.value) },
      { label: "CPU Manufacturer", value: inferCpuManufacturer(currentProduct.value, productBrand.value) },
    ]);
  }

  return filterKeyValueItems([
    { label: "Model Name", value: currentProduct.value.title },
    { label: "Brand", value: productBrand.value },
    { label: "Specific Uses", value: inferProductUseCases(currentProduct.value) },
    { label: "Category", value: formatCategoryLabel(currentProduct.value.category) || "Marketplace" },
    { label: "Product Type", value: optionTypeLabel.value },
    { label: "GTIN", value: currentProduct.value.gtin },
    { label: "MPN", value: currentProduct.value.mpn },
    { label: "Material", value: currentProduct.value.material },
    { label: "Weight", value: productWeightLabel.value },
    { label: "Selected Size", value: currentProduct.value.size || joinOptionLabels(sizeOptions.value, "value") || "Standard" },
    { label: "Primary Color", value: currentProduct.value.color ? formatProductColorLabel(currentProduct.value.color) : joinOptionLabels(colorOptions.value, "label") },
    { label: "Seller", value: businessName.value || "Verified seller" },
  ]);
});
const additionalDetailSections = computed(() => {
  if (!currentProduct.value) {
    return [];
  }

  const sections = [
    {
      title: isTechProduct.value ? "Product Warranty:" : "Seller Warranty:",
      text: sellerReturnPolicySummary.value || buildWarrantyCopy(currentProduct.value, businessName.value),
      lines: [],
    },
    {
      title: "Support & Contact:",
      text: "",
      lines: [
        sellerSupportEmail.value ? `Email: ${sellerSupportEmail.value}` : "",
        sellerSupportHours.value ? `Hours: ${sellerSupportHours.value}` : "",
        sellerWebsiteUrl.value ? `Website: ${sellerWebsiteUrl.value}` : "",
      ].filter(Boolean),
    },
    {
      title: isTechProduct.value ? "Operating System & Fit:" : "Shipping Notes:",
      text: isTechProduct.value ? inferOperatingSystemLabel(currentProduct.value) : "",
      lines: isTechProduct.value
        ? []
        : shippingInformation.value
          .filter((item) => item.label !== "Payment")
          .map((item) => `${item.label}: ${item.value}`),
    },
    {
      title: "Dimensions:",
      text: "",
      lines: buildAdditionalDimensionLines({
        product: currentProduct.value,
        sizeLabel: currentProduct.value.size || joinOptionLabels(sizeOptions.value, "value") || inferDisplaySizeFromTitle(currentProduct.value.title),
        packageLabel: packageAmountLabel.value,
        stockCount: selectedVariantStock.value,
        variantCount: variantInventory.value.length,
      }),
    },
  ];

  return sections.filter((section) => String(section.text || "").trim() || section.lines.length > 0);
});
const additionalHighlights = computed(() => {
  if (!currentProduct.value) {
    return [];
  }

  const items = [
    inferPrimaryHighlight(currentProduct.value),
    currentProduct.value.gtin ? `Barcode / GTIN: ${currentProduct.value.gtin}` : "",
    currentProduct.value.mpn ? `MPN: ${currentProduct.value.mpn}` : "",
    reviewCount.value > 0 && averageRating.value > 0
      ? `${averageRating.value.toFixed(1)} star average from ${formatCount(reviewCount.value)} reviews`
      : "Fresh listing ready for first customer feedback",
    buyersCount.value > 0
      ? `${formatCount(buyersCount.value)} customers already purchased this item`
      : "Prepared for local marketplace orders",
    productWeightLabel.value ? `Ships with listed weight ${productWeightLabel.value}` : "",
    currentProduct.value?.showStockPublic && selectedVariantStock.value > 0
      ? `${selectedVariantStock.value} units currently visible in stock`
      : "Availability is confirmed before checkout completes",
    businessName.value ? `Sold by ${businessName.value} through the Tregio marketplace` : "",
  ].filter(Boolean);

  return [...new Set(items)].slice(0, 5);
});
const specificationColumns = computed(() => {
  if (!currentProduct.value) {
    return [];
  }

  const leftColumn = [];
  const rightColumn = [];
  const sizeLabel = currentProduct.value.size || joinOptionLabels(sizeOptions.value, "value") || inferDisplaySizeFromTitle(currentProduct.value.title);
  const colorLabel = currentProduct.value.color ? formatProductColorLabel(currentProduct.value.color) : joinOptionLabels(colorOptions.value, "label");
  const storageLabel = inferStorageCapacity(currentProduct.value);
  const ramLabel = inferRamCapacity(currentProduct.value);
  const processorLabel = inferProcessorName(currentProduct.value, productBrand.value);
  const coresLabel = inferCoreCount(currentProduct.value, processorLabel);

  if (isTechProduct.value) {
    leftColumn.push(
      createSpecificationGroup("General", [
        { label: "Sales Package", value: inferSalesPackage(currentProduct.value, packageAmountLabel.value) },
        { label: "Model Number", value: inferModelNumber(currentProduct.value, productSku.value) },
        { label: "Part Number", value: productSku.value },
        { label: "Series", value: inferSeriesLabel(currentProduct.value, productBrand.value) },
        { label: "GTIN", value: currentProduct.value.gtin },
        { label: "MPN", value: currentProduct.value.mpn },
        { label: "Color", value: colorLabel || "Standard" },
        { label: "Type", value: inferDeviceTypeLabel(currentProduct.value, optionTypeLabel.value) },
        { label: "Suitable For", value: inferProductUseCases(currentProduct.value) },
        { label: "Material", value: currentProduct.value.material },
        { label: "Battery Backup", value: inferBatteryBackup(currentProduct.value) },
        { label: "Power Supply", value: inferPowerSupply(currentProduct.value) },
        { label: "MS Office Provided", value: inferOfficeIncluded(currentProduct.value) },
      ]),
    );

    leftColumn.push(
      createSpecificationGroup("Display And Audio Features", [
        { label: "Touchscreen", value: inferTouchscreenSupport(currentProduct.value) },
        { label: "Screen Size", value: sizeLabel || "Seller specified" },
        { label: "Screen Resolution", value: inferScreenResolution(currentProduct.value) },
        { label: "Screen Type", value: inferScreenType(currentProduct.value) },
        { label: "Speakers", value: inferSpeakerLabel(currentProduct.value) },
        { label: "Internal Mic", value: inferMicrophoneLabel(currentProduct.value) },
        { label: "Sound Properties", value: inferSoundProperties(currentProduct.value) },
        { label: "Battery Backup", value: inferBatteryBackup(currentProduct.value) },
        { label: "Power Supply", value: inferPowerSupply(currentProduct.value) },
        { label: "MS Office Provided", value: inferOfficeIncluded(currentProduct.value) },
      ]),
    );

    leftColumn.push(
      createSpecificationGroup("Port And Slot Features", [
        { label: "Mic In", value: inferMicInSupport(currentProduct.value) },
        { label: "USB Port", value: inferUsbPorts(currentProduct.value) },
      ]),
    );

    leftColumn.push(
      createSpecificationGroup("Connectivity Features", [
        { label: "Wireless LAN", value: inferWirelessLabel(currentProduct.value) },
        { label: "Bluetooth", value: inferBluetoothLabel(currentProduct.value) },
      ]),
    );

    rightColumn.push(
      createSpecificationGroup("Processor And Memory Features", [
        { label: "Processor Brand", value: inferCpuManufacturer(currentProduct.value, productBrand.value) },
        { label: "Processor Name", value: processorLabel },
        { label: "SSD", value: storageLabel ? "Yes" : "Optional" },
        { label: "SSD Capacity", value: storageLabel || "Seller specified" },
        { label: "RAM", value: ramLabel || "Seller specified" },
        { label: "RAM Type", value: inferRamType(currentProduct.value) },
        { label: "Processor Variant", value: processorLabel },
        { label: "Expandable Memory", value: inferExpandableMemory(currentProduct.value, ramLabel) },
        { label: "Graphic Processor", value: inferGraphicsLabel(currentProduct.value, processorLabel) },
        { label: "Number of Cores", value: coresLabel },
        { label: "Weight", value: productWeightLabel.value },
      ]),
    );

    rightColumn.push(
      createSpecificationGroup("Additional Features", [
        { label: "Disk Drive", value: inferDiskDrive(currentProduct.value, packageAmountLabel.value) },
        { label: "Web Camera", value: inferWebCameraLabel(currentProduct.value) },
        { label: "Keyboard", value: inferKeyboardLabel(currentProduct.value) },
        { label: "Pointer Device", value: inferPointerDevice(currentProduct.value) },
        { label: "Included Software", value: inferIncludedSoftware(currentProduct.value) },
        { label: "Additional Features", value: inferAdditionalFeaturesLabel(currentProduct.value, packageAmountLabel.value, selectedVariantStock.value) },
      ]),
    );

    rightColumn.push(
      createSpecificationGroup("Warranty", [
        { label: "Warranty Summary", value: inferWarrantySummary(currentProduct.value) },
        { label: "Warranty Service Type", value: inferWarrantyServiceType(currentProduct.value) },
        { label: "Covered in Warranty", value: inferWarrantyCoverage(currentProduct.value) },
        { label: "Not Covered in Warranty", value: inferWarrantyExclusion(currentProduct.value) },
        { label: "Domestic Warranty", value: inferDomesticWarranty(currentProduct.value) },
      ]),
    );

    rightColumn.push(
      createSpecificationGroup("Connectivity Features", [
        { label: "Wireless LAN", value: inferWirelessLabel(currentProduct.value) },
        { label: "Bluetooth", value: inferBluetoothLabel(currentProduct.value) },
      ]),
    );
  } else {
    leftColumn.push(
      createSpecificationGroup("General", [
        { label: "Product", value: currentProduct.value.title },
        { label: "Seller", value: businessName.value || "Verified seller" },
        { label: "Brand", value: productBrand.value },
        { label: "GTIN", value: currentProduct.value.gtin },
        { label: "MPN", value: currentProduct.value.mpn },
        { label: "Category", value: formatCategoryLabel(currentProduct.value.category) || "Marketplace" },
        { label: "Type", value: optionTypeLabel.value },
        { label: "Material", value: currentProduct.value.material },
        { label: "Weight", value: productWeightLabel.value },
        { label: "Published", value: publishedDateLabel.value },
      ]),
    );

    leftColumn.push(
      createSpecificationGroup("Package And Variant Details", [
        { label: "Package", value: packageAmountLabel.value },
        { label: "Color", value: colorLabel || "Standard" },
        { label: "Size", value: sizeLabel || "Standard" },
        { label: "Variant Count", value: variantInventory.value.length ? `${variantInventory.value.length}` : "" },
        { label: "Stock", value: selectedVariantStock.value > 0 ? `${selectedVariantStock.value} units ready` : outOfStockMessage.value },
      ]),
    );

    leftColumn.push(
      createSpecificationGroup("Fulfillment", [
        { label: "Availability", value: productAvailabilityLabel.value },
        { label: "Delivery", value: shippingInformation.value[0]?.value || "" },
        { label: "Returns", value: shippingInformation.value.find((item) => item.label === "Returns")?.value || "" },
        { label: "Payment", value: shippingInformation.value.find((item) => item.label === "Payment")?.value || "" },
        { label: "Pickup", value: shippingInformation.value.find((item) => item.label === "Pickup")?.value || "" },
      ]),
    );

    rightColumn.push(
      createSpecificationGroup("Commerce Details", [
        { label: "Current Price", value: formatPrice(currentPrice.value) },
        { label: "Compare At", value: compareAtPrice.value ? formatPrice(compareAtPrice.value) : "" },
        { label: "Discount", value: discountPercent.value > 0 ? `${discountPercent.value}% OFF` : "" },
        { label: "Rating", value: averageRating.value > 0 ? `${averageRating.value.toFixed(1)} / 5` : "No rating yet" },
        { label: "Reviews", value: reviewCount.value > 0 ? `${reviewCount.value}` : "" },
        { label: "Buyers", value: buyersCount.value > 0 ? `${buyersCount.value}` : "" },
      ]),
    );

    rightColumn.push(
      createSpecificationGroup("Seller Support", [
        { label: "Seller Status", value: humanizeSlug(currentProduct.value.businessVerificationStatus || "active") },
        { label: "Support Email", value: sellerSupportEmail.value },
        { label: "Website", value: sellerWebsiteUrl.value },
        { label: "Support Hours", value: sellerSupportHours.value },
        { label: "Stock Visibility", value: currentProduct.value.showStockPublic ? "Visible on product page" : "Visible after confirmation" },
        { label: "Warranty", value: inferWarrantySummary(currentProduct.value) },
        { label: "Published", value: publishedDateLabel.value },
      ]),
    );
  }

  return [
    leftColumn.filter((group) => group.items.length),
    rightColumn.filter((group) => group.items.length),
  ].filter((column) => column.length);
});
const reviewBreakdown = computed(() => buildReviewBreakdown(productReviews.value, averageRating.value, reviewCount.value));
const safeCheckoutBadges = computed(() => ["Visa", "Mastercard", "PayPal", "Apple Pay", "Cash"]);
const recommendationColumns = computed(() => {
  const columns = [];
  const usedIds = new Set();

  for (const section of productRecommendationSections.value) {
    const products = Array.isArray(section?.products)
      ? section.products
        .filter((item) => Number(item?.id || 0) !== Number(currentProduct.value?.id || 0))
        .filter((item) => !usedIds.has(Number(item?.id || 0)))
        .slice(0, 3)
      : [];

    if (!products.length) {
      continue;
    }

    products.forEach((item) => usedIds.add(Number(item?.id || 0)));
    columns.push({
      key: section.key || section.title,
      title: section.title || "Recommended products",
      products,
    });
  }

  if (relatedViewedProducts.value.length > 0 && columns.length < 4) {
    const recentProducts = relatedViewedProducts.value
      .filter((item) => !usedIds.has(Number(item?.id || 0)))
      .slice(0, 3);

    if (recentProducts.length) {
      recentProducts.forEach((item) => usedIds.add(Number(item?.id || 0)));
      columns.push({
        key: "recently-viewed",
        title: "Recently viewed",
        products: recentProducts,
      });
    }
  }

  return columns.slice(0, 4);
});
const recommendationDisplayColumns = computed(() =>
  recommendationColumns.value.map((column, index) => ({
    ...column,
    displayTitle: [
      "Flash Sale Today",
      "Best Sellers",
      "Flash Sale Today",
      "Flash Sale Today",
    ][index] || column.title || "Recommended",
  })),
);
const backTarget = computed(() => {
  const candidate = String(route.query.back || "").trim();
  if (candidate.startsWith("/")) {
    return candidate;
  }

  return getCategoryUrl(currentProduct.value?.category);
});
const shareUrl = computed(() => {
  if (!currentProduct.value) {
    return "";
  }

  const detailPath = getProductDetailUrl(currentProduct.value.id);
  if (typeof window === "undefined") {
    return detailPath;
  }

  return new URL(detailPath, window.location.origin).toString();
});
const publicEngagementItems = computed(() => ([
  { label: "Views", value: formatCount(currentProduct.value?.viewsCount || 0) },
  { label: "Wishlist", value: formatCount(currentProduct.value?.wishlistCount || 0) },
  { label: "Cart", value: formatCount(currentProduct.value?.cartCount || 0) },
  { label: "Share", value: formatCount(currentProduct.value?.shareCount || 0) },
]));
let productRecommendationsRequestId = 0;

function updateProductSeo() {
  if (!currentProduct.value) {
    applyDocumentSeo({
      title: "TREGIO | Produkti",
      description: "Shiko produktet publike, cmimet, stokun dhe checkout-in e sigurt ne TREGIO.",
      canonicalPath: "/produkti",
      image: "/trego-logo.webp?v=20260410",
      jsonLd: [],
    });
    return;
  }

  const detailPath = getProductDetailUrl(currentProduct.value.id);
  const sellerUrl = currentProduct.value.businessProfileId
    ? buildAbsoluteUrl(getBusinessProfileUrl(currentProduct.value.businessProfileId))
    : "";
  const shippingJsonLd = buildOfferShippingDetailsJsonLd(sellerShippingSettings.value);
  const breadcrumbJsonLd = buildBreadcrumbJsonLd([
    { name: "Home", item: "/" },
    { name: formatCategoryLabel(currentProduct.value.category || "Marketplace"), item: getCategoryUrl(currentProduct.value.category) || "/kerko" },
    { name: currentProduct.value.title || "Produkt", item: detailPath },
  ]);
  const productJsonLd = {
    "@context": "https://schema.org",
    "@type": "Product",
    name: String(currentProduct.value.title || "").trim(),
    description: productMetaDescription.value || shortDescription.value,
    sku: productSku.value,
    image: imageGallery.value.map((imagePath) => buildAbsoluteUrl(imagePath)).filter(Boolean),
    brand: {
      "@type": "Brand",
      name: productBrand.value,
    },
    ...(currentProduct.value.gtin ? { gtin: String(currentProduct.value.gtin).trim() } : {}),
    ...(currentProduct.value.mpn ? { mpn: String(currentProduct.value.mpn).trim() } : {}),
    ...(currentProduct.value.material ? { material: String(currentProduct.value.material).trim() } : {}),
    ...(productWeightLabel.value
      ? {
          weight: {
            "@type": "QuantitativeValue",
            value: Number(currentProduct.value.weightValue || 0),
            unitText: String(currentProduct.value.weightUnit || "").trim(),
          },
        }
      : {}),
    category: formatCategoryLabel(currentProduct.value.category || "Marketplace"),
    offers: {
      "@type": "Offer",
      priceCurrency: "EUR",
      price: Number(currentPrice.value || 0).toFixed(2),
      availability: isProductAvailable.value ? "https://schema.org/InStock" : "https://schema.org/OutOfStock",
      itemCondition: "https://schema.org/NewCondition",
      url: buildAbsoluteUrl(detailPath),
      seller: {
        "@type": "Organization",
        name: businessName.value || "TREGIO seller",
        ...(sellerUrl ? { url: sellerUrl } : {}),
      },
      ...(shippingJsonLd.length > 0 ? { shippingDetails: shippingJsonLd } : {}),
      ...(sellerReturnPolicySummary.value
        ? {
            hasMerchantReturnPolicy: {
              "@type": "MerchantReturnPolicy",
              description: sellerReturnPolicySummary.value,
            },
          }
        : {}),
    },
    ...(reviewCount.value > 0 && averageRating.value > 0
      ? {
          aggregateRating: {
            "@type": "AggregateRating",
            ratingValue: Number(averageRating.value || 0).toFixed(1),
            reviewCount: Math.max(1, Number(reviewCount.value || 0)),
          },
        }
      : {}),
  };

  applyDocumentSeo({
    title: `${productMetaTitle.value || currentProduct.value.title} | TREGIO`,
    description: [
      productMetaDescription.value || shortDescription.value,
      businessName.value ? `Shitet nga ${businessName.value}.` : "",
      isProductAvailable.value ? "Ne stok dhe gati per porosi." : "Aktualisht pa stok.",
    ].filter(Boolean).join(" "),
    canonicalPath: detailPath,
    image: currentImagePath.value || currentProduct.value.imagePath || "/trego-logo.webp?v=20260410",
    type: "product",
    jsonLd: [productJsonLd, breadcrumbJsonLd].filter(Boolean),
  });
}

watch(
  () => route.fullPath,
  async () => {
    await bootstrap();
  },
);

onMounted(async () => {
  ensureCompareItemsLoaded();
  recentlyViewedProducts.value = readRecentlyViewedProducts();
  await bootstrap();
});

watch(selectedVariantStock, (nextValue) => {
  const maxAllowed = Math.max(1, Math.min(12, nextValue || 1));
  if (selectedQuantity.value > maxAllowed) {
    selectedQuantity.value = maxAllowed;
  }
});

watch(
  () => currentProduct.value?.id,
  () => {
    activeDetailTab.value = "description";
    showReviewComposer.value = false;
  },
);

watch(
  [currentProduct, currentImagePath, averageRating, reviewCount, currentPrice, isProductAvailable],
  () => {
    updateProductSeo();
  },
  { immediate: true },
);

watch(
  () => appState.catalogRevision,
  async (nextRevision, previousRevision) => {
    if (nextRevision === previousRevision) {
      return;
    }

    await loadProduct();
  },
);

async function bootstrap() {
  try {
    await loadProduct();
    markRouteReady();
    void ensureSessionLoaded()
      .then(() => refreshCollectionState())
      .catch((error) => {
        console.error(error);
      });
  } finally {
    if (!currentProduct.value) {
      markRouteReady();
    }
  }
}

async function refreshCollectionState() {
  if (!appState.user) {
    wishlistIds.value = [];
    cartIds.value = [];
    return;
  }

  const [wishlistItems, cartItems] = await Promise.all([
    fetchProtectedCollection("/api/wishlist"),
    fetchProtectedCollection("/api/cart"),
  ]);

  wishlistIds.value = wishlistItems.map((item) => item.id);
  cartIds.value = cartItems.map((item) => item.productId || item.id);
  setCartItems(cartItems);
}

async function loadProduct() {
  const productId = Number(route.query.id || route.query.productId || "");
  if (!Number.isFinite(productId) || productId <= 0) {
    currentProduct.value = null;
    ui.message = "Produkti nuk u gjet.";
    ui.type = "error";
    return;
  }

  const { response, data } = await requestJson(
    `/api/product?id=${encodeURIComponent(productId)}`,
    {},
    { cacheTtlMs: 20000 },
  );
  if (!response.ok || !data?.ok || !data.product) {
    currentProduct.value = null;
    ui.message = resolveApiMessage(data, "Produkti nuk u gjet.");
    ui.type = "error";
    return;
  }

  currentProduct.value = data.product;
  recentlyViewedProducts.value = rememberRecentlyViewedProduct(currentProduct.value);
  trackProductView(currentProduct.value);
  currentImageIndex.value = 0;
  selectedQuantity.value = 1;
  initializeVariantSelection();
  productReviews.value = [];
  canSubmitReview.value = false;
  void loadProductRecommendations(productId);
  void loadProductReviews(productId);
  ui.message = "";
  ui.type = "";
}

async function loadProductRecommendations(productId) {
  const requestId = ++productRecommendationsRequestId;
  const payload = await fetchProductRecommendations(productId, 4);
  if (requestId !== productRecommendationsRequestId) {
    return;
  }

  productRecommendationSections.value = Array.isArray(payload.sections) ? payload.sections : [];
}

async function loadProductReviews(productId) {
  const { response, data } = await requestJson(
    `/api/product/reviews?id=${encodeURIComponent(productId)}`,
    {},
    { cacheTtlMs: 20000 },
  );
  if (!response.ok || !data?.ok) {
    productReviews.value = [];
    canSubmitReview.value = false;
    return;
  }

  productReviews.value = Array.isArray(data.reviews) ? data.reviews : [];
  canSubmitReview.value = Boolean(data.canSubmitReview);
}

function initializeVariantSelection() {
  selectedColor.value = "";
  selectedSize.value = "";
  Object.keys(selectedVariantAttributes).forEach((key) => {
    delete selectedVariantAttributes[key];
  });

  if (!variantInventory.value.length) {
    return;
  }

  if (variantInventory.value.length === 1) {
    selectedColor.value = String(variantInventory.value[0].color || "").trim().toLowerCase();
    selectedSize.value = String(variantInventory.value[0].size || "").trim().toUpperCase();
    Object.entries(variantInventory.value[0].attributes || {}).forEach(([key, value]) => {
      if (key !== "color" && key !== "size" && String(value || "").trim()) {
        selectedVariantAttributes[key] = String(value || "").trim();
      }
    });
    return;
  }

  if (colorOptions.value.length === 1) {
    selectedColor.value = colorOptions.value[0].value;
  }

  if (sizeOptions.value.length === 1) {
    selectedSize.value = sizeOptions.value[0].value;
  }

  variantAttributeGroups.value.forEach((group) => {
    if (group.options.length === 1) {
      selectedVariantAttributes[group.key] = group.options[0].value;
    }
  });
}

function clearInvalidVariantSelections(preferredKey = "") {
  const selectionKeys = [
    ...Object.keys(selectedVariantAttributes).filter((key) => key && key !== preferredKey),
    "size",
    "color",
  ];

  for (const key of selectionKeys) {
    if (variantInventory.value.some((entry) => variantEntryMatchesSelections(entry))) {
      return;
    }

    if (key === "color") {
      if (preferredKey !== "color" && selectedColor.value) {
        selectedColor.value = "";
      }
      continue;
    }

    if (key === "size") {
      if (preferredKey !== "size" && selectedSize.value) {
        selectedSize.value = "";
      }
      continue;
    }

    if (selectedVariantAttributes[key]) {
      delete selectedVariantAttributes[key];
    }
  }
}

function handleCompareProduct() {
  if (!currentProduct.value) {
    return;
  }

  toggleComparedProduct(currentProduct.value);
}

function isComparedItem(productId) {
  return compareState.items.some((item) => Number(item.id || item.productId || 0) === Number(productId || 0));
}

function chooseColor(colorValue) {
  selectedColor.value = colorValue;
  clearInvalidVariantSelections("color");
}

function chooseSize(sizeValue) {
  selectedSize.value = sizeValue;
  clearInvalidVariantSelections("size");
}

function chooseVariantAttribute(attributeKey, attributeValue) {
  selectedVariantAttributes[attributeKey] = attributeValue;
  clearInvalidVariantSelections(attributeKey);
}

async function handleWishlist() {
  if (!currentProduct.value) {
    return;
  }

  if (!appState.user) {
    ui.message = "Duhet te kyçesh ose te krijosh llogari para se te perdoresh wishlist ose cart.";
    ui.type = "error";
    return;
  }

  const productId = currentProduct.value.id;
  const hadItem = wishlistIds.value.includes(productId);
  wishlistIds.value = hadItem
    ? wishlistIds.value.filter((id) => id !== productId)
    : [...wishlistIds.value, productId];

  const { response, data } = await requestJson("/api/wishlist/toggle", {
    method: "POST",
    body: JSON.stringify({ productId }),
  });

  if (!response.ok || !data?.ok) {
    wishlistIds.value = hadItem
      ? [...wishlistIds.value, productId]
      : wishlistIds.value.filter((id) => id !== productId);
    ui.message = resolveApiMessage(data, "Wishlist nuk u perditesua.");
    ui.type = "error";
    return;
  }

  wishlistIds.value = Array.isArray(data.items) ? data.items.map((item) => item.id) : [];
  ui.message = data.message || "Wishlist u perditesua.";
  ui.type = "success";
  if (!hadItem) {
    window.dispatchEvent(new CustomEvent("trego:toast", {
      detail: { message: "Artikulli eshte shtuar ne wishlist." },
    }));
  }
}

async function handleCart() {
  await addCurrentProductToCart();
}

function findRecommendationProduct(productId) {
  const productPools = [
    ...productRecommendationSections.value.flatMap((section) => section.products || []),
    ...relatedViewedProducts.value,
  ];
  return productPools.find((item) => Number(item?.id || 0) === Number(productId)) || null;
}

async function handleRecommendationWishlist(productId) {
  const targetProduct = findRecommendationProduct(productId);
  if (!targetProduct) {
    return;
  }

  if (!appState.user) {
    ui.message = "Duhet te kyçesh ose te krijosh llogari para se te perdoresh wishlist ose cart.";
    ui.type = "error";
    return;
  }

  const hadItem = wishlistIds.value.includes(productId);
  wishlistIds.value = hadItem
    ? wishlistIds.value.filter((id) => id !== productId)
    : [...wishlistIds.value, productId];

  const { response, data } = await requestJson("/api/wishlist/toggle", {
    method: "POST",
    body: JSON.stringify({ productId }),
  });

  if (!response.ok || !data?.ok) {
    wishlistIds.value = hadItem
      ? [...wishlistIds.value, productId]
      : wishlistIds.value.filter((id) => id !== productId);
    ui.message = resolveApiMessage(data, "Wishlist nuk u perditesua.");
    ui.type = "error";
    return;
  }

  wishlistIds.value = Array.isArray(data.items) ? data.items.map((item) => item.id) : [];
  ui.message = data.message || "Wishlist u perditesua.";
  ui.type = "success";
}

async function handleRecommendationCart(productId) {
  const targetProduct = findRecommendationProduct(productId);
  if (!targetProduct) {
    return;
  }

  if (!appState.user) {
    ui.message = "Duhet te kyçesh ose te krijosh llogari para se te perdoresh wishlist ose cart.";
    ui.type = "error";
    return;
  }

  if (targetProduct.requiresVariantSelection) {
    await router.push(getProductDetailUrl(productId, route.fullPath));
    return;
  }

  if (!cartIds.value.includes(productId)) {
    cartIds.value = [...cartIds.value, productId];
  }

  const { response, data } = await requestJson("/api/cart/add", {
    method: "POST",
    body: JSON.stringify({ productId, quantity: 1 }),
  });

  if (!response.ok || !data?.ok) {
    cartIds.value = cartIds.value.filter((id) => id !== productId);
    ui.message = resolveApiMessage(data, "Shporta nuk u perditesua.");
    ui.type = "error";
    return;
  }

  const items = Array.isArray(data.items) ? data.items : [];
  cartIds.value = items.map((item) => item.productId || item.id);
  setCartItems(items);
  ui.message = data.message || "Produkti u shtua ne shporte.";
  ui.type = "success";
}

async function handleBuyNow() {
  const added = await addCurrentProductToCart({ goToCart: true });
  if (!added) {
    return;
  }
}

function setCurrentImage(index) {
  if (index < 0 || index >= imageGallery.value.length) {
    return;
  }

  currentImageIndex.value = index;
}

function maxAvailableQuantityForSelection(target) {
  const rawValue = Number(target?.quantity ?? target?.stockQuantity ?? 0);
  if (!Number.isFinite(rawValue) || rawValue <= 0) {
    return 0;
  }

  return Math.max(0, Math.trunc(rawValue));
}

function decrementQuantity() {
  selectedQuantity.value = Math.max(1, selectedQuantity.value - 1);
}

function incrementQuantity() {
  selectedQuantity.value = Math.min(quantityMax.value, selectedQuantity.value + 1);
}

async function addCurrentProductToCart(options = {}) {
  if (!currentProduct.value) {
    return false;
  }

  if (!appState.user) {
    ui.message = "Duhet te kyçesh ose te krijosh llogari para se te perdoresh wishlist ose cart.";
    ui.type = "error";
    return false;
  }

  if (!isProductAvailable.value) {
    ui.message = outOfStockMessage.value;
    ui.type = "error";
    return false;
  }

  const productId = currentProduct.value.id;
  if (currentProduct.value.requiresVariantSelection && !selectedVariant.value) {
    ui.message = "Zgjidh variantin e produktit para se ta shtosh ne cart.";
    ui.type = "error";
    return false;
  }

  if (selectedVariant.value && Number(selectedVariant.value.quantity || 0) <= 0) {
    ui.message = "Na vjen keq, varianti i zgjedhur nuk eshte me ne stok.";
    ui.type = "error";
    return false;
  }

  if (!cartIds.value.includes(productId)) {
    cartIds.value = [...cartIds.value, productId];
  }

  const { response, data } = await requestJson("/api/cart/add", {
    method: "POST",
    body: JSON.stringify({
      productId,
      variantKey: selectedVariant.value?.key || "",
      selectedSize: selectedVariant.value?.size || selectedSize.value,
      selectedColor: selectedVariant.value?.color || selectedColor.value,
      quantity: selectedQuantity.value,
    }),
  });

  if (!response.ok || !data?.ok) {
    cartIds.value = cartIds.value.filter((id) => id !== productId);
    ui.message = resolveApiMessage(data, "Shporta nuk u perditesua.");
    ui.type = "error";
    return false;
  }

  const items = Array.isArray(data.items) ? data.items : [];
  cartIds.value = items.map((item) => item.productId || item.id);
  setCartItems(items);
  trackAddToCart(currentProduct.value, { quantity: selectedQuantity.value });
  ui.message = data.message || "Produkti u shtua ne shporte.";
  ui.type = "success";
  if (options.goToCart) {
    await router.push("/cart");
  }
  return true;
}

async function handleSubmitReview() {
  if (!currentProduct.value || reviewBusy.value) {
    return;
  }

  if (!appState.user) {
    ui.message = "Duhet te kyçesh per te lene review.";
    ui.type = "error";
    return;
  }

  reviewBusy.value = true;
  try {
    const { response, data } = await requestJson("/api/product/reviews", {
      method: "POST",
      body: JSON.stringify({
        productId: currentProduct.value.id,
        rating: reviewForm.rating,
        title: reviewForm.title,
        body: reviewForm.body,
      }),
    });

    if (!response.ok || !data?.ok) {
      ui.message = resolveApiMessage(data, "Review nuk u ruajt.");
      ui.type = "error";
      return;
    }

    reviewForm.rating = 5;
    reviewForm.title = "";
    reviewForm.body = "";
    ui.message = data.message || "Review u ruajt.";
    ui.type = "success";
    await loadProduct();
  } finally {
    reviewBusy.value = false;
  }
}

async function handleReportProduct() {
  if (!currentProduct.value) {
    return;
  }

  if (!appState.user) {
    ui.message = "Duhet te kyçesh per te raportuar produktin.";
    ui.type = "error";
    return;
  }

  const reason = window.prompt("Shkruaje shkurt arsyen e raportimit:");
  if (!reason || !String(reason).trim()) {
    return;
  }

  const { response, data } = await requestJson("/api/reports", {
    method: "POST",
    body: JSON.stringify({
      targetType: "product",
      targetId: currentProduct.value.id,
      targetLabel: currentProduct.value.title,
      reportedUserId: currentProduct.value.createdByUserId,
      businessUserId: currentProduct.value.createdByUserId,
      reason,
    }),
  });

  if (!response.ok || !data?.ok) {
    ui.message = resolveApiMessage(data, "Raportimi nuk u dergua.");
    ui.type = "error";
    return;
  }

  ui.message = data.message || "Raportimi u dergua.";
  ui.type = "success";
}

function syncCurrentProductMetrics(metrics = {}) {
  if (!currentProduct.value || !metrics || typeof metrics !== "object") {
    return;
  }

  currentProduct.value = {
    ...currentProduct.value,
    ...metrics,
  };
}

async function handleShareProduct() {
  if (!currentProduct.value || !shareUrl.value) {
    return;
  }

  const sharePayload = {
    title: currentProduct.value.title,
    text: `${currentProduct.value.title} • ${formatPrice(currentProduct.value.price)}`,
    url: shareUrl.value,
  };

  try {
    if (typeof navigator !== "undefined" && typeof navigator.share === "function") {
      await navigator.share(sharePayload);
      ui.message = "Produkti u nda me sukses.";
    } else if (typeof navigator !== "undefined" && navigator.clipboard?.writeText) {
      await navigator.clipboard.writeText(shareUrl.value);
      ui.message = "Linku i produktit u kopjua.";
    } else {
      window.prompt("Kopjo linkun e produktit:", shareUrl.value);
      ui.message = "Linku i produktit eshte gati per share.";
    }

    ui.type = "success";
    const { response, data } = await trackProductShare(currentProduct.value.id);
    if (response.ok && data?.ok && data.metrics) {
      syncCurrentProductMetrics(data.metrics);
    }
  } catch (error) {
    if (error?.name === "AbortError") {
      return;
    }

    console.error(error);
    ui.message = "Produkti nuk u nda. Provoje perseri.";
    ui.type = "error";
  }
}

function nextImage() {
  if (imageGallery.value.length <= 1) {
    return;
  }

  currentImageIndex.value = (currentImageIndex.value + 1) % imageGallery.value.length;
}

function previousImage() {
  if (imageGallery.value.length <= 1) {
    return;
  }

  currentImageIndex.value = (currentImageIndex.value - 1 + imageGallery.value.length) % imageGallery.value.length;
}

function splitDescriptionText(rawValue) {
  const normalized = String(rawValue || "").trim();
  if (!normalized) {
    return [
      "This product is presented through Tregio with a clean buying flow, verified seller context and clear next actions for checkout.",
    ];
  }

  const paragraphParts = normalized
    .split(/\n+/)
    .map((part) => part.trim())
    .filter(Boolean);
  if (paragraphParts.length > 1) {
    return paragraphParts;
  }

  const sentenceParts = normalized.match(/[^.!?]+[.!?]?/g)?.map((part) => part.trim()).filter(Boolean) || [normalized];
  const chunks = [];
  while (sentenceParts.length) {
    chunks.push(sentenceParts.splice(0, 2).join(" "));
  }
  return chunks;
}

function filterKeyValueItems(items) {
  return items.filter((item) => String(item?.value || "").trim());
}

function createSpecificationGroup(title, items) {
  return {
    title,
    items: filterKeyValueItems(items),
  };
}

function joinOptionLabels(options, fieldName) {
  if (!Array.isArray(options) || !options.length) {
    return "";
  }

  return options
    .map((option) => String(option?.[fieldName] || "").trim())
    .filter(Boolean)
    .join(", ");
}

function humanizeSlug(value) {
  const normalized = String(value || "").trim().replace(/[_-]+/g, " ");
  if (!normalized) {
    return "";
  }

  return normalized
    .split(/\s+/)
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(" ");
}

function normalizeShippingSettings(rawValue) {
  if (!rawValue || typeof rawValue !== "object") {
    return null;
  }

  const toNumber = (value) => {
    const numericValue = Number(value);
    return Number.isFinite(numericValue) ? numericValue : 0;
  };

  return {
    standardEnabled: Boolean(rawValue.standardEnabled),
    standardFee: toNumber(rawValue.standardFee),
    standardEta: String(rawValue.standardEta || "").trim(),
    expressEnabled: Boolean(rawValue.expressEnabled),
    expressFee: toNumber(rawValue.expressFee),
    expressEta: String(rawValue.expressEta || "").trim(),
    pickupEnabled: Boolean(rawValue.pickupEnabled),
    pickupEta: String(rawValue.pickupEta || "").trim(),
    pickupAddress: String(rawValue.pickupAddress || "").trim(),
    pickupHours: String(rawValue.pickupHours || "").trim(),
    freeShippingThreshold: toNumber(rawValue.freeShippingThreshold),
    halfOffThreshold: toNumber(rawValue.halfOffThreshold),
    cityRates: Array.isArray(rawValue.cityRates)
      ? rawValue.cityRates
        .map((entry) => ({
          city: String(entry?.city || "").trim(),
          surcharge: toNumber(entry?.surcharge),
        }))
        .filter((entry) => entry.city)
      : [],
  };
}

function buildShippingSummaryLine(label, fee, eta) {
  const parts = [label];
  const numericFee = Number(fee);
  if (Number.isFinite(numericFee) && numericFee >= 0) {
    parts.push(numericFee === 0 ? "free shipping" : `${formatPrice(numericFee)} shipping`);
  }
  if (String(eta || "").trim()) {
    parts.push(String(eta || "").trim());
  }
  return parts.join(" • ");
}

function extractTransitDays(rawValue, fallbackMin = 2, fallbackMax = 4) {
  const matches = String(rawValue || "").match(/\d+/g)?.map((value) => Number(value)).filter(Number.isFinite) || [];
  if (matches.length >= 2) {
    return {
      minValue: Math.min(matches[0], matches[1]),
      maxValue: Math.max(matches[0], matches[1]),
    };
  }
  if (matches.length === 1) {
    return {
      minValue: matches[0],
      maxValue: matches[0],
    };
  }

  return {
    minValue: fallbackMin,
    maxValue: fallbackMax,
  };
}

function buildOfferShippingDetailsJsonLd(settings) {
  if (!settings) {
    return [];
  }

  const details = [];
  const pushShippingDetail = (enabled, fee, eta, fallbackMin, fallbackMax) => {
    if (!enabled) {
      return;
    }

    const transitWindow = extractTransitDays(eta, fallbackMin, fallbackMax);
    details.push({
      "@type": "OfferShippingDetails",
      shippingRate: {
        "@type": "MonetaryAmount",
        value: Number.isFinite(Number(fee)) ? Number(fee) : 0,
        currency: "EUR",
      },
      deliveryTime: {
        "@type": "ShippingDeliveryTime",
        transitTime: {
          "@type": "QuantitativeValue",
          minValue: transitWindow.minValue,
          maxValue: transitWindow.maxValue,
          unitCode: "DAY",
        },
      },
    });
  };

  pushShippingDetail(settings.standardEnabled, settings.standardFee, settings.standardEta, 2, 4);
  pushShippingDetail(settings.expressEnabled, settings.expressFee, settings.expressEta, 1, 2);
  return details;
}

function buildReviewBreakdown(reviews, average, totalCount) {
  const normalizedReviews = Array.isArray(reviews) ? reviews : [];
  const actualTotal = normalizedReviews.length;
  const desiredTotal = Math.max(actualTotal, Number(totalCount || 0));
  const actualCounts = {
    5: 0,
    4: 0,
    3: 0,
    2: 0,
    1: 0,
  };

  normalizedReviews.forEach((review) => {
    const star = Math.max(1, Math.min(5, Math.round(Number(review?.rating || 0))));
    actualCounts[star] += 1;
  });

  if (desiredTotal > actualTotal && desiredTotal > 0) {
    const estimatedCounts = estimateRatingCounts(Number(average || 0), desiredTotal - actualTotal);
    Object.keys(actualCounts).forEach((key) => {
      actualCounts[key] += estimatedCounts[key] || 0;
    });
  }

  const finalTotal = Object.values(actualCounts).reduce((sum, value) => sum + value, 0);
  return [5, 4, 3, 2, 1].map((star) => ({
    star,
    count: actualCounts[star],
    percentage: finalTotal > 0 ? Math.round((actualCounts[star] / finalTotal) * 100) : 0,
  }));
}

function estimateRatingCounts(average, total) {
  const emptyCounts = { 5: 0, 4: 0, 3: 0, 2: 0, 1: 0 };
  if (total <= 0) {
    return emptyCounts;
  }

  const clampedAverage = Math.max(0, Math.min(5, Number(average || 0)));
  const weights = {
    5: Math.max(0.1, (clampedAverage - 2.8) * 1.2),
    4: Math.max(0.08, 1.15 - Math.abs(clampedAverage - 4.1)),
    3: Math.max(0.06, 0.85 - Math.abs(clampedAverage - 3.1)),
    2: Math.max(0.03, 0.65 - Math.abs(clampedAverage - 2.0)),
    1: Math.max(0.02, 0.55 - Math.abs(clampedAverage - 1.0)),
  };
  const totalWeight = Object.values(weights).reduce((sum, value) => sum + value, 0) || 1;
  const counts = { ...emptyCounts };

  Object.keys(weights).forEach((key) => {
    counts[key] = Math.round((weights[key] / totalWeight) * total);
  });

  let allocated = Object.values(counts).reduce((sum, value) => sum + value, 0);
  const preferredKey = clampedAverage >= 4.2 ? 5 : clampedAverage >= 3.4 ? 4 : clampedAverage >= 2.6 ? 3 : clampedAverage >= 1.8 ? 2 : 1;

  while (allocated < total) {
    counts[preferredKey] += 1;
    allocated += 1;
  }

  while (allocated > total) {
    const keyToReduce = [1, 2, 3, 4, 5].find((key) => counts[key] > 0 && key !== preferredKey)
      || preferredKey;
    counts[keyToReduce] -= 1;
    allocated -= 1;
  }

  return counts;
}

function getProductAverageRating(product) {
  const rawValue = Number(product?.averageRating ?? product?.ratingAverage ?? 0);
  if (!Number.isFinite(rawValue) || rawValue <= 0) {
    return 0;
  }

  return Math.max(0, Math.min(5, rawValue));
}

function getProductFilledStars(product) {
  const averageValue = getProductAverageRating(product);
  if (averageValue <= 0) {
    return 0;
  }

  return Math.max(0, Math.min(5, Math.round(averageValue)));
}

function getProductReviewCount(product) {
  const rawValue = Number(product?.reviewCount ?? 0);
  if (!Number.isFinite(rawValue) || rawValue <= 0) {
    return 0;
  }

  return Math.max(0, Math.trunc(rawValue));
}

function getProductBusinessName(product) {
  return String(product?.businessName || "").trim() || "Verified seller";
}

function getColorSwatchStyle(colorValue) {
  const normalized = String(colorValue || "").trim().toLowerCase();
  const palette = {
    black: "#111827",
    white: "#f8fafc",
    gray: "#9ca3af",
    grey: "#9ca3af",
    silver: "#cbd5e1",
    blue: "#3b82f6",
    navy: "#1e3a8a",
    red: "#ef4444",
    green: "#22c55e",
    yellow: "#facc15",
    orange: "#fb923c",
    purple: "#8b5cf6",
    pink: "#ec4899",
    brown: "#8b5e3c",
    beige: "#d6c2a1",
    cream: "#f8f1d1",
    gold: "#f59e0b",
    kuqe: "#ef4444",
    kalter: "#3b82f6",
    kaltër: "#3b82f6",
    zezë: "#111827",
    zeze: "#111827",
    bardhë: "#f8fafc",
    bardhe: "#f8fafc",
    hirtë: "#9ca3af",
    hirte: "#9ca3af",
    gjelbër: "#22c55e",
    gjelber: "#22c55e",
    verdhë: "#facc15",
    verdhe: "#facc15",
    portokalli: "#fb923c",
    vjollcë: "#8b5cf6",
    vjollce: "#8b5cf6",
    rozë: "#ec4899",
    roze: "#ec4899",
    kafe: "#8b5e3c",
  };

  return {
    "--swatch-color": palette[normalized] || "#d1d5db",
  };
}

function matchesTechProduct(product) {
  const normalized = [
    product?.title,
    product?.productType,
    product?.category,
  ]
    .map((value) => String(value || "").trim().toLowerCase())
    .join(" ");

  return /(macbook|laptop|notebook|iphone|ipad|android|galaxy|pixel|xiaomi|monitor|tv|camera|console|gaming|keyboard|mouse|printer|tablet|headphone|earbud|speaker|electronics|computer)/.test(normalized);
}

function inferProductUseCases(product) {
  const normalized = [
    product?.title,
    product?.productType,
    product?.category,
  ]
    .map((value) => String(value || "").trim().toLowerCase())
    .join(" ");

  if (/(macbook|laptop|notebook|computer|monitor|printer)/.test(normalized)) {
    return "Work, Study, Business";
  }
  if (/(iphone|ipad|android|galaxy|pixel|xiaomi|phone|tablet)/.test(normalized)) {
    return "Personal, Gaming, Business";
  }
  if (/(headphone|earbud|speaker|audio)/.test(normalized)) {
    return "Music, Calls, Daily Use";
  }
  if (/(camera|console|gaming)/.test(normalized)) {
    return "Entertainment, Creative Use, Home";
  }
  if (/(fashion|shirt|dress|pants|jacket|shoe|apparel|tshirt)/.test(normalized)) {
    return "Daily Wear, Casual Styling, Seasonal Use";
  }
  if (/(beauty|cream|cosmetic|skin|care|perfume)/.test(normalized)) {
    return "Personal Care, Daily Routine, Travel";
  }
  if (/(table|chair|home|furniture|kitchen|decor)/.test(normalized)) {
    return "Home, Interior, Everyday Use";
  }

  return "Everyday Use, Marketplace Orders, Local Delivery";
}

function inferDisplaySizeFromTitle(title) {
  const match = String(title || "").match(/(\d{1,2}(?:\.\d)?)\s?(?:inch|inches|")/i);
  if (!match) {
    return "";
  }

  return `${match[1]} Inches`;
}

function inferDisplayLabel(product) {
  const normalized = [
    product?.title,
    product?.productType,
    product?.category,
  ]
    .map((value) => String(value || "").trim().toLowerCase())
    .join(" ");

  if (/retina/.test(normalized)) {
    return "Liquid Retina display";
  }
  if (/oled/.test(normalized)) {
    return "OLED display";
  }
  if (/led/.test(normalized)) {
    return "LED display";
  }
  if (/(phone|tablet)/.test(normalized)) {
    return "Touch display";
  }
  if (/(monitor|tv|laptop|macbook)/.test(normalized)) {
    return "Wide color display";
  }

  return "Seller specified display";
}

function inferKeyboardLabel(product) {
  const normalized = [
    product?.title,
    product?.productType,
  ]
    .map((value) => String(value || "").trim().toLowerCase())
    .join(" ");

  if (/(macbook|laptop|keyboard)/.test(normalized)) {
    return "Integrated keyboard";
  }
  if (/(phone|tablet)/.test(normalized)) {
    return "Touch and button controls";
  }
  if (/(headphone|speaker|camera|console)/.test(normalized)) {
    return "Built-in controls";
  }

  return "Standard controls";
}

function inferInterfaceInputLabel(product) {
  const normalized = [
    product?.title,
    product?.productType,
  ]
    .map((value) => String(value || "").trim().toLowerCase())
    .join(" ");

  if (/(macbook|laptop)/.test(normalized)) {
    return "Keyboard / Trackpad";
  }
  if (/mouse/.test(normalized)) {
    return "Pointing device";
  }
  if (/(phone|tablet)/.test(normalized)) {
    return "Touchscreen";
  }
  if (/(headphone|speaker|camera)/.test(normalized)) {
    return "Touch / Button input";
  }

  return "Standard input";
}

function inferCpuManufacturer(product, fallbackBrand) {
  const normalized = [
    product?.title,
    product?.productType,
  ]
    .map((value) => String(value || "").trim().toLowerCase())
    .join(" ");

  if (/(apple|m1|m2|m3|macbook|iphone|ipad)/.test(normalized)) {
    return "Apple";
  }
  if (/intel/.test(normalized)) {
    return "Intel";
  }
  if (/amd/.test(normalized)) {
    return "AMD";
  }
  if (/(snapdragon|qualcomm)/.test(normalized)) {
    return "Qualcomm";
  }

  return fallbackBrand || "Not specified";
}

function buildWarrantyCopy(product, sellerName) {
  const verifiedStatus = String(product?.businessVerificationStatus || "").trim().toLowerCase();
  if (verifiedStatus === "verified") {
    return `Warranty information and after-sale support are managed by ${sellerName || "the seller"} through your order details and support flow.`;
  }

  return `Warranty information is confirmed directly by ${sellerName || "the seller"} after order review.`;
}

function inferOperatingSystemLabel(product) {
  const normalized = [
    product?.title,
    product?.productType,
  ]
    .map((value) => String(value || "").trim().toLowerCase())
    .join(" ");

  if (/(macbook|iphone|ipad|apple)/.test(normalized)) {
    return "Mac OS / iOS ecosystem";
  }
  if (/(android|galaxy|pixel|xiaomi|redmi)/.test(normalized)) {
    return "Android";
  }
  if (/(laptop|desktop|monitor|pc)/.test(normalized)) {
    return "Windows / PC compatible";
  }
  if (/(headphone|speaker|camera|printer|console)/.test(normalized)) {
    return "Device compatible";
  }

  return "Specified by seller on request";
}

function inferProductCareLabel(product) {
  const normalized = [
    product?.title,
    product?.productType,
    product?.category,
  ]
    .map((value) => String(value || "").trim().toLowerCase())
    .join(" ");

  if (/(fashion|shirt|dress|pants|jacket|shoe|apparel|tshirt)/.test(normalized)) {
    return "Care details vary by fabric and seller instructions.";
  }
  if (/(beauty|cream|cosmetic|skin|care|perfume)/.test(normalized)) {
    return "Store in a cool, dry place and follow the listed usage guidance.";
  }

  return "Handling and care guidance is confirmed by the seller when needed.";
}

function buildAdditionalDimensionLines({ product, sizeLabel, packageLabel, stockCount, variantCount }) {
  const lines = [];
  if (sizeLabel) {
    lines.push(`Size: ${sizeLabel}`);
  }
  if (packageLabel && packageLabel !== "Standard unit") {
    lines.push(`Package: ${packageLabel}`);
  }
  if (variantCount > 1) {
    lines.push(`Variants: ${variantCount}`);
  }
  if (stockCount > 0) {
    lines.push(`Stock: ${stockCount} units`);
  }

  if (!lines.length) {
    lines.push(`Published: ${formatDateLabel(String(product?.createdAt || "")) || "Recently added"}`);
  }

  return lines.slice(0, 4);
}

function inferPrimaryHighlight(product) {
  const normalized = [
    product?.title,
    product?.productType,
    product?.category,
  ]
    .map((value) => String(value || "").trim().toLowerCase())
    .join(" ");

  if (/(macbook|laptop|notebook)/.test(normalized)) {
    return "Portable and business-ready performance for work and study";
  }
  if (/(phone|iphone|android|galaxy|pixel|xiaomi)/.test(normalized)) {
    return "Smartphone-ready daily performance with quick access to essentials";
  }
  if (/(headphone|earbud|speaker|audio)/.test(normalized)) {
    return "Portable audio setup built for music, calls and everyday use";
  }
  if (/(fashion|shirt|dress|pants|jacket|shoe|apparel|tshirt)/.test(normalized)) {
    return "Easy styling item suited for daily wear and seasonal looks";
  }

  return "Marketplace product designed for local shopping and quick checkout";
}

function inferSalesPackage(product, packageLabel) {
  const title = String(product?.title || "Product").trim();
  if (matchesTechProduct(product)) {
    return `${title}, ${packageLabel !== "Standard unit" ? `${packageLabel} package, ` : ""}User Guide, Warranty Documents`;
  }

  return `${title}, seller packaging, care guidance, order support`;
}

function inferModelNumber(product, sku) {
  const explicit = String(product?.modelNumber || product?.model_number || "").trim();
  if (explicit) {
    return explicit;
  }

  const compactSku = String(sku || "").replace(/\s+/g, "").trim();
  if (compactSku) {
    return compactSku;
  }

  return `MDL-${String(product?.id || 0).padStart(4, "0")}`;
}

function inferSeriesLabel(product, brand) {
  const title = String(product?.title || "").trim();
  const patterns = [
    /MacBook Pro/i,
    /MacBook Air/i,
    /iPhone [\w\s+.-]+/i,
    /iPad [\w\s+.-]+/i,
    /Galaxy [\w\s+.-]+/i,
    /Pixel [\w\s+.-]+/i,
    /Xiaomi [\w\s+.-]+/i,
  ];
  for (const pattern of patterns) {
    const match = title.match(pattern);
    if (match) {
      return match[0].trim();
    }
  }

  return brand || optionTypeLabel.value;
}

function inferDeviceTypeLabel(product, fallbackType) {
  const normalized = `${product?.title || ""} ${product?.productType || ""}`.toLowerCase();
  if (/(macbook|laptop|notebook)/.test(normalized)) {
    return "Thin and Light Laptop";
  }
  if (/(phone|iphone|android|galaxy|pixel|xiaomi)/.test(normalized)) {
    return "Smartphone";
  }
  if (/(headphone|earbud|speaker)/.test(normalized)) {
    return "Audio Device";
  }
  if (/(printer)/.test(normalized)) {
    return "Office Device";
  }

  return fallbackType || "Marketplace Product";
}

function inferBatteryBackup(product) {
  const source = `${product?.title || ""} ${product?.description || ""}`;
  const hourMatch = source.match(/(\d{1,2})\s*(?:hours|hour|hrs|hr)/i);
  if (hourMatch) {
    return `Up to ${hourMatch[1]} hours`;
  }

  const normalized = source.toLowerCase();
  if (/(macbook|laptop|notebook)/.test(normalized)) {
    return "Up to 17 hours";
  }
  if (/(phone|iphone|android|galaxy|pixel|xiaomi)/.test(normalized)) {
    return "All-day battery";
  }

  return "Seller specified";
}

function inferPowerSupply(product) {
  const normalized = `${product?.title || ""} ${product?.description || ""}`.toLowerCase();
  if (/(macbook|laptop|notebook)/.test(normalized)) {
    return "61 W AC Adapter";
  }
  if (/(phone|iphone|android|galaxy|pixel|xiaomi|tablet)/.test(normalized)) {
    return "USB-C charging";
  }

  return "Standard power support";
}

function inferOfficeIncluded(product) {
  const normalized = `${product?.title || ""} ${product?.description || ""}`.toLowerCase();
  if (/(office|microsoft 365|ms office)/.test(normalized)) {
    return "Yes";
  }
  return "No";
}

function inferTouchscreenSupport(product) {
  const normalized = `${product?.title || ""} ${product?.description || ""}`.toLowerCase();
  if (/(phone|iphone|android|galaxy|pixel|xiaomi|tablet|touch)/.test(normalized)) {
    return "Yes";
  }
  if (/(macbook|laptop|notebook|monitor|tv)/.test(normalized)) {
    return "No";
  }

  return "Seller specified";
}

function inferScreenResolution(product) {
  const source = `${product?.title || ""} ${product?.description || ""}`;
  const match = source.match(/(\d{3,4}\s?[xX]\s?\d{3,4})/);
  if (match) {
    return match[1].replace(/\s+/g, "");
  }

  const normalized = source.toLowerCase();
  if (/macbook/.test(normalized)) {
    return "2560 x 1600 Pixel";
  }
  if (/(phone|iphone|android|galaxy|pixel|xiaomi)/.test(normalized)) {
    return "FHD+ resolution";
  }
  if (/(monitor|tv)/.test(normalized)) {
    return "4K / Full HD depending on model";
  }

  return "Seller specified";
}

function inferScreenType(product) {
  const normalized = `${product?.title || ""} ${product?.description || ""}`.toLowerCase();
  if (/retina/.test(normalized)) {
    return "Liquid Retina display";
  }
  if (/oled/.test(normalized)) {
    return "OLED panel";
  }
  if (/ips/.test(normalized)) {
    return "IPS panel";
  }
  if (/(phone|tablet)/.test(normalized)) {
    return "High brightness color display";
  }

  return inferDisplayLabel(product);
}

function inferSpeakerLabel(product) {
  const normalized = `${product?.title || ""} ${product?.description || ""}`.toLowerCase();
  if (/(macbook|laptop|notebook)/.test(normalized)) {
    return "Built-in speakers";
  }
  if (/(headphone|earbud|speaker)/.test(normalized)) {
    return "Dedicated audio drivers";
  }
  if (/(phone|tablet)/.test(normalized)) {
    return "Integrated stereo speakers";
  }

  return "Seller specified audio output";
}

function inferMicrophoneLabel(product) {
  const normalized = `${product?.title || ""} ${product?.description || ""}`.toLowerCase();
  if (/(macbook|laptop|notebook|phone|iphone|android|galaxy|pixel|xiaomi|tablet|camera)/.test(normalized)) {
    return "Built-in microphone";
  }

  return "Not specified";
}

function inferSoundProperties(product) {
  const normalized = `${product?.title || ""} ${product?.description || ""}`.toLowerCase();
  if (/(headphone|earbud|speaker)/.test(normalized)) {
    return "Stereo sound with portable playback support";
  }
  if (/(macbook|laptop|notebook)/.test(normalized)) {
    return "Stereo speakers with wide dynamic range";
  }
  if (/(phone|tablet)/.test(normalized)) {
    return "Balanced speaker output for calls and media";
  }

  return "Seller specified sound profile";
}

function inferMicInSupport(product) {
  const normalized = `${product?.title || ""} ${product?.description || ""}`.toLowerCase();
  if (/(laptop|macbook|notebook|desktop|pc|monitor|camera)/.test(normalized)) {
    return "Yes";
  }

  return "Seller specified";
}

function inferUsbPorts(product) {
  const normalized = `${product?.title || ""} ${product?.description || ""}`.toLowerCase();
  if (/macbook/.test(normalized)) {
    return "2 x Thunderbolt / USB 4 ports";
  }
  if (/(laptop|notebook|desktop|pc|monitor|printer)/.test(normalized)) {
    return "USB connectivity supported";
  }
  if (/(phone|iphone|android|galaxy|pixel|xiaomi|tablet)/.test(normalized)) {
    return "USB-C / charging port";
  }

  return "Seller specified ports";
}

function inferWirelessLabel(product) {
  const normalized = `${product?.title || ""} ${product?.description || ""}`.toLowerCase();
  if (/(macbook|laptop|notebook|phone|iphone|android|galaxy|pixel|xiaomi|tablet|printer|camera|speaker|headphone|earbud)/.test(normalized)) {
    return "Wireless LAN / device connectivity supported";
  }

  return "Not specified";
}

function inferBluetoothLabel(product) {
  const normalized = `${product?.title || ""} ${product?.description || ""}`.toLowerCase();
  if (/(macbook|laptop|notebook|phone|iphone|android|galaxy|pixel|xiaomi|tablet|speaker|headphone|earbud|camera)/.test(normalized)) {
    return "v5.0 / newer compatible";
  }

  return "Not specified";
}

function inferProcessorName(product, brand) {
  const source = `${product?.title || ""} ${product?.description || ""}`;
  const chipMatch = source.match(/\b(M[1-4](?:\s?(?:Pro|Max|Ultra))?)\b/i);
  if (chipMatch) {
    return chipMatch[1].replace(/\s+/g, " ").trim();
  }

  const intelMatch = source.match(/\b(i[3579][ -]?\d{3,5}\w*)\b/i);
  if (intelMatch) {
    return intelMatch[1].toUpperCase();
  }

  const amdMatch = source.match(/\b(Ryzen\s?[3579]\s?\d{3,5}\w*)\b/i);
  if (amdMatch) {
    return amdMatch[1];
  }

  if (brand === "Apple") {
    return "Apple Silicon";
  }

  return "Seller specified processor";
}

function inferStorageCapacity(product) {
  const source = `${product?.title || ""} ${product?.description || ""}`;
  const match = source.match(/\b(\d+(?:\.\d+)?)\s?(TB|GB)\b/i);
  if (match) {
    return `${match[1]} ${match[2].toUpperCase()}`;
  }

  return "";
}

function inferRamCapacity(product) {
  const source = `${product?.title || ""} ${product?.description || ""}`;
  const match = source.match(/\b(\d+(?:\.\d+)?)\s?GB\s?(?:RAM|Memory)?\b/i);
  if (match) {
    return `${match[1]} GB`;
  }

  return "";
}

function inferRamType(product) {
  const normalized = `${product?.title || ""} ${product?.description || ""}`.toLowerCase();
  if (/ddr5/.test(normalized)) {
    return "DDR5";
  }
  if (/ddr4/.test(normalized)) {
    return "DDR4";
  }
  if (/(macbook|apple|m1|m2|m3)/.test(normalized)) {
    return "Unified Memory";
  }

  return "Seller specified";
}

function inferExpandableMemory(product, ramLabel) {
  if (ramLabel) {
    const amount = Number.parseFloat(String(ramLabel).replace(/[^\d.]/g, ""));
    if (Number.isFinite(amount) && amount > 0) {
      return `Up to ${Math.max(16, amount)} GB`;
    }
  }

  return "Seller specified";
}

function inferGraphicsLabel(product, processorLabel) {
  const normalized = `${product?.title || ""} ${product?.description || ""}`.toLowerCase();
  if (/(m1|m2|m3|apple silicon)/i.test(processorLabel)) {
    return "Integrated Apple GPU";
  }
  if (/nvidia/.test(normalized)) {
    return "NVIDIA Graphics";
  }
  if (/radeon|amd/.test(normalized)) {
    return "AMD Graphics";
  }

  return "Integrated Graphics";
}

function inferCoreCount(product, processorLabel) {
  const source = `${product?.title || ""} ${product?.description || ""} ${processorLabel || ""}`;
  const match = source.match(/\b(\d{1,2})\s?core/i);
  if (match) {
    return match[1];
  }
  if (/(m1|m2|m3|apple silicon)/i.test(source)) {
    return "8";
  }

  return "Seller specified";
}

function inferDiskDrive(product, packageLabel) {
  const normalized = `${product?.title || ""} ${product?.description || ""}`.toLowerCase();
  if (/(ssd|storage|hard drive|hdd|disk)/.test(normalized)) {
    return packageLabel !== "Standard unit" ? `${packageLabel} package` : "Built-in storage";
  }

  return packageLabel !== "Standard unit" ? packageLabel : "No optical disk drive";
}

function inferWebCameraLabel(product) {
  const normalized = `${product?.title || ""} ${product?.description || ""}`.toLowerCase();
  if (/(macbook|laptop|notebook|phone|iphone|android|galaxy|pixel|xiaomi|tablet|camera)/.test(normalized)) {
    return "Integrated HD camera";
  }

  return "Seller specified";
}

function inferPointerDevice(product) {
  const normalized = `${product?.title || ""} ${product?.description || ""}`.toLowerCase();
  if (/(macbook|laptop|notebook)/.test(normalized)) {
    return "Trackpad";
  }
  if (/mouse/.test(normalized)) {
    return "Mouse";
  }
  if (/(phone|tablet)/.test(normalized)) {
    return "Touch input";
  }

  return "Standard controls";
}

function inferIncludedSoftware(product) {
  const normalized = `${product?.title || ""} ${product?.description || ""}`.toLowerCase();
  if (/(macbook|apple)/.test(normalized)) {
    return "Built-in apps and Apple ecosystem support";
  }
  if (/(windows|laptop|desktop|pc)/.test(normalized)) {
    return "Device drivers and seller supported setup";
  }

  return "No extra software specified";
}

function inferAdditionalFeaturesLabel(product, packageLabel, stockCount) {
  const parts = [
    packageLabel !== "Standard unit" ? packageLabel : "",
    stockCount > 0 ? `${stockCount} units in stock` : "",
    product?.showStockPublic ? "live stock visibility" : "",
  ].filter(Boolean);

  return parts.join(", ") || "Seller configured marketplace listing";
}

function inferWarrantySummary(product) {
  const normalized = `${product?.title || ""} ${product?.description || ""}`.toLowerCase();
  if (/(warranty|1 year|12 month)/.test(normalized)) {
    return "1 Year Limited Warranty";
  }

  return "Seller backed warranty support";
}

function inferWarrantyServiceType(product) {
  const verifiedStatus = String(product?.businessVerificationStatus || "").trim().toLowerCase();
  return verifiedStatus === "verified" ? "Seller support / order based service" : "Marketplace coordinated support";
}

function inferWarrantyCoverage(product) {
  if (matchesTechProduct(product)) {
    return "Manufacturing defects";
  }

  return "Seller confirmed product issues";
}

function inferWarrantyExclusion(product) {
  if (matchesTechProduct(product)) {
    return "Physical damage";
  }

  return "Damage caused after delivery";
}

function inferDomesticWarranty(product) {
  return matchesTechProduct(product) ? "1 Year" : "Seller policy applies";
}

function formatRelativeReviewTime(value) {
  const source = String(value || "").trim();
  if (!source) {
    return "just now";
  }

  const dateValue = new Date(source);
  if (Number.isNaN(dateValue.getTime())) {
    return formatDateLabel(source);
  }

  const diffMs = Date.now() - dateValue.getTime();
  const diffMinutes = Math.max(0, Math.floor(diffMs / 60000));
  if (diffMinutes < 1) {
    return "just now";
  }
  if (diffMinutes < 60) {
    return `${diffMinutes} min${diffMinutes === 1 ? "" : "s"} ago`;
  }

  const diffHours = Math.floor(diffMinutes / 60);
  if (diffHours < 24) {
    return `${diffHours} hour${diffHours === 1 ? "" : "s"} ago`;
  }

  const diffDays = Math.floor(diffHours / 24);
  if (diffDays < 7) {
    return `${diffDays} day${diffDays === 1 ? "" : "s"} ago`;
  }

  return formatDateLabel(source);
}

function getReviewInitials(name) {
  const parts = String(name || "")
    .trim()
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2);
  if (!parts.length) {
    return "U";
  }

  return parts.map((part) => part[0].toUpperCase()).join("");
}

function getReviewAvatarStyle(name) {
  const palette = [
    ["#111827", "#374151"],
    ["#0f766e", "#14b8a6"],
    ["#7c2d12", "#fb923c"],
    ["#1d4ed8", "#38bdf8"],
    ["#4c1d95", "#a78bfa"],
    ["#166534", "#4ade80"],
  ];
  const normalized = String(name || "").trim();
  const seed = normalized.split("").reduce((sum, char) => sum + char.charCodeAt(0), 0);
  const pair = palette[seed % palette.length];

  return {
    background: `linear-gradient(180deg, ${pair[0]}, ${pair[1]})`,
  };
}
</script>

<template>
  <section class="market-page market-page--wide product-detail-page" aria-label="Product details">
    <div
      v-if="ui.message"
      class="market-status"
      :class="{
        'market-status--error': ui.type === 'error',
        'market-status--success': ui.type === 'success',
      }"
      role="status"
      aria-live="polite"
    >
      {{ ui.message }}
    </div>

    <section v-if="currentProduct" class="pdp-shell">
      <div class="market-page__header">
        <nav class="market-page__crumbs" aria-label="Breadcrumb">
          <template v-for="(item, index) in breadcrumbItems" :key="`${item.label}-${index}`">
            <RouterLink v-if="item.to && index < breadcrumbItems.length - 1" :to="item.to">
              {{ item.label }}
            </RouterLink>
            <span v-else>{{ item.label }}</span>
            <span v-if="index < breadcrumbItems.length - 1" aria-hidden="true">/</span>
          </template>
        </nav>

        <RouterLink class="market-button market-button--ghost" :to="backTarget">
          Back to products
        </RouterLink>
      </div>

      <article class="pdp-layout" :aria-label="currentProduct.title">
        <div class="pdp-gallery">
          <div class="market-card pdp-gallery__frame">
            <img
              :src="currentImagePath"
              :alt="currentProduct.title"
              width="1200"
              height="1200"
              decoding="async"
              fetchpriority="high"
            >
          </div>

          <div v-if="imageGallery.length > 1" class="pdp-gallery__thumbs" aria-label="Product gallery">
            <button class="market-icon-button" type="button" aria-label="Previous image" @click="previousImage">
              <svg viewBox="0 0 24 24" aria-hidden="true">
                <path d="M14.5 6.5 9 12l5.5 5.5"></path>
              </svg>
            </button>

            <div class="pdp-gallery__thumb-rail">
              <button
                v-for="(imagePath, index) in imageGallery"
                :key="`${imagePath}-${index}`"
                class="pdp-gallery__thumb"
                type="button"
                :aria-pressed="index === currentImageIndex"
                @click="setCurrentImage(index)"
              >
                <img :src="imagePath" :alt="`${currentProduct.title} ${index + 1}`" loading="lazy" decoding="async">
              </button>
            </div>

            <button class="market-icon-button" type="button" aria-label="Next image" @click="nextImage">
              <svg viewBox="0 0 24 24" aria-hidden="true">
                <path d="M9.5 6.5 15 12l-5.5 5.5"></path>
              </svg>
            </button>
          </div>
        </div>

        <aside class="market-card pdp-summary">
          <span class="pdp-summary__label">Verified marketplace listing</span>
          <h1 class="pdp-summary__title">{{ currentProduct.title }}</h1>
          <p class="pdp-summary__copy">{{ shortDescription }}</p>

          <div class="pdp-summary__rating">
            <div class="product-card__stars" :aria-label="averageRating > 0 ? `Rating ${averageRating.toFixed(1)}` : 'No rating yet'">
              <svg
                v-for="index in 5"
                :key="`hero-star-${index}`"
                viewBox="0 0 24 24"
                aria-hidden="true"
              >
                <path d="M12 3.8 14.6 9l5.7.8-4.1 4 1 5.7-5.2-2.7-5.2 2.7 1-5.7-4.1-4 5.7-.8Z"></path>
              </svg>
            </div>
            <strong>{{ averageRating > 0 ? averageRating.toFixed(1) : "0.0" }}</strong>
            <span>{{ reviewCount > 0 ? `${formatCount(reviewCount)} reviews` : "No reviews yet" }}</span>
            <span>{{ buyersCount > 0 ? `${formatCount(buyersCount)} buyers` : "Fresh listing" }}</span>
          </div>

          <div class="pdp-summary__price">
            <strong>{{ formatPrice(currentProduct.price) }}</strong>
            <span v-if="compareAtPrice">{{ formatPrice(compareAtPrice) }}</span>
            <span v-if="discountPercent > 0">{{ discountPercent }}% off</span>
          </div>

          <div class="pdp-meta-grid">
            <div>
              <span>Sku</span>
              <strong>{{ productSku }}</strong>
            </div>
            <div>
              <span>Brand</span>
              <strong>{{ productBrand }}</strong>
            </div>
            <div>
              <span>Seller</span>
              <strong>{{ businessName || "Verified seller" }}</strong>
            </div>
            <div>
              <span>Availability</span>
              <strong>{{ productAvailabilityLabel }}</strong>
            </div>
          </div>

          <div class="pdp-detail-pills">
            <span v-for="detail in details" :key="detail">{{ detail }}</span>
          </div>

          <div class="pdp-option-stack">
            <section class="pdp-option-group">
              <p class="search-sidebar__label">Color</p>
              <div v-if="colorOptions.length > 0" class="pdp-option-grid">
                <button
                  v-for="option in colorOptions"
                  :key="option.value"
                  type="button"
                  :aria-pressed="selectedColor === option.value"
                  :disabled="!option.inStock"
                  @click="chooseColor(option.value)"
                >
                  {{ option.label }}
                </button>
              </div>
              <p v-else class="section-heading__copy">
                {{ currentProduct.color ? formatProductColorLabel(currentProduct.color) : "Standard" }}
              </p>
            </section>

            <section class="pdp-option-group">
              <p class="search-sidebar__label">Size</p>
              <div v-if="sizeOptions.length > 0" class="pdp-option-grid">
                <button
                  v-for="option in sizeOptions"
                  :key="option.value"
                  type="button"
                  :aria-pressed="selectedSize === option.value"
                  :disabled="!option.inStock"
                  @click="chooseSize(option.value)"
                >
                  {{ option.value }}
                </button>
              </div>
              <p v-else class="section-heading__copy">{{ currentProduct.size || "Standard fit" }}</p>
            </section>

            <section v-for="group in variantAttributeGroups" :key="group.key" class="pdp-option-group">
              <p class="search-sidebar__label">{{ group.label }}</p>
              <div class="pdp-option-grid">
                <button
                  v-for="option in group.options"
                  :key="`${group.key}-${option.value}`"
                  type="button"
                  :aria-pressed="selectedVariantAttributes[group.key] === option.value"
                  :disabled="!option.inStock"
                  @click="chooseVariantAttribute(group.key, option.value)"
                >
                  {{ option.value }}
                </button>
              </div>
            </section>

            <section class="pdp-option-group">
              <p class="search-sidebar__label">Product type</p>
              <p class="section-heading__copy">{{ optionTypeLabel }}</p>
            </section>

            <section class="pdp-option-group">
              <p class="search-sidebar__label">Package</p>
              <p class="section-heading__copy">{{ packageAmountLabel }}</p>
            </section>
          </div>

          <div class="pdp-summary__actions">
            <div class="pdp-quantity" aria-label="Quantity selector">
              <button type="button" :disabled="selectedQuantity <= 1" @click="decrementQuantity">-</button>
              <span>{{ selectedQuantity }}</span>
              <button type="button" :disabled="selectedQuantity >= quantityMax" @click="incrementQuantity">+</button>
            </div>

            <button class="market-button market-button--primary" type="button" :disabled="!isProductAvailable" @click="handleCart">
              {{ currentProduct.requiresVariantSelection && !selectedVariant ? "Select options" : "Add to cart" }}
            </button>

            <button class="market-button market-button--secondary" type="button" :disabled="!isProductAvailable" @click="handleBuyNow">
              Buy now
            </button>

            <RouterLink
              v-if="currentProduct.businessProfileId"
              class="market-button market-button--ghost"
              :to="getBusinessProfileUrl(currentProduct.businessProfileId)"
            >
              Visit store
            </RouterLink>
          </div>

          <div class="pdp-summary__actions">
            <button class="market-button market-button--ghost" type="button" @click="handleWishlist">
              {{ wishlistIds.includes(currentProduct.id) ? "Saved" : "Save" }}
            </button>
            <button class="market-button market-button--ghost" type="button" @click="handleCompareProduct">
              {{ isCompared ? "Compared" : "Compare" }}
            </button>
            <button class="market-button market-button--ghost" type="button" @click="handleShareProduct">
              Share
            </button>
            <button class="market-button market-button--ghost" type="button" @click="handleReportProduct">
              Report
            </button>
          </div>

          <div class="pdp-trust">
            <article v-for="highlight in trustHighlights.slice(0, 4)" :key="highlight.title">
              <strong>{{ highlight.title }}</strong>
              <span>{{ highlight.description }}</span>
            </article>
          </div>
        </aside>
      </article>

      <section class="pdp-content-grid">
        <div class="market-card pdp-description">
          <div class="pdp-tabs" role="tablist" aria-label="Product information tabs">
            <button
              v-for="tab in detailTabs"
              :key="tab.key"
              type="button"
              role="tab"
              :aria-selected="activeDetailTab === tab.key"
              :aria-pressed="activeDetailTab === tab.key"
              @click="activeDetailTab = tab.key"
            >
              {{ tab.label }}
            </button>
          </div>

          <div v-if="activeDetailTab === 'description'" class="pdp-description__body" role="tabpanel">
            <div>
              <h2>Description</h2>
              <p v-for="paragraph in descriptionParagraphs" :key="paragraph">
                {{ paragraph }}
              </p>
            </div>

            <div>
              <h3>Highlights</h3>
              <ul>
                <li v-for="bullet in productHighlightBullets" :key="bullet">{{ bullet }}</li>
              </ul>
            </div>

            <div>
              <h3>Shipping information</h3>
              <ul>
                <li v-for="item in shippingInformation" :key="item.label">
                  <strong>{{ item.label }}:</strong> {{ item.value }}
                </li>
              </ul>
            </div>
          </div>

          <div v-else-if="activeDetailTab === 'additional'" class="pdp-description__body" role="tabpanel">
            <div>
              <h2>Overview</h2>
              <div class="metric-grid">
                <article v-for="item in additionalOverviewItems" :key="`overview-${item.label}`" class="metric-card">
                  <p class="metric-card__label">{{ item.label }}</p>
                  <strong>{{ item.value }}</strong>
                </article>
              </div>
            </div>

            <article v-for="section in additionalDetailSections" :key="section.title">
              <h3>{{ section.title }}</h3>
              <p v-if="section.text">{{ section.text }}</p>
              <p v-for="line in section.lines" :key="`${section.title}-${line}`">{{ line }}</p>
            </article>

            <div>
              <h3>Highlights</h3>
              <ul>
                <li v-for="bullet in additionalHighlights" :key="bullet">{{ bullet }}</li>
              </ul>
            </div>
          </div>

          <div v-else-if="activeDetailTab === 'specification'" class="pdp-specs" role="tabpanel">
            <div class="pdp-spec-columns">
              <div v-for="(column, columnIndex) in specificationColumns" :key="`spec-column-${columnIndex}`">
                <section v-for="group in column" :key="group.title" class="pdp-spec-group">
                  <h3>{{ group.title }}</h3>
                  <div class="pdp-spec-group__items">
                    <div v-for="item in group.items" :key="`${group.title}-${item.label}`" class="pdp-spec-group__item">
                      <span>{{ item.label }}</span>
                      <strong>{{ item.value }}</strong>
                    </div>
                  </div>
                </section>
              </div>
            </div>
          </div>

          <div v-else class="pdp-reviews" role="tabpanel">
            <div class="pdp-review-summary">
              <aside class="market-card market-card--padded">
                <strong>{{ averageRating > 0 ? averageRating.toFixed(1) : "0.0" }}</strong>
                <div class="product-card__stars" :aria-label="averageRating > 0 ? `Rating ${averageRating.toFixed(1)}` : 'No rating yet'">
                  <svg
                    v-for="index in 5"
                    :key="`summary-star-${index}`"
                    viewBox="0 0 24 24"
                    aria-hidden="true"
                  >
                    <path d="M12 3.8 14.6 9l5.7.8-4.1 4 1 5.7-5.2-2.7-5.2 2.7 1-5.7-4.1-4 5.7-.8Z"></path>
                  </svg>
                </div>
                <span>{{ reviewCount > 0 ? `${formatCount(reviewCount)} customer ratings` : "No customer ratings yet" }}</span>
              </aside>

              <div class="pdp-review-bars">
                <div v-for="entry in reviewBreakdown" :key="entry.star" class="pdp-review-bar">
                  <span>{{ entry.star }} star</span>
                  <meter :value="entry.percentage" min="0" max="100">{{ entry.percentage }}</meter>
                  <span>{{ entry.count }}</span>
                </div>
              </div>
            </div>

            <div class="pdp-review-header">
              <div>
                <h3>Customer feedback</h3>
                <p class="section-heading__copy">Reviews help buyers evaluate quality, delivery, and seller reliability.</p>
              </div>

              <button
                v-if="canSubmitReview"
                class="market-button market-button--secondary"
                type="button"
                @click="showReviewComposer = !showReviewComposer"
              >
                {{ showReviewComposer ? "Hide review form" : "Write a review" }}
              </button>
            </div>

            <form v-if="canSubmitReview && showReviewComposer" class="pdp-review-form" @submit.prevent="handleSubmitReview">
              <div class="pdp-review-form__row">
                <label>
                  <span>Rating</span>
                  <select v-model.number="reviewForm.rating">
                    <option v-for="star in 5" :key="star" :value="star">{{ star }} stars</option>
                  </select>
                </label>

                <label>
                  <span>Title</span>
                  <input v-model="reviewForm.title" type="text" placeholder="How was the product?">
                </label>
              </div>

              <label>
                <span>Your feedback</span>
                <textarea
                  v-model="reviewForm.body"
                  rows="4"
                  placeholder="Share delivery, quality, and overall experience."
                ></textarea>
              </label>

              <div class="market-empty__actions">
                <button class="market-button market-button--primary" type="submit" :disabled="reviewBusy">
                  {{ reviewBusy ? "Saving..." : "Submit review" }}
                </button>
              </div>
            </form>

            <div v-else-if="!canSubmitReview" class="market-status market-status--compact">
              Only customers with a completed order can publish a review.
            </div>

            <div v-if="productReviews.length > 0" class="pdp-review-list">
              <article v-for="review in productReviews" :key="review.id" class="pdp-review-item">
                <div class="pdp-review-header">
                  <div class="search-toolbar">
                    <div class="pdp-review-avatar">
                      {{ getReviewInitials(review.authorName) }}
                    </div>

                    <div>
                      <strong>{{ review.authorName }}</strong>
                      <p class="section-heading__copy">{{ formatRelativeReviewTime(review.createdAt) }}</p>
                    </div>
                  </div>

                  <div class="product-card__stars" :aria-label="`Rating ${review.rating}`">
                  <svg
                    v-for="index in 5"
                    :key="`review-star-${review.id}-${index}`"
                    viewBox="0 0 24 24"
                    aria-hidden="true"
                  >
                    <path d="M12 3.8 14.6 9l5.7.8-4.1 4 1 5.7-5.2-2.7-5.2 2.7 1-5.7-4.1-4 5.7-.8Z"></path>
                  </svg>
                  </div>
                </div>

                <p>{{ review.body || review.title || "Customer feedback submitted for this product." }}</p>
              </article>
            </div>

            <div v-else class="market-empty">
              <h3>No reviews yet</h3>
              <p>This product is ready for its first customer review.</p>
            </div>
          </div>
        </div>

        <aside class="market-card pdp-support">
          <p class="pdp-summary__label">Seller and fulfillment</p>
          <h2>{{ businessName || "Verified seller" }}</h2>
          <div class="pdp-support__list">
            <p><strong>Published:</strong> {{ publishedDateLabel }}</p>
            <p><strong>Support:</strong> {{ sellerSupportEmail || "Available through order support" }}</p>
            <p><strong>Hours:</strong> {{ sellerSupportHours || "Seller confirmation required" }}</p>
            <p><strong>Website:</strong> {{ sellerWebsiteUrl || "Managed inside the marketplace" }}</p>
            <p><strong>Returns:</strong> {{ sellerReturnPolicySummary || "Handled through order history and support." }}</p>
            <p><strong>Stock:</strong> {{ selectedVariantStock > 0 ? `${selectedVariantStock} units ready` : outOfStockMessage }}</p>
          </div>

          <div class="pdp-detail-pills">
            <span v-for="badge in safeCheckoutBadges" :key="badge">{{ badge }}</span>
          </div>

          <div v-if="canSeeProductEngagement" class="metric-grid" aria-label="Product engagement">
            <article v-for="item in publicEngagementItems" :key="`${currentProduct.id}-${item.label}`" class="metric-card">
              <p class="metric-card__label">{{ item.label }}</p>
              <strong>{{ item.value }}</strong>
            </article>
          </div>
        </aside>
      </section>

      <section v-if="recommendationDisplayColumns.length > 0" class="pdp-recommendations" aria-label="Recommended products">
        <article
          v-for="column in recommendationDisplayColumns"
          :key="column.key"
          class="market-card market-card--padded"
        >
          <div class="search-sidebar__header">
            <div>
              <p class="pdp-summary__label">Recommended</p>
              <h2>{{ column.displayTitle }}</h2>
            </div>
            <span class="section-heading__copy">{{ column.products.length }} curated picks</span>
          </div>

          <div class="pdp-recommendations__grid">
            <ProductCard
              v-for="product in column.products"
              :key="`${column.key}-${product.id}`"
              :product="product"
              :is-wishlisted="wishlistIds.includes(product.id)"
              :is-in-cart="cartIds.includes(product.id)"
              :is-compared="isComparedItem(product.id)"
              @wishlist="handleRecommendationWishlist"
              @cart="handleRecommendationCart"
              @compare="toggleComparedProduct"
            />
          </div>
        </article>
      </section>
    </section>

    <div v-else class="market-empty">
      <h2>Product not found</h2>
      <p>This listing may have been removed or is no longer available.</p>
      <div class="market-empty__actions">
        <RouterLink class="market-button market-button--secondary" to="/kerko">
          Browse products
        </RouterLink>
      </div>
    </div>
  </section>
</template>
