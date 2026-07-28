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
