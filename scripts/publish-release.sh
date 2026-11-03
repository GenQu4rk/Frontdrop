#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

REPOSITORY="GenQu4rk/Frontdrop"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' packaging/Info.plist)"
TAG="v$VERSION"
NOTES="docs/releases/$TAG.md"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    printf 'Invalid app version: %s\n' "$VERSION" >&2; exit 1
fi
if [ "$(git branch --show-current)" != "main" ] || [ -n "$(git status --porcelain)" ]; then
    printf 'Publish from a clean, committed main branch.\n' >&2; exit 1
fi
if [ "$(git remote get-url origin)" != "https://github.com/$REPOSITORY.git" ] && [ "$(git remote get-url origin)" != "git@github.com:$REPOSITORY.git" ]; then
    printf 'The origin remote must be %s.\n' "$REPOSITORY" >&2; exit 1
fi
if [ "$(gh api user --jq .login)" != "GenQu4rk" ]; then
    printf 'Sign in to GitHub CLI as GenQu4rk before publishing.\n' >&2; exit 1
fi
if [ ! -f "$NOTES" ]; then
    printf 'Release notes missing: %s\n' "$NOTES" >&2; exit 1
fi
if gh release view "$TAG" --repo "$REPOSITORY" >/dev/null 2>&1; then
    printf 'Release %s already exists. Increment the app version.\n' "$TAG" >&2; exit 1
fi
git fetch origin main
if ! git merge-base --is-ancestor origin/main HEAD; then
    printf 'The local branch does not contain origin/main. Resolve this before publishing.\n' >&2; exit 1
fi

./scripts/test.sh
./scripts/package-dmg.sh
ARCH="$(lipo -archs dist/Frontdrop.app/Contents/MacOS/Frontdrop)"
case "$ARCH" in
    arm64|x86_64) ;;
    "arm64 x86_64"|"x86_64 arm64") ARCH="universal" ;;
    *) printf 'Unsupported app architecture: %s\n' "$ARCH" >&2; exit 1 ;;
esac
DMG="dist/Frontdrop-$VERSION-$ARCH.dmg"
CHECKSUM="$DMG.sha256"
if [ ! -f "$DMG" ] || [ ! -f "$CHECKSUM" ]; then
    printf 'Release package is incomplete.\n' >&2; exit 1
fi
(
    cd dist
    shasum -a 256 -c "$(basename "$CHECKSUM")"
)
git push origin main
gh release create "$TAG" "$DMG" "$CHECKSUM" \
    --repo "$REPOSITORY" --target "$(git rev-parse HEAD)" \
    --title "Frontdrop $VERSION" --notes-file "$NOTES" --latest
gh release view "$TAG" --repo "$REPOSITORY" --json url --jq .url
