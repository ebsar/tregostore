export interface CheckoutAddressDraft {
  addressLine: string;
  city: string;
  country: string;
  zipCode: string;
  phoneNumber: string;
}

export interface DeliveryMethodOption {
  value: string;
  label: string;
  description: string;
  shippingAmount?: number;
  estimatedDeliveryText?: string;
  badge?: string;
}

export const CHECKOUT_ADDRESS_DRAFT_KEY = "trego_checkout_address_draft";
export const CHECKOUT_PAYMENT_METHOD_KEY = "trego_checkout_payment_method";
export const CHECKOUT_DELIVERY_METHOD_KEY = "trego_checkout_delivery_method";
export const CHECKOUT_SELECTED_CART_IDS_KEY = "trego_checkout_selected_cart_ids";
export const ORDER_CONFIRMATION_MESSAGE_KEY = "trego_order_confirmation_message";

export const DELIVERY_METHOD_OPTIONS: DeliveryMethodOption[] = [
  {
    value: "standard",
    label: "Dergese standard",
    description: "Opsioni me i balancuar, me kosto qe llogaritet sipas biznesit ne shporte.",
    shippingAmount: 2.5,
    estimatedDeliveryText: "2-4 dite pune",
    badge: "Opsioni 01",
  },
  {
    value: "express",
    label: "Dergese express",
    description: "Per porosi me urgjence, nese bizneset ne shporte e kane aktivizuar.",
    shippingAmount: 4.9,
    estimatedDeliveryText: "1-2 dite pune",
    badge: "Opsioni 02",
  },
  {
    value: "pickup",
    label: "Terheqje ne biznes",
    description: "Rezervo online dhe terhiqe produktin direkt te biznesi kur pickup eshte aktiv.",
    shippingAmount: 0,
    estimatedDeliveryText: "Gati per terheqje brenda 24 oresh",
    badge: "Opsioni 03",
  },
];

export function createEmptyAddress(): CheckoutAddressDraft {
  return {
    addressLine: "",
    city: "",
    country: "",
    zipCode: "",
    phoneNumber: "",
  };
}

export function normalizeAddress(address: Partial<CheckoutAddressDraft> | null | undefined): CheckoutAddressDraft {
  return {
    addressLine: String(address?.addressLine || address?.["address_line"] || "").trim(),
    city: String(address?.city || "").trim(),
    country: String(address?.country || "").trim(),
    zipCode: String(address?.zipCode || address?.["zip_code"] || "").trim(),
    phoneNumber: String(address?.phoneNumber || address?.["phone_number"] || "").trim(),
  };
}

function persistJson(key: string, value: unknown) {
  try {
    window.sessionStorage.setItem(key, JSON.stringify(value));
  } catch (error) {
    console.error(error);
  }
}

function readJson<T>(key: string, fallback: T): T {
  try {
    const rawValue = window.sessionStorage.getItem(key);
    if (!rawValue) {
      return fallback;
    }

    return JSON.parse(rawValue) as T;
  } catch (error) {
    console.error(error);
    return fallback;
  }
}

export function persistCheckoutSelectedCartIds(ids: Array<number | string>) {
  persistJson(
    CHECKOUT_SELECTED_CART_IDS_KEY,
    ids
      .map((id) => Number(id))
      .filter((id) => Number.isFinite(id) && id > 0),
  );
}

export function readCheckoutSelectedCartIds(): number[] {
  const parsedValue = readJson<number[]>(CHECKOUT_SELECTED_CART_IDS_KEY, []);
  return Array.isArray(parsedValue)
    ? parsedValue.map((id) => Number(id)).filter((id) => Number.isFinite(id) && id > 0)
    : [];
}

export function persistCheckoutAddressDraft(address: Partial<CheckoutAddressDraft>) {
  persistJson(CHECKOUT_ADDRESS_DRAFT_KEY, normalizeAddress(address));
}

export function readCheckoutAddressDraft(): CheckoutAddressDraft | null {
  const parsedValue = readJson<CheckoutAddressDraft | null>(CHECKOUT_ADDRESS_DRAFT_KEY, null);
  return parsedValue ? normalizeAddress(parsedValue) : null;
}

export function persistCheckoutPaymentMethod(method: string) {
  try {
    window.sessionStorage.setItem(CHECKOUT_PAYMENT_METHOD_KEY, String(method || "").trim());
  } catch (error) {
    console.error(error);
  }
}

export function readCheckoutPaymentMethod(): string {
  try {
    return String(window.sessionStorage.getItem(CHECKOUT_PAYMENT_METHOD_KEY) || "").trim();
  } catch (error) {
    console.error(error);
    return "";
  }
}

export function persistCheckoutDeliveryMethod(method: string) {
  try {
    window.sessionStorage.setItem(CHECKOUT_DELIVERY_METHOD_KEY, String(method || "").trim() || "standard");
  } catch (error) {
    console.error(error);
  }
}

export function readCheckoutDeliveryMethod(): string {
  try {
    return String(window.sessionStorage.getItem(CHECKOUT_DELIVERY_METHOD_KEY) || "").trim() || "standard";
  } catch (error) {
    console.error(error);
    return "standard";
  }
}

export function persistOrderConfirmationMessage(message: string) {
  try {
    const nextValue = String(message || "").trim();
    if (!nextValue) {
      return;
    }
    window.sessionStorage.setItem(ORDER_CONFIRMATION_MESSAGE_KEY, nextValue);
  } catch (error) {
    console.error(error);
  }
}

export function consumeOrderConfirmationMessage(): string {
  try {
    const value = String(window.sessionStorage.getItem(ORDER_CONFIRMATION_MESSAGE_KEY) || "").trim();
    if (!value) {
      return "";
    }
    window.sessionStorage.removeItem(ORDER_CONFIRMATION_MESSAGE_KEY);
    return value;
  } catch (error) {
    console.error(error);
    return "";
  }
}

export function clearCheckoutFlowState() {
  try {
    window.sessionStorage.removeItem(CHECKOUT_ADDRESS_DRAFT_KEY);
    window.sessionStorage.removeItem(CHECKOUT_PAYMENT_METHOD_KEY);
    window.sessionStorage.removeItem(CHECKOUT_DELIVERY_METHOD_KEY);
    window.sessionStorage.removeItem(CHECKOUT_SELECTED_CART_IDS_KEY);
  } catch (error) {
    console.error(error);
  }
}

export function getDeliveryMethodOption(deliveryMethod: string): DeliveryMethodOption {
  const normalizedValue = String(deliveryMethod || "").trim().toLowerCase() || "standard";
  return DELIVERY_METHOD_OPTIONS.find((option) => option.value === normalizedValue) || DELIVERY_METHOD_OPTIONS[0];
}

export function formatDeliveryMethodLabel(deliveryMethod: string): string {
  return getDeliveryMethodOption(deliveryMethod).label;
}
