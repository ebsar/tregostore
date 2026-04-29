<script setup lang="ts">
import { IonButton, IonContent, IonPage, IonSpinner } from "@ionic/vue";
import { computed, nextTick, onMounted, ref, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import AppPageHeader from "../components/AppPageHeader.vue";
import EmptyStatePanel from "../components/EmptyStatePanel.vue";
import { consumeOrderConfirmationMessage } from "../lib/checkout";
import { fetchOrders } from "../lib/api";
import {
  buildFulfillmentTimeline,
  formatOrderStatusBadgeLabel,
  formatOrderStatusLabel,
  formatPrice,
  formatRelativeDate,
  getOrderStatusTone,
  getOrderTerminalEvent,
} from "../lib/format";
import { createApiUrl } from "../lib/config";
import type { OrderItem } from "../types/models";
import { ensureSession, sessionState } from "../stores/session";

const route = useRoute();
const router = useRouter();
const orders = ref<OrderItem[]>([]);
const confirmationMessage = ref("");
const loading = ref(true);
const selectedOrderId = computed(() => {
  const nextValue = Number(route.query.orderId || 0);
  return Number.isFinite(nextValue) ? Math.max(0, nextValue) : 0;
});
const selectedOrderStatus = computed(() => String(route.query.status || "").trim());
const displayOrders = computed(() => {
  if (selectedOrderId.value <= 0) {
    return orders.value;
  }

  const selected = orders.value.find((order) => Number(order.id || 0) === selectedOrderId.value);
  if (!selected) {
    return orders.value;
  }

  return [
    selected,
    ...orders.value.filter((order) => Number(order.id || 0) !== selectedOrderId.value),
  ];
});

const orderSummary = computed(() => {
  const normalizedOrders = orders.value || [];
  const total = normalizedOrders.length;
  const active = normalizedOrders.filter((order) => {
    const status = String(order.fulfillmentStatus || order.status || "").trim().toLowerCase();
    return !["delivered", "returned", "cancelled"].includes(status);
  }).length;
  const delivered = normalizedOrders.filter((order) => {
    const status = String(order.fulfillmentStatus || order.status || "").trim().toLowerCase();
    return ["delivered", "returned"].includes(status);
  }).length;

  return { total, active, delivered };
});

onMounted(async () => {
  confirmationMessage.value = consumeOrderConfirmationMessage();
  try {
    await ensureSession();
    if (sessionState.user) {
      orders.value = await fetchOrders();
      await nextTick();
      await scrollToSelectedOrder();
    }
  } finally {
    loading.value = false;
  }
});

watch(
  () => route.query.orderId,
  async () => {
    await nextTick();
    await scrollToSelectedOrder();
  },
);

function getOrderItemsCount(order: OrderItem) {
  if (Array.isArray(order.items) && order.items.length) {
    return order.items.reduce((total, item) => total + Math.max(1, Number(item.quantity || 1)), 0);
  }

  return 0;
}

function openInvoice(orderId: number) {
  const invoiceUrl = createApiUrl(`/api/orders/invoice?id=${encodeURIComponent(String(orderId))}`);
  if (typeof window === "undefined") {
    return;
  }

  const popupWindow = window.open(invoiceUrl, "_blank", "noopener,noreferrer");
  if (!popupWindow) {
    window.location.href = invoiceUrl;
  }
}

async function scrollToSelectedOrder() {
  if (selectedOrderId.value <= 0 || typeof document === "undefined") {
    return;
  }

  const target = document.getElementById(`order-${selectedOrderId.value}`);
  target?.scrollIntoView({ block: "center", behavior: "smooth" });
}
</script>

<template>
  <IonPage>
    <IonContent :fullscreen="true">
      <div class="trego-mobile-screen">
        <AppPageHeader
          kicker="Porosite"
          title="Historiku i porosive nga i njejti account."
          subtitle="Kjo faqe lexon te njejtin data source si seksioni i porosive ne web."
          back-to="/tabs/account"
        />

        <section v-if="confirmationMessage">
          <p>Konfirmim</p>
          <p>{{ confirmationMessage }}</p>
        </section>

        <section v-if="selectedOrderId > 0">
          <p>Nga njoftimi</p>
          <p>
            Po shikon porosine <strong>#{{ selectedOrderId }}</strong>
            <template v-if="selectedOrderStatus"> me status <strong>{{ selectedOrderStatus }}</strong></template>.
          </p>
        </section>

        <section v-if="!sessionState.sessionLoaded || loading">
          <IonSpinner name="crescent" />
        </section>

        <EmptyStatePanel
          v-else-if="!sessionState.user"
          title="Kyçu per te pare porosite"
          copy="Pasi te kyçesh, porosite nga i njejti backend do te shfaqen ketu."
        >
          <IonButton @click="router.push({ path: '/login', query: { redirect: route.fullPath } })">
            Login
          </IonButton>
        </EmptyStatePanel>

        <template v-else-if="orders.length">
          <section>
            <div>
              <div>
                <p>Panorama</p>
                <h2>Porosite e tua ne levizje</h2>
              </div>
            </div>

            <div>
              <article>
                <strong>{{ orderSummary.total }}</strong>
                <span>gjithsej</span>
              </article>
              <article>
                <strong>{{ orderSummary.active }}</strong>
                <span>aktive</span>
              </article>
              <article>
                <strong>{{ orderSummary.delivered }}</strong>
                <span>te dorezuara</span>
              </article>
            </div>
          </section>

          <div>
            <article
              v-for="order in displayOrders"
             
              :key="order.id"
             
             
            >
              <div>
                <div>
                  <p>Order #{{ order.id }}</p>
                  <h3>{{ formatOrderStatusLabel(order.fulfillmentStatus || order.status) }}</h3>
                </div>
                <span>
                  {{ formatOrderStatusBadgeLabel(order.fulfillmentStatus || order.status) }}
                </span>
              </div>

              <div>
                <span>{{ formatRelativeDate(order.createdAt) }}</span>
                <span v-if="getOrderItemsCount(order)">{{ getOrderItemsCount(order) }} artikuj</span>
                <strong>{{ formatPrice(order.totalAmount) }}</strong>
              </div>

              <div>
                <div
                  v-for="step in buildFulfillmentTimeline(order)"
                  :key="`${order.id}-${step.key}`"
                 
                 
                >
                  <span />
                  <div>
                    <strong>{{ step.label }}</strong>
                    <small v-if="step.meta">{{ step.meta }}</small>
                  </div>
                </div>
              </div>

              <p
                v-if="getOrderTerminalEvent(order)"
               
               
              >
                <strong>{{ getOrderTerminalEvent(order)?.label }}</strong>
                <span v-if="getOrderTerminalEvent(order)?.meta">{{ getOrderTerminalEvent(order)?.meta }}</span>
              </p>

              <div>
                <IonButton @click="openInvoice(order.id)">
                  Invoice
                </IonButton>
                <IonButton @click="router.push('/messages')">
                  Support
                </IonButton>
              </div>
            </article>
          </div>
        </template>

        <EmptyStatePanel
          v-else
          title="Asnje porosi ende"
          copy="Kur checkout-i krijon porosi ne backend, ato do te shfaqen edhe ne app."
        />
      </div>
    </IonContent>
  </IonPage>
</template>
