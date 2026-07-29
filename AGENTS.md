# NikonLink project instructions

- Product and interface changes must target the native implementations by default:
  - iOS / iPadOS: `native/ios/`
  - Android: `native/android/`
  - HarmonyOS: `native/harmony/`
  - macOS and Windows when desktop scope is explicitly requested.
- Do not implement product or interface changes in the Web/PWA files (`index.html`, `styles.css`, `app.js`, service worker, or browser services) unless the user explicitly requests Web/PWA work.
- For mobile UI work, keep iOS, Android, and HarmonyOS behavior aligned while using each platform's native controls and conventions.
- Any change to the main application code is not complete until the affected native platforms have been packaged into deliverable artifacts after validation. In the final response, provide clickable absolute paths to every generated package so the user can download them directly.
- Package the platforms whose application code or shared behavior changed; when a cross-platform change affects every native implementation, package iOS / iPadOS, Android, HarmonyOS, macOS, and Windows.
- Prefer installable or distributable outputs over source archives (for example IPA or XCArchive, APK, HAP, macOS app/DMG, and Windows installer). Also generate checksums when the existing platform release workflow supports them.
- If packaging is blocked by unavailable signing credentials, platform tooling, or a host-OS restriction, do not silently substitute a build-only result. Complete every package that can be produced, then name the blocked platform, the exact blocker, and the expected artifact.
- After completing any Windows implementation change, run `scripts/build-windows.ps1` and produce the versioned `dist/NikonLink-<version>-Windows-<architecture>-Setup.exe` installer and its SHA-256 file before handing the work off. A source-only Windows change is not complete.
