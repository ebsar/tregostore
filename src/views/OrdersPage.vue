<script setup>
import { computed, onMounted, reactive, ref, watch } from "vue";
import { RouterLink, useRouter } from "vue-router";
import UserOrderCard from "../components/UserOrderCard.vue";
import { requestJson, resolveApiMessage } from "../lib/api";
import { consumeOrderConfirmationMessage, formatPrice } from "../lib/shop";
import { appState, ensureSessionLoaded, logoutUser, markRouteReady } from "../stores/app-state";

const router = useRouter();
const ORDERS_PER_PAGE = 6;

const orders = ref([]);
const busyOrderItemId = ref(0);
const selectedOrderId = ref(0);
const currentPage = ref(1);

const ui = reactive({
  message: "",
  type: "",
  guest: false,
});

const dashboardMenuItems = computed(() => {
  const role = String(appState.user?.role || "").trim().toLowerCase();

  if (role === "admin") {
    return [
      { href: "/llogaria", label: "Dashboard", icon: "dashboard" },
      { href: "/admin-porosite", label: "Order History", icon: "orders" },
      { href: "/admin-products", label: "Products", icon: "bag" },
      { href: "/bizneset-e-regjistruara", label: "Businesses", icon: "pin" },
      { href: "/wishlist", label: "Wishlist", icon: "heart" },
      { href: "/krahaso", label: "Compare", icon: "compare" },
      { href: "/te-dhenat-personale", label: "Setting", icon: "settings" },
    ];
  }

  if (role === "business") {
    return [
      { href: "/llogaria", label: "Dashboard", icon: "dashboard" },
      { href: "/porosite-e-biznesit", label: "Order History", icon: "orders" },
      { href: "/porosite-e-biznesit", label: "Track Order", icon: "pin" },
      { href: "/cart", label: "Shopping Cart", icon: "bag" },
      { href: "/wishlist", label: "Wishlist", icon: "heart" },
      { href: "/krahaso", label: "Compare", icon: "compare" },
      { href: "/adresat", label: "Cards & Address", icon: "card" },
      { href: "/kerko", label: "Browsing History", icon: "history" },
      { href: "/te-dhenat-personale", label: "Setting", icon: "settings" },
    ];
  }

  return [
    { href: "/llogaria", label: "Dashboard", icon: "dashboard" },
    { href: "/porosite", label: "Order History", icon: "orders", active: true },
    { href: "/track-order", label: "Track Order", icon: "pin" },
    { href: "/cart", label: "Shopping Cart", icon: "bag" },
    { href: "/wishlist", label: "Wishlist", icon: "heart" },
    { href: "/krahaso", label: "Compare", icon: "compare" },
    { href: "/adresat", label: "Cards & Address", icon: "card" },
    { href: "/kerko", label: "Browsing History", icon: "history" },
    { href: "/te-dhenat-personale", label: "Setting", icon: "settings" },
  ];
});

const pageCount = computed(() => Math.max(1, Math.ceil(orders.value.length / ORDERS_PER_PAGE)));

const paginatedOrders = computed(() => {
  const start = (currentPage.value - 1) * ORDERS_PER_PAGE;
  return orders.value.slice(start, start + ORDERS_PER_PAGE);
});

const selectedOrder = computed(() =>
  orders.value.find((order) => Number(order.id) === Number(selectedOrderId.value))
  || paginatedOrders.value[0]
  || null,
);

watch(orders, (nextOrders) => {
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
    await loadOrders();
  } finally {
    busyOrderItemId.value = 0;
  }
}

async function handleLogout() {
  const { response, data } = await logoutUser();
  if (!response.ok || !data?.ok) {
    ui.message = data?.message || "Dalja nga llogaria nuk funksionoi.";
    ui.type = "error";
    return;
  }

  await router.push("/");
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
    default:
      return "";
  }
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
  <section class="account-page orders-dashboard-page" aria-label="Order History">
    <div class="orders-breadcrumb-strip">
      <div class="orders-breadcrumb-inner">
        <nav class="orders-breadcrumbs" aria-label="Breadcrumb">
          <RouterLink to="/">Home</RouterLink>
          <span>›</span>
          <RouterLink to="/llogaria">User Account</RouterLink>
          <span>›</span>
          <RouterLink to="/llogaria">Dashboard</RouterLink>
          <span>›</span>
          <strong>Order History</strong>
        </nav>
      </div>
    </div>

    <div class="form-message" :class="ui.type" role="status" aria-live="polite">
      {{ ui.message }}
    </div>

    <section v-if="ui.guest" class="collection-empty-state collection-guest-gate">
      <h2>Per te pare porosite duhet te kyçesh.</h2>
      <p>Krijo llogari ose hyni ne llogarine tende per te ndjekur porosite dhe statusin e tyre.</p>
      <div class="collection-guest-gate-actions">
        <RouterLink class="nav-action nav-action-secondary" to="/login?redirect=%2Fporosite">
          Login
        </RouterLink>
        <RouterLink class="nav-action nav-action-primary" to="/signup?redirect=%2Fporosite">
          Sign Up
        </RouterLink>
      </div>
    </section>

    <div v-else class="orders-dashboard-layout">
      <aside class="orders-dashboard-sidebar">
        <div class="orders-dashboard-sidebar-card">
          <RouterLink
            v-for="item in dashboardMenuItems"
            :key="`${item.href}-${item.label}`"
            class="orders-dashboard-nav-link"
            :class="{ 'is-active': item.active }"
            :to="item.href"
          >
            <svg viewBox="0 0 24 24" aria-hidden="true">
              <path :d="renderDashboardIcon(item.icon)" />
            </svg>
            <span>{{ item.label }}</span>
          </RouterLink>

          <button class="orders-dashboard-nav-link orders-dashboard-nav-button" type="button" @click="handleLogout">
            <svg viewBox="0 0 24 24" aria-hidden="true">
              <path d="M15 5h4v14h-4M10 8l4 4-4 4M14 12H4" />
            </svg>
            <span>Log-out</span>
          </button>
        </div>
      </aside>

      <div class="orders-dashboard-main">
        <section class="orders-history-card">
          <div class="orders-history-card-head">
            <h1>ORDER HISTORY</h1>
          </div>

          <div v-if="orders.length === 0" class="orders-history-empty">
            <h2>Ju nuk keni asnje porosi.</h2>
          </div>

          <template v-else>
            <div class="orders-history-table-wrap">
              <table class="orders-history-table">
                <thead>
                  <tr>
                    <th>ORDER ID</th>
                    <th>STATUS</th>
                    <th>DATE</th>
                    <th>TOTAL</th>
                    <th>ACTION</th>
                  </tr>
                </thead>
                <tbody>
                  <tr
                    v-for="order in paginatedOrders"
                    :key="order.id"
                    :class="{ 'is-selected': Number(order.id) === Number(selectedOrderId) }"
                  >
                    <td class="orders-history-id">#{{ order.id || "-" }}</td>
                    <td>
                      <span
                        class="orders-history-status"
                        :class="getOrderHistoryStatus(order).tone"
                      >
                        {{ getOrderHistoryStatus(order).label }}
                      </span>
                    </td>
                    <td>{{ formatOrderDateTime(order.createdAt || "") }}</td>
                    <td>{{ formatOrderTotal(order) }}</td>
                    <td>
                      <button class="orders-history-action" type="button" @click="selectOrder(order)">
                        View Details
                        <span aria-hidden="true">→</span>
                      </button>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>

            <div v-if="pageCount > 1" class="orders-history-pagination" aria-label="Pagination">
              <button
                class="orders-history-page-button"
                type="button"
                :disabled="currentPage === 1"
                @click="goToPage(currentPage - 1)"
              >
                ←
              </button>
              <button
                v-for="page in pageCount"
                :key="`page-${page}`"
                class="orders-history-page-button"
                :class="{ 'is-active': currentPage === page }"
                type="button"
                @click="goToPage(page)"
              >
                {{ String(page).padStart(2, "0") }}
              </button>
              <button
                class="orders-history-page-button"
                type="button"
                :disabled="currentPage === pageCount"
                @click="goToPage(currentPage + 1)"
              >
                →
              </button>
            </div>
          </template>
        </section>

        <section v-if="selectedOrder" class="orders-history-detail">
          <UserOrderCard
            :order="selectedOrder"
            :busy-order-item-id="busyOrderItemId"
            @request-return="handleReturnRequest"
          />
        </section>
      </div>
    </div>
  </section>
</template>

<style scoped>
.orders-dashboard-page {
  width: min(1300px, calc(100vw - 48px));
  margin: 0 auto;
  padding: 0 0 80px;
}

.orders-breadcrumb-strip {
  margin-inline: calc(50% - 50vw);
  border-top: 1px solid rgba(15, 23, 42, 0.06);
  border-bottom: 1px solid rgba(15, 23, 42, 0.06);
  background: #f5f6f8;
}

.orders-breadcrumb-inner {
  width: min(1300px, calc(100vw - 48px));
  margin: 0 auto;
  padding: 28px 0;
}

.orders-breadcrumbs {
  display: flex;
  align-items: center;
  gap: 10px;
  flex-wrap: wrap;
  color: #64748b;
  font-size: 1rem;
}

.orders-breadcrumbs a {
  color: inherit;
  text-decoration: none;
}

.orders-breadcrumbs strong {
  color: #2496f3;
}

.orders-dashboard-layout {
  display: grid;
  grid-template-columns: 260px minmax(0, 1fr);
  gap: 38px;
  align-items: start;
  padding-top: 36px;
}

.orders-dashboard-sidebar-card {
  display: grid;
  background: #fff;
  border: 1px solid rgba(15, 23, 42, 0.08);
  border-radius: 8px;
  overflow: hidden;
  box-shadow: 0 24px 48px rgba(15, 23, 42, 0.06);
}

.orders-dashboard-nav-link,
.orders-dashboard-nav-button {
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

.orders-dashboard-nav-link svg,
.orders-dashboard-nav-button svg {
  width: 20px;
  height: 20px;
  fill: none;
  stroke: currentColor;
  stroke-width: 1.9;
  stroke-linecap: round;
  stroke-linejoin: round;
}

.orders-dashboard-nav-link.is-active {
  background: #ff7f32;
  color: #fff;
  font-weight: 700;
}

.orders-dashboard-nav-button {
  border-bottom: 0;
}

.orders-dashboard-main {
  display: grid;
  gap: 24px;
}

.orders-history-card {
  background: #fff;
  border: 1px solid rgba(15, 23, 42, 0.08);
  border-radius: 8px;
  overflow: hidden;
  box-shadow: 0 24px 48px rgba(15, 23, 42, 0.05);
}

.orders-history-card-head {
  padding: 18px 24px;
  border-bottom: 1px solid rgba(15, 23, 42, 0.08);
}

.orders-history-card-head h1 {
  margin: 0;
  color: #111827;
  font-size: 1.2rem;
  letter-spacing: -0.02em;
}

.orders-history-empty {
  padding: 40px 24px;
}

.orders-history-empty h2 {
  margin: 0;
  color: #111827;
  font-size: 1.2rem;
}

.orders-history-table-wrap {
  overflow-x: auto;
}

.orders-history-table {
  width: 100%;
  min-width: 780px;
  border-collapse: collapse;
}

.orders-history-table thead th {
  padding: 14px 24px;
  background: #f2f4f7;
  color: #5b6775;
  font-size: 0.92rem;
  font-weight: 700;
  text-align: left;
}

.orders-history-table tbody td {
  padding: 16px 24px;
  border-bottom: 1px solid rgba(15, 23, 42, 0.06);
  color: #4b5563;
  font-size: 1rem;
  vertical-align: middle;
}

.orders-history-table tbody tr.is-selected {
  background: #fff8f2;
}

.orders-history-id {
  color: #111827;
  font-weight: 800;
}

.orders-history-status {
  font-weight: 800;
}

.orders-history-status.is-progress {
  color: #ff7f32;
}

.orders-history-status.is-completed {
  color: #16a34a;
}

.orders-history-status.is-canceled {
  color: #ef4444;
}

.orders-history-action {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  border: 0;
  background: transparent;
  color: #2496f3;
  font-size: 1rem;
  font-weight: 700;
  cursor: pointer;
}

.orders-history-pagination {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 10px;
  padding: 28px 24px;
}

.orders-history-page-button {
  display: inline-flex;
  width: 40px;
  height: 40px;
  align-items: center;
  justify-content: center;
  border: 1px solid rgba(15, 23, 42, 0.12);
  border-radius: 999px;
  background: #fff;
  color: #111827;
  font-weight: 700;
  cursor: pointer;
}

.orders-history-page-button.is-active {
  border-color: #ff7f32;
  background: #ff7f32;
  color: #fff;
}

.orders-history-page-button:disabled {
  opacity: 0.45;
  cursor: default;
}

.orders-history-detail {
  display: grid;
}

@media (max-width: 1080px) {
  .orders-dashboard-layout {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 720px) {
  .orders-dashboard-page,
  .orders-breadcrumb-inner {
    width: min(100vw - 24px, 1300px);
  }

  .orders-dashboard-page {
    padding-bottom: 48px;
  }

  .orders-dashboard-layout {
    gap: 24px;
    padding-top: 24px;
  }

  .orders-dashboard-nav-link,
  .orders-dashboard-nav-button {
    min-height: 50px;
    padding-inline: 16px;
    font-size: 0.95rem;
  }

  .orders-history-card-head,
  .orders-history-table thead th,
  .orders-history-table tbody td {
    padding-inline: 16px;
  }

  .orders-history-pagination {
    flex-wrap: wrap;
  }
}
</style>
