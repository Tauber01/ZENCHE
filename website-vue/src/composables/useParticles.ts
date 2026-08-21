import { onMounted, onUnmounted, type Ref } from 'vue'
import * as THREE from 'three'

/**
 * 轻量 Three.js 浮动粒子背景 —— 摄影蓝光点 + 缓慢漂移
 */
export function useParticles(container: Ref<HTMLElement | null>) {
  let renderer: THREE.WebGLRenderer | null = null
  let frame = 0
  let scene: THREE.Scene | null = null
  let camera: THREE.PerspectiveCamera | null = null
  let points: THREE.Points | null = null
  let flare: THREE.Mesh | null = null
  let pointsGeometry: THREE.BufferGeometry | null = null
  let pointsMaterial: THREE.PointsMaterial | null = null
  let pointsTexture: THREE.CanvasTexture | null = null
  let flareGeometry: THREE.SphereGeometry | null = null
  let flareMaterial: THREE.MeshBasicMaterial | null = null
  let motionQuery: MediaQueryList | null = null

  const onResize = () => {
    if (!container.value || !renderer || !scene || !camera) return
    const w = container.value.clientWidth
    const h = Math.max(container.value.clientHeight, 1)
    renderer.setSize(w, h)
    camera.aspect = w / h
    camera.updateProjectionMatrix()
    if (motionQuery?.matches) renderer.render(scene, camera)
  }

  const animate = () => {
    if (!renderer || !scene || !camera || !points || !flare || motionQuery?.matches) return
    frame = requestAnimationFrame(animate)
    points.rotation.y += 0.0006
    points.rotation.x += 0.0002
    const t = performance.now() * 0.0004
    flare.position.x = 28 + Math.sin(t) * 4
    flare.position.y = 14 + Math.cos(t * 0.8) * 3
    renderer.render(scene, camera)
  }

  const onMotionChange = () => {
    cancelAnimationFrame(frame)
    frame = 0
    if (!renderer || !scene || !camera) return
    if (motionQuery?.matches) renderer.render(scene, camera)
    else animate()
  }

  onMounted(() => {
    if (!container.value) return
    const w = container.value.clientWidth
    const h = Math.max(container.value.clientHeight, 1)

    scene = new THREE.Scene()
    camera = new THREE.PerspectiveCamera(60, w / h, 0.1, 1000)
    camera.position.z = 60

    renderer = new THREE.WebGLRenderer({ alpha: true, antialias: true })
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2))
    renderer.setSize(w, h)
    renderer.setClearColor(0x000000, 0)
    container.value.appendChild(renderer.domElement)

    // 粒子云
    const count = 240
    const positions = new Float32Array(count * 3)
    const sizes = new Float32Array(count)
    for (let i = 0; i < count; i++) {
      positions[i * 3] = (Math.random() - 0.5) * 140
      positions[i * 3 + 1] = (Math.random() - 0.5) * 90
      positions[i * 3 + 2] = (Math.random() - 0.5) * 60
      sizes[i] = Math.random() * 1.6 + 0.3
    }
    pointsGeometry = new THREE.BufferGeometry()
    pointsGeometry.setAttribute('position', new THREE.BufferAttribute(positions, 3))
    pointsGeometry.setAttribute('size', new THREE.BufferAttribute(sizes, 1))

    // 圆形软粒子贴图
    const canvas = document.createElement('canvas')
    canvas.width = canvas.height = 64
    const ctx = canvas.getContext('2d')!
    const grad = ctx.createRadialGradient(32, 32, 0, 32, 32, 32)
    grad.addColorStop(0, 'rgba(122,176,255,1)')
    grad.addColorStop(0.4, 'rgba(47,128,255,0.6)')
    grad.addColorStop(1, 'rgba(47,128,255,0)')
    ctx.fillStyle = grad
    ctx.fillRect(0, 0, 64, 64)
    pointsTexture = new THREE.CanvasTexture(canvas)

    pointsMaterial = new THREE.PointsMaterial({
      size: 1.4,
      map: pointsTexture,
      transparent: true,
      depthWrite: false,
      blending: THREE.AdditiveBlending,
      sizeAttenuation: true,
      opacity: 0.8,
    })
    points = new THREE.Points(pointsGeometry, pointsMaterial)
    scene.add(points)

    // 镜头光晕球
    flareGeometry = new THREE.SphereGeometry(2, 16, 16)
    flareMaterial = new THREE.MeshBasicMaterial({
      color: 0x2f80ff,
      transparent: true,
      opacity: 0.12,
    })
    flare = new THREE.Mesh(flareGeometry, flareMaterial)
    flare.position.set(28, 14, -10)
    scene.add(flare)

    motionQuery = window.matchMedia('(prefers-reduced-motion: reduce)')
    motionQuery.addEventListener('change', onMotionChange)
    if (motionQuery.matches) renderer.render(scene, camera)
    else animate()

    window.addEventListener('resize', onResize)
  })

  onUnmounted(() => {
    cancelAnimationFrame(frame)
    frame = 0
    window.removeEventListener('resize', onResize)
    motionQuery?.removeEventListener('change', onMotionChange)
    scene?.clear()
    pointsGeometry?.dispose()
    pointsMaterial?.dispose()
    pointsTexture?.dispose()
    flareGeometry?.dispose()
    flareMaterial?.dispose()
    if (renderer) {
      renderer.renderLists.dispose()
      renderer.dispose()
      renderer.domElement.remove()
    }
    renderer = null
    scene = null
    camera = null
    points = null
    flare = null
    pointsGeometry = null
    pointsMaterial = null
    pointsTexture = null
    flareGeometry = null
    flareMaterial = null
    motionQuery = null
  })
}
