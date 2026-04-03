<script setup lang="ts">
import { IonContent, IonIcon, IonPage, IonSpinner } from "@ionic/vue";
import { chatbubbleEllipsesOutline, storefrontOutline } from "ionicons/icons";
import { computed, onMounted, ref } from "vue";
import { useRouter } from "vue-router";
import BusinessCardMobile from "../components/BusinessCardMobile.vue";
import EmptyStatePanel from "../components/EmptyStatePanel.vue";
import {
  fetchPublicBusinesses,
  fetchPublicBusinessProducts,
  openBusinessConversation,
  toggleBusinessFollow,
} from "../lib/api";
import type { BusinessItem, ProductItem } from "../types/models";
import { ensureSession, refreshCounts, sessionState } from "../stores/session";

const router = useRouter();
const loading = ref(true);
const query = ref("");
const selectedCategory = ref("all");
const businesses = ref<BusinessItem[]>([]);
const previewProducts = ref<Record<number, ProductItem[]>>({});
const followBusyId = ref(0);

const categories = computed(() => {
  const unique = new Set<string>();
  for (const business of businesses.value) {
    const next = String(business.category || "").trim();
    if (next) {
      unique.add(next);
    }
  }
  return ["all", ...Array.from(unique).sort((left, right) => left.localeCompare(right))];
});

const filteredBusinesses = computed(() => {
  const normalizedQuery = query.value.trim().toLowerCase();
  return businesses.value.filter((business) => {
    const matchesCategory = selectedCategory.value === "all"
      || String(business.category || "").trim() === selectedCategory.value;
    if (!matchesCategory) {
      return false;
    }

    if (!normalizedQuery) {
      return true;
    }

    return [
      business.businessName,
      business.city,
      business.category,
      business.description,
      business.businessDescription,
    ]
      .map((value) => String(value || "").toLowerCase())
      .join(" ")
      .includes(normalizedQuery);
  });
});

async function loadBusinesses() {
  loading.value = true;
  try {
    businesses.value = await fetchPublicBusinesses();

    const previewEntries = await Promise.all(
      businesses.value.slice(0, 10).map(async (business) => {
        const nextProducts = await fetchPublicBusinessProducts(business.id, 6, 0).catch(() => []);
        return [business.id, nextProducts] as const;
      }),
    );

    previewProducts.value = Object.fromEntries(previewEntries);
  } finally {
    loading.value = false;
  }
}

async function handleFollow(business: BusinessItem) {
  if (!sessionState.user) {
    router.push("/tabs/account");
    return;
  }

  followBusyId.value = business.id;
  try {
    const { response, data } = await toggleBusinessFollow(business.id);
    if (!response.ok || !data?.ok) {
      return;
    }

    businesses.value = businesses.value.map((item) => {
      if (item.id !== business.id) {
        return item;
      }

      const isFollowed = Boolean(data.business?.isFollowed ?? !item.isFollowed);
      const followersCount = Number(
        data.business?.followersCount
        ?? (item.followersCount || 0) + (isFollowed ? 1 : -1),
      );
      return {
        ...item,
        isFollowed,
        followersCount: Math.max(0, followersCount),
      };
    });
    await refreshCounts();
  } finally {
    followBusyId.value = 0;
  }
}

async function handleMessage(business: BusinessItem) {
  if (!sessionState.user) {
    router.push("/tabs/account");
    return;
  }

  const { response, data } = await openBusinessConversation(business.id);
  if (!response.ok || !data?.ok || !data?.conversation?.id) {
    return;
  }

  await refreshCounts();
  router.push(`/messages/${data.conversation.id}`);
}

onMounted(async () => {
  void ensureSession();
  await loadBusinesses();
});
</script>

<template>
  <IonPage>
    <IonContent class="app-gradient" :fullscreen="true">
      <div class="mobile-page mobile-page--tabbed mobile-page--edge businesses-page">
        <section class="businesses-top-shell surface-card">
          <div class="businesses-search-shell">
            <IonIcon :icon="storefrontOutline" />
            <input
              v-model="query"
              class="businesses-search-input"
              type="search"
              placeholder="Kerko biznesin"
            >
          </div>

          <div class="chip-row businesses-filter-row">
            <button
              v-for="category in categories"
              :key="category"
              class="chip businesses-filter-chip"
              :class="{ 'is-active': selectedCategory === category }"
              type="button"
              @click="selectedCategory = category"
            >
              {{ category === "all" ? "Te gjitha" : category }}
            </button>
          </div>
        </section>

        <section v-if="loading" class="surface-card empty-panel">
          <IonSpinner name="crescent" />
        </section>

        <section v-else-if="filteredBusinesses.length" class="stack-list">
          <BusinessCardMobile
            v-for="business in filteredBusinesses"
            :key="business.id"
            :business="business"
            :preview-products="previewProducts[business.id] || []"
            :follow-busy="followBusyId === business.id"
            @open="router.push(`/business/public/${business.id}`)"
            @follow="handleFollow(business)"
            @message="handleMessage(business)"
            @open-product="(id) => router.push(`/product/${id}`)"
          />
        </section>

        <EmptyStatePanel
          v-else
          title="Nuk u gjet asnje biznes"
          copy="Provo nje kategori tjeter ose nje kerkim me emer, qytet ose aktivitet."
        />
      </div>
    </IonContent>
  </IonPage>
</template>

<style scoped>
.businesses-page {
  gap: 14px;
}

.businesses-top-shell {
  display: grid;
  gap: 12px;
  padding: 12px;
}

.businesses-search-shell {
  display: flex;
  align-items: center;
  gap: 10px;
  min-height: 54px;
  padding: 0 16px;
  border-radius: 22px;
  border: 1px solid rgba(255, 255, 255, 0.5);
  background:
    linear-gradient(180deg, rgba(255, 255, 255, 0.24), rgba(255, 255, 255, 0.08)),
    radial-gradient(circle at 8% 0%, rgba(255, 255, 255, 0.18), transparent 30%);
  box-shadow:
    inset 0 1px 0 rgba(255, 255, 255, 0.62),
    0 14px 28px rgba(31, 41, 55, 0.08);
}

.businesses-search-shell ion-icon {
  color: var(--trego-accent);
  font-size: 1rem;
}

.businesses-search-input {
  width: 100%;
  border: 0;
  outline: 0;
  background: transparent;
  color: var(--trego-dark);
  font: inherit;
  font-size: 0.98rem;
  font-weight: 700;
}

.businesses-search-input::placeholder {
  color: var(--trego-muted);
}

.businesses-filter-row {
  padding-bottom: 2px;
}

.businesses-filter-chip.is-active {
  background:
    linear-gradient(135deg, rgba(255, 126, 64, 0.96), rgba(255, 106, 43, 0.88));
  color: #fffdf9;
  border-color: rgba(255, 140, 89, 0.44);
  box-shadow: 0 14px 24px rgba(255, 106, 43, 0.18);
}
</style>
