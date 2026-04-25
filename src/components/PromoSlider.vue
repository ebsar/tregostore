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
  <section aria-label="Reklamat kryesore">
    <div>
      <div
       
        @touchstart.passive="handleTouchStart"
        @touchmove.passive="handleTouchMove"
        @touchend.passive="handleTouchEnd"
        @touchcancel.passive="resetTouchState"
      >
        <div
         
         
         
        >
          <article
            v-for="(slide, index) in slides"
            :key="slide.title"
           
           
          >
            <img
             
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
             
              :to="slide.ctaHref"
              :aria-label="slide.title"
            />
            <div v-if="!slide.hideCopy">
              <span>{{ slide.badge }}</span>
              <h2>{{ slide.title }}</h2>
              <p>{{ slide.description }}</p>
              <RouterLink :to="slide.ctaHref">
                {{ slide.ctaLabel }}
              </RouterLink>
            </div>
          </article>
        </div>
      </div>

      <div>
        <div aria-label="Zgjedh slide">
          <button
            v-for="(slide, index) in slides"
            :key="slide.title"
           
           
            type="button"
            :aria-label="`Hap slide ${index + 1}: ${slide.title}`"
            @click="goToSlide(index)"
          ></button>
        </div>
      </div>
    </div>
  </section>
</template>
