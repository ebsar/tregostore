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
    <IonContent :fullscreen="true">
      <div class="trego-mobile-screen trego-messages-screen">
        <section class="trego-messages-header">
          <div>
            <AppBackButton back-to="/tabs/account" />
          </div>
          <div>
            <p>Mesazhet</p>
            <h1>Messages</h1>
          </div>
        </section>

        <section v-if="sessionState.sessionLoaded && sessionState.user" class="trego-messages-toolbar">
          <button class="trego-secondary-button" type="button" @click="openSupport">
            <IonIcon :icon="headsetOutline" />
            <span>Contact support</span>
          </button>

          <div class="trego-messages-search" role="search" aria-label="Kerko ne mesazhe">
            <IonIcon :icon="searchOutline" />
            <IonInput
              v-model="searchTerm"
             
              placeholder="Kerko ne mesazhe..."
              clear-input
            />
          </div>
        </section>

        <section v-if="!sessionState.sessionLoaded">
          <IonSpinner name="crescent" />
        </section>

        <EmptyStatePanel
          v-else-if="!sessionState.user"
          title="Kyçu per te pare mesazhet"
          copy="Mesazhet ruhen ne backend-in aktual dhe shfaqen ketu me te njejtin account."
        >
          <IonButton @click="router.push('/login?redirect=/messages')">
            Login
          </IonButton>
        </EmptyStatePanel>

        <div v-else-if="visibleConversations.length" class="trego-messages-list">
          <article
            v-for="conversation in visibleConversations"
            :key="conversation.id"
            class="trego-message-card"
           
           
            @click="openConversation(conversation.id)"
          >
            <div>
              <div>
                <p>{{ conversation.counterpartRole || "Conversation" }}</p>
                <h3>{{ conversation.counterpartName || "Support" }}</h3>
              </div>
              <span v-if="conversation.unreadCount">{{ conversation.unreadCount }} reja</span>
            </div>
            <p>
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
