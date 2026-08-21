import { createRouter, createWebHistory } from 'vue-router'
import Home from '@/views/Home.vue'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/', name: 'home', component: Home },
    { path: '/redeem', name: 'redeem', component: () => import('@/views/Redeem.vue') },
  ],
  scrollBehavior(to, from, savedPosition) {
    if (savedPosition) return savedPosition
    if (to.hash) {
      // 跨路由跳转时，Home 组件需要先渲染，延迟滚动确保元素存在
      if (from.path !== to.path) {
        return new Promise((resolve) =>
          setTimeout(() => resolve({ el: to.hash, top: 90, behavior: 'smooth' }), 200),
        )
      }
      return { el: to.hash, top: 90, behavior: 'smooth' }
    }
    return { top: 0 }
  },
})

export default router
