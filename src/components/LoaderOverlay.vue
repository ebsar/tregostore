<template>
  <div class="app-loader" aria-hidden="true">
    <div class="app-loader-backdrop"></div>
    <div class="app-loader-glow app-loader-glow-left"></div>
    <div class="app-loader-glow app-loader-glow-right"></div>
    <div class="app-loader-panel">
      <div class="app-loader-stage">
        <div class="app-loader-orbit app-loader-orbit-outer"></div>
        <div class="app-loader-orbit app-loader-orbit-inner"></div>

        <div class="app-loader-centerpiece">
          <div class="app-loader-logo-shell">
            <img class="app-loader-logo" src="/trego-logo.png" alt="TREGO">
          </div>
          <span class="app-loader-center-shine"></span>
        </div>

        <span class="app-loader-floating app-loader-floating-bag">
          <svg class="app-loader-icon" viewBox="0 0 24 24" aria-hidden="true">
            <path d="M7 8V7a5 5 0 0 1 10 0v1h2.3a1 1 0 0 1 1 .9l1.1 10a1 1 0 0 1-1 1.1H3.6a1 1 0 0 1-1-1.1l1.1-10a1 1 0 0 1 1-.9H7Zm2 0h6V7a3 3 0 0 0-6 0v1Z" />
          </svg>
        </span>
        <span class="app-loader-floating app-loader-floating-cart">
          <svg class="app-loader-icon" viewBox="0 0 24 24" aria-hidden="true">
            <path d="M3 5h2l2.1 9.1a1 1 0 0 0 1 .8h8.8a1 1 0 0 0 1-.8L20 8H7.2"></path>
            <circle cx="10" cy="19" r="1.4"></circle>
            <circle cx="18" cy="19" r="1.4"></circle>
          </svg>
        </span>
        <span class="app-loader-floating app-loader-floating-box">
          <svg class="app-loader-icon" viewBox="0 0 24 24" aria-hidden="true">
            <path d="m12 3 8 4.4v9.2L12 21l-8-4.4V7.4L12 3Zm0 2.2L6.3 8.1 12 11l5.7-2.9L12 5.2Zm-6 4.6v5.6l5 2.8v-5.6l-5-2.8Zm7 8.4 5-2.8V9.8l-5 2.8v5.6Z"></path>
          </svg>
        </span>
      </div>

      <div class="app-loader-copy-block">
        <p class="app-loader-eyebrow">TREGO STORE</p>
        <strong class="app-loader-brand">Po ngarkohet eksperienca e blerjes</strong>
        <p class="app-loader-copy">Duke sjelle produktet, bizneset dhe ofertat me te fundit...</p>
        <div class="app-loader-progress">
          <span class="app-loader-progress-bar"></span>
        </div>
      </div>
    </div>
  </div>
</template>
