#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

./scripts/build.sh
APP="$PWD/dist/Frontdrop.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
ARCH="$(lipo -archs "$APP/Contents/MacOS/Frontdrop")"
case "$ARCH" in
    arm64|x86_64) ;;
    "arm64 x86_64"|"x86_64 arm64") ARCH="universal" ;;
    *) printf 'Unsupported app architecture: %s\n' "$ARCH" >&2; exit 1 ;;
esac
DMG_NAME="Frontdrop-$VERSION-$ARCH.dmg"
STAGING="$(mktemp -d "${TMPDIR:-/tmp}/frontdrop-dmg.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
mkdir "$STAGING/payload"
ditto "$APP" "$STAGING/payload/Frontdrop.app"
ln -s /Applications "$STAGING/payload/Applications"
cat > "$STAGING/payload/Install Frontdrop.txt" <<EOF
Frontdrop $VERSION
Architecture: $ARCH | Requires macOS 14 or later

1. Quit any running copy of Frontdrop before updating.
2. Drag Frontdrop.app onto the Applications folder link.
3. Eject this disk image and open Frontdrop from Applications.
4. Choose a scene and click Set Wallpaper.

Closing the library keeps your wallpaper running. Use the menu-bar icon
to reopen the library, pause playback, stop, or quit.

This community build is ad-hoc signed and is not notarized by Apple.
If macOS blocks it, review Apple's guidance before choosing to open it:
https://support.apple.com/en-gb/102445

Source, licence and release information:
https://github.com/GenQu4rk/Frontdrop
EOF
codesign --verify --deep --strict "$STAGING/payload/Frontdrop.app"
hdiutil create -volname "Frontdrop $VERSION" -srcfolder "$STAGING/payload" \
    -format UDZO -fs HFS+ "$STAGING/$DMG_NAME"
hdiutil verify "$STAGING/$DMG_NAME"
mv -f "$STAGING/$DMG_NAME" "dist/$DMG_NAME"
(
    cd dist
    shasum -a 256 "$DMG_NAME" > "$DMG_NAME.sha256"
)
printf 'Packaged %s\nChecksum %s\n' "$PWD/dist/$DMG_NAME" "$PWD/dist/$DMG_NAME.sha256"
