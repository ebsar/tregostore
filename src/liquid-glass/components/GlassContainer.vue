<script setup lang="ts" name="GlassContainer">
import { ref, watch, computed, onBeforeUnmount, type CSSProperties } from 'vue'
import { GlassMode, type GlassContainerProps } from '../type'
import { ShaderDisplacementGenerator } from '../shader-util';

import GlassFilter from './GlassFilter.vue'
import { uuid } from '../utils';
const props = withDefaults(defineProps<GlassContainerProps>(), {
    className: "",
    displacementScale: 25,
    blurAmount: 12,
    saturation: 180,
    aberrationIntensity: 2,
    active: false,
    overLight: false,
    cornerRadius: 999,
    padding: "24px 32px",
    glassSize: () => ({ width: 270, height: 69 }),
    mode: GlassMode.standard,
    effect: "liquidGlass"
})
const shaderMapUrl = ref<string>("")
const isFirefox = window.navigator.userAgent.toLowerCase().includes("firefox")
const filterId = uuid()
let shaderGenerator: ShaderDisplacementGenerator | null = null
let shaderAnimationFrame = 0

const destroyShaderGenerator = () => {
    if (shaderGenerator) {
        shaderGenerator.destroy()
        shaderGenerator = null
    }
}

const createShaderGenerator = (width: number, height: number) => {
    destroyShaderGenerator()
    shaderGenerator = new ShaderDisplacementGenerator({
        width,
        height,
        effect: props.effect,
    })
}

const normalizeMouseOffset = () => {
    if (!props.mouseOffset) {
        return undefined
    }

    return {
        x: Math.max(-1, Math.min(1, props.mouseOffset.x / 100)),
        y: Math.max(-1, Math.min(1, props.mouseOffset.y / 100)),
    }
}

// Generate shader-based displacement map using shaderUtils
const generateShaderDisplacementMap = async (width: number, height: number) => {
    if (!shaderGenerator) {
        createShaderGenerator(width, height)
    }

    const dataUrl = await shaderGenerator!.updateShader(normalizeMouseOffset())
    return dataUrl
}

const scheduleShaderRefresh = () => {
    if (shaderAnimationFrame) {
        cancelAnimationFrame(shaderAnimationFrame)
    }

    shaderAnimationFrame = requestAnimationFrame(async () => {
        shaderAnimationFrame = 0

        if (props.mode !== "shader") {
            shaderMapUrl.value = ""
            return
        }

        if (!shaderGenerator) {
            createShaderGenerator(props.glassSize.width, props.glassSize.height)
        }

        const url = await generateShaderDisplacementMap(props.glassSize.width, props.glassSize.height)
        shaderMapUrl.value = url
    })
}

watch(
    () => [
        props.mode,
        props.glassSize.width,
        props.glassSize.height,
        props.effect,
        props.mouseOffset?.x ?? 0,
        props.mouseOffset?.y ?? 0,
    ],
    ([mode, width, height, effect], previous = []) => {
        const [previousMode, previousWidth, previousHeight, previousEffect] = previous
        const didShaderConfigChange =
            mode !== previousMode ||
            width !== previousWidth ||
            height !== previousHeight ||
            effect !== previousEffect

        if (mode !== "shader") {
            destroyShaderGenerator()
            shaderMapUrl.value = ""
            return
        }

        if (didShaderConfigChange || !shaderGenerator) {
            createShaderGenerator(props.glassSize.width, props.glassSize.height)
        }

        scheduleShaderRefresh()
    },
    { immediate: true },
)

onBeforeUnmount(() => {
    if (shaderAnimationFrame) {
        cancelAnimationFrame(shaderAnimationFrame)
    }
    destroyShaderGenerator()
})

const backdropStyle = computed<Partial<CSSProperties>>(() => {
    return {
        filter: isFirefox ? undefined : `url(#${filterId})`,
        backdropFilter: `blur(${(props.overLight ? 12 : 4) + props.blurAmount * 32}px) saturate(${props.saturation}%)`,
    }
})

const glassStyle = computed<Partial<CSSProperties>>(() => ({
    borderRadius: `${props.cornerRadius}px`,
    padding,
    boxShadow: props.overLight ? '0px 16px 70px rgba(0, 0, 0, 0.75)' : '0px 12px 40px rgba(0, 0, 0, 0.25)',
    '--glass-radius': `${props.cornerRadius}px`,
    '--glass-specular-opacity': String(props.overLight ? 0.7 : 0.56),
    '--glass-outline-opacity': String(props.overLight ? 0.84 : 0.72),
    '--glass-iridescence-opacity': String(props.overLight ? 0.3 : 0.22),
}))



</script>

<template>
    <div :class="`relative ${className} ${active ? 'active' : ''} ${Boolean(onClick) ? 'cursor-pointer' : ''}`"
        :style="style" @click="onClick">
        <GlassFilter :mode="mode" :id="filterId" :displacementScale="displacementScale"
            :aberrationIntensity="aberrationIntensity" :width="glassSize.width" :height="glassSize.height"
            :shaderMapUrl="shaderMapUrl" />

        <div class="glass" :style="glassStyle" @mouseenter="onMouseEnter" @mouseleave="onMouseLeave" @mousedown="onMouseDown" @mouseup="onMouseUp">
            <!-- backdrop layer that gets wiggly -->
            <span class="glass__warp" :style="{
                ...backdropStyle,
                position: 'absolute',
                inset: '0',
            }"></span>
            <span class="glass__fill"></span>
            <span class="glass__specular"></span>
            <span class="glass__outline"></span>
            <span class="glass__iridescence"></span>
            <span class="glass__depth"></span>

            <!-- user content stays sharp -->
            <div class="glass__content" :style="{
                textShadow: props.overLight ? '0px 2px 12px rgba(0, 0, 0, 0)' : '0px 2px 12px rgba(0, 0, 0, 0.4)',
            }">
                <slot />
            </div>
        </div>
    </div>
</template>

<style scoped>
.glass {
  position: relative;
  display: inline-flex;
  align-items: center;
  gap: 24px;
  overflow: hidden;
  transition: transform 0.2s ease-in-out, box-shadow 0.2s ease-in-out;
  border-radius: var(--glass-radius);
  background:
    linear-gradient(180deg, rgba(255, 255, 255, 0.1), rgba(255, 255, 255, 0.03) 42%, rgba(255, 255, 255, 0.05)),
    linear-gradient(135deg, rgba(255, 255, 255, 0.12), rgba(255, 255, 255, 0.02) 46%, rgba(255, 255, 255, 0.07));
}

.glass__warp,
.glass__fill,
.glass__specular,
.glass__outline,
.glass__iridescence,
.glass__depth {
  position: absolute;
  inset: 0;
  pointer-events: none;
  border-radius: inherit;
}

.glass__warp {
  opacity: 0.96;
}

.glass__fill {
  background:
    radial-gradient(120% 88% at 50% 0%, rgba(255, 255, 255, 0.18), rgba(255, 255, 255, 0.06) 26%, rgba(255, 255, 255, 0) 56%),
    radial-gradient(140% 120% at 50% 100%, rgba(255, 255, 255, 0.07), rgba(255, 255, 255, 0) 64%);
  mix-blend-mode: screen;
  opacity: 0.7;
}

.glass__specular {
  inset: 1px 5% auto;
  height: 22%;
  border-radius: 999px;
  background:
    linear-gradient(180deg, rgba(255, 255, 255, 0.92), rgba(255, 255, 255, 0.22) 58%, rgba(255, 255, 255, 0) 100%);
  opacity: var(--glass-specular-opacity);
  filter: blur(0.4px);
}

.glass__outline {
  padding: 1.35px;
  background:
    linear-gradient(180deg, rgba(255, 255, 255, 0.92), rgba(255, 255, 255, 0.36) 28%, rgba(255, 255, 255, 0.16) 68%, rgba(255, 255, 255, 0.08));
  opacity: var(--glass-outline-opacity);
  mix-blend-mode: screen;
  -webkit-mask: linear-gradient(#000 0 0) content-box, linear-gradient(#000 0 0);
  -webkit-mask-composite: xor;
  mask: linear-gradient(#000 0 0) content-box, linear-gradient(#000 0 0);
  mask-composite: exclude;
}

.glass__iridescence {
  inset: auto 4% 0;
  height: 26%;
  border-radius: 999px;
  background:
    linear-gradient(90deg, rgba(92, 181, 255, 0.22), rgba(255, 255, 255, 0) 28%, rgba(255, 255, 255, 0) 72%, rgba(255, 140, 204, 0.22));
  opacity: var(--glass-iridescence-opacity);
  filter: blur(5px);
}

.glass__depth {
  box-shadow:
    inset 0 1px 0 rgba(255, 255, 255, 0.58),
    inset 0 8px 16px rgba(255, 255, 255, 0.08),
    inset 0 -10px 18px rgba(0, 0, 0, 0.12),
    inset 0 -1px 0 rgba(255, 255, 255, 0.08);
}

.glass__content {
  position: relative;
  z-index: 1;
  font: 500 20px/1 system-ui;
}
</style>
