<script setup>
import { ref } from "vue";
import { formatDateLabel, formatVerificationStatusLabel, getBusinessInitials } from "../lib/shop";

const props = defineProps({
  business: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(["upload-logo", "save-edit", "update-verification", "update-edit-access"]);

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

function formatEditAccessLabel(status) {
  const normalizedStatus = String(status || "").trim().toLowerCase();
  if (normalizedStatus === "approved") {
    return "I lejuar";
  }
  if (normalizedStatus === "pending") {
    return "Ne pritje";
  }
  return "I mbyllur";
}
</script>

<template>
  <article class="registered-business-card">
    <div class="registered-business-card__header">
      <div class="registered-business-card__identity">
        <div class="registered-business-card__logo">
          <img
            v-if="business.logoPath"
            :src="business.logoPath"
            :alt="business.businessName"
            width="180"
            height="180"
            loading="lazy"
            decoding="async"
          >
          <span v-else class="registered-business-card__logo-mark">
            {{ getBusinessInitials(business.businessName) }}
          </span>
        </div>
        <div class="registered-business-card__meta">
          <p class="registered-business-card__eyebrow">Biznes i regjistruar</p>
          <h2>{{ business.businessName || "Biznes pa emer" }}</h2>
          <p>
            Pronari: <strong>{{ business.ownerName || "Pa emer" }}</strong>
          </p>
        </div>
      </div>

      <div class="registered-business-card__actions">
        <label :for="`registered-business-logo-${business.id}`">
          {{ business.logoPath ? "Ndrysho logon" : "Ngarko logo" }}
        </label>
        <button
          class="market-button market-button--secondary"
          type="button"
          @click="editing ? resetEditState() : (editing = true)"
        >
          {{ editing ? "Mbylle editimin" : "Edito biznesin" }}
        </button>
        <input
          class="sr-only"
          type="file"
          :id="`registered-business-logo-${business.id}`"
          accept="image/*"
          @change="handleLogoChange"
        >
        <div>
          Nr. biznesi: <strong>{{ business.businessNumber || "-" }}</strong>
        </div>
        <div>
          Verifikimi: <strong>{{ formatVerificationStatusLabel(business.verificationStatus) }}</strong>
        </div>
        <div v-if="business.verificationStatus === 'verified'">
          Editimi: <strong>{{ formatEditAccessLabel(business.profileEditAccessStatus) }}</strong>
        </div>
        <button
          class="market-button market-button--primary"
          type="button"
          @click="emit('update-verification', { businessId: business.id, verificationStatus: 'verified' })"
        >
          Verifiko
        </button>
        <button
          class="market-button market-button--ghost"
          type="button"
          @click="emit('update-verification', { businessId: business.id, verificationStatus: 'rejected' })"
        >
          Refuzo
        </button>
        <button
          v-if="business.verificationStatus === 'verified' && business.profileEditAccessStatus === 'pending'"
          class="market-button market-button--secondary"
          type="button"
          @click="emit('update-edit-access', { businessId: business.id, editAccessStatus: 'approved' })"
        >
          Lejo editimin
        </button>
        <button
          v-if="business.verificationStatus === 'verified' && business.profileEditAccessStatus === 'approved'"
          class="market-button market-button--ghost"
          type="button"
          @click="emit('update-edit-access', { businessId: business.id, editAccessStatus: 'locked' })"
        >
          Mbylle editimin
        </button>
      </div>
    </div>

    <div class="registered-business-card__stats">
      <div class="registered-business-card__stat">
        <span>Emri dhe mbiemri</span>
        <strong>{{ business.ownerName || "-" }}</strong>
      </div>
      <div class="registered-business-card__stat">
        <span>Emri i biznesit</span>
        <strong>{{ business.businessName || "-" }}</strong>
      </div>
      <div class="registered-business-card__stat">
        <span>Numri i telefonit</span>
        <strong>{{ business.phoneNumber || "-" }}</strong>
      </div>
      <div class="registered-business-card__stat">
        <span>Email-i i biznesit</span>
        <strong>{{ business.ownerEmail || "-" }}</strong>
      </div>
      <div class="registered-business-card__stat">
        <span>Qyteti</span>
        <strong>{{ business.city || "-" }}</strong>
      </div>
      <div class="registered-business-card__stat">
        <span>Adresa e biznesit</span>
        <strong>{{ business.addressLine || "-" }}</strong>
      </div>
      <div class="registered-business-card__stat">
        <span>Numri i porosive</span>
        <strong>{{ business.ordersCount || 0 }}</strong>
      </div>
      <div class="registered-business-card__stat">
        <span>Numri i produkteve</span>
        <strong>{{ business.productsCount || 0 }}</strong>
      </div>
      <div class="registered-business-card__stat">
        <span>Perditesuar se fundi</span>
        <strong>{{ formatDateLabel(business.updatedAt || business.createdAt || "") }}</strong>
      </div>
    </div>

    <div v-if="editing" class="registered-business-card__edit">
      <div class="registered-business-card__edit-grid">
        <label>
          <span>Emri i biznesit</span>
          <input v-model="formState.businessName" type="text" required>
        </label>

        <label>
          <span>Nr. i biznesit</span>
          <input v-model="formState.businessNumber" type="text" required>
        </label>
      </div>

      <div class="registered-business-card__edit-grid">
        <label>
          <span>Numri i telefonit</span>
          <input v-model="formState.phoneNumber" type="text" required>
        </label>

        <label>
          <span>Qyteti</span>
          <input v-model="formState.city" type="text" required>
        </label>
      </div>

      <label>
        <span>Adresa e biznesit</span>
        <input v-model="formState.addressLine" type="text" required>
      </label>

      <label>
        <span>Pershkrimi i biznesit</span>
        <textarea v-model="formState.businessDescription" rows="4" required></textarea>
      </label>

      <div class="registered-business-card__button-row">
        <button class="market-button market-button--primary" type="button" @click="handleSave">
          Ruaj ndryshimet
        </button>
        <button class="market-button market-button--ghost" type="button" @click="resetEditState">
          Anulo
        </button>
      </div>
    </div>
  </article>
</template>
