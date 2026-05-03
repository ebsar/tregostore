import { createRouter, createWebHistory } from "vue-router";
import { beginRouteLoading } from "../stores/app-state";

const HomePage = () => import("../views/HomePage.vue");
const SearchPage = () => import("../views/SearchPage.vue");
const ProductDetailPage = () => import("../views/ProductDetailPage.vue");
const BusinessProfilePage = () => import("../views/BusinessProfilePage.vue");
const BusinessesPage = () => import("../views/BusinessesPage.vue");
const LoginPage = () => import("../views/LoginPage.vue");
const SignupPage = () => import("../views/SignupPage.vue");
const VerifyEmailPage = () => import("../views/VerifyEmailPage.vue");
const ForgotPasswordPage = () => import("../views/ForgotPasswordPage.vue");
const ChangePasswordPage = () => import("../views/ChangePasswordPage.vue");
const WishlistPage = () => import("../views/WishlistPage.vue");
const CartPage = () => import("../views/CartPage.vue");
const AccountPage = () => import("../views/AccountPage.vue");
const MessagesPage = () => import("../views/MessagesPage.vue");
const PersonalDataPage = () => import("../views/PersonalDataPage.vue");
const AddressesPage = () => import("../views/AddressesPage.vue");
const OrdersPage = () => import("../views/OrdersPage.vue");
const PaymentMethodsPage = () => import("../views/PaymentMethodsPage.vue");
const SupportPage = () => import("../views/SupportPage.vue");
const TrackOrderPage = () => import("../views/TrackOrderPage.vue");
const BusinessOrdersPage = () => import("../views/BusinessOrdersPage.vue");
const RefundReturnsPage = () => import("../views/RefundReturnsPage.vue");
const NotificationsPage = () => import("../views/NotificationsPage.vue");
const AdminOrdersPage = () => import("../views/AdminOrdersPage.vue");
const CheckoutAddressPage = () => import("../views/CheckoutAddressPage.vue");
const PaymentOptionsPage = () => import("../views/PaymentOptionsPage.vue");
const OrderSuccessPage = () => import("../views/OrderSuccessPage.vue");
const AdminProductsPage = () => import("../views/AdminProductsPage.vue");
const AdminUsersPage = () => import("../views/AdminUsersPage.vue");
const AdminDisputesPage = () => import("../views/AdminDisputesPage.vue");
const AdminWorkspacePlaceholderPage = () => import("../views/AdminWorkspacePlaceholderPage.vue");
const BusinessDashboardPage = () => import("../views/BusinessDashboardPage.vue");
const RegisteredBusinessesPage = () => import("../views/RegisteredBusinessesPage.vue");
const ProductComparePage = () => import("../views/ProductComparePage.vue");
const LiquidGlassPage = () => import("../views/LiquidGlassPage.vue");

const routes = [
  {
    path: "/",
    component: HomePage,
    meta: {
      pageKey: "home",
      title: "TREGIO | Home",
    },
  },
  {
    path: "/kerko",
    component: SearchPage,
    meta: {
      pageKey: "search",
      title: "TREGIO | Kerko produkte",
    },
  },
  {
    path: "/kafshet-shtepiake",
    redirect: { path: "/kerko", query: { category: "pets" } },
  },
  {
    path: "/produkti",
    component: ProductDetailPage,
    meta: {
      pageKey: "product-detail",
      title: "TREGIO | Produkti",
    },
  },
  {
    path: "/profili-biznesit",
    component: BusinessProfilePage,
    meta: {
      pageKey: "business-profile",
      title: "TREGIO | Profili i biznesit",
    },
  },
  {
    path: "/bizneset",
    component: BusinessesPage,
    meta: {
      pageKey: "businesses",
      title: "TREGIO | Businesses",
      routeLoader: true,
    },
  },
  {
    path: "/login",
    component: LoginPage,
    meta: {
      pageKey: "login",
      title: "TREGIO | Login",
    },
  },
  {
    path: "/signup",
    component: SignupPage,
    meta: {
      pageKey: "signup",
      title: "TREGIO | Sign Up",
    },
  },
  {
    path: "/verifiko-email",
    component: VerifyEmailPage,
    meta: {
      pageKey: "verify-email",
      title: "TREGIO | Verifiko Emailin",
    },
  },
  {
    path: "/forgot-password",
    component: ForgotPasswordPage,
    meta: {
      pageKey: "forgot-password",
      title: "TREGIO | Kam harruar fjalekalimin",
    },
  },
  {
    path: "/ndrysho-fjalekalimin",
    component: ChangePasswordPage,
    meta: {
      pageKey: "change-password",
      title: "TREGIO | Ndryshimi i fjalekalimit",
    },
  },
  {
    path: "/wishlist",
    component: WishlistPage,
    meta: {
      pageKey: "wishlist",
      title: "TREGIO | Wishlist",
      routeLoader: true,
    },
  },
  {
    path: "/cart",
    component: CartPage,
    meta: {
      pageKey: "cart",
      title: "TREGIO | Cart",
      routeLoader: true,
    },
  },
  {
    path: "/llogaria",
    component: AccountPage,
    meta: {
      pageKey: "account",
      title: "TREGIO | Llogaria",
      routeLoader: true,
    },
  },
  {
    path: "/mesazhet",
    component: MessagesPage,
    meta: {
      pageKey: "account",
      title: "TREGIO | Mesazhet",
      routeLoader: true,
    },
  },
  {
    path: "/te-dhenat-personale",
    component: PersonalDataPage,
    meta: {
      pageKey: "personal-data",
      title: "TREGIO | Te dhenat personale",
      routeLoader: true,
    },
  },
  {
    path: "/adresat",
    component: AddressesPage,
    meta: {
      pageKey: "addresses",
      title: "TREGIO | Adresat",
      routeLoader: true,
    },
  },
  {
    path: "/porosite",
    component: OrdersPage,
    meta: {
      pageKey: "orders",
      title: "TREGIO | Porosite",
      routeLoader: true,
    },
  },
  {
    path: "/payments",
    component: PaymentMethodsPage,
    meta: {
      pageKey: "payments",
      title: "TREGIO | Payment Methods",
      routeLoader: true,
    },
  },
  {
    path: "/support",
    component: SupportPage,
    meta: {
      pageKey: "support",
      title: "TREGIO | Support",
      routeLoader: true,
    },
  },
  {
    path: "/track-order",
    component: TrackOrderPage,
    meta: {
      pageKey: "track-order",
      title: "TREGIO | Track Order",
      routeLoader: true,
    },
  },
  {
    path: "/refund-returne",
    component: RefundReturnsPage,
    meta: {
      pageKey: "refund-returns",
      title: "TREGIO | Refund / Returne",
      routeLoader: true,
    },
  },
  {
    path: "/njoftimet",
    component: NotificationsPage,
    meta: {
      pageKey: "notifications",
      title: "TREGIO | Njoftimet",
      routeLoader: true,
    },
  },
  {
    path: "/porosite-e-biznesit",
    component: BusinessOrdersPage,
    meta: {
      pageKey: "business-orders",
      title: "TREGIO | Porosite e biznesit",
      routeLoader: true,
    },
  },
  {
    path: "/admin-porosite",
    component: AdminOrdersPage,
    meta: {
      pageKey: "admin-orders",
      title: "TREGIO | Porosit e adminit",
      routeLoader: true,
    },
  },
  {
    path: "/adresa-e-porosise",
    component: CheckoutAddressPage,
    meta: {
      pageKey: "checkout-address",
      title: "TREGIO | Adresa e porosise",
      routeLoader: true,
    },
  },
  {
    path: "/menyra-e-pageses",
    component: PaymentOptionsPage,
    meta: {
      pageKey: "payment-options",
      title: "TREGIO | Menyra e pageses",
      routeLoader: true,
    },
  },
  {
    path: "/porosia-u-konfirmua",
    component: OrderSuccessPage,
    meta: {
      pageKey: "order-success",
      title: "TREGIO | Order confirmed",
      routeLoader: true,
    },
  },
  {
    path: "/admin-products",
    component: AdminProductsPage,
    meta: {
      pageKey: "admin-products",
      title: "TREGIO | Admin Products",
      routeLoader: true,
    },
  },
  {
    path: "/admin-products/inventory",
    component: AdminProductsPage,
    meta: {
      pageKey: "admin-products",
      title: "TREGIO | Admin Inventory",
      routeLoader: true,
    },
  },
  {
    path: "/admin-products/lista",
    redirect: (to) => ({
      path: "/admin-products/inventory",
      query: to.query,
    }),
  },
  {
    path: "/admin-users",
    component: AdminUsersPage,
    meta: {
      pageKey: "admin-users",
      title: "TREGIO | Admin Users",
      routeLoader: true,
    },
  },
  {
    path: "/admin-disputes",
    component: AdminDisputesPage,
    meta: {
      pageKey: "admin-disputes",
      title: "TREGIO | Admin Disputes",
      routeLoader: true,
    },
  },
  {
    path: "/admin-categories",
    component: AdminWorkspacePlaceholderPage,
    meta: {
      pageKey: "admin-categories",
      title: "TREGIO | Admin Categories",
      routeLoader: true,
      dashboardPlaceholder: {
        activeKey: "categories",
        eyebrow: "Admin categories",
        title: "Category management",
        description: "Prepare category operations in the correct admin area without inventing fake backend behavior.",
        note: "A dedicated categories API is not exposed yet, so this page stays as a clean integration point.",
      },
    },
  },
  {
    path: "/admin-ads",
    component: AdminWorkspacePlaceholderPage,
    meta: {
      pageKey: "admin-ads",
      title: "TREGIO | Admin Launch Ads",
      routeLoader: true,
      dashboardPlaceholder: {
        activeKey: "ads",
        eyebrow: "Launch ads",
        title: "Hero slider and campaign ads",
        description: "Prepare and review homepage launch banners from the correct admin workspace.",
        note: "The public homepage now supports product-driven launch slides. Connect upload, schedule, and publish actions here when the dedicated ads API is exposed.",
      },
    },
  },
  {
    path: "/admin-commissions",
    component: AdminWorkspacePlaceholderPage,
    meta: {
      pageKey: "admin-commissions",
      title: "TREGIO | Admin Commissions",
      routeLoader: true,
      dashboardPlaceholder: {
        activeKey: "commissions",
        eyebrow: "Admin commissions",
        title: "Commission reporting",
        description: "Keep commission reporting in its own workspace once the dedicated backend endpoint is exposed.",
        note: "Commission values exist inside order item data, but a standalone admin reporting API is still missing.",
      },
    },
  },
  {
    path: "/admin-payouts",
    component: AdminWorkspacePlaceholderPage,
    meta: {
      pageKey: "admin-payouts",
      title: "TREGIO | Admin Payouts",
      routeLoader: true,
      dashboardPlaceholder: {
        activeKey: "payouts",
        eyebrow: "Admin payouts",
        title: "Vendor payout operations",
        description: "This page reserves the right place for payout settlement and review once backend support is added.",
        note: "The UI is prepared, but a dedicated admin payouts endpoint is not available yet.",
      },
    },
  },
  {
    path: "/biznesi-juaj",
    component: BusinessDashboardPage,
    meta: {
      pageKey: "business-dashboard",
      title: "TREGIO | Biznesi juaj",
      routeLoader: true,
    },
  },
  {
    path: "/bizneset-e-regjistruara",
    component: RegisteredBusinessesPage,
    meta: {
      pageKey: "registered-businesses",
      title: "TREGIO | Bizneset e regjistruara",
      routeLoader: true,
    },
  },
  {
    path: "/krahaso-produkte",
    component: ProductComparePage,
    meta: {
      pageKey: "product-compare",
      title: "TREGIO | Krahaso produktet",
    },
  },
  {
    path: "/liquid-glass",
    component: LiquidGlassPage,
    meta: {
      pageKey: "liquid-glass",
      title: "TREGIO | Liquid Glass",
    },
  },
  {
    path: "/about",
    redirect: "/",
  },
];

const router = createRouter({
  history: createWebHistory(),
  routes,
  scrollBehavior(to, from) {
    if (to.path === from.path) {
      return false;
    }

    return { top: 0 };
  },
});

const DASHBOARD_ROUTE_PAGE_KEYS = new Set([
  "account",
  "addresses",
  "admin-categories",
  "admin-ads",
  "admin-commissions",
  "admin-disputes",
  "admin-orders",
  "admin-payouts",
  "admin-products",
  "admin-users",
  "business-dashboard",
  "business-orders",
  "notifications",
  "orders",
  "payments",
  "personal-data",
  "refund-returns",
  "registered-businesses",
  "support",
]);

function isAdminProductWorkspace(path) {
  return ["/admin-products", "/admin-products/inventory", "/admin-products/lista"].includes(path);
}

function isDashboardRoute(route) {
  return DASHBOARD_ROUTE_PAGE_KEYS.has(String(route.meta?.pageKey || ""));
}

function isDashboardShellNavigation(to, from) {
  if (!from.matched?.length) {
    return false;
  }

  return isDashboardRoute(to) && isDashboardRoute(from);
}

router.beforeEach((to, from) => {
  if (to.meta?.routeLoader) {
    if (
      to.path === from.path
      || isDashboardShellNavigation(to, from)
      || (isAdminProductWorkspace(to.path) && isAdminProductWorkspace(from.path))
    ) {
      return;
    }

    beginRouteLoading();
  }
});

export default router;
