// swift-tools-version: 6.0
import PackageDescription

// The package can be built with SwiftPM. The scripts in `Scripts/` (driven by the `Makefile`)
// build the exact same sources by calling `swiftc` directly — handy on toolchains where
// `swift build` misbehaves. Tests are a normal executable (no XCTest dependency) so they run
// anywhere: `swift run SiteBlockerTests` or `make test`.
let package = Package(
    name: "SiteBlocker",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "SiteBlockerCore", targets: ["SiteBlockerCore"]),
        .executable(name: "site-blocker-helper", targets: ["site-blocker-helper"]),
        .executable(name: "SiteBlocker", targets: ["SiteBlockerApp"]),
        .executable(name: "SiteBlockerTests", targets: ["SiteBlockerTests"]),
    ],
    targets: [
        .target(name: "SiteBlockerCore"),
        .executableTarget(name: "site-blocker-helper", dependencies: ["SiteBlockerCore"]),
        .executableTarget(name: "SiteBlockerApp", dependencies: ["SiteBlockerCore"]),
        .executableTarget(name: "SiteBlockerTests", dependencies: ["SiteBlockerCore"]),
    ],
    // Build in Swift 5 language mode (what `swiftc` uses by default, and what the project is
    // written against). This keeps `swift build`/`swift run` consistent with the `Scripts/`.
    swiftLanguageModes: [.v5]
)
