# 帧澈 ZENCHE project instructions

- Preserve legacy internal identifiers such as `NikonLink` and
  `com.tauber.nikonlink` when changing them would break app upgrades, signing,
  persisted preferences, or source compatibility. They are not public brand copy.
- Product and interface changes must target the native implementations by default:
  - iOS / iPadOS: `native/ios/`
  - Android: `native/android/`
  - HarmonyOS: `native/harmony/`
  - macOS: `native/macos/`
  - Windows: `native/windows/`
- Unless the user explicitly limits platform scope, every product, interface, and
  shared-behavior request must be implemented and kept aligned across all five
  native targets: iOS / iPadOS, Android, HarmonyOS, macOS, and Windows.
- Do not implement product or interface changes in the Web/PWA files (`index.html`, `styles.css`, `app.js`, service worker, or browser services) unless the user explicitly requests Web/PWA work.
- For mobile UI work, keep iOS, Android, and HarmonyOS behavior aligned while using each platform's native controls and conventions.
- Any change to the main application code is not complete until the affected native platforms have been packaged into deliverable artifacts after validation. In the final response, provide clickable absolute paths to every generated package so the user can download them directly.
- Package the platforms whose application code or shared behavior changed; when a cross-platform change affects every native implementation, package iOS / iPadOS, Android, HarmonyOS, macOS, and Windows.
- Prefer installable or distributable outputs over source archives (for example IPA or XCArchive, APK, HAP, macOS app/DMG, and Windows installer). Also generate checksums when the existing platform release workflow supports them.
- If packaging is blocked by unavailable signing credentials, platform tooling, or a host-OS restriction, do not silently substitute a build-only result. Complete every package that can be produced, then name the blocked platform, the exact blocker, and the expected artifact.
- After completing any Windows implementation change, run `scripts/build-windows.ps1` and produce the versioned `dist/ZENCHE-<version>-Windows-<architecture>-Setup.exe` installer and its SHA-256 file before handing the work off. A source-only Windows change is not complete.

## Signing continuity

- Every future build, package, update, and release must preserve the existing
  signing identity for its target platform so that users can upgrade in place
  and verify a continuous publisher identity.
- Reuse the established application identifiers, signing certificates, keys,
  provisioning profiles, entitlements, publisher identity, and update-signing
  configuration appropriate to each platform. Never rotate, replace, or fall
  back to a different signing identity merely to make a package succeed.
- Do not publish an unsigned, ad-hoc-signed, development-signed, or differently
  signed artifact as an official update when the established release signing
  material is unavailable. Produce all consistently signed artifacts that are
  possible, then report the exact missing credential or tooling as a blocker.
- Before handing off an update, verify its signing identity against the previous
  official release wherever platform tooling supports that comparison, and
  report the signing status in the release notes.

## Device identity continuity

- A user's device code must remain unchanged across application upgrades and
  across uninstalling an older version and installing a newer version on the
  same device.
- Implement device-code persistence with a platform-appropriate, stable identity
  mechanism rather than ordinary application preferences, caches, databases, or
  other storage that the operating system removes during uninstall.
- Keep the device-code derivation and migration behavior compatible with every
  previously released version. Never regenerate an existing device code merely
  because the application was upgraded, reinstalled, migrated, or could not read
  a newly introduced storage location.
- Validate device-code continuity with upgrade and uninstall/reinstall tests on
  iOS / iPadOS, Android, HarmonyOS, macOS, and Windows before releasing an update.
  If an operating-system restriction makes strict continuity impossible on a
  target, treat it as a release blocker and report the exact restriction rather
  than silently issuing a new device code.

## Brand identity and promotional copy

- Canonical Chinese product name: `帧澈`
- Canonical international product name: `ZENCHE`
- Canonical bilingual lockup: `帧澈 ZENCHE`
- Product descriptor: `跨平台相机控制与影像传输工具`
- English brand line: `Capture · Connect · Flow`
- Canonical slogan: `连接相机，也连接完整工作流`
- Canonical brand mark: the blue geometric `Z` in `icons/app-icon.svg`; promotional
  assets may use the equivalent `PV/assets/branding/zenche-z-mark.svg`.
- Do not substitute the former `澈` character tile for the canonical `Z` mark.
- Promotional materials must not substitute `完整创作流` or another variation for
  the canonical slogan.

## Documentation and release language

- Every completed task that changes repository files must, before handoff, update
  all three long-term memory documents in the same work cycle:
  `docs/PROJECT_OUTLINE.md`, `docs/TECHNICAL_APPROACH.md`, and
  `docs/TASK_PROGRESS.md`. This applies to code, product behavior,
  configuration, tests, validation, packaging, release, and documentation-policy
  changes; do not update only one of the three. Read-only investigation or advice
  that produces no repository change is exempt.
- Keep the three records complementary: `PROJECT_OUTLINE.md` captures durable
  product scope and release baseline; `TECHNICAL_APPROACH.md` captures engineering
  contracts and implementation decisions; `TASK_PROGRESS.md` captures the actual
  work, evidence, artifacts, signing state, blockers, and next action. These files
  are the project's long-term memory and must not rely on chat history.
- `README.md` must always contain complete Simplified Chinese, English, and
  Japanese versions in that order.
- The three README language sections must remain materially equivalent. Any
  product, platform, compatibility, installation, usage, build, security, or
  release-status change documented in one language must be synchronized to the
  other two in the same change.
- Every GitHub Release description must be written in detailed Simplified
  Chinese. Do not publish an empty body, a terse commit list, or automatically
  generated notes as the final release description.
- Every new version (every GitHub upload counts as a new version) must also
  update the in-app update-announcement popup content across all five native
  platforms. The announcement text describing new features and changes must
  be materially equivalent in every platform's implementation.
- A detailed Release description must cover the version highlights, platform
  changes, supported-camera or compatibility changes, package and signing
  status, validation performed, known limitations, upgrade guidance, and
  SHA-256 verification where applicable.
