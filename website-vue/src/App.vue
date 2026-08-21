<script setup lang="ts">
import Navbar from '@/components/Navbar.vue'
import Footer from '@/components/Footer.vue'
</script>

<template>
  <div class="relative min-h-screen overflow-hidden" style="background: var(--c-bg)">
    <!-- 环境背景 -->
    <div class="pointer-events-none fixed inset-0 z-0">
      <div class="absolute inset-0" style="background: var(--c-bg-grad); opacity: 0.7"></div>
      <div
        class="absolute inset-0 opacity-40"
        style="
          background-image: linear-gradient(var(--c-grid) 1px, transparent 1px),
            linear-gradient(90deg, var(--c-grid) 1px, transparent 1px);
          background-size: 48px 48px;
          mask-image: radial-gradient(ellipse at center, black, transparent 75%);
          -webkit-mask-image: radial-gradient(ellipse at center, black, transparent 75%);
        "
      ></div>
    </div>

    <Navbar />

    <main class="relative z-10">
      <RouterView />
    </main>

    <Footer />
  </div>
</template>
