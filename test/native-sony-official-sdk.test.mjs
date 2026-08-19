import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import test from "node:test";

const root = path.resolve(import.meta.dirname, "..");
const read = (relative) => fs.readFileSync(path.join(root, relative), "utf8");

test("desktop builds prepare and package Sony Camera Remote SDK 2.02.00", () => {
  const macBuild = read("scripts/build-macos.sh");
  const windowsBuild = read("scripts/build-windows.ps1");
  const macPrepare = read("scripts/prepare-sony-sdk.sh");
  const windowsPrepare = read("scripts/prepare-sony-sdk.ps1");

  assert.match(macBuild, /prepare-sony-sdk\.sh/);
  assert.match(macBuild, /SonySDKBridge\.cpp/);
  assert.match(macBuild, /lCr_Core/);
  assert.match(macBuild, /CrAdapter/);
  assert.match(windowsBuild, /prepare-sony-sdk\.ps1/);
  assert.match(windowsBuild, /CrAdapter/);
  assert.match(macPrepare, /SimpleCli\.zip/);
  assert.match(windowsPrepare, /SimpleCli\.zip/);
  assert.match(macPrepare, /Camera_Remote_SDK_Readme_v2\.02\.00\.pdf/);
  assert.match(windowsPrepare, /Camera_Remote_SDK_Readme_v2\.02\.00\.pdf/);
});

test("macOS routes Sony camera operations through the official SDK bridge", () => {
  const bridge = read(
    "native/macos/Sources/NikonLink/SonySDKBridge.cpp",
  );
  const service = read(
    "native/macos/Sources/NikonLink/SonyOfficialSDK.swift",
  );
  const camera = read("native/macos/Sources/NikonLink/main.swift");

  for (const api of [
    "EnumCameraObjects",
    "Connect",
    "GetLiveViewImage",
    "SendCommand",
    "GetSelectDeviceProperties",
    "SetDeviceProperty",
    "SetSaveInfo",
  ]) {
    assert.match(bridge, new RegExp(`SCRSDK::${api}`));
  }
  assert.match(service, /SonyOfficialSDKService/);
  assert.match(service, /CrDeviceProperty_Movie_File_Format|property = 295/);
  assert.match(service, /CrDeviceProperty_PictureProfile|property = 426/);
  assert.match(camera, /sonyOfficialSDK\.connect/);
  assert.match(camera, /sonyOfficialSDK\.liveViewImage/);
  assert.match(camera, /sonyOfficialSDK\.setMovieRecording/);
});

test("macOS falls back to a verified gphoto2 USB/PTP session when Sony SDK connection fails", () => {
  const camera = read("native/macos/Sources/NikonLink/main.swift");

  const sonyBranch = camera.match(
    /if matchedProfile\.vendorName == "Sony" \{([\s\S]*?)\n        \}\n        profile = matchedProfile/,
  )?.[1] ?? "";
  assert.ok(sonyBranch, "expected the Sony connection branch");
  assert.match(sonyBranch, /do \{[\s\S]*sonyOfficialSDK\.connect/);
  assert.match(sonyBranch, /catch \{/);
  assert.match(sonyBranch, /_ = try run\(\["--summary"\]\)/);
  assert.match(sonyBranch, /profile = matchedProfile[\s\S]*connected = true/);
  assert.match(sonyBranch, /gphoto2 USB\/PTP 回退/);

  const fallbackVerification = sonyBranch.indexOf(
    '_ = try run(["--summary"])',
  );
  const fallbackPublish = sonyBranch.lastIndexOf("connected = true");
  assert.ok(
    fallbackVerification >= 0 && fallbackVerification < fallbackPublish,
    "USB/PTP verification must finish before fallback connection is published",
  );
});

test("macOS isolates Sony and Nikon native SDK runtimes before connecting", () => {
  const camera = read("native/macos/Sources/NikonLink/main.swift");
  const nikonService = read(
    "native/macos/Sources/NikonLink/NikonOfficialSDK.swift",
  );

  assert.match(camera, /nikonOfficialSDK\.refresh\(allowRemoteProbe: false\)/);
  assert.match(camera, /sonyOfficialSDK\.refresh\(allowProbe: false\)/);
  assert.match(nikonService, /let sonyRuntimeInstalled/);
  assert.match(nikonService, /let isolateRemoteProbe = sonyRuntimeInstalled/);
  assert.match(
    nikonService,
    /isolateRemoteProbe[\s\S]*performIsolatedProbe/,
  );
});

test("Windows routes Sony cameras through Cr_Core instead of experimental PTP", () => {
  const sdk = read(
    "native/windows/Services/SonyOfficialSdkCamera.cs",
  );
  const camera = read("native/windows/Services/PtpCamera.cs");

  assert.match(sdk, /NativeLibrary\.Load/);
  assert.match(sdk, /EnumCameraObjects/);
  assert.match(sdk, /GetLiveViewImage/);
  assert.match(sdk, /SetDeviceProperty/);
  assert.match(sdk, /CommandMovieRecord/);
  assert.match(camera, /_sonySDK\.TryConnect/);
  assert.match(camera, /_sonySDK\.Capture/);
  assert.match(camera, /_sonySDK\.TriggerAutofocus/);
  assert.match(
    camera,
    /Camera Remote SDK 2\.02\.00 未能建立会话/,
  );
});

test("all five native targets expose an honest Sony SDK status", () => {
  const sources = [
    "native/macos/Sources/NikonLink/main.swift",
    "native/windows/MainWindow.xaml.cs",
    "native/ios/NikonLink/Views/RootView.swift",
    "native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java",
    "native/harmony/entry/src/main/ets/pages/Index.ets",
  ].map(read);

  for (const source of sources) assert.match(source, /索尼官方 SDK/);
  for (const mobileSource of sources.slice(2)) {
    assert.match(mobileSource, /官方桌面 SDK 不提供当前平台运行库/);
    assert.match(mobileSource, /Camera Remote Command/);
  }
});

test("Sony SDK archives and prepared proprietary runtimes stay untracked", () => {
  const ignore = read(".gitignore");
  assert.match(ignore, /SonySDK\//);
  assert.match(ignore, /CrSDK_v\*-Mac\.zip/);
  assert.match(ignore, /CrSDK_v\*-Win64\.zip/);
  assert.match(ignore, /CameraRemoteCommand-\*\.zip/);
});
