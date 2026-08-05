<!-- Hallmark · pre-emit critique: P5 H5 E4 S5 R5 V4 -->

# Design — 帧澈 ZENCHE Native

A locked native design system for 帧澈 ZENCHE. Every native platform reads this
file before changing product UI. Extend this system when a platform needs a new
capability; do not create a separate visual language per platform.

## Scope

- Native implementations only: iOS / iPadOS, Android, HarmonyOS, macOS, Windows.
- Web/PWA files are outside this system unless the user explicitly requests Web work.
- Platform-native controls, navigation, accessibility, typography, and settings
  surfaces take precedence over pixel parity.

## Splash screen

- Every native application shows a branded launch screen on cold start.
- Content: the geometric Z mark centred on a graphite rounded rectangle, followed
  by the bilingual lockup "帧澈 ZENCHE" and "Capture · Connect · Flow".
- Animation: Z mark scales up with a spring curve (≈600 ms), brand text fades in
  (≈400 ms after 500 ms delay), then the splash dissolves (≈500 ms fade) after
  a total hold of approximately 2.2–2.5 seconds.
- Background: `Paper` (`oklch(98.5% 0.004 250)`, #F7F9FC).
- No interactive elements, no skip button, no looping animation.
- The main workspace must not paint behind the splash; use an overlay or a
  separate window/surface so the first frame of the main UI is hidden until the
  splash completes.

## Genre

modern-minimal

## Macrostructure family

- App pages: Workbench — live preview first, contextual controls second, status last.
- Capture pages: preview + always-visible capture actions + core camera parameters.
- Monitor pages: preview + always-visible monitor aids + output controls.
- Library and transfer pages: native list/document layouts using the same hierarchy.

## Theme

The calibrated workbench tokens replace the original near-white palette. Use
these sRGB values as the cross-platform source of truth; platform resource APIs
may expose equivalent dynamic colours for system dark appearance.

| Token | Light | Dark | Purpose |
| --- | --- | --- | --- |
| Workbench | `#E9EDF2` | `#131519` | Application background |
| Workbench secondary | `#E4E9EF` | `#23272E` | Sidebars and recessed navigation |
| Surface | `#F8FAFC` | `#1B1E24` | Tool panels and control surfaces |
| Surface raised | `#FFFFFF` | `#23272E` | Dialog and raised-card surface |
| Ink | `#171C26` | `#ECEEF2` | Primary text |
| Muted ink | `#5A616C` | `#9AA1AD` | Secondary text |
| Rule | `#CFD6DF` | `#FFFFFF1F` | Dividers and quiet borders |
| Photo accent | `#1673E6` | `#2E86E0` | Photo actions and selected state |
| Photo soft | `#DCEAFD` | `#14293E` | Photo selection background |
| Video accent | `#D8323A` | `#FF5257` | Recording and video state |
| Video soft | `#FBE2E3` | `#3A1B1E` | Video selection background |
| Positive | `#1FA869` | `#35C97B` | Connected and successful state |
| Graphite | `#0A0B0D` | `#0A0B0D` | Colour-stable preview well |
| Readout glow | `#6BAEFF` | `#6BAEFF` | User-writable exposure values |
| UI accent | `#CDDC39` | `#CDDC39` | Capture control-surface selected and active state |
| Studio gold | `#D8B653` | `#D8B653` | Parameter readouts and adjusting-state markers only |
| Editor accent | `#E8833A` | `#E8833A` | Editor selected tool and scope readouts |

- UI accent, Studio gold, and Editor accent are the only additional accent
  colours. Studio gold marks parameter readouts and in-progress adjustments; it
  never becomes a selection or capture-action accent — selected and active
  states on capture control surfaces use UI accent, and photo actions keep
  Photo accent cobalt. Editor accent is confined to the image editor and
  scopes. Where Readout glow and Studio gold could overlap, the split is by
  surface: user-writable values inside calibration readout surfaces use
  Readout glow, while parameter readouts and adjusting-state markers on
  control-surface tiles and inspectors use Studio gold.
- Focus uses the platform accessibility focus colour with at least 3:1 contrast.
- Preview wells stay graphite in every appearance so ambient UI colour never
  changes colour-critical image judgement.
- Use solid semantic fills for commands. A restrained photo-accent gradient is
  reserved for the compact Z brand mark and never becomes a page background.

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

## Calibration readouts

- Desktop platforms (macOS, Windows) present this group of readouts in exactly
  one persistent form: either a compact graphite calibration rail directly
  after the preview and before capture actions, or the platform's persistent
  parameter inspector. Both forms are equivalent; a platform does not need
  both.
- Touch platforms (iOS/iPadOS, Android, HarmonyOS) present the same values in
  the main parameter tile surface instead of a separate rail, keeping the
  capture workspace single-column and uncluttered. The platform's real source
  may stay in the existing status surface; it is not required inside the tile.
- Readouts use monospaced tabular numerals and expose the platform's real
  source, mode, shutter or shutter angle, aperture when available, ISO, and
  exposure compensation.
- Values currently writable by the user use `Readout glow`; camera-controlled
  values use high-contrast neutral text and an explicit `AUTO` label.
- A disconnected camera or unavailable source shows em-dash placeholders and
  never presents model defaults as live camera values.
- Readouts are informational. Existing native parameter controls remain the
  editing surface, and readouts must not introduce a second write path.
- Narrow layouts may horizontally scroll or reduce the number of simultaneous
  fields, but values and labels must not overlap or resize the surrounding page.

## Capture workflow hierarchy

The capture workspace follows the decisions made during a real production day,
rather than exposing one undifferentiated list of camera properties:

1. **Session and delivery** — project name, naming template, creator and rights
   metadata, default rating, RAW + JPEG pairing, backup destination, and
   checksum manifest. This appears before camera setup so captured files have a
   destination and identity from the first frame.
2. **Exposure** — exposure mode first, followed by shutter or shutter angle,
   aperture, ISO, exposure compensation, and timed Bulb when the selected mode
   permits it. Mode-dependent locks remain visible and explain ownership.
3. **Focus and colour** — autofocus mode or focus position, white balance, and
   picture control. Composition aids and local zoom stay beside the preview
   because they change framing rather than the recorded camera property set.
4. **Capture automation** — interval capture, exposure bracketing, focus
   bracketing, and timed Bulb share one task surface with task-specific count,
   interval, duration, and step fields.
5. **Monitor and handoff** — live-view format, frame-rate reference, focus
   peaking, false colour, scopes, LUT, wireless receipt, library organisation,
   and verified export remain downstream of capture setup.

- Native targets expose only parameters backed by a working platform or camera
  capability. Future drive-mode, metering, image-quality, colour-space, flash,
  and video-codec controls plug into the relevant group after capability
  discovery; they are not shown as speculative or disabled placeholders.
- Supported-camera inventories belong in compatibility documentation and help.
  They never substitute for the current source in a status badge, preview
  overlay, connection prompt, or disconnected empty state.
- Mobile targets may collapse the session and automation surfaces, while desktop
  targets may keep exposure and focus/colour in a persistent inspector. The
  order and terminology remain aligned across platforms.

## Monitor controls

- Always show live view state, exposure, zoom, grid/safe-area aids, and output
  controls supported by the platform.
- Zebra, LUT, peaking, supersampling, codec, resolution, and frame-rate controls
  appear only where the native pipeline genuinely implements them.
- Clearly distinguish local preview processing from settings written to the camera.

## Waveform scopes

- Every native waveform uses the same colour-stable oscilloscope treatment:
  black plot wells with a subtle blue cast, a square high-contrast outer frame,
  three white quarter guides, a thin upper envelope, and a dense luminous particle
  cloud beneath it. Waveform data is never shown as a text-only block-character
  sparkline or a single clean chart line.
- Scope data is a spatial density measurement, not a column-average graph. Map
  each sampled source pixel to source X and its Y′, R′, G′, B′, Cb, or Cr level,
  accumulate a two-dimensional 64 × 48 density field, then apply logarithmic
  intensity compression for display. Preserve the decoded frame's full signal
  range and keep the channel calculation aligned with BT.709 coefficients.
- Luma traces are neutral white. YUV overlays keep green, blue/cyan, and
  magenta/red channels distinguishable. RGB parade views divide the plot into
  three equal, labelled R, G, and B channels using signal red, green, and blue.
- Compact monitor layouts may show an RGB parade and audio plot as separate
  cards. The professional monitor panel combines Y, YUV, and RGB plots in that
  order so exposure, colour balance, and per-channel clipping remain scannable.
- A missing audio source uses a centred cyan baseline and exposes the localized
  empty-source state to accessibility without placing status copy inside the plot.
  It must not fabricate audio activity.
- Scope labels are measurement metadata in the platform monospaced face. Keep
  them small, centred beneath the plot frame, and quiet without reducing plot
  contrast or shrinking touch targets. RGB parade plots show separate R, G, and B
  labels beneath their thirds instead of a corner title.
- Scope plots contain no decorative signature, watermark, corner branding, or
  borrowed application chrome.

## System album and cloud drives

- File management uses one native disclosure hierarchy on every platform:
  source → media type → file. Sources include System Album, Wireless Transfer,
  and 帧澈 ZENCHE Library; media types are Photos and Videos.
- The 帧澈 ZENCHE Library source also exposes user-created organizational
  branches. A branch may contain child branches at any depth and persists across
  launches. Creating a branch never moves, duplicates, or mutates the underlying
  media file; unassigned media remains under a clearly labelled Unclassified node.
- Branch organization is a primary workspace, not a secondary subsection of
  transfer settings. Its primary-navigation label is Branch or Branch Library,
  the branch workbench appears before system albums and wireless-transfer
  sources, and the workbench uses the photo accent for a clear visual anchor.
- Phone layouts present the branch workbench as a default-collapsed Branch
  Drawer so the file page opens at a practical density. The full drawer header
  is the disclosure target and shows root-branch and unclassified counts.
  Tablet, foldable-expanded, and desktop layouts keep the branch tree visible.
- Local library files can be dragged between branches or back to Unclassified.
  Desktop platforms start dragging directly; touch platforms use the native
  press-and-hold drag gesture. Valid targets gain a cobalt border/background,
  the destination expands after a successful drop, and the assignment persists
  across launches.
- Dragging changes only the file's organizational assignment inside 帧澈 ZENCHE.
  It never renames, duplicates, or relocates the underlying file on disk.
- Deleting a branch requires a destructive confirmation and recursively removes
  its child-branch structure. Assigned media returns to Unclassified; the
  underlying files remain untouched.
- Tree rows use restrained guide lines, indentation, native disclosure affordances,
  and counts. New-branch actions are available both at the library root and on
  every user branch so hierarchy creation is discoverable without a context menu.
- The disclosure hit target covers the chevron, branch name, and file count
  region rather than only the small indicator. Create and delete actions remain
  separate targets to prevent accidental toggles.
- Photo rows keep a visible thumbnail after assignment to any user branch.
  Unsupported image formats use the native photo placeholder; videos use an
  explicit play-state placeholder.
- Source and media-type rows are independently collapsible, retain their expanded
  state while the page is active, and show counts before the user expands them.
- The file page reads the owner's system photo library directly after native
  permission is granted. It does not require a separate import step.
- System-album media is read-only inside 帧澈 ZENCHE. Label its source and keep
  destructive actions limited to files stored in the 帧澈 ZENCHE library.
- Photos and videos share one recent-media strip or grid; video items always carry
  an explicit video or duration indicator.
- The cloud-drive entry opens a second-level native guide before leaving 帧澈 ZENCHE.
  The guide names the provider, explains the three-step connection flow, and offers
  both the provider's official service and the platform file picker.
- Cloud credentials remain in the provider's app or browser. 帧澈 ZENCHE never asks
  users to enter a cloud-drive password.
- The supported guide set is Baidu Netdisk, Aliyun Drive, Tencent Weiyun, Quark
  Cloud Drive, Xunlei Cloud Drive, and 115.

## In-camera storage

- In-camera storage is a first-class source in the native Library/File workspace
  on iOS / iPadOS, Android, HarmonyOS, macOS, and Windows. It uses standard
  PTP object operations over USB/PTP or Wi-Fi PTP/IP; system/UVC cameras show a
  clear unavailable state instead of an empty or simulated card.
- The source is a native disclosure surface. Its summary shows storage volumes,
  total/free capacity when the camera reports it, object count, and current task
  status. File rows show a thumbnail or explicit media placeholder, filename,
  size, capture date, dimensions when known, and protected state.
- Refresh, selection, batch download, and delete are separate native controls
  with at least 44-point targets. Protected objects are visible but cannot be
  selected for deletion.
- Download copies the original object into the existing 帧澈 ZENCHE capture
  workflow and library, preserving its file extension and applying the active
  session's naming, backup, metadata, and integrity behavior. Download never
  removes the camera copy.
- Delete acts on the camera memory card and is irreversible from 帧澈 ZENCHE.
  Every delete requires a native destructive confirmation that includes the
  selected count and explicitly says that the operation cannot be undone.
- Storage commands are serialized with capture commands. If live view is active,
  the native camera service pauses it before object operations and attempts to
  restore it afterward so the PTP session is not used concurrently.
- iOS / iPadOS exposes this source for connected Wi-Fi PTP/IP cameras. Android,
  HarmonyOS, macOS, and Windows also expose USB/PTP where their native platform
  connection allows it. A vendor SDK session that does not expose object
  enumeration directs the user to a standard USB/PTP or PTP/IP connection.

## Image editor

- Image Editor is a primary navigation destination on iOS / iPadOS, Android,
  HarmonyOS, macOS, and Windows rather than an action hidden inside a file menu.
- The professional-develop workspace follows the interaction depth of modern
  non-destructive raw developers without copying Adobe Camera Raw branding,
  proprietary icons, wording, panel order, or trade dress. It remains visibly
  and structurally part of 帧澈 ZENCHE.
- Adjustments are divided into focused native groups: Light (exposure,
  contrast, highlights, shadows, whites, blacks), Color (temperature, tint,
  vibrance, saturation), Color Wheels, Curves, Picker, Mask, Detail (texture,
  clarity, sharpening, noise reduction), Effects (dehaze, vignette), and
  Geometry (quarter rotation, horizontal/vertical flip, centered aspect-ratio
  crop). A separate AI-tools mode hosts generative/assisted tools; the
  professional and AI modes are an explicit, stable in-editor switch — never a
  global density toggle and never changed implicitly by navigation.
- Original, Natural Enhance, Soft Portrait, Clear Landscape, and High-Contrast
  B&W presets provide transparent starting points by changing the same visible
  sliders; presets are not opaque filters.
- A direct before/after action switches the dominant preview between Original
  and Adjusted states. Reset All clears every tonal and geometry change.
- Preview changes are immediate and non-destructive. The original file is never
  overwritten; Save High-Quality Copy exports a new 95-quality JPEG into the
  帧澈 ZENCHE library and selects the saved result.
- Apple targets use Core Image filters for exposure, white balance, tonal range,
  vibrance, local contrast, sharpening, noise reduction, and vignette. Android,
  HarmonyOS, and Windows use aligned pixel-domain tone, adaptive saturation,
  detail, vignette, geometry, and export pipelines.
- Videos and image formats that the platform cannot reliably decode, including
  unsupported RAW files, do not appear in the editor picker. Empty states explain
  this limitation instead of exposing controls that cannot complete.
- The preview remains the dominant surface. Sliders use native controls and
  preserve accessible touch targets; export is the single visually dominant
  action in the adjustment panel.

## Immersive preview

- Photo and video workspaces provide an explicit full-screen action with a minimum
  44 × 44 point/dp/vp target.
- Full-screen mode uses an edge-to-edge live image as the primary surface. Controls
  form sparse edge rails: status and exit at the top, mode and connection at the
  left, photo/video capture at the right, and exposure readouts at the bottom.
- Preserve the live image's focal area. Controls use compact dark translucent
  surfaces or native material so they remain legible without obscuring the frame.
- Full-screen camera parameters live in a collapsible, horizontally scrollable
  bottom tray. It exposes every genuinely writable core parameter without forcing
  the image to shrink.
- The tray has two levels: a compact primary row for shutter/shutter angle,
  aperture, ISO, and exposure compensation, plus an independently expandable
  More Parameters row for shooting mode, frame rate, focus, white balance,
  picture control, video specification, or monitor aids supported by that target.
- On phone layouts, parameter value columns and visual chrome are compacted while
  each decrement/increment action retains a minimum 44 × 44 point/dp/vp hit area.
- Exposure time, aperture, ISO, exposure compensation, and shutter angle advance
  in camera-standard fine increments (normally 1/3 stop). Values outside the
  connected camera's enumerated or ranged capabilities never become selectable.
- Camera mode rules lock parameters before a write is attempted. State-sensitive
  PTP read-only flags are advisory: pause live view and try the supported property
  candidates before disabling a control, so temporary firmware state is never
  mistaken for a permanent capability limit.
- Photo capture uses cobalt; active video capture uses signal red. Text and icons
  remain white or platform-high-contrast against the dark overlay.
- Every visible control performs a real action. Unsupported camera functions are
  omitted or visibly disabled with a reason.
- The reference-derived composition is 帧澈 ZENCHE chrome, not a reproduction of
  another camera application's branding, labels, or ornamental controls.
- Full-screen exit, system back gestures, keyboard Escape, and accessibility focus
  must all return to the previous workspace without losing the live session.

## Motion and feedback

- Motion serves two purposes: branded launch (splash) and functional UI feedback.
- Splash animation is the only decorative motion; it runs once per cold start
  and does not repeat.
- Within the main workspace, motion is limited to native state transitions
  (section changes, sheet presentation) and progress feedback (spinners,
  indeterminate bars).
- No bounce, parallax, or repeated reveal effects in the workspace.
- Successful visible changes are silent. Failures state what failed and what to do.
- Respect Reduce Motion and each platform's accessibility settings.
  When Reduce Motion is active, the splash appears instantly without scale
  animation and fades out after a shorter hold.

## Dialogs and support guidance

- Dialogs use a restrained card hierarchy: a concise icon-and-title header,
  grouped content cards, one visually dominant action, and a clearly reachable
  close action. Long announcements scroll inside the dialog while the close and
  reminder controls remain easy to reach.
- Use platform-native sheets, dialogs, windows, focus handling, and dismissal
  behavior. Do not imitate another platform's modal chrome.
- Donation surfaces identify the bundled QR code as 爱发电 / Afdian and provide a
  native action that opens `https://www.ifdian.net/a/Tauber`.
- The launch announcement, donation dialog, and issue-reporting surface all state
  that public issues remain free on GitHub and that users who sponsor through
  爱发电 can obtain a faster problem-feedback channel.
- Never imply that sponsorship unlocks application features or guarantees a fix.
  The software remains free, public Issue handling remains available to everyone,
  and sponsorship is voluntary.

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
