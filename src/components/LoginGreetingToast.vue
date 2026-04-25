<script setup>
defineProps({
  message: {
    type: String,
    required: true,
  },
});
</script>

<template>
  <div class="market-login-toast">
    Pershendetje {{ message }}!
  </div>
</template>
