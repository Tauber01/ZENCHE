#!/bin/zsh
set -euo pipefail

PROJECT_ROOT=${0:A:h:h}
HARMONY_ROOT="$PROJECT_ROOT/native/harmony"
DIST_DIR="$PROJECT_ROOT/dist"
VERSION=0.7.3

if [[ -n "${NIKONLINK_HVIGORW:-}" ]]; then
  HVIGOR_COMMAND=("$NIKONLINK_HVIGORW")
elif [[ -x "$HARMONY_ROOT/hvigorw" ]]; then
  HVIGOR_COMMAND=("$HARMONY_ROOT/hvigorw")
elif command -v hvigorw >/dev/null 2>&1; then
  HVIGOR_COMMAND=("$(command -v hvigorw)")
elif command -v hvigor >/dev/null 2>&1; then
  HVIGOR_COMMAND=("$(command -v hvigor)")
else
  echo "未检测到 DevEco Studio 的 hvigorw/hvigor。"
  echo "请在 DevEco Studio 中先同步 native/harmony，或设置 NIKONLINK_HVIGORW。"
  exit 1
fi

cd "$HARMONY_ROOT"
"${HVIGOR_COMMAND[@]}" \
  --mode module \
  -p product=default \
  -p module=entry@default \
  -p buildMode=release \
  assembleHap \
  --no-daemon

HAP_PATH=$(
  find "$HARMONY_ROOT/entry/build" -type f -name '*.hap' -print |
    sort |
    tail -n 1
)
if [[ -z "$HAP_PATH" ]]; then
  echo "构建完成，但没有在 entry/build 中找到 HAP。"
  exit 1
fi

mkdir -p "$DIST_DIR"
OUTPUT="$DIST_DIR/NikonLink-${VERSION}-HarmonyOS.hap"
cp "$HAP_PATH" "$OUTPUT"
shasum -a 256 "$OUTPUT" |
  awk '{print $1 "  NikonLink-0.7.3-HarmonyOS.hap"}' \
  > "$OUTPUT.sha256"

echo "HarmonyOS package: $OUTPUT"
echo "SHA-256:           $OUTPUT.sha256"
