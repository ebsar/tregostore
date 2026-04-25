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
    <IonContent :fullscreen="true">
      <div>
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
          <IonButton @click="router.push('/login?redirect=/admin/control')">
            Login
          </IonButton>
        </EmptyStatePanel>

        <EmptyStatePanel
          v-else-if="!canAccess"
          title="Kjo pjese eshte vetem per admin"
          copy="Per siguri, vetem roli admin e sheh panelin operativ."
        />

        <template v-else>
          <section>
            <div>
              <article v-for="item in statCards" :key="item.label">
                <IonIcon :icon="item.icon" />
                <strong>{{ item.value }}</strong>
                <span>{{ item.label }}</span>
              </article>
            </div>
          </section>

          <section>
            <button type="button" @click="activeSection = 'users'">Users</button>
            <button type="button" @click="activeSection = 'businesses'">Biznese</button>
            <button type="button" @click="activeSection = 'reports'">Reports</button>
            <button type="button" @click="activeSection = 'products'">Produkte</button>
          </section>

          <p v-if="ui.message">{{ ui.message }}</p>

          <section v-if="loading">
            <p>Po ngarkohet paneli admin...</p>
          </section>

          <template v-else-if="activeSection === 'users'">
            <section>
              <article v-for="user in users" :key="user.id">
                <div>
                  <div>
                    <p>User</p>
                    <h2>{{ user.fullName || "Pa emer" }}</h2>
                    <p>{{ user.email || "-" }}</p>
                  </div>
                  <span>{{ user.role || "client" }}</span>
                </div>

                <div>
                  <label>
                    <span>Roli</span>
                    <select v-model="draftForUser(user).role">
                      <option value="client">Client</option>
                      <option value="business">Business</option>
                      <option value="admin">Admin</option>
                    </select>
                  </label>
                  <label>
                    <span>Fjalekalim i perkohshem</span>
                    <input v-model="draftForUser(user).password" type="text" placeholder="Ndrysho fjalekalimin" />
                  </label>
                </div>

                <div>
                  <IonButton @click="handleUpdateRole(user)">Ruaje rolin</IonButton>
                  <IonButton @click="handleSetPassword(user)">Ruaje password</IonButton>
                  <IonButton @click="handleDeleteUser(user)">
                    <IonIcon slot="start" :icon="trashOutline" />
                    Fshije
                  </IonButton>
                </div>
              </article>
            </section>
          </template>

          <template v-else-if="activeSection === 'businesses'">
            <section>
              <div>
                <p>Biznes i ri</p>
                <h2>Krijo llogari biznesi</h2>
              </div>

              <div>
                <label><span>Pronari</span><input v-model="createBusinessForm.fullName" type="text" placeholder="Emri dhe mbiemri" /></label>
                <label><span>Email</span><input v-model="createBusinessForm.email" type="email" placeholder="biznesi@email.com" /></label>
              </div>
              <div>
                <label><span>Password</span><input v-model="createBusinessForm.password" type="text" placeholder="Fjalekalimi" /></label>
                <label><span>Biznesi</span><input v-model="createBusinessForm.businessName" type="text" placeholder="Emri i biznesit" /></label>
              </div>
              <div>
                <label><span>Nr. biznesit</span><input v-model="createBusinessForm.businessNumber" type="text" placeholder="BR-..." /></label>
                <label><span>Telefoni</span><input v-model="createBusinessForm.phoneNumber" type="text" placeholder="+383..." /></label>
              </div>
              <div>
                <label><span>Qyteti</span><input v-model="createBusinessForm.city" type="text" placeholder="Prishtine" /></label>
                <label><span>Adresa</span><input v-model="createBusinessForm.addressLine" type="text" placeholder="Adresa e biznesit" /></label>
              </div>
              <label><span>Pershkrimi</span><textarea v-model="createBusinessForm.businessDescription" rows="3" /></label>

              <IonButton @click="handleCreateBusiness">Krijo biznesin</IonButton>
            </section>

            <section>
              <article v-for="business in businesses" :key="business.id">
                <div>
                  <div>
                    <p>Biznes</p>
                    <h2>{{ business.businessName || "Biznes pa emer" }}</h2>
                    <p>{{ business.ownerName || "-" }} · {{ business.ownerEmail || "-" }}</p>
                  </div>
                  <span>{{ business.verificationStatus || "locked" }}</span>
                </div>

                <div>
                  <article><strong>{{ formatCount(business.productsCount || 0) }}</strong><span>produkte</span></article>
                  <article><strong>{{ formatCount(business.ordersCount || 0) }}</strong><span>porosi</span></article>
                  <article><strong>{{ business.profileEditAccessStatus || "locked" }}</strong><span>editim</span></article>
                </div>

                <div>
                  <IonButton @click="handleBusinessVerification(business, 'verified')">Verifiko</IonButton>
                  <IonButton @click="handleBusinessVerification(business, 'rejected')">Refuzo</IonButton>
                  <IonButton
                    v-if="business.profileEditAccessStatus === 'pending' || business.profileEditAccessStatus === 'locked'"
                   
                    @click="handleBusinessEditAccess(business, 'approved')"
                  >
                    Lejo editim
                  </IonButton>
                  <IonButton
                    v-if="business.profileEditAccessStatus === 'approved'"
                   
                    @click="handleBusinessEditAccess(business, 'locked')"
                  >
                    Mbylle editim
                  </IonButton>
                </div>
              </article>
            </section>
          </template>

          <template v-else-if="activeSection === 'reports'">
            <section>
              <article v-for="report in reports" :key="report.id">
                <div>
                  <div>
                    <p>{{ report.targetType || "Report" }}</p>
                    <h2>{{ report.targetLabel || "Objekt i raportuar" }}</h2>
                    <p>{{ report.reason || "-" }}</p>
                  </div>
                  <span>{{ report.status || "open" }}</span>
                </div>

                <p>{{ report.details || "Pa detaje shtese." }}</p>
                <label>
                  <span>Shenimet e adminit</span>
                  <textarea v-model="reportDrafts[Number(report.id)]" rows="3" />
                </label>
                <div>
                  <IonButton @click="handleReportUpdate(report, 'reviewing')">Reviewing</IonButton>
                  <IonButton @click="handleReportUpdate(report, 'resolved')">Resolved</IonButton>
                  <IonButton @click="handleReportUpdate(report, 'dismissed')">Dismiss</IonButton>
                </div>
              </article>
            </section>
          </template>

          <template v-else>
            <section>
              <div>
                <div>
                  <p>Produktet</p>
                  <h2>Panorama e katalogut</h2>
                </div>
              </div>
              <div>
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

