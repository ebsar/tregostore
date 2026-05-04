<template>
  <section class="orders-filter-bar" aria-label="Order filters">
    <label class="orders-filter-bar__search">
      <span class="sr-only">Search orders</span>
      <svg aria-hidden="true" viewBox="0 0 24 24">
        <path d="m21 21-4.3-4.3m1.3-5.2a6.5 6.5 0 1 1-13 0 6.5 6.5 0 0 1 13 0Z" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" />
      </svg>
      <input
        :value="searchQuery"
        type="search"
        placeholder="Search by order number, product, or seller"
        @input="$emit('update:searchQuery', $event.target.value)"
      />
    </label>

    <div class="orders-filter-bar__tabs" role="tablist" aria-label="Filter orders by status">
      <button
        v-for="tab in tabs"
        :key="tab.key"
        type="button"
        class="orders-filter-tab"
        :class="{ 'orders-filter-tab--active': tab.key === activeTab }"
        :aria-selected="tab.key === activeTab"
        role="tab"
        @click="$emit('select-tab', tab.key)"
      >
        <span>{{ tab.label }}</span>
        <small>{{ tab.count }}</small>
      </button>
    </div>
  </section>
</template>

<script setup>
defineProps({
  activeTab: {
    type: String,
    required: true,
  },
  searchQuery: {
    type: String,
    default: "",
  },
  tabs: {
    type: Array,
    required: true,
  },
});

defineEmits(["select-tab", "update:searchQuery"]);
</script>
