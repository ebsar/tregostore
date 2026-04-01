<script setup lang="ts">
import { computed } from "vue";
import type { BusinessItem } from "../types/models";
import { API_BASE_URL } from "../lib/config";

const props = defineProps<{
  business: BusinessItem;
}>();

const logoUrl = computed(() => {
  const path = String(props.business.logoPath || "").trim();
  if (!path) {
    return "https://images.unsplash.com/photo-1483985988355-763728e1935b?auto=format&fit=crop&w=800&q=80";
  }

  if (/^https?:\/\//i.test(path)) {
    return path;
  }

  return `${API_BASE_URL}${path.startsWith("/") ? path : `/${path}`}`;
});
</script>

<template>
  <article class="business-card-mobile surface-card">
    <img :src="logoUrl" :alt="business.businessName" />
    <div>
      <p class="business-card-mobile-kicker">{{ business.category || "Marke lokale" }}</p>
      <h3>{{ business.businessName }}</h3>
      <p>{{ business.description || "Profil publik me produkte reale, porosi dhe pickup options." }}</p>
    </div>
  </article>
</template>

<style scoped>
.business-card-mobile {
  display: grid;
  grid-template-columns: 76px minmax(0, 1fr);
  gap: 14px;
  padding: 12px;
}

.business-card-mobile img {
  width: 76px;
  height: 76px;
  border-radius: 22px;
  object-fit: cover;
}

.business-card-mobile-kicker {
  margin: 0 0 6px;
  color: var(--trego-accent);
  font-size: 0.74rem;
  font-weight: 800;
  text-transform: uppercase;
  letter-spacing: 0.08em;
}

.business-card-mobile h3 {
  margin: 0;
  color: var(--trego-dark);
  font-size: 1rem;
}

.business-card-mobile p:last-child {
  margin: 6px 0 0;
  color: var(--trego-muted);
  font-size: 0.84rem;
  line-height: 1.45;
}
</style>
