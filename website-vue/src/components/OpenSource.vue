<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { brand, openSource } from '@/data/site'
import AppIcon from './AppIcon.vue'
import { useReveal } from '@/composables/useReveal'

const root = ref<HTMLElement | null>(null)
useReveal(root)

// 动态统计：复制一份,运行时覆盖动态项
const stats = ref(openSource.stats.map((s) => ({ ...s })))

const formatNum = (n: number) => {
  if (n >= 1000) return (n / 1000).toFixed(1).replace(/\.0$/, '') + 'k'
  return String(n)
}

onMounted(async () => {
  const base = `https://api.github.com/repos/${openSource.repoOwner}/${openSource.repoName}`
  const headers = { Accept: 'application/vnd.github+json' }
  const setStat = (key: string, value: string) => {
    stats.value = stats.value.map((s) => (s.key === key ? { ...s, value } : s))
  }
  try {
    // 串行拉取，降低未认证限流（60次/小时/IP）触发概率
    const repoRes = await fetch(base, { headers })
    if (repoRes.ok) {
      const repo = await repoRes.json()
      setStat('stars', formatNum(repo.stargazers_count ?? 0))
    }
    const contribRes = await fetch(`${base}/contributors?per_page=100`, { headers })
    if (contribRes.ok) {
      const contribs = await contribRes.json()
      setStat('contributors', String(contribs.length))
    }
    const relRes = await fetch(`${base}/releases?per_page=100`, { headers })
    if (relRes.ok) {
      const rels = await relRes.json()
      setStat('releases', String(rels.length))
    }
  } catch {
    // 网络失败保留占位
  }
})
</script>

<template>
  <section id="opensource" ref="root" class="relative py-28 md:py-36">
    <div class="mx-auto max-w-6xl section-pad">
      <div class="reveal glass-strong rounded-[2rem] p-8 md:p-14 relative overflow-hidden">
        <div class="absolute -top-24 left-1/2 -translate-x-1/2 w-[500px] h-[300px] rounded-full" style="background: var(--c-glow); filter: blur(120px)"></div>

        <div class="relative grid lg:grid-cols-[1fr_1.2fr] gap-10 items-center">
          <!-- 左：说明 -->
          <div>
            <span class="text-sm font-mono text-lens tracking-[0.2em] uppercase">// Open Source</span>
            <h2 class="mt-4 text-3xl md:text-4xl font-bold text-gradient">开源、透明、可审计</h2>
            <p class="mt-5 c-text-3 leading-relaxed">
              ZENCHE 客户端与公开服务组件以 {{ openSource.license }} 发布，源码托管在 GitHub。
              拍摄、传输与管理默认在本地完成；只有主动使用 AI 功能时，用户提交的提示词才会发送到云服务；AI 修图还会发送当前编辑照片。
            </p>
            <a
              :href="brand.github"
              target="_blank"
              rel="noopener"
              class="mt-7 inline-flex items-center gap-2 px-6 py-3 rounded-full glass c-text hover:border-lens/40 transition-colors"
            >
              <AppIcon name="github" class="w-4.5 h-4.5" />
              在 GitHub 上查看
              <AppIcon name="external" class="w-3.5 h-3.5" />
            </a>
          </div>

          <!-- 右：统计卡（Stars/Contributors/Releases 动态拉取 GitHub API） -->
          <div class="grid grid-cols-2 gap-4">
            <div
              v-for="stat in stats"
              :key="stat.label"
              class="glass rounded-2xl p-6 flex flex-col gap-2"
            >
              <span class="grid place-items-center w-10 h-10 rounded-xl bg-lens/10 border border-lens/20 mb-1">
                <AppIcon :name="stat.icon" class="w-5 h-5 text-lens-glow" />
              </span>
              <span class="text-3xl font-bold c-text font-mono">{{ stat.value }}</span>
              <span class="text-xs c-text-4 font-mono tracking-wider uppercase">{{ stat.label }}</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>
