<script setup>
import { computed, reactive, ref } from "vue";
import { useRouter } from "vue-router";
import LiquidGlass from "../liquid-glass/components/LiquidGlass.vue";
import { fragmentShaders } from "../liquid-glass/shader-util";
import { GlassMode } from "../liquid-glass/type";

const router = useRouter();
const previewStageRef = ref(null);
const activeTab = ref("userInfo");
const effect = ref(fragmentShaders.flowingLiquid);

const effectNames = {
  flowingLiquid: "Flowing Liquid",
  liquidGlass: "Liquid Glass",
  transparentIce: "Transparent Ice",
  unevenGlass: "Uneven Glass",
  mosaicGlass: "Mosaic Glass",
  liquidGlass2: "Liquid Glass 2",
};

const effectList = [
  fragmentShaders.flowingLiquid,
  fragmentShaders.liquidGlass,
  fragmentShaders.transparentIce,
  fragmentShaders.unevenGlass,
  fragmentShaders.mosaicGlass,
  fragmentShaders.liquidGlass2,
];

const userInfoControls = reactive({
  mode: GlassMode.standard,
  displacementScale: 100,
  blurAmount: 0.5,
  saturation: 140,
  aberrationIntensity: 2,
  elasticity: 0,
  cornerRadius: 32,
  overLight: false,
});

const logoutControls = reactive({
  mode: GlassMode.standard,
  displacementScale: 64,
  blurAmount: 0.1,
  saturation: 130,
  aberrationIntensity: 2,
  elasticity: 0.35,
  cornerRadius: 100,
  overLight: false,
});

const activeControls = computed(() =>
  activeTab.value === "userInfo" ? userInfoControls : logoutControls,
);

const activeModeLabel = computed(() => {
  switch (activeControls.value.mode) {
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
          Kjo faqe eshte preview i vecante per efektin liquid glass. Nuk ndryshon pjeset tjera te webfaqes.
        </p>
      </div>

      <div class="account-header-actions">
        <button class="ghost-button" type="button" @click="router.back()">Mbyll</button>
      </div>
    </header>

    <section class="card liquid-glass-sandbox-card">
      <div class="glass-controls-layout">
        <div ref="previewStageRef" class="glass-controls-preview-stage">
          <div class="glass-controls-preview-scene" aria-hidden="true"></div>
          <div class="glass-controls-preview-scene-text" aria-hidden="true">TREGO</div>
          <div class="glass-controls-preview-glow is-primary" aria-hidden="true"></div>
          <div class="glass-controls-preview-glow is-secondary" aria-hidden="true"></div>

          <LiquidGlass
            v-if="activeTab === 'userInfo'"
            class-name="glass-controls-preview-glass"
            :mouse-container="previewStageRef"
            :effect="effect"
            :mode="activeControls.mode"
            :displacement-scale="activeControls.displacementScale"
            :blur-amount="activeControls.blurAmount"
            :saturation="activeControls.saturation"
            :aberration-intensity="activeControls.aberrationIntensity"
            :elasticity="activeControls.elasticity"
            :corner-radius="activeControls.cornerRadius"
            :over-light="activeControls.overLight"
            :style="{ position: 'absolute', top: '50%', left: '50%' }"
          >
            <div class="glass-controls-user-card">
              <div class="glass-controls-user-head">
                <div class="glass-controls-avatar">J</div>
                <div>
                  <strong>John Doe</strong>
                  <p>Software Engineer</p>
                </div>
              </div>

              <div class="glass-controls-user-meta">
                <div>
                  <span>Email</span>
                  <strong>john@example.com</strong>
                </div>
                <div>
                  <span>Location</span>
                  <strong>Prishtine</strong>
                </div>
                <div>
                  <span>Joined</span>
                  <strong>March 2023</strong>
                </div>
              </div>
            </div>
          </LiquidGlass>

          <LiquidGlass
            v-else
            class-name="glass-controls-preview-glass"
            :mouse-container="previewStageRef"
            :effect="effect"
            :mode="activeControls.mode"
            :displacement-scale="activeControls.displacementScale"
            :blur-amount="activeControls.blurAmount"
            :saturation="activeControls.saturation"
            :aberration-intensity="activeControls.aberrationIntensity"
            :elasticity="activeControls.elasticity"
            :corner-radius="activeControls.cornerRadius"
            :over-light="activeControls.overLight"
            padding="8px 16px"
            :style="{ position: 'absolute', top: '50%', left: '50%' }"
          >
            <div class="glass-controls-logout">
              <span>Logout</span>
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" aria-hidden="true">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M17 16l4-4m0 0l-4-4m4 4H8m5 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1"
                />
              </svg>
            </div>
          </LiquidGlass>

          <div class="glass-controls-preview-footer">
            <span>{{ activeTab === "userInfo" ? "User Info Card" : "Logout Button" }}</span>
            <strong>{{ activeModeLabel }}</strong>
          </div>
        </div>

        <div class="glass-controls-panel">
          <div class="glass-controls-tab-row">
            <button
              class="glass-controls-tab"
              :class="{ 'is-active': activeTab === 'userInfo' }"
              type="button"
              @click="activeTab = 'userInfo'"
            >
              User Info Card
            </button>
            <button
              class="glass-controls-tab"
              :class="{ 'is-active': activeTab === 'logOut' }"
              type="button"
              @click="activeTab = 'logOut'"
            >
              Logout Button
            </button>
          </div>

          <label class="field">
            <span>Refraction mode</span>
            <select v-model="activeControls.mode">
              <option :value="GlassMode.standard">Standard</option>
              <option :value="GlassMode.polar">Polar</option>
              <option :value="GlassMode.prominent">Prominent</option>
              <option :value="GlassMode.shader">Shader</option>
            </select>
          </label>

          <div class="glass-controls-radio-group">
            <span class="glass-controls-radio-title">Effect type</span>
            <label
              v-for="effectType in effectList"
              :key="effectType"
              class="glass-controls-radio"
            >
              <input v-model="effect" type="radio" name="effect" :value="effectType">
              <span>{{ effectNames[effectType] }}</span>
            </label>
          </div>

          <label class="field">
            <span>Displacement scale</span>
            <input v-model.number="activeControls.displacementScale" type="range" min="0" max="200" step="1">
          </label>

          <label class="field">
            <span>Blur amount</span>
            <input v-model.number="activeControls.blurAmount" type="range" min="0" max="1" step="0.01">
          </label>

          <label class="field">
            <span>Saturation</span>
            <input v-model.number="activeControls.saturation" type="range" min="100" max="300" step="1">
          </label>

          <label class="field">
            <span>Aberration intensity</span>
            <input
              v-model.number="activeControls.aberrationIntensity"
              type="range"
              min="0"
              max="20"
              step="0.5"
            >
          </label>

          <label class="field">
            <span>Elasticity</span>
            <input v-model.number="activeControls.elasticity" type="range" min="0" max="1" step="0.01">
          </label>

          <label class="field">
            <span>Corner radius</span>
            <input v-model.number="activeControls.cornerRadius" type="range" min="12" max="120" step="1">
          </label>

          <label class="field glass-controls-checkbox">
            <input v-model="activeControls.overLight" type="checkbox">
            <span>Over light</span>
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
  grid-template-columns: minmax(0, 1.08fr) minmax(0, 0.92fr);
  gap: 18px;
  align-items: start;
}

.glass-controls-preview-stage {
  position: relative;
  min-height: 420px;
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
  inset: auto auto 15% -6%;
  font-size: clamp(4.4rem, 9vw, 7rem);
  font-weight: 900;
  letter-spacing: -0.08em;
  color: rgba(47, 52, 70, 0.1);
  transform: rotate(-4deg);
  user-select: none;
  pointer-events: none;
}

.glass-controls-preview-glow {
  position: absolute;
  border-radius: 999px;
  filter: blur(30px);
  opacity: 0.8;
  pointer-events: none;
}

.glass-controls-preview-glow.is-primary {
  width: 180px;
  height: 180px;
  left: -24px;
  top: -24px;
  background: rgba(255, 106, 43, 0.18);
}

.glass-controls-preview-glow.is-secondary {
  width: 220px;
  height: 220px;
  right: -36px;
  bottom: -56px;
  background: rgba(47, 52, 70, 0.14);
}

.glass-controls-user-card {
  width: 288px;
  color: rgba(255, 255, 255, 0.94);
}

.glass-controls-user-head {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-bottom: 16px;
}

.glass-controls-avatar {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 46px;
  height: 46px;
  border-radius: 999px;
  background: rgba(0, 0, 0, 0.18);
  border: 1px solid rgba(255, 255, 255, 0.18);
  font-weight: 800;
}

.glass-controls-user-head strong,
.glass-controls-user-meta strong {
  display: block;
  font-size: 0.98rem;
}

.glass-controls-user-head p,
.glass-controls-user-meta span {
  margin: 0;
  font-size: 0.78rem;
  color: rgba(255, 255, 255, 0.76);
}

.glass-controls-user-meta {
  display: grid;
  gap: 10px;
}

.glass-controls-logout {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  color: rgba(255, 255, 255, 0.94);
  font-weight: 700;
  font-size: 1rem;
}

.glass-controls-logout svg {
  width: 18px;
  height: 18px;
}

.glass-controls-preview-footer {
  position: absolute;
  left: 18px;
  right: 18px;
  bottom: 16px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  font-size: 0.84rem;
  color: rgba(47, 52, 70, 0.82);
}

.glass-controls-preview-footer strong {
  color: rgba(31, 41, 55, 0.92);
}

.glass-controls-panel {
  display: grid;
  gap: 14px;
  padding: 14px;
  border-radius: 22px;
  border: 1px solid rgba(47, 52, 70, 0.1);
  background: rgba(255, 255, 255, 0.86);
  box-shadow: 0 18px 40px rgba(31, 41, 55, 0.08);
}

.glass-controls-tab-row {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 8px;
}

.glass-controls-tab {
  min-height: 42px;
  border: 1px solid rgba(47, 52, 70, 0.1);
  border-radius: 14px;
  background: rgba(245, 243, 241, 0.85);
  color: rgba(31, 41, 55, 0.78);
  font-weight: 700;
  transition: 0.2s ease;
}

.glass-controls-tab.is-active {
  background: rgba(47, 52, 70, 0.94);
  border-color: rgba(47, 52, 70, 0.94);
  color: #fff;
}

.glass-controls-radio-group {
  display: grid;
  gap: 8px;
}

.glass-controls-radio-title {
  font-size: 0.88rem;
  font-weight: 700;
  color: rgba(31, 41, 55, 0.84);
}

.glass-controls-radio {
  display: flex;
  align-items: center;
  gap: 10px;
  min-height: 42px;
  padding: 0 12px;
  border-radius: 14px;
  background: rgba(245, 243, 241, 0.78);
  border: 1px solid rgba(47, 52, 70, 0.08);
  color: rgba(31, 41, 55, 0.78);
}

.glass-controls-checkbox {
  display: flex;
  align-items: center;
  gap: 10px;
}

.glass-controls-checkbox span {
  margin: 0;
}

@media (max-width: 920px) {
  .glass-controls-layout {
    grid-template-columns: minmax(0, 1fr);
  }

  .glass-controls-preview-stage {
    min-height: 360px;
  }
}

@media (max-width: 640px) {
  .liquid-glass-sandbox-card {
    padding: 14px;
  }

  .glass-controls-preview-stage {
    min-height: 320px;
  }

  .glass-controls-user-card {
    width: min(250px, 72vw);
  }

  .glass-controls-tab-row {
    grid-template-columns: minmax(0, 1fr);
  }
}
</style>
