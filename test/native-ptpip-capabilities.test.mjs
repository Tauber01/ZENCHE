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
