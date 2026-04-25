<script setup>
import { computed, onMounted, reactive, ref, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import BusinessOrderCard from "../components/BusinessOrderCard.vue";
import DashboardShell from "../components/dashboard/DashboardShell.vue";
import { requestJson, resolveApiMessage } from "../lib/api";
import { getAdminDashboardNavItems } from "../lib/dashboard-ui";
import { getBusinessInitials, summarizeOrderFulfillmentStatus } from "../lib/shop";
import { appState, ensureSessionLoaded, markRouteReady } from "../stores/app-state";

const ORDER_STATUS_TABS = [
  { key: "all", label: "All" },
  { key: "pending", label: "Pending" },
  { key: "processing", label: "Processing" },
  { key: "shipped", label: "Shipped" },
  { key: "delivered", label: "Delivered" },
  { key: "cancelled", label: "Cancelled" },
  { key: "refunded", label: "Refunded" },
];

const router = useRouter();
const route = useRoute();
const orders = ref([]);
const orderSearchQuery = ref(readRouteSearchQuery(route.query.q));
const activeStatusTab = ref(readRouteStatusTab(route.query.status));
const busyOrderId = ref(0);
const ui = reactive({
  message: "",
  type: "",
});

const adminShellNavItems = computed(() => getAdminDashboardNavItems(appState.user));
const adminOrdersAvatarLabel = computed(() => getBusinessInitials(appState.user?.fullName || "Admin"));
const filteredOrders = computed(() => {
  const query = String(orderSearchQuery.value || "").trim().toLowerCase();

  return orders.value.filter((order) => {
    if (!matchesAdminOrderTab(order, activeStatusTab.value)) {
      return false;
    }

    if (!query) {
      return true;
    }

    return buildAdminOrderSearchHaystack(order).includes(query);
  });
});
const adminOrderSummary = computed(() => {
  const pending = orders.value.filter((order) =>
    ["pending_confirmation", "confirmed", "packed", "shipped", "partially_confirmed"]
      .includes(String(order.fulfillmentStatus || order.status || "").trim().toLowerCase()),
  ).length;
  const completed = orders.value.filter((order) =>
    ["delivered", "returned"].includes(String(order.fulfillmentStatus || order.status || "").trim().toLowerCase()),
  ).length;
  const issues = orders.value.filter((order) =>
    ["canceled", "cancelled", "failed", "refunded"].includes(String(order.fulfillmentStatus || order.status || "").trim().toLowerCase()),
  ).length;

  return [
    { label: "Total orders", value: orders.value.length, meta: "Across the marketplace" },
    { label: "In progress", value: pending, meta: "Need active monitoring" },
    { label: "Completed", value: completed, meta: "Delivered or returned" },
    { label: "Issues", value: issues, meta: "Canceled, failed, or refunded" },
  ];
});
const orderStatusTabs = computed(() =>
  ORDER_STATUS_TABS.map((tab) => ({
    ...tab,
    count: tab.key === "all"
      ? orders.value.length
      : orders.value.filter((order) => matchesAdminOrderTab(order, tab.key)).length,
  })),
);
const adminOrdersNotificationCount = computed(() => Number(adminOrderSummary.value[3]?.value || 0));

watch(
  () => route.query.q,
  (value) => {
    orderSearchQuery.value = readRouteSearchQuery(value);
  },
);

watch(
  () => route.query.status,
  (value) => {
    activeStatusTab.value = readRouteStatusTab(value);
  },
);

onMounted(async () => {
  try {
    const user = await ensureSessionLoaded();
    if (!user) {
      router.replace("/login");
      return;
    }

    if (user.role !== "admin") {
      router.replace("/");
      return;
    }

    await loadOrders();
  } finally {
    markRouteReady();
  }
});

async function loadOrders() {
  const { response, data } = await requestJson("/api/admin/orders");
  if (!response.ok || !data?.ok) {
    ui.message = resolveApiMessage(data, "Porosite e adminit nuk u ngarkuan.");
    ui.type = "error";
    orders.value = [];
    return;
  }

  orders.value = Array.isArray(data.orders) ? data.orders : [];
  ui.message = "";
  ui.type = "";
}

function readRouteSearchQuery(value) {
  if (Array.isArray(value)) {
    return String(value[0] || "").trim();
  }

  return String(value || "").trim();
}

function readRouteStatusTab(value) {
  const normalizedValue = Array.isArray(value) ? String(value[0] || "") : String(value || "");
  return ORDER_STATUS_TABS.some((tab) => tab.key === normalizedValue) ? normalizedValue : "all";
}

async function syncRouteFilters() {
  await router.replace({
    path: route.path,
    query: {
      ...route.query,
      q: String(orderSearchQuery.value || "").trim() || undefined,
      status: activeStatusTab.value !== "all" ? activeStatusTab.value : undefined,
    },
  });
}

async function handleAdminOrderSearch() {
  orderSearchQuery.value = String(orderSearchQuery.value || "").trim();
  await syncRouteFilters();
}

async function setAdminOrderTab(tabKey) {
  const nextTab = ORDER_STATUS_TABS.some((tab) => tab.key === tabKey) ? tabKey : "all";
  if (nextTab === activeStatusTab.value) {
    return;
  }

  activeStatusTab.value = nextTab;
  await syncRouteFilters();
}

async function handleUpdateOrderStatus(payload) {
  const orderId = Number(payload?.orderId || 0);
  const orderItemIds = Array.isArray(payload?.orderItemIds)
    ? payload.orderItemIds.map((itemId) => Number(itemId || 0)).filter((itemId) => itemId > 0)
    : [];

  if (!orderId || !orderItemIds.length) {
    ui.message = "Nuk u gjeten artikujt e porosise per perditesim.";
    ui.type = "error";
    return;
  }

  busyOrderId.value = orderId;
  const successfulItemIds = [];
  let lastMessage = "";
  try {
    for (const orderItemId of orderItemIds) {
      const { response, data } = await requestJson("/api/orders/status", {
        method: "POST",
        body: JSON.stringify({
          orderItemId,
          fulfillmentStatus: payload.fulfillmentStatus,
          trackingCode: payload.trackingCode,
          trackingUrl: payload.trackingUrl,
        }),
      });
      if (!response.ok || !data?.ok) {
        if (successfulItemIds.length) {
          applyOrderItemsUpdate({
            orderId,
            orderItemIds: successfulItemIds,
            fulfillmentStatus: payload.fulfillmentStatus,
            trackingCode: payload.trackingCode,
            trackingUrl: payload.trackingUrl,
          });
          ui.message = `${successfulItemIds.length}/${orderItemIds.length} artikuj u perditesuan. ${resolveApiMessage(data, "Pjesa tjeter nuk u ruajt.")}`;
        } else {
          ui.message = resolveApiMessage(data, "Statusi nuk u ruajt.");
        }
        ui.type = "error";
        return;
      }

      successfulItemIds.push(orderItemId);
      lastMessage = data.message || lastMessage;
    }

    applyOrderItemsUpdate({
      orderId,
      orderItemIds: successfulItemIds,
      fulfillmentStatus: payload.fulfillmentStatus,
      trackingCode: payload.trackingCode,
      trackingUrl: payload.trackingUrl,
    });
    ui.message = lastMessage || "Statusi u ruajt.";
    ui.type = "success";
  } finally {
    busyOrderId.value = 0;
  }
}

function applyOrderItemsUpdate(payload) {
  const orderItemIds = Array.isArray(payload?.orderItemIds)
    ? payload.orderItemIds.map((itemId) => Number(itemId || 0)).filter((itemId) => itemId > 0)
    : [];
  const nextStatus = String(payload?.fulfillmentStatus || "").trim().toLowerCase();
  const timestamp = new Date().toISOString();

  orders.value = orders.value.map((order) => {
    let hasUpdatedItem = false;
    const nextItems = Array.isArray(order?.items)
      ? order.items.map((item) => {
        if (!orderItemIds.includes(Number(item?.id || 0))) {
          return item;
        }

        hasUpdatedItem = true;
        return {
          ...item,
          fulfillmentStatus: nextStatus || item.fulfillmentStatus,
          trackingCode: String(payload?.trackingCode || "").trim(),
          trackingUrl: String(payload?.trackingUrl || "").trim(),
          confirmedAt: nextStatus === "confirmed" ? timestamp : item.confirmedAt,
          shippedAt: nextStatus === "shipped" ? timestamp : item.shippedAt,
          deliveredAt: nextStatus === "delivered" ? timestamp : item.deliveredAt,
          cancelledAt: nextStatus === "cancelled" ? timestamp : item.cancelledAt,
        };
      })
      : [];

    if (!hasUpdatedItem) {
      return order;
    }

    const nextOrderStatus = summarizeOrderFulfillmentStatus(nextItems);
    return {
      ...order,
      items: nextItems,
      fulfillmentStatus: nextOrderStatus,
      status: nextOrderStatus,
    };
  });
}

function buildAdminOrderSearchHaystack(order) {
  const itemText = Array.isArray(order?.items)
    ? order.items.map((item) => [
      item?.title,
      item?.productTitle,
      item?.businessName,
      item?.variantLabel,
      item?.trackingCode,
    ].filter(Boolean).join(" ")).join(" ")
    : "";

  return [
    order?.id,
    order?.customerName,
    order?.customerEmail,
    order?.fulfillmentStatus,
    order?.status,
    order?.paymentMethod,
    itemText,
  ]
    .filter(Boolean)
    .join(" ")
    .toLowerCase();
}

function matchesAdminOrderTab(order, tabKey) {
  const normalizedStatus = String(order?.fulfillmentStatus || order?.status || "").trim().toLowerCase();

  if (tabKey === "all") {
    return true;
  }
  if (tabKey === "pending") {
    return ["pending_confirmation", "confirmed", "partially_confirmed"].includes(normalizedStatus);
  }
  if (tabKey === "processing") {
    return normalizedStatus === "packed";
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
  if (tabKey === "refunded") {
    return ["returned", "refunded"].includes(normalizedStatus);
  }

  return true;
}
</script>

<template>
  <section class="market-page market-page--wide dashboard-page admin-orders-page" aria-label="Porosit e adminit">
    <DashboardShell
      :nav-items="adminShellNavItems"
      active-key="orders"
      :brand-initial="adminOrdersAvatarLabel"
      brand-title="Tregio Admin"
      brand-subtitle="Marketplace control"
      :brand-image-path="appState.user?.profileImagePath || ''"
      brand-fallback-icon="users"
      :profile-image-path="appState.user?.profileImagePath || ''"
      profile-fallback-icon="users"
      :profile-name="appState.user?.fullName || 'Admin'"
      :profile-subtitle="'Order operations'"
      :search-query="orderSearchQuery"
      search-placeholder="Search orders, users, products"
      :notification-count="adminOrdersNotificationCount"
      @update:search-query="orderSearchQuery = $event"
      @submit-search="handleAdminOrderSearch"
    >
      <header class="dashboard-section dashboard-page__hero">
        <div class="market-page__header-copy">
          <p class="market-page__eyebrow">Admin orders</p>
          <h1>Marketplace order overview</h1>
          <p>Review order flow, focus on exceptions faster, and keep fulfillment status changes in one clear list.</p>
        </div>
      </header>

      <div
        v-if="ui.message"
        class="market-status"
        :class="{ 'market-status--error': ui.type === 'error', 'market-status--success': ui.type === 'success' }"
        role="status"
        aria-live="polite"
      >
        {{ ui.message }}
      </div>

      <div v-if="orders.length === 0" class="market-empty">
        <h2>No admin orders to review</h2>
        <p>Porosite do te shfaqen ketu sapo te kete aktivitet qe kerkon mbikeqyrje administrative.</p>
      </div>

      <section v-else class="dashboard-section" aria-live="polite">
        <div class="dashboard-section__head">
          <div>
            <p class="market-page__eyebrow">Live queue</p>
            <h2>Orders</h2>
            <p class="dashboard-note">{{ filteredOrders.length }} / {{ orders.length }} records</p>
          </div>
          <span class="market-pill market-pill--accent">{{ filteredOrders.length }} visible</span>
        </div>

        <div class="dashboard-status-tabs" aria-label="Filter admin orders by status">
          <button
            v-for="tab in orderStatusTabs"
            :key="tab.key"
            class="dashboard-status-tab"
            :class="{ 'is-active': activeStatusTab === tab.key }"
            type="button"
            @click="setAdminOrderTab(tab.key)"
          >
            <span>{{ tab.label }}</span>
            <strong>{{ tab.count }}</strong>
          </button>
        </div>

        <div v-if="filteredOrders.length === 0" class="market-empty">
          <h3>No matching orders</h3>
          <p>Nuk u gjet asnje porosi per kete kerkim ose filter.</p>
        </div>

        <div v-else class="dashboard-card-list">
          <BusinessOrderCard
            v-for="order in filteredOrders"
            :key="order.id"
            :order="order"
            can-manage-status
            show-admin-finance
            :busy-order-id="busyOrderId"
            @update-order-status="handleUpdateOrderStatus"
          />
        </div>
      </section>
    </DashboardShell>
  </section>
</template>
