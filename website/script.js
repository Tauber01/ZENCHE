const translations = {
  en: {
    skip: "Skip to main content", navWorkflow: "Workflow", navPlatforms: "Platforms", navCameras: "Cameras", navDownload: "Download", headerCta: "Get the app",
    heroEyebrow: "CROSS-PLATFORM CAMERA WORKFLOW", heroTitleA: "Connect your camera, ", heroTitleB: "keep the whole workflow moving.", heroLede: "From USB / PTP capture and control to FTP, HTTP, and WebDAV transfers, then local organization and non-destructive development. ZENCHE keeps the set and the next step in the same rhythm.", heroPrimary: "Download ZENCHE", heroSecondary: "Explore the workflow", heroVersion: "current release", heroPlatforms: "native platforms", heroModels: "Nikon profiles", heroFrameLabel: "ZENCHE · NATIVE CONTROL", heroCaption: "Native control · Live view · Parameter write", visualNoteA: "direct camera link", visualNoteB: "set to library", scrollHint: "Scroll to see the full workflow", heroImageAlt: "ZENCHE native camera control interface",
    statementKicker: "A TOOL FOR THE WHOLE SET", statementA: "Every frame you make", statementB: "should arrive cleanly.", statementBody: "ZENCHE is open-source and local-first. Your images do not need to pass through an unfamiliar cloud, and your set does not need a pile of disconnected apps.", workflowKicker: "THE WORKFLOW", workflowTitleA: "From the set,", workflowTitleB: "all the way to the final frame.", workflowIntro: "One native app for capture, monitoring, transfer, organization, and development. Every step leaves a clear next move.", workCapture: "Capture", workCaptureSub: "Connect and shoot", workMonitor: "Monitor", workMonitorSub: "Real-time tools", workTransfer: "Transfer", workTransferSub: "Wireless inbox", workFlow: "Flow", workFlowSub: "Organize and develop",
    captureCaption: "Live view and camera parameters", captureTitle: "Connect. Compose. Shoot.", captureBody: "Connect a Nikon camera over native USB / PTP, read its capabilities, adjust shooting parameters, start live view, and trigger the shutter.", captureBullet1: "Shutter, aperture, ISO, and exposure compensation", captureBullet2: "Focus mode, white balance, and Picture Control", captureBullet3: "Interval, exposure bracketing, focus bracketing, and bulb timer", monitorCaption: "Preview only · never writes to the original", monitorTitle: "See more. Keep the original untouched.", monitorBody: "Put shutter angle, histograms, waveform, vectorscope, focus peaking, false color, zebra, and custom 3D LUTs on one screen.", monitorBullet1: "Shutter-angle conversion", monitorBullet2: "RGB histogram, waveform, and vectorscope", monitorBullet3: "Preview tools do not change camera settings or originals", transferCaption: "One local library", transferTitle: "Three protocols. One local library.", transferBody: "Send photos over FTP, HTTP, or WebDAV from a camera or mobile device. ZENCHE receives, sorts, and manages them in one place.", transferBullet1: "FTP / PASV camera transfer", transferBullet2: "Fast HTTP PUT / POST uploads", transferBullet3: "WebDAV for system file tools", flowCaption: "Local-first · source files stay put", flowTitle: "Organize, develop, then choose your next move.", flowBody: "Use project sessions, branch-based organization, RAW + JPEG pairing, XMP ratings, dual-target backup, and non-destructive high-quality copies without replacing the source.", flowBullet1: "Project sessions, naming templates, and SHA-256", flowBullet2: "Five adjustment groups and transparent presets", flowBullet3: "Original files are never overwritten",
    platformKicker: "NATIVE BY DEFAULT", platformTitleA: "Five platforms,", platformTitleB: "one workflow.", platformIntro: "Not a WebView stitched together. Each target uses its own native controls, permissions, and file-system conventions.", desktopBody: "Live view, parameter control, and the local library on a larger workbench.", desktopLink: "See desktop downloads", mobileBody: "Mobile capture, wireless transfers, and local organization that follows the set.", mobileLink: "See mobile downloads", harmonyBody: "A native workflow for HarmonyOS, with device coverage continuing to grow.", harmonyLink: "See installation notes",
    cameraKicker: "CAMERA PROFILES", cameraTitleA: "From D500 to ZR,", cameraTitleB: "ready to connect.", cameraBody: "The project includes USB / PTP profiles for 20 Nikon cameras across EXPEED 5, 6, and 7. A profile means the app can identify the device and choose parameter ranges; it does not mean every firmware, lens, and host combination has been field-tested.", cameraLink: "Read the camera test checklist", cameraFoot: "Nikon USB Vendor ID · 0x04b0", downloadKicker: "READY WHEN YOU ARE", downloadTitleA: "Bring ZENCHE to your", downloadTitleB: "next shoot.", downloadIntro: "v1.2.0 is released. Packages, checksums, and detailed release notes live in GitHub Releases.", allReleases: "All releases", downloadNote: "Read the platform installation and signing notes before downloading. Keep an in-camera card for important shoots; no tethered app should be your only backup.", openTitleA: "Tools should", openTitleB: "stay on your side.", openBody: "ZENCHE is built around local-first, open, verifiable software. Read the source, release history, security policy, and contribution guide to see how it works.", openButton: "Visit GitHub", footerLine: "Connect your camera. Keep the whole workflow moving.", footerOpen: "Open source · local first"
  }
};

const root = document.documentElement;
const languageButton = document.querySelector('[data-lang-toggle]');
let currentLanguage = 'zh';

function setLanguage(language) {
  currentLanguage = language;
  root.lang = language === 'en' ? 'en' : 'zh-CN';
  document.querySelectorAll('[data-i18n]').forEach((element) => {
    const key = element.dataset.i18n;
    if (language === 'en' && translations.en[key]) element.textContent = translations.en[key];
    else element.textContent = element.dataset.zh || element.textContent;
    if (!element.dataset.zh) element.dataset.zh = language === 'en' ? '' : element.textContent;
  });
  document.querySelectorAll('[data-i18n-alt]').forEach((element) => {
    if (!element.dataset.zhAlt) element.dataset.zhAlt = element.alt;
    element.alt = language === 'en' ? (translations.en[element.dataset.i18nAlt] || element.dataset.zhAlt) : element.dataset.zhAlt;
  });
  languageButton.querySelector('.language-active').textContent = language === 'en' ? 'EN' : '中';
  languageButton.querySelector('.language-active').nextElementSibling.textContent = language === 'en' ? '/' : '/';
  languageButton.querySelector('.language-active').nextElementSibling.nextElementSibling.textContent = language === 'en' ? '中' : 'EN';
}

document.querySelectorAll('[data-i18n]').forEach((element) => { element.dataset.zh = element.textContent; });
document.querySelectorAll('[data-i18n-alt]').forEach((element) => { element.dataset.zhAlt = element.alt; });
languageButton?.addEventListener('click', () => setLanguage(currentLanguage === 'zh' ? 'en' : 'zh'));

const menuToggle = document.querySelector('[data-menu-toggle]');
const mobileNav = document.querySelector('[data-mobile-nav]');
menuToggle?.addEventListener('click', () => {
  const open = mobileNav.classList.toggle('is-open');
  menuToggle.setAttribute('aria-expanded', String(open));
});
mobileNav?.querySelectorAll('a').forEach((link) => link.addEventListener('click', () => {
  mobileNav.classList.remove('is-open');
  menuToggle?.setAttribute('aria-expanded', 'false');
}));

document.querySelectorAll('[data-workflow-tab]').forEach((tab) => {
  tab.addEventListener('click', () => {
    const target = tab.dataset.workflowTab;
    document.querySelectorAll('[data-workflow-tab]').forEach((item) => item.classList.toggle('is-active', item === tab));
    document.querySelectorAll('[data-workflow-panel]').forEach((panel) => panel.classList.toggle('is-active', panel.dataset.workflowPanel === target));
  });
});

document.querySelectorAll('[data-platform]').forEach((tab) => {
  tab.addEventListener('click', () => {
    const target = tab.dataset.platform;
    document.querySelectorAll('[data-platform]').forEach((item) => {
      const active = item === tab;
      item.classList.toggle('is-active', active);
      item.setAttribute('aria-selected', String(active));
    });
    document.querySelectorAll('[data-download-panel]').forEach((panel) => panel.classList.toggle('is-active', panel.dataset.downloadPanel === target));
  });
});

const revealItems = document.querySelectorAll('.reveal');
if ('IntersectionObserver' in window && !window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
  const observer = new IntersectionObserver((entries, currentObserver) => {
    entries.forEach((entry) => {
      if (!entry.isIntersecting) return;
      entry.target.classList.add('is-visible');
      currentObserver.unobserve(entry.target);
    });
  }, { threshold: 0.12 });
  revealItems.forEach((item) => observer.observe(item));
} else revealItems.forEach((item) => item.classList.add('is-visible'));
