import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import test from "node:test";

const root = path.resolve(import.meta.dirname, "..");
const read = (relative) => fs.readFileSync(path.join(root, relative), "utf8");

test("desktop builds package and dynamically initialize Nikon's official SDKs", () => {
  const macBuild = read("scripts/build-macos.sh");
  const macBridge = read(
    "native/macos/Sources/NikonLink/NikonSDKBridge.cpp",
  );
  const macService = read(
    "native/macos/Sources/NikonLink/NikonOfficialSDK.swift",
  );
  const macProbe = read(
    "native/macos/Sources/NikonLink/NikonSDKProbe.cpp",
  );
  const windowsBuild = read("scripts/build-windows.ps1");
  const windowsService = read(
    "native/windows/Services/NikonOfficialSdkService.cs",
  );

  assert.match(macBuild, /prepare-nikon-sdk\.sh/);
  assert.match(macBuild, /TypeCommon Module\.bundle/);
  assert.match(macBuild, /libImgSDK\.dylib|Image\/Frameworks/);
  assert.match(macBridge, /InitializeSDK/);
  assert.match(macBridge, /Nkfl_Entry/);
  assert.match(macBridge, /0x0001/);
  assert.match(macBridge, /CFRunLoopRunInMode/);
  assert.match(macBridge, /EnumDevices/);
  assert.match(macBuild, /ZENCHE-NikonSDKProbe/);
  assert.match(macService, /performIsolatedProbe/);
  assert.match(macService, /Process\(\)/);
  assert.match(macProbe, /ScopedStdoutSilencer/);
  assert.match(macService, /decodeProbeOutput/);
  assert.match(macService, /\{\\"loaded\\":/);

  assert.match(windowsBuild, /prepare-nikon-sdk\.ps1/);
  assert.match(windowsBuild, /NikonSDK/);
  assert.match(windowsService, /ControlServiceLayer\.dll/);
  assert.match(windowsService, /NkImgSDK\.dll/);
  assert.match(windowsService, /NativeLibrary\.GetExport/);
  assert.match(windowsService, /InitializeSDK/);
  assert.match(windowsService, /Nkfl_Entry/);
});

test("all five native targets expose an honest Nikon SDK status", () => {
  const sources = [
    "native/macos/Sources/NikonLink/main.swift",
    "native/windows/MainWindow.xaml.cs",
    "native/ios/NikonLink/Views/RootView.swift",
    "native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java",
    "native/harmony/entry/src/main/ets/pages/Index.ets",
  ].map(read);

  for (const source of sources) {
    assert.match(source, /尼康官方 SDK/);
  }
  for (const mobileSource of sources.slice(2)) {
    assert.match(mobileSource, /官方桌面 SDK 不提供当前平台运行库/);
  }
});

test("macOS offers connection after the official SDK finds an available camera", () => {
  const service = read(
    "native/macos/Sources/NikonLink/NikonOfficialSDK.swift",
  );
  const interfaceSource = read(
    "native/macos/Sources/NikonLink/main.swift",
  );

  assert.match(service, /hasAvailableDevice/);
  assert.match(service, /remote\.devices\.contains/);
  assert.match(interfaceSource, /nikonOfficialSDK\.hasAvailableDevice/);
  assert.match(
    interfaceSource,
    /model\.connected\s*\? model\.disconnect\(\)\s*:\s*model\.connect\(\)/,
  );
});

test("macOS isolates crash-prone Nikon probes while keeping refresh functional", () => {
  const service = read(
    "native/macos/Sources/NikonLink/NikonOfficialSDK.swift",
  );

  assert.match(service, /operatingSystemVersion\.majorVersion >= 26/);
  assert.match(service, /isolateImageProbe/);
  assert.match(service, /performIsolatedProbe/);
  assert.match(service, /ZENCHE-NikonSDKProbe/);
});

test("SDK source archives and generated proprietary runtimes stay untracked", () => {
  const ignore = read(".gitignore");
  assert.match(ignore, /NikonSDK\//);
  assert.match(ignore, /S-SDKNEF-\*-ALLIN\.zip/);
  assert.match(ignore, /S-SDKZ-\*-ALLIN\.zip/);
  assert.match(read("README.md"), /proprietary Nikon runtimes are not committed/);
});
