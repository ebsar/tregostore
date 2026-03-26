import { createRouter, createWebHistory } from "vue-router";
import { beginRouteLoading } from "../stores/app-state";
import HomePage from "../views/HomePage.vue";
import SearchPage from "../views/SearchPage.vue";
import ProductDetailPage from "../views/ProductDetailPage.vue";
import BusinessProfilePage from "../views/BusinessProfilePage.vue";
import LoginPage from "../views/LoginPage.vue";
import SignupPage from "../views/SignupPage.vue";
import VerifyEmailPage from "../views/VerifyEmailPage.vue";
import ForgotPasswordPage from "../views/ForgotPasswordPage.vue";
import ChangePasswordPage from "../views/ChangePasswordPage.vue";
import WishlistPage from "../views/WishlistPage.vue";
import CartPage from "../views/CartPage.vue";
import AccountPage from "../views/AccountPage.vue";
import PersonalDataPage from "../views/PersonalDataPage.vue";
import AddressesPage from "../views/AddressesPage.vue";
import OrdersPage from "../views/OrdersPage.vue";
import BusinessOrdersPage from "../views/BusinessOrdersPage.vue";
import CheckoutAddressPage from "../views/CheckoutAddressPage.vue";
import PaymentOptionsPage from "../views/PaymentOptionsPage.vue";
import AdminProductsPage from "../views/AdminProductsPage.vue";
import BusinessDashboardPage from "../views/BusinessDashboardPage.vue";
import RegisteredBusinessesPage from "../views/RegisteredBusinessesPage.vue";

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

router.beforeEach(() => {
  beginRouteLoading();
});

export default router;
