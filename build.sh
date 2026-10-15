#!/bin/bash
# Builds NoWiFi.app with the Command Line Tools (no Xcode project needed).
#   ./build.sh            build into build/NoWiFi.app
#   ./build.sh install    also copy it to ~/Applications
set -euo pipefail
cd "$(dirname "$0")"

APP=build/NoWiFi.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

xcrun swiftc -O -parse-as-library \
  -target arm64-apple-macos14.0 \
  -sdk "$(xcrun --show-sdk-path)" \
  Sources/*.swift \
  -o "$APP/Contents/MacOS/NoWiFi"

cp Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - --identifier app.nowifi.menubar "$APP"
echo "Built $APP"

if [[ "${1:-}" == "install" ]]; then
  mkdir -p ~/Applications
  rm -rf ~/Applications/No\ Wi-Fi.app
  cp -R "$APP" ~/Applications/No\ Wi-Fi.app
  echo "Installed ~/Applications/No Wi-Fi.app"
fi
