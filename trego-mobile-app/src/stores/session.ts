import { computed, reactive } from "vue";
import {
  fetchCart,
  fetchConversations,
  fetchCurrentUserSessionState,
  fetchNotificationsCount,
  fetchWishlist,
  logoutUser,
} from "../lib/api";
import type { SessionUser } from "../types/models";
import { queryClient } from "../lib/query-client";
import { queryKeys } from "../lib/query-keys";

const state = reactive({
  user: null as SessionUser | null,
  sessionLoaded: false,
  wishlistCount: 0,
  cartCount: 0,
  messageUnreadCount: 0,
  notificationUnreadCount: 0,
});

export const sessionState = state;

export const isAuthenticated = computed(() => Boolean(state.user));
export const isBusinessUser = computed(() => state.user?.role === "business");
export const activityBadgeCount = computed(
  () => Math.max(0, Number(state.messageUnreadCount || 0)) + Math.max(0, Number(state.notificationUnreadCount || 0)),
);

// Helper to update counts from cached data
function updateCountsFromCache() {
  const wishlist = queryClient.getQueryData<any[]>(queryKeys.wishlist.main()) || [];
  const cart = queryClient.getQueryData<any[]>(queryKeys.cart.main()) || [];
  const conversations = queryClient.getQueryData<any[]>(queryKeys.messages.conversations()) || [];
  const notificationCount = queryClient.getQueryData<number>(["notifications", "count"]) || 0;

  state.wishlistCount = wishlist.length;
  state.cartCount = cart.reduce((total, item) => total + Math.max(0, Number(item.quantity || 0)), 0);
  state.messageUnreadCount = conversations.reduce(
    (total, item) => total + Math.max(0, Number(item.unreadCount || 0)),
    0,
  );
  state.notificationUnreadCount = notificationCount;
}

// Subscribe to relevant queries to sync counts
queryClient.getQueryCache().subscribe((event) => {
  const key = event?.query?.queryKey?.[0];
  if (["cart", "wishlist", "messages", "notifications"].includes(String(key)) && 
      (event.type === "updated" || event.type === "removed")) {
    updateCountsFromCache();
  }
});

export async function ensureSession() {
  if (state.sessionLoaded) {
    return state.user;
  }

  return queryClient.fetchQuery({
    queryKey: queryKeys.user.session(),
    queryFn: async () => {
      const session = await fetchCurrentUserSessionState();
      if (session.status === "authenticated") {
        state.user = session.user;
        state.sessionLoaded = true;
        void refreshCounts();
        return session.user;
      }

      if (session.status === "unreachable" && state.user) {
        state.sessionLoaded = true;
        return state.user;
      }

      state.user = null;
      state.sessionLoaded = true;
      state.wishlistCount = 0;
      state.cartCount = 0;
      state.messageUnreadCount = 0;
      state.notificationUnreadCount = 0;
      return null;
    },
    staleTime: Infinity,
  });
}

export async function refreshSession() {
  state.sessionLoaded = false;
  queryClient.invalidateQueries({ queryKey: queryKeys.user.session() });
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

  // Use prefetch/fetch to populate TanStack cache
  await Promise.all([
    queryClient.fetchQuery({ queryKey: queryKeys.wishlist.main(), queryFn: fetchWishlist }),
    queryClient.fetchQuery({ queryKey: queryKeys.cart.main(), queryFn: fetchCart }),
    queryClient.fetchQuery({ queryKey: queryKeys.messages.conversations(), queryFn: fetchConversations }),
    queryClient.fetchQuery({ queryKey: ["notifications", "count"], queryFn: fetchNotificationsCount }),
  ]);
  
  updateCountsFromCache();
}

export async function clearSession() {
  await logoutUser();
  state.user = null;
  state.sessionLoaded = true;
  state.wishlistCount = 0;
  state.cartCount = 0;
  state.messageUnreadCount = 0;
  state.notificationUnreadCount = 0;
  queryClient.clear();
}
