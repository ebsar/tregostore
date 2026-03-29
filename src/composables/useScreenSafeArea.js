import { onBeforeUnmount, onMounted, ref } from "vue";

function createSafeAreaProbe() {
  if (typeof document === "undefined") {
    return null;
  }

  const probe = document.createElement("div");
  probe.setAttribute("aria-hidden", "true");
  probe.style.cssText = [
    "position: fixed",
    "inset: 0",
    "visibility: hidden",
    "pointer-events: none",
    "padding-top: env(safe-area-inset-top, 0px)",
    "padding-right: env(safe-area-inset-right, 0px)",
    "padding-bottom: env(safe-area-inset-bottom, 0px)",
    "padding-left: env(safe-area-inset-left, 0px)",
  ].join(";");
  return probe;
}

export function useScreenSafeArea() {
  const top = ref("0px");
  const right = ref("0px");
  const bottom = ref("0px");
  const left = ref("0px");

  let probe = null;
  let frameId = 0;

  const readSafeArea = () => {
    if (!probe || typeof window === "undefined") {
      return;
    }

    const style = window.getComputedStyle(probe);
    top.value = style.paddingTop || "0px";
    right.value = style.paddingRight || "0px";
    bottom.value = style.paddingBottom || "0px";
    left.value = style.paddingLeft || "0px";
  };

  const scheduleReadSafeArea = () => {
    if (typeof window === "undefined") {
      return;
    }

    if (frameId) {
      window.cancelAnimationFrame(frameId);
    }

    frameId = window.requestAnimationFrame(() => {
      frameId = 0;
      readSafeArea();
    });
  };

  const clearScheduledFrame = () => {
    if (typeof window === "undefined" || !frameId) {
      return;
    }

    window.cancelAnimationFrame(frameId);
    frameId = 0;
  };

  onMounted(() => {
    probe = createSafeAreaProbe();
    if (!probe || typeof window === "undefined") {
      return;
    }

    document.body.appendChild(probe);
    scheduleReadSafeArea();

    window.addEventListener("resize", scheduleReadSafeArea, { passive: true });
    window.addEventListener("orientationchange", scheduleReadSafeArea, { passive: true });
    window.visualViewport?.addEventListener("resize", scheduleReadSafeArea, { passive: true });
    window.visualViewport?.addEventListener("scroll", scheduleReadSafeArea, { passive: true });
  });

  onBeforeUnmount(() => {
    clearScheduledFrame();

    if (typeof window !== "undefined") {
      window.removeEventListener("resize", scheduleReadSafeArea);
      window.removeEventListener("orientationchange", scheduleReadSafeArea);
      window.visualViewport?.removeEventListener("resize", scheduleReadSafeArea);
      window.visualViewport?.removeEventListener("scroll", scheduleReadSafeArea);
    }

    probe?.remove?.();
    probe = null;
  });

  return {
    top,
    right,
    bottom,
    left,
    update: scheduleReadSafeArea,
  };
}
