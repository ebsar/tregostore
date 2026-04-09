<script setup>
import { onBeforeUnmount, ref } from "vue";
import { RouterLink } from "vue-router";

const props = defineProps({
  slides: {
    type: Array,
    required: true,
  },
});

const currentIndex = ref(0);
let autoplayId = 0;
let touchStartX = 0;
let touchStartY = 0;
let touchLastX = 0;
let touchLastY = 0;
let touchActive = false;

function goToSlide(index) {
  const total = props.slides.length;
  if (!total) {
    return;
  }

  currentIndex.value = (index + total) % total;
}

function startAutoplay() {
  stopAutoplay();
  autoplayId = window.setInterval(() => {
    goToSlide(currentIndex.value + 1);
  }, 4800);
}

function stopAutoplay() {
  if (autoplayId) {
    window.clearInterval(autoplayId);
    autoplayId = 0;
  }
}

function restartAutoplay() {
  startAutoplay();
}

function handleTouchStart(event) {
  const touch = event.touches?.[0] || event.changedTouches?.[0];
  if (!touch) {
    return;
  }

  touchActive = true;
  touchStartX = touch.clientX;
  touchStartY = touch.clientY;
  touchLastX = touch.clientX;
  touchLastY = touch.clientY;
  stopAutoplay();
}

function handleTouchMove(event) {
  if (!touchActive) {
    return;
  }

  const touch = event.touches?.[0] || event.changedTouches?.[0];
  if (!touch) {
    return;
  }

  touchLastX = touch.clientX;
  touchLastY = touch.clientY;
}

function resetTouchState() {
  touchActive = false;
  touchStartX = 0;
  touchStartY = 0;
  touchLastX = 0;
  touchLastY = 0;
}

function handleTouchEnd(event) {
  if (!touchActive) {
    return;
  }

  const touch = event.changedTouches?.[0] || {
    clientX: touchLastX,
    clientY: touchLastY,
  };
  const startX = touchStartX;
  const startY = touchStartY;
  resetTouchState();

  const deltaX = touch.clientX - startX;
  const deltaY = touch.clientY - startY;
  if (Math.abs(deltaX) < 42 || Math.abs(deltaX) <= Math.abs(deltaY)) {
    restartAutoplay();
    return;
  }

  goToSlide(deltaX < 0 ? currentIndex.value + 1 : currentIndex.value - 1);
  restartAutoplay();
}

onBeforeUnmount(() => {
  stopAutoplay();
});
</script>

<template>
  <section class="home-promotions" aria-label="Reklamat kryesore">
    <div class="home-promo-slider">
      <div
        class="home-promo-viewport"
        @touchstart.passive="handleTouchStart"
        @touchmove.passive="handleTouchMove"
        @touchend.passive="handleTouchEnd"
        @touchcancel.passive="resetTouchState"
      >
        <div
          id="home-promo-track"
          class="home-promo-track"
          :style="{ transform: `translateX(-${currentIndex * 100}%)` }"
        >
          <article
            v-for="(slide, index) in slides"
            :key="slide.title"
            class="home-promo-slide home-promo-slide--tall"
            :class="{ 'home-promo-slide--image-only': slide.hideCopy }"
          >
            <img
              class="home-promo-image"
              :src="slide.imagePath"
              :alt="slide.title"
              width="885"
              height="333"
              :loading="index === 0 ? 'eager' : 'lazy'"
              decoding="async"
              :fetchpriority="index === 0 ? 'high' : 'auto'"
            >
            <RouterLink
              v-if="slide.hideCopy && slide.ctaHref"
              class="home-promo-slide-link"
              :to="slide.ctaHref"
              :aria-label="slide.title"
            />
            <div v-if="!slide.hideCopy" class="home-promo-copy">
              <span class="home-promo-badge">{{ slide.badge }}</span>
              <h2>{{ slide.title }}</h2>
              <p>{{ slide.description }}</p>
              <RouterLink class="hero-cta home-promo-cta" :to="slide.ctaHref">
                {{ slide.ctaLabel }}
              </RouterLink>
            </div>
          </article>
        </div>
      </div>

      <div class="home-promo-controls">
        <div id="home-promo-dots" class="home-promo-dots" aria-label="Zgjedh slide">
          <button
            v-for="(slide, index) in slides"
            :key="slide.title"
            class="home-promo-dot"
            :class="{ active: index === currentIndex }"
            type="button"
            :aria-label="`Hap slide ${index + 1}: ${slide.title}`"
            @click="goToSlide(index)"
          ></button>
        </div>
      </div>
    </div>
  </section>
</template>
