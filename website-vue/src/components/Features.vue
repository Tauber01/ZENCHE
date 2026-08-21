<script setup lang="ts">
import { ref } from 'vue'
import { features } from '@/data/site'
import AppIcon from './AppIcon.vue'
import { useReveal } from '@/composables/useReveal'

const root = ref<HTMLElement | null>(null)
useReveal(root)
</script>

<template>
  <section id="features" ref="root" class="relative py-28 md:py-36">
    <div class="mx-auto max-w-7xl section-pad">
      <div class="reveal text-center max-w-2xl mx-auto mb-16">
        <span class="text-sm font-mono text-lens tracking-[0.2em] uppercase">// Features</span>
        <h2 class="mt-4 text-4xl md:text-5xl font-bold text-gradient">从拍摄到修图，一套工作流</h2>
        <p class="mt-5 c-text-3 text-base md:text-lg">
          拍摄、控制、监看、传输、整理与修图，都在同一个原生应用中完成。
        </p>
      </div>

      <div class="grid sm:grid-cols-2 lg:grid-cols-3 gap-5">
        <article
          v-for="card in features"
          :key="card.title"
          class="reveal group glass glass-hover rounded-3xl p-7 relative overflow-hidden"
        >
          <!-- hover 光晕 -->
          <div
            class="absolute -top-16 -right-16 w-40 h-40 bg-lens/10 blur-3xl rounded-full opacity-0 group-hover:opacity-100 transition-opacity duration-500"
          ></div>

          <div class="relative">
            <div class="flex items-center justify-between mb-6">
              <span
                class="grid place-items-center w-12 h-12 rounded-2xl bg-lens/10 border border-lens/20"
              >
                <AppIcon :name="card.icon" class="w-6 h-6 text-lens-glow" />
              </span>
              <span class="text-[11px] font-mono c-text-4 tracking-widest">
                {{ String(features.indexOf(card) + 1).padStart(2, '0') }}
              </span>
            </div>

            <h3 class="text-2xl font-bold c-text">
              {{ card.title }}
              <span class="text-base font-medium c-text-3 ml-2">· {{ card.subtitle }}</span>
            </h3>

            <ul class="mt-5 space-y-2.5">
              <li
                v-for="item in card.items"
                :key="item"
                class="flex items-center gap-2.5 text-sm c-text-2"
              >
                <span class="w-1 h-1 rounded-full bg-lens"></span>
                {{ item }}
              </li>
            </ul>
          </div>
        </article>
      </div>
    </div>
  </section>
</template>
