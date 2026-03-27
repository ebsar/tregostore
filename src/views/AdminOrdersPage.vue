<script setup>
import { onMounted } from "vue";
import { useRouter } from "vue-router";
import { ensureSessionLoaded, markRouteReady } from "../stores/app-state";

const router = useRouter();

onMounted(async () => {
  try {
    const user = await ensureSessionLoaded();
    if (!user) {
      router.replace("/login");
      return;
    }

    if (user.role !== "admin") {
      router.replace("/");
    }
  } finally {
    markRouteReady();
  }
});
</script>

<template>
  <section class="account-page orders-page" aria-label="Porosit e adminit">
    <header class="account-header profile-page-header">
      <div>
        <p class="section-label">Admin</p>
        <h1>Porosit</h1>
        <p class="section-text">
          Ketu do ta lidhim me vone pamjen e pergjithshme te porosive ne nivel administrimi.
        </p>
      </div>
    </header>

    <div class="card account-section orders-empty-card">
      <h2>Paneli i porosive per admin po pergatitet.</h2>
      <p class="section-text">
        Tani per tani porosite menaxhohen nga perdoruesit dhe bizneset ne faqet e tyre perkatese.
      </p>
    </div>
  </section>
</template>
