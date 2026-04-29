<script setup>
import { computed, reactive, ref, watch } from "vue";
import { useRouter } from "vue-router";
import LiquidGlass from "../liquid-glass/components/LiquidGlass.vue";
import LiquidGlassNavSurface from "../components/LiquidGlassNavSurface.vue";
import {
  NAV_LIQUID_MODE_OPTIONS,
  readNavLiquidSettings,
  writeNavLiquidSettings,
} from "../lib/liquid-glass-nav-settings";
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

const navbarControls = reactive(readNavLiquidSettings());

const activeControls = computed(() =>
  activeTab.value === "userInfo" ? userInfoControls : logoutControls,
);

const activeModeLabel = computed(() => {
  const activeMode = activeTab.value === "navbar" ? navbarControls.mode : activeControls.value.mode;

  switch (activeMode) {
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

const navbarDisplacementLabel = computed(() => `${navbarControls.displacementScale}`);

watch(
  () => [navbarControls.mode, navbarControls.displacementScale],
  () => {
    writeNavLiquidSettings({
      mode: navbarControls.mode,
      displacementScale: navbarControls.displacementScale,
    });
  },
);
</script>

<template>
  <section class="market-page market-page--wide glass-page" aria-label="Liquid Glass">
    <header class="glass-page__hero">
      <div class="market-page__header-copy">
        <p>Eksperiment</p>
        <h1>Liquid Glass</h1>
        <p>
          Kjo faqe eshte preview i vecante per efektin liquid glass. Nuk ndryshon pjeset tjera te webfaqes.
        </p>
      </div>

      <div>
        <button class="market-button market-button--secondary" type="button" @click="router.back()">Mbyll</button>
      </div>
    </header>

    <section class="glass-workbench">
      <div class="glass-preview-card">
        <div ref="previewStageRef" class="glass-preview-stage">
          <div class="glass-preview-stage__panel" aria-hidden="true"></div>
          <div class="glass-preview-stage__brand" aria-hidden="true">TREGIO</div>
          <div class="glass-preview-stage__dot glass-preview-stage__dot--blue" aria-hidden="true"></div>
          <div class="glass-preview-stage__dot glass-preview-stage__dot--green" aria-hidden="true"></div>

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
           
          >
            <div class="glass-user-preview">
              <div class="glass-user-preview__identity">
                <div class="glass-user-preview__avatar">J</div>
                <div>
                  <strong>John Doe</strong>
                  <p>Software Engineer</p>
                </div>
              </div>

              <div class="glass-user-preview__facts">
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

          <LiquidGlassNavSurface
            v-else-if="activeTab === 'navbar'"
            class-name="glass-controls-preview-navbar-surface"
            :mouse-container="previewStageRef"
            :mode="navbarControls.mode"
            :displacement-scale="navbarControls.displacementScale"
            :blur-amount="0.1"
            :saturation="130"
            :aberration-intensity="2"
            :elasticity="0"
            :corner-radius="100"
            effect="liquidGlass"
           
          >
            <div class="glass-navbar-preview">
              <div>TREGIO</div>
              <div>
                <span>Veshje</span>
                <span>Beauty</span>
                <span>Tech</span>
              </div>
              <div>
                <span></span>
                <span></span>
                <span>Login</span>
              </div>
            </div>
          </LiquidGlassNavSurface>

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
           
          >
            <div class="glass-logout-preview">
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

          <div class="glass-preview-caption">
            <span>{{ activeTab === "userInfo" ? "User Info Card" : activeTab === "navbar" ? "Navbar Preview" : "Logout Button" }}</span>
            <strong>{{ activeModeLabel }}</strong>
          </div>
        </div>

        <div class="glass-controls">
          <div class="glass-tabs" role="tablist" aria-label="Liquid glass preview">
            <button
              class="glass-tab"
              :class="{ 'is-active': activeTab === 'userInfo' }"
              type="button"
              @click="activeTab = 'userInfo'"
            >
              User Info Card
            </button>
            <button
              class="glass-tab"
              :class="{ 'is-active': activeTab === 'logOut' }"
              type="button"
              @click="activeTab = 'logOut'"
            >
              Logout Button
            </button>
            <button
              class="glass-tab"
              :class="{ 'is-active': activeTab === 'navbar' }"
              type="button"
              @click="activeTab = 'navbar'"
            >
              Navbar
            </button>
          </div>

          <template v-if="activeTab === 'navbar'">
            <label class="glass-field">
              <span>Refraction mode</span>
              <select v-model="navbarControls.mode">
                <option
                  v-for="option in NAV_LIQUID_MODE_OPTIONS"
                  :key="option.value"
                  :value="option.value"
                >
                  {{ option.label }}
                </option>
              </select>
            </label>

            <label class="glass-field">
              <span>Displacement scale</span>
              <input v-model.number="navbarControls.displacementScale" type="range" min="0" max="300" step="1">
            </label>

            <label class="glass-field">
              <span>Scale value</span>
              <input v-model.number="navbarControls.displacementScale" type="number" min="0" max="1000" step="1">
            </label>

            <div class="glass-note">
              <strong>Navbar live settings</strong>
              <p>Keto vlera ruhen ne browser dhe aplikohen direkt te navbar-i i webfaqes.</p>
              <span>Displacement aktual: {{ navbarDisplacementLabel }}</span>
            </div>
          </template>

          <template v-else>
          <label class="glass-field">
            <span>Refraction mode</span>
            <select v-model="activeControls.mode">
              <option :value="GlassMode.standard">Standard</option>
              <option :value="GlassMode.polar">Polar</option>
              <option :value="GlassMode.prominent">Prominent</option>
              <option :value="GlassMode.shader">Shader</option>
            </select>
          </label>

          <div class="glass-field">
            <span>Effect type</span>
            <label
              v-for="effectType in effectList"
              :key="effectType"
              class="glass-radio"
            >
              <input v-model="effect" type="radio" name="effect" :value="effectType">
              <span>{{ effectNames[effectType] }}</span>
            </label>
          </div>

          <label class="glass-field">
            <span>Displacement scale</span>
            <input v-model.number="activeControls.displacementScale" type="range" min="0" max="200" step="1">
          </label>

          <label class="glass-field">
            <span>Blur amount</span>
            <input v-model.number="activeControls.blurAmount" type="range" min="0" max="1" step="0.01">
          </label>

          <label class="glass-field">
            <span>Saturation</span>
            <input v-model.number="activeControls.saturation" type="range" min="100" max="300" step="1">
          </label>

          <label class="glass-field">
            <span>Aberration intensity</span>
            <input
              v-model.number="activeControls.aberrationIntensity"
              type="range"
              min="0"
              max="20"
              step="0.5"
            >
          </label>

          <label class="glass-field">
            <span>Elasticity</span>
            <input v-model.number="activeControls.elasticity" type="range" min="0" max="1" step="0.01">
          </label>

          <label class="glass-field">
            <span>Corner radius</span>
            <input v-model.number="activeControls.cornerRadius" type="range" min="12" max="120" step="1">
          </label>

          <label class="glass-check">
            <input v-model="activeControls.overLight" type="checkbox">
            <span>Over light</span>
          </label>
          </template>
        </div>
      </div>
    </section>
  </section>
</template>

<style scoped>
.glass-page {
  display: grid;
  gap: 18px;
}

.glass-page__hero {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 18px;
  padding: 22px;
  border: 1px solid var(--dashboard-border);
  border-radius: var(--dashboard-radius);
  background:
    linear-gradient(135deg, rgba(37, 99, 235, 0.08), transparent 42%),
    linear-gradient(315deg, rgba(31, 138, 87, 0.08), transparent 38%),
    #ffffff;
}

.glass-page__hero .market-page__header-copy > p:first-child {
  margin: 0 0 6px;
  color: var(--dashboard-accent);
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.04em;
  text-transform: uppercase;
}

.glass-page__hero p {
  max-width: 700px;
  margin: 10px 0 0;
  color: var(--dashboard-muted);
  line-height: 1.55;
}

.glass-workbench {
  display: grid;
  grid-template-columns: minmax(0, 1.4fr) minmax(320px, 0.72fr);
  gap: 18px;
}

.glass-preview-card,
.glass-controls {
  border: 1px solid var(--dashboard-border);
  border-radius: var(--dashboard-radius);
  background: #ffffff;
}

.glass-preview-card {
  padding: 18px;
}

.glass-preview-stage {
  position: relative;
  min-height: 560px;
  overflow: hidden;
  display: grid;
  place-items: center;
  border-radius: 12px;
  background:
    linear-gradient(135deg, #eef4ff 0%, #ffffff 46%, #edfdf4 100%);
}

.glass-preview-stage__panel {
  position: absolute;
  inset: 34px;
  border: 1px solid rgba(17, 17, 17, 0.08);
  border-radius: 22px;
  background:
    linear-gradient(135deg, rgba(255, 255, 255, 0.6), rgba(255, 255, 255, 0.22)),
    repeating-linear-gradient(90deg, rgba(17, 17, 17, 0.035) 0 1px, transparent 1px 84px);
}

.glass-preview-stage__brand {
  position: absolute;
  top: 40px;
  left: 40px;
  color: rgba(17, 17, 17, 0.16);
  font-size: 42px;
  font-weight: 850;
}

.glass-preview-stage__dot {
  position: absolute;
  width: 96px;
  height: 96px;
  border-radius: 999px;
  opacity: 0.7;
}

.glass-preview-stage__dot--blue {
  right: 70px;
  top: 86px;
  background: #bfdbfe;
}

.glass-preview-stage__dot--green {
  left: 88px;
  bottom: 92px;
  background: #b7ebce;
}

.glass-user-preview,
.glass-navbar-preview,
.glass-logout-preview {
  color: #111111;
}

.glass-user-preview {
  width: min(420px, calc(100vw - 96px));
  display: grid;
  gap: 22px;
  padding: 24px;
}

.glass-user-preview__identity {
  display: flex;
  align-items: center;
  gap: 14px;
}

.glass-user-preview__avatar {
  width: 52px;
  height: 52px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  border-radius: 16px;
  background: #111111;
  color: #ffffff;
  font-weight: 800;
}

.glass-user-preview p,
.glass-user-preview span,
.glass-preview-caption span,
.glass-note p,
.glass-note span {
  margin: 0;
  color: var(--dashboard-muted);
  font-size: 13px;
  line-height: 1.45;
}

.glass-user-preview__facts {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 10px;
}

.glass-user-preview__facts div {
  display: grid;
  gap: 4px;
}

.glass-navbar-preview {
  width: min(640px, calc(100vw - 96px));
  display: grid;
  grid-template-columns: auto minmax(0, 1fr) auto;
  align-items: center;
  gap: 18px;
  padding: 12px 18px;
}

.glass-navbar-preview > div:first-child,
.glass-navbar-preview > div:last-child,
.glass-navbar-preview > div:nth-child(2) {
  display: flex;
  align-items: center;
  gap: 12px;
}

.glass-navbar-preview > div:first-child {
  font-weight: 850;
}

.glass-navbar-preview span {
  font-size: 13px;
  font-weight: 700;
}

.glass-navbar-preview > div:last-child span:empty {
  width: 28px;
  height: 28px;
  border-radius: 999px;
  background: rgba(17, 17, 17, 0.12);
}

.glass-logout-preview {
  display: inline-flex;
  align-items: center;
  gap: 10px;
  font-weight: 750;
}

.glass-logout-preview svg {
  width: 18px;
  height: 18px;
}

.glass-preview-caption {
  position: absolute;
  left: 24px;
  right: 24px;
  bottom: 24px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 12px 14px;
  border: 1px solid rgba(17, 17, 17, 0.08);
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.86);
}

.glass-controls {
  align-self: start;
  display: grid;
  gap: 16px;
  padding: 18px;
}

.glass-tabs {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 8px;
}

.glass-tab {
  min-height: 38px;
  border: 1px solid var(--dashboard-border);
  border-radius: 10px;
  background: #ffffff;
  color: var(--dashboard-muted);
  font-size: 12px;
  font-weight: 750;
  cursor: pointer;
}

.glass-tab.is-active {
  border-color: var(--dashboard-accent-border);
  background: var(--dashboard-accent-soft);
  color: var(--dashboard-accent);
}

.glass-field,
.glass-check,
.glass-note {
  display: grid;
  gap: 8px;
}

.glass-field > span,
.glass-check span {
  color: var(--dashboard-text);
  font-size: 13px;
  font-weight: 750;
}

.glass-field select,
.glass-field input[type="number"] {
  min-height: 40px;
  width: 100%;
  border: 1px solid var(--dashboard-border);
  border-radius: 10px;
  background: #ffffff;
  color: var(--dashboard-text);
}

.glass-field input[type="range"] {
  width: 100%;
}

.glass-radio,
.glass-check {
  display: flex;
  align-items: center;
  gap: 8px;
  color: var(--dashboard-muted);
  font-size: 13px;
}

.glass-note {
  padding: 14px;
  border: 1px solid var(--dashboard-accent-border);
  border-radius: 12px;
  background: var(--dashboard-accent-soft);
}

.glass-note strong {
  color: var(--dashboard-accent);
}

@media (max-width: 1100px) {
  .glass-workbench {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 720px) {
  .glass-page__hero {
    display: grid;
  }

  .glass-preview-stage {
    min-height: 460px;
  }

  .glass-tabs,
  .glass-user-preview__facts,
  .glass-navbar-preview {
    grid-template-columns: 1fr;
  }
}
</style>
