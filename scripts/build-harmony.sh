#!/bin/zsh
set -euo pipefail

PROJECT_ROOT=${0:A:h:h}
HARMONY_ROOT="$PROJECT_ROOT/native/harmony"
DIST_DIR="$PROJECT_ROOT/dist"
VERSION=1.5.7

if [[ -z "${DEVECO_HOME:-}" ]]; then
  for candidate in \
    "/Applications/DevEco-Studio.app/Contents" \
    "$HOME/Applications/DevEco-Studio.app/Contents" \
    "/Applications/DevEco Studio.app/Contents" \
    "$HOME/Applications/DevEco Studio.app/Contents"; do
    if [[ -d "$candidate" ]]; then
      DEVECO_HOME="$candidate"
      break
    fi
  done
fi

if [[ -n "${DEVECO_HOME:-}" && -d "$DEVECO_HOME" ]]; then
  export DEVECO_HOME
  export DEVECO_SDK_HOME="${DEVECO_SDK_HOME:-$DEVECO_HOME/sdk}"
  export HOS_SDK_HOME="${HOS_SDK_HOME:-$DEVECO_HOME/sdk/default}"
  export OHOS_SDK_HOME="${OHOS_SDK_HOME:-$DEVECO_HOME/sdk/default/openharmony}"
  export NODE_HOME="$DEVECO_HOME/tools/node"
  export JAVA_HOME="$DEVECO_HOME/jbr/Contents/Home"
fi

if [[ -n "${NIKONLINK_HVIGORW:-}" ]]; then
  HVIGOR_COMMAND=("$NIKONLINK_HVIGORW")
elif [[ -x "$HARMONY_ROOT/hvigorw" ]]; then
  HVIGOR_COMMAND=("$HARMONY_ROOT/hvigorw")
elif [[ -n "${DEVECO_HOME:-}" && -x "$DEVECO_HOME/tools/hvigor/bin/hvigorw" ]]; then
  HVIGOR_COMMAND=("$DEVECO_HOME/tools/hvigor/bin/hvigorw")
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
OUTPUT="$DIST_DIR/ZENCHE-${VERSION}-HarmonyOS.hap"
cp "$HAP_PATH" "$OUTPUT"
shasum -a 256 "$OUTPUT" |
  awk -v name="${OUTPUT:t}" '{print $1 "  " name}' \
  > "$OUTPUT.sha256"

echo "HarmonyOS package: $OUTPUT"
echo "SHA-256:           $OUTPUT.sha256"
