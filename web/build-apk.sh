#!/usr/bin/env bash
# HEARTHKEEP — wrap the PWA into a Capacitor Android APK.
# Run from the web/ directory.
set -euo pipefail

export JAVA_HOME=${JAVA_HOME:-/opt/homebrew/opt/openjdk@17}
export ANDROID_HOME=${ANDROID_HOME:-/opt/homebrew/share/android-commandlinetools}
export ANDROID_SDK_ROOT=${ANDROID_SDK_ROOT:-$ANDROID_HOME}
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"

cd "$(dirname "$0")"

echo "[apk] node $(node --version)   java $(java -version 2>&1 | head -1 | awk '{print $3}' | tr -d '"')"
echo "[apk] ANDROID_HOME=$ANDROID_HOME"

if [ ! -d node_modules ]; then
  echo "[apk] npm install"
  npm install --no-audit --no-fund --silent
fi

# Stage the web assets in dist/ so Capacitor's webDir resolves.
rm -rf dist
mkdir -p dist/src
cp index.html manifest.webmanifest icon-192.png icon-512.png sw.js dist/ 2>/dev/null || true
cp -R src/* dist/src/

# Defensive: Godot's --import step sometimes drops .import sidecar
# files inside web/android — gradle treats them as resource errors.
if [ -d android ]; then
  find android -name "*.import" -delete 2>/dev/null || true
fi

if [ ! -d android ]; then
  echo "[apk] cap add android"
  npx --yes cap add android
fi

echo "[apk] cap sync"
npx --yes cap sync android

# Re-scrub: cap sync may copy fresh .import sidecars in.
find android -name "*.import" -delete 2>/dev/null || true

cd android
echo "[apk] gradle assembleDebug"
./gradlew assembleDebug --no-daemon -q

cd ..
APK="android/app/build/outputs/apk/debug/app-debug.apk"
if [ ! -f "$APK" ]; then
  echo "[apk] ERROR — APK not produced at $APK"
  exit 1
fi

cp "$APK" "Hearthkeep-web-debug.apk"
echo "[apk] OK: web/Hearthkeep-web-debug.apk"
ls -la Hearthkeep-web-debug.apk
