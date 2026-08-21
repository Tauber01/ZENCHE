import { onMounted, onUnmounted, type Ref } from 'vue'
import { gsap } from 'gsap'
import { ScrollTrigger } from 'gsap/ScrollTrigger'

gsap.registerPlugin(ScrollTrigger)

/**
 * 滚动进入动画 —— 监听容器内所有 .reveal 元素，依次淡入上移
 */
export function useReveal(container: Ref<HTMLElement | null>) {
  let media: gsap.MatchMedia | null = null

  onMounted(() => {
    if (!container.value) return
    media = gsap.matchMedia()
    media.add('(prefers-reduced-motion: no-preference)', (context) => {
      const els = context.selector ? context.selector('.reveal') : []
      els.forEach((el: Element, i: number) => {
        gsap.to(el, {
          opacity: 1,
          y: 0,
          duration: 0.9,
          ease: 'power3.out',
          delay: (i % 6) * 0.08,
          scrollTrigger: {
            trigger: el,
            start: 'top 88%',
            toggleActions: 'play none none none',
          },
        })
      })
    }, container.value)
  })

  onUnmounted(() => {
    media?.revert()
    media = null
  })
}
