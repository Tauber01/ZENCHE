#!/bin/zsh
set -euo pipefail

PROJECT_ROOT=${0:A:h:h}
"$PROJECT_ROOT/scripts/build-macos.sh"
"$PROJECT_ROOT/scripts/build-android.sh"
if command -v xcodebuild >/dev/null &&
   xcrun --sdk iphoneos --show-sdk-path >/dev/null 2>&1; then
  IOS_DESTINATIONS=$(
    xcodebuild \
      -project "$PROJECT_ROOT/native/ios/NikonLink.xcodeproj" \
      -scheme NikonLink \
      -showdestinations 2>&1
  )
  if grep -q "Available destinations" <<<"$IOS_DESTINATIONS"; then
    "$PROJECT_ROOT/scripts/build-ios.sh" --unsigned
  else
    echo "Xcode 未安装可用的 iOS 平台支持，跳过 iOS 未签名构建。"
  fi
else
  echo "未检测到完整 Xcode/iPhoneOS SDK，跳过 iOS 未签名构建。"
fi

if [[ -n "${NIKONLINK_HVIGORW:-}" ]] ||
   [[ -x "$PROJECT_ROOT/native/harmony/hvigorw" ]] ||
   command -v hvigorw >/dev/null 2>&1 ||
   command -v hvigor >/dev/null 2>&1; then
  "$PROJECT_ROOT/scripts/build-harmony.sh"
else
  echo "未检测到 DevEco Studio hvigor，跳过 HarmonyOS 构建。"
fi

echo "Windows EXE 安装包需在 Windows 主机运行 scripts/build-windows.ps1。"
