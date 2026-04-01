import { computed, onMounted, onUnmounted, ref } from "vue";

const online = ref(typeof navigator === "undefined" ? true : navigator.onLine);
const unstable = ref(false);
let unstableTimer = 0;

function handleOnline() {
  online.value = true;
}

function handleOffline() {
  online.value = false;
}

export function markConnectionUnstable(durationMs = 2400) {
  unstable.value = true;
  window.clearTimeout(unstableTimer);
  unstableTimer = window.setTimeout(() => {
    unstable.value = false;
  }, durationMs);
}

export function useConnectivity() {
  onMounted(() => {
    window.addEventListener("online", handleOnline);
    window.addEventListener("offline", handleOffline);
  });

  onUnmounted(() => {
    window.removeEventListener("online", handleOnline);
    window.removeEventListener("offline", handleOffline);
  });

  return {
    isOnline: computed(() => online.value),
    isConnectionUnstable: computed(() => unstable.value),
  };
}
