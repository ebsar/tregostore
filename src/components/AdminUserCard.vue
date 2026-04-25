<script setup>
import { computed, ref } from "vue";
import PasswordToggleButton from "./PasswordToggleButton.vue";
import { formatDateLabel, formatRoleLabel } from "../lib/shop";

const props = defineProps({
  user: {
    type: Object,
    required: true,
  },
  currentUserId: {
    type: Number,
    default: 0,
  },
});

const emit = defineEmits(["change-role", "delete", "set-password"]);
const passwordInputType = ref("password");
const newPassword = ref("");

const isCurrentUser = computed(() => Number(props.user.id) === Number(props.currentUserId));
const roleOptions = computed(() =>
  [
    { role: "admin", label: "Beje admin" },
    { role: "business", label: "Beje biznes" },
    { role: "client", label: "Beje user" },
  ].filter((option) => option.role !== props.user.role),
);

function submitPassword() {
  emit("set-password", {
    userId: props.user.id,
    newPassword: newPassword.value,
    reset() {
      newPassword.value = "";
      passwordInputType.value = "password";
    },
  });
}
</script>

<template>
  <article class="admin-user-card">
    <div class="admin-user-card__header">
      <div class="admin-user-card__meta">
      <p class="admin-user-card__eyebrow">
        {{ formatRoleLabel(user.role) }}<template v-if="isCurrentUser"> • Ti</template>
      </p>
      <h3>{{ user.fullName }}</h3>
      <p>{{ user.email }}</p>
      <span>Krijuar me {{ formatDateLabel(user.createdAt) }}</span>
      </div>
    </div>

    <div class="admin-user-card__actions">
      <div class="admin-user-card__password">
        <div class="password-control">
          <input
            v-model="newPassword"
            :type="passwordInputType"
            placeholder="Fjalekalim i ri"
          >
          <PasswordToggleButton
            :visible="passwordInputType === 'text'"
            @toggle="passwordInputType = passwordInputType === 'password' ? 'text' : 'password'"
          />
        </div>
        <button class="market-button market-button--primary" type="button" @click="submitPassword">
          <span>Ruaje fjalekalimin</span>
        </button>
      </div>

      <div class="admin-user-card__role-actions">
        <button
          v-for="option in roleOptions"
          :key="option.role"
          class="market-button market-button--secondary"
          type="button"
          :disabled="isCurrentUser"
          @click="$emit('change-role', { userId: user.id, role: option.role })"
        >
          <span>{{ option.label }}</span>
        </button>
        <button
          class="market-button market-button--ghost"
          type="button"
          :disabled="isCurrentUser"
          @click="$emit('delete', user)"
        >
          <span>Fshije user-in</span>
        </button>
      </div>
    </div>
  </article>
</template>
