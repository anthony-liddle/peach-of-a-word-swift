// swift-tools-version: 6.2
import PackageDescription

// tools-version 6.2 and macOS 26 are both forced by InlineArray (Sources/
// PeachEngine/Formability.swift), which is macOS 26+. Tools-version 6.0 fails
// with "'v26' is unavailable".
let package = Package(
    name: "PeachEngine",
    platforms: [.macOS(.v26)],
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
