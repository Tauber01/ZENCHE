#!/bin/zsh
set -euo pipefail

PROJECT_ROOT=${0:A:h:h}
VERSION=0.7.0
ANDROID_ROOT="$PROJECT_ROOT/native/android"
ASSET_ROOT="$ANDROID_ROOT/app/src/main/assets/web"
DIST_ROOT="$PROJECT_ROOT/dist"

rm -rf "$ASSET_ROOT"
mkdir -p "$DIST_ROOT"

export JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home}"
export ANDROID_HOME="${ANDROID_HOME:-$PROJECT_ROOT/.toolchains/android-sdk}"
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"

if [[ ! -f "$ANDROID_HOME/platforms/android-35/android.jar" ]]; then
  yes | sdkmanager --licenses >/dev/null
  sdkmanager "platforms;android-35" "build-tools;35.0.1"
fi

cd "$ANDROID_ROOT"
if [[ ! -x ./gradlew ]]; then
  GRADLE_BIN="$PROJECT_ROOT/.toolchains/gradle-8.10.2/bin/gradle"
  if [[ ! -x "$GRADLE_BIN" ]]; then GRADLE_BIN=$(command -v gradle); fi
  "$GRADLE_BIN" wrapper \
    --gradle-version 8.10.2 \
    --gradle-distribution-url "https://mirrors.cloud.tencent.com/gradle/gradle-8.10.2-bin.zip"
fi
if [[ -x "$PROJECT_ROOT/.toolchains/gradle-8.10.2/bin/gradle" ]]; then
  "$PROJECT_ROOT/.toolchains/gradle-8.10.2/bin/gradle" --no-daemon clean assembleDebug
elif command -v gradle >/dev/null; then
  gradle --no-daemon clean assembleDebug
else
  ./gradlew --no-daemon clean assembleDebug
fi

APK_SOURCE="$ANDROID_ROOT/app/build/outputs/apk/debug/app-debug.apk"
APK_TARGET="$DIST_ROOT/NikonLink-$VERSION-android.apk"
cp "$APK_SOURCE" "$APK_TARGET"
shasum -a 256 "$APK_TARGET" > "$APK_TARGET.sha256"
echo "$APK_TARGET"
