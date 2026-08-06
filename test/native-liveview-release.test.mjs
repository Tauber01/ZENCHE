// S4b regression (#40/#23): live-view stop and failure paths must release
// tasks, threads, subprocesses, listeners and frames on all five targets.
// No unbounded frame buffers, no background loops that keep running after
// stop/disconnect/page-switch. These assertions lock the current safe
// implementation so future edits cannot silently regress it.
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const android = "native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java";
const harmonyPage = "native/harmony/entry/src/main/ets/pages/Index.ets";
const macos = "native/macos/Sources/NikonLink/main.swift";
const iosCamera = "native/ios/NikonLink/Camera/CameraService.swift";
const iosPtpIp = "native/ios/NikonLink/Connectivity/RemoteCaptureServices.swift";
const windows = "native/windows/Services/PtpCamera.cs";

test("Android: generation-guarded single-frame pump stops and releases on 3 strikes", async () => {
  const source = await readFile(android, "utf8");
  assert.match(
    source,
    /previewGeneration\+\+;[\s\S]{0,120}liveViewEnabled = false;/,
    "strike-out must invalidate the preview generation and stop the loop",
  );
  assert.match(
    source,
    /failures >= 3[\s\S]{0,300}finishExternalRecordingForDisconnect\(\)[\s\S]{0,200}stopLiveView\(\)/,
    "3 failures must finalize the recorder and stop live view",
  );
  assert.match(
    source,
    /previewWorkerRunning\.compareAndSet\(false, true\)/,
    "decode/process worker must be single-flight",
  );
  assert.match(
    source,
    /generation != previewGeneration[\s\S]{0,80}return;/,
    "stale generations must be dropped before work",
  );
});

test("HarmonyOS: failure loop stops live view and releases after 3 strikes", async () => {
  const source = await readFile(harmonyPage, "utf8");
  // E4 1.5.9: startPreviewLoop 按源路由（USB > 本机 > Wi‑Fi），失败路径
  // 仍是「收尾外录 → 停取景（wifiCamera 或 camera）→ 清 liveView 标志」；
  // 源分支使 stopLiveView() 到 liveView=false 的间隔变宽，锚点窗口随布局放宽。
  assert.match(
    source,
    /failures >= 3[\s\S]{0,200}finishExternalRecordingForDisconnect\(\)[\s\S]{0,250}stopLiveView\(\)[\s\S]{0,250}liveView = false;/,
    "3 failures must stop live view and clear state",
  );
  assert.match(source, /previewGeneration\+\+/, "stale generation must be invalidated");
});

test("macOS: gphoto live-view process is guarded, force-killed and drained", async () => {
  const source = await readFile(macos, "utf8");
  assert.match(
    source,
    /if let liveViewProcess, liveViewProcess\.isRunning/,
    "start must not duplicate a running live-view process",
  );
  assert.match(
    source,
    /Darwin\.kill\(process\.processIdentifier, SIGKILL\)[\s\S]{0,120}process\.waitUntilExit\(\)/,
    "stop must force-kill and reap the live-view process",
  );
  assert.match(
    source,
    /appendAvailableLiveViewErrors\(\)/,
    "stderr pipe must be drained so gphoto2 never blocks on it",
  );
});

test("iOS: disconnect stops the session, removes inputs/outputs and cancels PTP/IP", async () => {
  const camera = await readFile(iosCamera, "utf8");
  const ptpIp = await readFile(iosPtpIp, "utf8");
  assert.match(
    camera,
    /session\.isRunning[\s\S]{0,80}session\.stopRunning\(\)/,
    "disconnect must stop the AVCaptureSession",
  );
  assert.match(
    camera,
    /session\.inputs\.forEach\(self\.session\.removeInput\)/,
    "disconnect must remove all inputs",
  );
  assert.match(camera, /deinit[\s\S]{0,120}removeObserver\(self\)/, "deinit must drop observers");
  assert.match(
    ptpIp,
    /func disconnect\(\) async[\s\S]{0,80}command\?\.cancel\(\)[\s\S]{0,40}event\?\.cancel\(\)/,
    "PTP/IP disconnect must cancel both command and event connections",
  );
});

test("Windows: disconnect releases interface, closes handle and exits libusb", async () => {
  const source = await readFile(windows, "utf8");
  assert.match(
    source,
    /libusb_release_interface\([\s\S]{0,120}libusb_close\(_deviceHandle\)[\s\S]{0,120}libusb_exit\(_context\)/,
    "DisconnectCore must release the interface, close the device and exit the context",
  );
  assert.match(source, /_deviceHandle = nint\.Zero;[\s\S]{0,120}_interfaceNumber = -1;/, "state must reset");
});
