<template>
  <div class="app-loader" aria-hidden="true">
    <div class="app-loader-backdrop"></div>
    <div class="app-loader-panel">
      <div class="app-loader-icons">
        <div class="app-loader-icon-chip app-loader-icon-chip-bag">
          <svg class="app-loader-icon" viewBox="0 0 24 24" aria-hidden="true">
            <path d="M7 8h10l1 11H6z"></path>
            <path d="M9 9V7a3 3 0 0 1 6 0v2"></path>
          </svg>
        </div>

        <div class="app-loader-icon-chip app-loader-icon-chip-cart">
          <svg class="app-loader-icon" viewBox="0 0 24 24" aria-hidden="true">
            <path d="M3 5h2l2.1 9.1a1 1 0 0 0 1 .8h8.8a1 1 0 0 0 1-.8L20 8H7.2"></path>
            <circle cx="10" cy="19" r="1.4"></circle>
            <circle cx="18" cy="19" r="1.4"></circle>
          </svg>
        </div>

        <div class="app-loader-icon-chip app-loader-icon-chip-box">
          <svg class="app-loader-icon" viewBox="0 0 24 24" aria-hidden="true">
            <path d="M12 3 4.5 7v10L12 21l7.5-4V7z"></path>
            <path d="M12 21V11"></path>
            <path d="M4.5 7 12 11l7.5-4"></path>
          </svg>
        </div>
      </div>

      <strong class="app-loader-brand">Tregostore</strong>
      <p class="app-loader-copy">duke u ngarkuar</p>
    </div>
  </div>
</template>
