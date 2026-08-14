---
title: "PTP/IP 协议实现文档（ZENCHE 五端事实标准）"
tags: [zenche, ptpip, protocol, camera, wifi]
status: active
created: 2026-08-06
---

# PTP/IP 协议实现文档

> 事实标准：[CIPA DC-X005](https://www.cipa.jp/std/documents/e/DC-X005.pdf)
> 与 PIMA 15740；五端实现必须服从协议，不再以任一历史客户端实现覆盖标准。
> 本文档供 iOS/iPadOS、Android、HarmonyOS、macOS、Windows 共同维护。
>
> B2/E3/E4 已完成五端双通道 TCP、心跳、自动重连与原生 UI 接线；1.5.14 进一步
> 勘正 event Probe、完整事务 gate、会话代际与流式长度校验。Canon/PTP-IP 以及
> Nikon/Sony/Canon 的跨端互操作仍统一标记 `TBC-awaiting-hardware`。

## 1. 连接与通道

- 默认端口 **15740**，`host` 为相机热点 IP（AP 直连，通常 `192.168.1.1`）或局域网 IP（STA）。
- **双 TCP 通道**：command 通道承载操作事务，event 通道在握手后保持独立 reader，
  持续消费 Event(type 8)，并承载双向 Probe Request/Response(type 13/14)。两条流
  不得由多个 reader 竞争同一个包。
- 包帧：**所有包**均为 `[u32 length][u32 type][payload]`，length 含 8 字节头，
  小端（LE）；payload 数据字段除另行说明外均为 LE。

| type | 名称 | payload |
|---|---|---|
| 1 | InitCommandRequest | 会话 GUID(16B) + InitiatorName(UTF-16 含 `\0`) + ProtocolVersion(u32=0x00010000) |
| 2 | InitCommandAck | connectionNumber 在 **offset 8**（u32），CameraName 从 **offset 28**（UTF-16） |
| 3 | InitEventRequest | connectionNumber(u32) |
| 4 | InitEventAck | 无 |
| 6 | OperationRequest | DataPhaseInfo(u32) + OperationCode(u16) + TransactionID(u32) + N×Param(u32) |
| 7 | OperationResponse | ResponseCode@8(u16) + TransactionID@10(u32) + 响应参数 |
| 8 | Event | EventCode@8(u16) + TransactionID@10(u32) + 事件参数 |
| 9 | StartData（数据阶段开始） | TransactionID(u32)@8 + TotalLength(u64)@12 |
| 10 | Data | TransactionID(u32)@8 + 数据 |
| 12 | EndData | TransactionID(u32)@8 + 末段数据 |
| 13 | ProbeRequest | 空 payload；只在 event 通道发送 |
| 14 | ProbeResponse | 空 payload；只在 event 通道发送 |

- 五端同构握手序列（方法名随平台不同）：
  1. 建 command TCP → 发 type 1 → 收 type 2（取 connectionNumber 与 CameraName）。
  2. 建 event TCP → 发 type 3（携带 connectionNumber）→ 收 type 4。
  3. 启动 event reader，保证相机主动发 type 13 时立即回 type 14。
  4. command 通道发 `OpenSession`：DataPhaseInfo=1、opcode **0x1002**、transaction=**0**、
     参数 `[1]`；期望响应 **0x2001**（OK）。
  5. 会话建立后 `transactionID = 1`，之后每个事务自增。
- 五端仅会话 GUID 与 InitiatorName（例如 `ZENCHE Windows`）不同，包序列、协议
  版本和 OpenSession 参数必须一致。

## 2. 事务相位（DataPhaseInfo）

- **`1` = 无数据 / 数据入（data-in）**：`commandRequest`（仅请求→响应）与
  `dataRequest`（请求→StartData(9)→Data(10)/EndData(12)→响应）都用 `1`。
  - `commandRequest`：发 type 6 → 收 type 7，同时校验 TransactionID 与 ResponseCode。
  - `dataRequest`：发 type 6 → 收 type 9（校验 TransactionID@8、TotalLength@12）→
    循环收 type 10/12（数据在 offset 12 起，type 12 结束）→ 收 type 7 响应。
    - 若首包直接是 type 7：视为拒绝（ResponseCode，缺省 0x2002）。
    - TotalLength 为 `UINT64_MAX` 时按标准的“长度未知/流式”处理；否则 EndData 后的
      累计字节数必须与声明值完全一致。累计数据上限 **512 MB**。
    - 当前接收器为避免单包内存放大，将单个 PTP/IP 包限制为 **64 MiB**；因此超过
      约 64 MiB 的对象需要相机拆成多个 Data/EndData 包。CIPA 允许 responder 把整个
      对象放在单个 EndData 中，这类实现尚不兼容，不能把 512 MB 累计上限表述为对
      所有相机均可用的单文件能力。
- **`2` = 数据出（data-out）**：
  `请求(type 6, DataPhaseInfo=2)` → `StartData(type 9, TransactionID@8 + TotalLength(u64)@12)` →
  `EndData(type 12, TransactionID@8 + 数据)` → `响应(type 7)`。短属性值直接放在
  EndData；不得添加不存在的前导 `u32(0)`，也不得把数据塞进 StartData。
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
- 五端厂商识别流程：
  1. 先按握手 CameraName 启发式（`nikon`/`canon`/`sony`/`ilce`/`alpha` → 对应厂商）。
  2. `dataRequest(0x1001, [])` 解析数据段 Manufacturer 字段；GetDeviceInfo 无参数，
     数据集缺少可解析 Manufacturer，或 responder 明确返回 `OperationNotSupported`
     (`0x2005`) / `DevicePropNotSupported` (`0x200A`) / `DeviceBusy` (`0x2019`) 时回退
     启发式。TCP/帧/超时错误以及 `SessionNotOpen` (`0x2003`) / `InvalidTransactionID`
     (`0x2004`) / `SessionAlreadyOpen` (`0x201E`) 不得被启发式吞掉。
- GetDeviceInfo 数据段布局（`deviceInfoManufacturer`）：
  `StandardVersion(u16)` + `VendorExtensionID(u32)` + `VendorExtensionVersion(u16)` +
  `VendorExtensionDesc(PTP STR)` + `FunctionalMode(u16)` +
  五个 AUINT16 数组 `Operations/Events/DeviceProperties/CaptureFormats/ImageFormats`
  （各 `[u32 数量][u16×N]`）→ `Manufacturer(PTP STR)` → `Model` →
  `DeviceVersion` → `SerialNumber`。PTP STR 为 `[u8 字符数（含终止符）] +
  UTF-16LE`，不是 NUL 结尾 UTF-8。
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
- 五端取帧循环：约 10fps，单帧失败 300ms 退避重试；断连/重连先停取景再关会话。

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

## 9. 心跳保活与事务串行（1.5.14 修正）

- 每 5s 在 **event 通道**发送空 payload 的 ProbeRequest(type 13)，由常驻 event
  reader 接收 ProbeResponse(type 14)；单次超时 3s。相机主动发 type 13 时客户端
  必须立即回 type 14，type 8 事件必须被持续消费。心跳不得重复 OpenSession，
  也不得借用 GetDeviceInfo 等 command 事务。
- CIPA DC-X005 把 Initiator Probe 描述为事务期间的可选探测，并给出 10s 响应等待；
  当前 5s 周期 / 3s 超时是 ZENCHE 为快速断线恢复采用的产品策略性偏离，必须保留
  “待 Nikon/Sony/Canon 实机互操作验证”边界，不能称为规范规定值。
- 连续 3 次失败判离线 → `reconnecting` → 指数退避 1/2/4/8/16s 封顶 30s；
  手动断连（`manualDisconnect`）不触发重连；重连前先停实时取景。
- command 通道的每个完整事务必须持有会话级异步 gate，范围覆盖 transaction 分配、
  OperationRequest、全部 data phase 与 OperationResponse。Swift actor 跨 `await` 可重入、
  ArkTS Promise 与 C# async 也会交错，均不能视为“天然串行”；Android 的同步 I/O
  继续用实例 `synchronized` 边界。
- Apple、HarmonyOS、Windows 的 command/event writer 均绑定连接对象与 session
  generation；断开会先使 generation 失效，旧 gate waiter 或在途握手不得写入随后
  建立的新会话。Android 还必须把握手中的局部 command/event socket 纳入 transport
  generation，使 UI 线程可以只做非阻塞关闭、立即打断尚未完成的 TCP connect/read；
  初连/重连成功状态只可在双通道健康屏障及 connection generation 复核后发布。
- command 事务必须有有限 deadline。deadline、用户取消或传输/帧失败发生在事务开始后，
  必须退休当时捕获的精确 stream/session，不能让迟到响应留在共享流中被下一事务误取；
  gate waiter 被取消或跨代际唤醒时也必须正确交还 lease。普通 `OperationNotSupported`、
  `DeviceBusy` 等 PTP ResponseCode 不等同于 transport 失败，但 `SessionNotOpen`、
  `InvalidTransactionID` 与 `SessionAlreadyOpen` 属会话失效，必须让健康检查失败并进入
  统一重连。
- UI 层的源切换、断开、初连和恢复同样受 attempt/generation 所有权保护；任何 `await`
  后发布连接、厂商、取景或参数状态前都要复核。手动断开只清理自己捕获的会话，旧清理
  continuation 不得关闭后来建立的相机实例。
- Android 的 NetworkCallback 需要 `ACCESS_NETWORK_STATE`；HarmonyOS NetConnection
  需要 `GET_NETWORK_INFO`。监听必须限定 Wi-Fi bearer/当前相机网络并绑定回调代际，旧
  `onLost/netLost` 不得误杀新连接。缺少权限时初连可能成功，但断网即时重连不会工作。

## 10. 参考实现落点

| 端 | 传输+能力 | UI |
|---|---|---|
| iOS | `RemoteCaptureServices.swift`（actor `PTPIPSession` + `WifiCameraService`） | `RootView.swift` / `AppModel.swift` |
| macOS | 同上（构建脚本直接编译 iOS 文件） | `main.swift`（E3 UI 接线） |
| Windows | `Services/PtpIpCamera.cs`（E3 补能力） | `MainWindow.xaml.cs`（E3 UI 接线） |
| Android | `PtpIpCamera.java`（E4） | `MainActivity.java`（E4） |
| Harmony | `PtpIpCamera.ets`（E4） | `Index.ets`（E4） |
