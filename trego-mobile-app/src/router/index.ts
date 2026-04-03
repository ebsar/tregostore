import { createRouter, createWebHistory } from "@ionic/vue-router";

const TabsPage = () => import("../pages/TabsPage.vue");
const HomePage = () => import("../pages/HomePage.vue");
const SearchPage = () => import("../pages/SearchPage.vue");
const BusinessesPage = () => import("../pages/BusinessesPage.vue");
const WishlistPage = () => import("../pages/WishlistPage.vue");
const CartPage = () => import("../pages/CartPage.vue");
const AccountPage = () => import("../pages/AccountPage.vue");
const AppSettingsPage = () => import("../pages/AppSettingsPage.vue");
const ProductDetailPage = () => import("../pages/ProductDetailPage.vue");
const LoginPage = () => import("../pages/LoginPage.vue");
const SignupPage = () => import("../pages/SignupPage.vue");
const ForgotPasswordPage = () => import("../pages/ForgotPasswordPage.vue");
const ResetPasswordPage = () => import("../pages/ResetPasswordPage.vue");
const OrdersPage = () => import("../pages/OrdersPage.vue");
const MessagesPage = () => import("../pages/MessagesPage.vue");
const MessageConversationPage = () => import("../pages/MessageConversationPage.vue");
const BusinessHubPage = () => import("../pages/BusinessHubPage.vue");
const BusinessStudioPage = () => import("../pages/BusinessStudioPage.vue");
const BusinessStorePage = () => import("../pages/BusinessStorePage.vue");
const AdminControlPage = () => import("../pages/AdminControlPage.vue");
const CheckoutAddressPage = () => import("../pages/CheckoutAddressPage.vue");
const CheckoutPaymentPage = () => import("../pages/CheckoutPaymentPage.vue");

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    {
      path: "/",
      redirect: "/tabs/home",
    },
    {
      path: "/login",
      component: LoginPage,
    },
    {
      path: "/signup",
      component: SignupPage,
    },
    {
      path: "/forgot-password",
      component: ForgotPasswordPage,
    },
    {
      path: "/ndrysho-fjalekalimin",
      component: ResetPasswordPage,
    },
    {
      path: "/change-password",
      component: ResetPasswordPage,
    },
    {
      path: "/product/:id",
      component: ProductDetailPage,
    },
    {
      path: "/orders",
      component: OrdersPage,
    },
    {
      path: "/app/settings",
      component: AppSettingsPage,
    },
    {
      path: "/messages",
      component: MessagesPage,
    },
    {
      path: "/messages/:conversationId",
      component: MessageConversationPage,
    },
    {
      path: "/business",
      component: BusinessHubPage,
    },
    {
      path: "/business/studio",
      component: BusinessStudioPage,
    },
    {
      path: "/business/public/:id",
      component: BusinessStorePage,
    },
    {
      path: "/admin/control",
      component: AdminControlPage,
    },
    {
      path: "/checkout/address",
      component: CheckoutAddressPage,
    },
    {
      path: "/checkout/payment",
      component: CheckoutPaymentPage,
    },
    {
      path: "/tabs/",
      component: TabsPage,
      children: [
        {
          path: "",
          redirect: "/tabs/home",
        },
        {
          path: "home",
          component: HomePage,
        },
        {
          path: "search",
          component: SearchPage,
        },
        {
          path: "businesses",
          component: BusinessesPage,
        },
        {
          path: "wishlist",
          component: WishlistPage,
        },
        {
          path: "cart",
          component: CartPage,
        },
        {
          path: "account",
          component: AccountPage,
        },
      ],
    },
  ],
});

export default router;
