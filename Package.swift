// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "Frontdrop",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Frontdrop", targets: ["Frontdrop"])],
    targets: [
        .executableTarget(name: "Frontdrop", resources: [.copy("Resources")])
    ],
    swiftLanguageModes: [.v5]
)
