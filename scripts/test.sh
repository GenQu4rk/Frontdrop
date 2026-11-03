#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build
swiftc Sources/Frontdrop/Models.swift Tests/FrontdropTests/PolicyTests.swift -o .build/policy-tests
.build/policy-tests

swiftc Sources/Frontdrop/CataloguePolicy.swift Tests/FrontdropTests/CatalogueTests.swift -o .build/catalogue-tests
.build/catalogue-tests

swiftc Sources/Frontdrop/WindowPresenceController.swift Tests/FrontdropTests/WindowPresenceTests.swift -o .build/window-presence-tests
.build/window-presence-tests

swiftc -parse-as-library Sources/Frontdrop/CatalogueAdBlocker.swift Tests/FrontdropTests/AdBlockerTests.swift -o .build/adblock-tests
.build/adblock-tests

swiftc Sources/Frontdrop/WorkshopVideoProject.swift Tests/FrontdropTests/WorkshopVideoTests.swift -o .build/workshop-tests
.build/workshop-tests

swiftc Sources/Frontdrop/VideoArchive.swift Tests/FrontdropTests/VideoArchiveTests.swift -o .build/archive-tests
.build/archive-tests

swiftc Sources/Frontdrop/LibraryStorage.swift Tests/FrontdropTests/LibraryStorageTests.swift -o .build/storage-tests
.build/storage-tests

swiftc Sources/Frontdrop/UpdateChecker.swift Tests/FrontdropTests/UpdateCheckerTests.swift -o .build/update-checker-tests
.build/update-checker-tests
