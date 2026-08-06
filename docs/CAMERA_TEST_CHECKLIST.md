# Nikon camera hardware acceptance checklist

Record the camera firmware, lens, USB cable and host OS before testing.

- [ ] Z7 (`04b0:0442`) is identified by its correct model name.
- [ ] Z6 (`04b0:0443`) is identified by its correct model name.
- [ ] Z50 (`04b0:0444`) is identified by its correct model name.
- [ ] D780 (`04b0:0446`) is identified by its correct model name.
- [ ] D6 (`04b0:0447`) is identified by its correct model name.
- [ ] Z5 (`04b0:0448`) is identified by its correct model name.
- [ ] Z7II (`04b0:044b`) is identified by its correct model name.
- [ ] Z6II (`04b0:044c`) is identified by its correct model name.
- [ ] Z fc (`04b0:044f`) is identified by its correct model name.
- [ ] Z9 (`04b0:0450`) is identified by its correct model name.
- [ ] Z8 (`04b0:0451`) is identified by its correct model name.
- [ ] Z30 (`04b0:0452`) is identified by its correct model name.
- [ ] Z f (`04b0:0453`) is identified by its correct model name.
- [ ] Z6III (`04b0:0454`) is identified by its correct model name.
- [ ] Z50II (`04b0:0455`) is identified by its correct model name.
- [ ] Z5II (`04b0:0456`) is identified by its correct model name.
- [ ] ZR (`04b0:0457`) is identified by its correct model name or descriptor fallback.
- [ ] Other Nikon USB models are rejected with their actual Product ID.
- [ ] **Canon EOS R6 Mark III（待设备）**：USB/PTP 被识别为「Canon EOS R6 Mark III」，
      名称正确、ISO 范围显示 100–102400；Sony/Canon VID 通配（0x054c / 0x04a9）
      不误匹配 Nikon 机型。注：Canon 深度控制（对焦/快门/LiveView 专属 opcode）为
      TBC 未实机验证项，入册仅覆盖识别/名称/ISO 范围/泛型 PTP 连接。
- [ ] Android displays a USB permission prompt once and reconnects after relaunch.
- [ ] HarmonyOS displays the system USB permission prompt and reconnects after
      unplug/replug without retaining stale endpoints.
- [ ] Windows reports a clear WinUSB/libusb driver action when the PTP interface
      is owned by the system or another application.
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

- [ ] Starting the wireless inbox shows the receiver IPv4 address,
      FTP port 2121, and HTTP/WebDAV port 8080.
- [ ] Camera FTP profile logs in with `nikonlink` / `nikonlink` and PASV enabled.
- [ ] HTTP PUT to `/upload/<filename>` with Basic Auth stores byte-identical data.
- [ ] HTTP POST accepts a filename from the path, `filename` query item, or
      `X-Filename` header and rejects a missing `Content-Length`.
- [ ] WebDAV `OPTIONS`, `PROPFIND`, `MKCOL`, and authenticated `PUT` complete
      with standards-compatible status codes.
- [ ] Missing or incorrect HTTP Basic Auth receives `401` without creating a file.
- [ ] Manual JPEG upload appears in the 帧澈 ZENCHE library without restarting.
- [ ] NEF and HEIF uploads keep their original filename and extension.
- [ ] Auto upload receives consecutive captures without overwriting an existing file.
- [ ] Stopping the wireless inbox rejects new FTP, HTTP, and WebDAV connections.
- [ ] Windows chooses a free PASV data port and streams large files to a temporary
      `.part` file before the final atomic move.
- [ ] HarmonyOS listens on PASV data port 2122 only while FTP is transferring,
      and closes ports 2121, 2122, and 8080 after leaving the page.

## Windows

- [ ] `ZENCHE.exe` starts on a clean Windows 11 x64 machine with the packaged
      `libusb-1.0.dll`.
- [ ] The x64 package rejects x86/ARM64 libusb DLLs with an actionable message.
- [ ] Only the Nikon Still Image/PTP interface is bound to WinUSB or libusbK.
- [ ] Keyboard focus, window resizing at 1024×640, and 200% display scaling keep
      all critical controls operable.

## HarmonyOS

- [ ] The signed HAP installs on an API 12+ USB Host phone, tablet, and 2-in-1.
- [ ] The app remains usable at 320, 375, 414, and 768 vp widths.
- [ ] A PTP payload larger than 200 KB is reassembled correctly from 192 KB
      `bulkTransfer` calls.
- [ ] Removing the USB device during live view exits the loop and leaves the local
      photo library intact.

## iOS / iPadOS monitor output

- [ ] 720p60, 1080p30, 1080p60 and 2160p30 choose the closest supported
      AVFoundation format and report the actual dimensions and frame rate.
- [ ] H.264, HEVC and automatic output-encoding preferences persist after relaunch.
- [ ] Enabling 2× input sampling priority requests a higher format where available
      and falls back to the closest device-supported format without stopping preview.

## Current build status

The 1.0.0 stable release passes compilation, signature/container validation,
native UI startup checks and package scans. Windows passes .NET compilation and
PE/ZIP package checks. HarmonyOS source, resources, and unsigned HAP compilation
pass, but signing, startup, and hardware checks are still pending. No supported
EXPEED 6 / 7 body was attached to the build machine, so this checklist remains
the release gate for every platform and camera.
