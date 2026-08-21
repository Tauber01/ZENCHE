<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue'
import { brand, navLinks } from '@/data/site'
import AppIcon from './AppIcon.vue'

const scrolled = ref(false)
// 默认浅色；读取 localStorage 决定是否深色
const dark = ref(false)
const mobileOpen = ref(false)

const onScroll = () => (scrolled.value = window.scrollY > 24)

const applyTheme = () => {
  document.documentElement.classList.toggle('dark', dark.value)
  try {
    localStorage.setItem('zenche-theme', dark.value ? 'dark' : 'light')
  } catch {}
}

const toggleTheme = () => {
  dark.value = !dark.value
  applyTheme()
}

onMounted(() => {
  // 同步初始主题状态（与 index.html 内联脚本一致）
  dark.value = document.documentElement.classList.contains('dark')
  window.addEventListener('scroll', onScroll, { passive: true })
  onScroll()
})
onUnmounted(() => window.removeEventListener('scroll', onScroll))
</script>

<template>
  <header
    class="fixed top-0 inset-x-0 z-50 transition-all duration-500"
    :class="scrolled ? 'py-3' : 'py-5'"
  >
    <div
      class="mx-auto max-w-7xl section-pad flex items-center justify-between transition-all duration-500"
    >
      <!-- 滚动后玻璃背景 -->
      <div
        class="absolute inset-0 -z-10 transition-opacity duration-500"
        :class="scrolled ? 'opacity-100' : 'opacity-0'"
      >
        <div class="h-full w-full glass-strong rounded-none border-x-0 border-t-0"></div>
      </div>

      <!-- 品牌标记：用 router-link 确保从任意路由回首页 -->
      <router-link to="/" class="flex items-center gap-2.5 group" aria-label="ZENCHE 首页">
        <img src="/favicon.png" alt="ZENCHE" class="w-9 h-9 rounded-xl" />
        <span class="flex flex-col leading-none">
          <span class="c-text font-bold tracking-tight text-lg">{{ brand.name }}</span>
          <span class="text-[10px] c-text-3 tracking-[0.25em] font-medium">{{ brand.nameEn }}</span>
        </span>
      </router-link>

      <!-- 桌面导航 -->
      <nav class="hidden md:flex items-center gap-1">
        <router-link
          v-for="link in navLinks"
          :key="link.label"
          :to="link.to"
          class="px-4 py-2 text-sm c-text-2 hover:c-text rounded-full hover:bg-[color:var(--c-surface)] transition-colors"
        >
          {{ link.label }}
        </router-link>
      </nav>

      <!-- 右侧操作 -->
      <div class="flex items-center gap-2">
        <button
          @click="toggleTheme"
          class="grid place-items-center w-9 h-9 rounded-full glass c-text-3 hover:text-lens-glow transition-colors"
          :aria-label="dark ? '切换到浅色' : '切换到深色'"
          :aria-pressed="dark"
        >
          <AppIcon :name="dark ? 'sun' : 'moon'" class="w-4.5 h-4.5" />
        </button>
        <a
          :href="brand.github"
          target="_blank"
          rel="noopener"
          class="hidden sm:inline-flex items-center gap-2 px-4 py-2 rounded-full glass c-text text-sm hover:border-lens/40 transition-colors"
        >
          <AppIcon name="github" class="w-4 h-4" />
          GitHub
        </a>
        <button
          @click="mobileOpen = !mobileOpen"
          class="md:hidden grid place-items-center w-9 h-9 rounded-full glass c-text"
          aria-label="菜单"
          :aria-expanded="mobileOpen"
          aria-controls="mobile-nav"
        >
          <span class="text-lg leading-none">{{ mobileOpen ? '×' : '☰' }}</span>
        </button>
      </div>
    </div>

    <!-- 移动菜单 -->
    <transition
      enter-active-class="transition duration-300"
      enter-from-class="opacity-0 -translate-y-2"
      leave-active-class="transition duration-200"
      leave-to-class="opacity-0 -translate-y-2"
    >
      <nav id="mobile-nav" v-if="mobileOpen" class="md:hidden mx-6 mt-3 glass-strong p-4 rounded-2xl flex flex-col gap-1">
        <router-link
          v-for="link in navLinks"
          :key="link.label"
          :to="link.to"
          @click="mobileOpen = false"
          class="px-4 py-3 c-text-2 hover:c-text rounded-xl transition-colors hover:bg-[color:var(--c-surface)]"
        >
          {{ link.label }}
        </router-link>
      </nav>
    </transition>
  </header>
</template>
