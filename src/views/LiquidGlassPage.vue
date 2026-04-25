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
  <section aria-label="Liquid Glass">
    <header>
      <div>
        <p>Eksperiment</p>
        <h1>Liquid Glass</h1>
        <p>
          Kjo faqe eshte preview i vecante per efektin liquid glass. Nuk ndryshon pjeset tjera te webfaqes.
        </p>
      </div>

      <div>
        <button type="button" @click="router.back()">Mbyll</button>
      </div>
    </header>

    <section>
      <div>
        <div ref="previewStageRef">
          <div aria-hidden="true"></div>
          <div aria-hidden="true">TREGIO</div>
          <div aria-hidden="true"></div>
          <div aria-hidden="true"></div>

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
            <div>
              <div>
                <div>J</div>
                <div>
                  <strong>John Doe</strong>
                  <p>Software Engineer</p>
                </div>
              </div>

              <div>
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
            <div>
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
            <div>
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

          <div>
            <span>{{ activeTab === "userInfo" ? "User Info Card" : activeTab === "navbar" ? "Navbar Preview" : "Logout Button" }}</span>
            <strong>{{ activeModeLabel }}</strong>
          </div>
        </div>

        <div>
          <div>
            <button
             
             
              type="button"
              @click="activeTab = 'userInfo'"
            >
              User Info Card
            </button>
            <button
             
             
              type="button"
              @click="activeTab = 'logOut'"
            >
              Logout Button
            </button>
            <button
             
             
              type="button"
              @click="activeTab = 'navbar'"
            >
              Navbar
            </button>
          </div>

          <template v-if="activeTab === 'navbar'">
            <label>
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

            <label>
              <span>Displacement scale</span>
              <input v-model.number="navbarControls.displacementScale" type="range" min="0" max="300" step="1">
            </label>

            <label>
              <span>Scale value</span>
              <input v-model.number="navbarControls.displacementScale" type="number" min="0" max="1000" step="1">
            </label>

            <div>
              <strong>Navbar live settings</strong>
              <p>Keto vlera ruhen ne browser dhe aplikohen direkt te navbar-i i webfaqes.</p>
              <span>Displacement aktual: {{ navbarDisplacementLabel }}</span>
            </div>
          </template>

          <template v-else>
          <label>
            <span>Refraction mode</span>
            <select v-model="activeControls.mode">
              <option :value="GlassMode.standard">Standard</option>
              <option :value="GlassMode.polar">Polar</option>
              <option :value="GlassMode.prominent">Prominent</option>
              <option :value="GlassMode.shader">Shader</option>
            </select>
          </label>

          <div>
            <span>Effect type</span>
            <label
              v-for="effectType in effectList"
              :key="effectType"
             
            >
              <input v-model="effect" type="radio" name="effect" :value="effectType">
              <span>{{ effectNames[effectType] }}</span>
            </label>
          </div>

          <label>
            <span>Displacement scale</span>
            <input v-model.number="activeControls.displacementScale" type="range" min="0" max="200" step="1">
          </label>

          <label>
            <span>Blur amount</span>
            <input v-model.number="activeControls.blurAmount" type="range" min="0" max="1" step="0.01">
          </label>

          <label>
            <span>Saturation</span>
            <input v-model.number="activeControls.saturation" type="range" min="100" max="300" step="1">
          </label>

          <label>
            <span>Aberration intensity</span>
            <input
              v-model.number="activeControls.aberrationIntensity"
              type="range"
              min="0"
              max="20"
              step="0.5"
            >
          </label>

          <label>
            <span>Elasticity</span>
            <input v-model.number="activeControls.elasticity" type="range" min="0" max="1" step="0.01">
          </label>

          <label>
            <span>Corner radius</span>
            <input v-model.number="activeControls.cornerRadius" type="range" min="12" max="120" step="1">
          </label>

          <label>
            <input v-model="activeControls.overLight" type="checkbox">
            <span>Over light</span>
          </label>
          </template>
        </div>
      </div>
    </section>
  </section>
</template>

