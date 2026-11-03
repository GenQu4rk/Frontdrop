#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [ "$#" -ne 1 ]; then printf 'Usage: %s path/to/a/short-test-video.mp4\n' "$0"; exit 2; fi
mkdir -p .build
SDK_PATH="${FRONTDROP_SDK_PATH:-$(xcrun --show-sdk-path)}"
if [[ "$(xcrun --show-sdk-version)" == 27* ]] && [ -z "${FRONTDROP_SDK_PATH:-}" ] && [ -d /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk ]; then SDK_PATH=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk; fi
swiftc -sdk "$SDK_PATH" -swift-version 5 -parse-as-library Sources/Frontdrop/Models.swift Sources/Frontdrop/LibraryStore.swift Sources/Frontdrop/LibraryStorage.swift Sources/Frontdrop/WorkshopVideoProject.swift Sources/Frontdrop/DesktopEngine.swift Sources/Frontdrop/SceneRenderer.swift Tests/FrontdropTests/IntegrationTests.swift -o .build/integration-tests
.build/integration-tests "$1"

# Exercise the stable preview host with real Metal resources and video playback.
PREVIEW_APP="$PWD/.build/preview-tests.app"
mkdir -p "$PREVIEW_APP/Contents/MacOS"
ln -sfn "$PWD/Sources/Frontdrop/Resources" "$PREVIEW_APP/Contents/Resources"
swiftc -sdk "$SDK_PATH" -swift-version 5 -parse-as-library Sources/Frontdrop/Models.swift Sources/Frontdrop/SceneRenderer.swift Tests/FrontdropTests/PreviewTests.swift -o "$PREVIEW_APP/Contents/MacOS/preview-tests"
"$PREVIEW_APP/Contents/MacOS/preview-tests" "$1"
