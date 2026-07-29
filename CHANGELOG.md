# Changelog

All notable changes follow [Keep a Changelog](https://keepachangelog.com/) and
the project uses semantic versioning.

## [Unreleased]

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
