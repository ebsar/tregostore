<script setup>
import { onMounted, reactive } from "vue";
import { useRouter } from "vue-router";
import AuthField from "../components/auth/AuthField.vue";
import AuthPrimaryButton from "../components/auth/AuthPrimaryButton.vue";
import AuthSelectField from "../components/auth/AuthSelectField.vue";
import AuthShell from "../components/auth/AuthShell.vue";
import { requestJson, resolveApiMessage } from "../lib/api";
import { getVerifyEmailUrl } from "../lib/shop";
import { ensureSessionLoaded, markRouteReady } from "../stores/app-state";

const router = useRouter();
const form = reactive({
  fullName: "",
  email: "",
  phoneNumber: "",
  birthDate: "",
  gender: "",
  password: "",
  marketingEmailsOptIn: false,
  termsAccepted: false,
});
const ui = reactive({
  loading: false,
  message: "",
  type: "",
});

onMounted(async () => {
  try {
    const user = await ensureSessionLoaded();
    if (user) {
      await router.replace("/");
      return;
    }
  } finally {
    markRouteReady();
  }
});

function isStrongPassword(password) {
  return (
    password.length >= 8
    && /[A-Za-z]/.test(password)
    && /\d/.test(password)
    && /[^A-Za-z0-9]/.test(password)
  );
}

async function submitForm() {
  ui.loading = true;
  ui.message = "";
  ui.type = "";

  if (!isStrongPassword(form.password)) {
    ui.message = "Password must be at least 8 characters and include a letter, number, and symbol.";
    ui.type = "error";
    ui.loading = false;
    return;
  }

  if (!form.termsAccepted) {
    ui.message = "Please accept the Terms & Conditions to create your account.";
    ui.type = "error";
    ui.loading = false;
    return;
  }

  const submittedEmail = form.email.trim();

  try {
    const { response, data } = await requestJson("/api/register", {
      method: "POST",
      body: JSON.stringify({
        fullName: form.fullName.trim(),
        email: submittedEmail,
        password: form.password,
        phoneNumber: form.phoneNumber.trim(),
        birthDate: form.birthDate,
        gender: form.gender,
        marketingEmailsOptIn: form.marketingEmailsOptIn,
        termsAccepted: form.termsAccepted,
      }),
    });

    if (!response.ok || !data?.ok) {
      ui.message = resolveApiMessage(data, "We couldn't create your account.");
      ui.type = "error";
      return;
    }

    const hasDeliveryWarnings = Array.isArray(data?.warnings) && data.warnings.length > 0;
    ui.message = data.message || "Account created successfully.";
    ui.type = hasDeliveryWarnings ? "error" : "success";

    if (hasDeliveryWarnings) {
      form.password = "";
      return;
    }

    form.fullName = "";
    form.email = "";
    form.phoneNumber = "";
    form.birthDate = "";
    form.gender = "";
    form.password = "";
    form.marketingEmailsOptIn = false;
    form.termsAccepted = false;

    await router.push(data.redirectTo || getVerifyEmailUrl(submittedEmail));
  } catch (error) {
    ui.message = "The server is not responding. Please try again.";
    ui.type = "error";
    console.error(error);
  } finally {
    ui.loading = false;
  }
}
</script>

<template>
  <AuthShell
    title="Create your account"
    :show-brand="false"
    :message="ui.message"
    :message-type="ui.type"
  >
    <form class="auth-form" @submit.prevent="submitForm">
      <AuthField
        id="signup-name"
        v-model="form.fullName"
        label="Full name"
        name="fullName"
        type="text"
        autocomplete="name"
        required
      />

      <AuthField
        id="signup-email"
        v-model="form.email"
        label="Email"
        name="email"
        type="email"
        autocomplete="email"
        inputmode="email"
        required
      />

      <AuthField
        id="signup-phone"
        v-model="form.phoneNumber"
        label="Phone number"
        name="phoneNumber"
        type="tel"
        autocomplete="tel"
        inputmode="tel"
        placeholder="+383 44 123 456"
      />

      <div class="signup-form__row">
        <AuthField
          id="signup-birth-date"
          v-model="form.birthDate"
          label="Date of birth"
          name="birthDate"
          type="date"
          autocomplete="bday"
        />

        <AuthSelectField
          id="signup-gender"
          v-model="form.gender"
          label="Gender"
          name="gender"
          :options="[
            { value: '', label: 'Select gender' },
            { value: 'mashkull', label: 'Male' },
            { value: 'femer', label: 'Female' },
            { value: 'tjeter', label: 'Other' },
          ]"
        />
      </div>

      <AuthField
        id="signup-password"
        v-model="form.password"
        label="Password"
        name="password"
        type="password"
        autocomplete="new-password"
        required
      />

      <div class="signup-form__consents">
        <label class="signup-form__choice" for="signup-marketing-emails">
          <input
            id="signup-marketing-emails"
            v-model="form.marketingEmailsOptIn"
            name="marketingEmailsOptIn"
            type="checkbox"
          >
          <span>Send me emails with ads, offers, and promotions.</span>
        </label>

        <label class="signup-form__choice" for="signup-terms">
          <input
            id="signup-terms"
            v-model="form.termsAccepted"
            name="termsAccepted"
            type="checkbox"
            required
          >
          <span>I accept the Terms & Conditions.</span>
        </label>
      </div>

      <AuthPrimaryButton :loading="ui.loading" loading-label="Creating account...">
        Create account
      </AuthPrimaryButton>
    </form>

    <template #footer>
      <p class="auth-helper">
        Already have an account?
        <RouterLink class="auth-link" to="/login">
          Sign in
        </RouterLink>
      </p>
    </template>
  </AuthShell>
</template>

<style scoped>
.signup-form__row {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 16px;
}

.signup-form__consents {
  display: grid;
  gap: 10px;
}

.signup-form__choice {
  display: grid;
  grid-template-columns: auto minmax(0, 1fr);
  align-items: start;
  gap: 10px;
  color: #525252;
  font-size: 12px;
  line-height: 1.45;
}

.signup-form__choice input {
  width: 16px;
  height: 16px;
  margin: 1px 0 0;
  accent-color: #111111;
}

@media (max-width: 560px) {
  .signup-form__row {
    grid-template-columns: 1fr;
    gap: 16px;
  }
}
</style>
