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
    <IonContent class="app-gradient" :fullscreen="true">
      <div class="mobile-page">
        <AppPageHeader
          kicker="Porosite"
          title="Historiku i porosive nga i njejti account."
          subtitle="Kjo faqe lexon te njejtin data source si seksioni i porosive ne web."
          back-to="/tabs/account"
        />

        <section v-if="confirmationMessage" class="surface-card surface-card--strong section-card">
          <p class="section-kicker">Konfirmim</p>
          <p class="section-copy">{{ confirmationMessage }}</p>
        </section>

        <section v-if="selectedOrderId > 0" class="surface-card section-card order-push-banner">
          <p class="section-kicker">Nga njoftimi</p>
          <p class="section-copy">
            Po shikon porosine <strong>#{{ selectedOrderId }}</strong>
            <template v-if="selectedOrderStatus"> me status <strong>{{ selectedOrderStatus }}</strong></template>.
          </p>
        </section>

        <section v-if="!sessionState.sessionLoaded || loading" class="surface-card empty-panel">
          <IonSpinner name="crescent" />
        </section>

        <EmptyStatePanel
          v-else-if="!sessionState.user"
          title="Kyçu per te pare porosite"
          copy="Pasi te kyçesh, porosite nga i njejti backend do te shfaqen ketu."
        >
          <IonButton class="cta-button orders-login-button" @click="router.push({ path: '/login', query: { redirect: route.fullPath } })">
            Login
          </IonButton>
        </EmptyStatePanel>

        <template v-else-if="orders.length">
          <section class="surface-card surface-card--strong section-card summary-surface-card">
            <div class="section-head">
              <div>
                <p class="section-kicker">Panorama</p>
                <h2>Porosite e tua ne levizje</h2>
              </div>
            </div>

            <div class="mini-stat-grid">
              <article class="mini-stat">
                <strong>{{ orderSummary.total }}</strong>
                <span>gjithsej</span>
              </article>
              <article class="mini-stat">
                <strong>{{ orderSummary.active }}</strong>
                <span>aktive</span>
              </article>
              <article class="mini-stat">
                <strong>{{ orderSummary.delivered }}</strong>
                <span>te dorezuara</span>
              </article>
            </div>
          </section>

          <div class="stack-list">
            <article
              v-for="order in displayOrders"
              :id="`order-${order.id}`"
              :key="order.id"
              class="surface-card order-card"
              :class="{ 'is-highlighted': selectedOrderId > 0 && selectedOrderId === order.id }"
            >
              <div class="order-card-top">
                <div>
                  <p class="section-kicker">Order #{{ order.id }}</p>
                  <h3>{{ formatOrderStatusLabel(order.fulfillmentStatus || order.status) }}</h3>
                </div>
                <span class="order-status-badge" :class="`is-${getOrderStatusTone(order.fulfillmentStatus || order.status)}`">
                  {{ formatOrderStatusBadgeLabel(order.fulfillmentStatus || order.status) }}
                </span>
              </div>

              <div class="order-card-meta">
                <span>{{ formatRelativeDate(order.createdAt) }}</span>
                <span v-if="getOrderItemsCount(order)">{{ getOrderItemsCount(order) }} artikuj</span>
                <strong>{{ formatPrice(order.totalAmount) }}</strong>
              </div>

              <div class="order-timeline">
                <div
                  v-for="step in buildFulfillmentTimeline(order)"
                  :key="`${order.id}-${step.key}`"
                  class="order-timeline-step"
                  :class="{ 'is-completed': step.isCompleted, 'is-current': step.isCurrent, 'is-delivered': step.isDelivered }"
                >
                  <span class="order-timeline-dot" />
                  <div class="order-timeline-copy">
                    <strong>{{ step.label }}</strong>
                    <small v-if="step.meta">{{ step.meta }}</small>
                  </div>
                </div>
              </div>

              <p
                v-if="getOrderTerminalEvent(order)"
                class="order-terminal-note"
                :class="`is-${getOrderTerminalEvent(order)?.tone}`"
              >
                <strong>{{ getOrderTerminalEvent(order)?.label }}</strong>
                <span v-if="getOrderTerminalEvent(order)?.meta">{{ getOrderTerminalEvent(order)?.meta }}</span>
              </p>

              <div class="order-card-actions">
                <IonButton class="ghost-button" @click="openInvoice(order.id)">
                  Invoice
                </IonButton>
                <IonButton class="ghost-button" @click="router.push('/messages')">
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

<style scoped>
.orders-login-button {
  margin-top: 14px;
}

.order-card {
  display: flex;
  flex-direction: column;
  gap: 14px;
  padding: 16px;
}

.order-card.is-highlighted {
  border-color: var(--trego-selection-border);
  box-shadow: var(--trego-selection-shadow);
}

.order-push-banner strong {
  color: var(--trego-dark);
}

.order-card-top {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 12px;
}

.order-card-top h3 {
  margin: 0;
  color: var(--trego-dark);
  font-size: 1.02rem;
  line-height: 1.2;
}

.order-status-badge {
  display: inline-flex;
  min-height: 32px;
  align-items: center;
  justify-content: center;
  padding: 0 12px;
  border-radius: 999px;
  font-size: 0.74rem;
  font-weight: 800;
  white-space: nowrap;
  background: rgba(255, 255, 255, 0.74);
  color: var(--trego-dark);
}

.order-status-badge.is-pending {
  color: #9a5500;
  background: rgba(255, 208, 120, 0.28);
}

.order-status-badge.is-warning {
  color: #85521d;
  background: rgba(255, 188, 128, 0.24);
}

.order-status-badge.is-success {
  color: #1f6b4c;
  background: rgba(86, 198, 142, 0.22);
}

.order-status-badge.is-danger {
  color: #a24545;
  background: rgba(208, 108, 108, 0.18);
}

.order-card-meta {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 10px;
  color: var(--trego-muted);
  font-size: 0.8rem;
}

.order-card-meta strong {
  margin-left: auto;
  color: var(--trego-dark);
  font-size: 0.96rem;
}

.order-timeline {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.order-timeline-step {
  display: grid;
  grid-template-columns: 18px minmax(0, 1fr);
  gap: 10px;
  align-items: start;
  opacity: 0.65;
}

.order-timeline-step.is-completed,
.order-timeline-step.is-current,
.order-timeline-step.is-delivered {
  opacity: 1;
}

.order-timeline-dot {
  position: relative;
  width: 12px;
  height: 12px;
  margin-top: 2px;
  border-radius: 999px;
  background: rgba(47, 52, 70, 0.16);
  box-shadow: inset 0 0 0 1px rgba(255, 255, 255, 0.82);
}

.order-timeline-step.is-completed .order-timeline-dot,
.order-timeline-step.is-current .order-timeline-dot,
.order-timeline-step.is-delivered .order-timeline-dot {
  background: rgba(255, 106, 43, 0.92);
}

.order-timeline-copy {
  display: flex;
  flex-direction: column;
  gap: 3px;
}

.order-timeline-copy strong {
  color: var(--trego-dark);
  font-size: 0.83rem;
}

.order-timeline-copy small {
  color: var(--trego-muted);
  font-size: 0.72rem;
  line-height: 1.35;
}

.order-terminal-note {
  display: flex;
  flex-direction: column;
  gap: 4px;
  margin: 0;
  padding: 12px 14px;
  border-radius: 18px;
  background: rgba(255, 255, 255, 0.72);
  color: var(--trego-dark);
}

.order-terminal-note.is-cancelled {
  background: rgba(208, 108, 108, 0.12);
  color: var(--trego-danger);
}

.order-terminal-note.is-returned {
  background: rgba(86, 198, 142, 0.14);
  color: #1f6b4c;
}

.order-card-actions {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 10px;
}
</style>
