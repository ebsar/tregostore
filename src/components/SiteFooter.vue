<script setup>
import { ref } from "vue";
import { RouterLink } from "vue-router";

const newsletterEmail = ref("");

const programLinks = [
  { label: "Strength Training", to: "/kerko?q=Strength%20Training" },
  { label: "HIIT Classes", to: "/kerko?q=HIIT%20Classes" },
  { label: "Yoga & Wellness", to: "/kerko?q=Yoga%20Wellness" },
  { label: "Personal Training", to: "/kerko?q=Personal%20Training" },
];

const companyLinks = [
  { label: "About Us", to: "/" },
  { label: "Our Trainers", to: "/bizneset-e-regjistruara" },
  { label: "Membership", to: "/signup" },
  { label: "Contact", to: "/mesazhet" },
];

function handleNewsletterSubmit() {
  const nextEmail = String(newsletterEmail.value || "").trim();
  if (!nextEmail) {
    return;
  }

  window.dispatchEvent(new CustomEvent("trego:toast", {
    detail: {
      message: "Thanks for subscribing.",
      type: "success",
    },
  }));
  newsletterEmail.value = "";
}
</script>

<template>
  <footer class="site-footer" aria-label="Site footer">
    <div class="site-footer__inner">
      <div class="site-footer__grid">
        <section class="site-footer__brand">
          <RouterLink class="site-footer__logo" to="/">
            <img
              class="site-footer__logo-image"
              src="/trego-logo.png"
              alt="TREGIO"
              width="1024"
              height="1024"
            >
          </RouterLink>
          <p>
            Minimal essentials for focused routines, cleaner discovery, and premium everyday movement.
          </p>
        </section>

        <section class="site-footer__column">
          <h2>Programs</h2>
          <nav class="site-footer__links" aria-label="Programs">
            <RouterLink
              v-for="link in programLinks"
              :key="link.label"
              :to="link.to"
            >
              {{ link.label }}
            </RouterLink>
          </nav>
        </section>

        <section class="site-footer__column">
          <h2>Company</h2>
          <nav class="site-footer__links" aria-label="Company">
            <RouterLink
              v-for="link in companyLinks"
              :key="link.label"
              :to="link.to"
            >
              {{ link.label }}
            </RouterLink>
          </nav>
        </section>

        <section class="site-footer__column">
          <h2>Newsletter</h2>
          <p class="site-footer__newsletter-copy">
            Get thoughtful updates, new drops, and a cleaner weekly edit.
          </p>
          <form class="site-footer__newsletter" @submit.prevent="handleNewsletterSubmit">
            <input
              v-model="newsletterEmail"
              type="email"
              inputmode="email"
              autocomplete="email"
              placeholder="Your email"
              aria-label="Your email"
            >
            <button type="submit">Subscribe</button>
          </form>
        </section>
      </div>

      <div class="site-footer__bottom">
        <p>© 2026 TREGIO. All rights reserved.</p>
      </div>
    </div>
  </footer>
</template>

<style scoped>
.site-footer {
  margin-top: 56px;
  border-top: 1px solid #e5e5e5;
  background: #fafafa;
}

.site-footer__inner {
  width: min(100%, 1320px);
  margin: 0 auto;
  padding: 48px clamp(24px, 5vw, 56px) 24px;
}

.site-footer__grid {
  display: grid;
  grid-template-columns: 1.15fr 1fr 1fr 1.2fr;
  gap: 32px;
}

.site-footer__brand,
.site-footer__column {
  min-width: 0;
}

.site-footer__logo {
  width: fit-content;
  display: inline-flex;
  align-items: center;
  color: #111111;
  text-decoration: none;
}

.site-footer__logo-image {
  width: 44px;
  height: 44px;
  display: block;
  object-fit: contain;
}

.site-footer__brand p,
.site-footer__newsletter-copy {
  margin: 14px 0 0;
  max-width: 270px;
  color: #777777;
  font-family: "Inter", "Segoe UI", "Helvetica Neue", Arial, sans-serif;
  font-size: 14px;
  line-height: 1.7;
}

.site-footer__column h2 {
  margin: 0 0 14px;
  color: #111111;
  font-family: "Inter", "Segoe UI", "Helvetica Neue", Arial, sans-serif;
  font-size: 15px;
  font-weight: 600;
  line-height: 1.3;
}

.site-footer__links {
  display: grid;
  gap: 10px;
}

.site-footer__links a {
  width: fit-content;
  color: #5f5f5f;
  text-decoration: none;
  font-family: "Inter", "Segoe UI", "Helvetica Neue", Arial, sans-serif;
  font-size: 14px;
  line-height: 1.5;
  transition:
    color 160ms ease,
    text-decoration-color 160ms ease;
  text-decoration-line: underline;
  text-decoration-color: transparent;
  text-underline-offset: 3px;
}

.site-footer__links a:hover {
  color: #111111;
  text-decoration-color: currentColor;
}

.site-footer__newsletter {
  margin-top: 16px;
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto;
  gap: 10px;
}

.site-footer__newsletter input,
.site-footer__newsletter button {
  min-height: 42px;
  border-radius: 10px;
  font-family: "Inter", "Segoe UI", "Helvetica Neue", Arial, sans-serif;
  font-size: 14px;
}

.site-footer__newsletter input {
  min-width: 0;
  border: 1px solid #dddddd;
  background: #ffffff;
  padding: 0 14px;
  color: #111111;
  outline: none;
  transition: border-color 160ms ease;
}

.site-footer__newsletter input::placeholder {
  color: #9a9a9a;
}

.site-footer__newsletter input:focus {
  border-color: #bfbfbf;
}

.site-footer__newsletter button {
  border: 1px solid #e0e0e0;
  background: #f1f1f1;
  color: #111111;
  padding: 0 16px;
  font-weight: 500;
  cursor: pointer;
  transition:
    background-color 160ms ease,
    border-color 160ms ease;
}

.site-footer__newsletter button:hover {
  background: #e8e8e8;
  border-color: #d5d5d5;
}

.site-footer__bottom {
  margin-top: 28px;
  padding-top: 20px;
  border-top: 1px solid #e5e5e5;
  text-align: center;
}

.site-footer__bottom p {
  margin: 0;
  color: #8a8a8a;
  font-family: "Inter", "Segoe UI", "Helvetica Neue", Arial, sans-serif;
  font-size: 13px;
  line-height: 1.5;
}

@media (max-width: 960px) {
  .site-footer__grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 28px 24px;
  }
}

@media (max-width: 640px) {
  .site-footer {
    margin-top: 40px;
  }

  .site-footer__inner {
    padding: 40px 16px 22px;
  }

  .site-footer__grid {
    grid-template-columns: 1fr;
    gap: 26px;
  }

  .site-footer__newsletter {
    grid-template-columns: 1fr;
  }

  .site-footer__newsletter button {
    width: 100%;
  }
}
</style>
