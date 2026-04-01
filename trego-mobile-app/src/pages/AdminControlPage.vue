<script setup lang="ts">
import { IonButton, IonContent, IonIcon, IonPage } from "@ionic/vue";
import { briefcaseOutline, flagOutline, peopleOutline, storefrontOutline, trashOutline } from "ionicons/icons";
import { computed, onMounted, reactive, ref } from "vue";
import { useRouter } from "vue-router";
import AppPageHeader from "../components/AppPageHeader.vue";
import EmptyStatePanel from "../components/EmptyStatePanel.vue";
import ProductCardMobile from "../components/ProductCardMobile.vue";
import {
  createAdminBusiness,
  deleteAdminUser,
  fetchAdminBusinesses,
  fetchAdminProducts,
  fetchAdminReports,
  fetchAdminUsers,
  setAdminUserPassword,
  updateAdminBusinessEditAccess,
  updateAdminBusinessVerification,
  updateAdminReportStatus,
  updateAdminUserRole,
} from "../lib/api";
import { formatCount, formatDateLabel } from "../lib/format";
import type { AdminUserItem, BusinessItem, ProductItem, ReportItem } from "../types/models";
import { ensureSession, sessionState } from "../stores/session";

const router = useRouter();
const activeSection = ref<"users" | "businesses" | "reports" | "products">("users");
const loading = ref(true);
const users = ref<AdminUserItem[]>([]);
const businesses = ref<BusinessItem[]>([]);
const reports = ref<ReportItem[]>([]);
const products = ref<ProductItem[]>([]);
const userDrafts = reactive<Record<number, { role: string; password: string }>>({});
const reportDrafts = reactive<Record<number, string>>({});
const createBusinessForm = reactive({
  fullName: "",
  email: "",
  password: "",
  businessName: "",
  businessNumber: "",
  phoneNumber: "",
  city: "",
  addressLine: "",
  businessDescription: "",
});
const ui = reactive({
  message: "",
  type: "",
});

const canAccess = computed(() => sessionState.user?.role === "admin");
const statCards = computed(() => [
  { label: "Users", value: formatCount(users.value.length), icon: peopleOutline },
  { label: "Biznese", value: formatCount(businesses.value.length), icon: storefrontOutline },
  { label: "Reports", value: formatCount(reports.value.length), icon: flagOutline },
  { label: "Produkte", value: formatCount(products.value.length), icon: briefcaseOutline },
]);

function draftForUser(user: AdminUserItem) {
  const userId = Number(user.id || 0);
  if (!userDrafts[userId]) {
    userDrafts[userId] = {
      role: String(user.role || "client"),
      password: "",
    };
  }
  return userDrafts[userId];
}

function draftForReport(report: ReportItem) {
  const reportId = Number(report.id || 0);
  if (!(reportId in reportDrafts)) {
    reportDrafts[reportId] = String(report.adminNotes || "");
  }
  return reportDrafts[reportId];
}

async function loadAll() {
  loading.value = true;
  try {
    const [nextUsers, nextBusinesses, nextReports, nextProducts] = await Promise.all([
      fetchAdminUsers(),
      fetchAdminBusinesses(),
      fetchAdminReports(),
      fetchAdminProducts(),
    ]);
    users.value = nextUsers;
    businesses.value = nextBusinesses;
    reports.value = nextReports;
    products.value = nextProducts;
  } finally {
    loading.value = false;
  }
}

onMounted(async () => {
  await ensureSession();
  if (!canAccess.value) {
    loading.value = false;
    return;
  }
  await loadAll();
});

function setUiMessage(message: string, type: string = "info") {
  ui.message = message;
  ui.type = type;
}

async function handleUpdateRole(user: AdminUserItem) {
  const draft = draftForUser(user);
  const { response, data } = await updateAdminUserRole(Number(user.id), draft.role);
  if (!response.ok || !data?.ok) {
    setUiMessage(String(data?.message || "Roli nuk u ruajt."), "error");
    return;
  }
  setUiMessage(String(data.message || "Roli u ruajt."), "success");
  await loadAll();
}

async function handleSetPassword(user: AdminUserItem) {
  const draft = draftForUser(user);
  if (!String(draft.password || "").trim()) {
    setUiMessage("Shkruaj nje fjalekalim te perkohshem.", "error");
    return;
  }
  const { response, data } = await setAdminUserPassword(Number(user.id), draft.password);
  if (!response.ok || !data?.ok) {
    setUiMessage(String(data?.message || "Fjalekalimi nuk u ruajt."), "error");
    return;
  }
  draft.password = "";
  setUiMessage(String(data.message || "Fjalekalimi u ndryshua."), "success");
}

async function handleDeleteUser(user: AdminUserItem) {
  const { response, data } = await deleteAdminUser(Number(user.id));
  if (!response.ok || !data?.ok) {
    setUiMessage(String(data?.message || "Perdoruesi nuk u fshi."), "error");
    return;
  }
  setUiMessage(String(data.message || "Perdoruesi u fshi."), "success");
  await loadAll();
}

async function handleCreateBusiness() {
  const { response, data } = await createAdminBusiness({ ...createBusinessForm });
  if (!response.ok || !data?.ok) {
    setUiMessage(String(data?.message || "Biznesi nuk u krijua."), "error");
    return;
  }
  Object.keys(createBusinessForm).forEach((key) => {
    (createBusinessForm as any)[key] = "";
  });
  setUiMessage(String(data.message || "Biznesi u krijua."), "success");
  await loadAll();
}

async function handleBusinessVerification(business: BusinessItem, status: string) {
  const { response, data } = await updateAdminBusinessVerification(Number(business.id), status);
  if (!response.ok || !data?.ok) {
    setUiMessage(String(data?.message || "Verifikimi nuk u ruajt."), "error");
    return;
  }
  setUiMessage(String(data.message || "Verifikimi u ruajt."), "success");
  await loadAll();
}

async function handleBusinessEditAccess(business: BusinessItem, status: string) {
  const { response, data } = await updateAdminBusinessEditAccess(Number(business.id), status);
  if (!response.ok || !data?.ok) {
    setUiMessage(String(data?.message || "Leja e editimit nuk u ruajt."), "error");
    return;
  }
  setUiMessage(String(data.message || "Leja e editimit u ruajt."), "success");
  await loadAll();
}

async function handleReportUpdate(report: ReportItem, status: string) {
  const { response, data } = await updateAdminReportStatus(Number(report.id), status, draftForReport(report));
  if (!response.ok || !data?.ok) {
    setUiMessage(String(data?.message || "Raporti nuk u perditesua."), "error");
    return;
  }
  setUiMessage(String(data.message || "Raporti u perditesua."), "success");
  await loadAll();
}
</script>

<template>
  <IonPage>
    <IonContent class="app-gradient" :fullscreen="true">
      <div class="mobile-page">
        <AppPageHeader
          kicker="Admin"
          title="Kontroll qendror per users, biznese dhe raportime."
          subtitle="Ky ekran lidhet me po te njejtat endpoint-e administrative te web-it, por i optimizuar per telefon."
          back-to="/tabs/account"
        />

        <EmptyStatePanel
          v-if="!sessionState.user"
          title="Kyçu si admin"
          copy="Paneli i administrimit shfaqet sapo te hysh me llogari admin."
        >
          <IonButton class="cta-button" style="margin-top: 14px;" @click="router.push('/login?redirect=/admin/control')">
            Login
          </IonButton>
        </EmptyStatePanel>

        <EmptyStatePanel
          v-else-if="!canAccess"
          title="Kjo pjese eshte vetem per admin"
          copy="Per siguri, vetem roli admin e sheh panelin operativ."
        />

        <template v-else>
          <section class="surface-card surface-card--strong section-card">
            <div class="mini-stat-grid">
              <article v-for="item in statCards" :key="item.label" class="mini-stat">
                <IonIcon :icon="item.icon" />
                <strong>{{ item.value }}</strong>
                <span>{{ item.label }}</span>
              </article>
            </div>
          </section>

          <section class="chip-row">
            <button class="chip" :class="{ 'chip--active': activeSection === 'users' }" type="button" @click="activeSection = 'users'">Users</button>
            <button class="chip" :class="{ 'chip--active': activeSection === 'businesses' }" type="button" @click="activeSection = 'businesses'">Biznese</button>
            <button class="chip" :class="{ 'chip--active': activeSection === 'reports' }" type="button" @click="activeSection = 'reports'">Reports</button>
            <button class="chip" :class="{ 'chip--active': activeSection === 'products' }" type="button" @click="activeSection = 'products'">Produkte</button>
          </section>

          <p v-if="ui.message" class="checkout-message" :class="ui.type">{{ ui.message }}</p>

          <section v-if="loading" class="surface-card empty-panel">
            <p>Po ngarkohet paneli admin...</p>
          </section>

          <template v-else-if="activeSection === 'users'">
            <section class="stack-list">
              <article v-for="user in users" :key="user.id" class="surface-card section-card stack-list">
                <div class="section-head">
                  <div>
                    <p class="section-kicker">User</p>
                    <h2>{{ user.fullName || "Pa emer" }}</h2>
                    <p class="section-copy">{{ user.email || "-" }}</p>
                  </div>
                  <span class="meta-pill">{{ user.role || "client" }}</span>
                </div>

                <div class="checkout-grid">
                  <label class="checkout-field">
                    <span>Roli</span>
                    <select v-model="draftForUser(user).role" class="mobile-select">
                      <option value="client">Client</option>
                      <option value="business">Business</option>
                      <option value="admin">Admin</option>
                    </select>
                  </label>
                  <label class="checkout-field">
                    <span>Fjalekalim i perkohshem</span>
                    <input v-model="draftForUser(user).password" class="promo-input" type="text" placeholder="Ndrysho fjalekalimin" />
                  </label>
                </div>

                <div class="action-row">
                  <IonButton class="ghost-button" @click="handleUpdateRole(user)">Ruaje rolin</IonButton>
                  <IonButton class="ghost-button" @click="handleSetPassword(user)">Ruaje password</IonButton>
                  <IonButton class="ghost-button danger-button" @click="handleDeleteUser(user)">
                    <IonIcon slot="start" :icon="trashOutline" />
                    Fshije
                  </IonButton>
                </div>
              </article>
            </section>
          </template>

          <template v-else-if="activeSection === 'businesses'">
            <section class="surface-card section-card stack-list">
              <div>
                <p class="section-kicker">Biznes i ri</p>
                <h2>Krijo llogari biznesi</h2>
              </div>

              <div class="checkout-grid">
                <label class="checkout-field"><span>Pronari</span><input v-model="createBusinessForm.fullName" class="promo-input" type="text" placeholder="Emri dhe mbiemri" /></label>
                <label class="checkout-field"><span>Email</span><input v-model="createBusinessForm.email" class="promo-input" type="email" placeholder="biznesi@email.com" /></label>
              </div>
              <div class="checkout-grid">
                <label class="checkout-field"><span>Password</span><input v-model="createBusinessForm.password" class="promo-input" type="text" placeholder="Fjalekalimi" /></label>
                <label class="checkout-field"><span>Biznesi</span><input v-model="createBusinessForm.businessName" class="promo-input" type="text" placeholder="Emri i biznesit" /></label>
              </div>
              <div class="checkout-grid">
                <label class="checkout-field"><span>Nr. biznesit</span><input v-model="createBusinessForm.businessNumber" class="promo-input" type="text" placeholder="BR-..." /></label>
                <label class="checkout-field"><span>Telefoni</span><input v-model="createBusinessForm.phoneNumber" class="promo-input" type="text" placeholder="+383..." /></label>
              </div>
              <div class="checkout-grid">
                <label class="checkout-field"><span>Qyteti</span><input v-model="createBusinessForm.city" class="promo-input" type="text" placeholder="Prishtine" /></label>
                <label class="checkout-field"><span>Adresa</span><input v-model="createBusinessForm.addressLine" class="promo-input" type="text" placeholder="Adresa e biznesit" /></label>
              </div>
              <label class="checkout-field"><span>Pershkrimi</span><textarea v-model="createBusinessForm.businessDescription" class="mobile-textarea" rows="3" /></label>

              <IonButton class="cta-button" @click="handleCreateBusiness">Krijo biznesin</IonButton>
            </section>

            <section class="stack-list">
              <article v-for="business in businesses" :key="business.id" class="surface-card section-card stack-list">
                <div class="section-head">
                  <div>
                    <p class="section-kicker">Biznes</p>
                    <h2>{{ business.businessName || "Biznes pa emer" }}</h2>
                    <p class="section-copy">{{ business.ownerName || "-" }} · {{ business.ownerEmail || "-" }}</p>
                  </div>
                  <span class="meta-pill">{{ business.verificationStatus || "locked" }}</span>
                </div>

                <div class="mini-stat-grid">
                  <article class="mini-stat"><strong>{{ formatCount(business.productsCount || 0) }}</strong><span>produkte</span></article>
                  <article class="mini-stat"><strong>{{ formatCount(business.ordersCount || 0) }}</strong><span>porosi</span></article>
                  <article class="mini-stat"><strong>{{ business.profileEditAccessStatus || "locked" }}</strong><span>editim</span></article>
                </div>

                <div class="action-row">
                  <IonButton class="ghost-button" @click="handleBusinessVerification(business, 'verified')">Verifiko</IonButton>
                  <IonButton class="ghost-button" @click="handleBusinessVerification(business, 'rejected')">Refuzo</IonButton>
                  <IonButton
                    v-if="business.profileEditAccessStatus === 'pending' || business.profileEditAccessStatus === 'locked'"
                    class="ghost-button"
                    @click="handleBusinessEditAccess(business, 'approved')"
                  >
                    Lejo editim
                  </IonButton>
                  <IonButton
                    v-if="business.profileEditAccessStatus === 'approved'"
                    class="ghost-button"
                    @click="handleBusinessEditAccess(business, 'locked')"
                  >
                    Mbylle editim
                  </IonButton>
                </div>
              </article>
            </section>
          </template>

          <template v-else-if="activeSection === 'reports'">
            <section class="stack-list">
              <article v-for="report in reports" :key="report.id" class="surface-card section-card stack-list">
                <div class="section-head">
                  <div>
                    <p class="section-kicker">{{ report.targetType || "Report" }}</p>
                    <h2>{{ report.targetLabel || "Objekt i raportuar" }}</h2>
                    <p class="section-copy">{{ report.reason || "-" }}</p>
                  </div>
                  <span class="meta-pill">{{ report.status || "open" }}</span>
                </div>

                <p class="section-copy">{{ report.details || "Pa detaje shtese." }}</p>
                <label class="checkout-field">
                  <span>Shenimet e adminit</span>
                  <textarea v-model="reportDrafts[Number(report.id)]" class="mobile-textarea" rows="3" />
                </label>
                <div class="action-row">
                  <IonButton class="ghost-button" @click="handleReportUpdate(report, 'reviewing')">Reviewing</IonButton>
                  <IonButton class="ghost-button" @click="handleReportUpdate(report, 'resolved')">Resolved</IonButton>
                  <IonButton class="ghost-button" @click="handleReportUpdate(report, 'dismissed')">Dismiss</IonButton>
                </div>
              </article>
            </section>
          </template>

          <template v-else>
            <section class="stack-list">
              <div class="section-head">
                <div>
                  <p class="section-kicker">Produktet</p>
                  <h2>Panorama e katalogut</h2>
                </div>
              </div>
              <div class="product-grid">
                <ProductCardMobile
                  v-for="product in products.slice(0, 12)"
                  :key="product.id"
                  :product="product"
                  analytics-mode
                  @open="(id) => router.push(`/product/${id}`)"
                />
              </div>
            </section>
          </template>
        </template>
      </div>
    </IonContent>
  </IonPage>
</template>

<style scoped>
.mini-stat ion-icon {
  font-size: 1rem;
  color: var(--trego-accent);
}

.mobile-select,
.mobile-textarea {
  width: 100%;
  border: 1px solid var(--trego-input-border);
  border-radius: 18px;
  background: var(--trego-input-bg);
  color: var(--trego-dark);
}

.mobile-select {
  min-height: 48px;
  padding: 0 14px;
}

.mobile-textarea {
  padding: 12px 14px;
}

.checkout-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 12px;
}

.checkout-field {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.checkout-field span {
  color: var(--trego-dark);
  font-size: 0.82rem;
  font-weight: 700;
}

.action-row {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
}

.danger-button {
  --color: var(--trego-danger);
}

.chip--active {
  background: rgba(255, 106, 43, 0.14);
  border-color: rgba(255, 106, 43, 0.3);
}

@media (max-width: 420px) {
  .checkout-grid {
    grid-template-columns: 1fr;
  }
}
</style>
