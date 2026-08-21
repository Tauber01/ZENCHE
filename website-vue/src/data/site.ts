/**
 * ZENCHE 站点内容数据 —— 所有文案、功能、平台、相机型号、下载链接、兑换说明集中管理
 */

export const brand = {
  name: '帧澈',
  nameEn: 'ZENCHE',
  tagline: '跨平台相机控制与影像传输工具',
  taglineEn: 'Capture · Connect · Flow',
  description: '连接相机，也连接完整工作流',
  // 真实 GitHub 仓库
  github: 'https://github.com/Tauber01/ZENCHE',
  docs: 'https://github.com/Tauber01/ZENCHE#readme',
  license: 'https://github.com/Tauber01/ZENCHE/blob/main/LICENSE',
  security: 'https://github.com/Tauber01/ZENCHE/security',
  // 访问统计（Umami）
  umami: {
    src: 'https://umami.xn--n6qv0quslfsn.top/script.js',
    websiteId: '8907c3a8-671a-4b45-8ae8-ef1f3ebb124e',
  },
  // 当前发布版本
  version: 'V1.5.14',
}

export const navLinks = [
  { label: '功能', to: { path: '/', hash: '#features' } },
  { label: '平台', to: { path: '/', hash: '#platforms' } },
  { label: '相机', to: { path: '/', hash: '#cameras' } },
  { label: '下载', to: { path: '/', hash: '#download' } },
  { label: '开源', to: { path: '/', hash: '#opensource' } },
  { label: 'AI 兑换', to: '/redeem' },
]

export const heroButtons = [
  { label: '立即下载', href: '#download', variant: 'primary' as const },
  { label: '查看 GitHub', href: brand.github, variant: 'ghost' as const },
]

/* Hero 右侧 Mockup 数据 */
export const heroMockup = {
  connection: { label: 'Nikon Z8', status: '已连接', port: 'USB 3.2 · PTP' },
  liveView: { iso: '400', shutter: '1/250', aperture: 'f/2.8', wb: 'DAYLIGHT' },
  transfer: [
    { name: 'DSC_4821.NEF', size: '52.4 MB', progress: 100 },
    { name: 'DSC_4822.NEF', size: '49.8 MB', progress: 74 },
    { name: 'DSC_4823.NEF', size: '51.1 MB', progress: 23 },
  ],
}

/* 产品介绍 / 工作流 */
export const workflow = {
  title: '本地优先的专业相机工作流',
  body:
    'ZENCHE 是一套本地优先的原生相机工作流工具：在系统能力允许时，通过 USB/PTP 或 Wi‑Fi PTP/IP 连接相机，并通过 FTP、HTTP 或 WebDAV 接收影像，再在同一个应用完成预览、管理、导入与分享。',
  steps: [
    { key: 'Camera', desc: '相机连接' },
    { key: 'Capture', desc: '拍摄采集' },
    { key: 'Connect', desc: '影像传输' },
    { key: 'Manage', desc: '组织管理' },
    { key: 'Export', desc: '输出分享' },
  ],
}

/* 核心功能卡片 */
export interface FeatureCard {
  icon: string
  title: string
  subtitle: string
  items: string[]
}

export const features: FeatureCard[] = [
  {
    icon: 'capture',
    title: 'Capture',
    subtitle: '拍摄',
    items: ['USB 识别', '实时取景', 'SDRAM 拍摄', '间隔拍摄', '曝光包围', '焦点包围'],
  },
  {
    icon: 'control',
    title: 'Control',
    subtitle: '控制',
    items: ['快门', '光圈', 'ISO', '曝光补偿', '白平衡', 'Picture Control'],
  },
  {
    icon: 'monitor',
    title: 'Monitor',
    subtitle: '监看',
    items: ['RGB 直方图', 'Waveform', 'Vectorscope', 'LUT', '峰值对焦'],
  },
  {
    icon: 'connect',
    title: 'Connect',
    subtitle: '传输',
    items: ['FTP', 'HTTP', 'WebDAV'],
  },
  {
    icon: 'flow',
    title: 'Flow',
    subtitle: '管理',
    items: ['树状工作区', 'RAW + JPEG', 'XMP 评级', 'SHA-256'],
  },
  {
    icon: 'develop',
    title: 'Develop',
    subtitle: '修图',
    items: ['专业显影', '预设', '裁切', '非破坏 JPEG 输出'],
  },
]

/* 平台支持 */
export interface Platform {
  name: string
  icon: string
  status: 'ok' | 'beta' | 'limited'
  statusLabel: string
  detail?: string
}

export const platforms: Platform[] = [
  { name: 'macOS', icon: 'apple', status: 'ok', statusLabel: '可下载' },
  { name: 'Android', icon: 'android', status: 'ok', statusLabel: '可侧载' },
  { name: 'Windows', icon: 'windows', status: 'beta', statusLabel: '待实机复验' },
  { name: 'HarmonyOS', icon: 'harmony', status: 'limited', statusLabel: '需签名' },
  { name: 'iOS / iPadOS', icon: 'ios', status: 'limited', statusLabel: '需签名', detail: '无厂商 USB/PTP' },
]

/* 相机支持 */
export interface CameraGroup {
  chip: string
  models: string[]
  experimental?: boolean
}

export interface CameraBrand {
  brand: string
  groups: CameraGroup[]
}

export const cameraBrands: CameraBrand[] = [
  {
    brand: 'Nikon',
    groups: [
      { chip: 'EXPEED 5', models: ['D500', 'D7500', 'D850'] },
      { chip: 'EXPEED 6', models: ['Z7', 'Z6', 'Z50', 'D780', 'D6', 'Z5', 'Z7II', 'Z6II', 'Z fc', 'Z30'] },
      { chip: 'EXPEED 7', models: ['Z9', 'Z8', 'Z f', 'Z6III', 'Z50II', 'Z5II', 'ZR'] },
    ],
  },
  {
    brand: 'Sony α',
    groups: [
      { chip: 'α 系列', models: ['A1', 'A1 II', 'A9 III', 'A7R V', 'A7 IV', 'A7S III', 'A7C II', 'A7C R', 'ZV-E1', 'A6100', 'A6400', 'A6600', 'A6700', 'FX30', 'ZV-E10', 'ZV-E10 II'], experimental: true },
    ],
  },
  {
    brand: 'Canon EOS R',
    groups: [
      { chip: 'EOS R 系列', models: ['EOS R1', 'R3', 'R5', 'R5 Mark II', 'R6 Mark III', 'R6 Mark II', 'R6', 'R7', 'R8', 'R10', 'R50', 'R50 V', 'R5 C', 'R100'], experimental: true },
    ],
  },
]

// 向后兼容：Nikon 分组（Cameras.vue 旧版可能引用）
export const cameraGroups: CameraGroup[] = cameraBrands[0].groups

/* 下载 —— v1.5.14 官网自托管直链（5 平台、6 个安装包，文件名/字节数以 docs/releases/v1.5.14.md 为准） */
export interface DownloadAsset {
  label: string
  ext: string
  href: string
  bytes: number
}

export interface DownloadItem {
  platform: string
  icon: string
  note: string
  assets: DownloadAsset[]
}

const DL_BASE = 'https://zenche.top/downloads'

export const downloads: DownloadItem[] = [
  {
    platform: 'macOS',
    icon: 'apple',
    note: 'arm64 · ad-hoc，未公证 · Gatekeeper 可能拦截',
    assets: [
      {
        label: '下载',
        ext: 'dmg',
        href: `${DL_BASE}/ZENCHE-1.5.14-macOS-arm64.dmg`,
        bytes: 67_407_512,
      },
    ],
  },
  {
    platform: 'Windows',
    icon: 'windows',
    note: 'x64 · macOS 交叉构建 · 无 Authenticode · 待 Windows 实机复验',
    assets: [
      {
        label: '安装版',
        ext: 'exe',
        href: `${DL_BASE}/ZENCHE-1.5.14-Windows-x64-Setup.exe`,
        bytes: 90_921_100,
      },
      {
        label: '便携版',
        ext: 'zip',
        href: `${DL_BASE}/ZENCHE-1.5.14-Windows-x64.zip`,
        bytes: 110_175_835,
      },
    ],
  },
  {
    platform: 'Android',
    icon: 'android',
    note: 'Debug 证书签名 · 与旧包证书不同时不能覆盖安装',
    assets: [
      {
        label: '下载',
        ext: 'apk',
        href: `${DL_BASE}/ZENCHE-1.5.14-android.apk`,
        bytes: 3_346_729,
      },
    ],
  },
  {
    platform: 'HarmonyOS',
    icon: 'harmony',
    note: 'Release 构建，未签名 · 安装前需开发者签名与 Profile',
    assets: [
      {
        label: '下载',
        ext: 'hap',
        href: `${DL_BASE}/ZENCHE-1.5.14-HarmonyOS.hap`,
        bytes: 4_545_876,
      },
    ],
  },
  {
    platform: 'iOS / iPadOS',
    icon: 'ios',
    note: '未签名 · 必须重新签名，不能直接安装',
    assets: [
      {
        label: '下载',
        ext: 'ipa',
        href: `${DL_BASE}/ZENCHE-1.5.14-ios-unsigned.ipa`,
        bytes: 4_613_937,
      },
    ],
  },
]

/* 开源 —— Stars/Contributors/Releases 由组件动态拉取 GitHub API，此处仅给静态项与仓库信息 */
export const openSource = {
  license: 'MIT License',
  // GitHub 仓库 owner/repo（用于动态 API）
  repoOwner: 'Tauber01',
  repoName: 'ZENCHE',
  // 静态统计项：value 为占位，动态项（stars/contributors/releases）由组件覆盖
  stats: [
    { label: 'License', value: 'MIT', icon: 'scale', dynamic: false },
    { label: 'GitHub Stars', value: '—', icon: 'star', dynamic: true, key: 'stars' },
    { label: 'Contributors', value: '—', icon: 'users', dynamic: true, key: 'contributors' },
    { label: 'Releases', value: '—', icon: 'tag', dynamic: true, key: 'releases' },
  ],
}

/* AI 激活密钥兑换页 */
export const redeem = {
  title: 'AI 激活密钥兑换',
  subtitle: '输入购买获得的兑换码和设备 ID，生成绑定当前设备的激活密钥',
  steps: [
    '先在 App「设置 → AI 功能激活」点击复制设备 ID',
    '把设备 ID 粘贴到下方输入框',
    '输入你购买的兑换码，点击「生成激活密钥」',
    '复制生成的激活密钥，粘贴回 App 即可激活',
  ],
  fields: {
    deviceId: { label: '我的设备 ID', placeholder: '粘贴 App 中复制的设备 ID', hint: '生成的激活密钥绑定此设备，请确认设备 ID 正确。' },
    redeemCode: { label: '兑换码', placeholder: 'ZENCHE-REDEEM-xxx', hint: '填写购买后获得的兑换码。' },
  },
  notice: '兑换码仅用于 AI 云服务；ZENCHE 本体免费开源。每个兑换码包含 100 次 AI 云服务额度，生成的激活密钥绑定一台设备。',
  purchaseUrl: 'https://www.ifdian.net/a/Tauber',
  apiPath: '/api/redeem',
  messages: {
    loading: '正在生成激活密钥，请稍候…',
    success: '生成成功！请复制激活密钥，粘贴回 App 激活。',
    needDevice: '请先填写设备 ID',
    needCode: '请填写兑换码',
    copied: '激活密钥已复制',
    copyFailed: '复制失败，请手动选择并复制上方激活密钥',
    fail: '生成失败，请检查兑换码',
  },
}

/* Footer */
export const footerLinks = [
  { label: 'GitHub', href: brand.github },
  { label: 'Documentation', href: brand.docs },
  { label: 'License', href: brand.license },
  { label: 'Security', href: brand.security },
]

/* 友情链接 */
export const friendLinks = [
  { name: '昊天兽王', url: 'https://昊天兽王.top', desc: '提供服务器和网站搭建' },
  { name: '米粒工作室', url: 'https://milir.top', desc: '提供服务器' },
  { name: 'Tauber', url: 'https://www.ifdian.net/a/Tauber', desc: '作者' },
]
