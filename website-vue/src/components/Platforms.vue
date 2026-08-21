<script setup lang="ts">
import { ref } from 'vue'
import { platforms, downloads } from '@/data/site'
import AppIcon from './AppIcon.vue'
import { useReveal } from '@/composables/useReveal'

const root = ref<HTMLElement | null>(null)
useReveal(root)

const dlFor = (name: string) => downloads.find(d => d.platform === name)?.assets[0]?.href

const statusStyle: Record<string, string> = {
  ok: 'text-green-400 bg-green-400/10 border-green-400/20',
  beta: 'text-amber-400 bg-amber-400/10 border-amber-400/20',
  limited: 'c-text-3 bg-slate-400/10 border-slate-400/20',
}
</script>

<template>
  <section id="platforms" ref="root" class="relative py-28 md:py-36">
    <div class="mx-auto max-w-7xl section-pad">
      <div class="reveal text-center max-w-2xl mx-auto mb-16">
        <span class="text-sm font-mono text-lens tracking-[0.2em] uppercase">// Platforms</span>
        <h2 class="mt-4 text-4xl md:text-5xl font-bold text-gradient">一个工作流，覆盖多个平台</h2>
        <p class="mt-5 c-text-3 text-base md:text-lg">
          五端均为原生客户端，不使用 WebView；签名与实机验证状态以下载说明为准。
        </p>
      </div>

      <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-5 gap-4">
        <a
          v-for="p in platforms"
          :key="p.name"
          :href="dlFor(p.name)"
          target="_blank"
          rel="noopener"
          class="reveal group glass glass-hover rounded-3xl p-6 flex flex-col items-center text-center"
        >
          <span
            class="grid place-items-center w-16 h-16 rounded-2xl bg-lens/10 border border-lens/20 mb-4 group-hover:scale-110 transition-transform duration-500"
          >
            <AppIcon :name="p.icon" class="w-8 h-8 text-lens-glow" />
          </span>
          <h3 class="text-base font-semibold c-text">{{ p.name }}</h3>
          <span
            class="mt-3 inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[11px] font-mono border"
            :class="statusStyle[p.status]"
          >
            <span
              class="w-1.5 h-1.5 rounded-full"
              :class="{
                'bg-green-400': p.status === 'ok',
                'bg-amber-400': p.status === 'beta',
                'bg-slate-400': p.status === 'limited',
              }"
            ></span>
            {{ p.statusLabel }}
          </span>
          <span v-if="p.detail" class="mt-2 text-[10px] c-text-4">{{ p.detail }}</span>
          <span class="mt-3 text-[11px] c-text-4 font-mono">↓ 下载</span>
        </a>
      </div>
    </div>
  </section>
</template>
