#!/bin/zsh
set -euo pipefail

PROJECT_ROOT=${0:A:h:h}
VERSION=1.2.0
MODE=${1:---unsigned}
IOS_ROOT="$PROJECT_ROOT/native/ios"
BUILD_ROOT="$PROJECT_ROOT/build/ios"
DIST_ROOT="$PROJECT_ROOT/dist"
PROJECT="$IOS_ROOT/NikonLink.xcodeproj"
SCHEME=NikonLink
DESTINATION="generic/platform=iOS"

if [[ "$MODE" != "--unsigned" && "$MODE" != "--signed" ]]; then
  echo "用法：$0 [--unsigned|--signed]" >&2
  exit 64
fi

if ! command -v xcodebuild >/dev/null ||
   ! xcrun --sdk iphoneos --show-sdk-path >/dev/null 2>&1; then
  echo "需要安装完整 Xcode，并在 Xcode 设置中启用 iOS SDK。" >&2
  exit 2
fi

DESTINATIONS=$(
  xcodebuild -project "$PROJECT" -scheme "$SCHEME" -showdestinations 2>&1
)
if ! grep -q "Available destinations" <<<"$DESTINATIONS"; then
  echo "Xcode 尚未安装可用的 iOS 平台支持；请在 Xcode → Settings → Components 中安装 iOS。" >&2
  exit 2
fi

rm -rf "$BUILD_ROOT"
mkdir -p "$BUILD_ROOT" "$DIST_ROOT"

if [[ "$MODE" == "--unsigned" ]]; then
  DERIVED_DATA="$BUILD_ROOT/DerivedData"
  xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -sdk iphoneos \
    -destination "$DESTINATION" \
    -derivedDataPath "$DERIVED_DATA" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    build

  APP_SOURCE="$DERIVED_DATA/Build/Products/Release-iphoneos/帧澈 ZENCHE.app"
  [[ -d "$APP_SOURCE" ]] || {
    echo "未找到 iOS 应用构建结果。" >&2
    exit 1
  }

  PACKAGE_ROOT="$BUILD_ROOT/package"
  PAYLOAD_ROOT="$PACKAGE_ROOT/Payload"
  mkdir -p "$PAYLOAD_ROOT"
  ditto "$APP_SOURCE" "$PAYLOAD_ROOT/帧澈 ZENCHE.app"

  IPA_TARGET="$DIST_ROOT/ZENCHE-$VERSION-ios-unsigned.ipa"
  rm -f "$IPA_TARGET"
  (
    cd "$PACKAGE_ROOT"
    /usr/bin/zip -qry "$IPA_TARGET" Payload
  )
else
  : "${IOS_DEVELOPMENT_TEAM:?请设置 IOS_DEVELOPMENT_TEAM}"

  ARCHIVE_PATH="$BUILD_ROOT/NikonLink.xcarchive"
  EXPORT_ROOT="$BUILD_ROOT/export"
  EXPORT_OPTIONS="$BUILD_ROOT/ExportOptions.plist"
  cp "$IOS_ROOT/ExportOptions.plist" "$EXPORT_OPTIONS"
  /usr/libexec/PlistBuddy -c \
    "Set :teamID $IOS_DEVELOPMENT_TEAM" "$EXPORT_OPTIONS"
  /usr/libexec/PlistBuddy -c \
    "Set :method ${IOS_EXPORT_METHOD:-development}" "$EXPORT_OPTIONS"

  typeset -a signing_arguments
  signing_arguments=(
    "DEVELOPMENT_TEAM=$IOS_DEVELOPMENT_TEAM"
  )

  if [[ -n "${IOS_PROFILE_SPECIFIER:-}" ]]; then
    signing_arguments+=(
      "CODE_SIGN_STYLE=Manual"
      "PROVISIONING_PROFILE_SPECIFIER=$IOS_PROFILE_SPECIFIER"
    )
    [[ -n "${IOS_SIGNING_IDENTITY:-}" ]] &&
      signing_arguments+=("CODE_SIGN_IDENTITY=$IOS_SIGNING_IDENTITY")
    /usr/libexec/PlistBuddy -c "Set :signingStyle manual" "$EXPORT_OPTIONS"
    /usr/libexec/PlistBuddy -c "Add :provisioningProfiles dict" "$EXPORT_OPTIONS"
    /usr/libexec/PlistBuddy -c \
      "Add :provisioningProfiles:com.tauber.nikonlink.ios string $IOS_PROFILE_SPECIFIER" \
      "$EXPORT_OPTIONS"
  else
    signing_arguments+=("CODE_SIGN_STYLE=Automatic")
  fi

  xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -sdk iphoneos \
    -destination "$DESTINATION" \
    -archivePath "$ARCHIVE_PATH" \
    -allowProvisioningUpdates \
    "${signing_arguments[@]}" \
    archive

  xcodebuild \
    -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_ROOT" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    -allowProvisioningUpdates

  IPA_SOURCE=$(find "$EXPORT_ROOT" -maxdepth 1 -type f -name "*.ipa" | head -1)
  [[ -n "$IPA_SOURCE" ]] || {
    echo "签名导出完成，但未找到 IPA。" >&2
    exit 1
  }
  IPA_TARGET="$DIST_ROOT/ZENCHE-$VERSION-ios-signed.ipa"
  cp "$IPA_SOURCE" "$IPA_TARGET"
fi

shasum -a 256 "$IPA_TARGET" |
  awk -v name="${IPA_TARGET:t}" '{print $1 "  " name}' \
  > "$IPA_TARGET.sha256"
echo "$IPA_TARGET"
