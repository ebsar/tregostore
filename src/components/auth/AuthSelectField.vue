<script setup>
defineOptions({
  inheritAttrs: false,
});

defineProps({
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
  name: {
    type: String,
    default: "",
  },
  required: {
    type: Boolean,
    default: false,
  },
  options: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(["update:modelValue"]);

function handleInput(event) {
  emit("update:modelValue", event?.target?.value ?? "");
}
</script>

<template>
  <div class="auth-field">
    <span class="auth-field__label-row">
      <label class="auth-field__label" :for="id">{{ label }}</label>
    </span>

    <select
      v-bind="$attrs"
      class="auth-field__input auth-field__select"
      :id="id"
      :name="name || id"
      :value="modelValue"
      :required="required"
      @input="handleInput"
    >
      <option
        v-for="option in options"
        :key="option.value"
        :value="option.value"
        :disabled="option.disabled"
      >
        {{ option.label }}
      </option>
    </select>
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
  color: var(--color-muted);
  font-size: 12px;
  font-weight: 500;
  line-height: 1.4;
}

.auth-field__input {
  width: 100%;
  min-height: var(--touch-target);
  height: var(--touch-target);
  padding: 0 14px;
  border: 1px solid var(--color-border);
  border-radius: var(--radius-control);
  background: var(--color-surface);
  color: var(--color-text);
  font-size: 14px;
  line-height: 1.4;
  transition: border-color 160ms ease;
}

.auth-field__select {
  appearance: none;
  -webkit-appearance: none;
  background-image:
    linear-gradient(45deg, transparent 50%, #8a8a8a 50%),
    linear-gradient(135deg, #8a8a8a 50%, transparent 50%);
  background-position:
    calc(100% - 20px) calc(50% - 2px),
    calc(100% - 14px) calc(50% - 2px);
  background-size: 6px 6px, 6px 6px;
  background-repeat: no-repeat;
  padding-right: 34px;
}

.auth-field__input:focus {
  outline: none;
  border-color: var(--color-primary);
}
</style>
