import type { OrderItem, ProductItem } from "../types/models";
import { API_BASE_URL } from "./config";

export function formatPrice(value: number | string | null | undefined): string {
  const numericValue = Number(value || 0);
  return new Intl.NumberFormat("sq-AL", {
    style: "currency",
    currency: "EUR",
    maximumFractionDigits: 0,
  }).format(Number.isFinite(numericValue) ? numericValue : 0);
}

export function formatCount(value: number | string | null | undefined): string {
  const numericValue = Number(value || 0);
  return new Intl.NumberFormat("sq-AL", {
    maximumFractionDigits: 0,
  }).format(Number.isFinite(numericValue) ? Math.max(0, numericValue) : 0);
}

export function formatRelativeDate(value: string | undefined): string {
  if (!value) {
    return "";
  }

  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return "";
  }

  return date.toLocaleDateString("sq-AL", {
    day: "2-digit",
    month: "short",
    year: "numeric",
  });
}

export function formatDateLabel(value: string | undefined): string {
  if (!value) {
    return "";
  }

  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return "";
  }

  return date.toLocaleString("sq-AL", {
    day: "2-digit",
    month: "short",
    hour: "2-digit",
    minute: "2-digit",
  });
}

export function getProductImage(product: Partial<ProductItem> | null | undefined): string {
  const rawPath = String(product?.imagePath || "").trim();
  if (!rawPath) {
    return "https://images.unsplash.com/photo-1523275335684-37898b6baf30?auto=format&fit=crop&w=900&q=80";
  }

  if (/^https?:\/\//i.test(rawPath)) {
    return rawPath;
  }

  return `${API_BASE_URL}${rawPath.startsWith("/") ? rawPath : `/${rawPath}`}`;
}

export function getDiscountPercent(product: Partial<ProductItem>): number {
  const price = Number(product.price || 0);
  const compareAt = Number(product.compareAtPrice || 0);

  if (!Number.isFinite(compareAt) || compareAt <= price || compareAt <= 0) {
    return 0;
  }

  return Math.max(0, Math.round(((compareAt - price) / compareAt) * 100));
}

export function formatOrderStatusLabel(status: string | undefined): string {
  const labels: Record<string, string> = {
    pending_confirmation: "Porosia pret konfirmim",
    confirmed: "Porosia u konfirmua",
    partially_confirmed: "Porosia pjeserisht u konfirmua",
    pending: "Ne pritje",
    packed: "Po pergatitet",
    shipped: "Ne transport",
    delivered: "E dorezuar",
    cancelled: "E anuluar",
    returned: "E kthyer",
  };

  return labels[String(status || "").trim().toLowerCase()] || "Porosia";
}

export function formatOrderStatusBadgeLabel(status: string | undefined): string {
  const labels: Record<string, string> = {
    pending_confirmation: "Pret konfirmim",
    confirmed: "Konfirmuar",
    partially_confirmed: "Pjeserisht",
    packed: "Paketuar",
    shipped: "Ne dergese",
    delivered: "E dorezuar",
    cancelled: "Anuluar",
    returned: "Kthyer",
  };

  return labels[String(status || "").trim().toLowerCase()] || "Ne proces";
}

export function formatFulfillmentStatusLabel(status: string | undefined): string {
  const labels: Record<string, string> = {
    pending_confirmation: "Pret konfirmim",
    confirmed: "Konfirmuar",
    partially_confirmed: "Pjeserisht e konfirmuar",
    packed: "Paketuar",
    shipped: "Ne dergese",
    delivered: "E dorezuar",
    cancelled: "E anuluar",
    returned: "E kthyer",
  };

  return labels[String(status || "").trim().toLowerCase()] || "Ne proces";
}

export function getOrderStatusTone(status: string | undefined): "pending" | "success" | "warning" | "danger" | "neutral" {
  const normalizedStatus = String(status || "").trim().toLowerCase();
  if (normalizedStatus === "delivered" || normalizedStatus === "returned") {
    return "success";
  }
  if (normalizedStatus === "cancelled") {
    return "danger";
  }
  if (normalizedStatus === "packed" || normalizedStatus === "shipped" || normalizedStatus === "confirmed") {
    return "warning";
  }
  if (normalizedStatus === "pending_confirmation" || normalizedStatus === "partially_confirmed" || normalizedStatus === "pending") {
    return "pending";
  }

  return "neutral";
}

export interface OrderTimelineStep {
  key: string;
  label: string;
  meta: string;
  isCompleted: boolean;
  isCurrent: boolean;
  isDelivered: boolean;
}

export function buildFulfillmentTimeline(order: Partial<OrderItem> = {}): OrderTimelineStep[] {
  const normalizedStatus = String(order.fulfillmentStatus || order.status || "pending_confirmation").trim().toLowerCase() || "pending_confirmation";
  const progressSteps = ["pending_confirmation", "confirmed", "packed", "shipped", "delivered"];
  const indexedStatus = progressSteps.indexOf(normalizedStatus);
  const fallbackIndex = normalizedStatus === "returned" ? progressSteps.length - 1 : 0;
  const resolvedIndex = indexedStatus >= 0 ? indexedStatus : fallbackIndex;

  return progressSteps.map((stepKey, index) => {
    let meta = "";
    if (stepKey === "pending_confirmation") {
      meta = order.confirmationDueAt ? `Afati: ${formatDateLabel(order.confirmationDueAt)}` : "";
    } else if (stepKey === "confirmed") {
      meta = order.confirmedAt ? formatDateLabel(order.confirmedAt) : "";
    } else if (stepKey === "shipped") {
      meta = order.shippedAt ? formatDateLabel(order.shippedAt) : "";
    } else if (stepKey === "delivered") {
      meta = order.deliveredAt ? formatDateLabel(order.deliveredAt) : "";
    }

    return {
      key: stepKey,
      label: formatFulfillmentStatusLabel(stepKey),
      meta,
      isCompleted: index < resolvedIndex || (index === resolvedIndex && normalizedStatus === "delivered"),
      isCurrent: index === resolvedIndex && !["delivered", "cancelled", "returned"].includes(normalizedStatus),
      isDelivered: stepKey === "delivered" && ["delivered", "returned"].includes(normalizedStatus),
    };
  });
}

export function getOrderTerminalEvent(order: Partial<OrderItem> = {}): { label: string; meta: string; tone: "cancelled" | "returned" } | null {
  const normalizedStatus = String(order.fulfillmentStatus || order.status || "").trim().toLowerCase();
  if (normalizedStatus === "cancelled") {
    return {
      label: formatFulfillmentStatusLabel(normalizedStatus),
      meta: order.cancelledAt ? formatDateLabel(order.cancelledAt) : "",
      tone: "cancelled",
    };
  }

  if (normalizedStatus === "returned") {
    return {
      label: formatFulfillmentStatusLabel(normalizedStatus),
      meta: order.deliveredAt ? formatDateLabel(order.deliveredAt) : "",
      tone: "returned",
    };
  }

  return null;
}
