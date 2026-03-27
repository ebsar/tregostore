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
    }
  } finally {
    markRouteReady();
  }
});
</script>

<template>
  <section class="account-page orders-page" aria-label="Refund / Returne">
    <header class="account-header profile-page-header">
      <div>
        <p class="section-label">Mbeshtejtja</p>
        <h1>Refund / Returne</h1>
        <p class="section-text">
          Ketu do ta lidhim me vone procesin per kthimin ose rimbursimin e produkteve.
        </p>
      </div>
    </header>

    <div class="card account-section orders-empty-card">
      <h2>Ky seksion po pergatitet.</h2>
      <p class="section-text">
        Per momentin, nese ke nevoje per refund ose returne, kontakto biznesin nga profili i tij ose prit hapat e ardhshem te sistemit.
      </p>
    </div>
  </section>
</template>
