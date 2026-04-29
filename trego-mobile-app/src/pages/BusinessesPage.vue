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
    <IonContent :fullscreen="true">
      <div class="trego-mobile-screen">
        <section class="trego-search-card">
          <div class="trego-search-form">
            <IonIcon :icon="storefrontOutline" />
            <input
              v-model="query"
              type="search"
              placeholder="Kerko biznesin"
            >
          </div>

          <div class="trego-chip-row">
            <button
              v-for="category in categories"
              :key="category"
              :class="['trego-chip', { 'is-active': selectedCategory === category }]"
              type="button"
              @click="selectedCategory = category"
            >
              {{ category === "all" ? "Te gjitha" : category }}
            </button>
          </div>
        </section>

        <section v-if="loading" class="trego-business-list">
          <BusinessCardSkeleton v-for="index in 4" :key="index" />
        </section>

        <section v-else-if="visibleBusinesses.length" class="trego-business-list">
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
