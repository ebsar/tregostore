<script setup>
import { computed, onMounted, reactive, ref, watch } from "vue";
import { RouterLink, useRoute, useRouter } from "vue-router";
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
  if (
    preferredKey !== "color"
    && selectedColor.value
    && !variantInventory.value.some((entry) => variantEntryMatchesSelections(entry))
  ) {
    selectedColor.value = "";
  }
  if (
    preferredKey !== "size"
    selectedColor.value
    && !variantInventory.value.some((entry) => variantEntryMatchesSelections(entry))
  ) {
    selectedSize.value
    && !variantInventory.value.some((entry) => variantEntryMatchesSelections(entry))
  ) {
    selectedSize.value = "";
  }
  Object.entries(selectedVariantAttributes).forEach(([key, value]) => {
    if (!value || key === preferredKey) {
      return;
    }
    if (!variantInventory.value.some((entry) => variantEntryMatchesSelections(entry))) {
      delete selectedVariantAttributes[key];
    }
  });
}

function handleCompareProduct() {
  if (!currentProduct.value) {
    return;
  }

  toggleComparedProduct(currentProduct.value);
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
  <section class="product-detail-page pdp-page" aria-label="Product details">
    <div v-if="ui.message" class="form-message" :class="ui.type" role="status" aria-live="polite">
      {{ ui.message }}
    </div>

    <section v-if="currentProduct" class="product-detail-container pdp-container">
      <nav class="product-breadcrumbs pdp-breadcrumbs" aria-label="Breadcrumb">
        <div class="pdp-breadcrumb-track">
          <template v-for="(item, index) in breadcrumbItems" :key="`${item.label}-${index}`">
            <RouterLink
              v-if="item.to && index < breadcrumbItems.length - 1"
              class="product-breadcrumb-link"
              :to="item.to"
            >
              {{ item.label }}
            </RouterLink>
            <span v-else class="product-breadcrumb-current">{{ item.label }}</span>
            <span v-if="index < breadcrumbItems.length - 1" class="product-breadcrumb-separator" aria-hidden="true">/</span>
          </template>
        </div>

        <RouterLink class="pdp-back-link" :to="backTarget">
          Back to products
        </RouterLink>
      </nav>

      <article class="product-detail-card pdp-hero" :aria-label="currentProduct.title">
        <div class="pdp-gallery">
          <div class="pdp-gallery-stage">
            <img
              class="pdp-gallery-image"
              :src="currentImagePath"
              :alt="currentProduct.title"
              width="1200"
              height="1200"
              decoding="async"
              fetchpriority="high"
            >
          </div>

          <div v-if="imageGallery.length > 1" class="pdp-gallery-rail" aria-label="Product gallery">
            <button class="pdp-gallery-arrow" type="button" @click="previousImage">
              <svg viewBox="0 0 24 24" aria-hidden="true">
                <path d="M14.5 6.5 9 12l5.5 5.5"></path>
              </svg>
            </button>

            <div class="pdp-gallery-thumbnails">
              <button
                v-for="(imagePath, index) in imageGallery"
                :key="`${imagePath}-${index}`"
                class="pdp-gallery-thumb"
                :class="{ active: index === currentImageIndex }"
                type="button"
                @click="setCurrentImage(index)"
              >
                <img :src="imagePath" :alt="`${currentProduct.title} ${index + 1}`" loading="lazy" decoding="async">
              </button>
            </div>

            <button class="pdp-gallery-arrow" type="button" @click="nextImage">
              <svg viewBox="0 0 24 24" aria-hidden="true">
                <path d="M9.5 6.5 15 12l-5.5 5.5"></path>
              </svg>
            </button>
          </div>
        </div>

        <div class="pdp-info">
          <div class="pdp-rating-row">
            <div class="pdp-stars" :aria-label="averageRating > 0 ? `Rating ${averageRating.toFixed(1)}` : 'No rating yet'">
              <svg
                v-for="index in 5"
                :key="`hero-star-${index}`"
                class="pdp-star"
                :class="{ 'is-filled': index <= filledStars }"
                viewBox="0 0 24 24"
                aria-hidden="true"
              >
                <path d="M12 3.8 14.6 9l5.7.8-4.1 4 1 5.7-5.2-2.7-5.2 2.7 1-5.7-4.1-4 5.7-.8Z"></path>
              </svg>
            </div>
            <strong>{{ averageRating > 0 ? averageRating.toFixed(1) : "0.0" }} Star Rating</strong>
            <span>({{ reviewCount > 0 ? formatCount(reviewCount) : 0 }} user feedback)</span>
          </div>

          <div class="pdp-headline">
            <h1>{{ currentProduct.title }}</h1>
            <p v-if="businessName" class="pdp-business-posted">
              Posted by <strong>{{ businessName }}</strong>
            </p>
          </div>

          <div class="pdp-meta-grid">
            <div class="pdp-meta-column">
              <p><span>Sku:</span> <strong>{{ productSku }}</strong></p>
              <p><span>Brand:</span> <strong>{{ productBrand }}</strong></p>
              <p><span>Business:</span> <strong>{{ businessName || "Verified seller" }}</strong></p>
            </div>
            <div class="pdp-meta-column">
              <p><span>Availability:</span> <strong :class="['pdp-stock-copy', { 'is-live': isProductAvailable }]">{{ productAvailabilityLabel }}</strong></p>
              <p><span>Category:</span> <strong>{{ formatCategoryLabel(currentProduct.category) }}</strong></p>
              <p><span>Type:</span> <strong>{{ optionTypeLabel }}</strong></p>
            </div>
          </div>

          <div class="pdp-price-row">
            <div class="pdp-price-stack">
              <strong class="pdp-price-current">{{ formatPrice(currentProduct.price) }}</strong>
              <span v-if="compareAtPrice" class="pdp-price-old">{{ formatPrice(compareAtPrice) }}</span>
            </div>
            <span v-if="discountPercent > 0" class="pdp-offer-badge">{{ discountPercent }}% OFF</span>
          </div>

          <div class="product-detail-tags pdp-tags">
            <span v-for="detail in details" :key="detail" class="product-detail-tag pdp-tag">
              {{ detail }}
            </span>
          </div>

          <div class="pdp-options-grid">
            <section class="pdp-option-card">
              <p class="pdp-option-label">Color</p>
              <div v-if="colorOptions.length > 0" class="pdp-color-swatches">
                <button
                  v-for="option in colorOptions"
                  :key="option.value"
                  class="pdp-color-swatch"
                  :class="{ active: selectedColor === option.value, 'is-unavailable': !option.inStock }"
                  type="button"
                  :style="getColorSwatchStyle(option.value)"
                  :disabled="!option.inStock"
                  :title="option.label"
                  @click="chooseColor(option.value)"
                >
                  <span class="sr-only">{{ option.label }}</span>
                </button>
              </div>
              <div v-else class="pdp-static-field">
                {{ currentProduct.color ? formatProductColorLabel(currentProduct.color) : "Standard" }}
              </div>
            </section>

            <section class="pdp-option-card">
              <p class="pdp-option-label">Size</p>
              <label v-if="sizeOptions.length > 0" class="pdp-select-shell">
                <select v-model="selectedSize">
                  <option value="">Select size</option>
                  <option
                    v-for="option in sizeOptions"
                    :key="option.value"
                    :value="option.value"
                    :disabled="!option.inStock"
                  >
                    {{ option.value }}{{ option.inStock ? "" : " - unavailable" }}
                  </option>
                </select>
              </label>
              <div v-else class="pdp-static-field">
                {{ currentProduct.size || "Standard fit" }}
              </div>
            </section>

            <section class="pdp-option-card">
              <p class="pdp-option-label">Product type</p>
              <div class="pdp-static-field">
                {{ optionTypeLabel }}
              </div>
            </section>

            <section class="pdp-option-card">
              <p class="pdp-option-label">Package</p>
              <div class="pdp-static-field">
                {{ packageAmountLabel }}
              </div>
            </section>
          </div>

          <div class="pdp-buy-row">
            <div class="pdp-quantity-box">
              <button type="button" :disabled="selectedQuantity <= 1" @click="decrementQuantity">-</button>
              <span>{{ selectedQuantity }}</span>
              <button type="button" :disabled="selectedQuantity >= quantityMax" @click="incrementQuantity">+</button>
            </div>

            <button
              class="pdp-primary-button"
              :class="{ active: cartIds.includes(currentProduct.id) }"
              type="button"
              :disabled="!isProductAvailable"
              @click="handleCart"
            >
              Add to cart
            </button>

            <button
              class="pdp-secondary-button"
              type="button"
              :disabled="!isProductAvailable"
              @click="handleBuyNow"
            >
              Buy now
            </button>
          </div>

          <div class="pdp-utility-row">
            <button
              class="pdp-utility-action"
              :class="{ active: wishlistIds.includes(currentProduct.id) }"
              type="button"
              @click="handleWishlist"
            >
              <svg viewBox="0 0 24 24" aria-hidden="true">
                <path d="M12 20.4 4.9 13.8a4.8 4.8 0 0 1 6.8-6.8l.3.3.3-.3a4.8 4.8 0 1 1 6.8 6.8Z"></path>
              </svg>
              <span>Add to Wishlist</span>
            </button>

            <button
              class="pdp-utility-action"
              :class="{ active: isCompared }"
              type="button"
              @click="handleCompareProduct"
            >
              <svg viewBox="0 0 24 24" aria-hidden="true">
                <rect x="4.5" y="5.5" width="6.5" height="13" rx="1.8"></rect>
                <rect x="13" y="7.5" width="6.5" height="11" rx="1.8"></rect>
              </svg>
              <span>Add to Compare</span>
            </button>

            <button class="pdp-utility-action" type="button" @click="handleShareProduct">
              <svg viewBox="0 0 24 24" aria-hidden="true">
                <circle cx="18" cy="5" r="2.2"></circle>
                <circle cx="6" cy="12" r="2.2"></circle>
                <circle cx="18" cy="19" r="2.2"></circle>
                <path d="M8 11.2 15.9 6.7"></path>
                <path d="m8 12.8 7.9 4.5"></path>
              </svg>
              <span>Share product</span>
            </button>

            <button class="pdp-utility-action pdp-utility-action--ghost" type="button" @click="handleReportProduct">
              Report
            </button>
          </div>

          <div class="pdp-checkout-card">
            <p class="pdp-checkout-title">100% Guarantee Safe Checkout</p>
            <div class="pdp-checkout-badges">
              <span v-for="badge in safeCheckoutBadges" :key="badge" class="pdp-checkout-badge">{{ badge }}</span>
            </div>
          </div>

          <div v-if="canSeeProductEngagement" class="product-detail-engagement-row pdp-engagement-row" aria-label="Product engagement">
            <span
              v-for="item in publicEngagementItems"
              :key="`${currentProduct.id}-${item.label}`"
              class="product-detail-engagement-chip pdp-engagement-chip"
            >
              <small>{{ item.label }}</small>
              <strong>{{ item.value }}</strong>
            </span>
          </div>
        </div>
      </article>

      <section class="pdp-detail-tabs">
        <div class="pdp-tab-bar" role="tablist" aria-label="Product information tabs">
          <button
            v-for="tab in detailTabs"
            :key="tab.key"
            class="pdp-tab-button"
            :class="{ active: activeDetailTab === tab.key }"
            type="button"
            role="tab"
            :aria-selected="activeDetailTab === tab.key"
            @click="activeDetailTab = tab.key"
          >
            {{ tab.label }}
          </button>
        </div>

        <div v-if="activeDetailTab === 'description'" class="pdp-tab-panel pdp-description-panel" role="tabpanel">
          <div class="pdp-description-copy">
            <h2>Description</h2>
            <p v-for="paragraph in descriptionParagraphs" :key="paragraph">
              {{ paragraph }}
            </p>
          </div>

          <section class="pdp-side-card">
            <h3>Feature</h3>
            <ul class="pdp-bullet-list">
              <li v-for="highlight in trustHighlights" :key="highlight.title">
                <strong>{{ highlight.title }}</strong>
                <span>{{ highlight.description }}</span>
              </li>
            </ul>
          </section>

          <section class="pdp-side-card">
            <h3>Shipping Information</h3>
            <ul class="pdp-side-list">
              <li v-for="item in shippingInformation" :key="item.label">
                <strong>{{ item.label }}:</strong>
                <span>{{ item.value }}</span>
              </li>
            </ul>
          </section>
        </div>

        <div v-else-if="activeDetailTab === 'additional'" class="pdp-tab-panel pdp-additional-panel" role="tabpanel">
          <section class="pdp-info-group pdp-additional-overview">
            <h3>Overview</h3>
            <div class="pdp-additional-overview-grid">
              <div v-for="item in additionalOverviewItems" :key="`overview-${item.label}`" class="pdp-additional-overview-row">
                <span>{{ item.label }}:</span>
                <strong>{{ item.value }}</strong>
              </div>
            </div>
          </section>

          <section class="pdp-info-group pdp-additional-middle">
            <article v-for="section in additionalDetailSections" :key="section.title" class="pdp-additional-detail-block">
              <h3>{{ section.title }}</h3>
              <p v-if="section.text" class="pdp-info-paragraph">
                {{ section.text }}
              </p>
              <p v-for="line in section.lines" :key="`${section.title}-${line}`" class="pdp-additional-detail-line">
                {{ line }}
              </p>
            </article>
          </section>

          <section class="pdp-info-group pdp-additional-highlights">
            <h3>Highlights:</h3>
            <ul class="pdp-bullet-list pdp-bullet-list--compact pdp-additional-highlights-list">
              <li v-for="bullet in additionalHighlights" :key="bullet">
                <span>{{ bullet }}</span>
              </li>
            </ul>
          </section>
        </div>

        <div v-else-if="activeDetailTab === 'specification'" class="pdp-tab-panel pdp-specification-panel" role="tabpanel">
          <div class="pdp-spec-columns">
            <div v-for="(column, columnIndex) in specificationColumns" :key="`spec-column-${columnIndex}`" class="pdp-spec-column">
              <section v-for="group in column" :key="group.title" class="pdp-spec-group">
                <h3>{{ group.title }}</h3>
                <div class="pdp-spec-grid">
                  <div v-for="item in group.items" :key="`${group.title}-${item.label}`" class="pdp-spec-row">
                    <span>{{ item.label }}</span>
                    <strong>{{ item.value }}</strong>
                  </div>
                </div>
              </section>
            </div>
          </div>
        </div>

        <div v-else class="pdp-tab-panel pdp-reviews-panel" role="tabpanel">
          <div class="pdp-review-summary-layout">
            <aside class="pdp-review-score-card">
              <strong>{{ averageRating > 0 ? averageRating.toFixed(1) : "0.0" }}</strong>
              <div class="pdp-stars pdp-stars--summary" :aria-label="averageRating > 0 ? `Rating ${averageRating.toFixed(1)}` : 'No rating yet'">
                <svg
                  v-for="index in 5"
                  :key="`summary-star-${index}`"
                  class="pdp-star"
                  :class="{ 'is-filled': index <= filledStars }"
                  viewBox="0 0 24 24"
                  aria-hidden="true"
                >
                  <path d="M12 3.8 14.6 9l5.7.8-4.1 4 1 5.7-5.2-2.7-5.2 2.7 1-5.7-4.1-4 5.7-.8Z"></path>
                </svg>
              </div>
              <span>Customer Rating ({{ reviewCount > 0 ? formatCount(reviewCount) : 0 }})</span>
            </aside>

            <div class="pdp-review-bars">
              <div v-for="entry in reviewBreakdown" :key="entry.star" class="pdp-review-bar-row">
                <div class="pdp-review-bar-label">
                  <span>{{ entry.star }}</span>
                  <svg class="pdp-review-bar-star" viewBox="0 0 24 24" aria-hidden="true">
                    <path d="M12 3.8 14.6 9l5.7.8-4.1 4 1 5.7-5.2-2.7-5.2 2.7 1-5.7-4.1-4 5.7-.8Z"></path>
                  </svg>
                </div>
                <div class="pdp-review-bar-track">
                  <span class="pdp-review-bar-fill" :style="{ width: `${entry.percentage}%` }"></span>
                </div>
                <span class="pdp-review-bar-value">{{ entry.percentage }}% ({{ entry.count }})</span>
              </div>
            </div>
          </div>

          <div class="pdp-feedback-block">
            <div class="pdp-feedback-head">
              <h3>Customer Feedback</h3>
              <button
                v-if="canSubmitReview"
                class="pdp-review-toggle"
                type="button"
                @click="showReviewComposer = !showReviewComposer"
              >
                {{ showReviewComposer ? "Hide review form" : "Write a review" }}
              </button>
            </div>

            <form
              v-if="canSubmitReview && showReviewComposer"
              class="pdp-review-form"
              @submit.prevent="handleSubmitReview"
            >
              <label class="field">
                <span>Rating</span>
                <select v-model.number="reviewForm.rating">
                  <option v-for="star in 5" :key="star" :value="star">{{ star }} stars</option>
                </select>
              </label>

              <label class="field">
                <span>Title</span>
                <input v-model="reviewForm.title" type="text" placeholder="How was the product?">
              </label>

              <label class="field field--full">
                <span>Your feedback</span>
                <textarea v-model="reviewForm.body" rows="4" placeholder="Share delivery, quality and overall experience."></textarea>
              </label>

              <button type="submit" :disabled="reviewBusy">
                {{ reviewBusy ? "Saving..." : "Submit review" }}
              </button>
            </form>

            <div v-else-if="!canSubmitReview" class="product-review-empty-note pdp-review-note">
              Only customers with a completed order can publish a review.
            </div>

            <div v-if="productReviews.length > 0" class="product-reviews-list pdp-review-list">
              <article v-for="review in productReviews" :key="review.id" class="product-review-item pdp-review-item">
                <div class="pdp-review-person">
                  <div class="pdp-review-avatar" :style="getReviewAvatarStyle(review.authorName)">
                    {{ getReviewInitials(review.authorName) }}
                  </div>

                  <div class="pdp-review-meta">
                    <div class="pdp-review-author-line">
                      <strong>{{ review.authorName }}</strong>
                      <span>{{ formatRelativeReviewTime(review.createdAt) }}</span>
                    </div>

                    <div class="pdp-stars pdp-stars--review" :aria-label="`Rating ${review.rating}`">
                      <svg
                        v-for="index in 5"
                        :key="`review-star-${review.id}-${index}`"
                        class="pdp-star"
                        :class="{ 'is-filled': index <= Math.round(Number(review.rating || 0)) }"
                        viewBox="0 0 24 24"
                        aria-hidden="true"
                      >
                        <path d="M12 3.8 14.6 9l5.7.8-4.1 4 1 5.7-5.2-2.7-5.2 2.7 1-5.7-4.1-4 5.7-.8Z"></path>
                      </svg>
                    </div>
                  </div>
                </div>

                <p class="pdp-review-copy">{{ review.body || review.title || "Customer feedback submitted for this product." }}</p>
              </article>
            </div>

            <div v-else class="product-review-empty-note pdp-review-note">
              No review has been posted for this product yet.
            </div>
          </div>
        </div>
      </section>

      <section v-if="recommendationDisplayColumns.length > 0" class="pdp-related-board" aria-label="Recommended products">
        <div class="pdp-related-columns">
          <article v-for="column in recommendationDisplayColumns" :key="column.key" class="pdp-related-column">
            <header class="pdp-related-head">
              <h3>{{ column.displayTitle }}</h3>
            </header>

            <div class="pdp-related-stack">
              <article v-for="product in column.products" :key="`${column.key}-${product.id}`" class="pdp-mini-card">
                <RouterLink class="pdp-mini-card-media" :to="getProductDetailUrl(product.id, route.fullPath)">
                  <img
                    :src="product.imagePath"
                    :alt="product.title"
                    width="320"
                    height="320"
                    loading="lazy"
                    decoding="async"
                  >
                </RouterLink>

                <div class="pdp-mini-card-copy">
                  <RouterLink class="pdp-mini-card-title" :to="getProductDetailUrl(product.id, route.fullPath)">
                    {{ product.title }}
                  </RouterLink>
                  <p class="pdp-mini-card-business">{{ getProductBusinessName(product) }}</p>
                  <strong class="pdp-mini-card-price">{{ formatPrice(product.price) }}</strong>
                </div>
              </article>
            </div>
          </article>
        </div>
      </section>
    </section>

    <div v-else class="pets-empty-state">
      Produkti nuk u gjet.
    </div>
  </section>
</template>

<style scoped>
.pdp-page {
  gap: 28px;
  padding-bottom: 24px;
}

.pdp-container {
  gap: 28px;
}

.pdp-breadcrumbs {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  padding: 18px 24px;
  border: 1px solid rgba(15, 23, 42, 0.08);
  border-radius: 22px;
  background: #f8fafc;
  box-shadow: 0 18px 45px rgba(15, 23, 42, 0.06);
}

.pdp-breadcrumb-track {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 10px;
}

.pdp-back-link {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-height: 44px;
  padding: 0 18px;
  border-radius: 999px;
  border: 1px solid rgba(15, 23, 42, 0.12);
  color: #0f172a;
  font-size: 0.9rem;
  font-weight: 700;
  text-decoration: none;
  background: #ffffff;
}

.pdp-hero {
  display: grid;
  grid-template-columns: minmax(0, 1.02fr) minmax(0, 1.08fr);
  gap: 42px;
  padding: 34px;
  border: 1px solid rgba(15, 23, 42, 0.08);
  border-radius: 28px;
  background: #ffffff;
  box-shadow: 0 28px 70px rgba(15, 23, 42, 0.08);
}

.pdp-gallery,
.pdp-info {
  min-width: 0;
}

.pdp-gallery {
  display: grid;
  gap: 20px;
}

.pdp-gallery-stage {
  display: grid;
  place-items: center;
  min-height: 520px;
  padding: 28px;
  border: 1px solid rgba(15, 23, 42, 0.08);
  border-radius: 24px;
  background: #ffffff;
}

.pdp-gallery-image {
  width: 100%;
  max-width: 560px;
  max-height: 460px;
  object-fit: contain;
  display: block;
}

.pdp-gallery-rail {
  display: grid;
  grid-template-columns: auto minmax(0, 1fr) auto;
  gap: 14px;
  align-items: center;
}

.pdp-gallery-thumbnails {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(74px, 1fr));
  gap: 12px;
}

.pdp-gallery-thumb {
  display: grid;
  place-items: center;
  min-height: 86px;
  padding: 8px;
  border: 1px solid rgba(15, 23, 42, 0.08);
  border-radius: 14px;
  background: #ffffff;
  transition: border-color 0.2s ease, transform 0.2s ease, box-shadow 0.2s ease;
}

.pdp-gallery-thumb.active {
  border-color: #ff8a34;
  box-shadow: 0 0 0 3px rgba(255, 138, 52, 0.12);
}

.pdp-gallery-thumb:hover,
.pdp-gallery-arrow:hover,
.pdp-mini-icon:hover,
.pdp-mini-add:hover,
.pdp-utility-action:hover,
.pdp-primary-button:hover,
.pdp-secondary-button:hover,
.pdp-back-link:hover {
  transform: translateY(-1px);
}

.pdp-gallery-thumb img {
  width: 100%;
  aspect-ratio: 1;
  object-fit: contain;
  display: block;
}

.pdp-gallery-arrow {
  width: 52px;
  height: 52px;
  border: 0;
  border-radius: 999px;
  color: #ffffff;
  background: linear-gradient(180deg, #ff9f47, #ff7a1c);
  box-shadow: 0 14px 28px rgba(255, 138, 52, 0.25);
  transition: transform 0.2s ease, box-shadow 0.2s ease;
}

.pdp-gallery-arrow svg,
.pdp-utility-action svg,
.pdp-mini-icon svg,
.pdp-star,
.pdp-review-bar-star {
  width: 18px;
  height: 18px;
  fill: none;
  stroke: currentColor;
  stroke-width: 1.7;
  stroke-linecap: round;
  stroke-linejoin: round;
}

.pdp-info {
  display: grid;
  align-content: start;
  gap: 22px;
}

.pdp-rating-row {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 10px;
  color: #475569;
  font-size: 0.95rem;
}

.pdp-rating-row strong {
  color: #1e293b;
  font-weight: 700;
}

.pdp-stars {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  color: #ff8a34;
}

.pdp-stars--summary {
  justify-content: center;
}

.pdp-stars--mini .pdp-star {
  width: 13px;
  height: 13px;
}

.pdp-star {
  color: rgba(255, 138, 52, 0.28);
}

.pdp-star.is-filled,
.pdp-review-bar-star {
  fill: currentColor;
  color: #ff8a34;
}

.pdp-headline {
  display: grid;
  gap: 10px;
}

.pdp-headline h1 {
  margin: 0;
  color: #1f2937;
  font-size: clamp(2rem, 3vw, 2.9rem);
  line-height: 1.18;
}

.pdp-business-posted {
  margin: 0;
  color: #64748b;
  font-size: 0.98rem;
}

.pdp-business-posted strong {
  color: #111827;
}

.pdp-meta-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 18px;
  padding-bottom: 10px;
  border-bottom: 1px solid rgba(15, 23, 42, 0.08);
}

.pdp-meta-column {
  display: grid;
  gap: 10px;
}

.pdp-meta-column p {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  margin: 0;
  color: #64748b;
  font-size: 0.96rem;
}

.pdp-meta-column strong {
  color: #111827;
  font-weight: 700;
}

.pdp-stock-copy.is-live {
  color: #16a34a;
}

.pdp-price-row {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 14px;
}

.pdp-price-stack {
  display: inline-flex;
  flex-wrap: wrap;
  align-items: baseline;
  gap: 10px;
}

.pdp-price-current {
  color: #0ea5e9;
  font-size: clamp(2rem, 3vw, 2.8rem);
  font-weight: 800;
  line-height: 1;
}

.pdp-price-old {
  color: #94a3b8;
  font-size: 1.15rem;
  font-weight: 700;
  text-decoration: line-through;
}

.pdp-offer-badge {
  display: inline-flex;
  align-items: center;
  min-height: 34px;
  padding: 0 14px;
  border-radius: 8px;
  color: #7c5b00;
  font-size: 0.92rem;
  font-weight: 800;
  background: #ffe168;
}

.pdp-tags {
  gap: 8px;
}

.pdp-tag {
  border-radius: 999px;
  border: 1px solid rgba(15, 23, 42, 0.08);
  background: #f8fafc;
}

.pdp-options-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 16px;
}

.pdp-option-card {
  display: grid;
  gap: 12px;
}

.pdp-option-label {
  margin: 0;
  color: #334155;
  font-size: 0.92rem;
  font-weight: 700;
}

.pdp-color-swatches {
  display: flex;
  flex-wrap: wrap;
  gap: 12px;
}

.pdp-color-swatch {
  position: relative;
  width: 38px;
  height: 38px;
  border: 2px solid rgba(15, 23, 42, 0.08);
  border-radius: 999px;
  background: var(--swatch-color, #d1d5db);
  box-shadow: inset 0 1px 4px rgba(255, 255, 255, 0.46);
}

.pdp-color-swatch.active {
  border-color: #ff8a34;
  box-shadow: 0 0 0 4px rgba(255, 138, 52, 0.16);
}

.pdp-color-swatch.is-unavailable {
  opacity: 0.35;
}

.pdp-select-shell,
.pdp-static-field {
  display: flex;
  align-items: center;
  min-height: 50px;
  padding: 0 16px;
  border: 1px solid rgba(15, 23, 42, 0.12);
  border-radius: 12px;
  background: #ffffff;
}

.pdp-select-shell select {
  width: 100%;
  border: 0;
  background: transparent;
  color: #0f172a;
  font-size: 0.98rem;
  outline: 0;
}

.pdp-static-field {
  color: #111827;
  font-size: 0.98rem;
  font-weight: 600;
}

.pdp-buy-row {
  display: grid;
  grid-template-columns: auto minmax(0, 1fr) auto;
  gap: 14px;
}

.pdp-quantity-box {
  display: inline-flex;
  align-items: center;
  justify-content: space-between;
  min-width: 128px;
  min-height: 56px;
  padding: 0 10px;
  border: 1px solid rgba(15, 23, 42, 0.12);
  border-radius: 12px;
  background: #ffffff;
}

.pdp-quantity-box button {
  width: 38px;
  height: 38px;
  border: 0;
  border-radius: 10px;
  color: #475569;
  font-size: 1.5rem;
  background: transparent;
}

.pdp-quantity-box span {
  min-width: 24px;
  text-align: center;
  color: #0f172a;
  font-size: 1.05rem;
  font-weight: 800;
}

.pdp-primary-button,
.pdp-secondary-button,
.pdp-mini-add {
  min-height: 56px;
  padding: 0 24px;
  border-radius: 12px;
  font-size: 0.98rem;
  font-weight: 800;
  transition: transform 0.2s ease, box-shadow 0.2s ease;
}

.pdp-primary-button {
  border: 0;
  color: #ffffff;
  background: linear-gradient(180deg, #ff9c43, #ff7d1d);
  box-shadow: 0 16px 32px rgba(255, 138, 52, 0.22);
}

.pdp-primary-button.active {
  background: linear-gradient(180deg, #f97316, #ea580c);
}

.pdp-secondary-button {
  border: 1px solid #ff8a34;
  color: #ff8a34;
  background: #ffffff;
}

.pdp-utility-row {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 14px 22px;
  padding-bottom: 6px;
}

.pdp-utility-action {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  border: 0;
  color: #475569;
  font-size: 0.95rem;
  font-weight: 600;
  background: transparent;
  transition: transform 0.2s ease, color 0.2s ease;
}

.pdp-utility-action.active {
  color: #f43f5e;
}

.pdp-utility-action--ghost {
  margin-left: auto;
}

.pdp-checkout-card {
  display: grid;
  gap: 14px;
  padding: 18px 20px;
  border: 1px solid rgba(15, 23, 42, 0.08);
  border-radius: 18px;
  background: #ffffff;
}

.pdp-checkout-title {
  margin: 0;
  color: #334155;
  font-size: 0.98rem;
  font-weight: 700;
}

.pdp-checkout-badges {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
}

.pdp-checkout-badge {
  display: inline-flex;
  align-items: center;
  min-height: 32px;
  padding: 0 10px;
  border-radius: 999px;
  color: #334155;
  font-size: 0.82rem;
  font-weight: 700;
  background: #eff6ff;
}

.pdp-engagement-row {
  grid-template-columns: repeat(4, minmax(0, 1fr));
}

.pdp-engagement-chip {
  border-radius: 16px;
  background: #f8fafc;
  box-shadow: none;
}

.pdp-detail-tabs {
  display: grid;
  gap: 0;
  border: 1px solid rgba(15, 23, 42, 0.08);
  border-radius: 24px;
  background: #ffffff;
  overflow: hidden;
  box-shadow: 0 26px 54px rgba(15, 23, 42, 0.06);
}

.pdp-tab-bar {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 10px;
  padding: 0 18px;
  border-bottom: 1px solid rgba(15, 23, 42, 0.08);
  background: #ffffff;
}

.pdp-tab-button {
  position: relative;
  min-height: 70px;
  padding: 0 18px;
  border: 0;
  color: #64748b;
  font-size: 1rem;
  font-weight: 700;
  background: transparent;
}

.pdp-tab-button.active {
  color: #111827;
}

.pdp-tab-button.active::after {
  content: "";
  position: absolute;
  inset: auto 16px 0;
  height: 3px;
  border-radius: 999px;
  background: #ff8a34;
}

.pdp-tab-panel {
  display: grid;
  gap: 28px;
  padding: 34px;
}

.pdp-description-panel {
  grid-template-columns: minmax(0, 1.42fr) minmax(260px, 0.78fr) minmax(260px, 0.78fr);
  align-items: start;
}

.pdp-description-copy,
.pdp-side-card,
.pdp-info-group,
.pdp-spec-group,
.pdp-review-score-card,
.pdp-review-bars,
.pdp-mini-card-copy {
  display: grid;
  gap: 16px;
}

.pdp-description-copy h2,
.pdp-info-group h3,
.pdp-spec-group h3,
.pdp-side-card h3 {
  margin: 0;
  color: #1f2937;
  font-size: 1.45rem;
}

.pdp-description-copy p,
.pdp-info-paragraph {
  margin: 0;
  color: #475569;
  font-size: 1rem;
  line-height: 1.8;
}

.pdp-side-card {
  padding-left: 28px;
  border-left: 1px solid rgba(15, 23, 42, 0.08);
}

.pdp-bullet-list,
.pdp-side-list {
  display: grid;
  gap: 14px;
  padding: 0;
  margin: 0;
  list-style: none;
}

.pdp-bullet-list li,
.pdp-side-list li {
  display: grid;
  gap: 4px;
  color: #475569;
  font-size: 0.94rem;
  line-height: 1.6;
}

.pdp-bullet-list li {
  grid-template-columns: 24px minmax(0, 1fr);
  align-items: start;
}

.pdp-bullet-list li::before {
  content: "";
  width: 18px;
  height: 18px;
  margin-top: 3px;
  border-radius: 999px;
  background: radial-gradient(circle at 30% 30%, #ffbf80, #ff8a34 62%, #ff6a00 100%);
  box-shadow: 0 6px 14px rgba(255, 138, 52, 0.18);
}

.pdp-bullet-list li strong,
.pdp-side-list li strong {
  color: #111827;
  font-weight: 700;
}

.pdp-bullet-list li > strong,
.pdp-bullet-list li > span {
  grid-column: 2;
}

.pdp-bullet-list--compact li {
  grid-template-columns: 1fr;
}

.pdp-bullet-list--compact li::before {
  display: none;
}

.pdp-bullet-list--compact li > strong,
.pdp-bullet-list--compact li > span {
  grid-column: auto;
}

.pdp-additional-panel,
.pdp-specification-panel {
  grid-template-columns: repeat(3, minmax(0, 1fr));
  align-items: start;
}

.pdp-additional-panel {
  grid-template-columns: minmax(0, 1.2fr) minmax(0, 0.82fr) minmax(0, 0.92fr);
  gap: 36px;
}

.pdp-specification-panel {
  grid-template-columns: 1fr;
  gap: 0;
}

.pdp-spec-columns {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 28px;
}

.pdp-spec-column + .pdp-spec-column {
  padding-left: 28px;
  border-left: 1px solid rgba(15, 23, 42, 0.08);
}

.pdp-info-group,
.pdp-spec-group {
  align-content: start;
}

.pdp-additional-middle,
.pdp-additional-highlights {
  padding-left: 28px;
  border-left: 1px solid rgba(15, 23, 42, 0.08);
}

.pdp-additional-overview-grid {
  display: grid;
  gap: 12px;
}

.pdp-additional-overview-row {
  display: grid;
  grid-template-columns: minmax(150px, 0.9fr) minmax(0, 1fr);
  gap: 18px;
  align-items: start;
}

.pdp-additional-overview-row span {
  color: #111827;
  font-size: 0.95rem;
  font-weight: 600;
}

.pdp-additional-overview-row strong {
  color: #64748b;
  font-size: 0.95rem;
  font-weight: 600;
  line-height: 1.55;
}

.pdp-additional-middle {
  display: grid;
  gap: 22px;
}

.pdp-additional-detail-block {
  display: grid;
  gap: 10px;
}

.pdp-additional-detail-block h3,
.pdp-additional-highlights h3 {
  margin: 0;
  color: #1f2937;
  font-size: 1.2rem;
  font-weight: 800;
}

.pdp-additional-detail-line {
  margin: 0;
  color: #475569;
  font-size: 0.95rem;
  line-height: 1.65;
}

.pdp-additional-highlights-list {
  gap: 12px;
}

.pdp-additional-highlights-list li {
  display: list-item;
  color: #475569;
  font-size: 0.95rem;
  line-height: 1.7;
  list-style: disc;
  margin-left: 18px;
}

.pdp-additional-highlights-list li::before {
  display: none;
}

.pdp-info-pairs,
.pdp-spec-grid {
  display: grid;
  gap: 14px;
}

.pdp-spec-column {
  display: grid;
  gap: 22px;
}

.pdp-spec-group {
  padding-bottom: 18px;
  border-bottom: 1px solid rgba(15, 23, 42, 0.08);
}

.pdp-spec-group:last-child {
  padding-bottom: 0;
  border-bottom: 0;
}

.pdp-info-pair,
.pdp-spec-row {
  display: grid;
  gap: 5px;
}

.pdp-info-pair span,
.pdp-spec-row span {
  color: #64748b;
  font-size: 0.9rem;
}

.pdp-info-pair strong,
.pdp-spec-row strong {
  color: #111827;
  font-size: 1rem;
  font-weight: 700;
}

.pdp-spec-group h3 {
  margin: 0;
  color: #1f2937;
  font-size: 1.05rem;
  font-weight: 800;
}

.pdp-spec-grid {
  gap: 10px;
}

.pdp-spec-row {
  grid-template-columns: minmax(150px, 0.88fr) minmax(0, 1fr);
  gap: 16px;
  align-items: start;
}

.pdp-spec-row span {
  color: #111827;
  font-size: 0.9rem;
  font-weight: 700;
}

.pdp-spec-row strong {
  color: #64748b;
  font-size: 0.9rem;
  font-weight: 600;
  line-height: 1.55;
}

.pdp-reviews-panel {
  gap: 28px;
}

.pdp-review-summary-layout {
  display: grid;
  grid-template-columns: 184px minmax(0, 1fr);
  gap: 18px;
  align-items: start;
}

.pdp-review-score-card {
  place-items: center;
  align-content: center;
  min-height: 170px;
  padding: 20px 16px;
  border-radius: 0;
  background: #fff7cf;
  text-align: center;
}

.pdp-review-score-card strong {
  color: #1f2937;
  font-size: 3rem;
  line-height: 1;
}

.pdp-review-score-card span {
  color: #334155;
  font-size: 0.9rem;
  font-weight: 700;
}

.pdp-review-bars {
  display: grid;
  align-content: start;
  gap: 12px;
  padding-top: 10px;
}

.pdp-review-bar-row {
  display: grid;
  grid-template-columns: 62px minmax(0, 1fr) 112px;
  gap: 12px;
  align-items: center;
  color: #475569;
  font-size: 0.88rem;
}

.pdp-review-bar-label {
  display: inline-flex;
  align-items: center;
  gap: 3px;
  color: #ff8a34;
  font-weight: 700;
}

.pdp-review-bar-track {
  position: relative;
  height: 8px;
  border-radius: 999px;
  overflow: hidden;
  background: #e2e8f0;
}

.pdp-review-bar-fill {
  position: absolute;
  inset: 0 auto 0 0;
  border-radius: 999px;
  background: linear-gradient(90deg, #ffad60, #ff7a1c);
}

.pdp-review-bar-value {
  color: #64748b;
  font-size: 0.82rem;
  font-weight: 600;
}

.pdp-feedback-block {
  display: grid;
  gap: 18px;
}

.pdp-feedback-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 14px;
}

.pdp-feedback-head h3 {
  margin: 0;
  color: #1f2937;
  font-size: 1rem;
  font-weight: 800;
}

.pdp-review-toggle {
  min-height: 38px;
  padding: 0 14px;
  border: 1px solid rgba(255, 138, 52, 0.22);
  border-radius: 999px;
  color: #ff8a34;
  font-size: 0.84rem;
  font-weight: 800;
  background: #fff7ed;
}

.pdp-review-form {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 16px;
  padding: 24px;
  border-radius: 20px;
  background: #f8fafc;
}

.pdp-review-form .field {
  display: grid;
  gap: 8px;
}

.pdp-review-form .field--full {
  grid-column: 1 / -1;
}

.pdp-review-form span {
  color: #334155;
  font-size: 0.92rem;
  font-weight: 700;
}

.pdp-review-form input,
.pdp-review-form select,
.pdp-review-form textarea {
  width: 100%;
  min-height: 48px;
  padding: 12px 14px;
  border: 1px solid rgba(15, 23, 42, 0.12);
  border-radius: 12px;
  color: #111827;
  background: #ffffff;
  resize: vertical;
  outline: none;
}

.pdp-review-form button {
  width: fit-content;
  min-height: 52px;
  padding: 0 24px;
  border: 0;
  border-radius: 12px;
  color: #ffffff;
  font-size: 0.95rem;
  font-weight: 800;
  background: linear-gradient(180deg, #ff9c43, #ff7d1d);
}

.pdp-review-list {
  gap: 0;
}

.pdp-review-item {
  gap: 10px;
  padding: 16px 0;
  border-bottom: 1px solid rgba(15, 23, 42, 0.08);
  background: transparent;
}

.pdp-review-item:last-child {
  padding-bottom: 0;
  border-bottom: 0;
}

.pdp-review-person {
  display: flex;
  align-items: flex-start;
  gap: 12px;
}

.pdp-review-meta {
  display: grid;
  gap: 6px;
}

.pdp-review-author-line {
  display: inline-flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 6px;
}

.pdp-review-author-line strong {
  color: #111827;
  font-size: 0.92rem;
  font-weight: 700;
}

.pdp-review-author-line span {
  color: #64748b;
  font-size: 0.78rem;
  font-weight: 600;
}

.pdp-review-avatar {
  display: grid;
  place-items: center;
  width: 38px;
  height: 38px;
  flex-shrink: 0;
  border-radius: 999px;
  color: #ffffff;
  font-size: 0.8rem;
  font-weight: 800;
}

.pdp-stars--review .pdp-star {
  width: 14px;
  height: 14px;
}

.pdp-review-copy {
  margin: 0;
  padding-left: 50px;
  color: #475569;
  font-size: 0.9rem;
  line-height: 1.7;
}

.pdp-review-note {
  margin: 0;
  padding: 14px 16px;
  border-radius: 14px;
  background: #f8fafc;
}

.pdp-related-board {
  display: grid;
  gap: 18px;
  margin-top: 4px;
}

.pdp-related-columns {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 18px;
}

.pdp-related-column {
  display: grid;
  gap: 18px;
}

.pdp-related-head h3 {
  margin: 0;
  color: #1f2937;
  font-size: 1.14rem;
  font-weight: 800;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}

.pdp-related-stack {
  display: grid;
  gap: 14px;
}

.pdp-mini-card {
  display: grid;
  grid-template-columns: 92px minmax(0, 1fr);
  gap: 14px;
  padding: 14px;
  border: 1px solid rgba(15, 23, 42, 0.08);
  border-radius: 10px;
  background: #ffffff;
  box-shadow: none;
}

.pdp-mini-card-media {
  display: grid;
  place-items: center;
  border-radius: 8px;
  background: #ffffff;
  overflow: hidden;
}

.pdp-mini-card-media img {
  width: 100%;
  aspect-ratio: 1;
  object-fit: contain;
  display: block;
}

.pdp-mini-card-business {
  margin: 0;
  color: #64748b;
  font-size: 0.8rem;
  font-weight: 600;
}

.pdp-mini-card-title {
  color: #111827;
  font-size: 0.95rem;
  font-weight: 700;
  line-height: 1.4;
  text-decoration: none;
  display: -webkit-box;
  overflow: hidden;
  -webkit-line-clamp: 3;
  -webkit-box-orient: vertical;
}

.pdp-mini-card-price {
  color: #1d9bf0;
  font-size: 1rem;
  font-weight: 800;
}

@media (max-width: 1160px) {
  .pdp-hero {
    grid-template-columns: 1fr;
  }

  .pdp-side-card {
    padding-top: 16px;
    padding-left: 0;
    border-top: 1px solid rgba(15, 23, 42, 0.08);
    border-left: 0;
  }

  .pdp-description-panel,
  .pdp-additional-panel,
  .pdp-related-columns {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }

  .pdp-additional-panel {
    grid-template-columns: 1fr;
  }

  .pdp-spec-columns {
    grid-template-columns: 1fr;
  }

  .pdp-spec-column + .pdp-spec-column {
    padding-top: 16px;
    padding-left: 0;
    border-top: 1px solid rgba(15, 23, 42, 0.08);
    border-left: 0;
  }

  .pdp-additional-middle,
  .pdp-additional-highlights {
    padding-top: 16px;
    padding-left: 0;
    border-top: 1px solid rgba(15, 23, 42, 0.08);
    border-left: 0;
  }
}

@media (max-width: 820px) {
  .pdp-page {
    width: min(100%, calc(100% - 20px));
    gap: 22px;
  }

  .pdp-breadcrumbs,
  .pdp-hero,
  .pdp-tab-panel {
    padding: 20px;
  }

  .pdp-breadcrumbs {
    flex-direction: column;
    align-items: flex-start;
  }

  .pdp-meta-grid,
  .pdp-options-grid,
  .pdp-review-summary-layout,
  .pdp-review-form {
    grid-template-columns: 1fr;
  }

  .pdp-buy-row {
    grid-template-columns: 1fr;
  }

  .pdp-quantity-box,
  .pdp-primary-button,
  .pdp-secondary-button {
    width: 100%;
  }

  .pdp-engagement-row {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

@media (max-width: 640px) {
  .pdp-gallery-stage {
    min-height: 320px;
    padding: 20px;
  }

  .pdp-gallery-rail {
    grid-template-columns: 1fr;
  }

  .pdp-gallery-arrow {
    display: none;
  }

  .pdp-tab-bar {
    justify-content: flex-start;
    overflow-x: auto;
    scrollbar-width: none;
  }

  .pdp-tab-bar::-webkit-scrollbar {
    display: none;
  }

  .pdp-tab-button {
    min-height: 58px;
    white-space: nowrap;
  }

  .pdp-additional-panel,
  .pdp-related-columns {
    grid-template-columns: 1fr;
  }

  .pdp-additional-overview-row {
    grid-template-columns: 1fr;
    gap: 6px;
  }

  .pdp-spec-row {
    grid-template-columns: 1fr;
    gap: 4px;
  }

  .pdp-mini-card {
    grid-template-columns: 82px minmax(0, 1fr);
  }
}
</style>
