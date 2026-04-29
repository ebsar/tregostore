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
const attachmentInputElement = ref(null);
const conversationSearchInputElement = ref(null);
const mediaViewerStage = ref(null);
const conversations = ref([]);
const messages = ref([]);
const replySuggestions = ref([]);
const lastReplySuggestionDraft = ref("");
const activeConversationId = ref(0);
const conversationSearch = ref("");
const counterpartTyping = ref(false);
const pendingAttachment = ref(null);
const pendingAttachmentPreviewUrl = ref("");
const mediaRecorder = ref(null);
const mediaStream = ref(null);
const composerMenuOpen = ref(false);
const conversationSearchOpen = ref(false);
const attachmentAccept = ref("image/*,video/*,audio/*,.pdf,application/pdf");
const aiSuggestionsOpen = ref(false);
const editingMessageId = ref(0);
const bubbleMenuMessageId = ref(0);
const uploadProgress = ref(0);
const countdownNow = ref(Date.now());
const audioWaveforms = ref({});
const pendingDeleteMap = ref({});
const isMessagesMobile = ref(false);
const mobileMessagesPane = ref("list");
const mediaViewer = reactive({
  open: false,
  kind: "",
  src: "",
  title: "",
  scale: 1,
  offsetX: 0,
  offsetY: 0,
  dragStartX: 0,
  dragStartY: 0,
  isDragging: false,
  pinchDistance: 0,
  pinchStartScale: 1,
  swipeStartX: 0,
  swipeStartY: 0,
});
const composer = reactive({
  body: "",
});
const ui = reactive({
  message: "",
  type: "",
  guest: false,
  loadingConversations: false,
  loadingMessages: false,
  loadingSuggestions: false,
  sending: false,
  recordingAudio: false,
  dragOverComposer: false,
});
const messagePage = reactive({
  hasMore: false,
  nextBeforeId: 0,
  loadingOlder: false,
});

let pollIntervalId = 0;
let typingPollIntervalId = 0;
let typingHeartbeatTimeoutId = 0;
let countdownIntervalId = 0;
let optimisticMessageCounter = 0;

const isBusinessUser = computed(() => appState.user?.role === "business");
const isAdminUser = computed(() => appState.user?.role === "admin");
const canOpenSupportConversation = computed(() => {
  const role = String(appState.user?.role || "").trim();
  return role === "client" || role === "business";
});
const currentConversation = computed(() =>
  conversations.value.find((conversation) => Number(conversation.id) === Number(activeConversationId.value)) || null,
);
const showMessagesSidebar = computed(() => !isMessagesMobile.value || mobileMessagesPane.value === "list");
const showMessagesThread = computed(() => !isMessagesMobile.value || mobileMessagesPane.value === "thread");
const filteredConversations = computed(() => {
  const query = String(conversationSearch.value || "").trim().toLowerCase();
  if (!query) {
    return conversations.value;
  }

  return conversations.value.filter((conversation) => {
    const haystack = [
      conversation.counterpartName,
      conversation.lastMessagePreview,
      conversation.counterpartRole,
    ]
      .map((value) => String(value || "").toLowerCase())
      .join(" ");

    return haystack.includes(query);
  });
});
const threadItems = computed(() => {
  const items = [];
  let previousKey = "";

  for (const message of messages.value) {
    const rawValue = String(message.createdAt || "").trim();
    const normalizedValue = rawValue.includes("T") ? rawValue : rawValue.replace(" ", "T");
    const parsedDate = new Date(normalizedValue);
    let separatorLabel = "";
    let separatorKey = rawValue;

    if (!Number.isNaN(parsedDate.getTime())) {
      const now = new Date();
      const today = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
      const candidate = new Date(
        parsedDate.getFullYear(),
        parsedDate.getMonth(),
        parsedDate.getDate(),
      ).getTime();
      const diffDays = Math.round((today - candidate) / 86400000);

      if (diffDays === 0) {
        separatorLabel = "Today";
      } else if (diffDays === 1) {
        separatorLabel = "Yesterday";
      } else {
        separatorLabel = parsedDate.toLocaleDateString("sq-AL", {
          day: "2-digit",
          month: "long",
          year: "numeric",
        });
      }

      separatorKey = `${parsedDate.getFullYear()}-${parsedDate.getMonth()}-${parsedDate.getDate()}`;
    }

    if (separatorKey !== previousKey) {
      items.push({
        type: "separator",
        id: `separator-${separatorKey}`,
        label: separatorLabel || "Me heret",
      });
      previousKey = separatorKey;
    }

    items.push({
      type: "message",
      id: `message-${message.id}`,
      message,
    });
  }

  return items;
});
const unreadCount = computed(() =>
  conversations.value.reduce((total, conversation) => total + Number(conversation.unreadCount || 0), 0),
);
const composerCharacterCount = computed(() => String(composer.body || "").length);
const isEditingMessage = computed(() => Number(editingMessageId.value) > 0);
const pendingUploadLabel = computed(() => {
  if (!ui.sending || uploadProgress.value <= 0 || uploadProgress.value >= 100) {
    return "";
  }

  return `Po ngarkohet ${Math.round(uploadProgress.value)}%`;
});
const activePendingDelete = computed(() => {
  const entries = Object.values(pendingDeleteMap.value || {});
  if (!entries.length) {
    return null;
  }

  return entries
    .slice()
    .sort((first, second) => Number(first.expiresAt || 0) - Number(second.expiresAt || 0))[0];
});
const activePendingDeleteCountdown = computed(() => {
  if (!activePendingDelete.value) {
    return 0;
  }

  return Math.max(
    0,
    Math.ceil((Number(activePendingDelete.value.expiresAt || 0) - countdownNow.value) / 1000),
  );
});
const activePendingDeleteProgress = computed(() => {
  if (!activePendingDelete.value) {
    return 0;
  }

  const durationMs = Math.max(1, Number(activePendingDelete.value.durationMs || 5000));
  const remainingMs = Math.max(0, Number(activePendingDelete.value.expiresAt || 0) - countdownNow.value);
  return Math.max(0, Math.min(100, (remainingMs / durationMs) * 100));
});
const mediaViewerImageStyle = computed(() => ({
  transform: `translate3d(${mediaViewer.offsetX}px, ${mediaViewer.offsetY}px, 0) scale(${mediaViewer.scale})`,
}));
const introCopy = computed(() =>
  isAdminUser.value
    ? "Ketu i menaxhon bisedat e customer support me perdoruesit dhe bizneset."
    : isBusinessUser.value
      ? "Ketu i menaxhon mesazhet qe vijne nga klientet e interesuar per biznesin tend dhe bisedat me support."
      : "Ketu i gjen bisedat me bizneset dhe customer support, pa dale nga platforma.",
);

const pageTitle = computed(() => (
  isAdminUser.value
    ? "Inbox-i i support"
    : isBusinessUser.value
      ? "Inbox-i i biznesit"
      : "Bisedat e tua"
));

function formatPresenceLabel(conversation) {
  if (!conversation) {
    return "";
  }

  const rawValue = String(conversation.counterpartLastSeenAt || "").trim();
  if (!rawValue) {
    return "Offline";
  }

  const normalizedValue = rawValue.includes("T") ? rawValue : rawValue.replace(" ", "T");
  const parsedDate = new Date(normalizedValue);
  if (Number.isNaN(parsedDate.getTime())) {
    return "Offline";
  }

  const diffMs = Math.max(0, Date.now() - parsedDate.getTime());
  const diffSeconds = Math.max(1, Math.round(diffMs / 1000));
  const diffMinutes = Math.max(1, Math.round(diffMs / 60000));

  if (conversation.counterpartIsOnline && diffSeconds <= 75) {
    return "Active now";
  }

  if (conversation.counterpartIsOnline) {
    return `Online ${diffMinutes}m ago`;
  }

  if (diffSeconds <= 75) {
    return "Seen just now";
  }

  if (diffMinutes < 60) {
    return `Last seen ${diffMinutes} min ago`;
  }

  const diffHours = Math.round(diffMinutes / 60);
  if (diffHours < 24) {
    return `Last seen ${diffHours}h ago`;
  }

  const diffDays = Math.round(diffHours / 24);
  return `Last seen ${diffDays}d ago`;
}

const threadCounterpartLabel = computed(() => {
  const counterpartRole = String(currentConversation.value?.counterpartRole || "").trim();
  if (counterpartRole === "admin") {
    return "Customer Support";
  }

  if (counterpartRole === "business") {
    return "";
  }

  return "Klienti";
});
const threadStatusText = computed(() => {
  if (!currentConversation.value) {
    return "";
  }

  if (counterpartTyping.value) {
    return "typing...";
  }

  return formatPresenceLabel(currentConversation.value);
});

function stopPolling() {
  if (pollIntervalId) {
    window.clearInterval(pollIntervalId);
    pollIntervalId = 0;
  }
}

function stopTypingPolling() {
  if (typingPollIntervalId) {
    window.clearInterval(typingPollIntervalId);
    typingPollIntervalId = 0;
  }
}

function clearTypingHeartbeatTimeout() {
  if (typingHeartbeatTimeoutId) {
    window.clearTimeout(typingHeartbeatTimeoutId);
    typingHeartbeatTimeoutId = 0;
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

function startTypingPolling() {
  stopTypingPolling();
  typingPollIntervalId = window.setInterval(() => {
    if (document.hidden || !activeConversationId.value) {
      return;
    }

    void loadMessages(activeConversationId.value, { silent: true });
  }, 2500);
}

function readQueryConversationId() {
  const nextId = Number(route.query.conversationId || 0);
  return Number.isFinite(nextId) && nextId > 0 ? nextId : 0;
}

function updateMessagesViewportMode() {
  const nextIsMobile = window.matchMedia("(max-width: 980px)").matches;
  const wasMobile = isMessagesMobile.value;
  isMessagesMobile.value = nextIsMobile;

  if (!nextIsMobile) {
    mobileMessagesPane.value = "thread";
    return;
  }

  if (!wasMobile) {
    mobileMessagesPane.value = activeConversationId.value ? "thread" : "list";
  }
}

function showMobileConversationList() {
  if (!isMessagesMobile.value) {
    return;
  }

  closeBubbleMenu();
  closeComposerMenu();
  clearTypingHeartbeatTimeout();
  void sendTypingState(false);
  mobileMessagesPane.value = "list";
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

function conversationPreviewText(conversation) {
  if (!conversation) {
    return "Nise biseden nga kjo dritare.";
  }

  if (conversation.counterpartTyping) {
    return "typing...";
  }

  return conversation.lastMessagePreview || "Nise biseden nga kjo dritare.";
}

function revokePendingAttachmentPreview() {
  if (pendingAttachmentPreviewUrl.value) {
    URL.revokeObjectURL(pendingAttachmentPreviewUrl.value);
    pendingAttachmentPreviewUrl.value = "";
  }
}

function defaultWaveformBars(length = 24) {
  return Array.from({ length }, (_, index) => {
    const band = (index % 6) + 1;
    return 18 + band * 8;
  });
}

async function generateWaveformBarsFromUrl(sourceUrl) {
  const AudioContextClass = window.AudioContext || window.webkitAudioContext;
  if (!AudioContextClass || !sourceUrl) {
    return defaultWaveformBars();
  }

  try {
    const response = await fetch(sourceUrl);
    const audioBuffer = await response.arrayBuffer();
    const audioContext = new AudioContextClass();
    const decoded = await audioContext.decodeAudioData(audioBuffer.slice(0));
    const channelData = decoded.getChannelData(0);
    const samplesCount = 24;
    const blockSize = Math.max(1, Math.floor(channelData.length / samplesCount));
    const values = [];

    for (let index = 0; index < samplesCount; index += 1) {
      const start = index * blockSize;
      const end = Math.min(channelData.length, start + blockSize);
      let sum = 0;
      for (let cursor = start; cursor < end; cursor += 1) {
        sum += Math.abs(channelData[cursor] || 0);
      }
      const average = end > start ? sum / (end - start) : 0;
      values.push(Math.max(10, Math.min(100, Math.round(average * 180))));
    }

    await audioContext.close();
    return values.every((value) => value <= 10) ? defaultWaveformBars() : values;
  } catch (error) {
    console.error(error);
    return defaultWaveformBars();
  }
}

async function ensureAudioWaveform(cacheKey, sourceUrl) {
  const normalizedKey = String(cacheKey || "").trim();
  const normalizedUrl = String(sourceUrl || "").trim();
  if (!normalizedKey || !normalizedUrl || audioWaveforms.value[normalizedKey]) {
    return;
  }

  audioWaveforms.value = {
    ...audioWaveforms.value,
    [normalizedKey]: defaultWaveformBars(),
  };
  const waveform = await generateWaveformBarsFromUrl(normalizedUrl);
  audioWaveforms.value = {
    ...audioWaveforms.value,
    [normalizedKey]: waveform,
  };
}

function waveformBarsForMessage(message) {
  const key = `message-${Number(message?.id || 0)}`;
  return audioWaveforms.value[key] || defaultWaveformBars();
}

function pendingWaveformBars() {
  return audioWaveforms.value.pending || defaultWaveformBars();
}

function distanceBetweenTouches(touches) {
  if (!touches || touches.length < 2) {
    return 0;
  }

  const [firstTouch, secondTouch] = touches;
  const deltaX = Number(secondTouch.clientX || 0) - Number(firstTouch.clientX || 0);
  const deltaY = Number(secondTouch.clientY || 0) - Number(firstTouch.clientY || 0);
  return Math.hypot(deltaX, deltaY);
}

function clampMediaViewerScale(value) {
  return Math.max(1, Math.min(4, Number(value || 1)));
}

function resetMediaViewerTransform() {
  mediaViewer.scale = 1;
  mediaViewer.offsetX = 0;
  mediaViewer.offsetY = 0;
  mediaViewer.dragStartX = 0;
  mediaViewer.dragStartY = 0;
  mediaViewer.isDragging = false;
  mediaViewer.pinchDistance = 0;
  mediaViewer.pinchStartScale = 1;
}

function openMediaViewer(kind, sourceUrl, title = "") {
  mediaViewer.open = true;
  mediaViewer.kind = String(kind || "").trim();
  mediaViewer.src = String(sourceUrl || "").trim();
  mediaViewer.title = String(title || "").trim();
  resetMediaViewerTransform();
}

function shouldShowBusinessMessageLogo(message) {
  return Boolean(
    message
    && !message.isOwn
    && String(appState.user?.role || "").trim() === "client"
    && String(currentConversation.value?.counterpartRole || "").trim() === "business",
  );
}

function closeMediaViewer() {
  mediaViewer.open = false;
  mediaViewer.kind = "";
  mediaViewer.src = "";
  mediaViewer.title = "";
  resetMediaViewerTransform();
}

function handleMediaViewerWheel(event) {
  if (mediaViewer.kind !== "image") {
    return;
  }

  const direction = event.deltaY > 0 ? -0.18 : 0.18;
  mediaViewer.scale = clampMediaViewerScale(mediaViewer.scale + direction);
  if (mediaViewer.scale === 1) {
    mediaViewer.offsetX = 0;
    mediaViewer.offsetY = 0;
  }
}

function handleMediaViewerPointerDown(event) {
  if (mediaViewer.kind !== "image" || mediaViewer.scale <= 1) {
    return;
  }

  mediaViewer.isDragging = true;
  mediaViewer.dragStartX = Number(event.clientX || 0) - mediaViewer.offsetX;
  mediaViewer.dragStartY = Number(event.clientY || 0) - mediaViewer.offsetY;
}

function handleMediaViewerPointerMove(event) {
  if (!mediaViewer.isDragging || mediaViewer.kind !== "image") {
    return;
  }

  mediaViewer.offsetX = Number(event.clientX || 0) - mediaViewer.dragStartX;
  mediaViewer.offsetY = Number(event.clientY || 0) - mediaViewer.dragStartY;
}

function handleMediaViewerPointerUp() {
  mediaViewer.isDragging = false;
}

function handleMediaViewerTouchStart(event) {
  if (mediaViewer.kind !== "image") {
    return;
  }

  if (event.touches.length >= 2) {
    mediaViewer.isDragging = false;
    mediaViewer.pinchDistance = distanceBetweenTouches(event.touches);
    mediaViewer.pinchStartScale = mediaViewer.scale;
    return;
  }

  if (event.touches.length === 1 && mediaViewer.scale > 1) {
    mediaViewer.isDragging = true;
    mediaViewer.dragStartX = Number(event.touches[0].clientX || 0) - mediaViewer.offsetX;
    mediaViewer.dragStartY = Number(event.touches[0].clientY || 0) - mediaViewer.offsetY;
  }
}

function handleMediaViewerTouchMove(event) {
  if (mediaViewer.kind !== "image") {
    return;
  }

  if (event.touches.length >= 2 && mediaViewer.pinchDistance > 0) {
    const nextDistance = distanceBetweenTouches(event.touches);
    const ratio = nextDistance / mediaViewer.pinchDistance;
    mediaViewer.scale = clampMediaViewerScale(mediaViewer.pinchStartScale * ratio);
    return;
  }

  if (event.touches.length === 1 && mediaViewer.isDragging && mediaViewer.scale > 1) {
    mediaViewer.offsetX = Number(event.touches[0].clientX || 0) - mediaViewer.dragStartX;
    mediaViewer.offsetY = Number(event.touches[0].clientY || 0) - mediaViewer.dragStartY;
  }
}

function handleMediaViewerTouchEnd() {
  mediaViewer.isDragging = false;
  mediaViewer.pinchDistance = 0;
  mediaViewer.pinchStartScale = mediaViewer.scale;
  if (mediaViewer.scale <= 1) {
    mediaViewer.offsetX = 0;
    mediaViewer.offsetY = 0;
  }
}

function toggleMediaViewerZoom() {
  if (mediaViewer.kind !== "image") {
    return;
  }

  if (mediaViewer.scale > 1.05) {
    resetMediaViewerTransform();
    return;
  }

  mediaViewer.scale = 2.2;
}

function replaceMessageInThread(nextMessage) {
  if (!nextMessage?.id) {
    return;
  }

  messages.value = messages.value.map((message) => (
    Number(message.id) === Number(nextMessage.id)
      ? { ...message, ...nextMessage }
      : message
  ));
}

function appendMessageToThread(nextMessage) {
  if (!nextMessage?.id) {
    return;
  }

  const existingIndex = messages.value.findIndex(
    (message) => Number(message.id) === Number(nextMessage.id),
  );
  if (existingIndex >= 0) {
    messages.value.splice(existingIndex, 1, {
      ...messages.value[existingIndex],
      ...nextMessage,
    });
    return;
  }

  messages.value = [...messages.value, nextMessage];
}

function revokeOptimisticAttachment(message) {
  const attachmentPath = String(message?.attachmentPath || "").trim();
  if (message?.isPending && attachmentPath.startsWith("blob:")) {
    URL.revokeObjectURL(attachmentPath);
  }
}

function createOptimisticMessage({ body, attachmentFile, conversationId }) {
  optimisticMessageCounter -= 1;
  const senderName = [
    appState.user?.firstName,
    appState.user?.lastName,
  ]
    .filter(Boolean)
    .join(" ")
    || appState.user?.name
    || appState.user?.businessName
    || appState.user?.email
    || "Ti";

  return {
    id: optimisticMessageCounter,
    conversationId,
    senderName,
    body,
    createdAt: new Date().toISOString(),
    editedAt: "",
    deletedAt: "",
    readAt: "",
    isOwn: true,
    isPending: true,
    attachmentPath: attachmentFile ? URL.createObjectURL(attachmentFile) : "",
    attachmentContentType: attachmentFile?.type || "",
    attachmentFileName: attachmentFile?.name || "",
  };
}

function replaceOptimisticMessageInThread(optimisticMessage, savedMessage) {
  if (!optimisticMessage?.id || !savedMessage?.id) {
    return;
  }

  revokeOptimisticAttachment(optimisticMessage);
  const alreadyVisible = messages.value.some(
    (message) =>
      Number(message.id) === Number(savedMessage.id)
      && Number(message.id) !== Number(optimisticMessage.id),
  );

  if (alreadyVisible) {
    messages.value = messages.value.filter(
      (message) => Number(message.id) !== Number(optimisticMessage.id),
    );
    return;
  }

  messages.value = messages.value.map((message) => (
    Number(message.id) === Number(optimisticMessage.id)
      ? savedMessage
      : message
  ));
}

function removeOptimisticMessageFromThread(optimisticMessage) {
  if (!optimisticMessage?.id) {
    return;
  }

  revokeOptimisticAttachment(optimisticMessage);
  messages.value = messages.value.filter(
    (message) => Number(message.id) !== Number(optimisticMessage.id),
  );
}

function mergeMessagesWithPending(nextMessages, conversationId) {
  const pendingMessages = messages.value.filter(
    (message) =>
      message?.isPending
      && Number(message.conversationId || 0) === Number(conversationId || 0),
  );

  return pendingMessages.length ? [...nextMessages, ...pendingMessages] : nextMessages;
}

function mergeOlderMessages(nextMessages) {
  const existingIds = new Set(messages.value.map((message) => Number(message.id)));
  return [
    ...nextMessages.filter((message) => !existingIds.has(Number(message.id))),
    ...messages.value,
  ];
}

function isBubbleMenuOpen(messageId) {
  return Number(bubbleMenuMessageId.value || 0) === Number(messageId || 0);
}

function closeBubbleMenu() {
  bubbleMenuMessageId.value = 0;
}

function closeComposerMenu() {
  composerMenuOpen.value = false;
}

function closeConversationSearch() {
  conversationSearchOpen.value = false;
}

function handleGlobalClick() {
  closeBubbleMenu();
  closeComposerMenu();
  closeConversationSearch();
}

function toggleBubbleMenu(messageId) {
  const normalizedId = Number(messageId || 0);
  bubbleMenuMessageId.value = Number(bubbleMenuMessageId.value || 0) === normalizedId ? 0 : normalizedId;
}

function isMessagePendingDelete(messageId) {
  return Boolean(pendingDeleteMap.value[String(Number(messageId || 0))]);
}

function clearPendingDeleteEntry(messageId) {
  const normalizedKey = String(Number(messageId || 0));
  const existingEntry = pendingDeleteMap.value[normalizedKey];
  if (existingEntry?.timerId) {
    window.clearTimeout(existingEntry.timerId);
  }
  const nextMap = { ...pendingDeleteMap.value };
  delete nextMap[normalizedKey];
  pendingDeleteMap.value = nextMap;
}

async function finalizeDeleteMessage(messageId) {
  const normalizedKey = String(Number(messageId || 0));
  const existingEntry = pendingDeleteMap.value[normalizedKey];
  if (!existingEntry) {
    return;
  }

  try {
    const { response, data } = await requestJson("/api/chat/messages/delete", {
      method: "POST",
      body: JSON.stringify({
        messageId,
      }),
    });

    if (!response.ok || !data?.ok || !data.message) {
      ui.message = resolveApiMessage(data, "Mesazhi nuk u fshi.");
      ui.type = "error";
      return;
    }

    replaceMessageInThread(data.message);
    mergeConversation({
      ...currentConversation.value,
      lastMessagePreview: Number(currentConversation.value?.id) === Number(data.message.conversationId)
        ? "Mesazhi u fshi."
        : currentConversation.value?.lastMessagePreview,
    });
    if (Number(editingMessageId.value) === Number(messageId)) {
      cancelEditingMessage();
    }
    ui.message = "Mesazhi u fshi.";
    ui.type = "success";
  } catch (error) {
    console.error(error);
    ui.message = "Mesazhi nuk u fshi. Provoje perseri.";
    ui.type = "error";
  } finally {
    clearPendingDeleteEntry(messageId);
  }
}

function undoDeleteMessage(messageId) {
  clearPendingDeleteEntry(messageId);
  ui.message = "Fshirja u anulua.";
  ui.type = "success";
}

function clearPendingAttachment() {
  revokePendingAttachmentPreview();
  pendingAttachment.value = null;
  delete audioWaveforms.value.pending;
  if (attachmentInputElement.value) {
    attachmentInputElement.value.value = "";
  }
}

function canAttachDroppedFile(file) {
  const contentType = String(file?.type || "").trim().toLowerCase();
  return Boolean(
    contentType.startsWith("image/")
    || contentType.startsWith("video/")
    || contentType.startsWith("audio/")
    || contentType === "application/pdf"
    || String(file?.name || "").toLowerCase().endsWith(".pdf")
  );
}

function attachFileToComposer(file) {
  if (!file) {
    return;
  }

  if (!canAttachDroppedFile(file)) {
    ui.message = "Chat supporton vetem foto, video, audio dhe PDF.";
    ui.type = "error";
    return;
  }

  clearPendingAttachment();
  pendingAttachment.value = file;
  pendingAttachmentPreviewUrl.value = URL.createObjectURL(file);
  composerMenuOpen.value = false;
  ui.dragOverComposer = false;
  if (String(file.type || "").toLowerCase().startsWith("audio/")) {
    void ensureAudioWaveform("pending", pendingAttachmentPreviewUrl.value);
  }
}

function handleComposerDragOver(event) {
  event.preventDefault();
  ui.dragOverComposer = true;
}

function handleComposerDragLeave(event) {
  if (event.currentTarget?.contains?.(event.relatedTarget)) {
    return;
  }
  ui.dragOverComposer = false;
}

function handleComposerDrop(event) {
  event.preventDefault();
  ui.dragOverComposer = false;
  const droppedFile = event.dataTransfer?.files?.[0] || null;
  if (!droppedFile) {
    return;
  }
  attachFileToComposer(droppedFile);
}

function resizeComposerInput() {
  const inputElement = composerInputElement.value;
  if (!inputElement) {
    return;
  }

  inputElement.style.height = "0px";
  const nextHeight = Math.max(52, Math.min(inputElement.scrollHeight, 156));
  inputElement.style.height = `${nextHeight}px`;
}

function attachmentKind(message) {
  const contentType = String(message?.attachmentContentType || "").trim().toLowerCase();
  if (contentType.startsWith("image/")) {
    return "image";
  }
  if (contentType.startsWith("video/")) {
    return "video";
  }
  if (contentType.startsWith("audio/")) {
    return "audio";
  }
  return "";
}

function attachmentPreviewKind() {
  return attachmentKind({
    attachmentContentType: pendingAttachment.value?.type || "",
  });
}

function openAttachmentPicker(acceptValue = "image/*,video/*,audio/*,.pdf,application/pdf") {
  attachmentAccept.value = acceptValue;
  attachmentInputElement.value?.click?.();
}

function handleAttachmentSelection(event) {
  const nextFile = event?.target?.files?.[0] || null;
  if (!nextFile) {
    return;
  }
  attachFileToComposer(nextFile);
}

async function toggleAudioRecording() {
  if (ui.recordingAudio) {
    mediaRecorder.value?.stop?.();
    return;
  }

  try {
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    mediaStream.value = stream;
    const chunks = [];
    const recorder = new MediaRecorder(stream);
    mediaRecorder.value = recorder;
    ui.recordingAudio = true;

    recorder.addEventListener("dataavailable", (event) => {
      if (event.data?.size) {
        chunks.push(event.data);
      }
    });

    recorder.addEventListener("stop", () => {
      const audioType = chunks[0]?.type || recorder.mimeType || "audio/webm";
      const extension = audioType.includes("mp4") ? "m4a" : audioType.includes("ogg") ? "ogg" : "webm";
      const audioBlob = new Blob(chunks, { type: audioType });
      const audioFile = new File([audioBlob], `voice-message.${extension}`, { type: audioType });
      clearPendingAttachment();
      pendingAttachment.value = audioFile;
      pendingAttachmentPreviewUrl.value = URL.createObjectURL(audioFile);
      void ensureAudioWaveform("pending", pendingAttachmentPreviewUrl.value);
      ui.recordingAudio = false;
      recorder.stream.getTracks().forEach((track) => track.stop());
      mediaRecorder.value = null;
      mediaStream.value = null;
    });

    recorder.start();
  } catch (error) {
    console.error(error);
    ui.message = "Mikrofoni nuk u aktivizua.";
    ui.type = "error";
    ui.recordingAudio = false;
  }
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
  const { scrollToBottom = false, silent = false, beforeId = 0, prepend = false } = options;
  if (!conversationId) {
    messages.value = [];
    replySuggestions.value = [];
    counterpartTyping.value = false;
    messagePage.hasMore = false;
    messagePage.nextBeforeId = 0;
    return;
  }

  if (!silent) {
    ui.loadingMessages = true;
  }

  try {
    const params = new URLSearchParams({
      conversationId: String(conversationId),
      limit: "50",
    });
    if (beforeId) {
      params.set("beforeId", String(beforeId));
    }
    const previousScrollHeight = messagesViewport.value?.scrollHeight || 0;
    const { response, data } = await requestJson(
      `/api/chat/messages?${params.toString()}`,
    );

    if (!response.ok || !data?.ok) {
      ui.message = resolveApiMessage(data, "Biseda nuk u hap.");
      ui.type = "error";
      return;
    }

    mergeConversation(data.conversation);
    const nextMessages = Array.isArray(data.messages) ? data.messages : [];
    messages.value = prepend
      ? mergeOlderMessages(nextMessages)
      : mergeMessagesWithPending(nextMessages, conversationId);
    messagePage.hasMore = Boolean(data.messagePage?.hasMore);
    messagePage.nextBeforeId = Number(data.messagePage?.nextBeforeId || 0);
    counterpartTyping.value = Boolean(data.counterpartTyping);
    messages.value
      .filter((message) => attachmentKind(message) === "audio" && message.attachmentPath)
      .forEach((message) => {
        void ensureAudioWaveform(`message-${Number(message.id)}`, message.attachmentPath);
      });

    if (scrollToBottom) {
      await scrollMessagesToBottom();
    } else if (prepend && messagesViewport.value) {
      await nextTick();
      messagesViewport.value.scrollTop += Math.max(0, messagesViewport.value.scrollHeight - previousScrollHeight);
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

async function loadOlderMessages() {
  if (!activeConversationId.value || !messagePage.hasMore || messagePage.loadingOlder) {
    return;
  }

  messagePage.loadingOlder = true;
  try {
    await loadMessages(activeConversationId.value, {
      beforeId: messagePage.nextBeforeId,
      prepend: true,
      silent: true,
    });
  } finally {
    messagePage.loadingOlder = false;
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
    const shouldAutoSelectFirstConversation = !isMessagesMobile.value || queryConversationId > 0;

    const nextConversationId = [
      queryConversationId,
      keepSelection ? activeConversationId.value : 0,
      shouldAutoSelectFirstConversation ? conversations.value[0]?.id : 0,
    ]
      .map((value) => Number(value || 0))
      .find((value) => value > 0 && hasSelectedConversation(value)) || 0;

    const selectionChanged = nextConversationId !== Number(activeConversationId.value || 0);
    activeConversationId.value = nextConversationId;

    if (!nextConversationId) {
      messages.value = [];
      replySuggestions.value = [];
      if (isMessagesMobile.value) {
        mobileMessagesPane.value = "list";
      }
      if (route.query.conversationId) {
        await router.replace({ path: "/mesazhet", query: {} });
      }
      return;
    }

    if (isMessagesMobile.value && queryConversationId > 0) {
      mobileMessagesPane.value = "thread";
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

  clearTypingHeartbeatTimeout();
  void sendTypingState(false);
  closeBubbleMenu();
  cancelEditingMessage();
  clearPendingAttachment();
  composerMenuOpen.value = false;
  aiSuggestionsOpen.value = false;
  activeConversationId.value = normalizedConversationId;
  replySuggestions.value = [];
  counterpartTyping.value = false;
  if (isMessagesMobile.value) {
    mobileMessagesPane.value = "thread";
  } else if (readQueryConversationId() !== normalizedConversationId) {
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
    const draftText = String(composer.body || "").trim();
    const result = await fetchChatReplySuggestions(currentConversation.value.id, { draftText });
    if (!result.ok) {
      ui.message = result.message;
      ui.type = "error";
      return;
    }

    lastReplySuggestionDraft.value = draftText;
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
  aiSuggestionsOpen.value = false;
  await nextTick();
  resizeComposerInput();
  composerInputElement.value?.focus?.();
}

function formatReadReceipt(readAt) {
  const rawValue = String(readAt || "").trim();
  if (!rawValue) {
    return "";
  }

  const normalizedValue = rawValue.includes("T") ? rawValue : rawValue.replace(" ", "T");
  const parsedDate = new Date(normalizedValue);
  if (Number.isNaN(parsedDate.getTime())) {
    return "Seen";
  }

  const diffMs = Math.max(0, Date.now() - parsedDate.getTime());
  const diffSeconds = Math.max(1, Math.round(diffMs / 1000));
  const diffMinutes = Math.max(1, Math.round(diffMs / 60000));

  if (diffSeconds <= 75) {
    return "Seen just now";
  }

  if (diffMinutes < 60) {
    return `Seen ${diffMinutes} min ago`;
  }

  const diffHours = Math.max(1, Math.round(diffMinutes / 60));
  return `Seen ${diffHours}h ago`;
}

function formatDeliveredState(message) {
  if (!message?.isOwn) {
    return "";
  }

  if (message.isPending) {
    return "Sending...";
  }

  if (message.readAt) {
    const readReceipt = formatReadReceipt(message.readAt);
    if (String(currentConversation.value?.counterpartRole || "").trim() === "admin") {
      return readReceipt === "Seen just now"
        ? "Seen by Support"
        : `Seen by Support · ${readReceipt.replace(/^Seen\s*/i, "")}`.trim();
    }

    return readReceipt;
  }

  return "Delivered";
}

function messageEditedLabel(message) {
  if (!message?.editedAt || message?.deletedAt) {
    return "";
  }

  return "edited";
}

function startEditingMessage(message) {
  if (!message?.isOwn || message?.deletedAt || message?.isPending) {
    return;
  }

  editingMessageId.value = Number(message.id || 0);
  closeBubbleMenu();
  composer.body = String(message.body || "").trim();
  clearPendingAttachment();
  nextTick(() => {
    resizeComposerInput();
    composerInputElement.value?.focus?.();
  });
}

function cancelEditingMessage() {
  editingMessageId.value = 0;
  composer.body = "";
  nextTick(() => {
    resizeComposerInput();
  });
}

function sendRequestWithUploadProgress(url, { method = "POST", body, headers = {}, onUploadProgress } = {}) {
  return new Promise((resolve, reject) => {
    const xhr = new XMLHttpRequest();
    xhr.open(method, url, true);
    Object.entries(headers).forEach(([key, value]) => {
      if (value != null && value !== "") {
        xhr.setRequestHeader(key, value);
      }
    });
    xhr.responseType = "text";
    xhr.upload.onprogress = (event) => {
      if (!event.lengthComputable || typeof onUploadProgress !== "function") {
        return;
      }
      onUploadProgress((event.loaded / event.total) * 100);
    };
    xhr.onerror = () => reject(new Error("Request failed"));
    xhr.onload = () => {
      let data = {};
      try {
        data = xhr.responseText ? JSON.parse(xhr.responseText) : {};
      } catch (error) {
        console.error(error);
      }
      resolve({
        response: {
          ok: xhr.status >= 200 && xhr.status < 300,
          status: xhr.status,
          statusText: xhr.statusText,
        },
        data,
      });
    };
    xhr.send(body);
  });
}

async function sendTypingState(isTyping = true) {
  if (!currentConversation.value) {
    return;
  }

  try {
    await requestJson("/api/chat/typing", {
      method: "POST",
      body: JSON.stringify({
        conversationId: currentConversation.value.id,
        isTyping,
      }),
    });
  } catch (error) {
    console.error(error);
  }
}

function scheduleTypingHeartbeat() {
  clearTypingHeartbeatTimeout();

  if (!currentConversation.value) {
    return;
  }

  const hasBody = String(composer.body || "").trim().length > 0;
  if (!hasBody) {
    void sendTypingState(false);
    return;
  }

  void sendTypingState(true);
  typingHeartbeatTimeoutId = window.setTimeout(() => {
    scheduleTypingHeartbeat();
  }, 3000);
}

function handleComposerKeydown(event) {
  if (event.key !== "Enter" || event.shiftKey || event.isComposing) {
    return;
  }

  event.preventDefault();
  void sendMessage();
}

function handleComposerInput() {
  resizeComposerInput();
  scheduleTypingHeartbeat();
}

async function toggleAiSuggestions() {
  const draftText = String(composer.body || "").trim();
  const shouldRefreshSuggestions = lastReplySuggestionDraft.value !== draftText;
  aiSuggestionsOpen.value = true;
  if (!replySuggestions.value.length || shouldRefreshSuggestions) {
    await loadReplySuggestions();
  }
}

async function toggleConversationSearch() {
  conversationSearchOpen.value = !conversationSearchOpen.value;
  if (conversationSearchOpen.value) {
    await nextTick();
    conversationSearchInputElement.value?.focus?.();
    conversationSearchInputElement.value?.select?.();
  }
}

function toggleComposerMenu() {
  composerMenuOpen.value = !composerMenuOpen.value;
}

async function handleComposerMenuAction(action) {
  composerMenuOpen.value = false;

  if (action === "media") {
    openAttachmentPicker("image/*,video/*");
    return;
  }

  if (action === "pdf") {
    openAttachmentPicker(".pdf,application/pdf");
    return;
  }

  if (action === "audio") {
    await toggleAudioRecording();
  }
}

async function copyMessageBody(messageBody) {
  const normalizedBody = String(messageBody || "").trim();
  if (!normalizedBody) {
    return;
  }

  try {
    await navigator.clipboard.writeText(normalizedBody);
    closeBubbleMenu();
    ui.message = "Mesazhi u kopjua.";
    ui.type = "success";
  } catch (error) {
    console.error(error);
    ui.message = "Mesazhi nuk u kopjua.";
    ui.type = "error";
  }
}

async function refreshInbox() {
  await loadConversations({ keepSelection: true, refreshMessages: true });
}

async function sendMessage() {
  if (ui.sending || !currentConversation.value) {
    return;
  }

  const activeConversation = currentConversation.value;
  const conversationId = Number(activeConversation.id || 0);
  const messageBody = String(composer.body || "").trim();
  if (!messageBody && !pendingAttachment.value && !isEditingMessage.value) {
    ui.message = "Shkruaje mesazhin para se ta dergosh.";
    ui.type = "error";
    return;
  }

  ui.sending = true;
  closeBubbleMenu();
  uploadProgress.value = 0;
  ui.message = "";
  ui.type = "";
  const attachmentFile = pendingAttachment.value;
  let optimisticMessage = null;

  try {
    if (isEditingMessage.value) {
      const { response, data } = await requestJson("/api/chat/messages/update", {
        method: "POST",
        body: JSON.stringify({
          messageId: editingMessageId.value,
          body: messageBody,
        }),
      });

      if (!response.ok || !data?.ok || !data.message) {
        ui.message = resolveApiMessage(data, "Mesazhi nuk u perditesua.");
        ui.type = "error";
        return;
      }

      replaceMessageInThread(data.message);
    mergeConversation({
      ...currentConversation.value,
      lastMessagePreview: data.message.body,
    });
    cancelEditingMessage();
    aiSuggestionsOpen.value = false;
    ui.message = "Mesazhi u perditesua.";
    ui.type = "success";
    return;
    }

    optimisticMessage = createOptimisticMessage({
      body: messageBody,
      attachmentFile,
      conversationId,
    });
    messages.value = [...messages.value, optimisticMessage];
    mergeConversation({
      ...activeConversation,
      lastMessagePreview: messageBody || attachmentFile?.name || "Attachment",
    });
    if (attachmentKind(optimisticMessage) === "audio" && optimisticMessage.attachmentPath) {
      void ensureAudioWaveform(`message-${Number(optimisticMessage.id)}`, optimisticMessage.attachmentPath);
    }
    composer.body = "";
    if (attachmentFile) {
      clearPendingAttachment();
    }
    composerMenuOpen.value = false;
    aiSuggestionsOpen.value = false;
    await nextTick();
    resizeComposerInput();
    await scrollMessagesToBottom();
    void sendTypingState(false);

    const usesAttachment = Boolean(attachmentFile);
    const requestOptions = usesAttachment
      ? {
          method: "POST",
          body: (() => {
            const formData = new FormData();
            formData.append("conversationId", String(conversationId));
            formData.append("body", messageBody);
            formData.append("attachment", attachmentFile);
            return formData;
          })(),
        }
      : {
          method: "POST",
          body: JSON.stringify({
            conversationId,
            body: messageBody,
          }),
        };

    const { response, data } = usesAttachment
      ? await sendRequestWithUploadProgress("/api/chat/messages", {
          ...requestOptions,
          onUploadProgress(progressValue) {
            uploadProgress.value = progressValue;
          },
        })
      : await requestJson("/api/chat/messages", requestOptions);

    if (!response.ok || !data?.ok || !data.message) {
      removeOptimisticMessageFromThread(optimisticMessage);
      if (!String(composer.body || "").trim()) {
        composer.body = messageBody;
      }
      if (attachmentFile && !pendingAttachment.value) {
        pendingAttachment.value = attachmentFile;
        pendingAttachmentPreviewUrl.value = URL.createObjectURL(attachmentFile);
        if (attachmentInputElement.value) {
          attachmentInputElement.value.value = "";
        }
        if (String(attachmentFile.type || "").toLowerCase().startsWith("audio/")) {
          void ensureAudioWaveform("pending", pendingAttachmentPreviewUrl.value);
        }
      }
      await nextTick();
      resizeComposerInput();
      ui.message = resolveApiMessage(data, "Mesazhi nuk u dergua.");
      ui.type = "error";
      return;
    }

    mergeConversation(data.conversation);
    replaceOptimisticMessageInThread(optimisticMessage, data.message);
    if (attachmentKind(data.message) === "audio" && data.message.attachmentPath) {
      void ensureAudioWaveform(`message-${Number(data.message.id)}`, data.message.attachmentPath);
    }
    if (data.autoReplyMessage) {
      appendMessageToThread(data.autoReplyMessage);
      await nextTick();
      await scrollMessagesToBottom();
    }
    replySuggestions.value = [];
    counterpartTyping.value = false;
    ui.message = "Mesazhi u dergua.";
    ui.type = "success";
    void loadConversations({ keepSelection: true, refreshMessages: false, silent: true });
  } catch (error) {
    console.error(error);
    removeOptimisticMessageFromThread(optimisticMessage);
    if (!String(composer.body || "").trim()) {
      composer.body = messageBody;
    }
    if (attachmentFile && !pendingAttachment.value) {
      pendingAttachment.value = attachmentFile;
      pendingAttachmentPreviewUrl.value = URL.createObjectURL(attachmentFile);
      if (attachmentInputElement.value) {
        attachmentInputElement.value.value = "";
      }
      if (String(attachmentFile.type || "").toLowerCase().startsWith("audio/")) {
        void ensureAudioWaveform("pending", pendingAttachmentPreviewUrl.value);
      }
    }
    await nextTick();
    resizeComposerInput();
    ui.message = "Mesazhi nuk u dergua. Provoje perseri.";
    ui.type = "error";
  } finally {
    ui.sending = false;
    uploadProgress.value = 0;
  }
}

async function deleteMessage(message) {
  if (!message?.isOwn || Number(message.id || 0) <= 0) {
    return;
  }

  const messageId = Number(message.id || 0);
  if (isMessagePendingDelete(messageId)) {
    return;
  }

  closeBubbleMenu();
  const expiresAt = Date.now() + 5000;
  const timerId = window.setTimeout(() => {
    void finalizeDeleteMessage(messageId);
  }, 5000);

  pendingDeleteMap.value = {
    ...pendingDeleteMap.value,
    [String(messageId)]: {
      messageId,
      body: String(message.body || "").trim() || "Mesazhi",
      expiresAt,
      timerId,
    },
  };
  ui.message = "Mesazhi do te fshihet pas pak. Mund ta kthesh me Undo.";
  ui.type = "success";
}

async function openSupportConversation() {
  if (!canOpenSupportConversation.value || ui.loadingConversations) {
    return;
  }

  ui.message = "";
  ui.type = "";

  try {
    const { response, data } = await requestJson("/api/chat/open", {
      method: "POST",
      body: JSON.stringify({ target: "support" }),
    });

    if (!response.ok || !data?.ok || !data.conversation?.id) {
      ui.message = resolveApiMessage(data, "Biseda me support nuk u hap.");
      ui.type = "error";
      return;
    }

    mergeConversation(data.conversation);
    await openConversation(data.conversation.id);
  } catch (error) {
    console.error(error);
    ui.message = "Biseda me support nuk u hap. Provoje perseri.";
    ui.type = "error";
  }
}

async function bootstrap() {
  try {
    const user = await ensureSessionLoaded();
    if (!user) {
      ui.guest = true;
      ui.message = "Per te pare mesazhet duhet te kyçesh ose te krijosh llogari.";
      ui.type = "error";
      return;
    }

    ui.guest = false;

    if (!["client", "business", "admin"].includes(String(user.role || "").trim())) {
      await router.replace(user.role === "admin" ? "/admin-products" : "/");
      return;
    }

    await loadConversations({ keepSelection: false, refreshMessages: true });
    startPolling();
    startTypingPolling();
  } finally {
    markRouteReady();
  }
}

watch(
  () => route.query.conversationId,
  async () => {
    const nextConversationId = readQueryConversationId();
    if (!nextConversationId) {
      if (isMessagesMobile.value) {
        mobileMessagesPane.value = "list";
      }
      if (!conversations.value.length) {
        activeConversationId.value = 0;
        messages.value = [];
        replySuggestions.value = [];
        counterpartTyping.value = false;
      }
      return;
    }

    if (
      nextConversationId !== Number(activeConversationId.value || 0)
      && conversations.value.some((conversation) => Number(conversation.id) === nextConversationId)
    ) {
      cancelEditingMessage();
      clearPendingAttachment();
      composerMenuOpen.value = false;
      aiSuggestionsOpen.value = false;
      activeConversationId.value = nextConversationId;
      if (isMessagesMobile.value) {
        mobileMessagesPane.value = "thread";
      }
      replySuggestions.value = [];
      await loadMessages(nextConversationId, { scrollToBottom: true, silent: true });
    }
  },
);

watch(
  () => composer.body,
  () => {
    resizeComposerInput();
  },
);

onMounted(async () => {
  updateMessagesViewportMode();
  window.addEventListener("click", handleGlobalClick);
  window.addEventListener("resize", updateMessagesViewportMode);
  resizeComposerInput();
  await bootstrap();
});

onBeforeUnmount(() => {
  window.removeEventListener("click", handleGlobalClick);
  window.removeEventListener("resize", updateMessagesViewportMode);
  stopPolling();
  stopTypingPolling();
  clearTypingHeartbeatTimeout();
  Object.keys(pendingDeleteMap.value).forEach((messageId) => {
    clearPendingDeleteEntry(Number(messageId));
  });
  handleMediaViewerPointerUp();
  mediaRecorder.value?.stop?.();
  mediaStream.value?.getTracks?.().forEach((track) => track.stop());
  clearPendingAttachment();
  closeMediaViewer();
  void sendTypingState(false);
});
</script>

<template>
  <section class="market-page market-page--wide messages-page" aria-label="Mesazhet">
    <header class="messages-page__hero">
      <div>
        <p>Mesazhet</p>
      </div>

      <div>
        <span>Mesazhe te palexuara</span>
        <strong>{{ unreadCount }}</strong>
      </div>
    </header>

    <div
      v-if="ui.message"
      class="market-status"
      :class="{ 'market-status--error': ui.type === 'error' }"
      role="status"
      aria-live="polite"
    >
      {{ ui.message }}
    </div>

    <section v-if="ui.guest" class="market-empty messages-gate">
      <h2>Per te pare mesazhet duhet te kyçesh.</h2>
      <p>Krijo llogari ose hyni ne llogarine tende per te hapur bisedat me bizneset dhe support-in.</p>
      <div class="market-empty__actions">
        <RouterLink class="market-button market-button--primary" to="/login?redirect=%2Fmesazhet">
          Login
        </RouterLink>
        <RouterLink class="market-button market-button--secondary" to="/signup?redirect=%2Fmesazhet">
          Sign Up
        </RouterLink>
      </div>
    </section>

    <div
      v-else
      class="messages-layout"
      :class="{
        'messages-layout--mobile-list': isMessagesMobile && mobileMessagesPane === 'list',
        'messages-layout--mobile-thread': isMessagesMobile && mobileMessagesPane === 'thread',
      }"
    >
      <aside v-show="showMessagesSidebar" class="messages-sidebar">
        <div>
          <div>
            <p>Bisedat</p>
          </div>
          <div>
            <div @click.stop>
              <button
                class="messages-icon-button"
                type="button"
                :title="conversationSearchOpen ? 'Mbyll kerkimin' : 'Kerko ne biseda'"
                :aria-label="conversationSearchOpen ? 'Mbyll kerkimin' : 'Kerko ne biseda'"
                @click.stop="toggleConversationSearch"
              >
                <svg viewBox="0 0 24 24" aria-hidden="true">
                  <path
                    d="M11 19a8 8 0 1 1 0-16 8 8 0 0 1 0 16zm10 2-4.35-4.35"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                  />
                </svg>
                <span>Kerko ne biseda</span>
              </button>

              <div v-if="conversationSearchOpen">
                <label for="messages-conversation-search">Kerko ne biseda</label>
                <input
                 
                  ref="conversationSearchInputElement"
                  v-model="conversationSearch"
                 
                  type="search"
                  placeholder="Kerko ne biseda..."
                  autocomplete="off"
                  @click.stop
                >
              </div>
            </div>
            <button
              class="messages-icon-button"
              type="button"
              :disabled="ui.loadingConversations"
              @click="refreshInbox"
              :title="ui.loadingConversations ? 'Duke rifreskuar...' : 'Rifresko'"
              :aria-label="ui.loadingConversations ? 'Duke rifreskuar...' : 'Rifresko'"
            >
              <svg viewBox="0 0 24 24" aria-hidden="true">
                <path
                  d="M20 12a8 8 0 1 1-2.34-5.66M20 4v5h-5"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                />
              </svg>
              <span>{{ ui.loadingConversations ? "Duke rifreskuar..." : "Rifresko" }}</span>
            </button>
            <button
              v-if="canOpenSupportConversation"
              class="messages-icon-button"
              type="button"
              @click="openSupportConversation"
              title="Support"
              aria-label="Support"
            >
              <svg viewBox="0 0 24 24" aria-hidden="true">
                <path
                  d="M4 13a8 8 0 0 1 16 0v4a2 2 0 0 1-2 2h-2v-6h4M4 13v4a2 2 0 0 0 2 2h2v-6H4m8 6v1a2 2 0 0 1-2 2h-1"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                />
              </svg>
              <span>Support</span>
            </button>
            <RouterLink
              v-if="isBusinessUser"
              class="market-button market-button--secondary"
              to="/biznesi-juaj"
            >
              Paneli
            </RouterLink>
          </div>
        </div>

        <div aria-live="polite">
          <div v-if="ui.loadingConversations && !conversations.length">
            Duke ngarkuar bisedat...
          </div>

          <button
            v-for="conversation in filteredConversations"
            :key="conversation.id"
            class="messages-conversation"
            :class="{ 'is-active': Number(conversation.id) === Number(activeConversationId) }"
            type="button"
            @click="openConversation(conversation.id)"
          >
            <span class="messages-avatar" aria-hidden="true">
              <img
                v-if="conversation.counterpartImagePath"
               
                :src="conversation.counterpartImagePath"
                :alt="conversation.counterpartName"
                width="120"
                height="120"
                loading="lazy"
                decoding="async"
              >
              <span v-else>
                {{ getBusinessInitials(conversation.counterpartName) }}
              </span>
            </span>

            <span>
              <strong>
                <span
                 
                 
                  aria-hidden="true"
                ></span>
                <span>{{ conversation.counterpartName }}</span>
              </strong>
              <small>
                {{ formatPresenceLabel(conversation) }}
              </small>
              <span>
                {{ conversationPreviewText(conversation) }}
              </span>
            </span>

            <span>
              <small>{{ formatTimestamp(conversation.lastMessageAt) }}</small>
              <span v-if="Number(conversation.unreadCount) > 0">
                {{ conversation.unreadCount }}
              </span>
            </span>
          </button>

          <div v-if="!ui.loadingConversations && !conversations.length">
            {{
              isAdminUser
                ? "Kur nje perdorues ose biznes te hape bisede me support, do ta shohesh ketu."
                : isBusinessUser
                  ? "Kur nje klient te te shkruaje ose kur te hapesh support, biseda do te shfaqet ketu."
                  : "Kliko Message te profili i nje biznesi ose hap support per ta nisur biseden."
            }}
          </div>

          <div
            v-else-if="!ui.loadingConversations && conversations.length && !filteredConversations.length"
           
          >
            Nuk u gjet asnje bisede me kete kerkim.
          </div>
        </div>
      </aside>

      <section v-show="showMessagesThread" class="messages-thread">
        <template v-if="currentConversation">
          <header class="messages-thread__header">
            <div>
              <button
                v-if="isMessagesMobile"
                class="messages-thread__back"
                type="button"
                aria-label="Kthehu te bisedat"
                @click="showMobileConversationList"
              >
                <svg viewBox="0 0 24 24" aria-hidden="true">
                  <path d="M15 6 9 12l6 6"></path>
                </svg>
              </button>

              <span class="messages-avatar" aria-hidden="true">
                <img
                  v-if="currentConversation.counterpartImagePath"
                 
                  :src="currentConversation.counterpartImagePath"
                  :alt="currentConversation.counterpartName"
                  width="120"
                  height="120"
                  loading="lazy"
                  decoding="async"
                >
                <span v-else>
                  {{ getBusinessInitials(currentConversation.counterpartName) }}
                </span>
              </span>

              <div>
                <p v-if="threadCounterpartLabel">
                  {{ threadCounterpartLabel }}
                </p>
                <h2>
                  <span
                   
                   
                    aria-hidden="true"
                  ></span>
                  <RouterLink
                    v-if="currentConversation.profileUrl && currentConversation.counterpartRole === 'business'"
                    class="messages-thread__profile-link"
                    :to="currentConversation.profileUrl"
                  >
                    {{ currentConversation.counterpartName }}
                  </RouterLink>
                  <span v-else>{{ currentConversation.counterpartName }}</span>
                </h2>
                <p>
                  {{ threadStatusText }}
                </p>
              </div>
            </div>
          </header>

          <div ref="messagesViewport" class="messages-viewport">
            <div v-if="ui.loadingMessages && !messages.length">
              Duke hapur biseden...
            </div>

            <div v-else-if="!messages.length">
              Biseda eshte bosh. Shkruaje mesazhin e pare me poshte.
            </div>

            <button
              v-if="messages.length && messagePage.hasMore"
              class="messages-viewport__older-button"
              type="button"
              :disabled="messagePage.loadingOlder"
              @click="loadOlderMessages"
            >
              {{ messagePage.loadingOlder ? "Duke hapur..." : "Mesazhe me te vjetra" }}
            </button>

            <template v-for="item in threadItems" :key="item.id">
              <div v-if="item.type === 'separator'">
                <span>{{ item.label }}</span>
              </div>

              <article
                v-else
                class="message-bubble"
                :class="{
                  'message-bubble--own': item.message.isOwn,
                  'message-bubble--business-incoming': shouldShowBusinessMessageLogo(item.message),
                }"
              >
              <span
                v-if="shouldShowBusinessMessageLogo(item.message)"
                class="message-bubble__business-logo"
                aria-hidden="true"
              >
                <img
                  v-if="currentConversation.counterpartImagePath"
                  :src="currentConversation.counterpartImagePath"
                  :alt="currentConversation.counterpartName"
                  width="64"
                  height="64"
                  loading="lazy"
                  decoding="async"
                >
                <svg v-else viewBox="0 0 24 24" aria-hidden="true">
                  <path d="M4.5 21V8.5l7.5-4 7.5 4V21"></path>
                  <path d="M8 21v-6h8v6"></path>
                  <path d="M8 10.5h.01M12 10.5h.01M16 10.5h.01"></path>
                </svg>
              </span>
              <div class="message-bubble__actions">
                <div
                  v-if="item.message.isOwn && !item.message.deletedAt && !item.message.isPending"
                  class="message-bubble__action-menu"
                  @click.stop
                >
                  <button
                    class="message-bubble__actions-trigger"
                    type="button"
                    aria-label="Message actions"
                    @click.stop="toggleBubbleMenu(item.message.id)"
                  >
                    <span></span>
                    <span></span>
                    <span></span>
                  </button>

                  <div
                    v-if="isBubbleMenuOpen(item.message.id)"
                    class="message-bubble__action-list"
                  >
                    <button
                      type="button"
                      @click="copyMessageBody(item.message.body)"
                    >
                      Kopjo
                    </button>
                    <button
                      type="button"
                      @click="startEditingMessage(item.message)"
                    >
                      Ndrysho
                    </button>
                    <button
                      type="button"
                      @click="deleteMessage(item.message)"
                    >
                      Fshij
                    </button>
                  </div>
                </div>
              </div>
              <div
                v-if="item.message.attachmentPath"
               
               
              >
                <button
                  v-if="attachmentKind(item.message) === 'image'"
                 
                  type="button"
                  @click="openMediaViewer('image', item.message.attachmentPath, item.message.attachmentFileName || item.message.senderName)"
                >
                  <img
                   
                    :src="item.message.attachmentPath"
                    :alt="item.message.attachmentFileName || 'Attachment'"
                    loading="lazy"
                  >
                </button>
                <button
                  v-else-if="attachmentKind(item.message) === 'video'"
                 
                  type="button"
                  @click="openMediaViewer('video', item.message.attachmentPath, item.message.attachmentFileName || item.message.senderName)"
                >
                  <video
                   
                    :src="item.message.attachmentPath"
                    muted
                    playsinline
                    preload="metadata"
                  ></video>
                </button>
                <div
                  v-else-if="attachmentKind(item.message) === 'audio'"
                 
                >
                  <div aria-hidden="true">
                    <span
                      v-for="(barHeight, barIndex) in waveformBarsForMessage(item.message)"
                      :key="`${item.message.id}-${barIndex}`"
                     
                     
                    ></span>
                  </div>
                  <audio
                   
                    :src="item.message.attachmentPath"
                    controls
                    preload="metadata"
                  ></audio>
                </div>
                <a
                  v-else
                 
                  :href="item.message.attachmentPath"
                  target="_blank"
                  rel="noreferrer"
                >
                  {{ item.message.attachmentFileName || "Shkarko attachment" }}
                </a>
              </div>
              <p>{{ item.message.body }}</p>
              <span>
                {{ item.message.isOwn ? "Ti" : item.message.senderName }} · {{ formatTimestamp(item.message.createdAt) }}
                <template v-if="messageEditedLabel(item.message)">
                  · <span>{{ messageEditedLabel(item.message) }}</span>
                </template>
                <template v-if="item.message.isOwn">
                  · <span>{{ formatDeliveredState(item.message) }}</span>
                </template>
              </span>
              </article>
            </template>

            <div v-if="counterpartTyping" aria-live="polite">
              <span></span>
              <span></span>
              <span></span>
              <strong>{{ currentConversation.counterpartName }}</strong>
              <span>po shkruan...</span>
            </div>
          </div>

          <div v-if="activePendingDelete" role="status" aria-live="polite">
            <span>
              Mesazhi do te fshihet pas pak.
            </span>
            <button
             
              type="button"
              @click="undoDeleteMessage(activePendingDelete.messageId)"
            >
              Undo
            </button>
          </div>

          <form
            class="messages-composer"
            @submit.prevent="sendMessage"
            @click.stop
            @dragenter.prevent="handleComposerDragOver"
            @dragover.prevent="handleComposerDragOver"
            @dragleave="handleComposerDragLeave"
            @drop="handleComposerDrop"
          >
            <div v-if="isEditingMessage">
              <div>
                <strong>Po ndryshon mesazhin</strong>
                <p>Ndrysho tekstin dhe dergoje perseri.</p>
              </div>
              <button
               
                type="button"
                @click="cancelEditingMessage"
              >
                Anulo
              </button>
            </div>
            <div v-if="pendingAttachment">
              <div>
                <img
                  v-if="attachmentPreviewKind() === 'image'"
                 
                  :src="pendingAttachmentPreviewUrl"
                  :alt="pendingAttachment.name || 'Preview'"
                >
                <video
                  v-else-if="attachmentPreviewKind() === 'video'"
                 
                  :src="pendingAttachmentPreviewUrl"
                  controls
                  playsinline
                  preload="metadata"
                ></video>
                <audio
                  v-else-if="attachmentPreviewKind() === 'audio'"
                 
                  :src="pendingAttachmentPreviewUrl"
                  controls
                  preload="metadata"
                ></audio>
                <div
                  v-if="attachmentPreviewKind() === 'audio'"
                 
                  aria-hidden="true"
                >
                  <span
                    v-for="(barHeight, barIndex) in pendingWaveformBars()"
                    :key="`pending-${barIndex}`"
                   
                   
                  ></span>
                </div>
                <span v-else>
                  {{ pendingAttachment.name }}
                </span>
              </div>
              <button
               
                type="button"
                @click="clearPendingAttachment"
              >
                Largo
              </button>
            </div>

            <div>
              <div
                v-if="aiSuggestionsOpen && replySuggestions.length"
                class="messages-composer__suggestions"
                aria-live="polite"
              >
                <button
                  v-for="suggestion in replySuggestions"
                  :key="suggestion"
                  type="button"
                  @click="applyReplySuggestion(suggestion)"
                >
                  {{ suggestion }}
                </button>
              </div>

              <div class="messages-composer__row">
                <div class="messages-composer__field">
                  <textarea
                   
                    ref="composerInputElement"
                    v-model="composer.body"
                   
                    rows="1"
                    maxlength="1500"
                    placeholder="Shkruaje mesazhin..."
                    enterkeyhint="send"
                    @input="handleComposerInput"
                    @keydown="handleComposerKeydown"
                  ></textarea>

                  <button
                    class="messages-composer__attach-button"
                    type="button"
                    @click="toggleComposerMenu"
                  >
                    +
                  </button>

                  <div
                    v-if="composerMenuOpen"
                    class="messages-composer__menu"
                    role="menu"
                    aria-label="Attachment options"
                    @click.stop
                  >
                    <button
                      class="messages-composer__menu-item"
                      type="button"
                      @click="handleComposerMenuAction('media')"
                    >
                      Foto/Video
                    </button>
                    <button
                      class="messages-composer__menu-item"
                      type="button"
                      @click="handleComposerMenuAction('audio')"
                    >
                      {{ ui.recordingAudio ? "Ndalo audio" : "Audio" }}
                    </button>
                    <button
                      class="messages-composer__menu-item"
                      type="button"
                      @click="handleComposerMenuAction('pdf')"
                    >
                      PDF file
                    </button>
                  </div>
                </div>

                <button
                  class="messages-composer__ai-button"
                  type="button"
                  :disabled="ui.loadingSuggestions"
                  :title="ui.loadingSuggestions ? 'AI po sugjeron...' : 'Sugjero me AI'"
                  :aria-label="ui.loadingSuggestions ? 'AI po sugjeron...' : 'Sugjero me AI'"
                  @click="toggleAiSuggestions"
                >
                  <svg
                    viewBox="0 0 24 24"
                    aria-hidden="true"
                  >
                    <path
                      d="M12 3l1.6 4.4L18 9l-4.4 1.6L12 15l-1.6-4.4L6 9l4.4-1.6L12 3zM18.5 14l.9 2.6L22 17.5l-2.6.9-.9 2.6-.9-2.6-2.6-.9 2.6-.9.9-2.6z"
                      fill="currentColor"
                    />
                  </svg>
                  <span>{{ ui.loadingSuggestions ? "..." : "AI" }}</span>
                </button>
                <button
                  class="messages-composer__send-button"
                  type="submit"
                  :disabled="ui.sending"
                  :title="ui.sending ? (isEditingMessage ? 'Saving...' : 'Sending...') : (isEditingMessage ? 'Ruaj' : 'Dergo')"
                  :aria-label="ui.sending ? (isEditingMessage ? 'Saving...' : 'Sending...') : (isEditingMessage ? 'Ruaj' : 'Dergo')"
                >
                  <svg
                   
                    viewBox="0 0 24 24"
                    aria-hidden="true"
                  >
                    <path
                      d="M5 12.5L19 5l-4.5 14-2.7-5.1L5 12.5z"
                      fill="currentColor"
                    />
                  </svg>
                  <span>
                    {{ ui.sending ? (isEditingMessage ? "Saving..." : "Sending...") : (isEditingMessage ? "Ruaj" : "Dergo") }}
                  </span>
                </button>
              </div>
            </div>

            <div>
              <div>
                <div v-if="pendingUploadLabel">
                  <span>{{ pendingUploadLabel }}</span>
                  <span>
                    <span></span>
                  </span>
                </div>
              </div>
            </div>
          </form>
        </template>

        <div v-else>
          Zgjidh nje bisede nga lista ne te majte per t'i pare mesazhet.
        </div>
      </section>
    </div>

    <div
      v-if="mediaViewer.open"
     
      role="dialog"
      aria-modal="true"
      @click.self="closeMediaViewer"
    >
      <div></div>
      <div>
        <button
         
          type="button"
          @click="closeMediaViewer"
        >
          Mbyll
        </button>
        <div
          v-if="mediaViewer.kind === 'image'"
          ref="mediaViewerStage"
         
          @wheel.prevent="handleMediaViewerWheel"
          @pointerdown="handleMediaViewerPointerDown"
          @pointermove="handleMediaViewerPointerMove"
          @pointerup="handleMediaViewerPointerUp"
          @pointerleave="handleMediaViewerPointerUp"
          @touchstart="handleMediaViewerTouchStart"
          @touchmove.prevent="handleMediaViewerTouchMove"
          @touchend="handleMediaViewerTouchEnd"
          @dblclick="toggleMediaViewerZoom"
        >
          <img
           
            :src="mediaViewer.src"
            :alt="mediaViewer.title || 'Attachment preview'"
           
          >
        </div>
        <video
          v-else-if="mediaViewer.kind === 'video'"
         
          :src="mediaViewer.src"
          controls
          autoplay
          playsinline
        ></video>
      </div>
    </div>
  </section>
</template>

<style>
.messages-page {
  display: grid;
  gap: 12px;
  padding: 12px 16px 16px;
}

.messages-page__hero {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 12px 14px;
  border: 1px solid var(--dashboard-border);
  border-radius: var(--dashboard-radius);
  background: #ffffff;
}

.messages-page__hero p {
  margin: 0;
  color: var(--dashboard-accent);
  font-size: 12px;
  font-weight: 750;
  letter-spacing: 0.04em;
  text-transform: uppercase;
}

.messages-page__hero > div:last-child {
  display: grid;
  justify-items: end;
  gap: 4px;
}

.messages-page__hero span {
  color: var(--dashboard-muted);
  font-size: 12px;
  font-weight: 650;
}

.messages-page__hero strong {
  color: var(--dashboard-text);
  font-size: 22px;
  line-height: 1;
}

.messages-gate {
  background: #ffffff;
}

.messages-layout {
  min-height: 640px;
  display: grid;
  grid-template-columns: minmax(260px, 326px) minmax(0, 1fr);
  gap: 12px;
}

.messages-sidebar,
.messages-thread {
  min-width: 0;
  overflow: hidden;
  border: 1px solid var(--dashboard-border);
  border-radius: var(--dashboard-radius);
  background: #ffffff;
}

.messages-sidebar {
  display: grid;
  grid-template-rows: auto minmax(0, 1fr);
}

.messages-sidebar > div:first-child,
.messages-thread__header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  padding: 10px 12px;
  border-bottom: 1px solid var(--dashboard-border);
}

.messages-sidebar > div:first-child > div:first-child p {
  margin: 0;
  color: var(--dashboard-text);
  font-size: 16px;
  font-weight: 800;
}

.messages-sidebar > div:first-child > div:last-child {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 6px;
}

.messages-icon-button {
  width: 32px;
  min-width: 32px;
  min-height: 32px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  padding: 0;
  border: 1px solid var(--dashboard-border);
  border-radius: 10px;
  background: #ffffff;
  color: var(--dashboard-text);
  font-size: 12px;
  font-weight: 700;
  cursor: pointer;
}

.messages-icon-button span {
  position: absolute;
  width: 1px;
  height: 1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  white-space: nowrap;
}

.messages-icon-button svg {
  width: 15px;
  height: 15px;
}

.messages-sidebar .market-button,
.messages-thread__header .market-button {
  min-height: 32px;
  padding: 0 10px;
  border-radius: 10px;
  font-size: 12px;
}

.messages-sidebar > div:nth-child(2) {
  min-height: 0;
  overflow-y: auto;
  display: grid;
  align-content: start;
  gap: 4px;
  padding: 8px;
}

.messages-sidebar input[type="search"] {
  width: 100%;
  min-height: 34px;
  margin-top: 8px;
  padding: 8px 10px;
  border: 1px solid var(--dashboard-border);
  border-radius: 10px;
  background: #ffffff;
  color: var(--dashboard-text);
  font-size: 13px;
}

.messages-sidebar label {
  color: var(--dashboard-muted);
  font-size: 11px;
  font-weight: 700;
}

.messages-conversation {
  width: 100%;
  display: grid;
  grid-template-columns: auto minmax(0, 1fr) auto;
  gap: 9px;
  align-items: center;
  min-height: 58px;
  padding: 7px 8px;
  border: 1px solid transparent;
  border-radius: 10px;
  background: transparent;
  color: var(--dashboard-text);
  text-align: left;
  cursor: pointer;
}

.messages-conversation:hover,
.messages-conversation.is-active {
  border-color: var(--dashboard-accent-border);
  background: var(--dashboard-accent-soft);
}

.messages-avatar {
  width: 34px;
  height: 34px;
  overflow: hidden;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  border-radius: 11px;
  background: #111111;
  color: #ffffff;
  font-size: 12px;
  font-weight: 800;
}

.messages-avatar img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.messages-conversation strong,
.messages-thread__header h2 {
  min-width: 0;
  margin: 0;
  color: var(--dashboard-text);
  font-size: 13px;
  font-weight: 800;
}

.messages-conversation small,
.messages-conversation span span,
.messages-thread__header p,
.message-bubble > span {
  color: var(--dashboard-muted);
  font-size: 11px;
  line-height: 1.45;
}

.messages-conversation > span:nth-child(2) {
  min-width: 0;
  display: grid;
  gap: 1px;
}

.messages-conversation > span:nth-child(2) > span {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.messages-conversation > span:last-child {
  display: grid;
  justify-items: end;
  gap: 4px;
}

.messages-conversation > span:last-child > span {
  min-width: 20px;
  min-height: 20px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  border-radius: 999px;
  background: var(--dashboard-accent);
  color: #ffffff;
  font-size: 11px;
  font-weight: 800;
}

.messages-thread {
  display: grid;
  grid-template-rows: auto minmax(0, 1fr) auto auto;
}

.messages-thread__header {
  min-height: 48px;
  padding: 6px 10px;
}

.messages-thread__header > div:first-child {
  min-width: 0;
  display: flex;
  align-items: center;
  gap: 8px;
}

.messages-thread__header .messages-avatar {
  width: 30px;
  height: 30px;
  font-size: 11px;
}

.messages-thread__back {
  width: 30px;
  min-width: 30px;
  height: 30px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  border: 1px solid var(--dashboard-border);
  border-radius: 10px;
  background: #ffffff;
  color: var(--dashboard-text);
  cursor: pointer;
}

.messages-thread__back svg {
  width: 16px;
  height: 16px;
  fill: none;
  stroke: currentColor;
  stroke-width: 2;
  stroke-linecap: round;
  stroke-linejoin: round;
}

.messages-thread__header > div:first-child > div {
  min-width: 0;
  display: grid;
  gap: 1px;
}

.messages-thread__header h2 {
  display: flex;
  align-items: center;
  gap: 6px;
  line-height: 1.15;
}

.messages-thread__header p {
  margin: 0;
  line-height: 1.25;
}

.messages-thread__profile-link {
  min-width: 0;
  color: inherit;
  overflow: hidden;
  text-decoration: none;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.messages-thread__profile-link:hover {
  text-decoration: underline;
}

.messages-viewport {
  min-height: 0;
  overflow-y: auto;
  display: grid;
  align-content: start;
  gap: 8px;
  padding: 12px;
  background:
    linear-gradient(180deg, rgba(37, 99, 235, 0.03), transparent 180px),
    #fbfbfb;
}

.messages-viewport > div:first-child,
.messages-viewport > div:nth-child(2),
.messages-thread > div:last-child {
  color: var(--dashboard-muted);
  font-size: 13px;
}

.messages-viewport__older-button {
  justify-self: center;
  min-height: 32px;
  padding: 0 12px;
  border: 1px solid var(--dashboard-border);
  border-radius: 999px;
  background: #fff;
  color: var(--dashboard-muted);
  cursor: pointer;
  font-size: 12px;
  font-weight: 700;
}

.messages-viewport__older-button:disabled {
  cursor: wait;
  opacity: 0.65;
}

.message-bubble {
  position: relative;
  width: min(68%, 520px);
  display: grid;
  gap: 5px;
  justify-self: start;
  padding: 8px 10px;
  border: 1px solid var(--dashboard-border);
  border-radius: 12px;
  background: #ffffff;
  box-shadow: 0 6px 14px rgba(17, 17, 17, 0.035);
}

.message-bubble--own {
  justify-self: end;
  border-color: var(--dashboard-accent-border);
  background: var(--dashboard-accent-soft);
}

.message-bubble--business-incoming {
  margin-left: 38px;
}

.message-bubble__business-logo {
  position: absolute;
  left: -38px;
  bottom: 2px;
  width: 28px;
  height: 28px;
  overflow: hidden;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  border: 1px solid var(--dashboard-border);
  border-radius: 999px;
  background: #ffffff;
  color: var(--dashboard-muted);
  box-shadow: 0 6px 14px rgba(17, 17, 17, 0.08);
}

.message-bubble .message-bubble__business-logo img {
  width: 100%;
  height: 100%;
  border-radius: inherit;
  object-fit: cover;
}

.message-bubble__business-logo svg {
  width: 15px;
  height: 15px;
  fill: none;
  stroke: currentColor;
  stroke-width: 1.8;
  stroke-linecap: round;
  stroke-linejoin: round;
}

.message-bubble p {
  margin: 0;
  color: var(--dashboard-text);
  font-size: 13px;
  line-height: 1.45;
}

.message-bubble > div:first-child:empty {
  display: none;
}

.message-bubble button {
  min-height: 28px;
  border: 0;
  background: transparent;
  color: inherit;
}

.message-bubble__actions {
  position: absolute;
  top: 6px;
  right: 6px;
  z-index: 4;
  display: block;
  opacity: 0;
  pointer-events: none;
  transform: translateY(-2px);
  transition: opacity 140ms ease, transform 140ms ease;
}

.message-bubble:hover .message-bubble__actions,
.message-bubble:focus-within .message-bubble__actions {
  opacity: 1;
  pointer-events: auto;
  transform: translateY(0);
}

.message-bubble__action-menu {
  position: relative;
}

.message-bubble__actions-trigger {
  width: 30px;
  height: 30px;
  min-height: 30px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 3px;
  border: 1px solid rgba(17, 17, 17, 0.08);
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.92);
  box-shadow: 0 8px 18px rgba(17, 17, 17, 0.08);
  color: var(--dashboard-text);
  cursor: pointer;
}

.message-bubble__actions-trigger span {
  width: 3px;
  height: 3px;
  border-radius: 999px;
  background: currentColor;
}

.message-bubble__action-list {
  position: absolute;
  top: 36px;
  right: 0;
  min-width: 112px;
  display: grid;
  gap: 2px;
  padding: 5px;
  border: 1px solid var(--dashboard-border);
  border-radius: 10px;
  background: #ffffff;
  box-shadow: 0 12px 28px rgba(17, 17, 17, 0.14);
}

.message-bubble__action-list button {
  min-height: 30px;
  justify-content: flex-start;
  border-radius: 8px;
  padding: 0 10px;
  color: var(--dashboard-text);
  font-size: 12px;
  text-align: left;
  cursor: pointer;
}

.message-bubble__action-list button:hover {
  background: var(--dashboard-accent-soft);
}

.message-bubble > div:nth-child(2) button {
  padding: 0;
}

.message-bubble img,
.message-bubble video {
  max-width: 100%;
  max-height: 240px;
  border-radius: 10px;
  object-fit: cover;
}

.messages-composer {
  display: grid;
  gap: 8px;
  padding: 10px 12px;
  border-top: 1px solid var(--dashboard-border);
  background: #ffffff;
}

.messages-composer__suggestions {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}

.messages-composer__suggestions button {
  min-height: 30px;
  border-radius: 999px;
  background: #f7f7f7;
  font-size: 12px;
}

.messages-composer__row {
  display: grid;
  grid-template-columns: minmax(0, 1fr) 52px 52px;
  gap: 6px;
  align-items: stretch;
}

.messages-composer__field {
  position: relative;
  min-width: 0;
  min-height: 52px;
  overflow: visible;
}

.messages-composer textarea {
  width: 100%;
  min-height: 52px;
  max-height: 120px;
  resize: vertical;
  border: 1px solid var(--dashboard-border);
  border-radius: 10px;
  padding: 14px 52px 14px 12px;
  font-size: 13px;
  line-height: 1.35;
}

.messages-composer button {
  min-height: 34px;
  padding: 0 10px;
  border: 1px solid var(--dashboard-border);
  border-radius: 10px;
  background: #ffffff;
  color: var(--dashboard-text);
  font-size: 12px;
  font-weight: 700;
  cursor: pointer;
}

.messages-composer button[type="submit"] {
  border-color: #111111;
  background: #111111;
  color: #ffffff;
}

.messages-composer__attach-button {
  position: absolute;
  right: 8px;
  bottom: 8px;
  width: 36px;
  min-width: 36px;
  min-height: 36px;
  padding: 0;
  border-radius: 10px;
  z-index: 2;
}

.messages-composer__menu {
  position: absolute;
  right: 0;
  bottom: calc(100% + 10px);
  z-index: 12;
  min-width: 148px;
  display: grid;
  gap: 4px;
  padding: 6px;
  border: 1px solid var(--dashboard-border);
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.98);
  box-shadow: 0 16px 32px rgba(17, 17, 17, 0.14);
}

.messages-composer__menu-item {
  width: 100%;
  min-height: 38px;
  justify-content: flex-start;
  padding: 0 12px;
  border-radius: 10px;
  text-align: left;
}

.messages-composer__menu-item:hover {
  background: var(--dashboard-accent-soft);
}

.messages-composer__ai-button,
.messages-composer__send-button {
  width: 52px;
  min-width: 52px;
  min-height: 52px;
  height: 52px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  padding: 0;
  align-self: stretch;
}

.messages-composer__ai-button svg,
.messages-composer__send-button svg {
  width: 16px;
  height: 16px;
}

.messages-composer__send-button span,
.messages-composer__ai-button span {
  position: absolute;
  width: 1px;
  height: 1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  white-space: nowrap;
}

.messages-composer button:disabled {
  cursor: not-allowed;
  opacity: 0.62;
}

@media (max-width: 980px) {
  .messages-layout {
    min-height: calc(100svh - 160px);
    grid-template-columns: 1fr;
  }

  .messages-layout--mobile-list .messages-sidebar,
  .messages-layout--mobile-thread .messages-thread {
    display: grid;
  }

  .messages-layout--mobile-list .messages-thread,
  .messages-layout--mobile-thread .messages-sidebar {
    display: none;
  }

  .messages-sidebar,
  .messages-thread {
    min-height: calc(100svh - 160px);
  }
}

@media (max-width: 640px) {
  .messages-page {
    padding: 10px;
  }

  .messages-page__hero,
  .messages-sidebar > div:first-child {
    align-items: stretch;
    flex-direction: column;
  }

  .message-bubble {
    width: 100%;
  }

  .message-bubble--business-incoming {
    width: calc(100% - 38px);
  }
}
</style>
