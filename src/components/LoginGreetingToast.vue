<script setup>
defineProps({
  message: {
    type: String,
    required: true,
  },
});
</script>

<template>
  <div class="login-greeting-toast is-visible">
    Pershendetje {{ message }}!
  </div>
</template>
