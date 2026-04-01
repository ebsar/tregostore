<script setup lang="ts">
import { IonButton, IonContent, IonIcon, IonInput, IonPage } from "@ionic/vue";
import { headsetOutline, searchOutline } from "ionicons/icons";
import { computed, onMounted, ref, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import AppBackButton from "../components/AppBackButton.vue";
import { fetchConversations, openSupportConversation } from "../lib/api";
import EmptyStatePanel from "../components/EmptyStatePanel.vue";
import type { ConversationItem } from "../types/models";
import { ensureSession, refreshCounts, sessionState } from "../stores/session";

const route = useRoute();
const router = useRouter();
const conversations = ref<ConversationItem[]>([]);
const searchTerm = ref("");

const highlightedConversationId = computed(() => {
  const nextValue = Number(route.query.conversationId || 0);
  return Number.isFinite(nextValue) ? Math.max(0, nextValue) : 0;
});
const orderedConversations = computed(() => {
  if (highlightedConversationId.value <= 0) {
    return conversations.value;
  }

  const selected = conversations.value.find((item) => Number(item.id || 0) === highlightedConversationId.value);
  if (!selected) {
    return conversations.value;
  }

  return [
    selected,
    ...conversations.value.filter((item) => Number(item.id || 0) !== highlightedConversationId.value),
  ];
});
const visibleConversations = computed(() => {
  const needle = searchTerm.value.trim().toLowerCase();
  if (!needle) {
    return orderedConversations.value;
  }

  return orderedConversations.value.filter((conversation) => {
    const haystack = [
      conversation.counterpartName,
      conversation.businessName,
      conversation.clientName,
      conversation.counterpartRole,
      conversation.lastMessagePreview,
    ]
      .map((value) => String(value || "").toLowerCase())
      .join(" ");

    return haystack.includes(needle);
  });
});

async function loadConversations() {
  await ensureSession();
  if (sessionState.user) {
    conversations.value = await fetchConversations();
    await refreshCounts();
  }
}

function openConversation(conversationId: number) {
  router.push(`/messages/${conversationId}`);
}

async function openSupport() {
  await ensureSession();
  if (!sessionState.user) {
    router.push("/login?redirect=/messages");
    return;
  }

  const { response, data } = await openSupportConversation();
  if (!response.ok || !data?.ok || !data?.conversation?.id) {
    return;
  }

  router.push(`/messages/${data.conversation.id}`);
}

onMounted(async () => {
  if (highlightedConversationId.value > 0) {
    router.replace(`/messages/${highlightedConversationId.value}`);
    return;
  }

  await loadConversations();
});

watch(
  () => route.fullPath,
  () => {
    if (route.path === "/messages") {
      void loadConversations();
    }
  },
);
</script>

<template>
  <IonPage>
    <IonContent class="app-gradient" :fullscreen="true">
      <div class="mobile-page">
        <section class="messages-topbar">
          <AppBackButton back-to="/tabs/account" />
          <div class="messages-topbar-copy">
            <p class="section-kicker">Mesazhet</p>
            <h1>Messages</h1>
          </div>
        </section>

        <section v-if="sessionState.user" class="messages-toolbar">
          <button class="messages-support-button" type="button" @click="openSupport">
            <IonIcon :icon="headsetOutline" />
            <span>Contact support</span>
          </button>

          <div class="messages-search-shell" role="search" aria-label="Kerko ne mesazhe">
            <IonIcon :icon="searchOutline" />
            <IonInput
              v-model="searchTerm"
              class="messages-search-input"
              placeholder="Kerko ne mesazhe..."
              clear-input
            />
          </div>
        </section>

        <EmptyStatePanel
          v-if="!sessionState.user"
          title="Kyçu per te pare mesazhet"
          copy="Mesazhet ruhen ne backend-in aktual dhe shfaqen ketu me te njejtin account."
        >
          <IonButton class="cta-button messages-login-button" @click="router.push('/login?redirect=/messages')">
            Login
          </IonButton>
        </EmptyStatePanel>

        <div v-else-if="visibleConversations.length" class="stack-list">
          <article
            v-for="conversation in visibleConversations"
            :key="conversation.id"
            class="surface-card conversation-card"
            :class="{ 'is-highlighted': highlightedConversationId > 0 && highlightedConversationId === conversation.id }"
            @click="openConversation(conversation.id)"
          >
            <div class="section-head">
              <div>
                <p class="section-kicker">{{ conversation.counterpartRole || "Conversation" }}</p>
                <h3 class="conversation-card-title">{{ conversation.counterpartName || "Support" }}</h3>
              </div>
              <span class="chip" v-if="conversation.unreadCount">{{ conversation.unreadCount }} reja</span>
            </div>
            <p class="section-copy conversation-card-copy">
              {{ conversation.lastMessagePreview || "Nuk ka mesazh te fundit." }}
            </p>
          </article>
        </div>

        <EmptyStatePanel
          v-else
          title="Asnje conversation ende"
          copy="Sapo te hapet nje bisede nga web ose app, ajo do te lexohet ketu."
        />
      </div>
    </IonContent>
  </IonPage>
</template>

<style scoped>
.conversation-card {
  cursor: pointer;
  padding: 16px;
  transition: transform 180ms ease, box-shadow 180ms ease, border-color 180ms ease;
}

.messages-login-button {
  margin-top: 14px;
}

.messages-topbar {
  display: flex;
  align-items: center;
  gap: 10px;
}

.messages-topbar-copy {
  display: grid;
  gap: 2px;
}

.messages-topbar-copy h1,
.messages-topbar-copy p {
  margin: 0;
}

.messages-topbar-copy h1 {
  color: var(--trego-dark);
  font-size: 1.3rem;
  line-height: 1.05;
}

.messages-toolbar {
  display: grid;
  grid-template-columns: auto minmax(0, 1fr);
  gap: 10px;
  align-items: center;
}

.messages-support-button {
  display: inline-flex;
  min-height: 54px;
  align-items: center;
  justify-content: center;
  gap: 8px;
  padding: 0 14px;
  border: 0;
  border-radius: 20px;
  background: rgba(255, 255, 255, 0.9);
  color: var(--trego-dark);
  font-size: 0.74rem;
  font-weight: 800;
  box-shadow: 0 12px 28px rgba(31, 41, 55, 0.08);
}

.messages-support-button ion-icon {
  font-size: 1rem;
}

.messages-search-shell {
  display: grid;
  grid-template-columns: 18px minmax(0, 1fr);
  align-items: center;
  gap: 10px;
  min-height: 54px;
  padding: 0 14px;
  border-radius: 20px;
  border: 1px solid var(--trego-input-border);
  background: rgba(255, 255, 255, 0.9);
  box-shadow: 0 12px 28px rgba(31, 41, 55, 0.06);
}

.messages-search-shell ion-icon {
  color: var(--trego-muted);
}

.messages-search-input {
  --padding-start: 0;
  --padding-end: 0;
  --placeholder-color: rgba(47, 52, 70, 0.54);
  color: var(--trego-dark);
  font-size: 0.94rem;
  font-weight: 700;
}

.conversation-card-title {
  margin: 0;
  color: var(--trego-dark);
}

.conversation-card-copy {
  margin-top: 10px;
}

.conversation-card:active {
  transform: scale(0.992);
}

.conversation-card.is-highlighted {
  border-color: var(--trego-selection-border);
  box-shadow: var(--trego-selection-shadow);
}

body[data-theme="dark"] .messages-support-button,
body[data-theme="dark"] .messages-search-shell {
  background: rgba(18, 18, 20, 0.84);
  border-color: rgba(255, 255, 255, 0.12);
}
</style>
