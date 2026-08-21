<script setup lang="ts">
import { brand, footerLinks, friendLinks, openSource } from '@/data/site'
import AppIcon from './AppIcon.vue'

const year = new Date().getFullYear()
</script>

<template>
  <footer class="relative mt-10" style="border-top: 1px solid var(--c-border)">
    <div class="mx-auto max-w-7xl section-pad py-16">
      <div class="grid md:grid-cols-[1.5fr_1fr_1fr_1fr] gap-10">
        <!-- 品牌 -->
        <div>
          <router-link to="/" class="flex items-center gap-2.5 mb-5" aria-label="ZENCHE 首页">
            <img src="/favicon.png" alt="ZENCHE" class="w-9 h-9 rounded-xl" />
            <span class="flex flex-col leading-none">
              <span class="c-text font-bold tracking-tight text-lg">{{ brand.name }}</span>
              <span class="text-[10px] c-text-3 tracking-[0.25em] font-medium">{{ brand.nameEn }}</span>
            </span>
          </router-link>
          <p class="text-lens font-mono text-sm tracking-[0.15em]">{{ brand.taglineEn }}</p>
          <p class="mt-3 text-sm c-text-4 max-w-xs leading-relaxed">
            {{ brand.tagline }}。本地优先，原生实现。
          </p>
        </div>

        <!-- 链接 -->
        <div>
          <h4 class="text-xs font-mono c-text-4 tracking-widest uppercase mb-4">资源</h4>
          <ul class="space-y-3">
            <li v-for="link in footerLinks" :key="link.label">
              <a
                :href="link.href"
                target="_blank"
                rel="noopener"
                class="inline-flex items-center gap-1.5 text-sm c-text-2 hover:text-lens-glow transition-colors"
              >
                {{ link.label }}
                <AppIcon name="external" class="w-3 h-3 opacity-50" />
              </a>
            </li>
          </ul>
        </div>

        <!-- 平台 -->
        <div>
          <h4 class="text-xs font-mono c-text-4 tracking-widest uppercase mb-4">平台</h4>
          <ul class="space-y-3">
            <li v-for="p in ['macOS', 'Windows', 'Android', 'HarmonyOS', 'iOS / iPadOS']" :key="p">
              <router-link
                :to="{ path: '/', hash: '#platforms' }"
                class="text-sm c-text-2 hover:text-lens-glow transition-colors"
              >
                {{ p }}
              </router-link>
            </li>
          </ul>
        </div>

        <!-- 友情链接 -->
        <div>
          <h4 class="text-xs font-mono c-text-4 tracking-widest uppercase mb-4">友情链接</h4>
          <ul class="space-y-3">
            <li v-for="f in friendLinks" :key="f.name">
              <a
                :href="f.url"
                target="_blank"
                rel="noopener"
                class="group inline-flex flex-col gap-0.5 text-sm c-text-2 hover:text-lens-glow transition-colors"
              >
                <span class="font-medium">{{ f.name }}</span>
                <span class="text-xs c-text-4 group-hover:text-lens/70 transition-colors">{{ f.desc }}</span>
              </a>
            </li>
          </ul>
        </div>
      </div>

      <div class="mt-12 pt-8 flex flex-col md:flex-row items-center justify-between gap-4" style="border-top: 1px solid var(--c-border)">
        <p class="text-xs c-text-4 font-mono">
          © {{ year }} ZENCHE · {{ openSource.license }} · 为摄影工作流而设计
        </p>
        <a
          href="https://beian.miit.gov.cn/"
          target="_blank"
          rel="noopener"
          class="text-xs c-text-4 font-mono hover:text-lens-glow transition-colors"
        >
          宁ICP备2026002893号
        </a>
        <div class="flex items-center gap-4">
          <a
            :href="brand.github"
            target="_blank"
            rel="noopener"
            class="grid place-items-center w-9 h-9 rounded-full glass c-text-3 hover:text-lens-glow transition-colors"
            aria-label="GitHub"
          >
            <AppIcon name="github" class="w-4.5 h-4.5" />
          </a>
        </div>
      </div>
    </div>
  </footer>
</template>
