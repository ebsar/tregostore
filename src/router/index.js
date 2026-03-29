import { createRouter, createWebHistory } from "vue-router";
import { beginRouteLoading } from "../stores/app-state";

const HomePage = () => import("../views/HomePage.vue");
const SearchPage = () => import("../views/SearchPage.vue");
const ProductDetailPage = () => import("../views/ProductDetailPage.vue");
const BusinessProfilePage = () => import("../views/BusinessProfilePage.vue");
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
const BusinessOrdersPage = () => import("../views/BusinessOrdersPage.vue");
const RefundReturnsPage = () => import("../views/RefundReturnsPage.vue");
const NotificationsPage = () => import("../views/NotificationsPage.vue");
const AdminOrdersPage = () => import("../views/AdminOrdersPage.vue");
const CheckoutAddressPage = () => import("../views/CheckoutAddressPage.vue");
const PaymentOptionsPage = () => import("../views/PaymentOptionsPage.vue");
const AdminProductsPage = () => import("../views/AdminProductsPage.vue");
const BusinessDashboardPage = () => import("../views/BusinessDashboardPage.vue");
const RegisteredBusinessesPage = () => import("../views/RegisteredBusinessesPage.vue");

const routes = [
  {
    path: "/",
    component: HomePage,
    meta: {
      pageKey: "home",
      title: "TREGO | Home",
      shellClass: "page-shell page-shell-home-full",
      mainClass: "page-main page-main-collection",
    },
  },
  {
    path: "/kerko",
    component: SearchPage,
    meta: {
      pageKey: "search",
      title: "TREGO | Kerko produkte",
      shellClass: "page-shell",
      mainClass: "page-main page-main-collection",
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
      title: "TREGO | Produkti",
      shellClass: "page-shell",
      mainClass: "page-main page-main-product",
    },
  },
  {
    path: "/profili-biznesit",
    component: BusinessProfilePage,
    meta: {
      pageKey: "business-profile",
      title: "TREGO | Profili i biznesit",
      shellClass: "page-shell",
      mainClass: "page-main page-main-collection",
    },
  },
  {
    path: "/login",
    component: LoginPage,
    meta: {
      pageKey: "login",
      title: "TREGO | Login",
      shellClass: "page-shell page-shell-login",
      mainClass: "page-main page-main-login",
    },
  },
  {
    path: "/signup",
    component: SignupPage,
    meta: {
      pageKey: "signup",
      title: "TREGO | Sign Up",
      shellClass: "page-shell page-shell-signup",
      mainClass: "page-main page-main-signup",
    },
  },
  {
    path: "/verifiko-email",
    component: VerifyEmailPage,
    meta: {
      pageKey: "verify-email",
      title: "TREGO | Verifiko Emailin",
      shellClass: "page-shell page-shell-login",
      mainClass: "page-main page-main-login",
    },
  },
  {
    path: "/forgot-password",
    component: ForgotPasswordPage,
    meta: {
      pageKey: "forgot-password",
      title: "TREGO | Kam harruar fjalekalimin",
      shellClass: "page-shell",
      mainClass: "page-main",
    },
  },
  {
    path: "/ndrysho-fjalekalimin",
    component: ChangePasswordPage,
    meta: {
      pageKey: "change-password",
      title: "TREGO | Ndryshimi i fjalekalimit",
      shellClass: "page-shell",
      mainClass: "page-main page-main-account",
    },
  },
  {
    path: "/wishlist",
    component: WishlistPage,
    meta: {
      pageKey: "wishlist",
      title: "TREGO | Wishlist",
      shellClass: "page-shell",
      mainClass: "page-main page-main-collection",
      routeLoader: true,
    },
  },
  {
    path: "/cart",
    component: CartPage,
    meta: {
      pageKey: "cart",
      title: "TREGO | Cart",
      shellClass: "page-shell",
      mainClass: "page-main page-main-collection",
      routeLoader: true,
    },
  },
  {
    path: "/llogaria",
    component: AccountPage,
    meta: {
      pageKey: "account",
      title: "TREGO | Llogaria",
      shellClass: "page-shell",
      mainClass: "page-main page-main-account",
      routeLoader: true,
    },
  },
  {
    path: "/mesazhet",
    component: MessagesPage,
    meta: {
      pageKey: "account",
      title: "TREGO | Mesazhet",
      shellClass: "page-shell",
      mainClass: "page-main page-main-account",
      routeLoader: true,
    },
  },
  {
    path: "/te-dhenat-personale",
    component: PersonalDataPage,
    meta: {
      pageKey: "personal-data",
      title: "TREGO | Te dhenat personale",
      shellClass: "page-shell",
      mainClass: "page-main page-main-account",
      routeLoader: true,
    },
  },
  {
    path: "/adresat",
    component: AddressesPage,
    meta: {
      pageKey: "addresses",
      title: "TREGO | Adresat",
      shellClass: "page-shell",
      mainClass: "page-main page-main-account",
      routeLoader: true,
    },
  },
  {
    path: "/porosite",
    component: OrdersPage,
    meta: {
      pageKey: "orders",
      title: "TREGO | Porosite",
      shellClass: "page-shell",
      mainClass: "page-main page-main-account",
      routeLoader: true,
    },
  },
  {
    path: "/refund-returne",
    component: RefundReturnsPage,
    meta: {
      pageKey: "refund-returns",
      title: "TREGO | Refund / Returne",
      shellClass: "page-shell",
      mainClass: "page-main page-main-account",
      routeLoader: true,
    },
  },
  {
    path: "/njoftimet",
    component: NotificationsPage,
    meta: {
      pageKey: "notifications",
      title: "TREGO | Njoftimet",
      shellClass: "page-shell",
      mainClass: "page-main page-main-account",
      routeLoader: true,
    },
  },
  {
    path: "/porosite-e-biznesit",
    component: BusinessOrdersPage,
    meta: {
      pageKey: "business-orders",
      title: "TREGO | Porosite e biznesit",
      shellClass: "page-shell",
      mainClass: "page-main page-main-account",
      routeLoader: true,
    },
  },
  {
    path: "/admin-porosite",
    component: AdminOrdersPage,
    meta: {
      pageKey: "admin-orders",
      title: "TREGO | Porosit e adminit",
      shellClass: "page-shell",
      mainClass: "page-main page-main-account",
      routeLoader: true,
    },
  },
  {
    path: "/adresa-e-porosise",
    component: CheckoutAddressPage,
    meta: {
      pageKey: "checkout-address",
      title: "TREGO | Adresa e porosise",
      shellClass: "page-shell",
      mainClass: "page-main page-main-account",
      routeLoader: true,
    },
  },
  {
    path: "/menyra-e-pageses",
    component: PaymentOptionsPage,
    meta: {
      pageKey: "payment-options",
      title: "TREGO | Menyra e pageses",
      shellClass: "page-shell",
      mainClass: "page-main page-main-account",
      routeLoader: true,
    },
  },
  {
    path: "/admin-products",
    component: AdminProductsPage,
    meta: {
      pageKey: "admin-products",
      title: "TREGO | Admin Products",
      shellClass: "page-shell",
      mainClass: "page-main page-main-admin",
      routeLoader: true,
    },
  },
  {
    path: "/biznesi-juaj",
    component: BusinessDashboardPage,
    meta: {
      pageKey: "business-dashboard",
      title: "TREGO | Biznesi juaj",
      shellClass: "page-shell",
      mainClass: "page-main page-main-admin",
      routeLoader: true,
    },
  },
  {
    path: "/bizneset-e-regjistruara",
    component: RegisteredBusinessesPage,
    meta: {
      pageKey: "registered-businesses",
      title: "TREGO | Bizneset e regjistruara",
      shellClass: "page-shell",
      mainClass: "page-main page-main-admin",
      routeLoader: true,
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
  scrollBehavior() {
    return { top: 0 };
  },
});

router.beforeEach((to) => {
  if (to.meta?.routeLoader) {
    beginRouteLoading();
  }
});

export default router;
