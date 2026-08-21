<script setup lang="ts">
import { ref } from 'vue'
import { brand, downloads } from '@/data/site'
import AppIcon from './AppIcon.vue'
import { useReveal } from '@/composables/useReveal'

const root = ref<HTMLElement | null>(null)
useReveal(root)

const formatMiB = (bytes: number) => `${(bytes / 1024 / 1024).toFixed(2)} MiB`
</script>

<template>
  <section id="download" ref="root" class="relative py-28 md:py-40 overflow-hidden">
    <!-- 中心放射光晕 -->
    <div class="pointer-events-none absolute inset-0 flex justify-center">
      <div class="w-[700px] h-[700px] rounded-full bg-lens/15 blur-[140px]"></div>
    </div>

    <div class="relative mx-auto max-w-5xl section-pad text-center">
      <div class="reveal">
        <span class="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full glass text-xs text-lens-glow font-mono tracking-wider mb-7">
          <span class="w-1.5 h-1.5 rounded-full bg-lens animate-pulse-glow"></span>
          {{ brand.version }} · Latest Release
        </span>
        <h2 class="text-4xl md:text-6xl font-bold text-gradient leading-tight">
          开始你的专业影像工作流
        </h2>
        <p class="mt-5 c-text-3 text-base md:text-lg max-w-xl mx-auto">
          免费开源，五端原生客户端。核心工作流本地优先，AI 云服务按需联网。
        </p>
      </div>

      <div class="reveal mt-10 flex flex-wrap items-center justify-center gap-4">
        <a :href="brand.github + '/releases'" target="_blank" rel="noopener" class="btn-primary">
          <AppIcon name="github" class="w-4.5 h-4.5" />
          GitHub Releases
        </a>
        <a href="https://zenche.top/downloads/SHA256SUMS" target="_blank" rel="noopener" class="btn-ghost">
          <AppIcon name="check" class="w-4.5 h-4.5" />
          SHA-256 校验清单
        </a>
        <a href="#platforms" class="btn-ghost">
          <AppIcon name="download" class="w-4.5 h-4.5" />
          下载客户端
        </a>
      </div>

      <div class="reveal mt-14 grid grid-cols-2 md:grid-cols-5 gap-3">
        <div
          v-for="d in downloads"
          :key="d.platform"
          class="group glass glass-hover rounded-2xl p-5 flex flex-col items-center gap-3"
        >
          <span class="grid place-items-center w-12 h-12 rounded-xl bg-lens/10 border border-lens/20 group-hover:scale-110 transition-transform duration-500">
            <AppIcon :name="d.icon" class="w-6 h-6 text-lens-glow" />
          </span>
          <div>
            <p class="text-sm font-semibold c-text">{{ d.platform }}</p>
            <p class="text-[10px] c-text-4 mt-1 leading-relaxed">{{ d.note }}</p>
          </div>
          <div class="mt-auto w-full space-y-2 pt-1">
            <div
              v-for="asset in d.assets"
              :key="asset.href"
              class="space-y-1.5"
            >
              <a
                :href="asset.href"
                target="_blank"
                rel="noopener"
                class="inline-flex w-full items-center justify-between gap-2 rounded-xl border border-lens/20 bg-lens/10 px-3 py-2 text-[10px] text-lens-glow transition-colors hover:bg-lens/20"
              >
                <span class="font-medium">{{ asset.label }}</span>
                <span class="font-mono c-text-3">.{{ asset.ext }} · {{ formatMiB(asset.bytes) }}</span>
              </a>
              <a
                :href="asset.href + '.sha256'"
                target="_blank"
                rel="noopener"
                class="inline-flex text-[10px] font-mono c-text-4 underline decoration-dotted underline-offset-2 hover:text-lens-glow"
                :aria-label="`${d.platform} ${asset.label} SHA-256 校验文件`"
              >
                .sha256 校验文件
              </a>
            </div>
          </div>
        </div>
      </div>

      <p class="reveal mt-6 text-xs c-text-4 leading-relaxed">
        安装前请核对 SHA-256，并阅读
        <a
          href="https://github.com/Tauber01/ZENCHE/blob/main/docs/releases/v1.5.14.md"
          target="_blank"
          rel="noopener"
          class="text-lens-glow underline decoration-dotted underline-offset-2"
        >1.5.14 签名、安装与实机限制</a>。
      </p>
    </div>
  </section>
</template>
