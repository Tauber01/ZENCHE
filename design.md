# Design — Nikon Link Native

A locked native design system for Nikon Link. Every native platform reads this
file before changing product UI. Extend this system when a platform needs a new
capability; do not create a separate visual language per platform.

## Scope

- Native implementations only: iOS / iPadOS, Android, HarmonyOS, macOS, Windows.
- Web/PWA files are outside this system unless the user explicitly requests Web work.
- Platform-native controls, navigation, accessibility, typography, and settings
  surfaces take precedence over pixel parity.

## Genre

modern-minimal

## Macrostructure family

- App pages: Workbench — live preview first, contextual controls second, status last.
- Capture pages: preview + always-visible capture actions + core camera parameters.
- Monitor pages: preview + always-visible monitor aids + output controls.
- Library and transfer pages: native list/document layouts using the same hierarchy.

## Theme

- Paper: `oklch(98.5% 0.004 250)`
- Paper secondary: `oklch(96.5% 0.008 250)`
- Ink: `oklch(20% 0.022 258)`
- Muted ink: `oklch(44% 0.018 257)`
- Rule: `oklch(88% 0.012 252)`
- Photo accent: `oklch(49% 0.2 256)` — cobalt
- Video accent: `oklch(50% 0.2 25)` — signal red
- Focus: use the platform accessibility focus colour with at least 3:1 contrast.

Use platform colour APIs and existing native resource tokens. Do not introduce
Web CSS as a dependency of native implementations.

## Typography

- Display: platform system display face, bold, roman.
- Body: platform system UI face, regular.
- Data and camera readouts: platform monospaced face with tabular numerals.
- Maximum five text sizes per screen. Body text is never below the platform's
  accessible default.

## Spacing

Use a 4-point scale: 4, 8, 12, 16, 20, 24, 32, 40. Touch targets are at least
44 × 44 points/dp/vp.

## Navigation and settings

- The active creative page is always visible in primary navigation.
- A settings button is always present in the top app bar or native toolbar.
- The settings button opens or navigates to the platform's existing settings,
  connection, storage, transfer, and diagnostics surface.
- Camera connection remains a separate, clearly labelled action.

## Capture controls

- Remove the global “普通 / 专业” density switch.
- Always show shutter, live view, exposure compensation, focus, and composition
  controls when the platform and connected camera support them.
- Show shutter speed, aperture, ISO, exposure mode, white balance, and picture
  control in the main parameter surface on cameras that expose those capabilities.
- Disabled parameters include a visible reason; never rely on colour alone.

## Monitor controls

- Always show live view state, exposure, zoom, grid/safe-area aids, and output
  controls supported by the platform.
- Zebra, LUT, peaking, supersampling, codec, resolution, and frame-rate controls
  appear only where the native pipeline genuinely implements them.
- Clearly distinguish local preview processing from settings written to the camera.

## Motion and feedback

- Motion is limited to native state transitions and progress feedback.
- No decorative animation, bounce, parallax, or repeated reveal effects.
- Successful visible changes are silent. Failures state what failed and what to do.
- Respect Reduce Motion and each platform's accessibility settings.

## What systems MUST share

- Workbench hierarchy and contextual control grouping.
- Cobalt for photo actions and signal red for video state.
- Persistent settings access.
- No global normal/professional mode switch.
- Honest capability gating and platform-specific explanations.

## What systems MAY differ

- Navigation container, sheets/dialogs, toolbar placement, and control widgets.
- Parameter density according to available screen width.
- Features not implemented by that platform's native camera pipeline.

## Exports

This is a native-only design system. Native resource colours and control styles
remain in each platform project; Web, Tailwind, DTCG, and shadcn exports are
intentionally not generated.
