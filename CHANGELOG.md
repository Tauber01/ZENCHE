# Changelog

## [1.5.12] - 2026-08-11

### Fixed

- Fixed a Windows startup null-reference crash caused by WPF firing XAML
  default-selection events before the complete control tree existed.
- Moved the exposure-mode, video-shutter-mode, and shared-parameter
  initialization guards ahead of cross-control refresh and configuration.
- Preserved the selected video-shutter mode during initialization, then
  restored shutter configuration, parameter availability, and exposure
  readouts after the full interface loaded.

### Validation

- Added three Windows startup-order regression contracts and verified that
  they fail against the pre-fix `77dd405` baseline and pass after the fix.
- The full automated suite passes 518/518. Windows Release publish, NSIS, and
  portable ZIP packaging complete on the macOS cross-build host.
- Windows packages remain without Authenticode and still require real Windows
  cold-start, exposure/video-shutter switching, installation, driver, and
  SmartScreen validation.

## [1.5.11] - 2026-08-10

### Added

- Added persistent desktop workspaces on macOS and Windows. Both restore the
  main-window size and position; Windows also restores the maximized state.
  Saved off-screen windows are moved back into the visible desktop after
  display changes.
- Added draggable, keyboard-accessible splitters for the main navigation,
  capture controls, editor media pool, editor tool panel, and lower editor area.
- Made every desktop splitter resize its content continuously while dragging,
  widened the safe adjustment ranges, and added a dedicated splitter for the
  Windows AI tools panel.
- Added Default, Capture, Monitor, Edit, and Compact workspace presets, plus a
  one-click Restore Default Layout action.

### Fixed

- Added bounded Nikon Z50 busy recovery after SDRAM capture so a still-writing
  JPEG is retried without triggering a second exposure.
- Added Android Camera2 stream-plan fallback for vendor HALs that reject the
  normal two-JPEG session, including a timestamp-separated shared JPEG mode.
- Restored the native AI service default to the production HTTPS account proxy
  and removed obsolete mobile API-key guidance.
- Added visible system-photo import and Save New Copy actions to the Android,
  iOS/iPadOS, and HarmonyOS editors. Manual adjustments and mobile AI retouches
  now create new app copies; exporting creates a new system photo and leaves
  the original unchanged.
- Clarified the sign-in mode choices across all five native clients as
  Existing Account and Create Account, separating them from the actual submit
  button after production logs confirmed the reported click sent no login
  request.
- Kept the Apple submit action label visible beside its progress indicator so
  an in-flight sign-in no longer looks unresponsive.
- Reclaimed macOS AI workspace height by removing its duplicate section
  navigation and the unrelated generic edit footer; Windows AI modes and preset
  groups now reflow with the available panel width.
- Separated the desktop editor's top-level Pro Develop and AI Tools
  modes from its Adjustment Groups, removing the ambiguous duplicate menu row.
- Expanded the lower RGB scope to the available dock area and reduced duplicate
  preview rendering, idle timers, and retained editor bitmaps.
- Added bounded cleanup for Windows AI temporary results when replacing a
  result, switching photos or modes, leaving the editor, or closing the window.

### Known limitations

- Arbitrary floating panels and cross-display panel docking are not included in
  this first workspace release.
- Windows multi-monitor restore and 125%/150%/200% DPI behavior still require
  validation on a real Windows host. Packages remain unsigned or development
  signed according to their existing platform-specific status.

## [1.5.10] - 2026-08-09

### Added

- Added a trusted-LAN iOS / iPadOS camera bridge. Sony's official Camera Remote SDK runs on the macOS bridge; Nikon uses an explicitly identified PTP-compatible bridge.
- Added a Live Monitoring switch to the capture screen on iOS / iPadOS, Android, HarmonyOS, macOS, and Windows.
- Added official-website manifest updates for version 1.5.10 / build 37 with per-platform SHA-256 metadata.

### Changed

- Turning Live Monitoring off now stops preview frames without disconnecting the camera or disabling the shutter.
- Disabled monitoring clears cached preview frames immediately and presents an explicit localized empty state.
- Updated five-platform launch announcements and the Simplified Chinese, English, and Japanese release documentation.

### Known limitations

- Sony and Nikon bridge behavior still requires compatible-camera hardware validation, including live view, capture, recovery, latency, and long-session testing.
- iOS / HarmonyOS packages are unsigned, macOS is ad-hoc signed and not notarized, Windows has no Authenticode signature, and Android uses the existing debug certificate.

All notable changes follow [Keep a Changelog](https://keepachangelog.com/) and
the project uses semantic versioning.

## [1.5.3] - 2026-08-04

### Added

- Added an image-first full-screen monitoring HUD across iOS / iPadOS,
  Android, HarmonyOS, macOS, and Windows with connection/exposure telemetry,
  focus reticles, tool rails, real RGB scope data, an explicit silent-audio
  baseline, and a bottom parameter tray.
- Added device-summary cards, adaptive parameter cards, and a persistent
  capture dock to the five native capture workspaces.
- Added coordinated media-pool, preview, inspector, and analysis-scope regions
  to every native editor while preserving the existing editing and AI actions.

### Changed

- Unified the five native workspaces around a dark studio palette: ZENCHE blue
  identifies primary actions, warm gold is reserved for active parameter
  readouts, and red remains limited to recording and destructive states.
- Expanded Simplified Chinese, English, and Japanese localization for the new
  studio surfaces and synchronized the five-platform launch announcement.
- Raised native metadata and package scripts to version `1.5.3` / build `28`.

### Fixed

- Restored the iOS capture-session controls after the capture workspace redesign.
- Prevented disconnected full-screen HUDs, capture summaries, parameter trays,
  and output readouts from showing initialized camera values as live telemetry.
- Made Android editor rail shortcuts navigate to the existing wheels, curves,
  masks, and AI workspaces instead of showing a placeholder message.
- Added a compact Windows editor breakpoint and completed Simplified Chinese,
  English, and Japanese strings for the new workbench labels and empty states.

### Compatibility

- Camera connection, capture, external recording, file transfer, non-destructive
  editing, AI activation, and device-binding behavior are unchanged. Scope
  panels render measured camera/editor data and never invent telemetry.
- GitHub Release 中的 1.5.3 附件保留各自已有的验证属性：Android 为 Debug 证书，HarmonyOS 与 iOS 未签名，macOS 为 ad-hoc 且未公证，Windows 无 Authenticode 且尚未完成真实 Windows 主机验收。

## [1.5.2] - 2026-08-04

### Added

- Added a global status bar across iOS / iPadOS, Android, HarmonyOS, macOS,
  and Windows for connection state, current operations, and the total local
  library count.
- Added a five-platform Restore Device Code flow that verifies the old proof
  locally, requests a server migration, verifies the replacement code locally,
  and preserves the server-authoritative remaining AI quota.
- Added a loopback-only, zero-dependency redeem signer for migrated activation
  codes. The private key and shared secret are injected at runtime and are not
  stored in the repository.

### Changed

- Hardened the AI proxy with bounded request/upstream/image payloads, UTF-8-safe
  streaming, durable quota persistence, automatic refunds, and fail-stop
  behavior after uncertain storage failures.
- Android USB/PTP now falls back only for known asynchronous transport failures
  and reuses the synchronous path for the current connection after a successful
  fallback, avoiding repeated 10–12 second waits.
- Raised native release metadata to version `1.5.2` / build `27` and synchronized
  launch announcements and localization across all five clients.

### Limitations

- Device migration remains server-disabled until the production DNS/HTTPS,
  reverse-proxy, secret/key injection, and public-port closure gates are met.
- At the time of the 1.5.2 candidate review, those local packages were not yet a
  GitHub stable release. Platform signing, notarization, Windows-host validation,
  and camera-device validation were reported separately with those artifacts.

## [1.5.0] - 2026-08-03

### Added

- Added native external recording across iOS / iPadOS, Android, HarmonyOS,
  macOS, and Windows so photos and video can be stored on the connected smart
  device instead of relying only on the camera card.
- Added streaming Motion-JPEG AVI writers on Android, HarmonyOS, macOS, and
  Windows, with safe RIFF finalization when recording stops or the camera
  disconnects. iOS / iPadOS keeps the native AVFoundation MOV path.
- Added external recordings to project-session naming, dual-destination backup,
  SHA-256 manifests, and each platform's local ZENCHE media library.
- Added 107 Nikon NP3 cloud presets for native photo editing and live photo/video
  monitoring. The SDR approximation is display-only and never alters originals.
- Added native in-camera storage management across all five targets, including
  volume and object browsing, thumbnails, protected-object handling, batch
  download, and confirmed permanent deletion from the camera card.
- Added explicit AP-direct and STA-LAN modes to the native PTP/IP connection
  manager, with topology guidance and remembered mode selection.
- Added a self-hosted update metadata service at `/api/update` (plus the
  `/api/updates` compatibility alias and `/healthz`) and made all native clients
  query `https://zenche.top/api/update` before MirrorChyan and GitHub fallbacks.

### Changed

- PTP recording can now run in parallel: camera-body recording continues while
  live-view frames are written to the smart-device disk when external recording
  is enabled.
- Large video checksum calculation now streams in bounded chunks on iOS / iPadOS
  and HarmonyOS instead of loading the whole file into memory.
- Refined the Nikon cloud monitor card colors and responsive hierarchy, and
  stabilized native preset sheets, dialogs, and bounded drop-down selectors.
- Raised native release metadata to version `1.5.0` / build `25` and synchronized
  launch announcements, localization, package scripts, and three-language README
  documentation across all five native targets.

### Limitations

- Standard PTP live view does not carry an audio track; PTP external recordings
  are therefore silent Motion-JPEG AVI files. Local and UVC sources on iOS /
  iPadOS record MOV through AVFoundation.

### Fixed

- Fixed standard PTP camera-card browsing so USB and PTP/IP transports start
  from the root association and recursively enumerate nested `DCIM` folders
  instead of discarding directory objects and showing an empty file list.
- Fixed macOS camera-card browsing by retaining gphoto2's detailed file-list
  output, including the folder-local indexes, sizes, and deletion flags needed
  by the storage parser, instead of receiving an unparseable quiet path list.

## [1.4.1] - 2026-08-02

### Added

- Added native RGB three-channel waveform and audio waveform monitor cards across
  iOS / iPadOS, Android, HarmonyOS, macOS, and Windows.
- Added monitor-preview tap-to-focus feedback and native focus requests across
  all five targets.

### Changed

- Moved the Android recording control between the RGB and audio waveform cards.
- Removed the monitor lens readout, the monitor “曝光” tool entry, and the
  Android monitor preview fullscreen control.
- Exposed adjustable frame rate, shutter angle, ISO, and related monitor
  parameters directly in the monitor surfaces.
- The audio card reports a silent baseline because no camera audio transport is
  currently available; it does not fabricate live audio levels.
- Raised native release metadata to version `1.4.1` / build `24` and aligned
  package scripts, README downloads, announcements, and validation assets.

## [1.4.0] - 2026-08-02

### Fixed

- Fixed AI reference-image forwarding: the complete selected image data URL is
  sent through the proxy in the upstream `images` array, so edits are based on
  the original photo instead of becoming unrelated generations.
- Added server-authoritative AI quota deduction with remaining-count response
  headers and automatic rollback when an upstream request fails.
- AI retouching now atomically overwrites the current original; AI generation
  continues to save a separate new file.

### Changed

- Synchronized the five native targets and their launch announcements around
  the AI workflow, quota behavior, and original-versus-generated file semantics.
- Reorganized the native professional editor around a DaVinci-style grading
  workflow with Lift / Gamma / Gain color wheels, a master curve, RGB picker,
  and linear, radial, and subject mask controls. These controls are connected
  to native previews and high-quality non-destructive copies on all five
  targets.
- Improved Nikon, Sony, and Canon camera/PTP and professional-editor stability.
- Raised native release metadata to version `1.4.0` / build `23` and aligned
  package scripts, README downloads, and validation assets.

## [1.3.1] - 2026-08-02

### Added

- Rewrote the native launch announcement across all five targets with the
  current AI activation, device-code, redemption, purchase, compatibility, and
  anti-fraud guidance.
- Added the official `https://zenche.top` redemption path and in-app Afdian
  redemption-code purchase guidance to the release documentation and localized copy.

### Changed

- Unified the AI editor announcement around the Pro Develop / AI Tools
  switch, server-side usage counting, and device-bound activation keys.
- Removed the editable AI Server settings entry while keeping legacy configuration
  reads compatible; Nikon, Sony, and Canon camera profiles remain available.
- Raised native release metadata to version `1.3.1` / build `22` across all five
  targets and aligned package scripts, README downloads, and checksums.

## [1.3.0] - 2026-08-01

### Added

- Added AI photo editing and image generation to the native Image Editor across
  all five platforms, powered by the nano-banana image model.
- Added quick preset prompts including one-tap beautify, natural enhance, film
  grain, Japanese-clean, high-contrast B&W, retro warm tone, sky enhance, and
  food enhance, plus generation presets for portraits, landscapes, city night,
  and product shots.
- Added an activation-code licensing flow: each code binds to one device,
  enables 100 generations, and is counted server-side. The open-source clients
  embed no model API key; the author's proxy server holds the key and forwards
  requests.

## [1.2.0] - 2026-07-30

### Added

- Added a prominent native branch-library workspace across all five platforms,
  including nested user branches, branch deletion, persistent drag-and-drop
  organization, full-row disclosure targets, and thumbnails inside branches.
- Added a professional non-destructive image editor with grouped light, color,
  detail, effects, and geometry adjustments, transparent presets, before/after
  comparison, reset-all, and high-quality JPEG copy export.
- Added expandable secondary full-screen camera controls while keeping the
  primary mobile parameter tray compact and touch targets accessible.

### Changed

- Replaced phone branch trees with default-collapsed drawers while retaining
  always-visible trees on tablet, foldable-expanded, and desktop layouts.
- Aligned professional editing parameters, presets, geometry, localization,
  and export behavior across iOS/iPadOS, Android, HarmonyOS, macOS, and Windows.
- Promoted the native Image Editor to a primary navigation destination on every
  supported platform.

## [1.1.0] - 2026-07-30

### Added

- Integrated MirrorChyan-first update checks, optional CDK input, platform
  credential storage, full-package filtering, and automatic GitHub fallback
  across iOS / iPadOS, Android, HarmonyOS, macOS, and Windows.
- Added interval capture, exposure bracketing, focus bracketing, timed Bulb,
  cancellation, and progress reporting across all five native applications.
- Added capture sessions with project directories, naming templates,
  RAW + JPEG pairing, XMP ratings, dual-destination backup, and SHA-256
  manifests.
- Added RGB histograms, waveform and vectorscope readouts, focus peaking, and
  false-color monitoring without modifying original media.

### Fixed

- Added Nikon photo/video shutter-property fallback across macOS, Android,
  HarmonyOS, and Windows for bodies that expose the standard PTP shutter
  property as read-only.
- Delayed Nikon remote-mode takeover until a Bulb capture actually starts,
  restored body control afterward, and hardened live-view recovery after
  exclusive camera operations.
- Prevented macOS continuous live view from slowing over time when the bundled
  `gphoto2` process fills its standard-error pipe.
- Made tag release publication idempotent and required a detailed Simplified
  Chinese release-notes file instead of generated notes.

## [1.0.0] - 2026-07-30

### Added

- Added complete in-app Simplified Chinese, English, and Japanese language
  selection across all five native applications.
- Added the versioned launch announcement, anti-fraud notice, donation entry,
  and update guidance to the native clients.
- Added final bilingual promotional deliverables and English launch materials.

### Changed

- Promoted 帧澈 ZENCHE to the stable 1.0.0 release with aligned version/build
  metadata, download names, and documentation.
- Refined native layouts, runtime-localized connection states, and
  platform-specific installation guidance.

## [0.8.3] - 2026-07-30

### Added

- Added the canonical 帧澈 ZENCHE identity, geometric Z mark, bilingual lockup,
  product descriptor, English brand line, and canonical slogan.
- Added launch-promotion source assets and synchronized Chinese/English
  promotional pages.

### Changed

- Renamed public-facing product copy and packages to ZENCHE while preserving
  legacy internal identifiers required for upgrades and source compatibility.
- Rewrote README documentation in complete Simplified Chinese, English, and
  Japanese sections and synchronized packaging guidance.

## [0.8.1] - 2026-07-29

### Added

- Added concurrent FTP/PASV, authenticated HTTP PUT/POST, and WebDAV image
  inboxes across macOS, Windows, Android, HarmonyOS, and iOS/iPadOS.
- Added a versioned Windows NSIS `Setup.exe` with shortcuts, in-place upgrades,
  registered uninstall support, portable ZIP output, and SHA-256 checksums.

### Changed

- Refined the native mobile and desktop workspaces, monitoring controls,
  diagnostics, packaging metadata, and responsive layouts.

### Fixed

- Fixed Android USB permission completion on Android 13–16 devices whose
  privileged permission component does not reliably deliver fill-in extras.
- Fixed Nikon Z30 USB/PTP session startup by using transaction ID zero for
  `OpenSession`, recovering stalled endpoints, and retrying with a PTP device
  reset when initial transport setup fails.

## [0.8.0] - 2026-07-29

### Added

- Added native USB/PTP profiles for all ten Nikon EXPEED 6 bodies: Z7, Z6,
  Z50, D780, D6, Z5, Z7II, Z6II, Z fc and Z30.
- Added exact EXPEED 6 USB Product IDs across macOS, Android, Windows and
  HarmonyOS, including descriptor matching that distinguishes first- and
  second-generation Z6/Z7 bodies.

## [0.7.3] - 2026-07-29

### Added

- Added privacy-redacted, rolling local diagnostic logs and a prefilled GitHub
  Issue reporting action to every native client.
- Added native Windows 11 support with a WPF workbench, direct libusb Nikon
  USB/PTP transport, live view, SDRAM capture, camera controls, a local photo
  library, and a foreground FTP/PASV inbox.
- Added a native HarmonyOS Stage/ArkUI application with USB Host permission
  handling, chunked Nikon PTP transport, live view, capture, camera controls,
  an app-private photo library, and a foreground FTP/PASV inbox.
- Added reproducible Windows and HarmonyOS packaging scripts plus platform
  setup, signing, driver, permission, and hardware-acceptance documentation.

## [0.7.2] - 2026-07-29

### Fixed

- Prevented the Android header and connection status from overlapping system
  bars, display cutouts and HyperOS capsule notifications.

## [0.7.1] - 2026-07-29

### Added

- Added native USB/PTP profiles for every current EXPEED 7 body: Z9, Z8, Z f,
  Z6III, Z50II, Z5II and ZR, with exact Product IDs plus a Nikon descriptor
  fallback for firmware or platform USB-reporting differences.
- Added complete English and Japanese README documentation alongside Chinese.

### Changed

- Separated photo capture and video monitoring into clearly grouped workspaces
  across the web, macOS, Android and iOS/iPadOS interfaces.
- Moved zebra, peaking, histogram, LUT and monitor-output controls into the
  video workspace while keeping exposure and still-capture controls in photo.

## [0.7.0] - 2026-07-28

### Added

- Added exposure-program-aware control locking on macOS and Android.
- Added adjustable highlight zebra overlays for native live view.
- Added custom 3D `.cube` LUT import for non-destructive live-view monitoring.
- Added Nikon Picture Control presets to the native professional controls.
- Added native monitor-page parameter controls, 2× supersampling, codec preferences
  and selectable video specifications across macOS, Android and iOS/iPadOS.
- Added a native SwiftUI iOS/iPadOS app with selectable AVFoundation cameras,
  responsive iPhone/iPad layouts, capture, focus, exposure and zoom controls.
- Added iOS foreground FTP receiving, local photo management, system Photos
  export, native sharing, unsigned CI packaging and a signed IPA workflow.

### Changed

- Aligned native controls with Nikon Simplified Chinese menu terminology,
  represented Bulb as an M-mode shutter speed, and corrected Android AF-S,
  AF-C and preset white-balance PTP values.
- iOS now negotiates supported video specifications with the active system video
  device. Nikon PTP monitoring keeps its camera-native JPEG source and clearly
  limits codec selection while applying local resampling options.
- Added iOS lifecycle handling so camera sessions pause cleanly and local
  network receiving stops when the app moves to the background.

## [0.6.0] - 2026-07-28

### Added

- Added P, M, A, S and B exposure programs on macOS and Android.
- Added selectable 1–60 second Nikon bulb capture durations.
- Added a native passive-mode FTP receiver for direct Wi-Fi image transfer
  from supported Nikon cameras.
- Added automatic local-library import for JPEG, NEF, HEIF, HEIC and TIFF
  uploads.

### Changed

- Rebuilt the macOS disk image with both the app and an Applications shortcut
  for standard drag-to-install behavior.
- Expanded the transfer screen with live server address, port and camera setup
  instructions.

## [0.5.0] - 2026-07-28

### Added

- Added native USB/PTP detection for Nikon Z f (`0x0453`), Z6III (`0x0454`)
  and Z5II (`0x0456`) alongside the existing Z8 (`0x0451`).
- Added per-camera identity throughout connection, live-view, capture and error
  states on macOS and Android.
- Added a macOS USB Product ID fallback for Z5II when libgphoto2 reports it as
  a generic PTP camera.
- Added per-model ISO ranges and graceful connection when live view is not
  exposed by the current camera firmware.

### Changed

- Replaced Z8-only UI copy and USB filtering with a strict supported-camera
  registry.
- Expanded hardware acceptance checks to cover all four supported models.

## [0.4.0] - 2026-07-28

### Changed

- Replaced the packaged macOS WebView shell with a native SwiftUI/AppKit
  application.
- Replaced the packaged Android WebView shell with native Android Views.
- Connected native controls directly to the existing Z8 USB/PTP camera cores.
- Added native live-view, capture, professional parameter and local file
  management screens on both platforms.
- Removed HTML, CSS and JavaScript assets from DMG and APK builds.

## [0.3.1] - 2026-07-28

### Fixed

- Fixed unresponsive controls in the packaged macOS and Android apps.
- Bundled native WebView scripts into a classic single-file entry point to avoid
  local `file://` ES module restrictions.
- Removed redundant global `inert` locking and made the connection dialog open
  immediately.
- Added a timeout and memory fallback for local photo-library initialization.

## [0.3.0] - 2026-07-28

### Added

- Native Nikon Z8 USB/PTP connection on macOS and Android.
- Live view, tethered capture and JPEG transfer.
- Exposure, focus and white-balance parameter bridge.
- Reproducible DMG/APK build scripts and GitHub Actions workflows.
- Third-party notices, checksums and Z8 hardware acceptance checklist.

## [0.2.0] - 2026-07-28

### Added

- Browser/PWA camera connection, capture and offline support.
- IndexedDB photo library with import, download, delete and undo.
- Simple and professional experience modes.
