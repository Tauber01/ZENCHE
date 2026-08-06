import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const root = new URL('../', import.meta.url);
const read = async (path) => readFile(new URL(path, root), 'utf8');

// C3 契约锚点：iOS PTP/IP 能力扩展（实时取景 + 录像 + 参数读写）。
// 佳能序列与 C2 分支选用的 EOS 属性序列一致（0x9110/0xD1b8/0xD1b1/0xD1b0），
// 无实机，全部标 TBC-awaiting-hardware（纪律：不得写成已实机验证）。

test('iOS PTP/IP session exposes Nikon live-view and movie vendor ops', async () => {
  const service = await read(
    'native/ios/NikonLink/Connectivity/RemoteCaptureServices.swift');
  assert.match(service, /startLiveView: UInt16 = 0x9201/);
  assert.match(service, /endLiveView: UInt16 = 0x9202/);
  assert.match(service, /getLiveViewImage: UInt16 = 0x9203/);
  assert.match(service, /startMovieRecording: UInt16 = 0x920a/);
  assert.match(service, /endMovieRecording: UInt16 = 0x920b/);
  assert.match(service, /func startLiveView\(vendor: PTPIPCameraVendor\)/);
  assert.match(service, /func endLiveView\(vendor: PTPIPCameraVendor\)/);
  assert.match(service, /func getLiveViewFrame\(vendor: PTPIPCameraVendor\)/);
  assert.match(service, /func startMovieRecording\(vendor: PTPIPCameraVendor\)/);
  assert.match(service, /func stopMovieRecording\(vendor: PTPIPCameraVendor\)/);
});

test('iOS PTP/IP parameter read/write uses standard PTP prop ops', async () => {
  const service = await read(
    'native/ios/NikonLink/Connectivity/RemoteCaptureServices.swift');
  assert.match(service, /getDevicePropDesc: UInt16 = 0x1014/);
  assert.match(service, /getDevicePropValue: UInt16 = 0x1015/);
  assert.match(service, /setDevicePropValue: UInt16 = 0x1016/);
  // 常用参数属性码与 Android PtpCamera 口径一致
  assert.match(service, /propISO: UInt16 = 0x500f/);
  assert.match(service, /propFNumber: UInt16 = 0x5007/);
  assert.match(service, /propExposureTime: UInt16 = 0x500d/);
  assert.match(service, /func readProperty\(_ property: UInt16\)/);
  assert.match(service, /func writeProperty\(_ property: UInt16, value: Data\)/);
  assert.match(service, /func readPropertyDescriptor\(_ property: UInt16\)/);
  // SetDevicePropValue 需要数据段（DataPhaseInfo=2 的 data-out 请求）
  assert.match(service, /private func dataOutRequest/);
});

test('iOS Canon branch aligns with C2 EOS sequence (0x9110 EVF props)', async () => {
  const service = await read(
    'native/ios/NikonLink/Connectivity/RemoteCaptureServices.swift');
  assert.match(service, /canonEOSSetDevicePropValueEx: UInt16 = 0x9110/);
  assert.match(service, /canonGetViewFinderData: UInt16 = 0x9153/);
  assert.match(service, /canonEVFRecordStatus: UInt32 = 0xd1b8/);
  assert.match(service, /canonEVFMode: UInt32 = 0xd1b1/);
  assert.match(service, /canonEVFOutputDevice: UInt32 = 0xd1b0/);
  assert.match(service, /func canonWriteEosProp/);
  assert.match(service, /TBC-awaiting-hardware/);
});

test('iOS vendor detection derives from DeviceInfo manufacturer with name fallback', async () => {
  const service = await read(
    'native/ios/NikonLink/Connectivity/RemoteCaptureServices.swift');
  assert.match(service, /func detectVendor\(using cameraName: String\)/);
  assert.match(service, /deviceInfoManufacturer/);
  assert.match(service, /text\.contains\("nikon"\)/);
  assert.match(service, /text\.contains\("canon"\)/);
  assert.match(service, /text\.contains\("sony"\)/);
  assert.match(service, /enum PTPIPCameraVendor: Equatable/);
});

test('E2 1.5.9: iOS detectVendor 用 GetDeviceInfo(0x1001)，重连先停取景', async () => {
  const service = await read(
    'native/ios/NikonLink/Connectivity/RemoteCaptureServices.swift');
  // 0x1002→0x1001（0x1001 才是 ISO 15740 GetDeviceInfo；0x1002 实为 OpenSession）。
  assert.match(service, /func detectVendor\(using cameraName: String\)[\s\S]{0,400}0x1001/);
  // 心跳探测仍走 0x1002（B2 契约不变）。
  assert.match(service, /operation: 0x1002/);
  // 重连前先停实时取景（pro 复审观察项④收口）。
  assert.match(
    service,
    /enterReconnecting\(\)[\s\S]{0,300}stopLiveViewIfNeeded\(\)/,
  );
});

test('WifiCameraService exposes live view, recording and parameter state', async () => {
  const service = await read(
    'native/ios/NikonLink/Connectivity/RemoteCaptureServices.swift');
  assert.match(service, /@Published private\(set\) var vendor: PTPIPCameraVendor/);
  assert.match(service, /@Published private\(set\) var supportsMovieRecording = false/);
  assert.match(service, /@Published private\(set\) var isRecording = false/);
  assert.match(service, /@Published private\(set\) var liveViewFrame: CGImage\?/);
  assert.match(service, /@Published private\(set\) var isoValue = 0/);
  assert.match(service, /@Published private\(set\) var apertureValue: Float = 0/);
  assert.match(service, /@Published private\(set\) var shutterSpeedValue: Double = 0/);
  assert.match(service, /func startLiveViewIfNeeded\(\)/);
  assert.match(service, /func stopLiveViewIfNeeded\(\)/);
  assert.match(service, /func toggleVideoRecording\(\)/);
  assert.match(service, /func refreshParameters\(\)/);
  assert.match(service, /func stepISO\(_ direction: Int\)/);
  assert.match(service, /func stepAperture\(_ direction: Int\)/);
  assert.match(service, /func stepShutterSpeed\(_ direction: Int\)/);
  // 连接/重连成功路径：识别厂商后自动开取景与刷新参数
  assert.match(service, /detectVendor\(using: name\)/);
  assert.match(service, /startLiveViewIfNeeded\(\)/);
  // 断连清理：停取景/停录像后再断开会话
  assert.match(service, /stopLiveViewIfNeeded\(\)/);
  assert.match(service, /stopMovieRecording\(vendor: \w+\)/);
});

test('iOS UI routes record button to the active source and shows wifi live view', async () => {
  const rootView = await read('native/ios/NikonLink/Views/RootView.swift');
  assert.match(rootView, /model\.toggleVideoRecording\(\)/);
  assert.match(rootView, /model\.isRecording/);
  assert.match(rootView, /model\.videoRecordingAvailable/);
  assert.match(rootView, /wifiCamera\.liveViewFrame/);
  assert.match(rootView, /等待 Wi.?Fi 实时取景/);
  assert.match(rootView, /wifiParameterStrip/);
  assert.match(rootView, /WifiMonitorParameterCard\(\)/);
});

test('AppModel dispatches recording to camera or wifi by active source', async () => {
  const appModel = await read('native/ios/NikonLink/Models/AppModel.swift');
  assert.match(appModel, /var isRecording: Bool/);
  assert.match(appModel, /var videoRecordingAvailable: Bool/);
  assert.match(appModel, /func toggleVideoRecording\(\)/);
  assert.match(appModel, /wifiCamera\.toggleVideoRecording\(\)/);
});

test('E3: macOS gate keeps auto live-view off; UI wires wifi frame/record/params', async () => {
  const [service, main] = await Promise.all([
    read('native/ios/NikonLink/Connectivity/RemoteCaptureServices.swift'),
    read('native/macos/Sources/NikonLink/main.swift'),
  ]);
  // 门控：autoStartLiveViewOnConnect 默认 true（iOS 行为不变），macOS 显式置 false。
  assert.match(service, /var autoStartLiveViewOnConnect = true/);
  assert.match(service, /if self\.autoStartLiveViewOnConnect/);
  assert.match(main, /wifiCamera\.autoStartLiveViewOnConnect = false/);
  // macOS UI：取景帧（CGImage）、录像路由、参数步进卡。
  assert.match(main, /wifiCamera\.liveViewFrame/);
  assert.match(main, /wifiCamera\.toggleVideoRecording\(\)/);
  assert.match(main, /wifiCamera\.stepISO/);
  assert.match(main, /wifiCamera\.stepAperture/);
  assert.match(main, /wifiCamera\.stepShutterSpeed/);
  assert.match(main, /startLiveViewIfNeeded\(\)/);
  assert.match(main, /stopLiveViewIfNeeded\(\)/);
});

test('E3: Windows PtpIpCamera exposes data-out, vendor detect, live view, record, params', async () => {
  const [transport, window] = await Promise.all([
    read('native/windows/Services/PtpIpCamera.cs'),
    read('native/windows/MainWindow.xaml.cs'),
  ]);
  // data-out 相位（DataPhaseInfo=2：请求→StartData(9)→EndData(12)→响应）
  assert.match(transport, /SendCommandWithDataOutAsync/);
  assert.match(transport, /WriteUInt32\(payload, 2\)/);
  // 厂商识别：0x1001 GetDeviceInfo + 名称启发式
  assert.match(transport, /DetectVendorAsync/);
  assert.match(transport, /0x1001/);
  assert.match(transport, /VendorForManufacturer/);
  // 取景/录像/参数方法（Nikon opcode + Canon EOS 序列）
  assert.match(transport, /StartLiveViewAsync/);
  assert.match(transport, /StopLiveViewAsync/);
  assert.match(transport, /GetLiveViewFrameAsync/);
  assert.match(transport, /StartMovieRecordingAsync/);
  assert.match(transport, /StopMovieRecordingAsync/);
  assert.match(transport, /WritePropertyAsync/);
  assert.match(transport, /0x9201/);
  assert.match(transport, /0x9203/);
  assert.match(transport, /0x920a/);
  assert.match(transport, /0x9153/);
  // Windows UI：Wi‑Fi 取景循环 + 录像钮 + 参数卡
  assert.match(window, /StartWifiPreviewLoop/);
  assert.match(window, /WifiPreviewLoopAsync/);
  assert.match(window, /ToggleWifiMovieRecordingAsync/);
  assert.match(window, /StepWifiIsoAsync/);
  assert.match(window, /StepWifiApertureAsync/);
  assert.match(window, /StepWifiShutterAsync/);
  assert.match(window, /WifiStepperRow/);
  assert.match(window, /DetectVendorAsync/);
});

test('E4: Android PtpIpCamera exposes data-out, vendor detect, live view, record, params', async () => {
  const transport = await read(
    'native/android/app/src/main/java/com/tauber/nikonlink/PtpIpCamera.java');
  // data-out 相位（DataPhaseInfo=2：请求→StartData(9)→EndData(12)→响应）
  assert.match(transport, /sendCommandWithDataOut/);
  assert.match(transport, /request\.u32\(2\)/);
  assert.match(transport, /startData\.u64\(data\.length\)/);
  // 厂商识别：0x1001 GetDeviceInfo + 名称启发式
  assert.match(transport, /detectVendor/);
  assert.match(transport, /0x1001/);
  assert.match(transport, /vendorForManufacturer/);
  assert.match(transport, /vendorForName/);
  // 取景/录像/参数方法（Nikon opcode + Canon EOS 序列）
  assert.match(transport, /startLiveView/);
  assert.match(transport, /stopLiveView/);
  assert.match(transport, /getLiveViewFrame/);
  assert.match(transport, /startMovieRecording/);
  assert.match(transport, /stopMovieRecording/);
  assert.match(transport, /writeProperty/);
  assert.match(transport, /0x9201/);
  assert.match(transport, /0x9203/);
  assert.match(transport, /0x920a/);
  assert.match(transport, /0x9153/);
  assert.match(transport, /0x500f/);
  assert.match(transport, /0x5007/);
  assert.match(transport, /0x500d/);
  assert.match(transport, /TBC-awaiting-hardware/);
});

test('E4: Android MainActivity wires wifi live view, body recording, parameter steppers', async () => {
  const main = await read(
    'native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java');
  // 源优先级 + 厂商录像门控（USB > 本机 > Wi‑Fi）
  assert.match(main, /wifiSourceActive\(\)/);
  assert.match(main, /wifiVendorSupportsRecording\(\)/);
  // 控制卡：取景/录像按钮 + 参数读数 + ISO/光圈/快门步进
  assert.match(main, /updateWifiControlCard\(\)/);
  assert.match(main, /wifiLiveViewButton/);
  assert.match(main, /wifiRecordButton/);
  assert.match(main, /wifiParameterReadoutView/);
  assert.match(main, /stepWifiIso/);
  assert.match(main, /stepWifiAperture/);
  assert.match(main, /stepWifiShutter/);
  assert.match(main, /refreshWifiParameters\(\)/);
  // 连接/重连成功路径：detectVendor → 自动取景 → 参数刷新
  assert.match(main, /detectVendor\(\)/);
  assert.match(main, /startLiveView\(\)/);
  assert.match(main, /refreshWifiParameters\(\)/);
  // 断连/离线清理：停取景/停录像/清厂商
  assert.match(main, /stopLiveView\(\)/);
  assert.match(main, /wifiMovieRecording = false/);
  assert.match(main, /wifiVendor = PtpIpCamera\.CameraVendor\.UNKNOWN/);
  assert.match(main, /TBC-awaiting-hardware/);
});

test('E4: Harmony PtpIpCamera exposes data-out, vendor detect, live view, record, params', async () => {
  const transport = await read(
    'native/harmony/entry/src/main/ets/camera/PtpIpCamera.ets');
  // data-out 相位（DataPhaseInfo=2：请求→StartData(9)→EndData(12)→响应）
  assert.match(transport, /sendCommandWithDataOut/);
  assert.match(transport, /appendU32\(request, 2\)/);
  assert.match(transport, /appendU64\(startData, data\.length\)/);
  // 厂商识别：0x1001 GetDeviceInfo + 名称启发式 + Manufacturer 解析
  assert.match(transport, /detectVendor/);
  assert.match(transport, /0x1001/);
  assert.match(transport, /deviceInfoManufacturer/);
  assert.match(transport, /vendorForManufacturer/);
  assert.match(transport, /vendorForName/);
  // 取景/录像/参数方法（Nikon opcode + Canon EOS 序列）
  assert.match(transport, /startLiveView/);
  assert.match(transport, /stopLiveView/);
  assert.match(transport, /getLiveViewFrame/);
  assert.match(transport, /startMovieRecording/);
  assert.match(transport, /stopMovieRecording/);
  assert.match(transport, /writeProperty/);
  assert.match(transport, /0x9201/);
  assert.match(transport, /0x9203/);
  assert.match(transport, /0x920a/);
  assert.match(transport, /0x9153/);
  assert.match(transport, /0x500f/);
  assert.match(transport, /0x5007/);
  assert.match(transport, /0x500d/);
  assert.match(transport, /TBC-awaiting-hardware/);
});

test('E4: Harmony Index wires wifi live view, body recording, parameter steppers', async () => {
  const main = await read(
    'native/harmony/entry/src/main/ets/pages/Index.ets');
  // 源优先级 + 厂商录像门控（USB > 本机 > Wi‑Fi）
  assert.match(main, /wifiSourceActive\(\)/);
  assert.match(main, /wifiVendorSupportsRecording\(\)/);
  // 控制卡：取景/录像按钮 + 参数读数 + ISO/光圈/快门步进
  assert.match(main, /WifiStepperRow/);
  assert.match(main, /stepWifiIso/);
  assert.match(main, /stepWifiAperture/);
  assert.match(main, /stepWifiShutter/);
  assert.match(main, /refreshWifiParameters\(\)/);
  assert.match(main, /wifiParameterReadout/);
  // 连接/重连成功路径：detectVendor → 自动取景 → 参数刷新
  assert.match(main, /detectVendor\(\)/);
  assert.match(main, /startLiveView\(\)/);
  assert.match(main, /refreshWifiParameters\(\)/);
  // 预览循环按源路由（Wi‑Fi 源调 wifiCamera.getLiveViewFrame）
  assert.match(main, /wifiCamera\.getLiveViewFrame\(\)/);
  // 断连/离线清理：停取景/停录像/清厂商
  assert.match(main, /wifiCamera\.stopLiveView\(\)/);
  assert.match(main, /wifiMovieRecording = false/);
  assert.match(main, /wifiVendor = CameraVendor\.UNKNOWN/);
  assert.match(main, /TBC-awaiting-hardware/);
});
