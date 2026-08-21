<script setup lang="ts">
/** 统一图标组件 —— 所有 SVG 图标集中管理，按 name 渲染 */
defineProps<{ name: string; class?: string }>()
</script>

<template>
  <svg
    xmlns="http://www.w3.org/2000/svg"
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    stroke-width="1.6"
    stroke-linecap="round"
    stroke-linejoin="round"
    :class="$props.class"
    aria-hidden="true"
  >
    <!-- 相机光圈 -->
    <g v-if="name === 'aperture'">
      <circle cx="12" cy="12" r="9" />
      <circle cx="12" cy="12" r="4" />
      <line x1="12" y1="3" x2="12" y2="6" />
      <line x1="12" y1="18" x2="12" y2="21" />
      <line x1="3" y1="12" x2="6" y2="12" />
      <line x1="18" y1="12" x2="21" y2="12" />
    </g>
    <!-- 拍摄：相机机身 -->
    <g v-else-if="name === 'capture'">
      <path d="M3 8a2 2 0 0 1 2-2h2l1.5-2h7L17 6h2a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z" />
      <circle cx="12" cy="13" r="3.5" />
    </g>
    <!-- 控制：滑块 -->
    <g v-else-if="name === 'control'">
      <line x1="4" y1="8" x2="20" y2="8" />
      <circle cx="9" cy="8" r="2.4" fill="currentColor" />
      <line x1="4" y1="16" x2="20" y2="16" />
      <circle cx="15" cy="16" r="2.4" fill="currentColor" />
    </g>
    <!-- 监看：波形 -->
    <g v-else-if="name === 'monitor'">
      <rect x="3" y="4" width="18" height="16" rx="2" />
      <path d="M5 14l3-4 3 6 3-8 3 4 2-2" />
    </g>
    <!-- 传输：信号 -->
    <g v-else-if="name === 'connect'">
      <path d="M5 12a7 7 0 0 1 14 0" />
      <path d="M8 12a4 4 0 0 1 8 0" />
      <circle cx="12" cy="12" r="1.6" fill="currentColor" />
      <path d="M12 13.6V20" />
    </g>
    <!-- 管理：树状 -->
    <g v-else-if="name === 'flow'">
      <rect x="3" y="4" width="6" height="4" rx="1" />
      <rect x="15" y="4" width="6" height="4" rx="1" />
      <rect x="9" y="16" width="6" height="4" rx="1" />
      <path d="M6 8v3a2 2 0 0 0 2 2h8a2 2 0 0 0 2-2V8" />
      <path d="M12 13v3" />
    </g>
    <!-- 修图：调色板 -->
    <g v-else-if="name === 'develop'">
      <path d="M12 3a9 9 0 1 0 0 18c1.1 0 2-.9 2-2 0-.5-.2-1-.6-1.3-.4-.4-.6-.8-.6-1.4 0-1.1.9-2 2-2h1.2A4 4 0 0 0 21 12c0-5-4-9-9-9z" />
      <circle cx="7.5" cy="11" r="1.2" fill="currentColor" />
      <circle cx="12" cy="7.5" r="1.2" fill="currentColor" />
      <circle cx="16" cy="10" r="1.2" fill="currentColor" />
    </g>
    <!-- 平台图标 -->
    <g v-else-if="name === 'apple'">
      <path d="M16 3c.2 1.3-.3 2.6-1.1 3.5-.8.9-2.1 1.6-3.4 1.5-.2-1.3.4-2.6 1.1-3.4C13.4 3.7 14.7 3.1 16 3z" fill="currentColor" stroke="none" />
      <path d="M19 17.5c-.5 1.2-.8 1.8-1.5 2.9-1 1.5-2.4 3.4-4.1 3.4-1.6 0-2-1-4.1-1-2.1 0-2.6 1-4.1 1-1.7 0-3-1.7-4-3.2C-1 16.7-1.3 11 .9 8.5 2 7.2 3.5 6.4 5.2 6.4c1.7 0 2.8 1 4.1 1 1.3 0 2.2-1 4.1-1 1.5 0 3 .8 4.1 2-3.6 2-3 7 .5 9.1z" fill="currentColor" stroke="none" />
    </g>
    <g v-else-if="name === 'windows'">
      <path d="M4 6l7-1v6H4z" fill="currentColor" stroke="none" />
      <path d="M12 4.8L20 3.7V11h-8z" fill="currentColor" stroke="none" />
      <path d="M4 13h7v6l-7-1z" fill="currentColor" stroke="none" />
      <path d="M12 13h8v7.2l-8-1.1z" fill="currentColor" stroke="none" />
    </g>
    <g v-else-if="name === 'android'">
      <path d="M6 14a6 6 0 0 1 12 0v5H6z" />
      <path d="M8 9l-1.5-2.5M16 9l1.5-2.5" />
      <circle cx="9.5" cy="12" r="0.6" fill="currentColor" />
      <circle cx="14.5" cy="12" r="0.6" fill="currentColor" />
      <path d="M9 5l1 1.6M15 5l-1 1.6" />
    </g>
    <g v-else-if="name === 'harmony'">
      <circle cx="12" cy="12" r="9" />
      <path d="M8 9c1.5-1.5 6.5-1.5 8 0M8 15c1.5 1.5 6.5 1.5 8 0" />
    </g>
    <g v-else-if="name === 'ios'">
      <rect x="6" y="3" width="12" height="18" rx="2.5" />
      <line x1="10" y1="6" x2="14" y2="6" />
      <circle cx="12" cy="18" r="0.8" fill="currentColor" />
    </g>
    <!-- 状态 / 杂项 -->
    <g v-else-if="name === 'check'">
      <path d="M5 12l4 4 10-10" />
    </g>
    <g v-else-if="name === 'download'">
      <path d="M12 3v12M7 11l5 5 5-5" />
      <path d="M5 20h14" />
    </g>
    <g v-else-if="name === 'github'">
      <path d="M9 19c-4 1.5-4-2.5-6-3m12 5v-3.5c0-1 .1-1.4-.5-2 2.8-.3 5.5-1.4 5.5-6a4.6 4.6 0 0 0-1.3-3.2 4.3 4.3 0 0 0-.1-3.2s-1-.3-3.4 1.3a11.7 11.7 0 0 0-6.2 0C6.6 2.3 5.5 2.6 5.5 2.6a4.3 4.3 0 0 0-.1 3.2A4.6 4.6 0 0 0 4 9c0 4.6 2.7 5.7 5.5 6-.6.6-.6 1.2-.5 2V21" />
    </g>
    <g v-else-if="name === 'star'">
      <path d="M12 3l2.7 5.5 6 .9-4.3 4.2 1 6L12 17l-5.4 2.6 1-6L3.3 9.4l6-.9z" fill="currentColor" stroke="none" />
    </g>
    <g v-else-if="name === 'users'">
      <circle cx="9" cy="8" r="3" />
      <path d="M3 20a6 6 0 0 1 12 0" />
      <path d="M16 5a3 3 0 0 1 0 6M21 20a6 6 0 0 0-4-5.7" />
    </g>
    <g v-else-if="name === 'tag'">
      <path d="M3 11l8-8 9 9-8 8a2 2 0 0 1-2.8 0L3 13.8a2 2 0 0 1 0-2.8z" />
      <circle cx="8" cy="8" r="1.4" fill="currentColor" />
    </g>
    <g v-else-if="name === 'scale'">
      <path d="M12 3v18M7 7l-4 7a3 3 0 0 0 8 0L7 7zM17 7l-4 7a3 3 0 0 0 8 0l-4-7z" />
      <path d="M5 21h14" />
    </g>
    <g v-else-if="name === 'arrow-down'">
      <path d="M12 5v14M6 13l6 6 6-6" />
    </g>
    <g v-else-if="name === 'external'">
      <path d="M14 4h6v6M20 4l-9 9M18 13v5a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h5" />
    </g>
    <g v-else-if="name === 'sun'">
      <circle cx="12" cy="12" r="4" />
      <path d="M12 2v2M12 20v2M4 12H2M22 12h-2M5 5l1.5 1.5M17.5 17.5L19 19M19 5l-1.5 1.5M6.5 17.5L5 19" />
    </g>
    <g v-else-if="name === 'moon'">
      <path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z" />
    </g>
  </svg>
</template>
