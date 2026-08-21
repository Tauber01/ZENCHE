<script setup lang="ts">
import { ref } from 'vue'
import { workflow } from '@/data/site'
import AppIcon from './AppIcon.vue'
import { useReveal } from '@/composables/useReveal'

const root = ref<HTMLElement | null>(null)
useReveal(root)
</script>

<template>
  <section id="workflow" ref="root" class="relative py-28 md:py-36">
    <div class="mx-auto max-w-7xl section-pad">
      <div class="grid lg:grid-cols-2 gap-16 items-center">
        <!-- 左侧文字 -->
        <div class="reveal">
          <span class="text-sm font-mono text-lens tracking-[0.2em] uppercase">// Workflow</span>
          <h2 class="mt-4 text-4xl md:text-5xl font-bold text-gradient leading-tight">
            {{ workflow.title }}
          </h2>
          <p class="mt-6 text-base md:text-lg c-text-3 leading-relaxed max-w-xl">
            {{ workflow.body }}
          </p>
          <div class="mt-8 flex flex-wrap gap-3">
            <span
              v-for="word in ['预览', '管理', '导入', '分享']"
              :key="word"
              class="px-4 py-1.5 rounded-full glass text-sm c-text-2"
            >
              {{ word }}
            </span>
          </div>
        </div>

        <!-- 右侧工作流流程图 -->
        <div class="reveal">
          <div class="glass-strong rounded-3xl p-8 md:p-10 relative overflow-hidden">
            <div class="absolute -top-20 -right-20 w-60 h-60 bg-lens/10 blur-3xl rounded-full"></div>

            <div class="relative space-y-1">
              <div
                v-for="(step, i) in workflow.steps"
                :key="step.key"
                class="flex items-center gap-5"
              >
                <!-- 节点 -->
                <div class="flex items-center gap-4 flex-1">
                  <div
                    class="grid place-items-center w-14 h-14 rounded-2xl glass border-lens/20 shrink-0"
                    :class="i === 0 ? 'bg-lens/15' : ''"
                  >
                    <AppIcon
                      :name="['capture', 'capture', 'connect', 'flow', 'external'][i] || 'aperture'"
                      class="w-6 h-6 text-lens-glow"
                    />
                  </div>
                  <div class="flex-1">
                    <div class="flex items-baseline gap-3">
                      <span class="text-xs font-mono c-text-4">0{{ i + 1 }}</span>
                      <h3 class="text-lg font-semibold c-text">{{ step.key }}</h3>
                    </div>
                    <p class="text-sm c-text-3 mt-0.5">{{ step.desc }}</p>
                  </div>
                </div>
              ></div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>
