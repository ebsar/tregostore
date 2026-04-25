<script setup lang="ts">
import { IonButton, IonContent, IonPage } from "@ionic/vue";
import { computed, onMounted, ref } from "vue";
import { useRoute, useRouter } from "vue-router";
import AppPageHeader from "../components/AppPageHeader.vue";
import EmptyStatePanel from "../components/EmptyStatePanel.vue";
import ProductCardMobile from "../components/ProductCardMobile.vue";
import { fetchAdminProducts, fetchBusinessAnalytics, fetchBusinessProducts, fetchBusinessProfile } from "../lib/api";
import { formatCount, formatPrice } from "../lib/format";
import type { BusinessAnalytics, ProductItem } from "../types/models";
import { ensureSession, sessionState } from "../stores/session";

const route = useRoute();
const router = useRouter();
const profile = ref<any>(null);
const products = ref<ProductItem[]>([]);
const analytics = ref<BusinessAnalytics | null>(null);
const isBusiness = computed(() => sessionState.user?.role === "business");
const isAdmin = computed(() => sessionState.user?.role === "admin");
const canViewHub = computed(() => isBusiness.value || isAdmin.value);
const headerTitle = computed(() =>
  isAdmin.value ? "Admin insights ne format mobile." : "Business dashboard ne format mobile.",
);
const headerSubtitle = computed(() =>
  isAdmin.value
    ? "Shiko angazhimin e produkteve ne tere platformen, pa kaluar ne desktop."
    : "Profili, produktet dhe interesimi i klienteve lexohen nga te njejtat endpoints si dashboard-i aktual.",
);
const hubSectionTitle = computed(() =>
  isAdmin.value ? "Produktet e platformes" : "Katalogu i biznesit",
);
const insightCards = computed(() => {
  if (isBusiness.value) {
    return [
      { label: "Views", value: formatCount(analytics.value?.viewsCount || 0) },
      { label: "Wishlist", value: formatCount(analytics.value?.wishlistCount || 0) },
      { label: "Cart", value: formatCount(analytics.value?.cartCount || 0) },
      { label: "Share", value: formatCount(analytics.value?.shareCount || 0) },
    ];
  }

  const totals = products.value.reduce((accumulator, product) => {
    accumulator.viewsCount += Number(product.viewsCount || 0);
    accumulator.wishlistCount += Number(product.wishlistCount || 0);
    accumulator.cartCount += Number(product.cartCount || 0);
    accumulator.shareCount += Number(product.shareCount || 0);
    return accumulator;
  }, {
    viewsCount: 0,
    wishlistCount: 0,
    cartCount: 0,
    shareCount: 0,
  });

  return [
    { label: "Views", value: formatCount(totals.viewsCount) },
    { label: "Wishlist", value: formatCount(totals.wishlistCount) },
    { label: "Cart", value: formatCount(totals.cartCount) },
    { label: "Share", value: formatCount(totals.shareCount) },
  ];
});
const highlightedOrderId = computed(() => {
  const nextValue = Number(route.query.orderId || 0);
  return Number.isFinite(nextValue) ? Math.max(0, nextValue) : 0;
});
const overviewCopy = computed(() => {
  if (isAdmin.value) {
    return `${formatCount(products.value.length)} produkte aktive ne sistem, me qasje te shpejte ne statistikat kryesore per secilin artikull.`;
  }

  return profile.value?.description || "Ky modul lidhet me po te njejtin profil publik dhe shipping settings.";
});
const overviewLabel = computed(() =>
  isAdmin.value ? "Produkte gjithsej" : "Fitimi i biznesit",
);
const overviewValue = computed(() =>
  isAdmin.value ? formatCount(products.value.length) : formatPrice(analytics.value?.sellerEarnings || 0),
);
const highlightedOrderCopy = computed(() =>
  isAdmin.value
    ? "Ky sinjal erdhi nga push notification. Hape produktin ose menaxho porosine ne web per me shume detaje."
    : "Ky sinjal erdhi nga push notification per porosi te re. Ne hapin tjeter mund ta zgjerojme kete ekran me liste aktive porosish ne mobile.",
);
const emptyCopy = computed(() =>
  isAdmin.value
    ? "Kur backend-i kthen produktet administrative, ato shfaqen ketu me statistika angazhimi."
    : "Kur backend-i kthen produktet e biznesit, ato shfaqen ketu direkt me statistika angazhimi.",
);
const operationalLinks = computed(() =>
  isAdmin.value
    ? [
        { label: "Admin control", to: "/admin/control" },
        { label: "Orders", to: "/orders" },
        { label: "Messages", to: "/messages" },
      ]
    : [
        { label: "Business Studio", to: "/business/studio" },
        { label: "Orders", to: "/business/studio" },
        { label: "Messages", to: "/messages" },
      ],
);

onMounted(async () => {
  await ensureSession();
  if (isBusiness.value) {
    const [{ data }, productItems, analyticsPayload] = await Promise.all([
      fetchBusinessProfile(),
      fetchBusinessProducts(),
      fetchBusinessAnalytics(),
    ]);
    profile.value = data?.profile || null;
    analytics.value = analyticsPayload.data?.analytics || null;
    products.value = productItems;
    return;
  }

  if (isAdmin.value) {
    profile.value = null;
    analytics.value = null;
    products.value = await fetchAdminProducts();
  }
});

async function handleOpenProduct(productId: number) {
  await router.push(`/product/${productId}`);
}
</script>

<template>
  <IonPage>
    <IonContent :fullscreen="true">
      <div>
        <AppPageHeader
          kicker="Insights"
          :title="headerTitle"
          :subtitle="headerSubtitle"
          back-to="/tabs/account"
        />

        <EmptyStatePanel
          v-if="!sessionState.user"
          title="Kyçu si biznes"
          copy="Ky ekran përdor të njëjtin profil biznesi dhe të njëjtin katalog."
        >
          <IonButton @click="router.push({ path: '/login', query: { redirect: route.fullPath } })">
            Login
          </IonButton>
        </EmptyStatePanel>

        <EmptyStatePanel
          v-else-if="!canViewHub"
          title="Ky account nuk ka qasje ne insights"
          copy="Per kete ekran, hyni me account biznesi ose admin."
        />

        <template v-else>
          <section v-if="highlightedOrderId > 0">
            <p>Nga njoftimi</p>
            <h2>Porosia #{{ highlightedOrderId }} kerkon vemendje</h2>
            <p>
              {{ highlightedOrderCopy }}
            </p>
          </section>

          <section>
            <p>{{ isAdmin ? "Admin" : "Profili" }}</p>
            <h2>{{ profile?.businessName || sessionState.user.businessName || "Dashboard" }}</h2>
            <p>
              {{ overviewCopy }}
            </p>
            <div>
              <span>{{ overviewLabel }}</span>
              <span>{{ overviewValue }}</span>
            </div>
          </section>

          <section>
            <div>
              <div>
                <p>Insights</p>
                <h2>Sa interes po marrin produktet</h2>
              </div>
            </div>

            <div>
              <article
                v-for="item in insightCards"
                :key="`insight-${item.label}`"
               
              >
                <strong>{{ item.value }}</strong>
                <span>{{ item.label }}</span>
              </article>
            </div>
          </section>

          <section>
            <div>
              <div>
                <p>Operacionet</p>
                <h2>{{ isAdmin ? "Kalo te paneli operativ" : "Kalo te studio e biznesit" }}</h2>
              </div>
            </div>

            <div>
              <button
                v-for="item in operationalLinks"
                :key="item.label"
               
                type="button"
                @click="router.push(item.to)"
              >
                {{ item.label }}
              </button>
            </div>
          </section>

          <section>
            <div>
              <div>
                <p>Produktet</p>
                <h2>{{ hubSectionTitle }}</h2>
              </div>
            </div>

            <div v-if="products.length">
              <ProductCardMobile
                v-for="product in products"
                :key="product.id"
                :product="product"
                analytics-mode
                @open="handleOpenProduct"
              />
            </div>

            <EmptyStatePanel
              v-else
              title="Nuk ka produkte"
              :copy="emptyCopy"
            />
          </section>
        </template>
      </div>
    </IonContent>
  </IonPage>
</template>

