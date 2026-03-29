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
  loadingConversations: false,
  loadingMessages: false,
  loadingSuggestions: false,
  sending: false,
  recordingAudio: false,
  dragOverComposer: false,
});

let pollIntervalId = 0;
let typingPollIntervalId = 0;
let typingHeartbeatTimeoutId = 0;
let countdownIntervalId = 0;

const isBusinessUser = computed(() => appState.user?.role === "business");
const isAdminUser = computed(() => appState.user?.role === "admin");
const canOpenSupportConversation = computed(() => {
  const role = String(appState.user?.role || "").trim();
  return role === "client" || role === "business";
});
const currentConversation = computed(() =>
  conversations.value.find((conversation) => Number(conversation.id) === Number(activeConversationId.value)) || null,
);
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
    return "Biznesi";
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
  document.body.classList.add("dialog-open");
}

function closeMediaViewer() {
  mediaViewer.open = false;
  mediaViewer.kind = "";
  mediaViewer.src = "";
  mediaViewer.title = "";
  resetMediaViewerTransform();
  document.body.classList.remove("dialog-open");
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
  const { scrollToBottom = false, silent = false } = options;
  if (!conversationId) {
    messages.value = [];
    replySuggestions.value = [];
    counterpartTyping.value = false;
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
    counterpartTyping.value = Boolean(data.counterpartTyping);
    messages.value
      .filter((message) => attachmentKind(message) === "audio" && message.attachmentPath)
      .forEach((message) => {
        void ensureAudioWaveform(`message-${Number(message.id)}`, message.attachmentPath);
      });

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
  if (!message?.isOwn || message?.deletedAt) {
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
  aiSuggestionsOpen.value = !aiSuggestionsOpen.value;
  if (aiSuggestionsOpen.value && !replySuggestions.value.length) {
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

    const usesAttachment = Boolean(pendingAttachment.value);
    const requestOptions = usesAttachment
      ? {
          method: "POST",
          body: (() => {
            const formData = new FormData();
            formData.append("conversationId", String(currentConversation.value.id));
            formData.append("body", messageBody);
            formData.append("attachment", pendingAttachment.value);
            return formData;
          })(),
        }
      : {
          method: "POST",
          body: JSON.stringify({
            conversationId: currentConversation.value.id,
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
      ui.message = resolveApiMessage(data, "Mesazhi nuk u dergua.");
      ui.type = "error";
      return;
    }

    mergeConversation(data.conversation);
    messages.value = [...messages.value, data.message];
    if (attachmentKind(data.message) === "audio" && data.message.attachmentPath) {
      void ensureAudioWaveform(`message-${Number(data.message.id)}`, data.message.attachmentPath);
    }
    replySuggestions.value = [];
    composer.body = "";
    counterpartTyping.value = false;
    clearPendingAttachment();
    composerMenuOpen.value = false;
    aiSuggestionsOpen.value = false;
    await nextTick();
    resizeComposerInput();
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
      await router.replace("/login");
      return;
    }

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
  window.addEventListener("click", handleGlobalClick);
  resizeComposerInput();
  await bootstrap();
});

onBeforeUnmount(() => {
  window.removeEventListener("click", handleGlobalClick);
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
  <section class="messages-page" aria-label="Mesazhet">
    <header class="account-header messages-page-header">
      <div>
        <p class="section-label">Mesazhet</p>
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
        <div class="messages-sidebar-head" :class="{ 'is-search-open': conversationSearchOpen }">
          <div class="messages-sidebar-head-copy">
            <p class="section-label">Bisedat</p>
          </div>
          <div class="messages-sidebar-actions">
            <div class="messages-sidebar-search" @click.stop>
              <button
                class="nav-action nav-action-secondary messages-sidebar-action messages-sidebar-action-icon"
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
                <span class="sr-only">Kerko ne biseda</span>
              </button>

              <div v-if="conversationSearchOpen" class="messages-sidebar-search-dropdown">
                <label class="sr-only" for="messages-conversation-search">Kerko ne biseda</label>
                <input
                  id="messages-conversation-search"
                  ref="conversationSearchInputElement"
                  v-model="conversationSearch"
                  class="messages-conversation-search"
                  type="search"
                  placeholder="Kerko ne biseda..."
                  autocomplete="off"
                  @click.stop
                >
              </div>
            </div>
            <button
              class="nav-action nav-action-secondary messages-sidebar-action messages-sidebar-action-icon"
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
              <span class="sr-only">{{ ui.loadingConversations ? "Duke rifreskuar..." : "Rifresko" }}</span>
            </button>
            <button
              v-if="canOpenSupportConversation"
              class="nav-action nav-action-secondary messages-sidebar-action messages-sidebar-action-icon"
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
              <span class="sr-only">Support</span>
            </button>
            <RouterLink
              v-if="isBusinessUser"
              class="nav-action nav-action-secondary messages-sidebar-action"
              to="/biznesi-juaj"
            >
              Paneli
            </RouterLink>
          </div>
        </div>

        <div class="messages-conversation-list" aria-live="polite">
          <div v-if="ui.loadingConversations && !conversations.length" class="messages-empty-state">
            Duke ngarkuar bisedat...
          </div>

          <button
            v-for="conversation in filteredConversations"
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
              <strong class="messages-conversation-name-row">
                <span
                  class="messages-presence-dot"
                  :class="{ 'is-online': conversation.counterpartIsOnline }"
                  aria-hidden="true"
                ></span>
                <span>{{ conversation.counterpartName }}</span>
              </strong>
              <small class="messages-conversation-presence">
                {{ formatPresenceLabel(conversation) }}
              </small>
              <span :class="{ 'is-typing': conversation.counterpartTyping }">
                {{ conversationPreviewText(conversation) }}
              </span>
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
              isAdminUser
                ? "Kur nje perdorues ose biznes te hape bisede me support, do ta shohesh ketu."
                : isBusinessUser
                  ? "Kur nje klient te te shkruaje ose kur te hapesh support, biseda do te shfaqet ketu."
                  : "Kliko Message te profili i nje biznesi ose hap support per ta nisur biseden."
            }}
          </div>

          <div
            v-else-if="!ui.loadingConversations && conversations.length && !filteredConversations.length"
            class="messages-empty-state"
          >
            Nuk u gjet asnje bisede me kete kerkim.
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
                  {{ threadCounterpartLabel }}
                </p>
                <h2 class="messages-thread-name-row">
                  <span
                    class="messages-presence-dot"
                    :class="{ 'is-online': currentConversation.counterpartIsOnline }"
                    aria-hidden="true"
                  ></span>
                  <span>{{ currentConversation.counterpartName }}</span>
                </h2>
                <p class="messages-thread-status">
                  {{ threadStatusText }}
                </p>
              </div>
            </div>

            <RouterLink
              v-if="currentConversation.profileUrl && currentConversation.counterpartRole === 'business'"
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

            <template v-for="item in threadItems" :key="item.id">
              <div v-if="item.type === 'separator'" class="messages-date-separator">
                <span>{{ item.label }}</span>
              </div>

              <article
                v-else
                class="messages-bubble"
                :class="{
                  'is-own': item.message.isOwn,
                  'is-deleted': Boolean(item.message.deletedAt),
                  'is-pending-delete': isMessagePendingDelete(item.message.id),
                }"
              >
              <div class="messages-bubble-actions">
                <div
                  v-if="item.message.isOwn && !item.message.deletedAt"
                  class="messages-bubble-menu"
                  @click.stop
                >
                  <button
                    class="messages-bubble-menu-trigger"
                    type="button"
                    @click.stop="toggleBubbleMenu(item.message.id)"
                  >
                    <span></span>
                    <span></span>
                    <span></span>
                  </button>

                  <div
                    v-if="isBubbleMenuOpen(item.message.id)"
                    class="messages-bubble-menu-dropdown"
                  >
                    <button
                      class="messages-bubble-menu-item"
                      type="button"
                      @click="copyMessageBody(item.message.body)"
                    >
                      Kopjo
                    </button>
                    <button
                      class="messages-bubble-menu-item"
                      type="button"
                      @click="startEditingMessage(item.message)"
                    >
                      Ndrysho
                    </button>
                    <button
                      class="messages-bubble-menu-item is-danger"
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
                class="messages-attachment"
                :class="`is-${attachmentKind(item.message) || 'file'}`"
              >
                <button
                  v-if="attachmentKind(item.message) === 'image'"
                  class="messages-attachment-trigger"
                  type="button"
                  @click="openMediaViewer('image', item.message.attachmentPath, item.message.attachmentFileName || item.message.senderName)"
                >
                  <img
                    class="messages-attachment-image"
                    :src="item.message.attachmentPath"
                    :alt="item.message.attachmentFileName || 'Attachment'"
                    loading="lazy"
                  >
                </button>
                <button
                  v-else-if="attachmentKind(item.message) === 'video'"
                  class="messages-attachment-trigger"
                  type="button"
                  @click="openMediaViewer('video', item.message.attachmentPath, item.message.attachmentFileName || item.message.senderName)"
                >
                  <video
                    class="messages-attachment-video"
                    :src="item.message.attachmentPath"
                    muted
                    playsinline
                    preload="metadata"
                  ></video>
                </button>
                <div
                  v-else-if="attachmentKind(item.message) === 'audio'"
                  class="messages-audio-card"
                >
                  <div class="messages-audio-waveform" aria-hidden="true">
                    <span
                      v-for="(barHeight, barIndex) in waveformBarsForMessage(item.message)"
                      :key="`${item.message.id}-${barIndex}`"
                      class="messages-audio-wave"
                      :style="{ height: `${barHeight}%` }"
                    ></span>
                  </div>
                  <audio
                    class="messages-attachment-audio"
                    :src="item.message.attachmentPath"
                    controls
                    preload="metadata"
                  ></audio>
                </div>
                <a
                  v-else
                  class="messages-attachment-file"
                  :href="item.message.attachmentPath"
                  target="_blank"
                  rel="noreferrer"
                >
                  {{ item.message.attachmentFileName || "Shkarko attachment" }}
                </a>
              </div>
              <p>{{ item.message.body }}</p>
              <span class="messages-bubble-meta">
                {{ item.message.isOwn ? "Ti" : item.message.senderName }} · {{ formatTimestamp(item.message.createdAt) }}
                <template v-if="messageEditedLabel(item.message)">
                  · <span class="messages-message-meta-note">{{ messageEditedLabel(item.message) }}</span>
                </template>
                <template v-if="item.message.isOwn">
                  · <span class="messages-delivery-state">{{ formatDeliveredState(item.message) }}</span>
                </template>
              </span>
              </article>
            </template>

            <div v-if="counterpartTyping" class="messages-typing-indicator" aria-live="polite">
              <span class="messages-typing-dot"></span>
              <span class="messages-typing-dot"></span>
              <span class="messages-typing-dot"></span>
              <strong>{{ currentConversation.counterpartName }}</strong>
              <span>po shkruan...</span>
            </div>
          </div>

          <div v-if="activePendingDelete" class="messages-delete-undo-bar" role="status" aria-live="polite">
            <span>
              Mesazhi do te fshihet pas pak.
            </span>
            <button
              class="messages-bubble-copy"
              type="button"
              @click="undoDeleteMessage(activePendingDelete.messageId)"
            >
              Undo
            </button>
          </div>

          <form
            class="messages-compose"
            :class="{ 'is-drag-over': ui.dragOverComposer }"
            @submit.prevent="sendMessage"
            @click.stop
            @dragenter.prevent="handleComposerDragOver"
            @dragover.prevent="handleComposerDragOver"
            @dragleave="handleComposerDragLeave"
            @drop="handleComposerDrop"
          >
            <div v-if="isEditingMessage" class="messages-editing-banner">
              <div>
                <strong>Po ndryshon mesazhin</strong>
                <p>Ndrysho tekstin dhe dergoje perseri.</p>
              </div>
              <button
                class="messages-bubble-copy"
                type="button"
                @click="cancelEditingMessage"
              >
                Anulo
              </button>
            </div>

            <input
              ref="attachmentInputElement"
              class="sr-only"
              type="file"
              :accept="attachmentAccept"
              @change="handleAttachmentSelection"
            >

            <div v-if="pendingAttachment" class="messages-attachment-preview">
              <div class="messages-attachment-preview-media">
                <img
                  v-if="attachmentPreviewKind() === 'image'"
                  class="messages-attachment-image"
                  :src="pendingAttachmentPreviewUrl"
                  :alt="pendingAttachment.name || 'Preview'"
                >
                <video
                  v-else-if="attachmentPreviewKind() === 'video'"
                  class="messages-attachment-video"
                  :src="pendingAttachmentPreviewUrl"
                  controls
                  playsinline
                  preload="metadata"
                ></video>
                <audio
                  v-else-if="attachmentPreviewKind() === 'audio'"
                  class="messages-attachment-audio"
                  :src="pendingAttachmentPreviewUrl"
                  controls
                  preload="metadata"
                ></audio>
                <div
                  v-if="attachmentPreviewKind() === 'audio'"
                  class="messages-audio-waveform is-preview"
                  aria-hidden="true"
                >
                  <span
                    v-for="(barHeight, barIndex) in pendingWaveformBars()"
                    :key="`pending-${barIndex}`"
                    class="messages-audio-wave"
                    :style="{ height: `${barHeight}%` }"
                  ></span>
                </div>
                <span v-else class="messages-attachment-file">
                  {{ pendingAttachment.name }}
                </span>
              </div>
              <button
                class="messages-attachment-remove"
                type="button"
                @click="clearPendingAttachment"
              >
                Largo
              </button>
            </div>

            <div class="messages-compose-anchor">
              <div
                v-if="aiSuggestionsOpen && replySuggestions.length"
                class="messages-ai-suggestions"
                aria-live="polite"
              >
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

              <div class="messages-compose-row">
                <button
                  class="messages-compose-icon messages-compose-icon-ai"
                  type="button"
                  :disabled="ui.loadingSuggestions"
                  @click="toggleAiSuggestions"
                >
                  <svg
                    class="messages-compose-icon-svg"
                    viewBox="0 0 24 24"
                    aria-hidden="true"
                  >
                    <path
                      d="M12 3l1.6 4.4L18 9l-4.4 1.6L12 15l-1.6-4.4L6 9l4.4-1.6L12 3zM18.5 14l.9 2.6L22 17.5l-2.6.9-.9 2.6-.9-2.6-2.6-.9 2.6-.9.9-2.6zM6 14.5l.7 1.9 1.8.6-1.8.6-.7 1.9-.6-1.9-1.9-.6 1.9-.6.6-1.9z"
                      fill="currentColor"
                    />
                  </svg>
                  <span class="sr-only">Sugjero me AI</span>
                </button>

                <div class="messages-compose-input-shell">
                  <label class="sr-only" for="messages-compose-input">Shkruaje mesazhin</label>
                  <textarea
                    id="messages-compose-input"
                    ref="composerInputElement"
                    v-model="composer.body"
                    class="messages-compose-input"
                    rows="1"
                    maxlength="1500"
                    placeholder="Shkruaje mesazhin..."
                    enterkeyhint="send"
                    @input="handleComposerInput"
                    @keydown="handleComposerKeydown"
                  ></textarea>

                  <button
                    class="messages-compose-icon messages-compose-icon-plus"
                    :class="{ 'is-open': composerMenuOpen, 'is-recording': ui.recordingAudio }"
                    type="button"
                    @click="toggleComposerMenu"
                  >
                    +
                  </button>

                  <div v-if="composerMenuOpen" class="messages-compose-menu">
                    <button
                      class="messages-compose-menu-item"
                      type="button"
                      @click="handleComposerMenuAction('media')"
                    >
                      Foto/Video
                    </button>
                    <button
                      class="messages-compose-menu-item"
                      type="button"
                      @click="handleComposerMenuAction('audio')"
                    >
                      {{ ui.recordingAudio ? "Ndalo audio" : "Audio" }}
                    </button>
                    <button
                      class="messages-compose-menu-item"
                      type="button"
                      @click="handleComposerMenuAction('pdf')"
                    >
                      PDF file
                    </button>
                  </div>
                </div>

                <button
                  class="nav-action nav-action-primary messages-send-button"
                  type="submit"
                  :disabled="ui.sending"
                  :title="ui.sending ? (isEditingMessage ? 'Duke ruajtur...' : 'Duke derguar...') : (isEditingMessage ? 'Ruaj' : 'Dergo')"
                  :aria-label="ui.sending ? (isEditingMessage ? 'Duke ruajtur...' : 'Duke derguar...') : (isEditingMessage ? 'Ruaj' : 'Dergo')"
                >
                  <svg
                    class="messages-compose-icon-svg"
                    viewBox="0 0 24 24"
                    aria-hidden="true"
                  >
                    <path
                      d="M5 12.5L19 5l-4.5 14-2.7-5.1L5 12.5z"
                      fill="currentColor"
                    />
                  </svg>
                  <span class="sr-only">
                    {{ ui.sending ? (isEditingMessage ? "Duke ruajtur..." : "Duke derguar...") : (isEditingMessage ? "Ruaj" : "Dergo") }}
                  </span>
                </button>
              </div>
            </div>

            <div class="messages-compose-footer">
              <div class="messages-compose-meta">
                <div v-if="pendingUploadLabel" class="messages-upload-progress">
                  <span>{{ pendingUploadLabel }}</span>
                  <span class="messages-upload-progress-bar">
                    <span
                      class="messages-upload-progress-fill"
                      :style="{ width: `${Math.max(6, Math.round(uploadProgress))}%` }"
                    ></span>
                  </span>
                </div>
                <span class="messages-compose-counter">
                  {{ composerCharacterCount }}/1500
                </span>
              </div>
            </div>
          </form>
        </template>

        <div v-else class="messages-empty-state messages-thread-empty">
          Zgjidh nje bisede nga lista ne te majte per t'i pare mesazhet.
        </div>
      </section>
    </div>

    <div
      v-if="mediaViewer.open"
      class="messages-media-viewer"
      role="dialog"
      aria-modal="true"
      @click.self="closeMediaViewer"
    >
      <div class="messages-media-viewer-backdrop"></div>
      <div class="messages-media-viewer-card">
        <button
          class="messages-media-viewer-close"
          type="button"
          @click="closeMediaViewer"
        >
          Mbyll
        </button>
        <div
          v-if="mediaViewer.kind === 'image'"
          ref="mediaViewerStage"
          class="messages-media-viewer-stage"
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
            class="messages-media-viewer-image"
            :src="mediaViewer.src"
            :alt="mediaViewer.title || 'Attachment preview'"
            :style="mediaViewerImageStyle"
          >
        </div>
        <video
          v-else-if="mediaViewer.kind === 'video'"
          class="messages-media-viewer-video"
          :src="mediaViewer.src"
          controls
          autoplay
          playsinline
        ></video>
      </div>
    </div>
  </section>
</template>
