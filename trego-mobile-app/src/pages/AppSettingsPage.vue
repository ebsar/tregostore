<script setup lang="ts">
import { IonContent, IonIcon, IonPage } from "@ionic/vue";
import {
  moonOutline,
  notificationsOutline,
  personCircleOutline,
  shieldCheckmarkOutline,
  walletOutline,
} from "ionicons/icons";
import { computed, ref } from "vue";
import { useRouter } from "vue-router";
import AppPageHeader from "../components/AppPageHeader.vue";
import { useTheme } from "../composables/useTheme";
import { readMobilePreferences, writeMobilePreferences } from "../lib/preferences";
import { isPushConfigured, requestPushPermissionIfNeeded } from "../lib/push";

const router = useRouter();
const { themePreference, setThemePreference } = useTheme();
const preferences = ref(readMobilePreferences());
const canManagePush = computed(() => isPushConfigured());
const pushUi = ref({
  message: "",
  type: "",
});

const settingOptions = [
  {
    key: "theme",
    label: "Theme",
    icon: moonOutline,
    value: computed(() => themePreference.value),
    update: (value: string) => setThemePreference(value as "system" | "light" | "dark"),
    options: [
      { value: "system", label: "System" },
      { value: "light", label: "Light" },
      { value: "dark", label: "Dark" },
    ],
  },
  {
    key: "language",
    label: "Gjuha",
    icon: personCircleOutline,
    value: computed(() => preferences.value.language),
    update: (value: string) => {
      preferences.value = writeMobilePreferences({ language: value });
    },
    options: [
      { value: "sq", label: "Shqip" },
      { value: "en", label: "English" },
    ],
  },
  {
    key: "currency",
    label: "Valuta",
    icon: walletOutline,
    value: computed(() => preferences.value.currency),
    update: (value: string) => {
      preferences.value = writeMobilePreferences({ currency: value });
    },
    options: [
      { value: "EUR", label: "EUR" },
      { value: "USD", label: "USD" },
      { value: "CHF", label: "CHF" },
    ],
  },
  {
    key: "notificationMode",
    label: "Njoftimet",
    icon: notificationsOutline,
    value: computed(() => preferences.value.notificationMode),
    update: (value: string) => {
      preferences.value = writeMobilePreferences({ notificationMode: value });
    },
    options: [
      { value: "all", label: "Te gjitha" },
      { value: "orders", label: "Vetem porosi" },
      { value: "essential", label: "Essential" },
      { value: "off", label: "Off" },
    ],
  },
  {
    key: "privacyMode",
    label: "Privatësia",
    icon: shieldCheckmarkOutline,
    value: computed(() => preferences.value.privacyMode),
    update: (value: string) => {
      preferences.value = writeMobilePreferences({ privacyMode: value });
    },
    options: [
      { value: "standard", label: "Standard" },
      { value: "strict", label: "Strict" },
    ],
  },
] as const;

async function handleEnablePushNotifications() {
  const accepted = await requestPushPermissionIfNeeded(true, router);
  pushUi.value = {
    message: accepted
      ? "Njoftimet jane aktive ne kete pajisje."
      : "Leja per push nuk u aktivizua ende.",
    type: accepted ? "success" : "info",
  };
}
</script>

<template>
  <IonPage>
    <IonContent class="app-gradient" :fullscreen="true">
      <div class="mobile-page mobile-page--app-settings">
        <AppPageHeader
          kicker="App settings"
          title="Preferences"
          subtitle="Theme, gjuha, valuta, njoftimet dhe privatësia menaxhohen këtu, jo më në faqen kryesore të llogarisë."
          back-to="/tabs/account"
        />

        <section class="surface-card section-card app-settings-card">
          <div class="section-head app-settings-head">
            <div>
              <p class="section-kicker">Kontrollet</p>
              <h2>Zgjidhjet e app-it</h2>
            </div>
            <button
              v-if="canManagePush"
              class="settings-push-button"
              type="button"
              @click="handleEnablePushNotifications"
            >
              Push
            </button>
          </div>

          <div class="settings-select-list">
            <label
              v-for="setting in settingOptions"
              :key="setting.key"
              class="settings-select-row"
            >
              <span class="settings-select-label">
                <IonIcon :icon="setting.icon" />
                {{ setting.label }}
              </span>
              <select
                :value="setting.value.value"
                @change="setting.update(($event.target as HTMLSelectElement).value)"
              >
                <option
                  v-for="option in setting.options"
                  :key="`${setting.key}-${option.value}`"
                  :value="option.value"
                >
                  {{ option.label }}
                </option>
              </select>
            </label>
          </div>

          <p v-if="pushUi.message" class="settings-feedback" :class="`is-${pushUi.type}`">
            {{ pushUi.message }}
          </p>
        </section>
      </div>
    </IonContent>
  </IonPage>
</template>

<style scoped>
.mobile-page--app-settings {
  gap: 14px;
}

.app-settings-card {
  display: grid;
  gap: 14px;
}

.app-settings-head {
  align-items: center;
}

.settings-push-button {
  min-height: 34px;
  padding: 0 14px;
  border: 0;
  border-radius: 999px;
  background: rgba(255, 106, 43, 0.12);
  color: var(--trego-accent);
  font-size: 0.76rem;
  font-weight: 800;
}

.settings-select-list {
  display: grid;
  gap: 10px;
}

.settings-select-row {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto;
  gap: 10px;
  align-items: center;
  padding: 12px;
  border-radius: 18px;
  background: rgba(255, 255, 255, 0.66);
  border: 1px solid var(--trego-border);
}

.settings-select-label {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  color: var(--trego-dark);
  font-size: 0.82rem;
  font-weight: 700;
}

.settings-select-label ion-icon {
  color: var(--trego-accent);
  font-size: 1rem;
}

.settings-select-row select {
  min-width: 124px;
  min-height: 38px;
  padding: 0 10px;
  border-radius: 14px;
  border: 1px solid var(--trego-input-border);
  background: rgba(255, 255, 255, 0.88);
  color: var(--trego-dark);
  font-size: 0.78rem;
  font-weight: 700;
}

.settings-feedback {
  margin: 0;
  font-size: 0.8rem;
  line-height: 1.4;
}

.settings-feedback.is-success {
  color: #15803d;
}

.settings-feedback.is-info {
  color: var(--trego-muted);
}

@media (max-width: 420px) {
  .settings-select-row {
    grid-template-columns: 1fr;
  }

  .settings-select-row select {
    width: 100%;
    min-width: 0;
  }
}
</style>
