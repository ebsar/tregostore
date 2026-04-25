<script setup>
import { computed, onMounted, reactive, ref } from "vue";
import { RouterLink, useRouter } from "vue-router";
import DashboardBarChart from "../components/dashboard/DashboardBarChart.vue";
import DashboardDonutChart from "../components/dashboard/DashboardDonutChart.vue";
import DashboardShell from "../components/dashboard/DashboardShell.vue";
import ProductCard from "../components/ProductCard.vue";
import { fetchHomeRecommendations, requestJson, resolveApiMessage } from "../lib/api";
import { getAccountDashboardMenuItems } from "../lib/account-navigation";
import { formatCount, formatDateLabel, formatPrice, getBusinessInitials, getProductDetailUrl, normalizeAddress } from "../lib/shop";
import { appState, ensureSessionLoaded, logoutUser, markRouteReady } from "../stores/app-state";

const router = useRouter();
const orders = ref([]);
const savedAddress = ref(null);
const recommendationSections = ref([]);
const adminOrders = ref([]);
const adminProducts = ref([]);
const adminUsers = ref([]);
const adminReports = ref([]);
const dashboardProductPage = ref(0);
const accountSearchQuery = ref("");
const ui = reactive({
  message: "",
  type: "",
});

const isClientUser = computed(() =>
  Boolean(appState.user) && !["admin", "business"].includes(String(appState.user?.role || "").trim().toLowerCase()),
);
const isAdminUser = computed(() => normalizedRole.value === "admin");
const isBusinessUser = computed(() => normalizedRole.value === "business");
const normalizedRole = computed(() => String(appState.user?.role || "client").trim().toLowerCase());

const dashboardMenuItems = computed(() => getAccountDashboardMenuItems(appState.user, "dashboard"));
const accountShellNavItems = computed(() =>
  dashboardMenuItems.value.map((item) => ({
    key: item.key,
    label: item.label,
    icon: item.icon,
    to: item.href,
    group: item.group,
    badge: item.badge,
  })),
);
const dashboardRoleLabel = computed(() => {
  if (normalizedRole.value === "admin") {
    return "Admin workspace";
  }
  if (normalizedRole.value === "business") {
    return "Business workspace";
  }
  return "Customer account";
});
const dashboardIntroCopy = computed(() => {
  if (normalizedRole.value === "admin") {
    return "Use this space to jump into product moderation, order oversight, and marketplace management without hunting through multiple pages.";
  }
  if (normalizedRole.value === "business") {
    return "This account page stays lightweight and points you straight into your business tools, orders, and storefront settings.";
  }
  return "Track orders, manage addresses, and get back to the products and stores that matter most without extra steps.";
});
const dashboardQuickActions = computed(() => {
  const preferredKeys = normalizedRole.value === "admin"
    ? ["products", "inventory", "orders", "businesses"]
    : normalizedRole.value === "business"
      ? ["products", "inventory", "orders", "settings"]
      : ["orders", "payments", "wishlist", "support"];

  return preferredKeys
    .map((key) => dashboardMenuItems.value.find((item) => item.key === key))
    .filter(Boolean)
    .slice(0, 4);
});
const dashboardNotificationCount = computed(() =>
  isAdminUser.value
    ? adminReports.value.filter((report) =>
      !["resolved", "dismissed"].includes(String(report.status || "").trim().toLowerCase()),
    ).length
    : orders.value.filter((order) =>
      [
        "pending_confirmation",
        "confirmed",
        "packed",
        "shipped",
        "partially_confirmed",
      ].includes(String(order.fulfillmentStatus || order.status || "").trim().toLowerCase()),
    ).length,
);

const greetingName = computed(() => {
  const fullName = String(appState.user?.fullName || appState.user?.businessName || "User").trim();
  return fullName.split(/\s+/)[0] || fullName;
});

const userAvatarLabel = computed(() =>
  getBusinessInitials(appState.user?.fullName || appState.user?.businessName || "Tregio"),
);
const dashboardIdentityImage = computed(() => {
  if (normalizedRole.value === "business") {
    return String(appState.user?.businessLogoPath || "").trim();
  }

  return String(appState.user?.profileImagePath || "").trim();
});
const dashboardIdentityIcon = computed(() => {
  if (normalizedRole.value === "business") {
    return "store";
  }

  return normalizedRole.value === "admin" ? "users" : "user";
});

const accountLocationLabel = computed(() => {
  const city = String(savedAddress.value?.city || "").trim();
  const country = String(savedAddress.value?.country || "").trim();
  if (city && country) {
    return `${city}, ${country}`;
  }

  return formatDateLabel(appState.user?.createdAt || "") || "Anetar i Tregio";
});

const dashboardSummary = computed(() => {
  const totalOrders = orders.value.length;
  const pendingOrders = orders.value.filter((order) =>
    [
      "pending_confirmation",
      "confirmed",
      "packed",
      "shipped",
      "partially_confirmed",
    ].includes(String(order.fulfillmentStatus || order.status || "").trim().toLowerCase()),
  ).length;
  const completedOrders = orders.value.filter((order) =>
    ["delivered", "returned"].includes(String(order.fulfillmentStatus || order.status || "").trim().toLowerCase()),
  ).length;

  return [
    {
      label: "Total Orders",
      value: totalOrders,
      tone: "sky",
      icon: "rocket",
    },
    {
      label: "Pending Orders",
      value: pendingOrders,
      tone: "peach",
      icon: "receipt",
    },
    {
      label: "Completed Orders",
      value: completedOrders,
      tone: "mint",
      icon: "box",
    },
  ];
});

const adminBusinessCount = computed(() =>
  adminUsers.value.filter((user) => String(user.role || "").trim().toLowerCase() === "business").length,
);

const adminOpenReportsCount = computed(() =>
  adminReports.value.filter((report) =>
    !["resolved", "dismissed"].includes(String(report.status || "").trim().toLowerCase()),
  ).length,
);

const adminPublicProductsCount = computed(() =>
  adminProducts.value.filter((product) => Boolean(product.isPublic)).length,
);

const adminInStockProductsCount = computed(() =>
  adminProducts.value.filter((product) => Number(product.stockQuantity || 0) > 0).length,
);

const adminOverviewSummary = computed(() => ([
  {
    label: "Products",
    value: formatCount(adminProducts.value.length),
    meta: `${formatCount(adminPublicProductsCount.value)} public`,
  },
  {
    label: "Orders",
    value: formatCount(adminOrders.value.length),
    meta: "Across the marketplace",
  },
  {
    label: "Businesses",
    value: formatCount(adminBusinessCount.value),
    meta: `${formatCount(adminUsers.value.length)} total users`,
  },
  {
    label: "Open reports",
    value: formatCount(adminOpenReportsCount.value),
    meta: `${formatCount(adminReports.value.length)} total reports`,
  },
]));

const adminOrderSummary = computed(() => {
  const pending = adminOrderCounts.value.pending;
  const completed = adminOrderCounts.value.completed;
  const issues = adminOrderCounts.value.issues;

  return [
    { label: "Total orders", value: formatCount(adminOrders.value.length), meta: "All marketplace orders" },
    { label: "In progress", value: formatCount(pending), meta: "Need active monitoring" },
    { label: "Completed", value: formatCount(completed), meta: "Delivered or returned" },
    { label: "Issues", value: formatCount(issues), meta: "Canceled, failed, or refunded" },
  ];
});

const adminOrderCounts = computed(() => ({
  pending: adminOrders.value.filter((order) =>
    ["pending_confirmation", "confirmed", "packed", "shipped", "partially_confirmed"]
      .includes(String(order.fulfillmentStatus || order.status || "").trim().toLowerCase()),
  ).length,
  completed: adminOrders.value.filter((order) =>
    ["delivered", "returned"].includes(String(order.fulfillmentStatus || order.status || "").trim().toLowerCase()),
  ).length,
  issues: adminOrders.value.filter((order) =>
    ["canceled", "cancelled", "failed", "refunded"].includes(String(order.fulfillmentStatus || order.status || "").trim().toLowerCase()),
  ).length,
}));

const adminProductSummary = computed(() => ([
  { label: "Total products", value: formatCount(adminProducts.value.length), meta: "Across all vendors" },
  { label: "Public", value: formatCount(adminPublicProductsCount.value), meta: "Visible in marketplace" },
  { label: "In stock", value: formatCount(adminInStockProductsCount.value), meta: "Available now" },
  {
    label: "Hidden",
    value: formatCount(Math.max(0, adminProducts.value.length - adminPublicProductsCount.value)),
    meta: "Not publicly visible",
  },
]));

const adminEngagementSummary = computed(() => {
  const totals = adminProducts.value.reduce((accumulator, product) => {
    accumulator.viewsCount += Number(product.viewsCount || 0);
    accumulator.wishlistCount += Number(product.wishlistCount || 0);
    accumulator.cartCount += Number(product.cartCount || 0);
    accumulator.shareCount += Number(product.shareCount || 0);
    return accumulator;
  }, {
    viewsCount: 0,
    wishlistCount: 0,
    cartCount: 0,
    shareCount: 0,
  });

  return [
    { label: "Views", value: formatCount(totals.viewsCount), meta: "Product detail traffic" },
    { label: "Wishlist", value: formatCount(totals.wishlistCount), meta: "Saved by users" },
    { label: "Cart", value: formatCount(totals.cartCount), meta: "Added to cart" },
    { label: "Share", value: formatCount(totals.shareCount), meta: "Shared externally" },
  ];
});

const adminPlatformMixBars = computed(() => ([
  { label: "Products", value: adminProducts.value.length },
  { label: "Orders", value: adminOrders.value.length },
  { label: "Users", value: adminUsers.value.length },
  { label: "Reports", value: adminReports.value.length },
]));

const adminOrderStatusBars = computed(() => [
  { label: "In progress", value: adminOrderCounts.value.pending },
  { label: "Completed", value: adminOrderCounts.value.completed },
  { label: "Issues", value: adminOrderCounts.value.issues },
]);

const adminRoleDistribution = computed(() => ([
  {
    label: "Customers",
    value: adminUsers.value.filter((user) => {
      const role = String(user.role || "").trim().toLowerCase();
      return role === "client" || role === "user";
    }).length,
  },
  { label: "Businesses", value: adminBusinessCount.value },
  {
    label: "Admins",
    value: adminUsers.value.filter((user) => String(user.role || "").trim().toLowerCase() === "admin").length,
  },
]));

const sortedOrders = computed(() =>
  [...orders.value].sort((left, right) => {
    const leftTime = new Date(String(left?.createdAt || left?.created_at || "")).getTime();
    const rightTime = new Date(String(right?.createdAt || right?.created_at || "")).getTime();
    if (Number.isFinite(leftTime) && Number.isFinite(rightTime) && leftTime !== rightTime) {
      return rightTime - leftTime;
    }

    return Number(right?.id || 0) - Number(left?.id || 0);
  }),
);

const recentOrders = computed(() => sortedOrders.value.slice(0, 3));

const fallbackRecentProducts = computed(() => {
  const flattenedItems = sortedOrders.value.flatMap((order) =>
    (Array.isArray(order?.items) ? order.items : []).map((item, index) => ({
      id: Number(item?.productId || item?.product_id || item?.id || 0) || `recent-${order.id}-${index}`,
      title: String(item?.title || item?.productTitle || "Produkt").trim(),
      imagePath: String(item?.imagePath || item?.image_path || item?.image || "/bujqesia.webp").trim(),
      businessName: String(item?.businessName || "").trim(),
      price: Number(item?.unitPrice || item?.price || item?.totalPrice || 0),
      averageRating: Number(item?.averageRating || item?.ratingAverage || 0),
      reviewCount: Number(item?.reviewCount || 0),
    })),
  );

  const seen = new Set();
  return flattenedItems.filter((item) => {
    const key = String(item.id || item.title).trim();
    if (!key || seen.has(key)) {
      return false;
    }

    seen.add(key);
    return true;
  });
});

const dashboardProductSource = computed(() => {
  const preferredSection = recommendationSections.value.find((section) => section.key === "recommended-for-you")
    || recommendationSections.value.find((section) => section.key === "best-sellers")
    || recommendationSections.value.find((section) => section.key === "new-arrivals")
    || recommendationSections.value[0]
    || null;

  if (Array.isArray(preferredSection?.products) && preferredSection.products.length > 0) {
    return preferredSection.products.slice(0, 12);
  }

  return fallbackRecentProducts.value.slice(0, 12);
});

const dashboardProductTitle = computed(() =>
  recommendationSections.value.length > 0 ? "FOR YOU" : "RECENT ORDER",
);

const dashboardProductPageCount = computed(() =>
  Math.max(1, Math.ceil(dashboardProductSource.value.length / 4)),
);

const activeDashboardProductPage = computed(() =>
  Math.min(dashboardProductPage.value, Math.max(0, dashboardProductPageCount.value - 1)),
);

const dashboardProductRail = computed(() => {
  const start = activeDashboardProductPage.value * 4;
  return dashboardProductSource.value.slice(start, start + 4);
});

const primaryAddressLines = computed(() => {
  const address = savedAddress.value;
  if (!address) {
    return ["Nuk ke ruajtur ende adresë kryesore."];
  }

  const lines = [
    String(address.addressLine || "").trim(),
    [String(address.city || "").trim(), String(address.country || "").trim()].filter(Boolean).join(", "),
    String(address.zipCode || "").trim() ? `ZIP: ${String(address.zipCode || "").trim()}` : "",
    String(address.phoneNumber || "").trim() ? `Phone: ${String(address.phoneNumber || "").trim()}` : "",
    String(appState.user?.email || "").trim() ? `Email: ${String(appState.user?.email || "").trim()}` : "",
  ].filter(Boolean);

  return lines.length > 0 ? lines : ["Nuk ke ruajtur ende adresë kryesore."];
});

onMounted(async () => {
  try {
    const user = await ensureSessionLoaded();
    if (!user) {
      router.replace("/login");
      return;
    }

    const requests = [loadAddress()];
    if (isClientUser.value) {
      requests.push(loadOrders());
      requests.push(loadDashboardRecommendations());
    } else if (isAdminUser.value) {
      requests.push(loadAdminDashboardData());
    }
    await Promise.all(requests);
  } finally {
    markRouteReady();
  }
});

async function loadOrders() {
  const { response, data } = await requestJson("/api/orders");
  if (!response.ok || !data?.ok) {
    orders.value = [];
    if (!ui.message) {
      ui.message = resolveApiMessage(data, "Porosite nuk u ngarkuan.");
      ui.type = "error";
    }
    return;
  }

  orders.value = Array.isArray(data.orders) ? data.orders : [];
}

async function loadAddress() {
  const { response, data } = await requestJson("/api/address");
  if (!response.ok || !data?.ok) {
    savedAddress.value = null;
    return;
  }

  savedAddress.value = data.address ? normalizeAddress(data.address) : null;
}

async function loadDashboardRecommendations() {
  const payload = await fetchHomeRecommendations(12);
  recommendationSections.value = Array.isArray(payload.sections) ? payload.sections : [];
}

async function loadAdminDashboardData() {
  await Promise.all([
    loadAdminOrders(),
    loadAdminProducts(),
    loadAdminUsers(),
    loadAdminReports(),
  ]);
}

async function loadAdminOrders() {
  const { response, data } = await requestJson("/api/admin/orders");
  if (!response.ok || !data?.ok) {
    adminOrders.value = [];
    if (!ui.message) {
      ui.message = resolveApiMessage(data, "Admin orders could not be loaded.");
      ui.type = "error";
    }
    return;
  }

  adminOrders.value = Array.isArray(data.orders) ? data.orders : [];
}

async function loadAdminProducts() {
  const { response, data } = await requestJson("/api/admin/products");
  if (!response.ok || !data?.ok) {
    adminProducts.value = [];
    if (!ui.message) {
      ui.message = resolveApiMessage(data, "Admin products could not be loaded.");
      ui.type = "error";
    }
    return;
  }

  adminProducts.value = Array.isArray(data.products) ? data.products : [];
}

async function loadAdminUsers() {
  const { response, data } = await requestJson("/api/admin/users");
  if (!response.ok || !data?.ok) {
    adminUsers.value = [];
    if (!ui.message) {
      ui.message = resolveApiMessage(data, "Admin users could not be loaded.");
      ui.type = "error";
    }
    return;
  }

  adminUsers.value = Array.isArray(data.users) ? data.users : [];
}

async function loadAdminReports() {
  const { response, data } = await requestJson("/api/admin/reports");
  if (!response.ok || !data?.ok) {
    adminReports.value = [];
    if (!ui.message) {
      ui.message = resolveApiMessage(data, "Admin reports could not be loaded.");
      ui.type = "error";
    }
    return;
  }

  adminReports.value = Array.isArray(data.reports) ? data.reports : [];
}

async function handleLogout() {
  ui.message = "";
  const { response, data } = await logoutUser();
  if (!response.ok || !data?.ok) {
    ui.message = data?.message || "Dalja nga llogaria nuk funksionoi.";
    ui.type = "error";
    return;
  }

  router.push("/");
}

async function handleAccountDashboardSearch() {
  const query = String(accountSearchQuery.value || "").trim();
  await router.push({
    path: "/kerko",
    query: query ? { q: query } : {},
  });
}

function renderDashboardIcon(icon) {
  switch (icon) {
    case "dashboard":
      return "M4 5.5A1.5 1.5 0 0 1 5.5 4H11v6.5H4Zm9 0V4h5.5A1.5 1.5 0 0 1 20 5.5V11h-7ZM4 13h7v7H5.5A1.5 1.5 0 0 1 4 18.5Zm9 0h7v5.5A1.5 1.5 0 0 1 18.5 20H13Z";
    case "orders":
      return "M6 5h12a1 1 0 0 1 1 1v12H5V6a1 1 0 0 1 1-1Zm2 3h8M8 11h8M8 14h5";
    case "pin":
      return "M12 21s6-5.6 6-10.2A6 6 0 1 0 6 10.8C6 15.4 12 21 12 21Zm0-8a2 2 0 1 1 0-4 2 2 0 0 1 0 4Z";
    case "bag":
      return "M4 7h16l-1.4 11.2A2 2 0 0 1 16.6 20H7.4a2 2 0 0 1-2-1.8ZM9 9V6.8A3 3 0 0 1 12 4a3 3 0 0 1 3 2.8V9";
    case "heart":
      return "m12 20.4-1.2-1C5.4 14.6 2 11.5 2 7.8A4.8 4.8 0 0 1 6.8 3 5.3 5.3 0 0 1 12 5.9 5.3 5.3 0 0 1 17.2 3 4.8 4.8 0 0 1 22 7.8c0 3.7-3.4 6.8-8.8 11.6z";
    case "compare":
      return "M6.9 8.7a5.1 5.1 0 0 1 8.7-1.5l1.3-1.3v4.2h-4.2l1.5-1.5a3 3 0 1 0 .9 2.1h2.1a5.1 5.1 0 1 1-10.3 0c0-.3 0-.7.1-1zM17.1 15.3a5.1 5.1 0 0 1-8.7 1.5L7.1 18v-4.2h4.2l-1.5 1.5a3 3 0 1 0-.9-2.1H6.8a5.1 5.1 0 1 1 10.3 0c0 .3 0 .7-.1 1z";
    case "card":
      return "M3 7.5A2.5 2.5 0 0 1 5.5 5h13A2.5 2.5 0 0 1 21 7.5v9a2.5 2.5 0 0 1-2.5 2.5h-13A2.5 2.5 0 0 1 3 16.5Zm0 2.2h18M7 15h3";
    case "history":
      return "M12 6v6l4 2M4.9 7.8H2V3.9m.5 3.9A9 9 0 1 1 5 18";
    case "settings":
      return "M12 8.2a3.8 3.8 0 1 1 0 7.6 3.8 3.8 0 0 1 0-7.6Zm8 4-1.7.8c-.1.4-.3.8-.5 1.2l.7 1.8-1.7 1.7-1.8-.7c-.4.2-.8.4-1.2.5L12 20l-2.4-.7c-.4-.1-.8-.3-1.2-.5l-1.8.7-1.7-1.7.7-1.8c-.2-.4-.4-.8-.5-1.2L4 12.2l.8-2.2c.1-.4.3-.8.5-1.2l-.7-1.8L6.3 5l1.8.7c.4-.2.8-.4 1.2-.5L12 4l2.4.7c.4.1.8.3 1.2.5l1.8-.7 1.7 1.7-.7 1.8c.2.4.4.8.5 1.2Z";
    case "rocket":
      return "M12.5 3c3.7 0 6.5 2.8 6.5 6.5 0 4.8-3.9 8.8-8.8 8.8H7.5v-2.7L4 12l3.5-3.5V5.7h2.7C12.2 4.2 12.3 3.6 12.5 3Zm-.4 6.4a1.8 1.8 0 1 0 0-3.6 1.8 1.8 0 0 0 0 3.6Z";
    case "receipt":
      return "M6 3h12v18l-2.6-1.6L12 21l-3.4-1.6L6 21Zm3 5h6M9 11h6M9 14h4";
    case "box":
      return "M4.8 8.1 12 4l7.2 4.1V16L12 20l-7.2-4ZM12 12l7.2-3.9M12 12 4.8 8.1M12 12v8";
    default:
      return "";
  }
}

function formatDashboardOrderStatus(order) {
  const status = String(order?.fulfillmentStatus || order?.status || "").trim().toLowerCase();
  if (["delivered", "returned"].includes(status)) {
    return "COMPLETED";
  }

  if (["canceled", "cancelled", "failed", "refunded"].includes(status)) {
    return "CANCELED";
  }

  return "IN PROGRESS";
}

function dashboardOrderStatusClass(order) {
  const label = formatDashboardOrderStatus(order).toLowerCase();
  if (label === "completed") {
    return "is-completed";
  }

  if (label === "canceled") {
    return "is-canceled";
  }

  return "is-progress";
}

function formatDashboardOrderDate(value) {
  if (!value) {
    return "-";
  }

  const parsedDate = new Date(String(value).replace(" ", "T"));
  if (Number.isNaN(parsedDate.getTime())) {
    return String(value);
  }

  return parsedDate.toLocaleString("en-US", {
    month: "short",
    day: "2-digit",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

function formatDashboardOrderTotal(order) {
  return `${formatPrice(order?.totalPrice || 0)} (${Number(order?.totalItems || 0)} Products)`;
}

function productCardHref(product) {
  if (!product?.id) {
    return "/kerko";
  }

  return getProductDetailUrl(product.id, "/llogaria");
}

function productFilledStars(product) {
  const rating = Number(product?.averageRating ?? product?.ratingAverage ?? 0);
  if (!Number.isFinite(rating) || rating <= 0) {
    return 0;
  }

  return Math.max(0, Math.min(5, Math.round(rating)));
}

function productReviewCount(product) {
  const count = Number(product?.reviewCount ?? product?.buyersCount ?? product?.unitsSold ?? 0);
  if (!Number.isFinite(count) || count <= 0) {
    return 0;
  }

  return Math.trunc(count);
}

function goToPreviousDashboardProductPage() {
  if (dashboardProductPageCount.value <= 1) {
    return;
  }

  dashboardProductPage.value = activeDashboardProductPage.value <= 0
    ? dashboardProductPageCount.value - 1
    : activeDashboardProductPage.value - 1;
}

function goToNextDashboardProductPage() {
  if (dashboardProductPageCount.value <= 1) {
    return;
  }

  dashboardProductPage.value = activeDashboardProductPage.value >= dashboardProductPageCount.value - 1
    ? 0
    : activeDashboardProductPage.value + 1;
}
</script>

<template>
  <section class="market-page market-page--wide dashboard-page" aria-label="Llogaria ime">
    <div
      v-if="ui.message"
      class="market-status"
      :class="{ 'market-status--error': ui.type === 'error', 'market-status--success': ui.type === 'success' }"
      role="status"
      aria-live="polite"
    >
      {{ ui.message }}
    </div>

    <DashboardShell
      v-if="appState.user"
      :nav-items="accountShellNavItems"
      active-key="dashboard"
      :brand-initial="userAvatarLabel"
      :brand-title="appState.user.fullName || appState.user.businessName || 'Tregio User'"
      :brand-subtitle="dashboardRoleLabel"
      :brand-image-path="dashboardIdentityImage"
      :brand-fallback-icon="dashboardIdentityIcon"
      :profile-image-path="dashboardIdentityImage"
      :profile-fallback-icon="dashboardIdentityIcon"
      :profile-name="appState.user.fullName || appState.user.businessName || 'Tregio User'"
      :profile-subtitle="accountLocationLabel"
      :notification-count="dashboardNotificationCount"
      :search-query="accountSearchQuery"
      search-placeholder="Search marketplace"
      @update:search-query="accountSearchQuery = $event"
      @submit-search="handleAccountDashboardSearch"
    >
      <template #sidebar-footer>
        <button type="button" @click="handleLogout">
          <svg viewBox="0 0 24 24" aria-hidden="true">
            <path d="M15 5h4v14h-4M10 8l4 4-4 4M14 12H4" />
          </svg>
          <span>Log out</span>
        </button>
      </template>

      <header class="dashboard-section dashboard-page__hero">
        <div class="dashboard-section__head">
          <div class="market-page__header-copy">
            <p class="market-page__eyebrow">{{ dashboardRoleLabel }}</p>
            <h1>Hello, {{ greetingName }}</h1>
            <p>{{ dashboardIntroCopy }}</p>
          </div>
          <span class="dashboard-badge dashboard-badge--success">{{ accountLocationLabel }}</span>
        </div>

        <div class="dashboard-shortcuts">
          <RouterLink
            v-for="item in dashboardQuickActions"
            :key="`shortcut-${item.key}`"
            class="dashboard-shortcut"
            :to="item.href"
          >
            <strong>{{ item.label }}</strong>
            <span>Open {{ item.label.toLowerCase() }}</span>
          </RouterLink>
        </div>
      </header>

      <template v-if="isAdminUser">
        <section class="dashboard-section-group">
          <div class="dashboard-section__head">
            <div>
              <p class="market-page__eyebrow">Overview</p>
              <h2>Marketplace dashboard</h2>
              <p class="dashboard-note">Keep admin signal grouped by category so products, orders, and moderation stay easier to scan.</p>
            </div>
          </div>

          <div class="metric-grid">
            <article v-for="item in adminOverviewSummary" :key="`admin-overview-${item.label}`" class="metric-card">
              <p class="metric-card__label">{{ item.label }}</p>
              <strong>{{ item.value }}</strong>
              <span class="section-heading__copy">{{ item.meta }}</span>
            </article>
          </div>
        </section>

        <section class="dashboard-section-group">
          <div class="dashboard-section__head">
            <div>
              <p class="market-page__eyebrow">Orders</p>
              <h2>Order history metrics</h2>
              <p class="dashboard-note">Live order flow and exceptions are now surfaced here instead of being buried inside the orders page.</p>
            </div>
            <RouterLink class="market-button market-button--ghost" to="/admin-porosite">
              View orders
            </RouterLink>
          </div>

          <div class="metric-grid">
            <article v-for="item in adminOrderSummary" :key="`admin-orders-${item.label}`" class="metric-card">
              <p class="metric-card__label">{{ item.label }}</p>
              <strong>{{ item.value }}</strong>
              <span class="section-heading__copy">{{ item.meta }}</span>
            </article>
          </div>

          <div class="dashboard-chart-grid">
            <section class="dashboard-section dashboard-chart-card">
              <div class="dashboard-section__head">
                <div>
                  <p class="market-page__eyebrow">Orders</p>
                  <h2>Status mix</h2>
                </div>
              </div>

              <DashboardBarChart :items="adminOrderStatusBars" />
            </section>

            <section class="dashboard-section dashboard-chart-card">
              <div class="dashboard-section__head">
                <div>
                  <p class="market-page__eyebrow">Users</p>
                  <h2>Role distribution</h2>
                </div>
              </div>

              <DashboardDonutChart :items="adminRoleDistribution" />
            </section>
          </div>
        </section>

        <section class="dashboard-section-group">
          <div class="dashboard-section__head">
            <div>
              <p class="market-page__eyebrow">Products</p>
              <h2>Catalog metrics</h2>
              <p class="dashboard-note">Product counts and engagement are grouped together so the product page can stay focused on management actions.</p>
            </div>
            <RouterLink class="market-button market-button--ghost" to="/admin-products/inventory">
              View inventory
            </RouterLink>
          </div>

          <div class="metric-grid">
            <article v-for="item in adminProductSummary" :key="`admin-products-${item.label}`" class="metric-card">
              <p class="metric-card__label">{{ item.label }}</p>
              <strong>{{ item.value }}</strong>
              <span class="section-heading__copy">{{ item.meta }}</span>
            </article>
          </div>

          <div class="metric-grid">
            <article v-for="item in adminEngagementSummary" :key="`admin-engagement-${item.label}`" class="metric-card">
              <p class="metric-card__label">{{ item.label }}</p>
              <strong>{{ item.value }}</strong>
              <span class="section-heading__copy">{{ item.meta }}</span>
            </article>
          </div>
        </section>

        <section class="dashboard-section-group">
          <div class="dashboard-section__head">
            <div>
              <p class="market-page__eyebrow">Users & Moderation</p>
              <h2>Operational mix</h2>
              <p class="dashboard-note">Platform counts and moderation load stay in one place for quicker admin decisions.</p>
            </div>
            <RouterLink class="market-button market-button--ghost" to="/bizneset-e-regjistruara">
              View businesses
            </RouterLink>
          </div>

          <div class="dashboard-chart-grid">
            <section class="dashboard-section dashboard-chart-card">
              <div class="dashboard-section__head">
                <div>
                  <p class="market-page__eyebrow">Marketplace</p>
                  <h2>Operational mix</h2>
                </div>
              </div>

              <DashboardBarChart :items="adminPlatformMixBars" />
            </section>

            <section class="dashboard-section">
              <div class="dashboard-section__head">
                <div>
                  <p class="market-page__eyebrow">Moderation</p>
                  <h2>Need attention</h2>
                </div>
              </div>

              <div class="metric-grid metric-grid--compact">
                <article class="metric-card">
                  <p class="metric-card__label">Total users</p>
                  <strong>{{ formatCount(adminUsers.length) }}</strong>
                  <span class="section-heading__copy">All registered accounts</span>
                </article>
                <article class="metric-card">
                  <p class="metric-card__label">Businesses</p>
                  <strong>{{ formatCount(adminBusinessCount) }}</strong>
                  <span class="section-heading__copy">Vendor accounts</span>
                </article>
                <article class="metric-card">
                  <p class="metric-card__label">Open reports</p>
                  <strong>{{ formatCount(adminOpenReportsCount) }}</strong>
                  <span class="section-heading__copy">Need review</span>
                </article>
              </div>
            </section>
          </div>
        </section>
      </template>

      <section v-if="isClientUser && dashboardSummary.length > 0" class="metric-grid">
        <article v-for="stat in dashboardSummary" :key="stat.label" class="metric-card">
          <p class="metric-card__label">{{ stat.label }}</p>
          <strong>{{ stat.value }}</strong>
          <span>{{ stat.tone === 'mint' ? 'Updated from your order history' : 'Based on your recent account activity' }}</span>
        </article>
      </section>

      <div class="market-grid--split">
        <section class="dashboard-section">
          <div class="dashboard-section__head">
            <div>
              <p class="market-page__eyebrow">Account</p>
              <h2>Profile details</h2>
            </div>
            <RouterLink class="market-button market-button--ghost" to="/te-dhenat-personale">
              Edit account
            </RouterLink>
          </div>

          <div class="dashboard-shortcut">
            <strong>{{ appState.user.fullName || appState.user.businessName || "Tregio User" }}</strong>
            <span>{{ appState.user.email || "-" }}</span>
            <span>Phone: {{ savedAddress?.phoneNumber || appState.user.phoneNumber || "-" }}</span>
            <span>Joined: {{ formatDateLabel(appState.user.createdAt || "") || "-" }}</span>
          </div>
        </section>

        <section class="dashboard-section">
          <div class="dashboard-section__head">
            <div>
              <p class="market-page__eyebrow">Addresses</p>
              <h2>Primary address</h2>
            </div>
            <RouterLink class="market-button market-button--ghost" to="/adresat">
              Manage addresses
            </RouterLink>
          </div>

          <div class="dashboard-shortcut">
            <strong>{{ appState.user.fullName || appState.user.businessName || "Tregio User" }}</strong>
            <span v-for="line in primaryAddressLines" :key="line">{{ line }}</span>
          </div>
        </section>
      </div>

      <section v-if="isClientUser" class="table-card">
        <div class="dashboard-section__head">
          <div>
            <p class="market-page__eyebrow">Orders</p>
            <h2>Recent orders</h2>
          </div>
          <RouterLink class="market-button market-button--ghost" to="/porosite">
            View all
          </RouterLink>
        </div>

        <table v-if="recentOrders.length > 0" class="dashboard-table">
          <thead>
            <tr>
              <th>Order</th>
              <th>Status</th>
              <th>Date</th>
              <th>Total</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="order in recentOrders" :key="order.id">
              <td>#{{ order.id }}</td>
              <td>
                <span
                  class="dashboard-badge"
                  :class="formatDashboardOrderStatus(order) === 'IN PROGRESS' ? 'dashboard-badge--warning' : 'dashboard-badge--success'"
                >
                  {{ formatDashboardOrderStatus(order) }}
                </span>
              </td>
              <td>{{ formatDashboardOrderDate(order.createdAt || order.created_at) }}</td>
              <td>{{ formatDashboardOrderTotal(order) }}</td>
              <td>
                <RouterLink class="market-button market-button--ghost" to="/porosite">
                  View
                </RouterLink>
              </td>
            </tr>
          </tbody>
        </table>

        <div v-else class="market-empty">
          <h3>No recent orders</h3>
          <p>Nuk ka ende porosi të fundit për t’u shfaqur.</p>
        </div>
      </section>

      <section v-if="isClientUser" class="dashboard-section">
        <div class="dashboard-section__head">
          <div>
            <p class="market-page__eyebrow">Wishlist</p>
            <h2>{{ dashboardProductTitle }}</h2>
          </div>
          <RouterLink class="market-button market-button--ghost" to="/wishlist">
            View wishlist
          </RouterLink>
        </div>

        <div v-if="dashboardProductRail.length > 0" class="product-collection__grid">
          <ProductCard
            v-for="product in dashboardProductRail"
            :key="`${dashboardProductTitle}-${product.id}-${product.title}`"
            :product="product"
            :show-overlay-actions="false"
          />
        </div>

        <div v-if="dashboardProductPageCount > 1" class="dashboard-inline-meta">
          <button class="market-button market-button--ghost" type="button" aria-label="Kthehu mbrapa" @click="goToPreviousDashboardProductPage">
            Prev
          </button>
          <span class="section-heading__copy">Page {{ activeDashboardProductPage + 1 }} of {{ dashboardProductPageCount }}</span>
          <button class="market-button market-button--ghost" type="button" aria-label="Shko përpara" @click="goToNextDashboardProductPage">
            Next
          </button>
        </div>

        <div v-else-if="dashboardProductSource.length === 0" class="market-empty">
          <h3>No products yet</h3>
          <p>Nuk ka ende produkte për këtë seksion.</p>
        </div>
      </section>
    </DashboardShell>

    <div v-else class="market-empty">
      <h2>Account unavailable</h2>
      <p>We could not load the dashboard for this session.</p>
    </div>
  </section>
</template>
