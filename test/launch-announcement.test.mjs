import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const targets = {
  ios: ["native/ios/NikonLink/Views/RootView.swift"],
  android: [
    "native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java",
  ],
  harmony: ["native/harmony/entry/src/main/ets/pages/Index.ets"],
  macos: [
    "native/macos/Sources/NikonLink/main.swift",
    "native/macos/Sources/NikonLink/SettingsSheet.swift",
  ],
  windows: ["native/windows/MainWindow.xaml.cs"],
};

const scamWarning =
  "帧澈 ZENCHE 是开源免费项目。任何声称“进群领取软件”";
const fastFeedbackMessage =
  "公开问题可继续在 GitHub 免费提交；在爱发电赞助后，可获取快速问题反馈渠道。";
const officialQqGroup = "官方 QQ 群：165315727";
const afdianUrl = "https://www.ifdian.net/a/Tauber";
const announcementHighlights = [
  "Sony ZV‑E10",
  "一键导入照片和视频",
  "五端文件库改为“所有文件”优先",
  "1.5.14 已通过 GitHub 与官网发布",
];

test("all native targets show the launch announcement and scam warning", async () => {
  for (const [platform, paths] of Object.entries(targets)) {
    const source = (
      await Promise.all(paths.map((path) => readFile(path, "utf8")))
    ).join("\n");
    assert.match(
      source,
      /LaunchAnnouncement|launchAnnouncement/,
      `${platform} is missing the launch announcement`,
    );
    assert.ok(
      source.includes(scamWarning),
      `${platform} is missing the scam warning`,
    );
  }
});

test("all native targets persist announcement dismissal by app version", async () => {
  const sources = await Promise.all(
    Object.values(targets).map(async (paths) =>
      (
        await Promise.all(paths.map((path) => readFile(path, "utf8")))
      ).join("\n"),
    ),
  );
  for (const [index, source] of sources.entries()) {
    assert.match(
      source,
      /dismissed.*announcement.*version/i,
      `${Object.keys(targets)[index]} is missing version-scoped dismissal`,
    );
  }
});

test("all native targets describe the complete 1.5.14 release", async () => {
  for (const [platform, paths] of Object.entries(targets)) {
    const source = (
      await Promise.all(paths.map((path) => readFile(path, "utf8")))
    ).join("\n");
    for (const highlight of announcementHighlights) {
      assert.ok(
        source.includes(highlight),
        `${platform} launch announcement is missing: ${highlight}`,
      );
    }
  }
});

test("the bundled donation image is shared or copied across native packages", async () => {
  const sharedImage = await readFile(
    "native/macos/Resources/wechat-donation.png",
  );
  const harmonyImage = await readFile(
    "native/harmony/entry/src/main/resources/base/media/afdian_donation.png",
  );
  assert.deepEqual(harmonyImage, sharedImage);

  const iosProject = await readFile(
    "native/ios/NikonLink.xcodeproj/project.pbxproj",
    "utf8",
  );
  const androidBuild = await readFile(
    "native/android/app/build.gradle",
    "utf8",
  );
  const windowsProject = await readFile(
    "native/windows/NikonLink.Windows.csproj",
    "utf8",
  );
  assert.match(iosProject, /macos\/Resources\/wechat-donation\.png/);
  assert.match(androidBuild, /macos\/Resources/);
  assert.match(windowsProject, /macos\\Resources\\wechat-donation\.png/);
});

test("all native targets disclose the optional faster feedback channel", async () => {
  for (const [platform, paths] of Object.entries(targets)) {
    const source = (
      await Promise.all(paths.map((path) => readFile(path, "utf8")))
    ).join("\n");
    assert.ok(
      source.includes(fastFeedbackMessage),
      `${platform} is missing the faster-feedback disclosure`,
    );
    assert.ok(
      source.includes(afdianUrl),
      `${platform} is missing the Afdian destination`,
    );
    assert.ok(
      source.includes(officialQqGroup),
      `${platform} is missing the official QQ group`,
    );
  }
});
