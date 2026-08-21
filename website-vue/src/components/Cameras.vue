<script setup lang="ts">
import { ref } from 'vue'
import { cameraBrands } from '@/data/site'
import AppIcon from './AppIcon.vue'
import { useReveal } from '@/composables/useReveal'

const root = ref<HTMLElement | null>(null)
useReveal(root)
</script>

<template>
  <section id="cameras" ref="root" class="relative py-28 md:py-36">
    <div class="mx-auto max-w-7xl section-pad">
      <div class="reveal text-center max-w-2xl mx-auto mb-16">
        <span class="text-sm font-mono text-lens tracking-[0.2em] uppercase">// Cameras</span>
        <h2 class="mt-4 text-4xl md:text-5xl font-bold text-gradient">Nikon / Sony / Canon 机型档案</h2>
        <p class="mt-5 c-text-3 text-base md:text-lg">
          Android、HarmonyOS、macOS 与 Windows 内置 50 款机型档案（Nikon 20、Sony 16、Canon 14）；Sony 与 Canon 为实验性支持。档案表示设备识别与参数范围已进入源码，不代表所有硬件组合均已完成实机验证；iOS / iPadOS 不提供厂商 USB/PTP。
        </p>
      </div>

      <div class="space-y-12">
        <div v-for="brand in cameraBrands" :key="brand.brand">
          <!-- 品牌标题 -->
          <div class="reveal flex items-center gap-3 mb-6">
            <span class="grid place-items-center w-10 h-10 rounded-xl bg-lens/10 border border-lens/20">
              <AppIcon name="aperture" class="w-5 h-5 text-lens-glow" />
            </span>
            <h3 class="text-2xl font-bold c-text">{{ brand.brand }}</h3>
            <span class="h-px flex-1" style="background: var(--c-border)"></span>
            <span class="text-xs font-mono c-text-4">
              {{ brand.groups.reduce((n, g) => n + g.models.length, 0) }} 机型
            </span>
          </div>

          <!-- 分组卡片 -->
          <div class="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
            <div
              v-for="(group, gi) in brand.groups"
              :key="group.chip"
              class="reveal glass-strong rounded-3xl p-8 relative overflow-hidden"
            >
              <div class="absolute -top-16 -right-16 w-40 h-40 bg-lens/10 blur-3xl rounded-full"></div>

              <div class="relative">
                <div class="flex items-center gap-3 mb-6">
                  <div>
                    <p class="text-[11px] font-mono c-text-4 tracking-widest">{{ brand.brand.toUpperCase() }}</p>
                    <h4 class="text-xl font-bold c-text">{{ group.chip }}</h4>
                  </div>
                  <span class="ml-auto text-3xl font-extrabold c-text opacity-[0.06] font-mono">
                    0{{ gi + 1 }}
                  </span>
                </div>

                <div class="flex flex-wrap gap-2">
                  <span
                    v-for="model in group.models"
                    :key="model"
                    class="px-3 py-1.5 rounded-lg text-sm font-mono c-text hover:border-lens/30 hover:text-lens-glow transition-colors"
                    style="background: var(--c-surface); border: 1px solid var(--c-border)"
                  >
                    {{ model }}
                  </span>
                </div>

                <div class="mt-5 flex items-center justify-between">
                  <p class="text-xs c-text-4 font-mono">{{ group.models.length }} 机型</p>
                  <span
                    v-if="group.experimental"
                    class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[11px] font-mono border border-amber-400/30 text-amber-400 bg-amber-400/10"
                  >
                    <span class="w-1.5 h-1.5 rounded-full bg-amber-400"></span>
                    实验性 · 待实机验证
                  </span>
                  <span
                    v-else
                    class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[11px] font-mono border border-green-400/30 text-green-400 bg-green-400/10"
                  >
                    <span class="w-1.5 h-1.5 rounded-full bg-green-400"></span>
                    已进入源码 · 待扩大实机验证
                  </span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>
