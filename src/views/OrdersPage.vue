<script setup>
import { computed, onMounted, reactive, ref, watch } from "vue";
import { RouterLink, useRoute, useRouter } from "vue-router";
import AccountUtilityShell from "../components/account/AccountUtilityShell.vue";
import OrderCard from "../components/orders/OrderCard.vue";
import OrderDetails from "../components/orders/OrderDetails.vue";
import OrderFilters from "../components/orders/OrderFilters.vue";
import { requestJson, resolveApiMessage } from "../lib/api";
import { consumeOrderConfirmationMessage } from "../lib/shop";
import { ensureSessionLoaded, markRouteReady } from "../stores/app-state";

const router = useRouter();
const route = useRoute();
const ORDERS_PER_PAGE = 6;
const ORDER_STATUS_TABS = [
  { key: "all", label: "All Orders" },
  { key: "processing", label: "Processing" },
  { key: "shipped", label: "Shipped" },
  { key: "delivered", label: "Delivered" },
  { key: "cancelled", label: "Cancelled" },
  { key: "refunded", label: "Refunded" },
];

const orders = ref([]);
const ordersLoaded = ref(false);
const loadingOrders = ref(false);
const ordersError = ref("");
const busyOrderItemId = ref(0);
const selectedOrderId = ref(readRouteOrderId(route.query.orderId));
const actionsMenuOrderId = ref(0);
const currentPage = ref(1);
const orderSearchQuery = ref(readRouteSearchQuery(route.query.q));
const activeStatusTab = ref(readRouteStatusTab(route.query.status));

const ui = reactive({
  message: "",
  type: "",
  guest: false,
});

const dashboardNotificationCount = computed(() =>
  orders.value.filter((order) => ["processing", "shipped"].includes(getNormalizedOrderStatus(order))).length,
);

const filteredOrders = computed(() => {
  const normalizedQuery = normalizeOrderSearchValue(orderSearchQuery.value);

  return orders.value.filter((order) => {
    if (!matchesOrderStatusTab(order, activeStatusTab.value)) {
      return false;
    }

    if (!normalizedQuery) {
      return true;
    }

    const orderId = String(order?.id || "").trim().toLowerCase();
    const queryWithoutHash = normalizedQuery.replace(/^#/, "");
    const queryOrderNumber = extractOrderSearchNumber(normalizedQuery);

    if (orderId && (
      orderId === queryWithoutHash
      || orderId.includes(queryWithoutHash)
      || (queryOrderNumber && orderId.includes(queryOrderNumber))
    )) {
      return true;
    }

    return getOrderSearchHaystack(order).includes(normalizedQuery);
  });
});

const orderStatusTabs = computed(() =>
  ORDER_STATUS_TABS.map((tab) => ({
    ...tab,
    count: tab.key === "all"
      ? orders.value.length
      : orders.value.filter((order) => matchesOrderStatusTab(order, tab.key)).length,
  })),
);

const pageCount = computed(() => Math.max(1, Math.ceil(filteredOrders.value.length / ORDERS_PER_PAGE)));

const paginatedOrders = computed(() => {
  const start = (currentPage.value - 1) * ORDERS_PER_PAGE;
  return filteredOrders.value.slice(start, start + ORDERS_PER_PAGE);
});

const selectedOrder = computed(() => {
  if (!selectedOrderId.value) {
    return null;
  }

  return filteredOrders.value.find((order) => Number(order.id) === Number(selectedOrderId.value)) || null;
});

const hasAnyOrders = computed(() => orders.value.length > 0);
const hasSearchOrFilter = computed(() => Boolean(orderSearchQuery.value.trim()) || activeStatusTab.value !== "all");

watch(filteredOrders, (nextOrders) => {
  const maxPage = Math.max(1, Math.ceil(nextOrders.length / ORDERS_PER_PAGE));
  if (currentPage.value > maxPage) {
    currentPage.value = maxPage;
  }

  if (!ordersLoaded.value || !selectedOrderId.value) {
    return;
  }

  const selectionStillVisible = nextOrders.some((order) => Number(order.id) === Number(selectedOrderId.value));
  if (!selectionStillVisible) {
    selectedOrderId.value = 0;
    syncRouteFilters({ q: orderSearchQuery.value, status: activeStatusTab.value, orderId: "" });
  }
});

watch(
  () => route.query.q,
  (query) => {
    const nextQuery = readRouteSearchQuery(query);
    if (nextQuery !== orderSearchQuery.value) {
      orderSearchQuery.value = nextQuery;
      currentPage.value = 1;
    }
  },
);

watch(
  () => route.query.status,
  (status) => {
    const nextStatus = readRouteStatusTab(status);
    if (nextStatus !== activeStatusTab.value) {
      activeStatusTab.value = nextStatus;
      currentPage.value = 1;
    }
  },
);

watch(
  () => route.query.orderId,
  (orderId) => {
    const nextOrderId = readRouteOrderId(orderId);
    if (nextOrderId !== selectedOrderId.value) {
      selectedOrderId.value = nextOrderId;
    }
  },
);

onMounted(async () => {
  try {
    const user = await ensureSessionLoaded();
    if (!user) {
      ui.guest = true;
      ui.message = "Per te pare porosite duhet te kyçesh ose te krijosh llogari.";
      ui.type = "error";
      return;
    }

    const confirmation = consumeOrderConfirmationMessage();
    if (confirmation) {
      ui.message = confirmation;
      ui.type = "success";
    }

    await loadOrders();
  } finally {
    markRouteReady();
  }
});

async function loadOrders() {
  loadingOrders.value = true;
  ordersError.value = "";

  try {
    const { response, data } = await requestJson("/api/orders");
    if (!response.ok || !data?.ok) {
      orders.value = [];
      ordersError.value = resolveApiMessage(data, "Orders could not be loaded.");
      return;
    }

    orders.value = Array.isArray(data.orders) ? data.orders : [];
    const routeOrderId = readRouteOrderId(route.query.orderId);
    selectedOrderId.value = orders.value.some((order) => Number(order.id) === Number(routeOrderId)) ? routeOrderId : 0;
  } catch (error) {
    orders.value = [];
    ordersError.value = "Network error. Please try again.";
  } finally {
    ordersLoaded.value = true;
    loadingOrders.value = false;
  }
}

async function handleReturnRequest(item) {
  if (!item?.id) {
    ui.message = "This order item cannot be returned yet.";
    ui.type = "error";
    return;
  }

  const reason = window.prompt("Shkruaj arsyen e kthimit:");
  if (!reason) {
    return;
  }

  busyOrderItemId.value = Number(item.id) || 0;
  try {
    const { response, data } = await requestJson("/api/returns/request", {
      method: "POST",
      body: JSON.stringify({
        orderItemId: item.id,
        reason,
        details: "",
      }),
    });

    if (!response.ok || !data?.ok) {
      ui.message = resolveApiMessage(data, "Kerkesa per kthim nuk u dergua.");
      ui.type = "error";
      return;
    }

    ui.message = data.message || "Kerkesa per kthim u dergua.";
    ui.type = "success";
    orders.value = orders.value.map((order) => ({
      ...order,
      items: Array.isArray(order.items)
        ? order.items.map((entry) =>
          Number(entry?.id || 0) === Number(item.id)
            ? {
              ...entry,
              returnRequestStatus: "requested",
            }
            : entry)
        : [],
    }));
  } finally {
    busyOrderItemId.value = 0;
  }
}

function handleSearchQueryUpdate(value) {
  orderSearchQuery.value = String(value || "");
  currentPage.value = 1;
  syncRouteFilters({ q: orderSearchQuery.value, status: activeStatusTab.value, orderId: selectedOrderId.value });
}

function openOrder(order) {
  selectedOrderId.value = Number(order?.id || 0);
  actionsMenuOrderId.value = 0;
  syncRouteFilters({ q: orderSearchQuery.value, status: activeStatusTab.value, orderId: selectedOrderId.value });
}

function closeOrderDetails() {
  selectedOrderId.value = 0;
  syncRouteFilters({ q: orderSearchQuery.value, status: activeStatusTab.value, orderId: "" });
}

function toggleOrderMenu(order) {
  const nextOrderId = Number(order?.id || 0);
  actionsMenuOrderId.value = Number(actionsMenuOrderId.value) === nextOrderId ? 0 : nextOrderId;
}

function goToPage(page) {
  const nextPage = Number(page || 1);
  if (!Number.isFinite(nextPage) || nextPage < 1 || nextPage > pageCount.value) {
    return;
  }

  currentPage.value = nextPage;
}

async function setOrderStatusTab(tabKey) {
  const nextTab = ORDER_STATUS_TABS.some((tab) => tab.key === tabKey) ? tabKey : "all";
  if (nextTab === activeStatusTab.value) {
    return;
  }

  activeStatusTab.value = nextTab;
  currentPage.value = 1;
  await syncRouteFilters({ q: orderSearchQuery.value, status: nextTab, orderId: selectedOrderId.value });
}

function handleOrderMenuAction({ action, order }) {
  actionsMenuOrderId.value = 0;

  if (action === "download-invoice") {
    window.open(`/api/orders/invoice?id=${encodeURIComponent(order?.id || "")}`, "_blank", "noopener,noreferrer");
    return;
  }

  if (action === "request-return") {
    requestReturnForOrder(order);
    return;
  }

  if (action === "contact-support") {
    handleContactSupport(order);
  }
}

function requestReturnForOrder(order) {
  const item = getFirstReturnableItem(order);
  if (!item) {
    ui.message = "Return/refund is available after the order is shipped or delivered.";
    ui.type = "error";
    return;
  }

  handleReturnRequest(item);
}

function handleContactSeller(item) {
  router.push({
    path: "/mesazhet",
    query: {
      orderId: selectedOrderId.value || undefined,
      productId: item?.productId || undefined,
      sellerId: item?.businessUserId || undefined,
    },
  });
}

function handleContactSupport(order = null) {
  router.push({
    path: "/support",
    query: order?.id ? { orderId: order.id } : {},
  });
}

function handleReportProblem(order) {
  router.push({
    path: "/support",
    query: {
      topic: "order",
      orderId: order?.id || undefined,
    },
  });
}

function readRouteSearchQuery(value) {
  return Array.isArray(value) ? String(value[0] || "") : String(value || "");
}

function readRouteOrderId(value) {
  const nextValue = Array.isArray(value) ? value[0] : value;
  const nextNumber = Number(nextValue || 0);
  return Number.isFinite(nextNumber) ? nextNumber : 0;
}

function readRouteStatusTab(value) {
  const nextValue = Array.isArray(value) ? String(value[0] || "") : String(value || "");
  return ORDER_STATUS_TABS.some((tab) => tab.key === nextValue) ? nextValue : "all";
}

async function syncRouteFilters({ q = "", status = "all", orderId = "" } = {}) {
  const nextQuery = {
    ...route.query,
    q: String(q || "").trim() || undefined,
    status: status && status !== "all" ? status : undefined,
    orderId: orderId ? String(orderId) : undefined,
  };

  await router.replace({
    path: route.path,
    query: nextQuery,
  });
}

function normalizeOrderSearchValue(value) {
  return String(value || "")
    .trim()
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "");
}

function extractOrderSearchNumber(value) {
  const match = normalizeOrderSearchValue(value).match(/(?:#|order|porosi|nr|number|numri)?\s*(\d+)/);
  return match?.[1] || "";
}

function getOrderSearchHaystack(order) {
  const itemText = Array.isArray(order?.items)
    ? order.items.map((item) => [
      item?.title,
      item?.productTitle,
      item?.productName,
      item?.businessName,
      item?.variantLabel,
      item?.color,
      item?.size,
    ].filter(Boolean).join(" ")).join(" ")
    : "";

  return normalizeOrderSearchValue([
    order?.id ? `#${order.id}` : "",
    order?.status,
    order?.fulfillmentStatus,
    order?.paymentStatus,
    order?.createdAt,
    order?.customerName,
    order?.totalPrice,
    order?.totalItems,
    itemText,
  ].filter(Boolean).join(" "));
}

function matchesOrderStatusTab(order, tabKey) {
  if (tabKey === "all") {
    return true;
  }

  return getNormalizedOrderStatus(order) === tabKey;
}

function getNormalizedOrderStatus(order) {
  const statuses = [
    order?.status,
    order?.fulfillmentStatus,
    ...(Array.isArray(order?.items) ? order.items.map((item) => item?.fulfillmentStatus) : []),
  ].map((status) => String(status || "").trim().toLowerCase());

  if (hasReturnActivity(order) || statuses.some((status) => ["returned", "refunded", "return_requested"].includes(status))) {
    return "refunded";
  }

  if (statuses.some((status) => ["cancelled", "canceled", "failed"].includes(status))) {
    return "cancelled";
  }

  if (statuses.includes("delivered")) {
    return "delivered";
  }

  if (statuses.some((status) => ["shipped", "in_transit", "out_for_delivery"].includes(status))) {
    return "shipped";
  }

  return "processing";
}

function hasReturnActivity(order) {
  return Array.isArray(order?.items)
    && order.items.some((item) => String(item?.returnRequestStatus || "").trim());
}

function getFirstReturnableItem(order) {
  const items = Array.isArray(order?.items) ? order.items : [];
  return items.find((item) => {
    const status = String(item.fulfillmentStatus || order?.fulfillmentStatus || order?.status || "").toLowerCase();
    return ["delivered", "shipped"].includes(status) && !item.returnRequestStatus;
  }) || null;
}
</script>

<template>
  <AccountUtilityShell
    v-if="!ui.guest"
    active-key="orders"
    eyebrow="Customer account"
    title="My Orders"
    description="Track, view, and manage your orders"
    :status-message="ui.message"
    :status-type="ui.type"
    :notification-count="dashboardNotificationCount"
    search-placeholder="Search orders, products, sellers"
  >
    <section class="orders-marketplace" aria-label="My Orders">
      <header class="orders-marketplace__hero">
        <div>
          <span>Orders</span>
          <h2>My Orders</h2>
          <p>Track, view, and manage your marketplace orders without leaving your dashboard.</p>
        </div>
        <RouterLink class="orders-marketplace__shop-link" to="/kerko">
          Start shopping
        </RouterLink>
      </header>

      <OrderFilters
        :tabs="orderStatusTabs"
        :active-tab="activeStatusTab"
        :search-query="orderSearchQuery"
        @select-tab="setOrderStatusTab"
        @update:search-query="handleSearchQueryUpdate"
      />

      <section v-if="loadingOrders" class="orders-marketplace__layout orders-marketplace__layout--loading" aria-label="Loading orders">
        <div class="orders-list-panel">
          <article v-for="index in 3" :key="`order-skeleton-${index}`" class="order-card order-card--skeleton">
            <span></span>
            <span></span>
            <span></span>
          </article>
        </div>
        <aside class="order-details-panel order-details-panel--skeleton">
          <span></span>
          <span></span>
          <span></span>
        </aside>
      </section>

      <section v-else-if="ordersError" class="orders-state-card orders-state-card--error">
        <h3>Orders could not be loaded</h3>
        <p>{{ ordersError }}</p>
        <button type="button" class="market-button market-button--primary" @click="loadOrders">
          Retry
        </button>
      </section>

      <section v-else-if="!hasAnyOrders" class="orders-state-card">
        <h3>No orders yet</h3>
        <p>Your placed orders will appear here as soon as checkout is completed.</p>
        <RouterLink class="market-button market-button--primary" to="/kerko">
          Start shopping
        </RouterLink>
      </section>

      <section v-else class="orders-marketplace__layout">
        <div class="orders-list-panel">
          <div class="orders-list-panel__head">
            <div>
              <span>Results</span>
              <h3>{{ filteredOrders.length }} order{{ filteredOrders.length === 1 ? "" : "s" }}</h3>
            </div>
            <small v-if="hasSearchOrFilter">Filtered view</small>
          </div>

          <section v-if="filteredOrders.length === 0" class="orders-state-card orders-state-card--compact">
            <h3>No search results</h3>
            <p>Try another order number, product name, seller, or status filter.</p>
            <button
              type="button"
              class="market-button market-button--secondary"
              @click="handleSearchQueryUpdate(''); setOrderStatusTab('all')"
            >
              Clear filters
            </button>
          </section>

          <template v-else>
            <OrderCard
              v-for="order in paginatedOrders"
              :key="order.id"
              :order="order"
              :selected="Number(order.id) === Number(selectedOrderId)"
              :menu-open="Number(actionsMenuOrderId) === Number(order.id)"
              @select="openOrder"
              @view="openOrder"
              @toggle-menu="toggleOrderMenu"
              @menu-action="handleOrderMenuAction"
            />

            <nav v-if="pageCount > 1" class="orders-pagination" aria-label="Orders pagination">
              <button type="button" :disabled="currentPage === 1" @click="goToPage(currentPage - 1)">
                Previous
              </button>
              <span>Page {{ currentPage }} of {{ pageCount }}</span>
              <button type="button" :disabled="currentPage === pageCount" @click="goToPage(currentPage + 1)">
                Next
              </button>
            </nav>
          </template>
        </div>

        <div class="orders-details-wrap">
          <OrderDetails
            v-if="selectedOrder"
            :order="selectedOrder"
            :busy-order-item-id="busyOrderItemId"
            @close="closeOrderDetails"
            @contact-seller="handleContactSeller"
            @contact-support="handleContactSupport"
            @report-problem="handleReportProblem"
            @request-return="handleReturnRequest"
          />

          <aside v-else class="orders-details-empty">
            <span aria-hidden="true">#</span>
            <h3>Select an order</h3>
            <p>Click an order card to see tracking, products, payment, delivery address, and support actions.</p>
          </aside>
        </div>
      </section>
    </section>
  </AccountUtilityShell>

  <section v-else class="market-page market-page--wide dashboard-page" aria-label="My Orders">
    <div class="market-empty account-gate">
      <h2>Sign in to see your orders</h2>
      <p>Create an account or log in to follow your purchases, delivery progress, and return requests.</p>
      <div class="account-gate__actions">
        <RouterLink class="market-button market-button--primary" to="/login?redirect=%2Fporosite">
          Login
        </RouterLink>
        <RouterLink class="market-button market-button--secondary" to="/signup?redirect=%2Fporosite">
          Sign up
        </RouterLink>
      </div>
    </div>
  </section>
</template>
