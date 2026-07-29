#!/bin/zsh
set -euo pipefail

PROJECT_ROOT=${0:A:h:h}
VERSION=0.7.1
ARCH=$(uname -m)
BUILD_ROOT="$PROJECT_ROOT/build/macos"
DIST_ROOT="$PROJECT_ROOT/dist"
APP_ROOT="$BUILD_ROOT/Nikon Link.app"
CONTENTS="$APP_ROOT/Contents"
RESOURCES="$CONTENTS/Resources"
DMG_ROOT="$BUILD_ROOT/dmg"

# Keep local packaging usable when a newly installed Xcode is selected but its
# license has not been accepted yet. The Command Line Tools are sufficient here.
if ! /usr/bin/xcrun --find swiftc >/dev/null 2>&1 &&
  [[ -x /Library/Developer/CommandLineTools/usr/bin/swiftc ]]; then
  export DEVELOPER_DIR=/Library/Developer/CommandLineTools
fi

rm -rf "$BUILD_ROOT"
mkdir -p "$CONTENTS/MacOS" "$RESOURCES/bin" "$RESOURCES/lib" \
  "$RESOURCES/camlibs" "$RESOURCES/iolibs" "$DIST_ROOT"

xcrun swiftc -swift-version 5 -O \
  -framework AppKit -framework SwiftUI \
  "$PROJECT_ROOT/native/macos/Sources/NikonLink/"*.swift \
  -o "$CONTENTS/MacOS/NikonLink"
cp "$PROJECT_ROOT/native/macos/Info.plist" "$CONTENTS/Info.plist"
cp "$PROJECT_ROOT/native/macos/Resources/wechat-donation.png" \
  "$RESOURCES/wechat-donation.png"

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

typeset -a scan_queue
scan_queue=("$RESOURCES/bin/gphoto2" "$RESOURCES/camlibs/"*.so "$RESOURCES/iolibs/"*.so)
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

for target in "$RESOURCES/bin/gphoto2" "$RESOURCES/camlibs/"*.so "$RESOURCES/iolibs/"*.so "$RESOURCES/lib/"*.dylib; do
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

find "$RESOURCES" -type f \( -name "*.dylib" -o -name "*.so" -o -name "gphoto2" \) -print0 |
  xargs -0 -n1 codesign --force --sign - --timestamp=none
codesign --force --deep --sign - --timestamp=none \
  --entitlements "$PROJECT_ROOT/native/macos/Entitlements.plist" "$APP_ROOT"

DMG_PATH="$DIST_ROOT/NikonLink-$VERSION-macOS-$ARCH.dmg"
rm -f "$DMG_PATH"
mkdir -p "$DMG_ROOT"
cp -R "$APP_ROOT" "$DMG_ROOT/"
ln -s /Applications "$DMG_ROOT/Applications"
hdiutil create -volname "Nikon Link $VERSION" -srcfolder "$DMG_ROOT" \
  -format UDZO -ov "$DMG_PATH"
codesign --verify --deep --strict "$APP_ROOT"
shasum -a 256 "$DMG_PATH" > "$DMG_PATH.sha256"
echo "$DMG_PATH"
