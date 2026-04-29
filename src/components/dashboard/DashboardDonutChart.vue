<script setup>
import { computed } from "vue";

const props = defineProps({
  items: {
    type: Array,
    default: () => [],
  },
});

const palette = ["#2563eb", "#1f8a57", "#d08a22", "#d14b72", "#6d5efc"];

const normalizedItems = computed(() => {
  const fallback = [
    { label: "Primary", value: 48 },
    { label: "Secondary", value: 32 },
    { label: "Other", value: 20 },
  ];
  const source = Array.isArray(props.items) && props.items.length > 0 ? props.items : fallback;
  return source.map((item, index) => ({
    label: String(item?.label || "Item"),
    value: Math.max(0, Number(item?.value || 0)),
    color: palette[index % palette.length],
  }));
});

const total = computed(() =>
  normalizedItems.value.reduce((sum, item) => sum + item.value, 0),
);

const segments = computed(() => {
  let offset = 0;
  return normalizedItems.value.map((item) => {
    const ratio = total.value > 0 ? item.value / total.value : 0;
    const dash = ratio * 251.2;
    const segment = {
      ...item,
      dash,
      offset,
    };
    offset -= dash;
    return segment;
  });
});
</script>

<template>
  <div class="dashboard-donut-chart">
    <div class="dashboard-donut-chart__visual">
      <svg viewBox="0 0 120 120" role="img" aria-label="Distribution chart">
        <circle cx="60" cy="60" r="40" class="dashboard-donut-chart__track"></circle>
        <circle
          v-for="segment in segments"
          :key="segment.label"
          cx="60"
          cy="60"
          r="40"
          class="dashboard-donut-chart__segment"
          :style="{
            stroke: segment.color,
            strokeDasharray: `${segment.dash} 251.2`,
            strokeDashoffset: segment.offset,
          }"
        ></circle>
      </svg>
      <div class="dashboard-donut-chart__center">
        <strong>{{ total }}</strong>
        <span>Total</span>
      </div>
    </div>

    <div class="dashboard-donut-chart__legend">
      <div v-for="segment in segments" :key="`legend-${segment.label}`" class="dashboard-donut-chart__legend-item">
        <span class="dashboard-donut-chart__swatch" :style="{ backgroundColor: segment.color }"></span>
        <span>{{ segment.label }}</span>
        <strong>{{ segment.value }}</strong>
      </div>
    </div>
  </div>
</template>

<style scoped>
.dashboard-donut-chart {
  display: grid;
  gap: 12px;
}

.dashboard-donut-chart__visual {
  position: relative;
  width: 116px;
  height: 116px;
}

svg {
  width: 100%;
  height: 100%;
  transform: rotate(-90deg);
}

.dashboard-donut-chart__track,
.dashboard-donut-chart__segment {
  fill: none;
  stroke-width: 10;
}

.dashboard-donut-chart__track {
  stroke: #efefef;
}

.dashboard-donut-chart__segment {
  stroke-linecap: butt;
}

.dashboard-donut-chart__center {
  position: absolute;
  inset: 0;
  display: grid;
  place-content: center;
  text-align: center;
}

.dashboard-donut-chart__center strong {
  color: #111111;
  font-size: 18px;
  font-weight: 700;
  line-height: 1;
}

.dashboard-donut-chart__center span,
.dashboard-donut-chart__legend-item span {
  color: #808080;
  font-size: 11px;
  line-height: 1.25;
}

.dashboard-donut-chart__legend {
  display: grid;
  gap: 8px;
}

.dashboard-donut-chart__legend-item {
  display: grid;
  grid-template-columns: 10px minmax(0, 1fr) auto;
  align-items: center;
  gap: 8px;
}

.dashboard-donut-chart__legend-item strong {
  color: #111111;
  font-size: 12px;
  font-weight: 600;
}

.dashboard-donut-chart__swatch {
  width: 10px;
  height: 10px;
  border-radius: 999px;
}
</style>
