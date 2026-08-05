#!/bin/zsh
set -euo pipefail

PROJECT_ROOT=${0:A:h:h}
VERSION=1.5.6
ARCH=$(uname -m)
BUILD_ROOT="$PROJECT_ROOT/build/macos"
SDK_ROOT="$PROJECT_ROOT/build/nikon-sdk/macos"
SONY_SDK_ROOT="$PROJECT_ROOT/build/sony-sdk/macos"
BUILD_LOCK="$PROJECT_ROOT/build/.macos-build.lock"
DIST_ROOT="$PROJECT_ROOT/dist"
APP_ROOT="$BUILD_ROOT/帧澈 ZENCHE.app"
CONTENTS="$APP_ROOT/Contents"
RESOURCES="$CONTENTS/Resources"
DMG_ROOT="$BUILD_ROOT/dmg"

mkdir -p "$PROJECT_ROOT/build"
if ! mkdir "$BUILD_LOCK" 2>/dev/null; then
  print -u2 "Another macOS package build is already running: $BUILD_LOCK"
  exit 1
fi
trap 'rmdir "$BUILD_LOCK" 2>/dev/null || true' EXIT

# Keep local packaging usable when a newly installed Xcode is selected but its
# license has not been accepted yet. The Command Line Tools are sufficient here.
if ! /usr/bin/xcrun --find swiftc >/dev/null 2>&1 &&
  [[ -x /Library/Developer/CommandLineTools/usr/bin/swiftc ]]; then
  export DEVELOPER_DIR=/Library/Developer/CommandLineTools
fi

chmod -R u+rwX "$BUILD_ROOT" 2>/dev/null || true
rm -rf "$BUILD_ROOT"
mkdir -p "$CONTENTS/MacOS" "$RESOURCES/bin" "$RESOURCES/lib" \
  "$RESOURCES/camlibs" "$RESOURCES/iolibs" "$CONTENTS/Frameworks" \
  "$DIST_ROOT"

"$PROJECT_ROOT/scripts/prepare-nikon-sdk.sh" >/dev/null
"$PROJECT_ROOT/scripts/prepare-sony-sdk.sh" >/dev/null

xcrun clang++ -std=c++17 -O2 -fvisibility=hidden \
  -c "$PROJECT_ROOT/native/macos/Sources/NikonLink/NikonSDKBridge.cpp" \
  -o "$BUILD_ROOT/NikonSDKBridge.o"
xcrun clang++ -std=c++17 -O2 \
  "$PROJECT_ROOT/native/macos/Sources/NikonLink/NikonSDKProbe.cpp" \
  "$BUILD_ROOT/NikonSDKBridge.o" \
  -framework CoreFoundation \
  -Xlinker -rpath -Xlinker @executable_path/../Frameworks \
  -o "$CONTENTS/MacOS/ZENCHE-NikonSDKProbe"
xcrun clang++ -std=c++17 -O2 -fvisibility=hidden \
  -I "$SONY_SDK_ROOT/include" \
  -c "$PROJECT_ROOT/native/macos/Sources/NikonLink/SonySDKBridge.cpp" \
  -o "$BUILD_ROOT/SonySDKBridge.o"

xcrun swiftc -swift-version 5 -O \
  -framework AppKit -framework SwiftUI -framework Photos -framework AVKit \
  -framework AVFoundation -framework CoreImage \
  -framework Network -framework CoreBluetooth -framework CoreLocation \
  -framework CoreFoundation -Xlinker -rpath \
  -Xlinker @executable_path/../Frameworks \
  -Xlinker "$BUILD_ROOT/NikonSDKBridge.o" \
  -Xlinker "$BUILD_ROOT/SonySDKBridge.o" \
  -L "$SONY_SDK_ROOT/runtime" -lCr_Core -lc++ \
  "$PROJECT_ROOT/native/ios/NikonLink/Models/CameraStorage.swift" \
  "$PROJECT_ROOT/native/ios/NikonLink/Connectivity/RemoteCaptureServices.swift" \
  "$PROJECT_ROOT/native/shared/NikonCloudPreview.swift" \
  "$PROJECT_ROOT/native/macos/Sources/NikonLink/"*.swift \
  -o "$CONTENTS/MacOS/ZENCHE"
LIBUSB_PREFIX=$(brew --prefix libusb)
xcrun clang++ -std=c++17 -O2 \
  -I "$LIBUSB_PREFIX/include/libusb-1.0" \
  "$PROJECT_ROOT/native/macos/Sources/NikonLink/NikonPTPControl.cpp" \
  -L "$LIBUSB_PREFIX/lib" -lusb-1.0 \
  -o "$RESOURCES/bin/zenche-nikon-ptp"
cp "$PROJECT_ROOT/native/macos/Info.plist" "$CONTENTS/Info.plist"
cp "$PROJECT_ROOT/native/macos/Resources/wechat-donation.png" \
  "$RESOURCES/wechat-donation.png"
cp "$PROJECT_ROOT/native/macos/Resources/camera-nikon.jpg" \
  "$RESOURCES/camera-nikon.jpg"
cp "$PROJECT_ROOT/native/macos/Resources/camera-sony.jpg" \
  "$RESOURCES/camera-sony.jpg"
cp "$PROJECT_ROOT/native/macos/Resources/camera-canon.jpg" \
  "$RESOURCES/camera-canon.jpg"
cp "$PROJECT_ROOT/native/macos/Resources/nikon-cloud-presets.json" \
  "$RESOURCES/nikon-cloud-presets.json"
cp -R "$SDK_ROOT/Image/Frameworks/." "$CONTENTS/Frameworks/"
cp -R "$SDK_ROOT/Remote/Frameworks/." "$CONTENTS/Frameworks/"
cp "$SONY_SDK_ROOT/runtime/"*.dylib "$CONTENTS/Frameworks/"
mkdir -p "$CONTENTS/Frameworks/CrAdapter"
cp "$SONY_SDK_ROOT/runtime/CrAdapter/"*.dylib \
  "$CONTENTS/Frameworks/CrAdapter/"
mkdir -p "$RESOURCES/SonySDK"
cp "$SONY_SDK_ROOT/documentation/Camera_Remote_SDK_Readme_v2.02.00.pdf" \
  "$RESOURCES/SonySDK/"
# Archives downloaded through a browser carry quarantine metadata. Leaving it
# on nested SDK dylibs makes dyld reject them even after the enclosing app has
# been signed, so clear only that inherited metadata before code signing.
xattr -dr com.apple.quarantine "$CONTENTS/Frameworks" 2>/dev/null || true
# Nikon's nested TestApp.zip expands Royalmile's framework aliases as real
# duplicate files/directories. Restore the canonical versioned-framework
# symlinks so codesign sees one bundle instead of three overlapping bundles.
ROYALMILE_FRAMEWORK="$CONTENTS/Frameworks/Royalmile.framework"
if [[ -d "$ROYALMILE_FRAMEWORK/Versions/A" ]]; then
  rm -rf "$ROYALMILE_FRAMEWORK/Resources" \
    "$ROYALMILE_FRAMEWORK/Royalmile" \
    "$ROYALMILE_FRAMEWORK/Versions/Current"
  ln -s "Versions/Current/Resources" "$ROYALMILE_FRAMEWORK/Resources"
  ln -s "Versions/Current/Royalmile" "$ROYALMILE_FRAMEWORK/Royalmile"
  ln -s "A" "$ROYALMILE_FRAMEWORK/Versions/Current"
fi
cp -R "$SDK_ROOT/Remote/TypeCommon Module.bundle" "$CONTENTS/MacOS/"
cp -R "$SDK_ROOT/Remote/Config/." "$CONTENTS/MacOS/"
mkdir -p "$RESOURCES/NikonSDK/Remote/Config" \
  "$RESOURCES/NikonSDK/Image/Profiles"
cp -R "$SDK_ROOT/Remote/Config/." "$RESOURCES/NikonSDK/Remote/Config/"
cp -R "$SDK_ROOT/Image/Resources/Profiles/." \
  "$RESOURCES/NikonSDK/Image/Profiles/"
cp "$SDK_ROOT/Image/Resources/prm.bin" "$RESOURCES/prm.bin"
for localization in zh-Hans en ja; do
  mkdir -p "$RESOURCES/$localization.lproj"
  cp "$PROJECT_ROOT/native/ios/NikonLink/$localization.lproj/Localizable.strings" \
    "$RESOURCES/$localization.lproj/Localizable.strings"
  cp "$PROJECT_ROOT/native/ios/NikonLink/$localization.lproj/InfoPlist.strings" \
    "$RESOURCES/$localization.lproj/InfoPlist.strings"
done

ICONSET="$BUILD_ROOT/AppIcon.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$PROJECT_ROOT/icons/icon-512.png" \
    --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  doubled=$((size * 2))
  sips -z "$doubled" "$doubled" "$PROJECT_ROOT/icons/icon-512.png" \
    --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$RESOURCES/AppIcon.icns"

if [[ -d "$PROJECT_ROOT/third_party/licenses" ]]; then
  cp -R "$PROJECT_ROOT/third_party/licenses" "$RESOURCES/Licenses"
fi

GPHOTO_PREFIX=$(brew --prefix libgphoto2)
GPHOTO_BIN=$(command -v gphoto2)
cp "$GPHOTO_BIN" "$RESOURCES/bin/gphoto2"

CAMLIB_DIR=$(find "$GPHOTO_PREFIX/lib/libgphoto2" -mindepth 1 -maxdepth 1 -type d | sort -V | tail -1)
IOLIB_DIR=$(find "$GPHOTO_PREFIX/lib/libgphoto2_port" -mindepth 1 -maxdepth 1 -type d | sort -V | tail -1)
cp "$CAMLIB_DIR/ptp2.so" "$RESOURCES/camlibs/"
cp "$IOLIB_DIR/usb1.so" "$RESOURCES/iolibs/"
chmod -R u+rwX "$RESOURCES"

typeset -a scan_queue
scan_queue=(
  "$RESOURCES/bin/gphoto2"
  "$RESOURCES/bin/zenche-nikon-ptp"
  "$RESOURCES/camlibs/"*.so
  "$RESOURCES/iolibs/"*.so
)
typeset -A copied
while (( ${#scan_queue[@]} )); do
  current=${scan_queue[1]}
  scan_queue=("${scan_queue[@]:1}")
  while IFS= read -r dependency; do
    [[ "$dependency" == /opt/homebrew/* ]] || continue
    base=${dependency:t}
    [[ -n "${copied[$base]-}" ]] && continue
    [[ -f "$dependency" ]] || continue
    cp "$dependency" "$RESOURCES/lib/$base"
    copied[$base]=1
    scan_queue+=("$RESOURCES/lib/$base")
  done < <(otool -L "$current" | tail -n +2 | awk '{print $1}')
done

for target in \
  "$RESOURCES/bin/gphoto2" \
  "$RESOURCES/bin/zenche-nikon-ptp" \
  "$RESOURCES/camlibs/"*.so \
  "$RESOURCES/iolibs/"*.so \
  "$RESOURCES/lib/"*.dylib; do
  [[ -f "$target" ]] || continue
  while IFS= read -r dependency; do
    [[ "$dependency" == /opt/homebrew/* ]] || continue
    install_name_tool -change "$dependency" "@rpath/${dependency:t}" "$target"
  done < <(otool -L "$target" | tail -n +2 | awk '{print $1}')
  if [[ "$target" == "$RESOURCES/lib/"*.dylib ]]; then
    install_name_tool -id "@rpath/${target:t}" "$target"
  fi
done
install_name_tool -add_rpath "@executable_path/../lib" "$RESOURCES/bin/gphoto2" 2>/dev/null || true
install_name_tool -add_rpath "@executable_path/../lib" \
  "$RESOURCES/bin/zenche-nikon-ptp" 2>/dev/null || true

find "$RESOURCES" -type f \( \
    -name "*.dylib" -o -name "*.so" -o -name "gphoto2" -o \
    -name "zenche-nikon-ptp" \
  \) -print0 |
  xargs -0 -n1 codesign --force --sign - --timestamp=none
find "$CONTENTS/Frameworks" -type f -name "*.dylib" -print0 |
  xargs -0 -n1 codesign --force --sign - --timestamp=none
for framework_binary in \
  "$CONTENTS/Frameworks/Elm.framework/Versions/A/Elm" \
  "$CONTENTS/Frameworks/Royalmile.framework/Versions/A/Royalmile"; do
  [[ -f "$framework_binary" ]] || continue
  codesign --force --sign - --timestamp=none "$framework_binary"
done
codesign --force --deep --sign - --timestamp=none \
  "$CONTENTS/MacOS/TypeCommon Module.bundle"
codesign --force --sign - --timestamp=none \
  "$CONTENTS/MacOS/ZENCHE-NikonSDKProbe"
codesign --force --deep --sign - --timestamp=none \
  --entitlements "$PROJECT_ROOT/native/macos/Entitlements.plist" "$APP_ROOT"

DMG_PATH="$DIST_ROOT/ZENCHE-$VERSION-macOS-$ARCH.dmg"
rm -f "$DMG_PATH"
mkdir -p "$DMG_ROOT"
cp -R "$APP_ROOT" "$DMG_ROOT/"
ln -s /Applications "$DMG_ROOT/Applications"
hdiutil create -volname "帧澈 ZENCHE $VERSION" -srcfolder "$DMG_ROOT" \
  -format UDZO -ov "$DMG_PATH"
codesign --verify --deep --strict "$APP_ROOT"
shasum -a 256 "$DMG_PATH" |
  awk -v name="${DMG_PATH:t}" '{print $1 "  " name}' \
  > "$DMG_PATH.sha256"
echo "$DMG_PATH"
