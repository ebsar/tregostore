<template>
  <article class="order-summary-card order-support-card">
    <header>
      <span>Support</span>
      <strong>Need help?</strong>
    </header>
    <div class="order-support-card__actions">
      <a class="order-support-card__action" :href="invoiceHref" target="_blank" rel="noreferrer">
        Download invoice
      </a>
      <button type="button" class="order-support-card__action" :disabled="!returnableItem || busy" @click="$emit('request-return', returnableItem)">
        {{ busy ? "Sending..." : "Request return/refund" }}
      </button>
      <button type="button" class="order-support-card__action" @click="$emit('report-problem')">
        Report a problem
      </button>
      <button type="button" class="order-support-card__action" @click="$emit('contact-support')">
        Contact support
      </button>
    </div>
  </article>
</template>

<script setup>
import { computed } from "vue";

const props = defineProps({
  busy: {
    type: Boolean,
    default: false,
  },
  order: {
    type: Object,
    required: true,
  },
  returnableItem: {
    type: Object,
    default: null,
  },
});

defineEmits(["contact-support", "report-problem", "request-return"]);

const invoiceHref = computed(() => `/api/orders/invoice?id=${encodeURIComponent(props.order?.id || "")}`);
</script>
