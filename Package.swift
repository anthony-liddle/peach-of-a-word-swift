// swift-tools-version: 6.2
import PackageDescription

// tools-version 6.2 and the 26 platform floors are both forced by InlineArray
// (Sources/PeachEngine/Formability.swift). Tools-version 6.0 fails with
// "'v26' is unavailable".
//
// The iOS floor was added so the SwiftUI app target can depend on this package.
// iOS 26 is a very high minimum for a shipping app, and it buys a 25 ms saving
// on a once-per-puzzle operation. See "The iOS 26 floor" in docs/REPORT.md:
// a real build should drop InlineArray and lower this.
let package = Package(
    name: "PeachEngine",
    platforms: [.macOS(.v26), .iOS(.v26)],
    products: [
        .library(name: "PeachEngine", targets: ["PeachEngine"]),
        .executable(name: "peach-bench", targets: ["PeachBench"]),
    ],
    targets: [
        .target(name: "PeachEngine"),
        .executableTarget(name: "PeachBench", dependencies: ["PeachEngine"]),
        .testTarget(name: "PeachEngineTests", dependencies: ["PeachEngine"]),
    ]
)
