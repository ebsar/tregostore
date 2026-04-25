<script setup>
import { computed, ref } from "vue";
import PasswordToggleButton from "../PasswordToggleButton.vue";

defineOptions({
  inheritAttrs: false,
});

const props = defineProps({
  id: {
    type: String,
    required: true,
  },
  label: {
    type: String,
    required: true,
  },
  modelValue: {
    type: String,
    default: "",
  },
  type: {
    type: String,
    default: "text",
  },
  name: {
    type: String,
    default: "",
  },
  autocomplete: {
    type: String,
    default: "",
  },
  placeholder: {
    type: String,
    default: "",
  },
  inputmode: {
    type: String,
    default: "",
  },
  required: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(["update:modelValue"]);
const passwordVisible = ref(false);
const isPasswordField = computed(() => props.type === "password");
const inputType = computed(() => (isPasswordField.value
  ? (passwordVisible.value ? "text" : "password")
  : props.type));

function handleInput(event) {
  emit("update:modelValue", event?.target?.value ?? "");
}
</script>

<template>
  <div class="auth-field">
    <span class="auth-field__label-row">
      <label class="auth-field__label" :for="id">{{ label }}</label>
      <span v-if="$slots['label-action']" class="auth-field__label-action">
        <slot name="label-action" />
      </span>
    </span>

    <div class="auth-field__input-wrap" :class="{ 'auth-field__input-wrap--password': isPasswordField }">
      <input
        v-bind="$attrs"
        class="auth-field__input"
        :class="{ 'auth-field__input--password': isPasswordField }"
        :id="id"
        :name="name || id"
        :type="inputType"
        :value="modelValue"
        :autocomplete="autocomplete || undefined"
        :placeholder="placeholder || undefined"
        :inputmode="inputmode || undefined"
        :required="required"
        @input="handleInput"
      >

      <PasswordToggleButton
        v-if="isPasswordField"
        class="auth-field__toggle"
        :visible="passwordVisible"
        @toggle="passwordVisible = !passwordVisible"
      />
    </div>
  </div>
</template>

<style scoped>
.auth-field {
  display: grid;
  gap: 8px;
}

.auth-field__label-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

.auth-field__label {
  color: #6b7280;
  font-size: 12px;
  font-weight: 500;
  line-height: 1.4;
}

.auth-field__label-action {
  display: inline-flex;
  align-items: center;
  font-size: 12px;
  line-height: 1.4;
}

.auth-field__input-wrap {
  position: relative;
}

.auth-field__input {
  width: 100%;
  height: 44px;
  padding: 0 14px;
  border: 1px solid #dddddd;
  border-radius: 8px;
  background: #ffffff;
  color: #111111;
  font-size: 14px;
  line-height: 1.4;
  transition: border-color 160ms ease;
}

.auth-field__input::placeholder {
  color: #a3a3a3;
}

.auth-field__input--password {
  padding-right: 48px;
}

.auth-field__toggle {
  position: absolute;
  top: 50%;
  right: 6px;
  transform: translateY(-50%);
  width: 32px;
  height: 32px;
  border-radius: 8px;
}

.auth-field__input:focus {
  outline: none;
  border-color: #bcbcbc;
}
</style>
