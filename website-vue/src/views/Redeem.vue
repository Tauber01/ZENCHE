<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue'
import { gsap } from 'gsap'
import { redeem } from '@/data/site'
import AppIcon from '@/components/AppIcon.vue'

const deviceId = ref('')
const redeemCode = ref('')
const loading = ref(false)
const msg = ref('')
const msgType = ref<'' | 'ok' | 'err'>('')
const code = ref('')
const showResult = ref(false)
const root = ref<HTMLElement | null>(null)
let media: gsap.MatchMedia | null = null

const setMsg = (text: string, type: '' | 'ok' | 'err') => {
  msg.value = text
  msgType.value = type
}

const submit = async () => {
  setMsg('', '')
  showResult.value = false
  if (!deviceId.value.trim()) return setMsg(redeem.messages.needDevice, 'err')
  if (!redeemCode.value.trim()) return setMsg(redeem.messages.needCode, 'err')

  loading.value = true
  setMsg(redeem.messages.loading, '')
  try {
    const res = await fetch(redeem.apiPath, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ deviceId: deviceId.value.trim(), redeemCode: redeemCode.value.trim() }),
    })
    const data = await res.json()
    if (!res.ok) return setMsg(data.error || redeem.messages.fail, 'err')
    code.value = data.code
    showResult.value = true
    setMsg(redeem.messages.success, 'ok')
    deviceId.value = ''
    redeemCode.value = ''
  } catch (e) {
    setMsg('请求失败：' + (e as Error).message, 'err')
  } finally {
    loading.value = false
  }
}

const copyCode = async () => {
  try {
    await navigator.clipboard.writeText(code.value)
    setMsg(redeem.messages.copied, 'ok')
  } catch {
    setMsg(redeem.messages.copyFailed, 'err')
  }
}

onMounted(() => {
  if (!root.value) return
  media = gsap.matchMedia()
  media.add('(prefers-reduced-motion: no-preference)', () => {
    gsap.from('.redeem-item', {
      opacity: 0,
      y: 24,
      duration: 0.7,
      ease: 'power3.out',
      stagger: 0.1,
    })
  }, root.value)
})

onUnmounted(() => {
  media?.revert()
  media = null
})
</script>

<template>
  <section
    ref="root"
    class="relative min-h-screen flex items-center justify-center px-6 pt-32 pb-20"
  >
    <div class="pointer-events-none absolute inset-0">
      <div class="absolute top-1/4 left-1/4 w-[400px] h-[400px] rounded-full bg-lens/15 blur-[120px]"></div>
      <div class="absolute bottom-1/4 right-1/4 w-[300px] h-[300px] rounded-full bg-lens-deep/10 blur-[100px]"></div>
    </div>

    <div class="relative w-full max-w-2xl">
      <!-- 标题 -->
      <div class="redeem-item text-center mb-10">
        <span class="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full glass text-xs text-lens-glow font-mono tracking-wider mb-6">
          <AppIcon name="aperture" class="w-3.5 h-3.5" />
          ZENCHE AI
        </span>
        <h1 class="text-3xl md:text-4xl font-bold text-gradient">{{ redeem.title }}</h1>
        <p class="mt-3 c-text-3">{{ redeem.subtitle }}</p>
      </div>

      <!-- 使用步骤 -->
      <div class="redeem-item glass-strong rounded-2xl p-6 mb-5">
        <p class="text-xs font-mono text-lens tracking-[0.2em] uppercase mb-4">// 使用步骤</p>
        <ol class="space-y-2.5">
          <li
            v-for="(step, i) in redeem.steps"
            :key="i"
            class="flex items-start gap-3 text-sm c-text-2"
          >
            <span class="grid place-items-center w-5 h-5 rounded-full bg-lens/15 text-lens-glow text-[11px] font-mono font-semibold shrink-0 mt-0.5">
              {{ i + 1 }}
            </span>
            {{ step }}
          </li>
        </ol>
        <p class="mt-5 text-xs c-text-4 leading-relaxed">{{ redeem.notice }}</p>
        <a
          :href="redeem.purchaseUrl"
          target="_blank"
          rel="noopener"
          class="mt-3 inline-flex items-center gap-1.5 text-sm text-lens-glow underline decoration-dotted underline-offset-4"
        >
          没有兑换码？前往爱发电购买
          <AppIcon name="external" class="w-3.5 h-3.5" />
        </a>
      </div>

      <form @submit.prevent="submit" novalidate>
        <!-- 设备 ID -->
        <div class="redeem-item glass rounded-2xl p-6 mb-4">
          <label for="device-id" class="block text-sm font-semibold c-text mb-2.5">{{ redeem.fields.deviceId.label }}</label>
          <input
            id="device-id"
            v-model="deviceId"
            type="text"
            :placeholder="redeem.fields.deviceId.placeholder"
            aria-describedby="device-id-hint redeem-status"
            class="w-full rounded-xl px-4 py-3 text-sm c-text font-mono transition-colors focus:outline-none focus:border-lens/40"
            style="background: var(--c-surface); border: 1px solid var(--c-border)"
          />
          <p id="device-id-hint" class="mt-2 text-xs c-text-4">{{ redeem.fields.deviceId.hint }}</p>
        </div>

        <!-- 兑换码 -->
        <div class="redeem-item glass rounded-2xl p-6 mb-4">
          <label for="redeem-code" class="block text-sm font-semibold c-text mb-2.5">{{ redeem.fields.redeemCode.label }}</label>
          <input
            id="redeem-code"
            v-model="redeemCode"
            type="text"
            :placeholder="redeem.fields.redeemCode.placeholder"
            aria-describedby="redeem-code-hint redeem-status"
            class="w-full rounded-xl px-4 py-3 text-sm c-text font-mono transition-colors focus:outline-none focus:border-lens/40"
            style="background: var(--c-surface); border: 1px solid var(--c-border)"
          />
          <p id="redeem-code-hint" class="mt-2 text-xs c-text-4">{{ redeem.fields.redeemCode.hint }}</p>
        </div>

        <!-- 提交按钮 + 消息 -->
        <div class="redeem-item glass rounded-2xl p-6">
          <button
            type="submit"
            :disabled="loading"
            class="btn-primary w-full"
          >
            <span v-if="loading" class="w-4 h-4 border-2 border-white/40 border-t-white rounded-full animate-spin"></span>
            <AppIcon v-else name="aperture" class="w-4.5 h-4.5" />
            {{ loading ? '正在生成…' : '生成激活密钥' }}
          </button>

          <p
            id="redeem-status"
            aria-live="polite"
            :role="msgType === 'err' ? 'alert' : 'status'"
            class="mt-3 min-h-5 text-sm font-mono"
            :class="{ 'text-green-400': msgType === 'ok', 'text-red-400': msgType === 'err', 'c-text-3': msgType === '' }"
          >
            {{ msg }}
          </p>

          <!-- 结果 -->
          <transition
            enter-active-class="transition duration-400"
            enter-from-class="opacity-0 translate-y-2"
          >
            <div v-if="showResult" class="mt-5">
              <p class="block text-xs font-mono c-text-4 tracking-wider mb-2">你的激活密钥</p>
              <div class="rounded-xl p-4 font-mono text-xs text-lens-glow break-all whitespace-pre-wrap leading-relaxed" style="background: var(--c-surface); border: 1px solid rgba(47,128,255,0.2)">
                {{ code }}
              </div>
              <button type="button" @click="copyCode" class="btn-ghost w-full mt-3 text-sm">
                <AppIcon name="check" class="w-4 h-4" />
                复制激活密钥
              </button>
            </div>
          </transition>
        </div>
      </form>

      <!-- 返回首页 -->
      <div class="redeem-item text-center mt-6">
        <router-link to="/" class="inline-flex items-center gap-1.5 text-sm c-text-4 hover:text-lens-glow transition-colors">
          ← 返回首页
        </router-link>
      </div>
    </div>
  </section>
</template>
