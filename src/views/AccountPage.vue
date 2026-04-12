<script setup>
import { computed, onMounted, reactive, ref } from "vue";
import { RouterLink, useRouter } from "vue-router";
import { fetchHomeRecommendations, requestJson, resolveApiMessage } from "../lib/api";
import { getAccountDashboardMenuItems } from "../lib/account-navigation";
import { formatDateLabel, formatPrice, getBusinessInitials, getProductDetailUrl, normalizeAddress } from "../lib/shop";
import { appState, ensureSessionLoaded, logoutUser, markRouteReady } from "../stores/app-state";

const router = useRouter();
const orders = ref([]);
const savedAddress = ref(null);
const recommendationSections = ref([]);
const dashboardProductPage = ref(0);
const ui = reactive({
  message: "",
  type: "",
});

const isClientUser = computed(() =>
  Boolean(appState.user) && !["admin", "business"].includes(String(appState.user?.role || "").trim().toLowerCase()),
);

const dashboardMenuItems = computed(() => getAccountDashboardMenuItems(appState.user, "dashboard"));

const greetingName = computed(() => {
  const fullName = String(appState.user?.fullName || appState.user?.businessName || "User").trim();
  return fullName.split(/\s+/)[0] || fullName;
});

const userAvatarLabel = computed(() =>
  getBusinessInitials(appState.user?.fullName || appState.user?.businessName || "Tregio"),
);

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
  <section class="account-page account-dashboard-page" aria-label="Llogaria ime">
    <div class="form-message" :class="ui.type" role="status" aria-live="polite">
      {{ ui.message }}
    </div>

    <div v-if="appState.user" class="account-dashboard-layout">
      <aside class="account-dashboard-sidebar">
        <div class="account-dashboard-sidebar-card">
          <RouterLink
            v-for="item in dashboardMenuItems"
            :key="`${item.href}-${item.label}`"
            class="account-dashboard-nav-link"
            :class="{ 'is-active': item.active }"
            :to="item.href"
          >
            <svg viewBox="0 0 24 24" aria-hidden="true">
              <path :d="renderDashboardIcon(item.icon)" />
            </svg>
            <span>{{ item.label }}</span>
          </RouterLink>

          <button class="account-dashboard-nav-link account-dashboard-nav-button" type="button" @click="handleLogout">
            <svg viewBox="0 0 24 24" aria-hidden="true">
              <path d="M15 5h4v14h-4M10 8l4 4-4 4M14 12H4" />
            </svg>
            <span>Log-out</span>
          </button>
        </div>
      </aside>

      <div class="account-dashboard-main">
        <header class="account-dashboard-header">
          <div>
            <h1>Hello, {{ greetingName }}</h1>
            <p>
              From your account dashboard. you can easily check &amp; view your
              <RouterLink to="/porosite">Recent Orders</RouterLink>, manage your
              <RouterLink to="/adresat">Shipping and Billing Addresses</RouterLink>
              and edit your
              <RouterLink to="/ndrysho-fjalekalimin">Password</RouterLink> and
              <RouterLink to="/te-dhenat-personale">Account Details</RouterLink>.
            </p>
          </div>
        </header>

        <div class="account-dashboard-content">
          <div class="account-dashboard-cards">
            <section class="account-dashboard-card">
              <div class="account-dashboard-card-head">
                <h2>ACCOUNT INFO</h2>
              </div>

              <div class="account-dashboard-profile">
                <div class="account-dashboard-avatar" aria-hidden="true">
                  {{ userAvatarLabel }}
                </div>
                <div class="account-dashboard-profile-copy">
                  <strong>{{ appState.user.fullName || appState.user.businessName || "Tregio User" }}</strong>
                  <span>{{ accountLocationLabel }}</span>
                </div>
              </div>

              <div class="account-dashboard-lines">
                <p><span>Email:</span> {{ appState.user.email || "-" }}</p>
                <p><span>Phone:</span> {{ savedAddress?.phoneNumber || appState.user.phoneNumber || "-" }}</p>
                <p><span>Joined:</span> {{ formatDateLabel(appState.user.createdAt || "") || "-" }}</p>
              </div>

              <RouterLink class="account-dashboard-action" to="/te-dhenat-personale">
                EDIT ACCOUNT
              </RouterLink>
            </section>

            <section class="account-dashboard-card">
              <div class="account-dashboard-card-head">
                <h2>BILLING ADDRESS</h2>
              </div>

              <div class="account-dashboard-address">
                <strong>{{ appState.user.fullName || appState.user.businessName || "Tregio User" }}</strong>
                <p
                  v-for="line in primaryAddressLines"
                  :key="line"
                >
                  {{ line }}
                </p>
              </div>

              <RouterLink class="account-dashboard-action" to="/adresat">
                EDIT ADDRESS
              </RouterLink>
            </section>
          </div>

          <aside class="account-dashboard-stats">
            <article
              v-for="stat in dashboardSummary"
              :key="stat.label"
              class="account-dashboard-stat"
              :class="`is-${stat.tone}`"
            >
              <span class="account-dashboard-stat-icon" aria-hidden="true">
                <svg viewBox="0 0 24 24">
                  <path :d="renderDashboardIcon(stat.icon)" />
                </svg>
              </span>
              <div class="account-dashboard-stat-copy">
                <strong>{{ stat.value }}</strong>
                <span>{{ stat.label }}</span>
              </div>
            </article>
          </aside>
        </div>

        <section v-if="isClientUser" class="account-dashboard-panel">
          <header class="account-dashboard-panel-head">
            <h2>RECENT ORDER</h2>
            <RouterLink to="/porosite">View All</RouterLink>
          </header>

          <div v-if="recentOrders.length > 0" class="account-dashboard-orders-table">
            <div class="account-dashboard-orders-table-head">
              <span>ORDER ID</span>
              <span>STATUS</span>
              <span>DATE</span>
              <span>TOTAL</span>
              <span>ACTION</span>
            </div>

            <article
              v-for="order in recentOrders"
              :key="order.id"
              class="account-dashboard-orders-row"
            >
              <strong>#{{ order.id }}</strong>
              <span
                class="account-dashboard-order-status"
                :class="dashboardOrderStatusClass(order)"
              >
                {{ formatDashboardOrderStatus(order) }}
              </span>
              <span>{{ formatDashboardOrderDate(order.createdAt || order.created_at) }}</span>
              <span>{{ formatDashboardOrderTotal(order) }}</span>
              <RouterLink to="/porosite">View Details</RouterLink>
            </article>
          </div>

          <p v-else class="account-dashboard-empty-state">
            Nuk ka ende porosi të fundit për t’u shfaqur.
          </p>
        </section>

        <section v-if="isClientUser" class="account-dashboard-panel">
          <header class="account-dashboard-panel-head">
            <h2>{{ dashboardProductTitle }}</h2>
            <RouterLink to="/kerko">View All</RouterLink>
          </header>

          <div v-if="dashboardProductRail.length > 0" class="account-dashboard-product-strip">
            <RouterLink
              v-for="product in dashboardProductRail"
              :key="`${dashboardProductTitle}-${product.id}-${product.title}`"
              class="account-dashboard-product-card"
              :to="productCardHref(product)"
            >
              <div class="account-dashboard-product-media">
                <img
                  :src="product.imagePath"
                  :alt="product.title"
                  width="320"
                  height="320"
                  loading="lazy"
                  decoding="async"
                >
              </div>
              <div class="account-dashboard-product-meta">
                <div class="account-dashboard-product-rating">
                  <span class="account-dashboard-product-stars" aria-hidden="true">
                    <svg
                      v-for="index in 5"
                      :key="`${product.id}-star-${index}`"
                      viewBox="0 0 24 24"
                      :class="{ 'is-filled': index <= productFilledStars(product) }"
                    >
                      <path d="M12 3.8 14.6 9l5.7.8-4.1 4 1 5.7-5.2-2.7-5.2 2.7 1-5.7-4.1-4 5.7-.8Z" />
                    </svg>
                  </span>
                  <small v-if="productReviewCount(product) > 0">({{ productReviewCount(product) }})</small>
                </div>
                <h3>{{ product.title }}</h3>
                <p v-if="product.businessName" class="account-dashboard-product-business">
                  {{ product.businessName }}
                </p>
                <strong>{{ formatPrice(product.price || 0) }}</strong>
              </div>
            </RouterLink>
          </div>

          <div v-if="dashboardProductPageCount > 1" class="account-dashboard-strip-controls">
            <button type="button" aria-label="Kthehu mbrapa" @click="goToPreviousDashboardProductPage">
              ←
            </button>
            <div class="account-dashboard-strip-dots" aria-hidden="true">
              <span
                v-for="page in dashboardProductPageCount"
                :key="`dashboard-products-${page}`"
                :class="{ 'is-active': page - 1 === activeDashboardProductPage }"
              ></span>
            </div>
            <button type="button" aria-label="Shko përpara" @click="goToNextDashboardProductPage">
              →
            </button>
          </div>

          <p v-else-if="dashboardProductSource.length === 0" class="account-dashboard-empty-state">
            Nuk ka ende produkte për këtë seksion.
          </p>
        </section>
      </div>
    </div>
  </section>
</template>

<style scoped>
.account-dashboard-page {
  width: min(1300px, calc(100vw - 48px));
  margin: 0 auto;
  padding: 0;
}

.account-dashboard-layout {
  display: grid;
  grid-template-columns: 260px minmax(0, 1fr);
  gap: 38px;
  align-items: start;
}

.account-dashboard-sidebar-card {
  display: grid;
  background: #fff;
  border: 1px solid rgba(15, 23, 42, 0.08);
  border-radius: 8px;
  overflow: hidden;
}

.account-dashboard-nav-link,
.account-dashboard-nav-button {
  display: flex;
  align-items: center;
  gap: 14px;
  min-height: 54px;
  padding: 0 22px;
  border: 0;
  border-bottom: 1px solid rgba(15, 23, 42, 0.06);
  background: #fff;
  color: #5b6775;
  text-decoration: none;
  font-size: 1rem;
  font-weight: 500;
  text-align: left;
  cursor: pointer;
}

.account-dashboard-nav-link svg,
.account-dashboard-nav-button svg {
  width: 20px;
  height: 20px;
  fill: none;
  stroke: currentColor;
  stroke-width: 1.9;
  stroke-linecap: round;
  stroke-linejoin: round;
}

.account-dashboard-nav-link.is-active {
  background: #ff7f32;
  color: #fff;
  font-weight: 700;
}

.account-dashboard-nav-button {
  border-bottom: 0;
}

.account-dashboard-main {
  display: grid;
  gap: 24px;
}

.account-dashboard-header h1 {
  margin: 0;
  color: #111827;
  font-size: clamp(2rem, 3vw, 2.7rem);
  line-height: 1;
  letter-spacing: -0.04em;
}

.account-dashboard-header p {
  max-width: 760px;
  margin: 14px 0 0;
  color: #4b5563;
  font-size: 1.05rem;
  line-height: 1.7;
}

.account-dashboard-header a {
  color: #2496f3;
  text-decoration: none;
  font-weight: 600;
}

.account-dashboard-content {
  display: grid;
  grid-template-columns: minmax(0, 1fr) 310px;
  gap: 24px;
  align-items: start;
}

.account-dashboard-cards {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 24px;
}

.account-dashboard-card {
  display: grid;
  gap: 24px;
  background: #fff;
  border: 1px solid rgba(15, 23, 42, 0.08);
}

.account-dashboard-card-head {
  padding: 18px 24px;
  border-bottom: 1px solid rgba(15, 23, 42, 0.08);
}

.account-dashboard-card-head h2 {
  margin: 0;
  color: #111827;
  font-size: 1.05rem;
  letter-spacing: -0.02em;
}

.account-dashboard-profile,
.account-dashboard-lines,
.account-dashboard-address {
  padding: 0 24px;
}

.account-dashboard-profile {
  display: flex;
  align-items: center;
  gap: 16px;
}

.account-dashboard-avatar {
  display: inline-flex;
  width: 52px;
  height: 52px;
  align-items: center;
  justify-content: center;
  border-radius: 999px;
  background: linear-gradient(135deg, #ffb37c, #ff7f32);
  color: #fff;
  font-weight: 800;
}

.account-dashboard-profile-copy {
  display: grid;
  gap: 4px;
}

.account-dashboard-profile-copy strong {
  color: #111827;
  font-size: 1.1rem;
}

.account-dashboard-profile-copy span {
  color: #6b7280;
}

.account-dashboard-lines,
.account-dashboard-address {
  display: grid;
  gap: 10px;
}

.account-dashboard-lines p,
.account-dashboard-address p {
  margin: 0;
  color: #4b5563;
  line-height: 1.5;
}

.account-dashboard-lines span {
  color: #111827;
  font-weight: 600;
}

.account-dashboard-address strong {
  color: #111827;
  font-size: 1.05rem;
}

.account-dashboard-action {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: fit-content;
  min-height: 46px;
  margin: 0 24px 24px;
  padding: 0 22px;
  border: 1px solid rgba(36, 150, 243, 0.28);
  background: #fff;
  color: #2496f3;
  text-decoration: none;
  font-weight: 800;
}

.account-dashboard-stats {
  display: grid;
  gap: 24px;
}

.account-dashboard-panel {
  background: #fff;
  border: 1px solid rgba(15, 23, 42, 0.08);
  border-radius: 8px;
  overflow: hidden;
}

.account-dashboard-panel-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  padding: 18px 24px;
  border-bottom: 1px solid rgba(15, 23, 42, 0.08);
}

.account-dashboard-panel-head h2 {
  margin: 0;
  color: #202939;
  font-size: 1.05rem;
  letter-spacing: -0.02em;
}

.account-dashboard-panel-head a {
  color: #ff7f32;
  text-decoration: none;
  font-weight: 700;
}

.account-dashboard-orders-table {
  display: grid;
}

.account-dashboard-orders-table-head,
.account-dashboard-orders-row {
  display: grid;
  grid-template-columns: 1.05fr 1fr 1.15fr 1.2fr 0.85fr;
  gap: 18px;
  align-items: center;
  padding: 18px 24px;
}

.account-dashboard-orders-table-head {
  background: #f8fafc;
  border-bottom: 1px solid rgba(15, 23, 42, 0.08);
  color: #5b6775;
  font-size: 0.85rem;
  font-weight: 700;
}

.account-dashboard-orders-row {
  border-bottom: 1px solid rgba(15, 23, 42, 0.07);
  color: #4b5563;
}

.account-dashboard-orders-row:last-child {
  border-bottom: 0;
}

.account-dashboard-orders-row strong {
  color: #111827;
  font-size: 1.02rem;
}

.account-dashboard-orders-row a {
  color: #2496f3;
  text-decoration: none;
  font-weight: 700;
}

.account-dashboard-order-status {
  font-weight: 800;
}

.account-dashboard-order-status.is-progress {
  color: #ff7f32;
}

.account-dashboard-order-status.is-completed {
  color: #1fad37;
}

.account-dashboard-order-status.is-canceled {
  color: #ef4444;
}

.account-dashboard-product-strip {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
}

.account-dashboard-product-card {
  display: grid;
  gap: 18px;
  min-height: 360px;
  padding: 24px 22px 28px;
  border-right: 1px solid rgba(15, 23, 42, 0.08);
  color: inherit;
  text-decoration: none;
}

.account-dashboard-product-card:last-child {
  border-right: 0;
}

.account-dashboard-product-media {
  display: grid;
  place-items: center;
  min-height: 180px;
}

.account-dashboard-product-media img {
  width: min(170px, 100%);
  height: 170px;
  object-fit: contain;
}

.account-dashboard-product-meta {
  display: grid;
  gap: 10px;
  align-content: start;
}

.account-dashboard-product-rating {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  color: #6b7280;
}

.account-dashboard-product-stars {
  display: inline-flex;
  gap: 2px;
}

.account-dashboard-product-stars svg {
  width: 16px;
  height: 16px;
  fill: #d5dbe3;
}

.account-dashboard-product-stars svg.is-filled {
  fill: #ff8a1f;
}

.account-dashboard-product-meta h3 {
  margin: 0;
  color: #202939;
  font-size: 1.05rem;
  line-height: 1.45;
  display: -webkit-box;
  -webkit-line-clamp: 3;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.account-dashboard-product-business {
  margin: 0;
  color: #6b7280;
  font-size: 0.95rem;
}

.account-dashboard-product-meta strong {
  color: #1d8eff;
  font-size: 1.7rem;
  line-height: 1;
}

.account-dashboard-strip-controls {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 16px;
  padding: 10px 24px 26px;
}

.account-dashboard-strip-controls button {
  display: inline-flex;
  width: 48px;
  height: 48px;
  align-items: center;
  justify-content: center;
  border: 1px solid rgba(255, 127, 50, 0.7);
  border-radius: 999px;
  background: #fff;
  color: #ff7f32;
  font-size: 1.5rem;
  cursor: pointer;
}

.account-dashboard-strip-dots {
  display: inline-flex;
  align-items: center;
  gap: 10px;
}

.account-dashboard-strip-dots span {
  width: 10px;
  height: 10px;
  border-radius: 999px;
  background: #f3d5c2;
}

.account-dashboard-strip-dots span.is-active {
  background: #ff7f32;
}

.account-dashboard-empty-state {
  margin: 0;
  padding: 26px 24px 30px;
  color: #6b7280;
}

.account-dashboard-stat {
  display: flex;
  align-items: center;
  gap: 18px;
  min-height: 112px;
  padding: 24px;
  border-radius: 8px;
}

.account-dashboard-stat.is-sky {
  background: #e7f4ff;
}

.account-dashboard-stat.is-peach {
  background: #fff1e7;
}

.account-dashboard-stat.is-mint {
  background: #edf8ea;
}

.account-dashboard-stat-icon {
  display: inline-flex;
  width: 54px;
  height: 54px;
  align-items: center;
  justify-content: center;
  background: rgba(255, 255, 255, 0.88);
}

.account-dashboard-stat-icon svg {
  width: 28px;
  height: 28px;
  fill: none;
  stroke: #2496f3;
  stroke-width: 1.8;
  stroke-linecap: round;
  stroke-linejoin: round;
}

.account-dashboard-stat.is-peach .account-dashboard-stat-icon svg {
  stroke: #ff7f32;
}

.account-dashboard-stat.is-mint .account-dashboard-stat-icon svg {
  stroke: #4aa75f;
}

.account-dashboard-stat-copy {
  display: grid;
  gap: 6px;
}

.account-dashboard-stat-copy strong {
  color: #111827;
  font-size: 2rem;
  line-height: 1;
}

.account-dashboard-stat-copy span {
  color: #4b5563;
  font-size: 1.05rem;
}

@media (max-width: 1080px) {
  .account-dashboard-layout,
  .account-dashboard-content,
  .account-dashboard-cards {
    grid-template-columns: 1fr;
  }

  .account-dashboard-orders-table-head,
  .account-dashboard-orders-row {
    grid-template-columns: repeat(5, minmax(0, 1fr));
  }

  .account-dashboard-product-strip {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }

  .account-dashboard-product-card:nth-child(2n) {
    border-right: 0;
  }

  .account-dashboard-sidebar {
    order: 2;
  }
}

@media (max-width: 720px) {
  .account-dashboard-page {
    width: min(100vw - 24px, 1300px);
    padding-top: 0;
  }

  .account-dashboard-nav-link,
  .account-dashboard-nav-button {
    min-height: 50px;
    padding-inline: 16px;
    font-size: 0.95rem;
  }

  .account-dashboard-card-head,
  .account-dashboard-profile,
  .account-dashboard-lines,
  .account-dashboard-address {
    padding-inline: 16px;
  }

  .account-dashboard-action {
    margin-inline: 16px;
  }

  .account-dashboard-panel-head,
  .account-dashboard-orders-table-head,
  .account-dashboard-orders-row,
  .account-dashboard-strip-controls {
    padding-left: 16px;
    padding-right: 16px;
  }

  .account-dashboard-orders-table-head {
    display: none;
  }

  .account-dashboard-orders-row {
    grid-template-columns: 1fr;
    gap: 8px;
    padding-top: 16px;
    padding-bottom: 16px;
  }

  .account-dashboard-orders-row a {
    margin-top: 4px;
  }

  .account-dashboard-product-strip {
    grid-template-columns: 1fr;
  }

  .account-dashboard-product-card {
    min-height: auto;
    border-right: 0;
    border-bottom: 1px solid rgba(15, 23, 42, 0.08);
  }

  .account-dashboard-product-card:last-child {
    border-bottom: 0;
  }
}
</style>
