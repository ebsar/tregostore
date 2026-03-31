<script setup>
import { computed, reactive } from "vue";
import { useRouter } from "vue-router";
import LiquidGlass from "../liquid-glass/components/LiquidGlass.vue";
import { GlassMode } from "../liquid-glass/type";

const router = useRouter();

// Local-only controls: this page previews the material but does not change the rest of the site.
const controls = reactive({
  mode: GlassMode.standard,
  displacementScale: 80,
  blurAmount: 0.12,
  saturation: 150,
  aberrationIntensity: 2,
  cornerRadius: 28,
  overLight: false,
});

const modeLabel = computed(() => {
  switch (controls.mode) {
    case GlassMode.polar:
      return "Polar";
    case GlassMode.prominent:
      return "Prominent";
    case GlassMode.shader:
      return "Shader";
    case GlassMode.standard:
    default:
      return "Standard";
  }
});
</script>

<template>
  <section class="account-page" aria-label="Liquid Glass">
    <header class="account-header">
      <div>
        <p class="section-label">Eksperiment</p>
        <h1>Liquid Glass</h1>
        <p class="section-text">
          Kjo faqe eshte vetem preview. Nuk ndryshon asnje funksion te webfaqes.
        </p>
      </div>

      <div class="account-header-actions">
        <button class="ghost-button" type="button" @click="router.back()">Mbyll</button>
      </div>
    </header>

    <section class="card liquid-glass-sandbox-card">
      <div class="glass-controls-layout">
        <div class="glass-controls-preview-stage">
          <div class="glass-controls-preview-scene" aria-hidden="true"></div>
          <div class="glass-controls-preview-scene-text" aria-hidden="true">TREGO</div>

          <LiquidGlass
            class-name="glass-controls-preview-glass"
            :anchored="true"
            :mode="controls.mode"
            :displacement-scale="controls.displacementScale"
            :blur-amount="controls.blurAmount"
            :saturation="controls.saturation"
            :aberration-intensity="controls.aberrationIntensity"
            :corner-radius="controls.cornerRadius"
            :over-light="controls.overLight"
            padding="14px 16px"
            :style="{ position: 'absolute', left: '14px', right: '14px', top: '14px' }"
          >
            <div class="glass-controls-preview-row">
              <strong>Preview</strong>
              <span class="glass-controls-preview-pill">{{ modeLabel }}</span>
            </div>
          </LiquidGlass>
        </div>

        <div class="glass-controls-panel">
          <label class="field">
            <span>Refraction mode</span>
            <select v-model="controls.mode">
              <option :value="GlassMode.standard">Standard</option>
              <option :value="GlassMode.polar">Polar</option>
              <option :value="GlassMode.prominent">Prominent</option>
              <option :value="GlassMode.shader">Shader</option>
            </select>
          </label>

          <label class="field">
            <span>Displacement scale</span>
            <input v-model.number="controls.displacementScale" type="range" min="0" max="200" step="1">
          </label>

          <label class="field">
            <span>Blur amount</span>
            <input v-model.number="controls.blurAmount" type="range" min="0" max="1" step="0.01">
          </label>

          <label class="field">
            <span>Saturation</span>
            <input v-model.number="controls.saturation" type="range" min="100" max="300" step="1">
          </label>

          <label class="field">
            <span>Aberration intensity</span>
            <input v-model.number="controls.aberrationIntensity" type="range" min="0" max="20" step="0.5">
          </label>

          <label class="field">
            <span>Corner radius</span>
            <input v-model.number="controls.cornerRadius" type="range" min="12" max="56" step="1">
          </label>

          <label class="field" style="display: flex; align-items: center; gap: 10px;">
            <input v-model="controls.overLight" type="checkbox">
            <span style="margin: 0;">Over light</span>
          </label>
        </div>
      </div>
    </section>
  </section>
</template>

<style scoped>
.liquid-glass-sandbox-card {
  padding: 18px;
}

.glass-controls-layout {
  display: grid;
  grid-template-columns: minmax(0, 1.05fr) minmax(0, 0.95fr);
  gap: 18px;
  align-items: start;
}

.glass-controls-preview-stage {
  position: relative;
  min-height: 340px;
  border-radius: 28px;
  border: 1px solid rgba(47, 52, 70, 0.12);
  background: rgba(255, 255, 255, 0.92);
  overflow: hidden;
  box-shadow: 0 20px 44px rgba(31, 41, 55, 0.08);
}

.glass-controls-preview-scene {
  position: absolute;
  inset: 0;
  background:
    radial-gradient(120% 90% at 18% 20%, rgba(255, 106, 43, 0.14), rgba(255, 255, 255, 0) 62%),
    radial-gradient(100% 90% at 82% 14%, rgba(47, 52, 70, 0.1), rgba(255, 255, 255, 0) 62%),
    linear-gradient(180deg, rgba(245, 243, 241, 0.95), rgba(245, 243, 241, 0.6));
}

.glass-controls-preview-scene-text {
  position: absolute;
  inset: auto auto 18% -6%;
  font-size: clamp(4.2rem, 9vw, 7rem);
  font-weight: 900;
  letter-spacing: -0.08em;
  color: rgba(47, 52, 70, 0.12);
  transform: rotate(-4deg);
  user-select: none;
  pointer-events: none;
}

.glass-controls-preview-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  width: 100%;
  color: rgba(255, 255, 255, 0.9);
  font-weight: 800;
}

.glass-controls-preview-pill {
  display: inline-flex;
  align-items: center;
  padding: 6px 10px;
  border-radius: 999px;
  background: rgba(0, 0, 0, 0.18);
  border: 1px solid rgba(255, 255, 255, 0.18);
  color: rgba(255, 255, 255, 0.9);
  font-size: 0.78rem;
}

.glass-controls-panel {
  display: grid;
  gap: 12px;
  padding: 14px;
  border-radius: 22px;
  border: 1px solid rgba(47, 52, 70, 0.1);
  background: rgba(255, 255, 255, 0.86);
  box-shadow: 0 18px 40px rgba(31, 41, 55, 0.08);
}

@media (max-width: 920px) {
  .glass-controls-layout {
    grid-template-columns: minmax(0, 1fr);
  }
}
</style>
