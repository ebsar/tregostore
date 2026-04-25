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
    <div
        @click="onClick">
        <GlassFilter :mode="mode" :displacementScale="displacementScale"
            :aberrationIntensity="aberrationIntensity" :width="glassSize.width" :height="glassSize.height"
            :shaderMapUrl="shaderMapUrl" />

        <div @mouseenter="onMouseEnter" @mouseleave="onMouseLeave" @mousedown="onMouseDown" @mouseup="onMouseUp">
            <!-- backdrop layer that gets wiggly -->
            <span></span>
            <span></span>
            <span></span>
            <span></span>
            <span></span>
            <span></span>

            <!-- user content stays sharp -->
            <div>
                <slot />
            </div>
        </div>
    </div>
</template>

