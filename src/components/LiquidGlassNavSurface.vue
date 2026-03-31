<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch, watchEffect, type CSSProperties } from "vue";
import GlassFilter from "../liquid-glass/components/GlassFilter.vue";
import { ShaderDisplacementGenerator } from "../liquid-glass/shader-util";
import { GlassMode } from "../liquid-glass/type";
import { uuid } from "../liquid-glass/utils";

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
  effect?: "liquidGlass" | "liquidGlass2" | "flowingLiquid" | "transparentIce" | "unevenGlass" | "mosaicGlass"
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
  effect: "liquidGlass",
});

const surfaceRef = ref<HTMLElement | null>(null);
const surfaceSize = ref({ width: 1, height: 1 });
const mouseOffset = ref({ x: 0, y: 0 });
const globalMousePos = ref({ x: 0, y: 0 });
const shaderMapUrl = ref("");
const filterId = uuid();
const isFirefox = typeof window !== "undefined" && window.navigator.userAgent.toLowerCase().includes("firefox");
let resizeObserver: ResizeObserver | null = null;
let shaderGenerator: ShaderDisplacementGenerator | null = null;
let shaderAnimationFrame = 0;

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

function destroyShaderGenerator() {
  if (shaderGenerator) {
    shaderGenerator.destroy();
    shaderGenerator = null;
  }
}

function createShaderGenerator(width: number, height: number) {
  destroyShaderGenerator();
  shaderGenerator = new ShaderDisplacementGenerator({
    width,
    height,
    effect: props.effect,
  });
}

function normalizeMouseOffset() {
  return {
    x: Math.max(-1, Math.min(1, mouseOffset.value.x / 100)),
    y: Math.max(-1, Math.min(1, mouseOffset.value.y / 100)),
  };
}

async function generateShaderDisplacementMap(width: number, height: number) {
  if (!shaderGenerator) {
    createShaderGenerator(width, height);
  }

  return shaderGenerator!.updateShader(normalizeMouseOffset());
}

function scheduleShaderRefresh() {
  if (shaderAnimationFrame) {
    cancelAnimationFrame(shaderAnimationFrame);
  }

  shaderAnimationFrame = requestAnimationFrame(async () => {
    shaderAnimationFrame = 0;

    if (props.mode !== "shader") {
      shaderMapUrl.value = "";
      return;
    }

    const nextWidth = Math.max(1, surfaceSize.value.width);
    const nextHeight = Math.max(1, surfaceSize.value.height);
    if (!shaderGenerator) {
      createShaderGenerator(nextWidth, nextHeight);
    }

    shaderMapUrl.value = await generateShaderDisplacementMap(nextWidth, nextHeight);
  });
}

const fadeInFactor = computed(() => {
  if (!surfaceRef.value || !globalMousePos.value.x || !globalMousePos.value.y) {
    return 0;
  }

  const rect = surfaceRef.value.getBoundingClientRect();
  const centerX = rect.left + rect.width / 2;
  const centerY = rect.top + rect.height / 2;
  const edgeDistanceX = Math.max(0, Math.abs(globalMousePos.value.x - centerX) - rect.width / 2);
  const edgeDistanceY = Math.max(0, Math.abs(globalMousePos.value.y - centerY) - rect.height / 2);
  const edgeDistance = Math.sqrt(edgeDistanceX * edgeDistanceX + edgeDistanceY * edgeDistanceY);
  const activationZone = 200;

  return edgeDistance > activationZone ? 0 : 1 - edgeDistance / activationZone;
});

const elasticityStrength = computed(() => Math.max(0, props.elasticity) * 2.2);

const elasticTranslation = computed(() => {
  if (!surfaceRef.value || !fadeInFactor.value) {
    return { x: 0, y: 0 };
  }

  const rect = surfaceRef.value.getBoundingClientRect();
  const centerX = rect.left + rect.width / 2;
  const centerY = rect.top + rect.height / 2;

  return {
    x: (globalMousePos.value.x - centerX) * elasticityStrength.value * 0.12 * fadeInFactor.value,
    y: (globalMousePos.value.y - centerY) * elasticityStrength.value * 0.12 * fadeInFactor.value,
  };
});

const directionalScale = computed(() => {
  if (!surfaceRef.value || !globalMousePos.value.x || !globalMousePos.value.y) {
    return "scale(1)";
  }

  const rect = surfaceRef.value.getBoundingClientRect();
  const centerX = rect.left + rect.width / 2;
  const centerY = rect.top + rect.height / 2;
  const deltaX = globalMousePos.value.x - centerX;
  const deltaY = globalMousePos.value.y - centerY;
  const edgeDistanceX = Math.max(0, Math.abs(deltaX) - rect.width / 2);
  const edgeDistanceY = Math.max(0, Math.abs(deltaY) - rect.height / 2);
  const edgeDistance = Math.sqrt(edgeDistanceX * edgeDistanceX + edgeDistanceY * edgeDistanceY);
  const activationZone = 200;

  if (edgeDistance > activationZone) {
    return "scale(1)";
  }

  const centerDistance = Math.sqrt(deltaX * deltaX + deltaY * deltaY);
  if (centerDistance === 0) {
    return "scale(1)";
  }

  const normalizedX = deltaX / centerDistance;
  const normalizedY = deltaY / centerDistance;
  const stretchIntensity = Math.min(centerDistance / 240, 1) * elasticityStrength.value * fadeInFactor.value;
  const scaleX = 1 + Math.abs(normalizedX) * stretchIntensity * 0.42 - Math.abs(normalizedY) * stretchIntensity * 0.18;
  const scaleY = 1 + Math.abs(normalizedY) * stretchIntensity * 0.42 - Math.abs(normalizedX) * stretchIntensity * 0.18;

  return `scaleX(${Math.max(0.86, scaleX)}) scaleY(${Math.max(0.86, scaleY)})`;
});

const surfaceTransform = computed(() =>
  `translate3d(${elasticTranslation.value.x}px, ${elasticTranslation.value.y}px, 0) ${directionalScale.value}`,
);

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

watch(
  () => [
    props.mode,
    props.effect,
    surfaceSize.value.width,
    surfaceSize.value.height,
    mouseOffset.value.x,
    mouseOffset.value.y,
  ],
  ([mode, effect, width, height], previous = []) => {
    const [previousMode, previousEffect, previousWidth, previousHeight] = previous as typeof previous;
    const didShaderConfigChange =
      mode !== previousMode
      || effect !== previousEffect
      || width !== previousWidth
      || height !== previousHeight;

    if (mode !== "shader") {
      destroyShaderGenerator();
      shaderMapUrl.value = "";
      return;
    }

    if (didShaderConfigChange || !shaderGenerator) {
      createShaderGenerator(Math.max(1, surfaceSize.value.width), Math.max(1, surfaceSize.value.height));
    }

    scheduleShaderRefresh();
  },
  { immediate: true },
);

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
  if (shaderAnimationFrame) {
    cancelAnimationFrame(shaderAnimationFrame);
  }
  destroyShaderGenerator();
  if (resizeObserver) {
    resizeObserver.disconnect();
    resizeObserver = null;
  }
  window.removeEventListener("resize", updateSurfaceSize);
});

const backdropStyle = computed<Partial<CSSProperties>>(() => ({
  filter: isFirefox ? undefined : `url(#${filterId})`,
  backdropFilter: "none",
  WebkitBackdropFilter: "none",
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

const surfaceStyle = computed<Partial<CSSProperties>>(() => ({
  borderRadius: `${props.cornerRadius}px`,
  transform: surfaceTransform.value,
  transition: "transform 0.2s ease-out",
  willChange: "transform",
  "--liquid-nav-radius": `${props.cornerRadius}px`,
  "--liquid-nav-specular-opacity": String(props.overLight ? 0.72 : 0.58),
  "--liquid-nav-outline-opacity": String(props.overLight ? 0.86 : 0.74),
  "--liquid-nav-iridescence-opacity": String(props.overLight ? 0.34 : 0.24),
  "--liquid-nav-shadow": overlayBoxShadow.value,
} as Partial<CSSProperties>));
</script>

<template>
  <div
    ref="surfaceRef"
    :class="['liquid-glass-nav-surface', className]"
    :style="surfaceStyle"
  >
    <GlassFilter
      :id="filterId"
      :mode="mode"
      :displacementScale="displacementScale"
      :aberrationIntensity="aberrationIntensity"
      :width="surfaceSize.width"
      :height="surfaceSize.height"
      :shaderMapUrl="shaderMapUrl"
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
    >
      <span
        class="glass__warp"
        :style="{
          ...backdropStyle,
          position: 'absolute',
          inset: '0',
        }"
      ></span>
      <span class="liquid-glass-nav-surface-fill"></span>
      <span class="liquid-glass-nav-surface-specular"></span>
      <span class="liquid-glass-nav-surface-depth"></span>
    </div>

    <span
      class="liquid-glass-nav-surface-outline"
      :style="{
        position: 'absolute',
        inset: '0',
        background: borderGradient,
      }"
    ></span>

    <span
      class="liquid-glass-nav-surface-glint"
      :style="{
        position: 'absolute',
        inset: '0',
        background: borderGradientStrong,
      }"
    ></span>

    <span class="liquid-glass-nav-surface-iridescence"></span>

    <div class="liquid-glass-nav-surface-content">
      <slot />
    </div>
  </div>
</template>

<style scoped>
.liquid-glass-nav-surface {
  position: relative;
  display: block;
  width: 100%;
  isolation: isolate;
  border-radius: var(--liquid-nav-radius);
}

.liquid-glass-nav-surface-base {
  position: absolute;
  inset: 0;
  overflow: hidden;
  pointer-events: none;
  border-radius: inherit;
  box-shadow: var(--liquid-nav-shadow);
  background:
    linear-gradient(180deg, rgba(255, 255, 255, 0.1), rgba(255, 255, 255, 0.03) 42%, rgba(255, 255, 255, 0.05)),
    linear-gradient(135deg, rgba(255, 255, 255, 0.12), rgba(255, 255, 255, 0.02) 46%, rgba(255, 255, 255, 0.07));
}

.glass__warp,
.liquid-glass-nav-surface-fill,
.liquid-glass-nav-surface-specular,
.liquid-glass-nav-surface-depth,
.liquid-glass-nav-surface-outline,
.liquid-glass-nav-surface-glint,
.liquid-glass-nav-surface-iridescence {
  border-radius: inherit;
  pointer-events: none;
}

.glass__warp {
  opacity: 0.96;
}

.liquid-glass-nav-surface-fill {
  position: absolute;
  inset: 0;
  background:
    radial-gradient(120% 88% at 50% 0%, rgba(255, 255, 255, 0.18), rgba(255, 255, 255, 0.06) 26%, rgba(255, 255, 255, 0) 56%),
    radial-gradient(140% 120% at 50% 100%, rgba(255, 255, 255, 0.07), rgba(255, 255, 255, 0) 64%);
  mix-blend-mode: screen;
  opacity: 0.7;
}

.liquid-glass-nav-surface-specular {
  position: absolute;
  inset: 1px 5% auto;
  height: 22%;
  border-radius: 999px;
  background:
    linear-gradient(180deg, rgba(255, 255, 255, 0.92), rgba(255, 255, 255, 0.22) 58%, rgba(255, 255, 255, 0) 100%);
  opacity: var(--liquid-nav-specular-opacity);
  filter: blur(0.4px);
}

.liquid-glass-nav-surface-depth {
  position: absolute;
  inset: 0;
  box-shadow:
    inset 0 1px 0 rgba(255, 255, 255, 0.58),
    inset 0 8px 16px rgba(255, 255, 255, 0.08),
    inset 0 -10px 18px rgba(0, 0, 0, 0.12),
    inset 0 -1px 0 rgba(255, 255, 255, 0.08);
}

.liquid-glass-nav-surface-outline,
.liquid-glass-nav-surface-glint {
  padding: 1.35px;
  -webkit-mask: linear-gradient(#000 0 0) content-box, linear-gradient(#000 0 0);
  -webkit-mask-composite: xor;
  mask: linear-gradient(#000 0 0) content-box, linear-gradient(#000 0 0);
  mask-composite: exclude;
}

.liquid-glass-nav-surface-outline {
  mix-blend-mode: screen;
  opacity: var(--liquid-nav-outline-opacity);
  box-shadow:
    0 0 0 0.5px rgba(255, 255, 255, 0.5) inset,
    0 1px 3px rgba(255, 255, 255, 0.25) inset,
    0 1px 4px rgba(0, 0, 0, 0.35);
}

.liquid-glass-nav-surface-glint {
  mix-blend-mode: overlay;
  opacity: 0.42;
}

.liquid-glass-nav-surface-iridescence {
  position: absolute;
  inset: auto 4% 0;
  height: 26%;
  border-radius: 999px;
  background:
    linear-gradient(90deg, rgba(92, 181, 255, 0.22), rgba(255, 255, 255, 0) 28%, rgba(255, 255, 255, 0) 72%, rgba(255, 140, 204, 0.22));
  opacity: var(--liquid-nav-iridescence-opacity);
  filter: blur(5px);
}

.liquid-glass-nav-surface-content {
  position: relative;
  z-index: 1;
  width: 100%;
  pointer-events: auto;
}
</style>
