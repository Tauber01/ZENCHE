---
title: "PTP/IP 协议实现文档（ZENCHE 五端事实标准）"
tags: [zenche, ptpip, protocol, camera, wifi]
status: active
created: 2026-08-06
---

# PTP/IP 协议实现文档

> 事实标准：`native/ios/NikonLink/Connectivity/RemoteCaptureServices.swift`（E3 之前
> 无字节级文档，协议全部以 iOS 实现为准）。本文档供 E4（Android/Harmony PTP/IP
> 全端化）及后续维护使用；若与 iOS 实现不一致，以 iOS 实现为最终裁决。
>
> 传输层由 B2 落地（五端双通道 TCP + 心跳保活 + 自动重连），本批（E3）在
> macOS（UI 接线）与 Windows（传输+UI）补齐能力；Canon/PTP-IP 新代码全部
> `TBC-awaiting-hardware`。

## 1. 连接与通道

- 默认端口 **15740**，`host` 为相机热点 IP（AP 直连，通常 `192.168.1.1`）或局域网 IP（STA）。
- **双 TCP 通道**：command 通道承载全部事务（请求/响应/数据），event 通道只做握手
  （InitEventRequest/InitEventAck），本实现不使用事件推送（心跳探测走 command 通道）。
- 包帧：**所有包**均为 `[u32 length][u32 type][payload]`，length 含 8 字节头，
  小端（LE）；payload 数据字段除另行说明外均为 LE。

| type | 名称 | payload |
|---|---|---|
| 1 | InitCommandRequest | 会话 GUID(16B) + InitiatorName(UTF-16 含 `\0`) + ProtocolVersion(u32=0x00010000) |
| 2 | InitCommandAck | connectionNumber 在 **offset 8**（u32），CameraName 从 **offset 28**（UTF-16） |
| 3 | InitEventRequest | connectionNumber(u32) |
| 4 | InitEventAck | 无 |
| 6 | OperationRequest | DataPhaseInfo(u32) + OperationCode(u16) + TransactionID(u32) + N×Param(u32) |
| 7 | OperationResponse | ResponseCode 在 **data offset 8**（u16），其余为响应参数 |
| 9 | StartData（数据阶段开始） | TransactionID(u32)@8 + TotalLength(u64)@12 + 首段数据 |
| 10 | Data | TransactionID(u32)@8 + 数据 |
| 12 | EndData | TransactionID(u32)@8 + 末段数据 |

- 握手序列（iOS `connect`，Windows `ConnectAsync` 同构）：
  1. 建 command TCP → 发 type 1 → 收 type 2（取 connectionNumber 与 CameraName）。
  2. 建 event TCP → 发 type 3（携带 connectionNumber）→ 收 type 4。
  3. command 通道发 `OpenSession`：DataPhaseInfo=1、opcode **0x1002**、transaction=**0**、
     参数 `[1]`；期望响应 **0x2001**（OK）。
  4. 会话建立后 `transactionID = 1`，之后每个事务自增。
- **Windows/iOS 差异**：Windows `ConnectAsync` 的握手用 InitCommandRequest 同构
  （GUID + "ZENCHE Windows" + 0x00010000）。

## 2. 事务相位（DataPhaseInfo）

- **`1` = 无数据 / 数据入（data-in）**：`commandRequest`（仅请求→响应）与
  `dataRequest`（请求→StartData(9)→Data(10)/EndData(12)→响应）都用 `1`。
  - `commandRequest`：发 type 6 → 收 type 7，取 ResponseCode（data offset 8）。
  - `dataRequest`：发 type 6 → 收 type 9（校验 TransactionID@8、TotalLength@12）→
    循环收 type 10/12（数据在 offset 12 起，type 12 结束）→ 收 type 7 响应。
    - 若首包直接是 type 7：视为拒绝（ResponseCode，缺省 0x2002）。
    - TotalLength 上限 **512 MB**（单文件传输上限）。
- **`2` = 数据出（data-out）**：iOS `dataOutRequest` / Windows 需补（E3）：
  `请求(type 6, DataPhaseInfo=2)` → `StartData(type 9, TransactionID@8 + TotalLength(u64)@12 + 数据)` →
  `EndData(type 12, TransactionID@8)` → `响应(type 7)`。
  - 用于 `SetDevicePropValue(0x1016)` 与 Canon `EOS_SetDevicePropValueEx(0x9110)`。

## 3. 会话/存储/拍摄（既有，B2/C3 已实现）

| 操作 | opcode | 相位 | 参数 | 备注 |
|---|---|---|---|---|
| OpenSession | 0x1002 | 1 | [1] | transaction=0，期望 0x2001 |
| Capture（快门） | 0x100E | 1 | [0,0] | 期望 0x2001，原片留机身 |
| GetStorageIDs | 0x1004 | data-in | — | — |
| GetStorageInfo | 0x1005 | data-in | [storageID] | — |
| GetObjectHandles | 0x1007 | data-in | [storageID,0,UINT32_MAX] | — |
| GetObjectInfo | 0x1008 | data-in | [handle] | — |
| GetObject | 0x1009 | data-in | [handle] | 单文件 ≤512MB |
| GetThumb | 0x100A | data-in | [handle] | — |
| DeleteObject | 0x100B | 1 | [handle,0] | — |
| GetDevicePropDesc | 0x1014 | data-in | [propCode] | 属性描述符（可写性校验） |
| GetDevicePropValue | 0x1015 | data-in | [propCode] | 属性值（UINT16 回 2B / UINT32 回 4B） |
| SetDevicePropValue | 0x1016 | **data-out** | [propCode] | 数据段为属性值（LE，按类型） |

## 4. 厂商识别（detectVendor）

- **0x1001 = GetDeviceInfo**（ISO 15740；0x1002 实为 OpenSession——E2 已勘正，
  C3 曾误用 0x1002）。
- 流程（iOS `detectVendor(using:)`，Windows 补同构）：
  1. 先按握手 CameraName 启发式（`nikon`/`canon`/`sony`/`ilce`/`alpha` → 对应厂商）。
  2. `dataRequest(0x1001, [1])` 解析数据段 Manufacturer 字段；解析失败回退启发式。
- GetDeviceInfo 数据段布局（`deviceInfoManufacturer`，UTF-8 字符串以 `\0` 结尾）：
  `StandardVersion(u16)` + `VendorExtensionID(u32)` + `VendorExtensionVersion(u16)` +
  `VendorExtensionDesc(UTF-8)` + `FunctionalMode(u16)` +
  四个数组 `Operations/Events/DeviceProperties/CaptureFormats`（各 `[u16 数量][u16×N]`）+
  `ImageFormats`（同上）→ `Manufacturer(UTF-8)` → `Model` → `DeviceVersion` → `SerialNumber`。
- 结果按会话缓存，断连清零。

## 5. 实时取景（vendor 分发）

| 厂商 | 开启 | 关闭 | 取帧 |
|---|---|---|---|
| Nikon | 0x9201 | 0x9202 | 0x9203（data-in，返回 JPEG） |
| Canon | 0x9110 写 EVFMode(0xD1b1)=1 + EVFOutputDevice(0xD1b0)=2（Busy 容忍） | 0x9110 写 EVFOutputDevice=0 + EVFMode=0 | 0x9153 GetViewFinderData（data-in，EOS dataset） |
| Sony/unknown | 不支持（不开启，不误报录像） | — | — |

- Canon EOS dataset（0x9153 数据段，对齐 libgphoto2 `ptp_canon_eos_get_viewfinder_image`）：
  多个 blob 依 `[u32 len][u32 type][payload]` 排列；**type 1=常规 JPEG、9=Movie 模式 JPEG、
  11=JPEG**；其余 type 跳过 `len` 字节。JPEG 载荷在 blob 内 offset 8 起，再经
  JPEG 标记（FFD8/FFD9）扫描兜底。
- Canon EVFOutputDevice 条件写（对齐 libgphoto2 canon.c「do not set it everytime」）：
  先 `0x1015` 读当前值，仅 `(cur & ~1) == 0` 时写 2=PC；读失败回退无条件写
  （E2 观察项①裁定为合理保守策略）。EVFMode 读当前值非 1 才写。
- 三端取帧循环：约 10fps，单帧失败 300ms 退避重试；断连/重连先停取景再关会话。

## 6. 录像（vendor 分发）

| 厂商 | 开始 | 停止 |
|---|---|---|
| Nikon | 0x920a（未处取景态先 0x9201） | 0x920b |
| Canon | 0x9110 写 EVFRecordStatus(0xD1b8)=1 | 0x9110 写 EVFRecordStatus=0 |
| Sony/unknown | 不支持 | — |

- Canon 录像前若未处取景态，先按 §5 序列开取景（Movie 模式 Busy 容忍不阻断）。
- 文件保存在相机卡内（本实现不做机身录像下载）。

## 7. 参数读写（常用参数）

| 参数 | propCode | 值类型 | 编码 |
|---|---|---|---|
| ISO | 0x500f | UINT16 | 原值 |
| 光圈 F | 0x5007 | UINT16 | F×100 |
| 快门（秒） | 0x500d | UINT32 | 秒×10000 |

- 读：`dataRequest(0x1015, [propCode])`，UINT16 回 2 字节 / UINT32 回 4 字节。
- 写：`dataOutRequest(0x1016, [propCode], 值LE)`。
- 属性码与 Android PtpCamera USB 口径一致。
- Canon EOS 属性读同样走标准 0x1015/0x1014（gphoto2 同）；**0x9114 是 SetRemoteMode，
  不是属性读**（E2 勘正）。Canon 属性写经 0x9110（载荷见 §8）。

## 8. Canon EOS_SetDevicePropValueEx（0x9110，data-out）

- 数据段 12 字节 LE：`[u32 length=12][u32 propCode][u32 value]`。
- 用于：EVFMode(0xD1b1)、EVFOutputDevice(0xD1b0)、EVFRecordStatus(0xD1b8)、
  Canon Log(0xD176)、以及 EVF/Movie 态属性写（TBC-awaiting-hardware）。

## 9. 心跳保活（B2，值不可改）

- 每 5s `probe`（GetDeviceInfo 复用 **0x1002** OpenSession 响应判定，transaction=0，
  期望 0x2001；注意这与 §4 的厂商识别 0x1001 是两回事——探测用 0x1002 为 B2
  既有契约，勿动）；单次超时 3s（iOS Task 竞速 / Windows linked CTS）。
- 连续 3 次失败判离线 → `reconnecting` → 指数退避 1/2/4/8/16s 封顶 30s；
  手动断连（`manualDisconnect`）不触发重连；重连前先停实时取景。
- 全部 PTP/IP 事务共用 command 通道（天然串行，E4 照 iOS actor 模型维持该纪律）。

## 10. 参考实现落点

| 端 | 传输+能力 | UI |
|---|---|---|
| iOS | `RemoteCaptureServices.swift`（actor `PTPIPSession` + `WifiCameraService`） | `RootView.swift` / `AppModel.swift` |
| macOS | 同上（构建脚本直接编译 iOS 文件） | `main.swift`（E3 UI 接线） |
| Windows | `Services/PtpIpCamera.cs`（E3 补能力） | `MainWindow.xaml.cs`（E3 UI 接线） |
| Android | `PtpIpCamera.java`（E4） | `MainActivity.java`（E4） |
| Harmony | `PtpIpCamera.ets`（E4） | `Index.ets`（E4） |
