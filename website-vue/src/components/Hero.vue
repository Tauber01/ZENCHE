<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue'
import { gsap } from 'gsap'
import { brand, heroButtons, heroMockup } from '@/data/site'
import AppIcon from './AppIcon.vue'
import { useParticles } from '@/composables/useParticles'

const root = ref<HTMLElement | null>(null)
const particleLayer = ref<HTMLElement | null>(null)
useParticles(particleLayer)

let media: gsap.MatchMedia | null = null
onMounted(() => {
  if (!root.value) return
  media = gsap.matchMedia()
  media.add('(prefers-reduced-motion: no-preference)', () => {
    const tl = gsap.timeline({ defaults: { ease: 'power3.out' } })
    tl.from('.hero-eyebrow', { opacity: 0, y: 20, duration: 0.6 })
      .from('.hero-title', { opacity: 0, y: 30, duration: 0.9 }, '-=0.2')
      .from('.hero-sub', { opacity: 0, y: 20, duration: 0.7 }, '-=0.5')
      .from('.hero-en', { opacity: 0, y: 16, duration: 0.6 }, '-=0.4')
      .from('.hero-desc', { opacity: 0, y: 16, duration: 0.6 }, '-=0.4')
      .from('.hero-cta', { opacity: 0, y: 20, duration: 0.6 }, '-=0.3')
      .from('.hero-meta', { opacity: 0, duration: 0.6 }, '-=0.3')
      .from('.mockup-shell', { opacity: 0, x: 90, duration: 1.1 }, '-=1')
      .from('.mockup-piece', { opacity: 0, y: 24, duration: 0.6, stagger: 0.12 }, '-=0.5')
  }, root.value)
})
onUnmounted(() => {
  media?.revert()
  media = null
})
</script>

<template>
  <section
    id="top"
    ref="root"
    class="relative min-h-screen flex items-center pt-28 pb-20 overflow-hidden"
  >
    <!-- Three.js 粒子层 -->
    <div ref="particleLayer" class="absolute inset-0 z-0"></div>

    <!-- 摄影元素背景 -->
    <div class="pointer-events-none absolute inset-0 z-0">
      <!-- Nikon 相机轮廓 -->
      <svg
        class="absolute -right-10 top-1/4 w-[520px] opacity-[0.06] animate-float-slow"
        viewBox="0 0 200 140"
        fill="none"
        stroke="#2f80ff"
        stroke-width="1"
      >
        <rect x="20" y="30" width="160" height="90" rx="10" />
        <rect x="50" y="18" width="50" height="16" rx="3" />
        <circle cx="100" cy="75" r="40" />
        <circle cx="100" cy="75" r="28" />
        <circle cx="100" cy="75" r="16" />
        <rect x="150" y="38" width="20" height="12" rx="2" />
        <circle cx="35" cy="45" r="3" />
      </svg>
      <!-- 蓝色光晕 -->
      <div
        class="absolute top-1/3 right-1/4 w-[400px] h-[400px] rounded-full bg-lens/20 blur-[120px]"
      ></div>
      <div
        class="absolute bottom-1/4 left-1/4 w-[300px] h-[300px] rounded-full bg-lens-deep/10 blur-[100px]"
      ></div>
    </div>

    <div class="relative z-10 mx-auto max-w-7xl section-pad w-full">
      <div class="grid lg:grid-cols-2 gap-12 lg:gap-8 items-center">
        <!-- 左侧文字 -->
        <div class="flex flex-col items-start">
          <span
            class="hero-eyebrow inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full glass text-xs text-lens-glow font-mono tracking-wider mb-7"
          >
            <span class="w-1.5 h-1.5 rounded-full bg-lens animate-pulse-glow"></span>
            {{ brand.taglineEn }}
          </span>

          <h1 class="hero-title text-6xl md:text-7xl lg:text-8xl font-extrabold tracking-tight leading-[0.95]">
            <span class="text-gradient">帧澈</span>
            <span class="block text-gradient-lens mt-1">ZENCHE</span>
          </h1>

          <p class="hero-sub mt-6 text-xl md:text-2xl c-text font-medium">
            {{ brand.tagline }}
          </p>
          <p class="hero-desc mt-5 text-base md:text-lg c-text-3 max-w-md leading-relaxed">
            {{ brand.description }}
          </p>

          <div class="hero-cta mt-9 flex flex-wrap items-center gap-4">
            <a
              v-for="btn in heroButtons"
              :key="btn.label"
              :href="btn.href"
              :target="btn.href.startsWith('http') ? '_blank' : undefined"
              rel="noopener"
              :class="btn.variant === 'primary' ? 'btn-primary' : 'btn-ghost'"
            >
              <AppIcon :name="btn.variant === 'primary' ? 'download' : 'github'" class="w-4.5 h-4.5" />
              {{ btn.label }}
            </a>
          </div>

          <div class="hero-meta mt-10 flex items-center gap-6 text-xs c-text-4 font-mono">
            <span class="flex items-center gap-1.5">
              <AppIcon name="check" class="w-3.5 h-3.5 text-lens" /> MIT 开源
            </span>
            <span class="flex items-center gap-1.5">
              <AppIcon name="check" class="w-3.5 h-3.5 text-lens" /> 5 平台原生
            </span>
            <span class="flex items-center gap-1.5">
              <AppIcon name="check" class="w-3.5 h-3.5 text-lens" /> 本地优先
            </span>
          </div>
        </div>

        <!-- 右侧产品 Mockup -->
        <div class="mockup-shell relative">
          <div class="relative glass-strong rounded-3xl p-3 shadow-[0_30px_80px_-20px_rgba(47,128,255,0.4)]">
            <!-- 顶部状态栏 -->
            <div
              class="mockup-piece flex items-center justify-between px-4 py-3 border-b border-white/[0.06]"
            >
              <div class="flex items-center gap-2.5">
                <span class="flex gap-1.5">
                  <span class="w-2.5 h-2.5 rounded-full bg-red-400/70"></span>
                  <span class="w-2.5 h-2.5 rounded-full bg-yellow-400/70"></span>
                  <span class="w-2.5 h-2.5 rounded-full bg-green-400/70"></span>
                </span>
                <span class="text-xs text-slate-400 font-mono ml-2">ZENCHE</span>
              </div>
              <span class="flex items-center gap-1.5 text-xs text-lens-glow font-mono">
                <span class="w-1.5 h-1.5 rounded-full bg-lens animate-pulse-glow"></span>
                {{ heroMockup.connection.status }}
              </span>
            </div>

            <div class="grid grid-cols-5 gap-3 p-3">
              <!-- 实时取景 -->
              <div class="mockup-piece col-span-3 relative rounded-2xl overflow-hidden bg-ink-800 border border-white/[0.06] aspect-[4/3]">
                <div class="absolute inset-0 bg-gradient-to-br from-lens-deep/30 via-ink-800 to-ink-900"></div>
                <!-- 取景十字线 -->
                <div class="absolute inset-0">
                  <div class="absolute left-1/3 top-0 bottom-0 w-px bg-white/10"></div>
                  <div class="absolute left-2/3 top-0 bottom-0 w-px bg-white/10"></div>
                  <div class="absolute top-1/3 left-0 right-0 h-px bg-white/10"></div>
                  <div class="absolute top-2/3 left-0 right-0 h-px bg-white/10"></div>
                  <div class="absolute inset-0 grid place-items-center">
                    <div class="w-16 h-16 border border-lens/50 rounded-sm"></div>
                  </div>
                </div>
                <!-- 对焦点 -->
                <div class="absolute top-[30%] left-[40%] w-2 h-2 bg-lens rounded-sm shadow-[0_0_8px_#2f80ff]"></div>
                <!-- 扫描线 -->
                <div class="absolute inset-x-0 h-px bg-lens/40 animate-scan"></div>
                <!-- 底部参数 -->
                <div class="absolute bottom-0 inset-x-0 px-3 py-2 flex justify-between text-[10px] font-mono text-slate-300 bg-gradient-to-t from-ink-900/90 to-transparent">
                  <span>{{ heroMockup.connection.label }}</span>
                  <span>{{ heroMockup.liveView.wb }}</span>
                </div>
              </div>

              <!-- 右侧参数 -->
              <div class="mockup-piece col-span-2 flex flex-col gap-3">
                <div
                  v-for="(item, i) in [
                    { k: 'ISO', v: heroMockup.liveView.iso },
                    { k: 'SHUTTER', v: heroMockup.liveView.shutter },
                    { k: 'APERTURE', v: heroMockup.liveView.aperture },
                  ]"
                  :key="i"
                  class="glass rounded-xl px-3 py-2.5 flex items-center justify-between"
                >
                  <span class="text-[10px] font-mono text-slate-500 tracking-wider">{{ item.k }}</span>
                  <span class="text-sm font-mono text-lens-glow font-semibold">{{ item.v }}</span>
                </div>
                <!-- RGB 波形 -->
                <div class="glass rounded-xl px-3 py-2 flex-1 min-h-[60px] relative overflow-hidden">
                  <span class="text-[9px] font-mono text-slate-500">RGB WAVEFORM</span>
                  <svg class="absolute bottom-1 inset-x-2 h-10 w-[calc(100%-1rem)]" viewBox="0 0 100 40" preserveAspectRatio="none">
                    <polyline points="0,30 10,18 20,24 30,10 40,20 50,6 60,16 70,12 80,22 90,14 100,26" fill="none" stroke="#2f80ff" stroke-width="1" opacity="0.9" />
                    <polyline points="0,34 10,26 20,30 30,18 40,26 50,14 60,22 70,20 80,28 90,22 100,30" fill="none" stroke="#7ab0ff" stroke-width="1" opacity="0.6" />
                    <polyline points="0,36 10,32 20,34 30,26 40,30 50,22 60,28 70,26 80,32 90,28 100,34" fill="none" stroke="#1a5fd6" stroke-width="1" opacity="0.5" />
                  </svg>
                </div>
              </div>
            </div>

            <!-- 文件传输列表 -->
            <div class="mockup-piece px-4 pb-3">
              <div class="flex items-center justify-between mb-2">
                <span class="text-[10px] font-mono text-slate-500 tracking-wider">FILE TRANSFER</span>
                <span class="text-[10px] font-mono text-slate-600">3 / 128</span>
              </div>
              <div class="space-y-1.5">
                <div
                  v-for="file in heroMockup.transfer"
                  :key="file.name"
                  class="flex items-center gap-3"
                >
                  <span class="text-[10px] font-mono text-slate-400 w-28 truncate">{{ file.name }}</span>
                  <div class="flex-1 h-1 rounded-full bg-white/[0.06] overflow-hidden">
                    <div
                      class="h-full rounded-full bg-gradient-to-r from-lens-deep to-lens"
                      :style="{ width: file.progress + '%' }"
                    ></div>
                  </div>
                  <span class="text-[10px] font-mono text-slate-500 w-12 text-right">{{ file.size }}</span>
                </div>
              </div>
            </div>
          </div>

          <!-- 浮动光晕装饰 -->
          <div class="absolute -inset-4 -z-10 bg-lens/10 blur-3xl rounded-full opacity-60"></div>
        </div>
      </div>
    </div>

    <!-- 滚动提示 -->
    <a
      href="#workflow"
      class="absolute bottom-8 left-1/2 -translate-x-1/2 flex flex-col items-center gap-2 c-text-4 hover:text-lens transition-colors"
    >
      <span class="text-[10px] font-mono tracking-widest">SCROLL</span>
      <AppIcon name="arrow-down" class="w-4 h-4 animate-float-slow" />
    </a>
  </section>
</template>
