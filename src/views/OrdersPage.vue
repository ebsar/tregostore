<script setup>
import { computed, onMounted, reactive, ref, watch } from "vue";
import { RouterLink, useRoute, useRouter } from "vue-router";
import AccountUtilityShell from "../components/account/AccountUtilityShell.vue";
import UserOrderCard from "../components/UserOrderCard.vue";
import { requestJson, resolveApiMessage } from "../lib/api";
import { consumeOrderConfirmationMessage, formatPrice } from "../lib/shop";
import { ensureSessionLoaded, markRouteReady } from "../stores/app-state";

const router = useRouter();
const route = useRoute();
const ORDERS_PER_PAGE = 6;
const ORDER_STATUS_TABS = [
  { key: "all", label: "All" },
  { key: "pending", label: "Pending" },
  { key: "processing", label: "Processing" },
  { key: "shipped", label: "Shipped" },
  { key: "delivered", label: "Delivered" },
  { key: "cancelled", label: "Cancelled" },
  { key: "returned", label: "Returned / Refunded" },
];

const orders = ref([]);
const busyOrderItemId = ref(0);
const selectedOrderId = ref(0);
const currentPage = ref(1);
const orderSearchQuery = ref(readRouteSearchQuery(route.query.q));
const activeStatusTab = ref(readRouteStatusTab(route.query.status));

const ui = reactive({
  message: "",
  type: "",
  guest: false,
});
const dashboardNotificationCount = computed(() =>
  orders.value.filter((order) =>
    [
      "pending_confirmation",
      "confirmed",
      "packed",
      "shipped",
      "partially_confirmed",
    ].includes(String(order.fulfillmentStatus || order.status || "").trim().toLowerCase()),
  ).length,
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

const selectedOrder = computed(() =>
  filteredOrders.value.find((order) => Number(order.id) === Number(selectedOrderId.value))
  || paginatedOrders.value[0]
  || null,
);

watch(filteredOrders, (nextOrders) => {
  const maxPage = Math.max(1, Math.ceil(nextOrders.length / ORDERS_PER_PAGE));
  if (currentPage.value > maxPage) {
    currentPage.value = maxPage;
  }

  if (nextOrders.length === 0) {
    selectedOrderId.value = 0;
    return;
  }

  const hasSelected = nextOrders.some((order) => Number(order.id) === Number(selectedOrderId.value));
  if (!hasSelected) {
    selectedOrderId.value = Number(nextOrders[0]?.id || 0);
  }
}, { immediate: true });

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

watch(currentPage, () => {
  if (paginatedOrders.value.length === 0) {
    return;
  }

  const visibleSelection = paginatedOrders.value.some((order) => Number(order.id) === Number(selectedOrderId.value));
  if (!visibleSelection) {
    selectedOrderId.value = Number(paginatedOrders.value[0]?.id || 0);
  }
});

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
  const { response, data } = await requestJson("/api/orders");
  if (!response.ok || !data?.ok) {
    if (!ui.message) {
      ui.message = resolveApiMessage(data, "Porosite nuk u ngarkuan.");
      ui.type = "error";
    }
    orders.value = [];
    return;
  }

  orders.value = Array.isArray(data.orders) ? data.orders : [];
}

async function handleReturnRequest(item) {
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

function selectOrder(order) {
  selectedOrderId.value = Number(order?.id || 0);
}

function goToPage(page) {
  const nextPage = Number(page || 1);
  if (!Number.isFinite(nextPage) || nextPage < 1 || nextPage > pageCount.value) {
    return;
  }

  currentPage.value = nextPage;
}

function readRouteSearchQuery(value) {
  return Array.isArray(value) ? String(value[0] || "") : String(value || "");
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

async function handleOrderSearch() {
  const query = String(orderSearchQuery.value || "").trim();
  orderSearchQuery.value = query;
  currentPage.value = 1;
  await syncRouteFilters({ q: query, status: activeStatusTab.value });
}

async function setOrderStatusTab(tabKey) {
  const nextTab = ORDER_STATUS_TABS.some((tab) => tab.key === tabKey) ? tabKey : "all";
  if (nextTab === activeStatusTab.value) {
    return;
  }

  activeStatusTab.value = nextTab;
  currentPage.value = 1;
  await syncRouteFilters({ q: orderSearchQuery.value, status: nextTab });
}

function readRouteStatusTab(value) {
  const nextValue = Array.isArray(value) ? String(value[0] || "") : String(value || "");
  return ORDER_STATUS_TABS.some((tab) => tab.key === nextValue) ? nextValue : "all";
}

async function syncRouteFilters({ q = "", status = "all" } = {}) {
  const nextQuery = {
    ...route.query,
    q: String(q || "").trim() || undefined,
    status: status && status !== "all" ? status : undefined,
  };

  await router.replace({
    path: route.path,
    query: nextQuery,
  });
}

function getOrderSearchHaystack(order) {
  const itemText = Array.isArray(order?.items)
    ? order.items.map((item) => [
      item?.title,
      item?.productTitle,
      item?.productName,
      item?.businessName,
      item?.variantLabel,
    ].filter(Boolean).join(" ")).join(" ")
    : "";

  return normalizeOrderSearchValue([
    order?.id ? `#${order.id}` : "",
    order?.status,
    order?.fulfillmentStatus,
    order?.paymentStatus,
    order?.createdAt,
    order?.totalPrice,
    order?.totalItems,
    itemText,
  ].filter(Boolean).join(" "));
}

function matchesOrderStatusTab(order, tabKey) {
  const normalizedStatus = String(order?.fulfillmentStatus || order?.status || "").trim().toLowerCase();

  if (tabKey === "all") {
    return true;
  }
  if (tabKey === "pending") {
    return ["pending_confirmation"].includes(normalizedStatus);
  }
  if (tabKey === "processing") {
    return ["confirmed", "packed", "partially_confirmed"].includes(normalizedStatus);
  }
  if (tabKey === "shipped") {
    return normalizedStatus === "shipped";
  }
  if (tabKey === "delivered") {
    return normalizedStatus === "delivered";
  }
  if (tabKey === "cancelled") {
    return ["cancelled", "canceled", "failed"].includes(normalizedStatus);
  }
  if (tabKey === "returned") {
    return ["returned", "refunded"].includes(normalizedStatus);
  }

  return true;
}

function getOrderHistoryStatus(order) {
  const normalizedStatus = String(order?.fulfillmentStatus || order?.status || "").trim().toLowerCase();

  if (["delivered"].includes(normalizedStatus)) {
    return {
      label: "COMPLETED",
      tone: "is-completed",
    };
  }

  if (["cancelled", "returned"].includes(normalizedStatus)) {
    return {
      label: "CANCELED",
      tone: "is-canceled",
    };
  }

  return {
    label: "IN PROGRESS",
    tone: "is-progress",
  };
}

function formatOrderDateTime(value) {
  if (!value) {
    return "-";
  }

  const parsedDate = new Date(String(value).replace(" ", "T"));
  if (Number.isNaN(parsedDate.getTime())) {
    return String(value);
  }

  const formatter = new Intl.DateTimeFormat("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  });

  const parts = formatter.formatToParts(parsedDate);
  const month = parts.find((part) => part.type === "month")?.value || "";
  const day = parts.find((part) => part.type === "day")?.value || "";
  const year = parts.find((part) => part.type === "year")?.value || "";
  const hour = parts.find((part) => part.type === "hour")?.value || "";
  const minute = parts.find((part) => part.type === "minute")?.value || "";

  return `${month} ${day}, ${year} ${hour}:${minute}`.trim();
}

function formatOrderTotal(order) {
  const itemCount = Number(order?.totalItems || order?.items?.length || 0);
  const productLabel = itemCount === 1 ? "Product" : "Products";
  return `${formatPrice(order?.totalPrice || 0)} (${itemCount} ${productLabel})`;
}
</script>

<template>
  <AccountUtilityShell
    v-if="!ui.guest"
    active-key="orders"
    eyebrow="Customer account"
    title="Order history"
    description="Track recent purchases, open the full order breakdown, and start a return when the order is eligible."
    :status-message="ui.message"
    :status-type="ui.type"
    :notification-count="dashboardNotificationCount"
    search-placeholder="Search orders, products, returns"
  >
    <div class="orders-history-grid">
      <section class="orders-history-card">
        <div class="dashboard-toolbar">
          <div class="orders-history-card__header">
            <div>
              <h2>Orders</h2>
              <p>{{ filteredOrders.length }} result<span v-if="filteredOrders.length !== 1">s</span> ready to review.</p>
            </div>
          </div>

          <form class="dashboard-toolbar__search" role="search" @submit.prevent="handleOrderSearch">
            <input
              v-model="orderSearchQuery"
              type="search"
              placeholder="Search by order number or product"
              aria-label="Search orders"
            >
          </form>
        </div>

        <div v-if="orders.length > 0" class="dashboard-status-tabs" aria-label="Filter orders by status">
          <button
            v-for="tab in orderStatusTabs"
            :key="tab.key"
            class="dashboard-status-tab"
            :class="{ 'is-active': activeStatusTab === tab.key }"
            type="button"
            @click="setOrderStatusTab(tab.key)"
          >
            <span>{{ tab.label }}</span>
            <strong>{{ tab.count }}</strong>
          </button>
        </div>

        <div v-if="orders.length === 0" class="market-empty">
          <h2>No orders yet</h2>
          <p>Your placed orders will appear here as soon as checkout is completed.</p>
        </div>

        <div v-else-if="filteredOrders.length === 0" class="market-empty">
          <h2>No matching orders</h2>
          <p>Try a different order number, status, or product name.</p>
        </div>

        <template v-else>
          <table class="dashboard-table">
            <thead>
              <tr>
                <th>Order</th>
                <th>Status</th>
                <th>Date</th>
                <th>Total</th>
                <th>Action</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="order in paginatedOrders" :key="order.id">
                <td>
                  <strong>#{{ order.id || "-" }}</strong>
                </td>
                <td>
                  <span class="dashboard-badge" :class="{
                    'dashboard-badge--success': getOrderHistoryStatus(order).tone === 'is-completed',
                    'dashboard-badge--warning': getOrderHistoryStatus(order).tone === 'is-progress',
                    'dashboard-badge--error': getOrderHistoryStatus(order).tone === 'is-canceled',
                  }">
                    {{ getOrderHistoryStatus(order).label }}
                  </span>
                </td>
                <td>{{ formatOrderDateTime(order.createdAt || "") }}</td>
                <td>{{ formatOrderTotal(order) }}</td>
                <td>
                  <button class="dashboard-table__action" type="button" @click="selectOrder(order)">
                    View details
                    <span aria-hidden="true">→</span>
                  </button>
                </td>
              </tr>
            </tbody>
          </table>

          <div v-if="pageCount > 1" class="account-form__actions" aria-label="Pagination">
            <button
              class="market-button market-button--secondary"
              type="button"
              :disabled="currentPage === 1"
              @click="goToPage(currentPage - 1)"
            >
              Previous
            </button>
            <button
              v-for="page in pageCount"
              :key="`page-${page}`"
              class="market-button"
              :class="page === currentPage ? 'market-button--primary' : 'market-button--secondary'"
              type="button"
              @click="goToPage(page)"
            >
              {{ String(page).padStart(2, "0") }}
            </button>
            <button
              class="market-button market-button--secondary"
              type="button"
              :disabled="currentPage === pageCount"
              @click="goToPage(currentPage + 1)"
            >
              Next
            </button>
          </div>
        </template>
      </section>

      <section v-if="selectedOrder" class="orders-history-card">
        <div class="orders-history-card__header">
          <div>
            <h2>Selected order</h2>
            <p>Products are grouped by seller so multivendor order details stay easier to read.</p>
          </div>
        </div>

        <UserOrderCard
          :order="selectedOrder"
          :busy-order-item-id="busyOrderItemId"
          @request-return="handleReturnRequest"
        />
      </section>
    </div>
  </AccountUtilityShell>

  <section v-else class="market-page market-page--wide dashboard-page" aria-label="Order History">
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
