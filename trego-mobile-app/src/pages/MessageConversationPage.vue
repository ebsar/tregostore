<script setup lang="ts">
import {
  IonButton,
  IonContent,
  IonPage,
  IonSpinner,
  IonTextarea,
} from "@ionic/vue";
import { sendOutline } from "ionicons/icons";
import { computed, nextTick, onMounted, ref, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import AppBackButton from "../components/AppBackButton.vue";
import EmptyStatePanel from "../components/EmptyStatePanel.vue";
import {
  fetchConversationDetail,
  resolveApiMessage,
  sendConversationMessage,
} from "../lib/api";
import { createApiUrl } from "../lib/config";
import { formatRelativeDate } from "../lib/format";
import type { ChatMessage, ConversationItem } from "../types/models";
import { ensureSession, refreshCounts, sessionState } from "../stores/session";

const route = useRoute();
const router = useRouter();
const loading = ref(true);
const sending = ref(false);
const errorMessage = ref("");
const composerText = ref("");
const conversation = ref<ConversationItem | null>(null);
const messages = ref<ChatMessage[]>([]);

const conversationId = computed(() => {
  const nextValue = Number(route.params.conversationId || 0);
  return Number.isFinite(nextValue) ? Math.max(0, nextValue) : 0;
});
const highlightedMessageId = computed(() => {
  const nextValue = Number(route.query.messageId || 0);
  return Number.isFinite(nextValue) ? Math.max(0, nextValue) : 0;
});
const prefillMessage = computed(() => String(route.query.prefill || "").trim());
const pageTitle = computed(() => conversation.value?.counterpartName || "Biseda");
const pageSubtitle = computed(() => {
  if (!conversation.value) {
    return "Detajet e bisedes";
  }

  const role = String(conversation.value.counterpartRole || "").trim() || "kontakt";
  return `${role} • ${conversation.value.counterpartTyping ? "po shkruan..." : "e lidhur me backend-in aktual"}`;
});

async function scrollToHighlightedMessage() {
  if (highlightedMessageId.value <= 0 || typeof document === "undefined") {
    return;
  }

  await nextTick();
  const target = document.getElementById(`message-${highlightedMessageId.value}`);
  target?.scrollIntoView({ block: "center", behavior: "smooth" });
}

async function loadConversation() {
  loading.value = true;
  errorMessage.value = "";

  try {
    await ensureSession();
    if (!sessionState.user || conversationId.value <= 0) {
      conversation.value = null;
      messages.value = [];
      return;
    }

    const detail = await fetchConversationDetail(conversationId.value);
    conversation.value = detail.conversation;
    messages.value = detail.messages;
    if (prefillMessage.value && !composerText.value.trim()) {
      composerText.value = prefillMessage.value;
    }
    await refreshCounts();
    await scrollToHighlightedMessage();
  } catch (error) {
    console.error(error);
    errorMessage.value = "Biseda nuk u hap dot.";
  } finally {
    loading.value = false;
  }
}

async function handleSendMessage() {
  if (!sessionState.user || conversationId.value <= 0 || sending.value) {
    return;
  }

  const body = composerText.value.trim();
  if (!body) {
    return;
  }

  sending.value = true;
  errorMessage.value = "";

  try {
    const result = await sendConversationMessage(conversationId.value, body);
    if (!result.ok) {
      errorMessage.value = resolveApiMessage(result.data, "Mesazhi nuk u dergua.");
      return;
    }

    composerText.value = "";
    await loadConversation();
  } finally {
    sending.value = false;
  }
}

function openAttachment(path: string) {
  const href = createApiUrl(path);
  if (typeof window === "undefined") {
    return;
  }
  window.open(href, "_blank", "noopener,noreferrer");
}

onMounted(() => {
  void loadConversation();
});

watch(
  () => [route.params.conversationId, route.query.messageId] as const,
  () => {
    if (prefillMessage.value && !composerText.value.trim()) {
      composerText.value = prefillMessage.value;
    }
    void loadConversation();
  },
);
</script>

<template>
  <IonPage>
    <IonContent :fullscreen="true">
      <div class="trego-mobile-screen">
        <div>
          <AppBackButton back-to="/messages" />
        </div>
        <section>
          <div>
            <div>
              <p>Mesazhet</p>
              <h1>{{ pageTitle }}</h1>
              <p>{{ pageSubtitle }}</p>
            </div>
          </div>
        </section>

        <EmptyStatePanel
          v-if="!sessionState.user"
          title="Kyçu per ta hapur biseden"
          copy="Pas login-it, app-i do te kthehet te kjo bisede."
        >
          <IonButton
           
           
            @click="router.push({ path: '/login', query: { redirect: route.fullPath } })"
          >
            Login
          </IonButton>
        </EmptyStatePanel>

        <section v-else-if="loading">
          <IonSpinner name="crescent" />
        </section>

        <EmptyStatePanel
          v-else-if="!conversation"
          title="Biseda nuk u gjet"
          copy="Mund te jete fshire ose nuk keni me qasje ne te."
        />

        <template v-else>
          <section>
            <article
              v-for="message in messages"
             
              :key="message.id"
             
             
            >
              <div>
                <strong>{{ message.senderName || (message.isOwn ? "Ti" : pageTitle) }}</strong>
                <small>{{ formatRelativeDate(message.createdAt) }}</small>
              </div>
              <p v-if="message.body">{{ message.body }}</p>
              <button
                v-if="message.attachmentPath"
                type="button"
               
                @click="openAttachment(message.attachmentPath)"
              >
                Hap bashkangjitjen
              </button>
            </article>
          </section>

          <section>
            <div>
              <p>Quick reply</p>
              <h2>Shkruaj nje mesazh</h2>
            </div>

            <IonTextarea
              v-model="composerText"
             
              auto-grow
              :rows="3"
              placeholder="Shkruaj mesazhin tend..."
            />

            <p v-if="errorMessage">{{ errorMessage }}</p>

            <IonButton :disabled="sending || !composerText.trim()" @click="handleSendMessage">
              <IonIcon slot="start" :icon="sendOutline" />
              {{ sending ? "Po dergohet..." : "Dergo mesazhin" }}
            </IonButton>
          </section>
        </template>
      </div>
    </IonContent>
  </IonPage>
</template>
