<script setup>
import { computed, ref } from "vue";
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
  <article class="admin-user-item">
    <div class="admin-user-copy">
      <p class="admin-user-meta">
        {{ formatRoleLabel(user.role) }}<template v-if="isCurrentUser"> • Ti</template>
      </p>
      <h3>{{ user.fullName }}</h3>
      <p>{{ user.email }}</p>
      <span class="admin-user-created">Krijuar me {{ formatDateLabel(user.createdAt) }}</span>
    </div>

    <div class="admin-user-actions">
      <div class="admin-user-password-row">
        <div class="admin-password-input-wrap">
          <input
            v-model="newPassword"
            class="admin-user-password-input"
            :type="passwordInputType"
            placeholder="Fjalekalim i ri"
          >
          <button
            class="admin-password-toggle"
            type="button"
            aria-label="Shfaq fjalekalimin"
            @click="passwordInputType = passwordInputType === 'password' ? 'text' : 'password'"
          >
            <span class="admin-password-toggle-icon">{{ passwordInputType === "password" ? "Sy" : "Fsheh" }}</span>
          </button>
        </div>
        <button class="product-action-button admin-action-button" type="button" @click="submitPassword">
          <span>Ruaje fjalekalimin</span>
        </button>
      </div>

      <div class="admin-user-button-row">
        <button
          v-for="option in roleOptions"
          :key="option.role"
          class="product-action-button admin-action-button"
          type="button"
          :disabled="isCurrentUser"
          @click="$emit('change-role', { userId: user.id, role: option.role })"
        >
          <span>{{ option.label }}</span>
        </button>
        <button
          class="product-action-button admin-action-button admin-action-danger"
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
