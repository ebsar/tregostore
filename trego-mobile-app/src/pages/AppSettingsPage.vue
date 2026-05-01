<script setup lang="ts">
import { IonContent, IonIcon, IonPage } from "@ionic/vue";
import {
  moonOutline,
  notificationsOutline,
  personCircleOutline,
  shieldCheckmarkOutline,
  walletOutline,
} from "ionicons/icons";
import { computed, onMounted, ref } from "vue";
import { useRouter } from "vue-router";
import AppPageHeader from "../components/AppPageHeader.vue";
import { useTheme } from "../composables/useTheme";
import { readMobilePreferences, writeMobilePreferences } from "../lib/preferences";
import { getPushClientStatus, isPushConfigured, requestPushPermissionIfNeeded } from "../lib/push";

const router = useRouter();
const { themePreference, setThemePreference } = useTheme();
const preferences = ref(readMobilePreferences());
const canManagePush = computed(() => isPushConfigured());
const pushUi = ref({
  message: "",
  type: "",
});
const pushStatus = ref({
  configured: false,
  nativeRuntime: false,
  initialized: false,
  permission: "unavailable",
  subscribed: false,
  platform: "web",
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
  pushStatus.value = await getPushClientStatus(router);
  pushUi.value = {
    message: accepted
      ? "Njoftimet jane aktive ne kete pajisje."
      : "Leja per push nuk u aktivizua ende.",
    type: accepted ? "success" : "info",
  };
}

onMounted(async () => {
  pushStatus.value = await getPushClientStatus(router);
});
</script>

<template>
  <IonPage>
    <IonContent :fullscreen="true">
      <div class="trego-mobile-screen trego-settings-screen">
        <AppPageHeader
          kicker="App settings"
          title="Preferences"
          subtitle="Theme, gjuha, valuta, njoftimet dhe privatësia menaxhohen këtu, jo më në faqen kryesore të llogarisë."
          back-to="/tabs/account"
        />

        <section class="trego-settings-controls">
          <div>
            <div>
              <p>Kontrollet</p>
              <h2>Zgjidhjet e app-it</h2>
            </div>
            <button
              v-if="canManagePush"
             
              type="button"
              @click="handleEnablePushNotifications"
            >
              Push
            </button>
          </div>

          <div>
            <label
              v-for="setting in settingOptions"
              :key="setting.key"
             
            >
              <span>
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

          <p v-if="pushUi.message">
            {{ pushUi.message }}
          </p>
        </section>

        <section class="trego-settings-status">
          <div>
            <div>
              <p>Push status</p>
              <h2>APNs / FCM readiness</h2>
            </div>
          </div>

          <div>
            <div>
              <span>Provider</span>
              <strong>{{ pushStatus.configured ? "OneSignal → APNs/FCM" : "I pakonfiguruar" }}</strong>
            </div>
            <div>
              <span>Platforma</span>
              <strong>{{ pushStatus.platform }}</strong>
            </div>
            <div>
              <span>Permission</span>
              <strong>{{ pushStatus.permission }}</strong>
            </div>
            <div>
              <span>Subscription</span>
              <strong>{{ pushStatus.subscribed ? "Aktive" : "Jo aktive" }}</strong>
            </div>
          </div>

          <p>
            Push-et reale varen edhe nga konfigurimi i OneSignal, APNs per iOS, dhe FCM per Android.
          </p>
        </section>
      </div>
    </IonContent>
  </IonPage>
</template>
