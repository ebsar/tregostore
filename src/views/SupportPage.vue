<script setup>
import { computed, onMounted, reactive } from "vue";
import { RouterLink } from "vue-router";
import AccountUtilityShell from "../components/account/AccountUtilityShell.vue";
import { ensureSessionLoaded, markRouteReady } from "../stores/app-state";

const ui = reactive({
  guest: false,
});

const supportCards = computed(() => ([
  {
    title: "Messages",
    description: "Open conversations with businesses and support from one inbox.",
    href: "/mesazhet",
    action: "Open inbox",
  },
  {
    title: "Track order",
    description: "Check delivery progress with your order number and billing email.",
    href: "/track-order",
    action: "Track order",
  },
  {
    title: "Refunds & returns",
    description: "Follow return requests and refund decisions without leaving the dashboard.",
    href: "/refund-returne",
    action: "Open returns",
  },
  {
    title: "Notifications",
    description: "Review marketplace alerts, confirmations, and delivery updates.",
    href: "/njoftimet",
    action: "View notifications",
  },
]));

onMounted(async () => {
  try {
    const user = await ensureSessionLoaded();
    if (!user) {
      ui.guest = true;
    }
  } finally {
    markRouteReady();
  }
});
</script>

<template>
  <AccountUtilityShell
    v-if="!ui.guest"
    active-key="support"
    eyebrow="Customer support"
    title="Support & help"
    description="Use the right support path quickly: messages, order tracking, refunds, and account notifications."
    search-placeholder="Search support or help topics"
  >
    <section class="account-card">
      <div class="account-card__header">
        <div>
          <h2>Support shortcuts</h2>
          <p>Everything important for after-purchase help stays grouped here so users do not need to hunt through multiple pages.</p>
        </div>
      </div>

      <div class="account-support-grid">
        <article
          v-for="card in supportCards"
          :key="card.href"
          class="account-support-card"
        >
          <div>
            <h3>{{ card.title }}</h3>
            <p>{{ card.description }}</p>
          </div>
          <RouterLink class="market-button market-button--secondary" :to="card.href">
            {{ card.action }}
          </RouterLink>
        </article>
      </div>
    </section>
  </AccountUtilityShell>

  <section v-else class="market-page market-page--wide dashboard-page" aria-label="Support">
    <div class="market-empty account-gate">
      <h2>Sign in to reach support tools</h2>
      <p>Log in first to access messages, refund requests, and order tracking from one place.</p>
      <div class="account-gate__actions">
        <RouterLink class="market-button market-button--primary" to="/login?redirect=%2Fsupport">
          Login
        </RouterLink>
        <RouterLink class="market-button market-button--secondary" to="/signup?redirect=%2Fsupport">
          Sign up
        </RouterLink>
      </div>
    </div>
  </section>
</template>
