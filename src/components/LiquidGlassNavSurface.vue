<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watchEffect, type CSSProperties } from "vue";
import GlassFilter from "../liquid-glass/components/GlassFilter.vue";
import { GlassMode } from "../liquid-glass/type";
import { autoPx, uuid } from "../liquid-glass/utils";

const props = withDefaults(defineProps<{
  mouseContainer?: HTMLElement | null
  className?: string
  displacementScale?: number
  blurAmount?: number
  saturation?: number
  aberrationIntensity?: number
  elasticity?: number
  cornerRadius?: number
  overLight?: boolean
  mode?: GlassMode | "standard" | "polar" | "prominent" | "shader"
}>(), {
  className: "",
  displacementScale: 64,
  blurAmount: 0.1,
  saturation: 130,
  aberrationIntensity: 2,
  elasticity: 0.35,
  cornerRadius: 100,
  overLight: false,
  mode: GlassMode.standard,
});

const surfaceRef = ref<HTMLElement | null>(null);
const surfaceSize = ref({ width: 1, height: 1 });
const mouseOffset = ref({ x: 0, y: 0 });
const globalMousePos = ref({ x: 0, y: 0 });
const filterId = uuid();
const isFirefox = typeof window !== "undefined" && window.navigator.userAgent.toLowerCase().includes("firefox");
let resizeObserver: ResizeObserver | null = null;

function updateSurfaceSize() {
  if (!surfaceRef.value) {
    return;
  }

  const rect = surfaceRef.value.getBoundingClientRect();
  surfaceSize.value = {
    width: Math.max(1, rect.width),
    height: Math.max(1, rect.height),
  };
}

function handleMouseMove(event: MouseEvent) {
  if (!surfaceRef.value) {
    return;
  }

  const rect = surfaceRef.value.getBoundingClientRect();
  const centerX = rect.left + rect.width / 2;
  const centerY = rect.top + rect.height / 2;

  mouseOffset.value = {
    x: ((event.clientX - centerX) / Math.max(rect.width, 1)) * 100,
    y: ((event.clientY - centerY) / Math.max(rect.height, 1)) * 100,
  };

  globalMousePos.value = {
    x: event.clientX,
    y: event.clientY,
  };
}

function resetMouse() {
  mouseOffset.value = { x: 0, y: 0 };
  globalMousePos.value = { x: 0, y: 0 };
}

watchEffect((onCleanup) => {
  const container = props.mouseContainer || surfaceRef.value?.parentElement;
  if (!container) {
    return;
  }

  container.addEventListener("mousemove", handleMouseMove);
  container.addEventListener("mouseleave", resetMouse);

  onCleanup(() => {
    container.removeEventListener("mousemove", handleMouseMove);
    container.removeEventListener("mouseleave", resetMouse);
  });
});

onMounted(() => {
  updateSurfaceSize();
  resizeObserver = new ResizeObserver(() => {
    updateSurfaceSize();
  });

  if (surfaceRef.value) {
    resizeObserver.observe(surfaceRef.value);
    if (surfaceRef.value.parentElement) {
      resizeObserver.observe(surfaceRef.value.parentElement);
    }
  }

  window.addEventListener("resize", updateSurfaceSize);
});

onBeforeUnmount(() => {
  if (resizeObserver) {
    resizeObserver.disconnect();
    resizeObserver = null;
  }
  window.removeEventListener("resize", updateSurfaceSize);
});

const backdropStyle = computed<Partial<CSSProperties>>(() => ({
  filter: isFirefox ? undefined : `url(#${filterId})`,
  backdropFilter: "blur(15.2px) saturate(130%)",
  WebkitBackdropFilter: "blur(15.2px) saturate(130%)",
}));

const overlayBoxShadow = computed(() =>
  props.overLight
    ? "0px 16px 70px rgba(0, 0, 0, 0.75)"
    : "0px 12px 40px rgba(0, 0, 0, 0.25)",
);

const borderGradient = computed(() =>
  `linear-gradient(${135 + mouseOffset.value.x * 1.2}deg, rgba(255, 255, 255, 0) 0%, rgba(255, 255, 255, ${
    0.12 + Math.abs(mouseOffset.value.x) * 0.008
  }) ${Math.max(10, 33 + mouseOffset.value.y * 0.3)}%, rgba(255, 255, 255, ${
    0.4 + Math.abs(mouseOffset.value.x) * 0.012
  }) ${Math.min(90, 66 + mouseOffset.value.y * 0.4)}%, rgba(255, 255, 255, 0) 100%)`,
);

const borderGradientStrong = computed(() =>
  `linear-gradient(${135 + mouseOffset.value.x * 1.2}deg, rgba(255, 255, 255, 0) 0%, rgba(255, 255, 255, ${
    0.32 + Math.abs(mouseOffset.value.x) * 0.008
  }) ${Math.max(10, 33 + mouseOffset.value.y * 0.3)}%, rgba(255, 255, 255, ${
    0.6 + Math.abs(mouseOffset.value.x) * 0.012
  }) ${Math.min(90, 66 + mouseOffset.value.y * 0.4)}%, rgba(255, 255, 255, 0) 100%)`,
);
</script>

<template>
  <div
    ref="surfaceRef"
    :class="['liquid-glass-nav-surface', className]"
    :style="{ borderRadius: `${cornerRadius}px` }"
    aria-hidden="true"
  >
    <GlassFilter
      :id="filterId"
      :mode="mode"
      :displacementScale="displacementScale"
      :aberrationIntensity="aberrationIntensity"
      :width="surfaceSize.width"
      :height="surfaceSize.height"
    />

    <div
      :class="`bg-black transition-all duration-150 ease-in-out pointer-events-none ${overLight ? 'opacity-20' : 'opacity-0'}`"
      :style="{
        position: 'absolute',
        inset: '0',
        borderRadius: `${cornerRadius}px`,
      }"
    ></div>

    <div
      :class="`bg-black transition-all duration-150 ease-in-out pointer-events-none mix-blend-overlay ${overLight ? 'opacity-100' : 'opacity-0'}`"
      :style="{
        position: 'absolute',
        inset: '0',
        borderRadius: `${cornerRadius}px`,
      }"
    ></div>

    <div
      class="liquid-glass-nav-surface-base"
      :style="{
        borderRadius: `${cornerRadius}px`,
        boxShadow: overlayBoxShadow,
      }"
    >
      <span
        class="glass__warp"
        :style="{
          ...backdropStyle,
          position: 'absolute',
          inset: '0',
        }"
      ></span>
    </div>

    <span
      :style="{
        position: 'absolute',
        inset: '0',
        height: autoPx(surfaceSize.height),
        width: autoPx(surfaceSize.width),
        borderRadius: `${cornerRadius}px`,
        pointerEvents: 'none',
        mixBlendMode: 'screen',
        opacity: 0.2,
        padding: '1.5px',
        WebkitMask: 'linear-gradient(#000 0 0) content-box, linear-gradient(#000 0 0)',
        WebkitMaskComposite: 'xor',
        maskComposite: 'exclude',
        boxShadow: '0 0 0 0.5px rgba(255, 255, 255, 0.5) inset, 0 1px 3px rgba(255, 255, 255, 0.25) inset, 0 1px 4px rgba(0, 0, 0, 0.35)',
        background: borderGradient,
      }"
    ></span>

    <span
      :style="{
        position: 'absolute',
        inset: '0',
        height: autoPx(surfaceSize.height),
        width: autoPx(surfaceSize.width),
        borderRadius: `${cornerRadius}px`,
        pointerEvents: 'none',
        mixBlendMode: 'overlay',
        padding: '1.5px',
        WebkitMask: 'linear-gradient(#000 0 0) content-box, linear-gradient(#000 0 0)',
        WebkitMaskComposite: 'xor',
        maskComposite: 'exclude',
        boxShadow: '0 0 0 0.5px rgba(255, 255, 255, 0.5) inset, 0 1px 3px rgba(255, 255, 255, 0.25) inset, 0 1px 4px rgba(0, 0, 0, 0.35)',
        background: borderGradientStrong,
      }"
    ></span>
  </div>
</template>

<style scoped>
.liquid-glass-nav-surface {
  position: absolute;
  inset: 0;
  display: block;
  pointer-events: none;
  z-index: 0;
}

.liquid-glass-nav-surface-base {
  position: absolute;
  inset: 0;
  overflow: hidden;
}
</style>
