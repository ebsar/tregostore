<script setup>
import { computed, nextTick, onMounted, reactive, ref, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import { isGoogleWebAuthEnabled, renderGoogleAuthButton } from "../lib/google-auth";
import { requestJson, resolveApiMessage } from "../lib/api";
import { getVerifyEmailUrl, persistLoginGreeting } from "../lib/shop";
import { appState, applyAuthenticatedSession, logoutUser } from "../stores/app-state";

const props = defineProps({
  showClose: {
    type: Boolean,
    default: false,
  },
  expanded: {
    type: Boolean,
    default: false,
  },
  initialMode: {
    type: String,
    default: "login",
  },
  standalone: {
    type: Boolean,
    default: false,
  },
  syncRouteTabs: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(["close", "authenticated"]);

const route = useRoute();
const router = useRouter();

const loginForm = reactive({
  identifier: "",
  password: "",
});
const signupForm = reactive({
  fullName: "",
  email: "",
  phoneNumber: "",
  birthDate: "",
  gender: "",
  password: "",
});
const forgotForm = reactive({
  email: "",
});
const resetForm = reactive({
  email: "",
  code: "",
  newPassword: "",
  confirmPassword: "",
});

const ui = reactive({
  loading: false,
  message: "",
  type: "",
});

const mode = ref(normalizeMode(props.initialMode));
const showLoginPassword = ref(false);
const showSignupPassword = ref(false);
const showResetPassword = ref(false);
const showResetConfirmPassword = ref(false);
const googleButtonElement = ref(null);
const googleEnabled = isGoogleWebAuthEnabled();

const isAuthenticated = computed(() => Boolean(appState.user));
const welcomeName = computed(() =>
  String(appState.user?.fullName || appState.user?.businessName || appState.user?.firstName || "User").trim(),
);
const isSignupMode = computed(() => mode.value === "signup");
const showTabbedAuth = computed(() => ["login", "signup"].includes(mode.value));

const accountActions = computed(() => {
  if (!appState.user) {
    return [];
  }

  if (appState.user.role === "admin") {
    return [
      { label: "Dashboard", to: "/llogaria" },
    ];
  }

  if (appState.user.role === "business") {
    return [
      { label: "Dashboard", to: "/biznesi-juaj" },
    ];
  }

  return [
    { label: "Dashboard", to: "/llogaria" },
  ];
});

watch(
  () => props.initialMode,
  (nextMode) => {
    if (!["forgot", "reset"].includes(mode.value)) {
      mode.value = normalizeMode(nextMode);
    }
  },
);

watch(
  () => mode.value,
  async (nextMode) => {
    if (!googleEnabled || !["login", "signup"].includes(nextMode)) {
      return;
    }

    await nextTick();
    await renderGoogleButtonForMode();
  },
  { immediate: true },
);

onMounted(async () => {
  if (!googleEnabled || !["login", "signup"].includes(mode.value)) {
    return;
  }

  await nextTick();
  await renderGoogleButtonForMode();
});

function normalizeMode(value) {
  const normalized = String(value || "").trim().toLowerCase();
  return ["login", "signup", "forgot", "reset"].includes(normalized) ? normalized : "login";
}

function resetUiState() {
  ui.message = "";
  ui.type = "";
}

async function setMode(nextMode, syncTabs = true) {
  mode.value = normalizeMode(nextMode);
  resetUiState();

  if (!props.syncRouteTabs || !syncTabs || !["login", "signup"].includes(mode.value)) {
    return;
  }

  const targetPath = mode.value === "signup" ? "/signup" : "/login";
  if (route.path !== targetPath) {
    await router.replace({ path: targetPath, query: route.query });
  }
}

function isStrongPassword(password) {
  return (
    password.length >= 8
    && /[A-Za-z]/.test(password)
    && /\d/.test(password)
    && /[^A-Za-z0-9]/.test(password)
  );
}

function showSocialAuthMessage(provider) {
  ui.message = `${provider} auth po behet gati. Duhet te lidhen credential-et server-side per ta aktivizuar plotesisht.`;
  ui.type = "success";
}

async function renderGoogleButtonForMode() {
  if (!googleEnabled || !googleButtonElement.value) {
    return;
  }

  try {
    await renderGoogleAuthButton(
      googleButtonElement.value,
      handleGoogleCredential,
      {
        text: mode.value === "signup" ? "signup_with" : "continue_with",
        width: 365,
      },
    );
  } catch (error) {
    console.error(error);
  }
}

async function handleGoogleCredential(googleResponse) {
  const credential = String(googleResponse?.credential || "").trim();
  if (!credential) {
    ui.message = "Google auth nuk ktheu credential valide.";
    ui.type = "error";
    return;
  }

  ui.loading = true;
  resetUiState();

  try {
    const intent = mode.value === "signup" ? "signup" : "login";
    const { response, data } = await requestJson("/api/auth/google", {
      method: "POST",
      body: JSON.stringify({
        credential,
        intent,
      }),
    });

    if (!response.ok || !data?.ok) {
      ui.message = resolveApiMessage(data, "Google auth nuk funksionoi.");
      ui.type = "error";
      return;
    }

    ui.message = data.message || "U kyqe me sukses.";
    ui.type = "success";
    if (data.user) {
      persistLoginGreeting(data.user?.firstName || data.user?.fullName || "User");
      await applyAuthenticatedSession(data.user);
    }

    emit("authenticated");

    const redirectPath = String(route.query.redirect || "").trim();
    const shouldNavigate = props.standalone
      || ["/login", "/signup", "/verifiko-email"].includes(route.path)
      || Boolean(redirectPath);

    if (shouldNavigate) {
      await router.push(redirectPath || data.redirectTo || "/");
      return;
    }

    emit("close");
  } catch (error) {
    ui.message = "Serveri nuk po pergjigjet. Provoje perseri.";
    ui.type = "error";
    console.error(error);
  } finally {
    ui.loading = false;
  }
}

async function submitLoginForm() {
  ui.loading = true;
  resetUiState();

  try {
    const { response, data } = await requestJson("/api/login", {
      method: "POST",
      body: JSON.stringify({
        identifier: loginForm.identifier.trim(),
        password: loginForm.password,
      }),
    });

    if (!response.ok || !data?.ok) {
      ui.message = resolveApiMessage(data, "Kerkojme falje, por llogaria nuk ekziston.");
      ui.type = "error";
      if (data?.redirectTo) {
        emit("close");
        await router.push(data.redirectTo);
      }
      return;
    }

    ui.message = data.message || "U kyqe me sukses.";
    ui.type = "success";
    persistLoginGreeting(data.user?.firstName || data.user?.fullName || "User");
    await applyAuthenticatedSession(data.user || null);
    emit("authenticated");

    const redirectPath = String(route.query.redirect || "").trim();
    const shouldNavigate = props.standalone
      || ["/login", "/signup", "/verifiko-email"].includes(route.path)
      || Boolean(redirectPath);

    if (shouldNavigate) {
      await router.push(redirectPath || data.redirectTo || "/");
      return;
    }

    emit("close");
  } catch (error) {
    ui.message = "Serveri nuk po pergjigjet. Provoje perseri.";
    ui.type = "error";
    console.error(error);
  } finally {
    ui.loading = false;
  }
}

async function submitSignupForm() {
  ui.loading = true;
  resetUiState();
  const submittedEmail = signupForm.email.trim();

  if (!isStrongPassword(signupForm.password)) {
    ui.message = "Password duhet te kete minimum 8 karaktere, te pakten nje shkronje, nje numer dhe nje simbol.";
    ui.type = "error";
    ui.loading = false;
    return;
  }

  try {
    const { response, data } = await requestJson("/api/register", {
      method: "POST",
      body: JSON.stringify({
        fullName: signupForm.fullName.trim(),
        email: submittedEmail,
        phoneNumber: signupForm.phoneNumber.trim(),
        birthDate: signupForm.birthDate,
        gender: signupForm.gender,
        password: signupForm.password,
      }),
    });

    if (!response.ok || !data?.ok) {
      ui.message = resolveApiMessage(data, "Regjistrimi nuk funksionoi.");
      ui.type = "error";
      return;
    }

    const hasDeliveryWarnings = Array.isArray(data?.warnings) && data.warnings.length > 0;
    ui.message = data.message || "Llogaria u ruajt me sukses. Po kalon te verifikimi i email-it...";
    ui.type = hasDeliveryWarnings ? "error" : "success";

    if (hasDeliveryWarnings) {
      signupForm.password = "";
      return;
    }

    signupForm.fullName = "";
    signupForm.email = "";
    signupForm.phoneNumber = "";
    signupForm.birthDate = "";
    signupForm.gender = "";
    signupForm.password = "";

    emit("close");
    await router.push(data.redirectTo || getVerifyEmailUrl(submittedEmail));
  } catch (error) {
    ui.message = "Serveri nuk po pergjigjet. Provoje perseri.";
    ui.type = "error";
    console.error(error);
  } finally {
    ui.loading = false;
  }
}

async function submitForgotPasswordForm() {
  ui.loading = true;
  resetUiState();

  try {
    const { response, data } = await requestJson("/api/forgot-password", {
      method: "POST",
      body: JSON.stringify({ email: forgotForm.email.trim() }),
    });

    if (!response.ok || !data?.ok) {
      ui.message = resolveApiMessage(data, "Kerkesa nuk u dergua.");
      ui.type = "error";
      return;
    }

    resetForm.email = forgotForm.email.trim();
    resetForm.code = "";
    resetForm.newPassword = "";
    resetForm.confirmPassword = "";
    mode.value = "reset";
    ui.message = data.message || "Kodi u dergua me sukses.";
    ui.type = "success";
  } catch (error) {
    ui.message = "Serveri nuk po pergjigjet. Provoje perseri.";
    ui.type = "error";
    console.error(error);
  } finally {
    ui.loading = false;
  }
}

async function resendResetCode() {
  ui.loading = true;
  resetUiState();

  try {
    const { response, data } = await requestJson("/api/forgot-password", {
      method: "POST",
      body: JSON.stringify({ email: resetForm.email.trim() }),
    });

    if (!response.ok || !data?.ok) {
      ui.message = resolveApiMessage(data, "Kodi i ri nuk u dergua.");
      ui.type = "error";
      return;
    }

    ui.message = data.message || "Kodi i ri u dergua me sukses.";
    ui.type = "success";
  } catch (error) {
    ui.message = "Serveri nuk po pergjigjet. Provoje perseri.";
    ui.type = "error";
    console.error(error);
  } finally {
    ui.loading = false;
  }
}

async function submitResetPasswordForm() {
  ui.loading = true;
  resetUiState();

  try {
    const { response, data } = await requestJson("/api/password-reset/confirm", {
      method: "POST",
      body: JSON.stringify({
        email: resetForm.email.trim(),
        code: resetForm.code.trim(),
        newPassword: resetForm.newPassword,
        confirmPassword: resetForm.confirmPassword,
      }),
    });

    if (!response.ok || !data?.ok) {
      ui.message = resolveApiMessage(data, "Ndryshimi i fjalekalimit nuk funksionoi.");
      ui.type = "error";
      return;
    }

    loginForm.identifier = resetForm.email.trim();
    loginForm.password = "";
    forgotForm.email = "";
    resetForm.email = "";
    resetForm.code = "";
    resetForm.newPassword = "";
    resetForm.confirmPassword = "";
    mode.value = "login";
    ui.message = data.message || "Fjalekalimi u ndryshua. Tani mund te kyçesh.";
    ui.type = "success";
  } catch (error) {
    ui.message = "Serveri nuk po pergjigjet. Provoje perseri.";
    ui.type = "error";
    console.error(error);
  } finally {
    ui.loading = false;
  }
}

async function handleLogout() {
  ui.loading = true;
  resetUiState();

  try {
    const { response, data } = await logoutUser();
    if (!response.ok || !data?.ok) {
      ui.message = data?.message || "Dalja nga llogaria deshtoi. Provoje perseri.";
      ui.type = "error";
      return;
    }

    emit("close");
    await router.push("/");
  } catch (error) {
    ui.message = "Dalja nga llogaria deshtoi. Provoje perseri.";
    ui.type = "error";
    console.error(error);
  } finally {
    ui.loading = false;
  }
}

async function openRoute(target) {
  emit("close");
  await router.push(target);
}
</script>

<template>
  <div class="overlay-panel overlay-panel--wide" @click.stop>
    <template v-if="!isAuthenticated">
      <div class="auth-panel">
        <button
          v-if="props.showClose"
          type="button"
          class="market-icon-button auth-panel__close"
          aria-label="Close"
          @click="$emit('close')"
        >
          ×
        </button>

        <template v-if="showTabbedAuth">
          <div class="auth-panel__tabs" role="tablist" aria-label="Authentication tabs">
            <button
              type="button"
              role="tab"
              :aria-selected="mode === 'login'"
              @click="setMode('login')"
            >
              Sign In
            </button>
            <button
              type="button"
             
             
              role="tab"
              :aria-selected="mode === 'signup'"
              @click="setMode('signup')"
            >
              Sign Up
            </button>
          </div>

          <form v-if="mode === 'login'" class="auth-panel__form" @submit.prevent="submitLoginForm">
            <label class="auth-panel__field">
              <span>Email Address</span>
              <input
                v-model="loginForm.identifier"
                type="text"
                inputmode="email"
                autocomplete="username"
                placeholder="name@example.com"
                required
              >
            </label>

            <div class="auth-panel__stack">
              <div class="auth-panel__inline">
                <span>Password</span>
                <button class="market-button market-button--ghost" type="button" @click="setMode('forgot', false)">
                  Forgot Password
                </button>
              </div>
              <label class="auth-panel__field auth-panel__password">
                <input
                  v-model="loginForm.password"
                  :type="showLoginPassword ? 'text' : 'password'"
                  autocomplete="current-password"
                  placeholder="password"
                  required
                >
                <button
                  type="button"
                  class="market-icon-button"
                  :aria-label="showLoginPassword ? 'Hide password' : 'Show password'"
                  @click="showLoginPassword = !showLoginPassword"
                >
                  <svg viewBox="0 0 24 24" aria-hidden="true">
                    <path
                      d="M2 12s3.6-6 10-6 10 6 10 6-3.6 6-10 6-10-6-10-6Z M12 15.2A3.2 3.2 0 1 0 12 8.8a3.2 3.2 0 0 0 0 6.4Z"
                    />
                  </svg>
                </button>
              </label>
            </div>

            <button
              class="market-button market-button--primary"
              type="submit"
              :disabled="ui.loading"
            >
              <span>{{ ui.loading ? "LOADING..." : "LOGIN" }}</span>
              <svg viewBox="0 0 24 24" aria-hidden="true">
                <path d="M5 12h14M13 5l6 7-6 7" />
              </svg>
            </button>
          </form>

          <form v-else class="auth-panel__form" @submit.prevent="submitSignupForm">
            <div class="auth-panel__form-row">
              <label class="auth-panel__field">
                <span>Full Name</span>
                <input
                  v-model="signupForm.fullName"
                  type="text"
                  autocomplete="name"
                  placeholder="Kevin Gilbert"
                  required
                >
              </label>

              <label class="auth-panel__field">
                <span>Phone Number</span>
                <input
                  v-model="signupForm.phoneNumber"
                  type="tel"
                  autocomplete="tel"
                  placeholder="+383 44 123 456"
                  required
                >
              </label>
            </div>

            <label class="auth-panel__field">
              <span>Email Address</span>
              <input
                v-model="signupForm.email"
                type="email"
                autocomplete="email"
                placeholder="name@example.com"
                required
              >
            </label>

            <div class="auth-panel__form-row">
              <label class="auth-panel__field">
                <span>Birth Date</span>
                <input v-model="signupForm.birthDate" type="date" required>
              </label>

              <label class="auth-panel__field">
                <span>Gender</span>
                <select v-model="signupForm.gender" required>
                  <option value="">Select</option>
                  <option value="mashkull">Male</option>
                  <option value="femer">Female</option>
                </select>
              </label>
            </div>

            <div class="auth-panel__stack">
              <span>Password</span>
              <label class="auth-panel__field auth-panel__password">
                <input
                  v-model="signupForm.password"
                  :type="showSignupPassword ? 'text' : 'password'"
                  autocomplete="new-password"
                  placeholder="Minimum 8 characters, number and symbol"
                  required
                >
                <button
                  type="button"
                  class="market-icon-button"
                  :aria-label="showSignupPassword ? 'Hide password' : 'Show password'"
                  @click="showSignupPassword = !showSignupPassword"
                >
                  <svg viewBox="0 0 24 24" aria-hidden="true">
                    <path
                      d="M2 12s3.6-6 10-6 10 6 10 6-3.6 6-10 6-10-6-10-6Z M12 15.2A3.2 3.2 0 1 0 12 8.8a3.2 3.2 0 0 0 0 6.4Z"
                    />
                  </svg>
                </button>
              </label>
            </div>

            <button class="market-button market-button--primary" type="submit" :disabled="ui.loading">
              <span>{{ ui.loading ? "LOADING..." : "CREATE ACCOUNT" }}</span>
              <svg viewBox="0 0 24 24" aria-hidden="true">
                <path d="M5 12h14M13 5l6 7-6 7" />
              </svg>
            </button>
          </form>

          <div class="auth-panel__divider">
            <span>or</span>
          </div>

          <div class="auth-panel__socials">
            <div v-if="googleEnabled" ref="googleButtonElement"></div>
            <button
              v-else
              type="button"
              class="market-button market-button--secondary auth-panel__social-button"
              @click="showSocialAuthMessage('Google')"
            >
              <span>G</span>
              <span>
                {{ mode === "signup" ? "Sign Up With Google" : "Login With Google" }}
              </span>
              <span aria-hidden="true"></span>
            </button>
            <button
              type="button"
              class="market-button market-button--secondary auth-panel__social-button"
              @click="showSocialAuthMessage('Apple')"
            >
              <span></span>
              <span>
                {{ mode === "signup" ? "Sign Up With Apple" : "Login With Apple" }}
              </span>
              <span aria-hidden="true"></span>
            </button>
          </div>
        </template>

        <template v-else-if="mode === 'forgot'">
          <div class="auth-panel__inline">
            <button class="market-button market-button--ghost" type="button" @click="setMode('login', false)">
              ←
            </button>
            <h3>Forgot Password</h3>
          </div>

          <p>
            Enter your email and we’ll send a reset code without leaving this page.
          </p>

          <form class="auth-panel__form" @submit.prevent="submitForgotPasswordForm">
            <label class="auth-panel__field">
              <span>Email Address</span>
              <input
                v-model="forgotForm.email"
                type="email"
                autocomplete="email"
                placeholder="name@example.com"
                required
              >
            </label>

            <button class="market-button market-button--primary" type="submit" :disabled="ui.loading">
              <span>{{ ui.loading ? "LOADING..." : "SEND CODE" }}</span>
              <svg viewBox="0 0 24 24" aria-hidden="true">
                <path d="M5 12h14M13 5l6 7-6 7" />
              </svg>
            </button>
          </form>
        </template>

        <template v-else-if="mode === 'reset'">
          <div class="auth-panel__inline">
            <button class="market-button market-button--ghost" type="button" @click="setMode('forgot', false)">
              ←
            </button>
            <h3>Reset Password</h3>
          </div>

          <p>
            Enter the 6-digit code and set a new password.
          </p>

          <form class="auth-panel__form" @submit.prevent="submitResetPasswordForm">
            <label class="auth-panel__field">
              <span>Email Address</span>
              <input
                v-model="resetForm.email"
                type="email"
                autocomplete="email"
                placeholder="name@example.com"
                required
              >
            </label>

            <label class="auth-panel__field">
              <span>Reset Code</span>
              <input
                v-model="resetForm.code"
                type="text"
                inputmode="numeric"
                maxlength="6"
                placeholder="123456"
                required
              >
            </label>

            <div class="auth-panel__stack">
              <span>New Password</span>
              <label class="auth-panel__field auth-panel__password">
                <input
                  v-model="resetForm.newPassword"
                  :type="showResetPassword ? 'text' : 'password'"
                  autocomplete="new-password"
                  placeholder="New password"
                  required
                >
                <button
                  type="button"
                  class="market-icon-button"
                  :aria-label="showResetPassword ? 'Hide password' : 'Show password'"
                  @click="showResetPassword = !showResetPassword"
                >
                  <svg viewBox="0 0 24 24" aria-hidden="true">
                    <path
                      d="M2 12s3.6-6 10-6 10 6 10 6-3.6 6-10 6-10-6-10-6Z M12 15.2A3.2 3.2 0 1 0 12 8.8a3.2 3.2 0 0 0 0 6.4Z"
                    />
                  </svg>
                </button>
              </label>
            </div>

            <div class="auth-panel__stack">
              <span>Confirm Password</span>
              <label class="auth-panel__field auth-panel__password">
                <input
                  v-model="resetForm.confirmPassword"
                  :type="showResetConfirmPassword ? 'text' : 'password'"
                  autocomplete="new-password"
                  placeholder="Confirm password"
                  required
                >
                <button
                  type="button"
                  class="market-icon-button"
                  :aria-label="showResetConfirmPassword ? 'Hide password' : 'Show password'"
                  @click="showResetConfirmPassword = !showResetConfirmPassword"
                >
                  <svg viewBox="0 0 24 24" aria-hidden="true">
                    <path
                      d="M2 12s3.6-6 10-6 10 6 10 6-3.6 6-10 6-10-6-10-6Z M12 15.2A3.2 3.2 0 1 0 12 8.8a3.2 3.2 0 0 0 0 6.4Z"
                    />
                  </svg>
                </button>
              </label>
            </div>

            <div class="auth-form__actions">
              <button class="market-button market-button--primary" type="submit" :disabled="ui.loading">
                <span>{{ ui.loading ? "LOADING..." : "SAVE PASSWORD" }}</span>
                <svg viewBox="0 0 24 24" aria-hidden="true">
                  <path d="M5 12h14M13 5l6 7-6 7" />
                </svg>
              </button>
              <button class="market-button market-button--secondary" type="button" :disabled="ui.loading" @click="resendResetCode">
                RESEND CODE
              </button>
            </div>
          </form>
        </template>

        <p
          v-if="ui.message"
          :class="['market-status', ui.type === 'error' ? 'market-status--error' : ui.type === 'success' ? 'market-status--success' : '']"
        >
          {{ ui.message }}
        </p>
      </div>
    </template>

    <template v-else>
      <div class="auth-panel">
        <p>Account</p>
        <h3>Hi, {{ welcomeName }}</h3>
        <div class="auth-panel__stack">
          <button
            v-for="action in accountActions"
            :key="action.label"
            type="button"
            class="market-button market-button--secondary"
            @click="openRoute(action.to)"
          >
            {{ action.label }}
          </button>
        </div>
        <button
          type="button"
          class="market-button market-button--primary"
          :disabled="ui.loading"
          @click="handleLogout"
        >
          <span>{{ ui.loading ? "LOADING..." : "LOG OUT" }}</span>
          <svg viewBox="0 0 24 24" aria-hidden="true">
            <path d="M5 12h14M13 5l6 7-6 7" />
          </svg>
        </button>
        <p
          v-if="ui.message"
          :class="['market-status', ui.type === 'error' ? 'market-status--error' : ui.type === 'success' ? 'market-status--success' : '']"
        >
          {{ ui.message }}
        </p>
      </div>
    </template>
  </div>
</template>
