<script setup>
import { computed, nextTick, onBeforeUnmount, onMounted, reactive, ref, watch } from "vue";
import { RouterLink, useRoute, useRouter } from "vue-router";
import { fetchChatReplySuggestions, requestJson, resolveApiMessage } from "../lib/api";
import { getBusinessInitials } from "../lib/shop";
import { appState, ensureSessionLoaded, markRouteReady } from "../stores/app-state";

const route = useRoute();
const router = useRouter();
const messagesViewport = ref(null);
const composerInputElement = ref(null);
const conversations = ref([]);
const messages = ref([]);
const replySuggestions = ref([]);
const activeConversationId = ref(0);
const composer = reactive({
  body: "",
});
const ui = reactive({
  message: "",
  type: "",
  loadingConversations: false,
  loadingMessages: false,
  loadingSuggestions: false,
  sending: false,
});

let pollIntervalId = 0;

const isBusinessUser = computed(() => appState.user?.role === "business");
const currentConversation = computed(() =>
  conversations.value.find((conversation) => Number(conversation.id) === Number(activeConversationId.value)) || null,
);
const unreadCount = computed(() =>
  conversations.value.reduce((total, conversation) => total + Number(conversation.unreadCount || 0), 0),
);
const introCopy = computed(() =>
  isBusinessUser.value
    ? "Ketu i menaxhon mesazhet qe vijne nga klientet e interesuar per biznesin tend."
    : "Ketu i gjen bisedat me bizneset dhe mund te vazhdosh komunikimin pa dale nga platforma.",
);

function stopPolling() {
  if (pollIntervalId) {
    window.clearInterval(pollIntervalId);
    pollIntervalId = 0;
  }
}

function startPolling() {
  stopPolling();
  pollIntervalId = window.setInterval(() => {
    if (document.hidden) {
      return;
    }

    void loadConversations({ keepSelection: true, refreshMessages: true, silent: true });
  }, 10000);
}

function readQueryConversationId() {
  const nextId = Number(route.query.conversationId || 0);
  return Number.isFinite(nextId) && nextId > 0 ? nextId : 0;
}

function formatTimestamp(value) {
  const rawValue = String(value || "").trim();
  if (!rawValue) {
    return "";
  }

  const normalizedValue = rawValue.includes("T") ? rawValue : rawValue.replace(" ", "T");
  const parsedDate = new Date(normalizedValue);
  if (Number.isNaN(parsedDate.getTime())) {
    return rawValue;
  }

  const now = new Date();
  const sameDay =
    parsedDate.getDate() === now.getDate()
    && parsedDate.getMonth() === now.getMonth()
    && parsedDate.getFullYear() === now.getFullYear();

  return parsedDate.toLocaleString("sq-AL", sameDay
    ? { hour: "2-digit", minute: "2-digit" }
    : { day: "2-digit", month: "2-digit", hour: "2-digit", minute: "2-digit" });
}

function mergeConversation(nextConversation) {
  if (!nextConversation?.id) {
    return;
  }

  const existingIndex = conversations.value.findIndex(
    (conversation) => Number(conversation.id) === Number(nextConversation.id),
  );
  if (existingIndex >= 0) {
    conversations.value.splice(existingIndex, 1, {
      ...conversations.value[existingIndex],
      ...nextConversation,
    });
    return;
  }

  conversations.value = [nextConversation, ...conversations.value];
}

async function scrollMessagesToBottom() {
  await nextTick();
  const viewportElement = messagesViewport.value;
  if (!viewportElement) {
    return;
  }

  viewportElement.scrollTop = viewportElement.scrollHeight;
}

async function loadMessages(conversationId, options = {}) {
  const { scrollToBottom = false, silent = false } = options;
  if (!conversationId) {
    messages.value = [];
    replySuggestions.value = [];
    return;
  }

  if (!silent) {
    ui.loadingMessages = true;
  }

  try {
    const { response, data } = await requestJson(
      `/api/chat/messages?conversationId=${encodeURIComponent(conversationId)}`,
    );

    if (!response.ok || !data?.ok) {
      ui.message = resolveApiMessage(data, "Biseda nuk u hap.");
      ui.type = "error";
      return;
    }

    mergeConversation(data.conversation);
    messages.value = Array.isArray(data.messages) ? data.messages : [];

    if (scrollToBottom) {
      await scrollMessagesToBottom();
    }
  } catch (error) {
    console.error(error);
    if (!silent) {
      ui.message = "Mesazhet nuk u ngarkuan. Provoje perseri.";
      ui.type = "error";
    }
  } finally {
    if (!silent) {
      ui.loadingMessages = false;
    }
  }
}

async function loadConversations(options = {}) {
  const {
    keepSelection = true,
    refreshMessages = true,
    silent = false,
  } = options;

  if (!silent) {
    ui.loadingConversations = true;
  }

  try {
    const { response, data } = await requestJson("/api/chat/conversations");
    if (!response.ok || !data?.ok) {
      conversations.value = [];
      messages.value = [];
      activeConversationId.value = 0;
      ui.message = resolveApiMessage(data, "Bisedat nuk u ngarkuan.");
      ui.type = "error";
      return;
    }

    conversations.value = Array.isArray(data.conversations) ? data.conversations : [];
    const queryConversationId = readQueryConversationId();
    const hasSelectedConversation = (conversationId) =>
      conversations.value.some((conversation) => Number(conversation.id) === Number(conversationId));

    const nextConversationId = [queryConversationId, keepSelection ? activeConversationId.value : 0, conversations.value[0]?.id]
      .map((value) => Number(value || 0))
      .find((value) => value > 0 && hasSelectedConversation(value)) || 0;

    const selectionChanged = nextConversationId !== Number(activeConversationId.value || 0);
    activeConversationId.value = nextConversationId;

    if (!nextConversationId) {
      messages.value = [];
      replySuggestions.value = [];
      if (route.query.conversationId) {
        await router.replace({ path: "/mesazhet", query: {} });
      }
      return;
    }

    if (refreshMessages) {
      await loadMessages(nextConversationId, {
        scrollToBottom: selectionChanged,
        silent,
      });
    }
  } catch (error) {
    console.error(error);
    if (!silent) {
      ui.message = "Inbox-i nuk u ngarkua. Provoje perseri pas pak.";
      ui.type = "error";
    }
  } finally {
    if (!silent) {
      ui.loadingConversations = false;
    }
  }
}

async function openConversation(conversationId) {
  const normalizedConversationId = Number(conversationId || 0);
  if (!Number.isFinite(normalizedConversationId) || normalizedConversationId <= 0) {
    return;
  }

  activeConversationId.value = normalizedConversationId;
  replySuggestions.value = [];
  if (readQueryConversationId() !== normalizedConversationId) {
    await router.replace({
      path: "/mesazhet",
      query: { conversationId: String(normalizedConversationId) },
    });
  }

  await loadMessages(normalizedConversationId, { scrollToBottom: true });
  void loadConversations({ keepSelection: true, refreshMessages: false, silent: true });
}

async function loadReplySuggestions() {
  if (!currentConversation.value || ui.loadingSuggestions) {
    return;
  }

  ui.loadingSuggestions = true;
  try {
    const result = await fetchChatReplySuggestions(currentConversation.value.id);
    if (!result.ok) {
      ui.message = result.message;
      ui.type = "error";
      return;
    }

    replySuggestions.value = Array.isArray(result.suggestions) ? result.suggestions : [];
  } catch (error) {
    console.error(error);
    ui.message = "Sugjerimet AI nuk u pergatiten. Provoje perseri.";
    ui.type = "error";
  } finally {
    ui.loadingSuggestions = false;
  }
}

async function applyReplySuggestion(suggestion) {
  composer.body = String(suggestion || "").trim();
  await nextTick();
  composerInputElement.value?.focus?.();
}

async function sendMessage() {
  if (ui.sending || !currentConversation.value) {
    return;
  }

  const messageBody = String(composer.body || "").trim();
  if (!messageBody) {
    ui.message = "Shkruaje mesazhin para se ta dergosh.";
    ui.type = "error";
    return;
  }

  ui.sending = true;
  ui.message = "";
  ui.type = "";

  try {
    const { response, data } = await requestJson("/api/chat/messages", {
      method: "POST",
      body: JSON.stringify({
        conversationId: currentConversation.value.id,
        body: messageBody,
      }),
    });

    if (!response.ok || !data?.ok || !data.message) {
      ui.message = resolveApiMessage(data, "Mesazhi nuk u dergua.");
      ui.type = "error";
      return;
    }

    mergeConversation(data.conversation);
    messages.value = [...messages.value, data.message];
    replySuggestions.value = [];
    composer.body = "";
    ui.message = "Mesazhi u dergua.";
    ui.type = "success";
    await scrollMessagesToBottom();
    void loadConversations({ keepSelection: true, refreshMessages: false, silent: true });
  } catch (error) {
    console.error(error);
    ui.message = "Mesazhi nuk u dergua. Provoje perseri.";
    ui.type = "error";
  } finally {
    ui.sending = false;
  }
}

async function bootstrap() {
  try {
    const user = await ensureSessionLoaded();
    if (!user) {
      await router.replace("/login");
      return;
    }

    if (!["client", "business"].includes(String(user.role || "").trim())) {
      await router.replace(user.role === "admin" ? "/admin-products" : "/");
      return;
    }

    await loadConversations({ keepSelection: false, refreshMessages: true });
    startPolling();
  } finally {
    markRouteReady();
  }
}

watch(
  () => route.query.conversationId,
  async () => {
    const nextConversationId = readQueryConversationId();
    if (!nextConversationId) {
      if (!conversations.value.length) {
        activeConversationId.value = 0;
        messages.value = [];
        replySuggestions.value = [];
      }
      return;
    }

    if (
      nextConversationId !== Number(activeConversationId.value || 0)
      && conversations.value.some((conversation) => Number(conversation.id) === nextConversationId)
    ) {
      activeConversationId.value = nextConversationId;
      replySuggestions.value = [];
      await loadMessages(nextConversationId, { scrollToBottom: true, silent: true });
    }
  },
);

onMounted(async () => {
  await bootstrap();
});

onBeforeUnmount(() => {
  stopPolling();
});
</script>

<template>
  <section class="messages-page" aria-label="Mesazhet">
    <header class="account-header messages-page-header">
      <div>
        <p class="section-label">Mesazhet</p>
        <h1>{{ isBusinessUser ? "Inbox-i i biznesit" : "Bisedat e tua" }}</h1>
        <p class="section-text">
          {{ introCopy }}
        </p>
      </div>

      <div class="summary-chip messages-summary-chip">
        <span>Mesazhe te palexuara</span>
        <strong>{{ unreadCount }}</strong>
      </div>
    </header>

    <div class="form-message" :class="ui.type" role="status" aria-live="polite">
      {{ ui.message }}
    </div>

    <div class="messages-layout">
      <aside class="card messages-sidebar">
        <div class="messages-sidebar-head">
          <div>
            <p class="section-label">Bisedat</p>
            <h2>{{ conversations.length }}</h2>
          </div>
          <RouterLink
            v-if="isBusinessUser"
            class="nav-action nav-action-secondary messages-sidebar-action"
            to="/biznesi-juaj"
          >
            Paneli
          </RouterLink>
        </div>

        <div class="messages-conversation-list" aria-live="polite">
          <div v-if="ui.loadingConversations && !conversations.length" class="messages-empty-state">
            Duke ngarkuar bisedat...
          </div>

          <button
            v-for="conversation in conversations"
            :key="conversation.id"
            class="messages-conversation-card"
            :class="{ 'is-active': Number(conversation.id) === Number(activeConversationId) }"
            type="button"
            @click="openConversation(conversation.id)"
          >
            <span class="messages-conversation-avatar" aria-hidden="true">
              <img
                v-if="conversation.counterpartImagePath"
                class="messages-conversation-avatar-image"
                :src="conversation.counterpartImagePath"
                :alt="conversation.counterpartName"
                width="120"
                height="120"
                loading="lazy"
                decoding="async"
              >
              <span v-else class="messages-conversation-avatar-fallback">
                {{ getBusinessInitials(conversation.counterpartName) }}
              </span>
            </span>

            <span class="messages-conversation-copy">
              <strong>{{ conversation.counterpartName }}</strong>
              <span>{{ conversation.lastMessagePreview || "Nise biseden nga kjo dritare." }}</span>
            </span>

            <span class="messages-conversation-meta">
              <small>{{ formatTimestamp(conversation.lastMessageAt) }}</small>
              <span v-if="Number(conversation.unreadCount) > 0" class="messages-unread-badge">
                {{ conversation.unreadCount }}
              </span>
            </span>
          </button>

          <div v-if="!ui.loadingConversations && !conversations.length" class="messages-empty-state">
            {{
              isBusinessUser
                ? "Kur nje klient te te shkruaje, biseda do te shfaqet ketu."
                : "Kliko Message te profili i nje biznesi per ta nisur biseden."
            }}
          </div>
        </div>
      </aside>

      <section class="card messages-thread">
        <template v-if="currentConversation">
          <header class="messages-thread-head">
            <div class="messages-thread-head-copy">
              <span class="messages-conversation-avatar messages-thread-avatar" aria-hidden="true">
                <img
                  v-if="currentConversation.counterpartImagePath"
                  class="messages-conversation-avatar-image"
                  :src="currentConversation.counterpartImagePath"
                  :alt="currentConversation.counterpartName"
                  width="120"
                  height="120"
                  loading="lazy"
                  decoding="async"
                >
                <span v-else class="messages-conversation-avatar-fallback">
                  {{ getBusinessInitials(currentConversation.counterpartName) }}
                </span>
              </span>

              <div>
                <p class="section-label">
                  {{ isBusinessUser ? "Klienti" : "Biznesi" }}
                </p>
                <h2>{{ currentConversation.counterpartName }}</h2>
              </div>
            </div>

            <RouterLink
              v-if="currentConversation.profileUrl && !isBusinessUser"
              class="nav-action nav-action-secondary"
              :to="currentConversation.profileUrl"
            >
              Shiko profilin
            </RouterLink>
          </header>

          <div ref="messagesViewport" class="messages-thread-viewport">
            <div v-if="ui.loadingMessages && !messages.length" class="messages-empty-state messages-thread-empty">
              Duke hapur biseden...
            </div>

            <div v-else-if="!messages.length" class="messages-empty-state messages-thread-empty">
              Biseda eshte bosh. Shkruaje mesazhin e pare me poshte.
            </div>

            <article
              v-for="message in messages"
              :key="message.id"
              class="messages-bubble"
              :class="{ 'is-own': message.isOwn }"
            >
              <p>{{ message.body }}</p>
              <span>{{ message.isOwn ? "Ti" : message.senderName }} · {{ formatTimestamp(message.createdAt) }}</span>
            </article>
          </div>

          <form class="messages-compose" @submit.prevent="sendMessage">
            <div class="messages-ai-toolbar">
              <button
                class="nav-action nav-action-secondary messages-ai-button"
                type="button"
                :disabled="ui.loadingSuggestions"
                @click="loadReplySuggestions"
              >
                {{ ui.loadingSuggestions ? "Duke sugjeruar..." : "Sugjero me AI" }}
              </button>

              <div v-if="replySuggestions.length" class="messages-ai-suggestions" aria-live="polite">
                <button
                  v-for="suggestion in replySuggestions"
                  :key="suggestion"
                  class="messages-ai-chip"
                  type="button"
                  @click="applyReplySuggestion(suggestion)"
                >
                  {{ suggestion }}
                </button>
              </div>
            </div>

            <label class="sr-only" for="messages-compose-input">Shkruaje mesazhin</label>
            <textarea
              id="messages-compose-input"
              ref="composerInputElement"
              v-model="composer.body"
              class="messages-compose-input"
              rows="3"
              maxlength="1500"
              placeholder="Shkruaje mesazhin..."
            ></textarea>
            <button class="nav-action nav-action-primary messages-send-button" type="submit" :disabled="ui.sending">
              {{ ui.sending ? "Duke derguar..." : "Dergo" }}
            </button>
          </form>
        </template>

        <div v-else class="messages-empty-state messages-thread-empty">
          Zgjidh nje bisede nga lista ne te majte per t'i pare mesazhet.
        </div>
      </section>
    </div>
  </section>
</template>
