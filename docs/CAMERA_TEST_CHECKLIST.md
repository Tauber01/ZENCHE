# Nikon camera hardware acceptance checklist

Record the camera firmware, lens, USB cable and host OS before testing.

- [ ] Z9 (`04b0:0450`) is identified by its correct model name.
- [ ] Z8 (`04b0:0451`) is identified by its correct model name.
- [ ] Z f (`04b0:0453`) is identified by its correct model name.
- [ ] Z6III (`04b0:0454`) is identified by its correct model name.
- [ ] Z50II (`04b0:0455`) is identified by its correct model name.
- [ ] Z5II (`04b0:0456`) is identified by its correct model name.
- [ ] ZR (`04b0:0457`) is identified by its correct model name or descriptor fallback.
- [ ] Other Nikon USB models are rejected with their actual Product ID.
- [ ] Android displays a USB permission prompt once and reconnects after relaunch.
- [ ] Live view starts, refreshes continuously and stops when disabled.
- [ ] One shutter press creates exactly one file in the local library.
- [ ] Captured JPEG opens at full resolution and has a valid EXIF timestamp.
- [ ] Shutter speed, aperture, ISO sensitivity and exposure compensation change on the body.
- [ ] P, S, A and M shooting modes change on the body.
- [ ] M mode with the Bulb shutter speed opens and closes after the app-selected duration.
- [ ] P locks shutter and aperture; A locks shutter; S locks aperture.
- [ ] M exposes shutter, aperture and ISO while locking exposure compensation.
- [ ] M (Bulb) exposes aperture, ISO sensitivity and app duration while locking
      the regular shutter-speed control and exposure compensation.
- [ ] The local stripe pattern appears only above the selected 70–100 IRE threshold.
- [ ] A valid 3D `.cube` LUT changes live view but not the captured JPEG bytes.
- [ ] Invalid, incomplete and 1D LUT files show an actionable import error.
- [ ] Auto, Standard, Neutral, Vivid, Monochrome, Portrait, Landscape and Flat
      Picture Controls either change on the body or report unsupported clearly.
- [ ] White balance, focus mode and shooting mode report unsupported values clearly.
- [ ] Monitor-page ISO sensitivity, preset white-balance and exposure controls
      update the camera body.
- [ ] Enabling local 2× supersampling changes preview resampling without changing
      the captured JPEG bytes.
- [ ] Nikon PTP live-view format is shown as camera-output JPEG and cannot be
      mistaken for the camera's video file type.
- [ ] Switching the 720p / 1080p monitor display size updates the local output label
      and keeps the live-view loop responsive.
- [ ] Disconnecting the cable disables the shutter without losing saved files.
- [ ] Reconnecting after sleep restores live view without restarting the host.
- [ ] A 50-frame session completes without a leaked USB handle or stalled queue.

## Wireless transfer

- [ ] Starting the wireless inbox shows the receiver IPv4 address and port 2121.
- [ ] Camera FTP profile logs in with `nikonlink` / `nikonlink` and PASV enabled.
- [ ] Manual JPEG upload appears in the Nikon Link library without restarting.
- [ ] NEF and HEIF uploads keep their original filename and extension.
- [ ] Auto upload receives consecutive captures without overwriting an existing file.
- [ ] Stopping the wireless inbox rejects new camera connections.

## iOS / iPadOS monitor output

- [ ] 720p60, 1080p30, 1080p60 and 2160p30 choose the closest supported
      AVFoundation format and report the actual dimensions and frame rate.
- [ ] H.264, HEVC and automatic output-encoding preferences persist after relaunch.
- [ ] Enabling 2× input sampling priority requests a higher format where available
      and falls back to the closest device-supported format without stopping preview.

## Current build status

The 0.7.2 stable release passes compilation, signature/container validation,
native UI startup checks and package scans confirming that DMG/APK contain no
WebView or web assets. No supported EXPEED 7 body was attached to the build
machine, so the checklist above remains the release-candidate gate for Z9, Z8,
Z f, Z6III, Z50II, Z5II and ZR.
