<script setup>
import { computed } from "vue";

const props = defineProps({
  items: {
    type: Array,
    default: () => [],
  },
});

const normalizedItems = computed(() => {
  const fallback = [
    { label: "A", value: 32 },
    { label: "B", value: 54 },
    { label: "C", value: 41 },
    { label: "D", value: 68 },
  ];
  const source = Array.isArray(props.items) && props.items.length > 0 ? props.items : fallback;
  return source.map((item) => ({
    label: String(item?.label || "Item"),
    value: Math.max(0, Number(item?.value || 0)),
  }));
});

const maxValue = computed(() =>
  Math.max(...normalizedItems.value.map((item) => item.value), 1),
);
</script>

<template>
  <div class="dashboard-bar-chart">
    <div v-for="item in normalizedItems" :key="item.label" class="dashboard-bar-chart__row">
      <div class="dashboard-bar-chart__meta">
        <span>{{ item.label }}</span>
        <strong>{{ item.value }}</strong>
      </div>
      <div class="dashboard-bar-chart__track">
        <span class="dashboard-bar-chart__fill" :style="{ width: `${(item.value / maxValue) * 100}%` }"></span>
      </div>
    </div>
  </div>
</template>

<style scoped>
.dashboard-bar-chart {
  display: grid;
  gap: 14px;
}

.dashboard-bar-chart__row {
  display: grid;
  gap: 8px;
}

.dashboard-bar-chart__meta {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  color: #666666;
  font-size: 13px;
  line-height: 1.4;
}

.dashboard-bar-chart__meta strong {
  color: #111111;
  font-weight: 600;
}

.dashboard-bar-chart__track {
  height: 8px;
  overflow: hidden;
  border-radius: 999px;
  background: #efefef;
}

.dashboard-bar-chart__fill {
  display: block;
  height: 100%;
  border-radius: inherit;
  background: linear-gradient(90deg, #2563eb 0%, #3b82f6 100%);
}

.dashboard-bar-chart__row:nth-child(4n + 2) .dashboard-bar-chart__fill {
  background: linear-gradient(90deg, #1f8a57 0%, #2eb872 100%);
}

.dashboard-bar-chart__row:nth-child(4n + 3) .dashboard-bar-chart__fill {
  background: linear-gradient(90deg, #d08a22 0%, #f0b24d 100%);
}

.dashboard-bar-chart__row:nth-child(4n + 4) .dashboard-bar-chart__fill {
  background: linear-gradient(90deg, #d14b72 0%, #f26b8f 100%);
}
</style>
