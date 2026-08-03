#!/bin/zsh
set -euo pipefail

PROJECT_ROOT=${0:A:h:h}

DIST="$PROJECT_ROOT/dist"
ARCHIVE="$DIST/旧版"
CURRENT_VERSION=$(node -e "console.log(require('$PROJECT_ROOT/package.json').version)" 2>/dev/null || echo "1.5.0")
mkdir -p "$DIST" "$ARCHIVE"
setopt NULL_GLOB
echo "归档 $CURRENT_VERSION 之前的旧版安装包…"
for f in "$DIST"/*; do
  base=$(basename "$f")
  [[ "$base" == "旧版" || "$base" == ".DS_Store" || "$base" == ZENCHE-${CURRENT_VERSION}* ]] && continue
  [[ -f "$f" ]] && mv "$f" "$ARCHIVE/"
done
echo "归档完成。"

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
