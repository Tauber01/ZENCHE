#!/bin/zsh
set -euo pipefail

PROJECT_ROOT=${0:A:h:h}
SDK_ZIP=${SONY_CRSDK_MAC_ZIP:-"$PROJECT_ROOT/CrSDK_v2.02.00_20260610a_Mac.zip"}
OUTPUT_ROOT=${SONY_CRSDK_OUTPUT:-"$PROJECT_ROOT/build/sony-sdk/macos"}

if [[ ! -f "$SDK_ZIP" ]]; then
  print -u2 "Sony Camera Remote SDK archive not found: $SDK_ZIP"
  exit 1
fi

TEMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/zenche-sony-sdk.XXXXXX")
trap 'rm -rf "$TEMP_ROOT"' EXIT

unzip -q "$SDK_ZIP" 'SimpleCli.zip' 'Camera_Remote_SDK_Readme_v2.02.00.pdf' \
  -d "$TEMP_ROOT/outer"
unzip -q "$TEMP_ROOT/outer/SimpleCli.zip" -d "$TEMP_ROOT/simple"

HEADER_ROOT="$TEMP_ROOT/simple/app/CRSDK"
RUNTIME_ROOT="$TEMP_ROOT/simple/external/crsdk"
for required in \
  "$HEADER_ROOT/CameraRemote_SDK.h" \
  "$RUNTIME_ROOT/libCr_Core.dylib" \
  "$RUNTIME_ROOT/libmonitor_protocol.dylib" \
  "$RUNTIME_ROOT/libmonitor_protocol_pf.dylib" \
  "$RUNTIME_ROOT/CrAdapter/libCr_PTP_USB.dylib" \
  "$RUNTIME_ROOT/CrAdapter/libCr_PTP_IP.dylib" \
  "$RUNTIME_ROOT/CrAdapter/libusb-1.0.0.dylib" \
  "$RUNTIME_ROOT/CrAdapter/libssh2.dylib"; do
  if [[ ! -e "$required" ]]; then
    print -u2 "Required Sony SDK file is missing: $required"
    exit 1
  fi
done

rm -rf "$OUTPUT_ROOT"
mkdir -p "$OUTPUT_ROOT/include/CRSDK" "$OUTPUT_ROOT/runtime/CrAdapter" \
  "$OUTPUT_ROOT/documentation"
cp "$HEADER_ROOT/"*.h "$OUTPUT_ROOT/include/CRSDK/"
cp "$RUNTIME_ROOT/"*.dylib "$OUTPUT_ROOT/runtime/"
cp "$RUNTIME_ROOT/CrAdapter/"*.dylib "$OUTPUT_ROOT/runtime/CrAdapter/"
cp "$TEMP_ROOT/outer/Camera_Remote_SDK_Readme_v2.02.00.pdf" \
  "$OUTPUT_ROOT/documentation/"

print "$OUTPUT_ROOT"
