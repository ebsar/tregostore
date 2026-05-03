<script setup>
import { computed } from "vue";

const props = defineProps({
  values: {
    type: Array,
    default: () => [],
  },
  labels: {
    type: Array,
    default: () => [],
  },
  height: {
    type: Number,
    default: 180,
  },
});

const width = 640;
const padding = 18;

const normalizedValues = computed(() => {
  const nextValues = Array.isArray(props.values) && props.values.length > 0
    ? props.values.map((value) => Number(value || 0))
    : [120, 180, 160, 220, 200, 260, 240];
  return nextValues.map((value) => (Number.isFinite(value) ? value : 0));
});

const points = computed(() => {
  const values = normalizedValues.value;
  const minValue = Math.min(...values);
  const maxValue = Math.max(...values);
  const range = Math.max(maxValue - minValue, 1);

  return values.map((value, index) => {
    const x = padding + (index * (width - padding * 2)) / Math.max(values.length - 1, 1);
    const y = props.height - padding - ((value - minValue) / range) * (props.height - padding * 2);
    return { x, y };
  });
});

const linePath = computed(() =>
  points.value.map((point, index) => `${index === 0 ? "M" : "L"} ${point.x} ${point.y}`).join(" "),
);

const areaPath = computed(() => {
  if (points.value.length === 0) {
    return "";
  }

  const first = points.value[0];
  const last = points.value[points.value.length - 1];
  return `${linePath.value} L ${last.x} ${props.height - padding} L ${first.x} ${props.height - padding} Z`;
});

const chartLabels = computed(() => {
  if (Array.isArray(props.labels) && props.labels.length === normalizedValues.value.length) {
    return props.labels;
  }

  return normalizedValues.value.map((_, index) => `P${index + 1}`);
});
</script>

<template>
  <div class="dashboard-chart dashboard-chart--line">
    <svg :viewBox="`0 0 ${width} ${height}`" role="img" aria-label="Line chart">
      <g class="dashboard-chart__grid">
        <line v-for="line in 5" :key="`grid-${line}`" x1="18" :y1="line * 40" x2="622" :y2="line * 40"></line>
      </g>
      <path class="dashboard-chart__area" :d="areaPath"></path>
      <path class="dashboard-chart__line" :d="linePath"></path>
      <circle v-for="(point, index) in points" :key="`point-${index}`" :cx="point.x" :cy="point.y" r="4"></circle>
    </svg>

    <div class="dashboard-chart__labels">
      <span v-for="label in chartLabels" :key="label">{{ label }}</span>
    </div>
  </div>
</template>

<style scoped>
.dashboard-chart {
  display: grid;
  gap: 8px;
}

svg {
  width: 100%;
  height: auto;
}

.dashboard-chart__grid line {
  stroke: #ececec;
  stroke-width: 1;
}

.dashboard-chart__area {
  fill: rgba(255, 106, 0, 0.12);
}

.dashboard-chart__line {
  fill: none;
  stroke: var(--color-primary);
  stroke-width: 2;
  stroke-linecap: round;
  stroke-linejoin: round;
}

circle {
  fill: #ffffff;
  stroke: var(--color-primary);
  stroke-width: 1.75;
}

.dashboard-chart__labels {
  display: flex;
  justify-content: space-between;
  gap: 8px;
  color: #848484;
  font-size: 11px;
  line-height: 1.25;
}
</style>
