<script setup lang="ts">
import { IonButton, IonContent, IonIcon, IonPage, IonSpinner } from "@ionic/vue";
import {
  briefcaseOutline,
  chatbubblesOutline,
  headsetOutline,
  heartOutline,
  logOutOutline,
  personCircleOutline,
  receiptOutline,
  searchOutline,
  settingsOutline,
} from "ionicons/icons";
import { computed, onMounted, ref } from "vue";
import { useRouter } from "vue-router";
import { openSupportConversation } from "../lib/api";
import { createApiUrl } from "../lib/config";
import { clearSession, ensureSession, isBusinessUser, refreshCounts, sessionState } from "../stores/session";

const router = useRouter();
const searchOpen = ref(false);
const searchQuery = ref("");
const supportBusy = ref(false);

const isAdminUser = computed(() => sessionState.user?.role === "admin");
const greeting = computed(() => sessionState.user?.fullName || sessionState.user?.businessName || "Tregio user");
const accountImageUrl = computed(() => {
  const rawValue = String(
    sessionState.user?.profileImagePath || sessionState.user?.businessLogoPath || "",
  ).trim();
  return rawValue ? createApiUrl(rawValue) : "";
});
const accountInitials = computed(() => {
  const label = String(greeting.value || "").trim();
  if (!label) {
    return "T";
  }

  const parts = label.split(/\s+/).filter(Boolean);
  if (parts.length === 1) {
    return parts[0].slice(0, 1).toUpperCase();
  }

  return `${parts[0]?.[0] || ""}${parts[1]?.[0] || ""}`.toUpperCase();
});

const actionItems = computed(() =>
  [
    {
      title: "Profili",
      copy: "Detajet e llogarise",
      icon: personCircleOutline,
      to: "/tabs/account",
    },
    {
      title: "Wishlist",
      copy: "Produktet e ruajtura",
      icon: heartOutline,
      to: "/tabs/wishlist",
    },
    {
      title: "Mesazhet",
      copy: "Bisedat dhe support",
      icon: chatbubblesOutline,
      to: "/messages",
    },
    {
      title: "Porosite",
      copy: "Statuset dhe historiku",
      icon: receiptOutline,
      to: "/orders",
    },
    isAdminUser.value
      ? {
          title: "Admin",
          copy: "Users dhe raporte",
          icon: settingsOutline,
          to: "/admin/control",
        }
      : null,
    isBusinessUser.value
      ? {
          title: "Biznesi",
          copy: "Studio dhe menaxhim",
          icon: briefcaseOutline,
          to: "/business/studio",
        }
      : null,
    {
      title: "Settings",
      copy: "Theme dhe privatësi",
      icon: settingsOutline,
      to: "/app/settings",
    },
  ].filter(Boolean),
);

const filteredActionItems = computed(() => {
  const normalized = searchQuery.value.trim().toLowerCase();
  if (!normalized) {
    return actionItems.value;
  }

  return actionItems.value.filter((item: any) =>
    [item.title, item.copy]
      .map((value) => String(value || "").toLowerCase())
      .join(" ")
      .includes(normalized),
  );
});

onMounted(() => {
  void ensureSession();
});

function handleShortcutSelect(item: any) {
  if (item?.to) {
    router.push(item.to);
  }
}

async function handleSupport() {
  if (supportBusy.value) {
    return;
  }

  if (!sessionState.user) {
    router.push("/login?redirect=/tabs/account");
    return;
  }

  supportBusy.value = true;
  try {
    const { response, data } = await openSupportConversation();
    if (!response.ok || !data?.ok || !data?.conversation?.id) {
      router.push("/messages");
      return;
    }
    await refreshCounts();
    router.push(`/messages/${data.conversation.id}`);
  } finally {
    supportBusy.value = false;
  }
}

async function handleLogout() {
  await clearSession();
  router.replace("/tabs/home");
}
</script>

<template>
  <IonPage>
    <IonContent class="app-gradient" :fullscreen="true">
      <div class="mobile-page mobile-page--tabbed mobile-page--account" :class="{ 'is-guest': !sessionState.user }">
        <div class="account-sticky-shell">
          <div class="account-top-tools">
            <button class="account-top-pill" type="button" @click="handleSupport">
              <IonIcon :icon="headsetOutline" />
              <span>Customer Service</span>
            </button>

            <button class="account-top-icon" type="button" @click="searchOpen = !searchOpen">
              <IonIcon :icon="searchOutline" />
            </button>
          </div>

          <section v-if="searchOpen" class="surface-card account-search-shell">
            <IonIcon :icon="searchOutline" />
            <input
              v-model="searchQuery"
              class="account-search-input"
              type="search"
              placeholder="Kerko settings, porosi, mesazhe"
            >
          </section>

          <section v-if="sessionState.user" class="surface-card section-card account-hero-card">
            <div class="account-hero-main">
              <div class="account-avatar-shell">
                <img
                  v-if="accountImageUrl"
                  :src="accountImageUrl"
                  :alt="greeting"
                  class="account-avatar-image"
                >
                <span v-else class="account-avatar-fallback">{{ accountInitials }}</span>
              </div>

              <div class="account-hero-copy">
                <p class="section-kicker">User information</p>
                <h1>{{ greeting }}</h1>
                <p>{{ sessionState.user.email || "Tregio account" }}</p>
              </div>
            </div>

            <div class="account-hero-meta">
              <span v-if="isAdminUser" class="account-chip">Admin</span>
              <span v-else-if="isBusinessUser" class="account-chip">Business</span>
            </div>
          </section>
        </div>

        <section v-if="!sessionState.sessionLoaded" class="surface-card surface-card--strong guest-account-card account-loading-card">
          <IonSpinner name="crescent" />
        </section>

        <template v-else-if="!sessionState.user">
          <section class="surface-card surface-card--strong guest-account-card">
            <p class="section-kicker">Account</p>
            <h1>Kyçuni ose krijoni llogari.</h1>
            <p class="section-copy">Qasuni në wishlist, porosi, mesazhe dhe settings sapo të hyni në llogari.</p>

            <div class="guest-account-actions">
              <IonButton class="cta-button guest-account-button" @click="router.push('/login?redirect=/tabs/account')">
                Login
              </IonButton>
              <IonButton class="ghost-button guest-account-button" @click="router.push('/signup?redirect=/tabs/account')">
                Sign up
              </IonButton>
            </div>
          </section>
        </template>

        <template v-else>
          <section class="account-shortcuts-grid">
            <button
              v-for="item in filteredActionItems"
              :key="item.title"
              class="account-shortcut-card"
              type="button"
              @click="handleShortcutSelect(item)"
            >
              <IonIcon :icon="item.icon" />
              <strong>{{ item.title }}</strong>
              <small>{{ item.copy }}</small>
            </button>
          </section>

          <IonButton class="ghost-button account-logout-button" @click="handleLogout">
            <IonIcon slot="start" :icon="logOutOutline" />
            Logout
          </IonButton>
        </template>
      </div>
    </IonContent>
  </IonPage>
</template>

<style scoped>
.mobile-page--account {
  gap: 14px;
}

.account-sticky-shell {
  position: sticky;
  top: calc(env(safe-area-inset-top, 0px) + 8px);
  z-index: 7;
  display: grid;
  gap: 12px;
}

.account-top-tools {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

.account-top-pill,
.account-top-icon {
  display: inline-flex;
  align-items: center;
  border: 1px solid rgba(255, 255, 255, 0.56);
  border-radius: 999px;
  background:
    linear-gradient(180deg, rgba(255,255,255,0.24), rgba(255,255,255,0.08));
  color: var(--trego-dark);
  box-shadow:
    inset 0 1px 0 rgba(255,255,255,0.72),
    0 12px 24px rgba(15, 23, 42, 0.06);
}

.account-top-pill {
  min-height: 40px;
  gap: 8px;
  padding: 0 14px;
  font-size: 0.82rem;
  font-weight: 800;
}

.account-top-icon {
  justify-content: center;
  width: 40px;
  height: 40px;
}

.account-search-shell {
  display: flex;
  align-items: center;
  gap: 10px;
  min-height: 52px;
  padding: 0 16px;
}

.account-search-shell ion-icon {
  color: var(--trego-accent);
  font-size: 1rem;
}

.account-search-input {
  width: 100%;
  border: 0;
  outline: 0;
  background: transparent;
  color: var(--trego-dark);
  font: inherit;
  font-size: 0.94rem;
  font-weight: 700;
}

.account-search-input::placeholder {
  color: var(--trego-muted);
}

.mobile-page--account.is-guest {
  min-height: 100%;
  justify-content: center;
}

.guest-account-card {
  display: grid;
  gap: 12px;
  width: min(100%, 460px);
  min-height: 280px;
  margin: 0 auto;
  padding: 24px 20px;
  align-content: center;
  text-align: center;
}

.account-loading-card {
  place-items: center;
}

.guest-account-card h1,
.guest-account-card p {
  margin: 0;
}

.guest-account-card h1 {
  color: var(--trego-dark);
  font-size: clamp(1.5rem, 7vw, 1.9rem);
  line-height: 1.04;
}

.guest-account-actions {
  display: flex;
  justify-content: center;
  flex-wrap: wrap;
  gap: 10px;
  margin-top: 8px;
}

.guest-account-button {
  width: 136px;
  max-width: 100%;
}

.account-hero-card {
  display: grid;
  gap: 14px;
}

.account-hero-main {
  display: grid;
  grid-template-columns: auto minmax(0, 1fr);
  gap: 14px;
  align-items: center;
}

.account-avatar-shell {
  display: inline-flex;
  width: 68px;
  height: 68px;
  align-items: center;
  justify-content: center;
  overflow: hidden;
  border-radius: 22px;
  background: linear-gradient(135deg, rgba(255, 106, 43, 0.18), rgba(47, 52, 70, 0.08));
  border: 1px solid var(--trego-border);
  box-shadow: var(--trego-shadow-soft);
}

.account-avatar-image {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
}

.account-avatar-fallback {
  color: var(--trego-dark);
  font-size: 1.15rem;
  font-weight: 800;
  letter-spacing: 0.04em;
}

.account-hero-copy h1,
.account-hero-copy p {
  margin: 0;
}

.account-hero-copy h1 {
  color: var(--trego-dark);
  font-size: clamp(1.45rem, 6vw, 1.8rem);
  line-height: 1.05;
}

.account-hero-copy p:last-child {
  margin-top: 5px;
  color: var(--trego-muted);
  font-size: 0.9rem;
}

.account-hero-meta {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.account-chip {
  display: inline-flex;
  min-height: 32px;
  align-items: center;
  padding: 0 12px;
  border-radius: 999px;
  background: var(--trego-interactive-bg);
  color: var(--trego-dark);
  font-size: 0.76rem;
  font-weight: 700;
}

.account-shortcuts-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 12px;
}

.account-shortcut-card {
  display: grid;
  gap: 8px;
  justify-items: start;
  min-height: 112px;
  padding: 16px 14px;
  border: 1px solid rgba(255, 255, 255, 0.58);
  border-radius: 24px;
  background:
    linear-gradient(180deg, rgba(255, 255, 255, 0.28), rgba(255, 255, 255, 0.12)),
    radial-gradient(circle at top left, rgba(255, 255, 255, 0.34), transparent 34%);
  color: var(--trego-dark);
  text-align: left;
  box-shadow:
    inset 0 1px 0 rgba(255, 255, 255, 0.78),
    0 16px 28px rgba(31, 41, 55, 0.08);
}

.account-shortcut-card ion-icon {
  display: inline-flex;
  width: 38px;
  height: 38px;
  align-items: center;
  justify-content: center;
  border-radius: 16px;
  background: linear-gradient(135deg, rgba(64, 124, 255, 0.18), rgba(64, 124, 255, 0.1));
  font-size: 1rem;
  color: #3d6cff;
}

.account-shortcut-card strong,
.account-shortcut-card small {
  display: block;
}

.account-shortcut-card strong {
  font-size: 0.92rem;
  font-weight: 800;
}

.account-shortcut-card small {
  color: var(--trego-muted);
  font-size: 0.75rem;
  line-height: 1.3;
}

.account-logout-button {
  margin-top: 2px;
}

body[data-theme="dark"] .account-top-pill,
body[data-theme="dark"] .account-top-icon,
body[data-theme="dark"] .account-shortcut-card {
  border-color: rgba(198, 214, 242, 0.14);
  background: rgba(19, 27, 42, 0.78);
  box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.08);
  color: rgba(241, 245, 249, 0.92);
}

body[data-theme="dark"] .account-search-input {
  color: rgba(241, 245, 249, 0.92);
}

body[data-theme="dark"] .account-avatar-shell {
  background: linear-gradient(135deg, rgba(64, 124, 255, 0.14), rgba(255, 255, 255, 0.04));
}
</style>
