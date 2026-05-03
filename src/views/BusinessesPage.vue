<script setup>
import { computed, onMounted, reactive, ref } from "vue";
import { RouterLink } from "vue-router";
import { requestJson, resolveApiMessage } from "../lib/api";
import { getBusinessProfileUrl } from "../lib/shop";
import { markRouteReady } from "../stores/app-state";

const businesses = ref([]);
const searchQuery = ref("");
const ui = reactive({
  loading: true,
  message: "",
  type: "",
});

const filteredBusinesses = computed(() => {
  const query = normalizeLookupValue(searchQuery.value);
  if (!query) {
    return businesses.value;
  }

  return businesses.value.filter((business) =>
    [
      business.businessName,
      business.businessDescription,
      business.city,
      business.addressLine,
      business.supportEmail,
    ]
      .map(normalizeLookupValue)
      .join(" ")
      .includes(query),
  );
});

onMounted(async () => {
  try {
    await loadBusinesses();
  } finally {
    ui.loading = false;
    markRouteReady();
  }
});

async function loadBusinesses() {
  const { response, data } = await requestJson("/api/businesses/public", {}, { cacheTtlMs: 30000 });
  if (!response.ok || !data?.ok) {
    ui.message = resolveApiMessage(data, "Bizneset nuk u ngarkuan.");
    ui.type = "error";
    businesses.value = [];
    return;
  }

  businesses.value = Array.isArray(data.businesses) ? data.businesses : [];
  ui.message = "";
  ui.type = "";
}

function normalizeLookupValue(value) {
  return String(value || "")
    .trim()
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "");
}

function getBusinessInitials(business) {
  const name = String(business?.businessName || "TG").trim();
  return name
    .split(/\s+/)
    .slice(0, 2)
    .map((part) => part.charAt(0).toUpperCase())
    .join("") || "TG";
}

function getBusinessLocation(business) {
  return [business?.city, business?.addressLine]
    .map((item) => String(item || "").trim())
    .filter(Boolean)
    .slice(0, 2)
    .join(" · ") || "TREGIO business";
}

function getBusinessCopy(business) {
  return String(business?.businessDescription || "").trim() || "Shfleto profilin publik dhe produktet aktive te ketij biznesi.";
}

function getBusinessProductsCount(business) {
  const count = Number(business?.productsCount || business?.publicProductsCount || 0);
  return Number.isFinite(count) ? Math.max(0, Math.trunc(count)) : 0;
}

function getBusinessProfileTarget(business) {
  return String(business?.profileUrl || "").trim() || getBusinessProfileUrl(business?.id);
}
</script>

<template>
  <section class="market-page market-page--wide businesses-page" aria-label="Business profiles">
    <header class="businesses-page__hero">
      <div>
        <p class="businesses-page__eyebrow">Business directory</p>
        <h1>Explore TREGIO businesses</h1>
        <p>Shiko profilet publike te bizneseve, produktet aktive dhe informacionin kryesor para se te blesh.</p>
      </div>

      <label class="businesses-page__search">
        <span>Search businesses</span>
        <input
          v-model="searchQuery"
          type="search"
          placeholder="Search by business, city, or category"
          autocomplete="off"
        >
      </label>
    </header>

    <div
      v-if="ui.message"
      class="market-status"
      :class="{ 'market-status--error': ui.type === 'error' }"
      role="status"
      aria-live="polite"
    >
      {{ ui.message }}
    </div>

    <div v-if="ui.loading" class="businesses-page__empty">
      Loading businesses...
    </div>

    <div v-else-if="businesses.length === 0" class="businesses-page__empty">
      Ende nuk ka biznese publike.
    </div>

    <div v-else-if="filteredBusinesses.length === 0" class="businesses-page__empty">
      Nuk u gjet asnje biznes per kete kerkim.
    </div>

    <div v-else class="businesses-page__grid" aria-live="polite">
      <RouterLink
        v-for="business in filteredBusinesses"
        :key="business.id"
        class="business-profile-card"
        :to="getBusinessProfileTarget(business)"
      >
        <span class="business-profile-card__logo">
          <img v-if="business.logoPath" :src="business.logoPath" :alt="business.businessName">
          <span v-else>{{ getBusinessInitials(business) }}</span>
        </span>

        <span class="business-profile-card__body">
          <strong>{{ business.businessName || "TREGIO business" }}</strong>
          <small>{{ getBusinessLocation(business) }}</small>
          <span>{{ getBusinessCopy(business) }}</span>
        </span>

        <span class="business-profile-card__meta">
          {{ getBusinessProductsCount(business) }} products
        </span>
      </RouterLink>
    </div>
  </section>
</template>

<style scoped>
.businesses-page {
  display: grid;
  gap: var(--space-6);
  padding-top: var(--space-8);
  padding-bottom: var(--space-16);
}

.businesses-page__hero {
  display: grid;
  grid-template-columns: minmax(0, 1fr) minmax(240px, 360px);
  align-items: end;
  gap: var(--space-6);
  padding-bottom: var(--space-6);
  border-bottom: 1px solid var(--color-border);
}

.businesses-page__eyebrow {
  margin: 0 0 8px;
  color: var(--color-primary);
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.businesses-page h1 {
  margin: 0;
  color: var(--color-text);
  font-size: clamp(2rem, 4vw, 3.5rem);
  line-height: 1;
  letter-spacing: -0.05em;
}

.businesses-page__hero p:not(.businesses-page__eyebrow) {
  max-width: 560px;
  margin: 12px 0 0;
  color: var(--color-muted);
  font-size: 15px;
  line-height: 1.65;
}

.businesses-page__search {
  display: grid;
  gap: 8px;
}

.businesses-page__search span {
  color: var(--color-muted);
  font-size: 12px;
  font-weight: 600;
}

.businesses-page__search input {
  width: 100%;
  min-height: var(--touch-target);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-pill);
  background: #fbfbfb;
  padding: 0 var(--space-4);
  color: var(--color-text);
  font-size: 14px;
  outline: none;
}

.businesses-page__search input:focus {
  border-color: var(--color-primary);
  background: #ffffff;
}

.businesses-page__grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
  gap: var(--space-4);
}

.business-profile-card {
  display: grid;
  grid-template-columns: 54px minmax(0, 1fr);
  gap: var(--space-4);
  min-height: 150px;
  padding: var(--space-4);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-card);
  background: var(--color-surface);
  color: var(--color-text);
  text-decoration: none;
  transition:
    border-color 160ms ease,
    transform 160ms ease;
}

.business-profile-card:hover {
  border-color: var(--color-primary-border);
  transform: translateY(-1px);
}

.business-profile-card__logo {
  width: 54px;
  height: 54px;
  overflow: hidden;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  border-radius: 14px;
  background: #f5f5f5;
  color: #111111;
  font-size: 14px;
  font-weight: 800;
}

.business-profile-card__logo img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.business-profile-card__body {
  min-width: 0;
  display: grid;
  gap: 5px;
}

.business-profile-card__body strong {
  overflow: hidden;
  color: #111111;
  font-size: 15px;
  font-weight: 700;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.business-profile-card__body small,
.business-profile-card__body span,
.business-profile-card__meta {
  color: #777777;
  font-size: 12px;
  line-height: 1.45;
}

.business-profile-card__body span {
  display: -webkit-box;
  overflow: hidden;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 2;
}

.business-profile-card__meta {
  grid-column: 2;
  align-self: end;
  width: fit-content;
  padding: 5px 9px;
  border-radius: 999px;
  background: #fff3ec;
  color: #d95716;
  font-weight: 700;
}

.businesses-page__empty {
  padding: 32px;
  border: 1px dashed #dddddd;
  border-radius: 16px;
  background: #fbfbfb;
  color: #666666;
  text-align: center;
  font-size: 14px;
}

@media (max-width: 760px) {
  .businesses-page__hero {
    grid-template-columns: 1fr;
    align-items: start;
  }

  .businesses-page__grid {
    grid-template-columns: 1fr;
  }
}
</style>
