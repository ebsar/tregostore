<script setup lang="ts">
import {
  IonContent,
  IonIcon,
  IonInfiniteScroll,
  IonInfiniteScrollContent,
  IonPage,
} from "@ionic/vue";
import { storefrontOutline } from "ionicons/icons";
import { computed, onMounted, ref, watch } from "vue";
import { useRouter } from "vue-router";
import BusinessCardMobile from "../components/BusinessCardMobile.vue";
import BusinessCardSkeleton from "../components/BusinessCardSkeleton.vue";
import EmptyStatePanel from "../components/EmptyStatePanel.vue";
import {
  fetchPublicBusinesses,
  fetchPublicBusinessProductsPage,
  openBusinessConversation,
  toggleBusinessFollow,
} from "../lib/api";
import type { BusinessItem, ProductItem } from "../types/models";
import { ensureSession, refreshCounts, sessionState } from "../stores/session";

const PAGE_SIZE = 8;
const router = useRouter();
const loading = ref(true);
const query = ref("");
const selectedCategory = ref("all");
const displayedCount = ref(PAGE_SIZE);
const businesses = ref<BusinessItem[]>([]);
const previewProducts = ref<Record<number, ProductItem[]>>({});
const previewLoadingIds = ref<number[]>([]);
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

const visibleBusinesses = computed(() => filteredBusinesses.value.slice(0, displayedCount.value));
const hasMoreVisible = computed(() => visibleBusinesses.value.length < filteredBusinesses.value.length);

async function ensurePreviewProductsLoaded(entries: BusinessItem[] = []) {
  const targets = entries.filter((business) => {
    const businessId = Number(business.id || 0);
    return businessId > 0
      && !previewProducts.value[businessId]
      && !previewLoadingIds.value.includes(businessId);
  });

  if (!targets.length) {
    return;
  }

  previewLoadingIds.value = [...previewLoadingIds.value, ...targets.map((business) => Number(business.id))];
  try {
    const previewEntries = await Promise.all(
      targets.map(async (business) => {
        const nextProducts = await fetchPublicBusinessProductsPage(business.id, 6, 0).catch(() => ({
          items: [] as ProductItem[],
        }));
        return [business.id, nextProducts.items || []] as const;
      }),
    );

    previewProducts.value = {
      ...previewProducts.value,
      ...Object.fromEntries(previewEntries),
    };
  } finally {
    const completedIds = new Set(targets.map((business) => Number(business.id)));
    previewLoadingIds.value = previewLoadingIds.value.filter((id) => !completedIds.has(id));
  }
}

async function loadBusinesses() {
  loading.value = true;
  try {
    businesses.value = await fetchPublicBusinesses();
    displayedCount.value = PAGE_SIZE;
    await ensurePreviewProductsLoaded(visibleBusinesses.value);
  } finally {
    loading.value = false;
  }
}

async function handleFollow(business: BusinessItem) {
  if (!sessionState.user) {
    router.push("/login?redirect=/tabs/businesses");
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
    router.push("/login?redirect=/tabs/businesses");
    return;
  }

  const { response, data } = await openBusinessConversation(business.id);
  if (!response.ok || !data?.ok || !data?.conversation?.id) {
    return;
  }

  await refreshCounts();
  router.push(`/messages/${data.conversation.id}`);
}

async function handleLoadMore(event: CustomEvent) {
  const infinite = event.target as HTMLIonInfiniteScrollElement & { complete: () => void; disabled: boolean };
  if (!hasMoreVisible.value) {
    infinite.complete();
    infinite.disabled = true;
    return;
  }

  displayedCount.value += PAGE_SIZE;
  await ensurePreviewProductsLoaded(visibleBusinesses.value);
  infinite.complete();
  if (!hasMoreVisible.value) {
    infinite.disabled = true;
  }
}

onMounted(async () => {
  void ensureSession();
  await loadBusinesses();
});

watch([query, selectedCategory], async () => {
  displayedCount.value = PAGE_SIZE;
  await ensurePreviewProductsLoaded(visibleBusinesses.value);
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

        <section v-if="loading" class="stack-list">
          <BusinessCardSkeleton v-for="index in 4" :key="index" />
        </section>

        <section v-else-if="visibleBusinesses.length" class="stack-list">
          <BusinessCardMobile
            v-for="business in visibleBusinesses"
            :key="business.id"
            :business="business"
            :preview-products="previewProducts[business.id] || []"
            :follow-busy="followBusyId === business.id"
            @open="router.push(`/business/public/${business.id}`)"
            @follow="handleFollow(business)"
            @message="handleMessage(business)"
            @open-product="(id) => router.push(`/product/${id}`)"
          />

          <IonInfiniteScroll
            v-if="hasMoreVisible"
            threshold="160px"
            @ionInfinite="handleLoadMore"
          >
            <IonInfiniteScrollContent
              loading-spinner="crescent"
              loading-text="Po ngarkohen biznese te tjera..."
            />
          </IonInfiniteScroll>
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
  position: sticky;
  top: calc(env(safe-area-inset-top, 0px) + 8px);
  z-index: 6;
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
    linear-gradient(135deg, rgba(37, 99, 235, 0.96), rgba(29, 78, 216, 0.9));
  color: #fffdf9;
  border-color: rgba(59, 130, 246, 0.42);
  box-shadow: 0 14px 24px rgba(37, 99, 235, 0.16);
}

body[data-theme="dark"] .businesses-top-shell {
  background: rgba(6, 12, 22, 0.82);
}

body[data-theme="dark"] .businesses-search-shell {
  border-color: rgba(198, 214, 242, 0.14);
  background: rgba(19, 27, 42, 0.78);
  box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.08);
}

body[data-theme="dark"] .businesses-search-input {
  color: rgba(241, 245, 249, 0.92);
}
</style>
