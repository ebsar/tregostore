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
    <IonContent :fullscreen="true">
      <div>
        <div>
          <div>
            <button type="button" @click="handleSupport">
              <IonIcon :icon="headsetOutline" />
              <span>Customer Service</span>
            </button>

            <button type="button" @click="searchOpen = !searchOpen">
              <IonIcon :icon="searchOutline" />
            </button>
          </div>

          <section v-if="searchOpen">
            <IonIcon :icon="searchOutline" />
            <input
              v-model="searchQuery"
             
              type="search"
              placeholder="Kerko settings, porosi, mesazhe"
            >
          </section>

          <section v-if="sessionState.user">
            <div>
              <div>
                <img
                  v-if="accountImageUrl"
                  :src="accountImageUrl"
                  :alt="greeting"
                 
                >
                <span v-else>{{ accountInitials }}</span>
              </div>

              <div>
                <p>User information</p>
                <h1>{{ greeting }}</h1>
                <p>{{ sessionState.user.email || "Tregio account" }}</p>
              </div>
            </div>

            <div>
              <span v-if="isAdminUser">Admin</span>
              <span v-else-if="isBusinessUser">Business</span>
            </div>
          </section>
        </div>

        <section v-if="!sessionState.sessionLoaded">
          <IonSpinner name="crescent" />
        </section>

        <template v-else-if="!sessionState.user">
          <section>
            <p>Account</p>
            <h1>Kyçuni ose krijoni llogari.</h1>
            <p>Qasuni në wishlist, porosi, mesazhe dhe settings sapo të hyni në llogari.</p>

            <div>
              <IonButton @click="router.push('/login?redirect=/tabs/account')">
                Login
              </IonButton>
              <IonButton @click="router.push('/signup?redirect=/tabs/account')">
                Sign up
              </IonButton>
            </div>
          </section>
        </template>

        <template v-else>
          <section>
            <button
              v-for="item in filteredActionItems"
              :key="item.title"
             
              type="button"
              @click="handleShortcutSelect(item)"
            >
              <IonIcon :icon="item.icon" />
              <strong>{{ item.title }}</strong>
              <small>{{ item.copy }}</small>
            </button>
          </section>

          <IonButton @click="handleLogout">
            <IonIcon slot="start" :icon="logOutOutline" />
            Logout
          </IonButton>
        </template>
      </div>
    </IonContent>
  </IonPage>
</template>

