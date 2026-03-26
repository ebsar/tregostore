<template>
  <div class="app-loader" aria-hidden="true">
    <div class="app-loader-backdrop"></div>
    <div class="app-loader-glow app-loader-glow-left"></div>
    <div class="app-loader-glow app-loader-glow-right"></div>
    <div class="app-loader-panel">
      <div class="app-loader-stage">
        <div class="app-loader-orbit app-loader-orbit-outer"></div>
        <div class="app-loader-orbit app-loader-orbit-inner"></div>
        <div class="app-loader-orbit app-loader-orbit-core"></div>

        <div class="app-loader-centerpiece">
          <img class="app-loader-logo" src="/trego-logo.png" alt="TREGO">
          <span class="app-loader-center-shine"></span>
        </div>
      </div>

      <div class="app-loader-copy-block">
        <strong class="app-loader-brand">tregostore</strong>
        <p class="app-loader-copy">
          duke u ngarkuar
          <span class="app-loader-dots" aria-hidden="true">
            <span></span>
            <span></span>
            <span></span>
          </span>
        </p>
      </div>
    </div>
  </div>
</template>
