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
  <div
    class="header-auth-dropdown"
    :class="{
      'header-auth-dropdown--expanded': props.expanded || isSignupMode,
      'header-auth-dropdown--standalone': props.standalone,
    }"
    @click.stop
  >
    <template v-if="!isAuthenticated">
      <div
        class="header-auth-card"
        :class="{
          'header-auth-card--signup': isSignupMode,
          'header-auth-card--expanded': props.expanded || props.standalone || props.showClose,
          'header-auth-card--tabbed': showTabbedAuth,
        }"
      >
        <button
          v-if="props.showClose"
          type="button"
          class="header-auth-close"
          aria-label="Close"
          @click="$emit('close')"
        >
          ×
        </button>

        <template v-if="showTabbedAuth">
          <div class="header-auth-tabs" role="tablist" aria-label="Authentication tabs">
            <button
              type="button"
              class="header-auth-tab"
              :class="{ 'is-active': mode === 'login' }"
              role="tab"
              :aria-selected="mode === 'login'"
              @click="setMode('login')"
            >
              Sign In
            </button>
            <button
              type="button"
              class="header-auth-tab"
              :class="{ 'is-active': mode === 'signup' }"
              role="tab"
              :aria-selected="mode === 'signup'"
              @click="setMode('signup')"
            >
              Sign Up
            </button>
          </div>

          <form v-if="mode === 'login'" class="header-auth-form" @submit.prevent="submitLoginForm">
            <label class="header-auth-field">
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

            <div class="header-auth-field-group">
              <div class="header-auth-field-row">
                <span>Password</span>
                <button type="button" class="header-auth-text-link" @click="setMode('forgot', false)">
                  Forgot Password
                </button>
              </div>
              <label class="header-auth-field header-auth-field--password">
                <input
                  v-model="loginForm.password"
                  :type="showLoginPassword ? 'text' : 'password'"
                  autocomplete="current-password"
                  placeholder="password"
                  required
                >
                <button
                  type="button"
                  class="header-auth-password-toggle"
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
              class="header-auth-primary header-auth-primary--login"
              type="submit"
              :disabled="ui.loading"
            >
              <span>{{ ui.loading ? "LOADING..." : "LOGIN" }}</span>
              <svg viewBox="0 0 24 24" aria-hidden="true">
                <path d="M5 12h14M13 5l6 7-6 7" />
              </svg>
            </button>
          </form>

          <form v-else class="header-auth-form" @submit.prevent="submitSignupForm">
            <div class="header-auth-two-cols">
              <label class="header-auth-field">
                <span>Full Name</span>
                <input
                  v-model="signupForm.fullName"
                  type="text"
                  autocomplete="name"
                  placeholder="Kevin Gilbert"
                  required
                >
              </label>

              <label class="header-auth-field">
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

            <label class="header-auth-field">
              <span>Email Address</span>
              <input
                v-model="signupForm.email"
                type="email"
                autocomplete="email"
                placeholder="name@example.com"
                required
              >
            </label>

            <div class="header-auth-two-cols">
              <label class="header-auth-field">
                <span>Birth Date</span>
                <input v-model="signupForm.birthDate" type="date" required>
              </label>

              <label class="header-auth-field">
                <span>Gender</span>
                <select v-model="signupForm.gender" required>
                  <option value="">Select</option>
                  <option value="mashkull">Male</option>
                  <option value="femer">Female</option>
                </select>
              </label>
            </div>

            <div class="header-auth-field-group">
              <span>Password</span>
              <label class="header-auth-field header-auth-field--password">
                <input
                  v-model="signupForm.password"
                  :type="showSignupPassword ? 'text' : 'password'"
                  autocomplete="new-password"
                  placeholder="Minimum 8 characters, number and symbol"
                  required
                >
                <button
                  type="button"
                  class="header-auth-password-toggle"
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

            <button class="header-auth-primary" type="submit" :disabled="ui.loading">
              <span>{{ ui.loading ? "LOADING..." : "CREATE ACCOUNT" }}</span>
              <svg viewBox="0 0 24 24" aria-hidden="true">
                <path d="M5 12h14M13 5l6 7-6 7" />
              </svg>
            </button>
          </form>

          <div class="header-auth-divider">
            <span>or</span>
          </div>

          <div class="header-auth-socials">
            <div v-if="googleEnabled" ref="googleButtonElement" class="header-auth-google-slot"></div>
            <button
              v-else
              type="button"
              class="header-auth-social-button"
              @click="showSocialAuthMessage('Google')"
            >
              <span class="header-auth-social-icon header-auth-social-icon--google">G</span>
              <span class="header-auth-social-label">
                {{ mode === "signup" ? "Sign Up With Google" : "Login With Google" }}
              </span>
              <span class="header-auth-social-spacer" aria-hidden="true"></span>
            </button>
            <button
              type="button"
              class="header-auth-social-button"
              @click="showSocialAuthMessage('Apple')"
            >
              <span class="header-auth-social-icon header-auth-social-icon--apple"></span>
              <span class="header-auth-social-label">
                {{ mode === "signup" ? "Sign Up With Apple" : "Login With Apple" }}
              </span>
              <span class="header-auth-social-spacer" aria-hidden="true"></span>
            </button>
          </div>
        </template>

        <template v-else-if="mode === 'forgot'">
          <div class="header-auth-inline-top">
            <button type="button" class="header-auth-back" @click="setMode('login', false)">
              ←
            </button>
            <h3>Forgot Password</h3>
          </div>

          <p class="header-auth-copy">
            Enter your email and we’ll send a reset code without leaving this page.
          </p>

          <form class="header-auth-form" @submit.prevent="submitForgotPasswordForm">
            <label class="header-auth-field">
              <span>Email Address</span>
              <input
                v-model="forgotForm.email"
                type="email"
                autocomplete="email"
                placeholder="name@example.com"
                required
              >
            </label>

            <button class="header-auth-primary" type="submit" :disabled="ui.loading">
              <span>{{ ui.loading ? "LOADING..." : "SEND CODE" }}</span>
              <svg viewBox="0 0 24 24" aria-hidden="true">
                <path d="M5 12h14M13 5l6 7-6 7" />
              </svg>
            </button>
          </form>
        </template>

        <template v-else-if="mode === 'reset'">
          <div class="header-auth-inline-top">
            <button type="button" class="header-auth-back" @click="setMode('forgot', false)">
              ←
            </button>
            <h3>Reset Password</h3>
          </div>

          <p class="header-auth-copy">
            Enter the 6-digit code and set a new password.
          </p>

          <form class="header-auth-form" @submit.prevent="submitResetPasswordForm">
            <label class="header-auth-field">
              <span>Email Address</span>
              <input
                v-model="resetForm.email"
                type="email"
                autocomplete="email"
                placeholder="name@example.com"
                required
              >
            </label>

            <label class="header-auth-field">
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

            <div class="header-auth-field-group">
              <span>New Password</span>
              <label class="header-auth-field header-auth-field--password">
                <input
                  v-model="resetForm.newPassword"
                  :type="showResetPassword ? 'text' : 'password'"
                  autocomplete="new-password"
                  placeholder="New password"
                  required
                >
                <button
                  type="button"
                  class="header-auth-password-toggle"
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

            <div class="header-auth-field-group">
              <span>Confirm Password</span>
              <label class="header-auth-field header-auth-field--password">
                <input
                  v-model="resetForm.confirmPassword"
                  :type="showResetConfirmPassword ? 'text' : 'password'"
                  autocomplete="new-password"
                  placeholder="Confirm password"
                  required
                >
                <button
                  type="button"
                  class="header-auth-password-toggle"
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

            <div class="header-auth-inline-actions">
              <button class="header-auth-primary" type="submit" :disabled="ui.loading">
                <span>{{ ui.loading ? "LOADING..." : "SAVE PASSWORD" }}</span>
                <svg viewBox="0 0 24 24" aria-hidden="true">
                  <path d="M5 12h14M13 5l6 7-6 7" />
                </svg>
              </button>
              <button class="header-auth-ghost" type="button" :disabled="ui.loading" @click="resendResetCode">
                RESEND CODE
              </button>
            </div>
          </form>
        </template>

        <p v-if="ui.message" class="header-auth-message" :class="`is-${ui.type}`">
          {{ ui.message }}
        </p>
      </div>
    </template>

    <template v-else>
      <div class="header-auth-card header-auth-card--menu">
        <p class="header-auth-eyebrow">Account</p>
        <h3 class="header-auth-menu-title">Hi, {{ welcomeName }}</h3>
        <div class="header-auth-menu">
          <button
            v-for="action in accountActions"
            :key="action.label"
            type="button"
            class="header-auth-menu-link"
            @click="openRoute(action.to)"
          >
            {{ action.label }}
          </button>
        </div>
        <button
          type="button"
          class="header-auth-primary header-auth-primary--danger"
          :disabled="ui.loading"
          @click="handleLogout"
        >
          <span>{{ ui.loading ? "LOADING..." : "LOG OUT" }}</span>
          <svg viewBox="0 0 24 24" aria-hidden="true">
            <path d="M5 12h14M13 5l6 7-6 7" />
          </svg>
        </button>
        <p v-if="ui.message" class="header-auth-message" :class="`is-${ui.type}`">
          {{ ui.message }}
        </p>
      </div>
    </template>
  </div>
</template>

<style scoped>
.header-auth-dropdown {
  width: min(432px, calc(100vw - 24px));
}

.header-auth-dropdown--expanded {
  width: min(432px, calc(100vw - 24px));
}

.header-auth-dropdown--standalone {
  width: min(432px, calc(100vw - 24px));
}

.header-auth-card {
  position: relative;
  display: grid;
  gap: 14px;
  background: #fff;
  border: 1px solid rgba(15, 23, 42, 0.09);
  border-radius: 6px;
  box-shadow: 0 18px 36px rgba(15, 23, 42, 0.08);
  max-height: min(86svh, 760px);
  overflow-x: hidden;
  overflow-y: auto;
  overscroll-behavior: contain;
  scrollbar-gutter: stable;
}

.header-auth-card--expanded {
  gap: 14px;
  border-radius: 6px;
  box-shadow: 0 22px 44px rgba(15, 23, 42, 0.12);
}

.header-auth-card--tabbed.header-auth-card--expanded {
  min-height: auto;
}

.header-auth-card--signup {
  max-height: min(86svh, 820px);
}

.header-auth-close {
  position: absolute;
  top: 12px;
  right: 12px;
  z-index: 2;
  display: inline-flex;
  width: 38px;
  height: 38px;
  align-items: center;
  justify-content: center;
  border: 0;
  background: rgba(255, 255, 255, 0.9);
  color: #1f2937;
  font-size: 1.5rem;
  cursor: pointer;
}

.header-auth-tabs {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  border-bottom: 1px solid rgba(15, 23, 42, 0.09);
  position: sticky;
  top: 0;
  z-index: 2;
  background: #fff;
}

.header-auth-tab {
  min-height: 48px;
  border: 0;
  border-bottom: 3px solid transparent;
  background: #fff;
  color: #7b8794;
  font-size: 0.94rem;
  font-weight: 700;
  cursor: pointer;
}

.header-auth-tab.is-active {
  color: #111827;
  border-bottom-color: #ff7f32;
}

.header-auth-form,
.header-auth-socials,
.header-auth-inline-top,
.header-auth-copy,
.header-auth-message,
.header-auth-menu,
.header-auth-eyebrow,
.header-auth-card h3 {
  margin-left: 28px;
  margin-right: 28px;
}

.header-auth-form,
.header-auth-socials,
.header-auth-menu {
  display: grid;
  gap: 12px;
}

.header-auth-socials,
.header-auth-menu {
  margin-bottom: 26px;
}

.header-auth-card--tabbed .header-auth-socials {
  gap: 8px;
  align-content: start;
}

.header-auth-card h3 {
  margin-top: 0;
  margin-bottom: 0;
  color: #111827;
  font-size: 1.2rem;
  font-weight: 800;
  text-align: center;
}

.header-auth-inline-top {
  display: flex;
  align-items: center;
  gap: 12px;
  padding-top: 22px;
}

.header-auth-inline-top h3 {
  margin: 0;
  text-align: left;
}

.header-auth-back {
  display: inline-flex;
  width: 36px;
  height: 36px;
  align-items: center;
  justify-content: center;
  border: 1px solid rgba(15, 23, 42, 0.12);
  background: #fff;
  color: #111827;
  font-size: 1.15rem;
  cursor: pointer;
}

.header-auth-copy {
  margin-top: -4px;
  margin-bottom: 0;
  color: #64748b;
  line-height: 1.6;
}

.header-auth-field,
.header-auth-field-group {
  display: grid;
  gap: 8px;
}

.header-auth-field span,
.header-auth-field-group > span,
.header-auth-field-row span {
  color: #374151;
  font-size: 0.82rem;
  font-weight: 700;
}

.header-auth-field-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

.header-auth-text-link {
  padding: 0;
  border: 0;
  background: transparent;
  color: #2f9cf3;
  font-size: 0.78rem;
  font-weight: 700;
  cursor: pointer;
}

.header-auth-field input,
.header-auth-field select {
  min-height: 36px;
  width: 100%;
  padding: 0 12px;
  border: 1px solid rgba(203, 213, 225, 0.9);
  background: #fff;
  color: #111827;
  font-size: 0.9rem;
  border-radius: 2px;
}

.header-auth-card--tabbed .header-auth-field,
.header-auth-card--tabbed .header-auth-field-group {
  gap: 6px;
}

.header-auth-card--tabbed .header-auth-field span,
.header-auth-card--tabbed .header-auth-field-group > span,
.header-auth-card--tabbed .header-auth-field-row span {
  font-size: 0.9rem;
}

.header-auth-card--tabbed .header-auth-field input,
.header-auth-card--tabbed .header-auth-field select {
  min-height: 34px;
  padding: 0 12px;
  font-size: 0.88rem;
  border-radius: 2px;
}

.header-auth-field input:focus,
.header-auth-field select:focus {
  outline: none;
  border-color: rgba(255, 127, 50, 0.8);
  box-shadow: 0 0 0 3px rgba(255, 127, 50, 0.08);
}

.header-auth-field--password {
  position: relative;
}

.header-auth-field--password input {
  padding-right: 50px;
}

.header-auth-card--tabbed .header-auth-field--password input {
  padding-right: 36px;
}

.header-auth-password-toggle {
  position: absolute;
  top: 50%;
  right: 12px;
  display: inline-flex;
  width: 22px;
  height: 22px;
  align-items: center;
  justify-content: center;
  border: 0;
  background: transparent;
  color: #4b5563;
  transform: translateY(-50%);
  cursor: pointer;
}

.header-auth-password-toggle svg {
  width: 16px;
  height: 16px;
  fill: none;
  stroke: currentColor;
  stroke-width: 1.8;
  stroke-linecap: round;
  stroke-linejoin: round;
}

.header-auth-two-cols {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 10px;
}

.header-auth-card--tabbed .header-auth-two-cols {
  gap: 8px;
}

.header-auth-primary,
.header-auth-social-button,
.header-auth-ghost,
.header-auth-menu-link {
  min-height: 36px;
  width: 100%;
  font-size: 0.84rem;
  font-weight: 800;
  cursor: pointer;
}

.header-auth-card--tabbed .header-auth-primary,
.header-auth-card--tabbed .header-auth-social-button {
  min-height: 36px;
  font-size: 0.84rem;
}

.header-auth-card--tabbed .header-auth-social-button,
.header-auth-card--tabbed .header-auth-google-slot {
  width: 100%;
  min-height: 36px;
  justify-self: center;
}

.header-auth-card--tabbed .header-auth-google-slot {
  display: flex;
  align-items: center;
}

.header-auth-card--tabbed .header-auth-social-button {
  box-sizing: border-box;
  height: 36px;
  gap: 10px;
  padding: 0 14px;
  font-size: 0.82rem;
  line-height: 1;
  white-space: nowrap;
  justify-content: flex-start;
  border-radius: 2px;
}

.header-auth-card--tabbed .header-auth-google-slot :deep(.nsm7Bb-HzV7m-LgbsSe-MJoBVe) {
  width: 100% !important;
  min-width: 0 !important;
  height: 36px !important;
  min-height: 36px !important;
  box-sizing: border-box !important;
  border-radius: 2px !important;
}

.header-auth-card--tabbed .header-auth-google-slot :deep(div[role="button"]) {
  width: 100% !important;
  height: 36px !important;
  min-height: 36px !important;
  border-radius: 2px !important;
}

.header-auth-card--tabbed .header-auth-social-icon {
  width: 18px;
  font-size: 1rem;
}

.header-auth-primary {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 12px;
  border: 0;
  background: #ff7f32;
  color: #fff;
  border-radius: 2px;
}

.header-auth-primary--login {
  width: 100%;
  min-height: 36px;
  padding: 0 12px;
  justify-self: center;
  border-radius: 2px;
}

.header-auth-primary svg {
  width: 16px;
  height: 16px;
  fill: none;
  stroke: currentColor;
  stroke-width: 1.9;
  stroke-linecap: round;
  stroke-linejoin: round;
}

.header-auth-primary:disabled,
.header-auth-ghost:disabled {
  cursor: wait;
  opacity: 0.72;
}

.header-auth-primary--danger {
  margin: 0 26px 24px;
}

.header-auth-divider {
  position: relative;
  margin: 0 28px;
  color: #7b8794;
  text-align: center;
}

.header-auth-divider::before {
  content: "";
  position: absolute;
  inset: 50% 0 auto;
  border-top: 1px solid rgba(15, 23, 42, 0.1);
}

.header-auth-divider span {
  position: relative;
  display: inline-block;
  padding: 0 14px;
  background: #fff;
  font-weight: 700;
}

.header-auth-google-slot {
  display: flex;
  justify-content: center;
  min-height: 36px;
}

.header-auth-google-slot :deep(div[role="button"]) {
  width: 100% !important;
  border-radius: 2px !important;
}

.header-auth-social-button {
  display: grid;
  grid-template-columns: 18px minmax(0, 1fr) 18px;
  align-items: center;
  gap: 10px;
  border: 1px solid rgba(203, 213, 225, 0.9);
  background: #fff;
  color: #475569;
  text-align: center;
}

.header-auth-social-icon {
  display: inline-flex;
  width: 18px;
  align-items: center;
  justify-content: center;
  font-size: 1rem;
  font-weight: 800;
  line-height: 1;
}

.header-auth-social-icon--google {
  color: #4285f4;
}

.header-auth-social-icon--apple {
  color: #111827;
}

.header-auth-social-label {
  display: block;
  min-width: 0;
  color: inherit;
  font-size: inherit;
  font-weight: 600;
  text-align: center;
  white-space: nowrap;
}

.header-auth-social-spacer {
  display: block;
  width: 18px;
  height: 18px;
  visibility: hidden;
}

.header-auth-inline-actions {
  display: grid;
  gap: 12px;
}

.header-auth-ghost {
  border: 1px solid rgba(15, 23, 42, 0.12);
  background: #fff;
  color: #475569;
}

.header-auth-message {
  margin-top: 0;
  margin-bottom: 30px;
  padding: 12px 14px;
  font-size: 0.95rem;
  line-height: 1.5;
}

.header-auth-message.is-error {
  background: #fff1f2;
  color: #be123c;
}

.header-auth-message.is-success {
  background: #eff6ff;
  color: #0f4c81;
}

.header-auth-card--menu {
  padding-top: 28px;
}

.header-auth-menu-title {
  margin-top: 0;
  margin-bottom: 0;
  color: #1f2937;
  font-size: 1.55rem;
  line-height: 1.15;
}

.header-auth-eyebrow {
  margin-top: 0;
  margin-bottom: -8px;
  color: #ff7f32;
  font-size: 0.82rem;
  font-weight: 800;
  letter-spacing: 0.1em;
  text-transform: uppercase;
}

.header-auth-menu-link {
  border: 1px solid rgba(15, 23, 42, 0.08);
  background: #fff;
  color: #1f2937;
}

@media (max-width: 640px) {
  .header-auth-dropdown,
  .header-auth-dropdown--expanded,
  .header-auth-dropdown--standalone {
    width: min(100vw - 16px, 432px);
  }

  .header-auth-form,
  .header-auth-socials,
  .header-auth-inline-top,
  .header-auth-copy,
  .header-auth-message,
  .header-auth-menu,
  .header-auth-eyebrow,
  .header-auth-card h3,
  .header-auth-divider {
    margin-left: 16px;
    margin-right: 16px;
  }

  .header-auth-primary--danger {
    margin-left: 16px;
    margin-right: 16px;
    margin-bottom: 16px;
  }

  .header-auth-two-cols {
    grid-template-columns: 1fr;
  }

  .header-auth-card,
  .header-auth-card--expanded {
    gap: 12px;
    max-height: min(90svh, 760px);
    border-radius: 6px;
  }

  .header-auth-card--tabbed.header-auth-card--expanded {
    min-height: auto;
  }

  .header-auth-tab {
    min-height: 46px;
    font-size: 0.9rem;
  }

  .header-auth-field-row {
    align-items: flex-start;
    flex-direction: column;
    gap: 8px;
  }

  .header-auth-close {
    top: 10px;
    right: 10px;
    width: 36px;
    height: 36px;
  }

  .header-auth-social-button {
    padding: 0 12px;
  }

  .header-auth-card--tabbed .header-auth-primary,
  .header-auth-card--tabbed .header-auth-social-button {
    min-height: 36px;
    font-size: 0.82rem;
  }

  .header-auth-card--tabbed .header-auth-field input,
  .header-auth-card--tabbed .header-auth-field select {
    min-height: 34px;
    padding: 0 10px;
    font-size: 0.86rem;
  }

  .header-auth-card--tabbed .header-auth-social-button,
  .header-auth-card--tabbed .header-auth-google-slot {
    width: 100%;
    min-height: 36px;
  }

  .header-auth-card--tabbed .header-auth-social-button {
    height: 36px;
  }

  .header-auth-card--tabbed .header-auth-socials {
    gap: 4px;
  }

  .header-auth-card--tabbed .header-auth-google-slot :deep(.nsm7Bb-HzV7m-LgbsSe-MJoBVe) {
    width: 100% !important;
    height: 36px !important;
    min-height: 36px !important;
  }

  .header-auth-card--tabbed .header-auth-google-slot :deep(div[role="button"]) {
    width: 100% !important;
    height: 36px !important;
    min-height: 36px !important;
  }

  .header-auth-primary--login {
    width: 100%;
  }
}
</style>
