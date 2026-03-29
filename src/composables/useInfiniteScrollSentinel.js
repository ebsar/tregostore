import {
  nextTick,
  onBeforeUnmount,
  ref,
  unref,
  watch,
} from "vue";

export function useInfiniteScrollSentinel({
  enabled = true,
  hasMore,
  loading,
  onLoadMore,
  rootMargin = "0px 0px 260px 0px",
  threshold = 0.08,
} = {}) {
  const target = ref(null);
  const supportsAutoLoad = ref(false);
  let observer = null;

  function disconnectObserver() {
    if (observer) {
      observer.disconnect();
      observer = null;
    }
  }

  function canObserve() {
    return typeof window !== "undefined" && typeof window.IntersectionObserver === "function";
  }

  async function handleIntersect(entries) {
    const firstEntry = entries?.[0];
    if (!firstEntry?.isIntersecting) {
      return;
    }

    if (!unref(enabled) || !unref(hasMore) || unref(loading)) {
      return;
    }

    await onLoadMore?.();
  }

  function refreshObserver() {
    disconnectObserver();
    supportsAutoLoad.value = canObserve();

    if (!supportsAutoLoad.value || !target.value || !unref(enabled) || !unref(hasMore)) {
      return;
    }

    observer = new window.IntersectionObserver(
      (entries) => {
        void handleIntersect(entries);
      },
      {
        root: null,
        rootMargin,
        threshold,
      },
    );

    observer.observe(target.value);
  }

  watch(
    [
      target,
      () => unref(enabled),
      () => unref(hasMore),
      () => unref(loading),
    ],
    () => {
      void nextTick(refreshObserver);
    },
    { immediate: true },
  );

  onBeforeUnmount(() => {
    disconnectObserver();
  });

  return {
    target,
    supportsAutoLoad,
  };
}
