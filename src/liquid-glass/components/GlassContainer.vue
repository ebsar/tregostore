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



</script>

<template>
    <div :class="`relative ${className} ${active ? 'active' : ''} ${Boolean(onClick) ? 'cursor-pointer' : ''}`"
        :style="style" @click="onClick">
        <GlassFilter :mode="mode" :id="filterId" :displacementScale="displacementScale"
            :aberrationIntensity="aberrationIntensity" :width="glassSize.width" :height="glassSize.height"
            :shaderMapUrl="shaderMapUrl" />

        <div class="glass" :style="{
            borderRadius: `${cornerRadius}px`,
            position: 'relative',
            display: 'inline-flex',
            alignItems: 'center',
            gap: '24px',
            padding,
            overflow: 'hidden',
            transition: 'all 0.2s ease-in-out',
            boxShadow: props.overLight ? '0px 16px 70px rgba(0, 0, 0, 0.75)' : '0px 12px 40px rgba(0, 0, 0, 0.25)',
        }" @mouseenter="onMouseEnter" @mouseleave="onMouseLeave" @mousedown="onMouseDown" @mouseup="onMouseUp">
            <!-- backdrop layer that gets wiggly -->
            <span class="glass__warp" :style="{
                ...backdropStyle,
                position: 'absolute',
                inset: '0',
            }"></span>

            <!-- user content stays sharp -->
            <div class="transition-all duration-150 ease-in-out text-white" :style="{
                position: 'relative',
                zIndex: 1,
                font: '500 20px/1 system-ui',
                textShadow: props.overLight ? '0px 2px 12px rgba(0, 0, 0, 0)' : '0px 2px 12px rgba(0, 0, 0, 0.4)',
            }">
                <slot />
            </div>
        </div>
    </div>
</template>
