#!/bin/zsh
set -euo pipefail

PROJECT_ROOT=${0:A:h:h}
IMAGE_SDK_ZIP=${NIKON_IMAGE_SDK_ZIP:-"$PROJECT_ROOT/S-SDKNEF-001BF-ALLIN.zip"}
REMOTE_SDK_ZIP=${NIKON_REMOTE_SDK_ZIP:-"$PROJECT_ROOT/S-SDKZ-200BF-ALLIN.zip"}
OUTPUT_ROOT=${NIKON_SDK_OUTPUT:-"$PROJECT_ROOT/build/nikon-sdk/macos"}

if [[ ! -f "$IMAGE_SDK_ZIP" ]]; then
  print -u2 "Nikon Image SDK archive not found: $IMAGE_SDK_ZIP"
  exit 1
fi
if [[ ! -f "$REMOTE_SDK_ZIP" ]]; then
  print -u2 "Nikon Remote SDK archive not found: $REMOTE_SDK_ZIP"
  exit 1
fi

TEMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/zenche-nikon-sdk.XXXXXX")
trap 'rm -rf "$TEMP_ROOT"' EXIT

rm -rf "$OUTPUT_ROOT"
mkdir -p \
  "$OUTPUT_ROOT/Image/Frameworks" \
  "$OUTPUT_ROOT/Image/Resources/Profiles" \
  "$OUTPUT_ROOT/Remote/Frameworks" \
  "$OUTPUT_ROOT/Remote/Config"

unzip -q "$IMAGE_SDK_ZIP" \
  'Image SDK/Library/Mac/Sample/Lib/release/*' \
  'Image SDK/Library/Mac/Sample/Resources/prm.bin' \
  'Image SDK/Library/Mac/Profiles/*' \
  -d "$TEMP_ROOT/image"

IMAGE_LIBRARY_ROOT="$TEMP_ROOT/image/Image SDK/Library/Mac"
cp -R "$IMAGE_LIBRARY_ROOT/Sample/Lib/release/"*.dylib \
  "$OUTPUT_ROOT/Image/Frameworks/"
cp -R "$IMAGE_LIBRARY_ROOT/Sample/Lib/release/Elm.framework" \
  "$OUTPUT_ROOT/Image/Frameworks/"
cp "$IMAGE_LIBRARY_ROOT/Sample/Resources/prm.bin" \
  "$OUTPUT_ROOT/Image/Resources/prm.bin"
cp -R "$IMAGE_LIBRARY_ROOT/Profiles/." \
  "$OUTPUT_ROOT/Image/Resources/Profiles/"

unzip -q "$REMOTE_SDK_ZIP" 'Module/Mac/BinaryFile/TestApp.zip' \
  -d "$TEMP_ROOT/remote"
unzip -q "$TEMP_ROOT/remote/Module/Mac/BinaryFile/TestApp.zip" \
  -d "$TEMP_ROOT/remote-runtime"

REMOTE_APP="$TEMP_ROOT/remote-runtime/TestApp"
cp -R "$REMOTE_APP/Frameworks/libNkPTPDriver2.dylib" \
  "$OUTPUT_ROOT/Remote/Frameworks/"
cp -R "$REMOTE_APP/Frameworks/Royalmile.framework" \
  "$OUTPUT_ROOT/Remote/Frameworks/"
cp -R "$REMOTE_APP/TestApp/TypeCommon Module.bundle" \
  "$OUTPUT_ROOT/Remote/"
for config in DC_PTP_Config.config MaidLayer.config RangeValue.config; do
  cp "$REMOTE_APP/TestApp/$config" "$OUTPUT_ROOT/Remote/Config/$config"
done

print "$OUTPUT_ROOT"
