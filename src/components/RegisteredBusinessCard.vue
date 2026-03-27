<script setup>
import { ref } from "vue";
import { formatDateLabel, getBusinessInitials } from "../lib/shop";

const props = defineProps({
  business: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(["upload-logo", "save-edit"]);

const editing = ref(false);
const formState = ref(createFormState(props.business));

function createFormState(business) {
  return {
    businessName: String(business.businessName || ""),
    businessNumber: String(business.businessNumber || ""),
    phoneNumber: String(business.phoneNumber || ""),
    city: String(business.city || ""),
    addressLine: String(business.addressLine || ""),
    businessDescription: String(business.businessDescription || ""),
  };
}

function resetEditState() {
  formState.value = createFormState(props.business);
  editing.value = false;
}

function handleLogoChange(event) {
  const file = event.target.files?.[0];
  if (!file) {
    return;
  }

  emit("upload-logo", {
    businessId: props.business.id,
    file,
  });
  event.target.value = "";
}

function handleSave() {
  emit("save-edit", {
    businessId: props.business.id,
    payload: { ...formState.value },
    done() {
      editing.value = false;
    },
  });
}
</script>

<template>
  <article class="registered-business-card">
    <div class="registered-business-card-head">
      <div class="registered-business-identity">
        <div class="registered-business-avatar-shell">
          <img
            v-if="business.logoPath"
            class="registered-business-avatar-image"
            :src="business.logoPath"
            :alt="business.businessName"
            loading="lazy"
            decoding="async"
          >
          <span v-else class="registered-business-avatar-fallback">
            {{ getBusinessInitials(business.businessName) }}
          </span>
        </div>
        <div class="registered-business-copy">
          <p class="section-label">Biznes i regjistruar</p>
          <h2>{{ business.businessName || "Biznes pa emer" }}</h2>
          <p class="registered-business-owner">
            Pronari: <strong>{{ business.ownerName || "Pa emer" }}</strong>
          </p>
        </div>
      </div>

      <div class="registered-business-head-actions">
        <label class="registered-business-logo-upload" :for="`registered-business-logo-${business.id}`">
          {{ business.logoPath ? "Ndrysho logon" : "Ngarko logo" }}
        </label>
        <button
          class="registered-business-edit-toggle"
          type="button"
          @click="editing ? resetEditState() : (editing = true)"
        >
          {{ editing ? "Mbylle editimin" : "Edito biznesin" }}
        </button>
        <input
          :id="`registered-business-logo-${business.id}`"
          class="registered-business-logo-input"
          type="file"
          accept="image/*"
          @change="handleLogoChange"
        >
        <div class="registered-business-number-chip">
          Nr. biznesi: <strong>{{ business.businessNumber || "-" }}</strong>
        </div>
      </div>
    </div>

    <div class="registered-business-grid">
      <div class="summary-chip">
        <span>Emri dhe mbiemri</span>
        <strong>{{ business.ownerName || "-" }}</strong>
      </div>
      <div class="summary-chip">
        <span>Emri i biznesit</span>
        <strong>{{ business.businessName || "-" }}</strong>
      </div>
      <div class="summary-chip">
        <span>Numri i telefonit</span>
        <strong>{{ business.phoneNumber || "-" }}</strong>
      </div>
      <div class="summary-chip">
        <span>Email-i i biznesit</span>
        <strong>{{ business.ownerEmail || "-" }}</strong>
      </div>
      <div class="summary-chip">
        <span>Qyteti</span>
        <strong>{{ business.city || "-" }}</strong>
      </div>
      <div class="summary-chip">
        <span>Adresa e biznesit</span>
        <strong>{{ business.addressLine || "-" }}</strong>
      </div>
      <div class="summary-chip">
        <span>Numri i porosive</span>
        <strong>{{ business.ordersCount || 0 }}</strong>
      </div>
      <div class="summary-chip">
        <span>Numri i produkteve</span>
        <strong>{{ business.productsCount || 0 }}</strong>
      </div>
      <div class="summary-chip">
        <span>Perditesuar se fundi</span>
        <strong>{{ formatDateLabel(business.updatedAt || business.createdAt || "") }}</strong>
      </div>
    </div>

    <div v-if="editing" class="auth-form registered-business-edit-form">
      <div class="field-row">
        <label class="field">
          <span>Emri i biznesit</span>
          <input v-model="formState.businessName" type="text" required>
        </label>

        <label class="field">
          <span>Nr. i biznesit</span>
          <input v-model="formState.businessNumber" type="text" required>
        </label>
      </div>

      <div class="field-row">
        <label class="field">
          <span>Numri i telefonit</span>
          <input v-model="formState.phoneNumber" type="text" required>
        </label>

        <label class="field">
          <span>Qyteti</span>
          <input v-model="formState.city" type="text" required>
        </label>
      </div>

      <label class="field">
        <span>Adresa e biznesit</span>
        <input v-model="formState.addressLine" type="text" required>
      </label>

      <label class="field">
        <span>Pershkrimi i biznesit</span>
        <textarea v-model="formState.businessDescription" rows="4" required></textarea>
      </label>

      <div class="registered-business-edit-actions">
        <button class="registered-business-save-button" type="button" @click="handleSave">
          Ruaj ndryshimet
        </button>
        <button class="ghost-button registered-business-cancel-button" type="button" @click="resetEditState">
          Anulo
        </button>
      </div>
    </div>
  </article>
</template>
