#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
APP="$PWD/dist/Frontdrop.app"
ICONSET="$PWD/packaging/Frontdrop.iconset"
swift scripts/make-icon.swift "$ICONSET"
iconutil -c icns "$ICONSET" -o packaging/Frontdrop.icns
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
SDK_PATH="${FRONTDROP_SDK_PATH:-$(xcrun --show-sdk-path)}"
# The preview 27 SDK needs SwiftUI macro plugins absent from CommandLineTools.
if [[ "$(xcrun --show-sdk-version)" == 27* ]] && [ -z "${FRONTDROP_SDK_PATH:-}" ] && [ -d /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk ]; then
    SDK_PATH=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk
fi
swiftc -sdk "$SDK_PATH" -O -whole-module-optimization -parse-as-library -swift-version 5 -target "$(uname -m)-apple-macos14.0" Sources/Frontdrop/*.swift -o "$APP/Contents/MacOS/Frontdrop"
cp Sources/Frontdrop/Resources/* "$APP/Contents/Resources/"
if [ -f docs/Evidence.md ]; then
    cp docs/Evidence.md docs/Artwork.md "$APP/Contents/Resources/"
    mkdir -p "$APP/Contents/Resources/evidence"
    cp docs/evidence/backdrop-rea.json docs/evidence/renderer-rea.json docs/evidence/backdrop-ui-rea.json docs/evidence/rea-server.json docs/evidence/resource-observations.json docs/evidence/backdrop-ui.png "$APP/Contents/Resources/evidence/"
fi
if [ -f packaging/Frontdrop.icns ]; then cp packaging/Frontdrop.icns "$APP/Contents/Resources/"; fi
cp packaging/Info.plist "$APP/Contents/Info.plist"
codesign --force --deep --sign - "$APP"
printf 'Built %s\n' "$APP"
