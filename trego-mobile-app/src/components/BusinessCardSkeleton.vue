<template>
  <article class="business-card-skeleton surface-card">
    <div class="business-card-skeleton-head">
      <div class="business-card-skeleton-profile">
        <span class="business-card-skeleton-avatar mobile-shimmer" />
        <div class="business-card-skeleton-copy">
          <span class="business-card-skeleton-line medium mobile-shimmer" />
          <span class="business-card-skeleton-line short mobile-shimmer" />
        </div>
      </div>
      <div class="business-card-skeleton-actions">
        <span class="business-card-skeleton-pill mobile-shimmer" />
        <span class="business-card-skeleton-icon mobile-shimmer" />
      </div>
    </div>

    <div class="business-card-skeleton-rail">
      <span v-for="index in 3" :key="index" class="business-card-skeleton-product mobile-shimmer" />
    </div>
  </article>
</template>

<style scoped>
.business-card-skeleton {
  display: grid;
  gap: 14px;
  padding: 14px;
  border-radius: 28px;
}

.business-card-skeleton-head,
.business-card-skeleton-profile,
.business-card-skeleton-actions {
  display: flex;
  align-items: center;
}

.business-card-skeleton-head {
  justify-content: space-between;
  gap: 12px;
}

.business-card-skeleton-profile {
  min-width: 0;
  gap: 12px;
  flex: 1 1 auto;
}

.business-card-skeleton-avatar {
  display: block;
  width: 70px;
  height: 70px;
  border-radius: 24px;
}

.business-card-skeleton-copy {
  display: grid;
  gap: 8px;
  flex: 1 1 auto;
}

.business-card-skeleton-line,
.business-card-skeleton-pill,
.business-card-skeleton-icon,
.business-card-skeleton-product {
  display: block;
  border-radius: 999px;
}

.business-card-skeleton-line {
  height: 12px;
}

.business-card-skeleton-line.medium {
  width: 72%;
}

.business-card-skeleton-line.short {
  width: 44%;
}

.business-card-skeleton-actions {
  gap: 8px;
}

.business-card-skeleton-pill {
  width: 84px;
  height: 38px;
}

.business-card-skeleton-icon {
  width: 38px;
  height: 38px;
}

.business-card-skeleton-rail {
  display: grid;
  grid-auto-flow: column;
  grid-auto-columns: 110px;
  gap: 10px;
}

.business-card-skeleton-product {
  aspect-ratio: 0.82;
  border-radius: 18px;
}
</style>
