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
- [ ] **Canon EOS 录像（待设备，C2 1.5.8）**：Android/Harmony/Windows 在佳能
      （VID 0x04a9）上开始/停止录像经 EOS_SetDevicePropValueEx(0x9110) 写
      EVFRecordStatus(0xD1b8)（1=开始 0=停止）；机身出现「录像中」指示、再次
      停止后生成视频文件。实现按 libgphoto2 常量 + digiCamControl/qDslrDashboard
      社区方案，未经实机验证（TBC-awaiting-hardware），实机条目通过后移除该标注。
- [ ] **Canon EOS 实时取景（待设备，E2 1.5.9）**：Android/Harmony/Windows 在佳能
      （VID 0x04a9）上取景启停经 EVFMode(0xD1b1)/EVFOutputDevice(0xD1b0) 条件写
      （EVFOutputDevice 仅 (cur & ~1)==0 时写 2=PC），取帧走 EOS_GetViewFinderData
      (0x9153) 并解出内嵌 JPEG（EOS dataset type 1/9/11）；视频监看实时刷新、
      停止取景后机身回到 TFT 显示。实现对齐 libgphoto2 library.c/ptp.c，
      未经实机验证（TBC-awaiting-hardware），实机条目通过后移除该标注。
- [ ] **Canon EOS 取景态参数读写（待设备，E2 1.5.9）**：EVF/Movie 态下 ISO/
      光圈/快门经标准 GetDevicePropValue(0x1015) 读取、经 0x9110 写入（gphoto2
      对 EOS 属性读同样走标准 0x1015；0x9114 实为 SetRemoteMode 非属性读）；
      步进后机身数值变化且读回一致。
- [ ] **macOS Canon 实时取景（待设备，E2 1.5.9）**：gphoto2 厂商中立管道
      拉取佳能实时取景（未经实机验证）；本批不改 macOS 代码，仅挂条目。
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

## macOS / Windows PTP/IP 遥控 — E3 1.5.9（待设备，TBC-awaiting-hardware）

- [ ] **macOS Wi‑Fi 遥控**：连接尼康/佳能 PTP/IP 相机后，监看页与全屏取景显示
      Wi‑Fi 实时取景帧（CGImage，约 10fps）；录像钮对 Wi‑Fi 相机走机身录像
      （Nikon 0x920a/0x920b；Canon EVFRecordStatus，TBC）；参数步进卡经
      0x1015/0x1016 读写 ISO/光圈/快门后机身数值变化且读回一致；离开监看页
      停止拉帧（不白空转）。
- [ ] **Windows Wi‑Fi 遥控**：连接后自动识别厂商（GetDeviceInfo 0x1001 +
      名称启发式），尼康/佳能自动开实时取景并拉帧；控制卡「开启/停止实时取景」
      「开始/停止录制」可用；ISO/光圈/快门步进写入后读回一致；录像文件保存在
      相机卡内；断连/重连后取景与参数自动恢复。
- [ ] **PTP/IP data-out 相位**（Windows 新增）：SetDevicePropValue(0x1016) 与
      Canon 0x9110 经 请求→StartData(9)→EndData(12)→响应 相位写入成功，机身
      数值变化（对齐 iOS 实现与 docs/PTPIP_PROTOCOL.md）。

## iOS PTP/IP (Wi‑Fi 相机) — C3 1.5.8（待设备，TBC-awaiting-hardware）

- [ ] **实时取景**：连接尼康/佳能 Wi‑Fi 相机后自动开实时取景，视频监看页与
      iPad 监看页持续刷新 JPEG 帧（约 10fps，单帧失败 300ms 退避重试）；
      断开连接后停止。尼康走 0x9201/0x9202/0x9203；佳能按 C2 序列
      （0x9110 写 EVFMode/EVFOutputDevice，Busy 容忍）后取 0x9153
      GetViewFinderData。
- [ ] **录像启停**：Wi‑Fi 连接且厂商识别为尼康/佳能时录像钮可用；开始/停止走
      尼康 0x920a/0x920b 或佳能 EVFRecordStatus(0xD1b8)（1=开始 0=停止）；
      REC 指示与时间码随录像走动，文件保存在相机卡内。Sony/未知厂商不误报
      录像能力。
- [ ] **参数读写**：ISO（0x500f）/ 光圈（0x5007）/ 快门（0x500d）经
      GetDevicePropValue(0x1015)/SetDevicePropValue(0x1016) 读取与写入，
      Wi‑Fi 参数卡步进后机身数值变化且读回一致。
- [ ] 心跳保活、断连清理与自动重连在新取景/录像路径下不回退：断连先停录像/
      取景再关会话，重连成功后自动恢复取景与参数。

## Current build status

The 1.0.0 stable release passes compilation, signature/container validation,
native UI startup checks and package scans. Windows passes .NET compilation and
PE/ZIP package checks. HarmonyOS source, resources, and unsigned HAP compilation
pass, but signing, startup, and hardware checks are still pending. No supported
EXPEED 6 / 7 body was attached to the build machine, so this checklist remains
the release gate for every platform and camera.
