<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, useAttrs, type ComponentPublicInstance } from "vue";

defineOptions({ inheritAttrs: false });

const props = withDefaults(defineProps<{
  as?: string | object
  mouseContainer?: HTMLElement | null
  elasticity?: number
}>(), {
  as: "button",
  mouseContainer: null,
  elasticity: 0.35,
});

const attrs = useAttrs();
const buttonRef = ref<HTMLElement | ComponentPublicInstance | null>(null);
const pointer = ref({ x: 0, y: 0 });
const hovering = ref(false);
let trackedTarget: HTMLElement | null = null;
let trackedElement: HTMLElement | null = null;

function resolveButtonElement() {
  if (!buttonRef.value) {
    return null;
  }

  if (buttonRef.value instanceof HTMLElement) {
    return buttonRef.value;
  }

  const componentRoot = (buttonRef.value as ComponentPublicInstance).$el;
  return componentRoot instanceof HTMLElement ? componentRoot : null;
}

function handleMouseMove(event: MouseEvent) {
  pointer.value = { x: event.clientX, y: event.clientY };
}

function handleMouseLeave() {
  hovering.value = false;
  pointer.value = { x: 0, y: 0 };
}

function handleMouseEnter() {
  hovering.value = true;
}

onMounted(() => {
  trackedElement = resolveButtonElement();
  trackedTarget = props.mouseContainer || trackedElement?.parentElement || null;

  const target = trackedTarget;
  if (target) {
    target.addEventListener("mousemove", handleMouseMove);
    target.addEventListener("mouseleave", handleMouseLeave);
  }

  if (trackedElement) {
    trackedElement.addEventListener("mouseenter", handleMouseEnter);
    trackedElement.addEventListener("mouseleave", handleMouseLeave);
  }
});

onBeforeUnmount(() => {
  if (trackedTarget) {
    trackedTarget.removeEventListener("mousemove", handleMouseMove);
    trackedTarget.removeEventListener("mouseleave", handleMouseLeave);
  }

  if (trackedElement) {
    trackedElement.removeEventListener("mouseenter", handleMouseEnter);
    trackedElement.removeEventListener("mouseleave", handleMouseLeave);
  }
});

const forwardedAttrs = computed(() => {
  const { style: _style, ...rest } = attrs;
  return rest;
});

const motionStyle = computed(() => {
  const buttonElement = resolveButtonElement();

  if (!buttonElement || !hovering.value) {
    return {
      transform: "translate3d(0, 0, 0) scale(1)",
      transition: "transform 0.18s ease-out",
      willChange: "transform",
    };
  }

  const rect = buttonElement.getBoundingClientRect();
  const centerX = rect.left + rect.width / 2;
  const centerY = rect.top + rect.height / 2;
  const deltaX = pointer.value.x - centerX;
  const deltaY = pointer.value.y - centerY;
  const edgeDistanceX = Math.max(0, Math.abs(deltaX) - rect.width / 2);
  const edgeDistanceY = Math.max(0, Math.abs(deltaY) - rect.height / 2);
  const edgeDistance = Math.sqrt(edgeDistanceX * edgeDistanceX + edgeDistanceY * edgeDistanceY);
  const activationZone = 150;

  if (edgeDistance > activationZone) {
    return {
      transform: "translate3d(0, 0, 0) scale(1)",
      transition: "transform 0.18s ease-out",
      willChange: "transform",
    };
  }

  const fadeInFactor = 1 - edgeDistance / activationZone;
  const centerDistance = Math.sqrt(deltaX * deltaX + deltaY * deltaY);
  if (!centerDistance) {
    return {
      transform: "translate3d(0, 0, 0) scale(1)",
      transition: "transform 0.18s ease-out",
      willChange: "transform",
    };
  }

  const normalizedX = deltaX / centerDistance;
  const normalizedY = deltaY / centerDistance;
  const strength = Math.max(0, props.elasticity) * 2.1;
  const translationX = deltaX * strength * 0.035 * fadeInFactor;
  const translationY = deltaY * strength * 0.035 * fadeInFactor;
  const stretchIntensity = Math.min(centerDistance / 160, 1) * strength * fadeInFactor;
  const scaleX = 1 + Math.abs(normalizedX) * stretchIntensity * 0.22 - Math.abs(normalizedY) * stretchIntensity * 0.08;
  const scaleY = 1 + Math.abs(normalizedY) * stretchIntensity * 0.22 - Math.abs(normalizedX) * stretchIntensity * 0.08;

  return {
    transform: `translate3d(${translationX}px, ${translationY}px, 0) scaleX(${Math.max(0.92, scaleX)}) scaleY(${Math.max(0.92, scaleY)})`,
    transition: "transform 0.12s ease-out",
    willChange: "transform",
  };
});
</script>

<template>
  <component
    :is="as"
    ref="buttonRef"
    v-bind="forwardedAttrs"
    :style="[attrs.style, motionStyle]"
  >
    <slot />
  </component>
</template>
