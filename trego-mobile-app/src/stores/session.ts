import { computed, reactive } from "vue";
import {
  fetchCart,
  fetchConversations,
  fetchCurrentUserOptional,
  fetchNotificationsCount,
  fetchWishlist,
  logoutUser,
} from "../lib/api";
import type { SessionUser } from "../types/models";

const state = reactive({
  user: null as SessionUser | null,
  sessionLoaded: false,
  wishlistCount: 0,
  cartCount: 0,
  messageUnreadCount: 0,
  notificationUnreadCount: 0,
});

let sessionPromise: Promise<SessionUser | null> | null = null;
let countsPromise: Promise<void> | null = null;

export const sessionState = state;

export const isAuthenticated = computed(() => Boolean(state.user));
export const isBusinessUser = computed(() => state.user?.role === "business");
export const activityBadgeCount = computed(
  () => Math.max(0, Number(state.messageUnreadCount || 0)) + Math.max(0, Number(state.notificationUnreadCount || 0)),
);

export async function ensureSession() {
  if (state.sessionLoaded) {
    return state.user;
  }

  if (sessionPromise) {
    return sessionPromise;
  }

  sessionPromise = (async () => {
    const user = await fetchCurrentUserOptional();
    state.user = user;
    state.sessionLoaded = true;
    if (user) {
      void refreshCounts();
    }
    return user;
  })();

  try {
    return await sessionPromise;
  } finally {
    sessionPromise = null;
  }
}

export async function refreshSession() {
  state.sessionLoaded = false;
  return ensureSession();
}

export async function refreshCounts() {
  if (!state.user) {
    state.wishlistCount = 0;
    state.cartCount = 0;
    state.messageUnreadCount = 0;
    state.notificationUnreadCount = 0;
    return;
  }

  if (countsPromise) {
    return countsPromise;
  }

  countsPromise = (async () => {
    const [wishlist, cart, conversations, notificationUnreadCount] = await Promise.all([
      fetchWishlist(),
      fetchCart(),
      fetchConversations(),
      fetchNotificationsCount(),
    ]);
    state.wishlistCount = wishlist.length;
    state.cartCount = cart.reduce((total, item) => total + Math.max(0, Number(item.quantity || 0)), 0);
    state.messageUnreadCount = conversations.reduce(
      (total, item) => total + Math.max(0, Number(item.unreadCount || 0)),
      0,
    );
    state.notificationUnreadCount = Math.max(0, Number(notificationUnreadCount || 0));
  })();

  try {
    await countsPromise;
  } finally {
    countsPromise = null;
  }
}

export async function clearSession() {
  await logoutUser();
  state.user = null;
  state.sessionLoaded = true;
  state.wishlistCount = 0;
  state.cartCount = 0;
  state.messageUnreadCount = 0;
  state.notificationUnreadCount = 0;
}
