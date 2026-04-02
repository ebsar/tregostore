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
    <IonContent class="app-gradient" :fullscreen="true">
      <div class="mobile-page">
        <div class="page-back-anchor">
          <AppBackButton back-to="/messages" />
        </div>
        <section class="surface-card surface-card--strong section-card conversation-hero">
          <div class="conversation-hero-top">
            <div class="conversation-hero-copy">
              <p class="section-kicker">Mesazhet</p>
              <h1>{{ pageTitle }}</h1>
              <p class="section-copy">{{ pageSubtitle }}</p>
            </div>
          </div>
        </section>

        <EmptyStatePanel
          v-if="!sessionState.user"
          title="Kyçu per ta hapur biseden"
          copy="Pas login-it, app-i do te kthehet te kjo bisede."
        >
          <IonButton
            class="cta-button"
            style="margin-top: 14px;"
            @click="router.push({ path: '/login', query: { redirect: route.fullPath } })"
          >
            Login
          </IonButton>
        </EmptyStatePanel>

        <section v-else-if="loading" class="surface-card empty-panel">
          <IonSpinner name="crescent" />
        </section>

        <EmptyStatePanel
          v-else-if="!conversation"
          title="Biseda nuk u gjet"
          copy="Mund te jete fshire ose nuk keni me qasje ne te."
        />

        <template v-else>
          <section class="surface-card section-card conversation-thread">
            <article
              v-for="message in messages"
              :id="`message-${message.id}`"
              :key="message.id"
              class="message-bubble"
              :class="{
                'is-own': message.isOwn,
                'is-highlighted': highlightedMessageId > 0 && highlightedMessageId === message.id,
              }"
            >
              <div class="message-bubble-head">
                <strong>{{ message.senderName || (message.isOwn ? "Ti" : pageTitle) }}</strong>
                <small>{{ formatRelativeDate(message.createdAt) }}</small>
              </div>
              <p v-if="message.body" class="message-bubble-body">{{ message.body }}</p>
              <button
                v-if="message.attachmentPath"
                type="button"
                class="message-attachment"
                @click="openAttachment(message.attachmentPath)"
              >
                Hap bashkangjitjen
              </button>
            </article>
          </section>

          <section class="surface-card section-card stack-list">
            <div>
              <p class="section-kicker">Quick reply</p>
              <h2 style="margin:0; color: var(--trego-dark);">Shkruaj nje mesazh</h2>
            </div>

            <IonTextarea
              v-model="composerText"
              class="message-composer"
              auto-grow
              :rows="3"
              placeholder="Shkruaj mesazhin tend..."
            />

            <p v-if="errorMessage" class="section-copy conversation-error">{{ errorMessage }}</p>

            <IonButton class="cta-button" :disabled="sending || !composerText.trim()" @click="handleSendMessage">
              <IonIcon slot="start" :icon="sendOutline" />
              {{ sending ? "Po dergohet..." : "Dergo mesazhin" }}
            </IonButton>
          </section>
        </template>
      </div>
    </IonContent>
  </IonPage>
</template>

<style scoped>
.conversation-hero {
  padding: 16px 16px 14px;
}

.conversation-hero-top {
  display: flex;
  align-items: flex-start;
  gap: 0;
}

.conversation-hero-copy h1 {
  margin: 2px 0 0;
  color: var(--trego-dark);
  font-size: 1.14rem;
  line-height: 1.2;
}

.conversation-thread {
  display: flex;
  flex-direction: column;
  gap: 12px;
  padding: 16px;
}

.message-bubble {
  align-self: flex-start;
  width: min(100%, 88%);
  padding: 12px 14px;
  border-radius: 18px;
  background: var(--trego-interactive-bg);
  border: 1px solid var(--trego-input-border);
  box-shadow: 0 8px 18px rgba(15, 23, 42, 0.06);
}

.message-bubble.is-own {
  align-self: flex-end;
  background: color-mix(in srgb, var(--trego-accent) 14%, var(--trego-surface-strong) 86%);
}

.message-bubble.is-highlighted {
  border-color: var(--trego-selection-border);
  box-shadow: var(--trego-selection-shadow);
}

.message-bubble-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  margin-bottom: 6px;
}

.message-bubble-head strong {
  color: var(--trego-dark);
  font-size: 0.82rem;
}

.message-bubble-head small {
  color: var(--trego-muted);
  font-size: 0.72rem;
}

.message-bubble-body {
  margin: 0;
  color: var(--trego-dark);
  line-height: 1.55;
}

.message-attachment {
  margin-top: 8px;
  padding: 0;
  border: 0;
  background: transparent;
  color: var(--trego-accent);
  font-weight: 700;
}

.message-composer {
  border-radius: 18px;
  border: 1px solid var(--trego-input-border);
  background: var(--trego-input-bg);
  --padding-top: 12px;
  --padding-bottom: 12px;
  --padding-start: 14px;
  --padding-end: 14px;
}

.conversation-error {
  color: var(--ion-color-danger, #d14343);
}
</style>
