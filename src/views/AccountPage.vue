<script setup>
import { computed, onMounted, reactive } from "vue";
import { useRouter } from "vue-router";
import { requestJson } from "../lib/api";
import { formatDateLabel } from "../lib/shop";
import { appState, ensureSessionLoaded, logoutUser, markRouteReady } from "../stores/app-state";

const router = useRouter();
const ui = reactive({
  message: "",
  type: "",
});

const roleLinks = computed(() => {
  if (!appState.user) {
    return [];
  }

  if (appState.user.role === "admin") {
    return [
      { href: "/admin-products", label: "Artikujt" },
      { href: "/bizneset-e-regjistruara", label: "Bizneset e regjistruara" },
    ];
  }

  if (appState.user.role === "business") {
    return [
      { href: "/biznesi-juaj", label: "Biznesi juaj" },
      { href: "/porosite-e-biznesit", label: "Porosite e biznesit" },
    ];
  }

  return [];
});

onMounted(async () => {
  try {
    const user = await ensureSessionLoaded();
    if (!user) {
      router.replace("/login");
      return;
    }
  } finally {
    markRouteReady();
  }
});

async function handleLogout() {
  ui.message = "";
  const { response, data } = await logoutUser();
  if (!response.ok || !data?.ok) {
    ui.message = data?.message || "Dalja nga llogaria nuk funksionoi.";
    ui.type = "error";
    return;
  }

  router.push(data.redirectTo || "/login");
}

async function handlePasswordChange(event) {
  event.preventDefault();
  ui.message = "";

  const formData = new FormData(event.currentTarget);
  const payload = {
    currentPassword: formData.get("currentPassword")?.toString() || "",
    newPassword: formData.get("newPassword")?.toString() || "",
    confirmPassword: formData.get("confirmPassword")?.toString() || "",
  };

  const { response, data } = await requestJson("/api/change-password", {
    method: "POST",
    body: JSON.stringify(payload),
  });

  if (!response.ok || !data?.ok) {
    ui.message = data?.errors?.join(" ") || data?.message || "Ndryshimi i fjalekalimit nuk funksionoi.";
    ui.type = "error";
    return;
  }

  ui.message = data.message || "Fjalekalimi u ndryshua me sukses.";
  ui.type = "success";
  event.currentTarget.reset();
  window.setTimeout(() => {
    router.push(data.redirectTo || "/login");
  }, 800);
}
</script>

<template>
  <section class="account-page" aria-label="Llogaria ime">
    <header class="account-header">
      <div>
        <p class="section-label">Llogaria ime</p>
        <h1>Menaxho profilin tend</h1>
        <p class="section-text">
          Ketu mund t'i shohesh te dhenat personale, adresat, porosite dhe te ndryshosh fjalekalimin.
        </p>
      </div>
    </header>

    <div class="form-message" :class="ui.type" role="status" aria-live="polite">
      {{ ui.message }}
    </div>

    <div class="account-layout" v-if="appState.user">
      <aside class="card account-sidebar">
        <div v-if="roleLinks.length > 0" class="account-nav-group">
          <p class="section-label account-nav-label">Roli yt</p>
          <a
            v-for="link in roleLinks"
            :key="link.href"
            class="account-nav-link"
            :href="link.href"
          >
            {{ link.label }}
          </a>
        </div>

        <div class="account-nav-group">
          <p class="section-label account-nav-label">Opsionet</p>
          <a class="account-nav-link" href="/te-dhenat-personale">Te dhenat personale</a>
          <a class="account-nav-link" href="/adresat">Adresat</a>
          <a class="account-nav-link" href="/porosite">Porosite</a>
          <a class="account-nav-link" href="/ndrysho-fjalekalimin">Ndryshimi i fjalekalimit</a>
        </div>

        <button class="account-nav-link account-nav-link-button" type="button" @click="handleLogout">
          Shkycu
        </button>
      </aside>

      <div class="account-sections">
        <section class="card account-section">
          <p class="section-label">Profili</p>
          <h2>Te dhenat personale</h2>
          <div class="account-info-grid">
            <div class="summary-chip">
              <span>Emri i plote</span>
              <strong>{{ appState.user.fullName }}</strong>
            </div>
            <div class="summary-chip">
              <span>Email</span>
              <strong>{{ appState.user.email }}</strong>
            </div>
            <div class="summary-chip">
              <span>Anetar qe nga</span>
              <strong>{{ formatDateLabel(appState.user.createdAt) }}</strong>
            </div>
          </div>
        </section>

        <section class="card account-section">
          <p class="section-label">Adresat</p>
          <h2>Adresat e ruajtura</h2>
          <p class="section-text">
            Shko te faqja e adresave per ta ruajtur ose ndryshuar adresen tende default.
          </p>
          <a class="nav-action nav-action-secondary" href="/adresat">Hape adresen</a>
        </section>

        <section class="card account-section">
          <p class="section-label">Porosite</p>
          <h2>Historia e porosive</h2>
          <p class="section-text">
            Te gjitha porosite e tua te konfirmuara dalin te faqja e porosive.
          </p>
          <a class="nav-action nav-action-secondary" href="/porosite">Shiko porosite</a>
        </section>

        <section class="card account-section">
          <p class="section-label">Siguria</p>
          <h2>Ndryshimi i fjalekalimit</h2>
          <form class="auth-form" @submit="handlePasswordChange">
            <label class="field">
              <span>Fjalekalimi aktual</span>
              <input name="currentPassword" type="password" placeholder="Shkruaje fjalekalimin aktual" required>
            </label>

            <label class="field">
              <span>Fjalekalimi i ri</span>
              <input name="newPassword" type="password" placeholder="Shkruaje fjalekalimin e ri" required>
            </label>

            <label class="field">
              <span>Konfirmo fjalekalimin e ri</span>
              <input name="confirmPassword" type="password" placeholder="Shkruaje perseri fjalekalimin e ri" required>
            </label>

            <button type="submit">Ruaje fjalekalimin e ri</button>
          </form>
        </section>
      </div>
    </div>
  </section>
</template>
