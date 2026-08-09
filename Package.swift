// swift-tools-version: 6.0
import PackageDescription

// These floors are as low as the code allows.
//
// They were briefly macOS 26 / iOS 26, because `LetterCounts` used InlineArray,
// which is the only API in this package that required it. Dropping InlineArray
// for a plain [Int8] costs about 25 ms on a once-per-puzzle operation and buys
// back nine years of device support, which is the better trade for a game meant
// to run on one specific phone. See docs/MEASUREMENTS.md for the number and
// Sources/PeachEngine/Formability.swift for the reasoning.
//
// iOS 17 is set by the app target, not by this package: @Observable and
// ContentUnavailableView are both iOS 17. The engine alone would go lower.
// macOS 14 is the matching floor and clears ContinuousClock in PeachBench,
// which needs macOS 13.
let package = Package(
    name: "PeachEngine",
    platforms: [.macOS(.v14), .iOS(.v17)],
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
