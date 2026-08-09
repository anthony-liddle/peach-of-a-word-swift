import Foundation

/// Absolute path to the repository root, derived from this file's own location
/// at compile time.
///
/// `#filePath` is a Swift magic literal: the compiler substitutes the path of
/// the source file it appears in. TypeScript's nearest equivalent is
/// `import.meta.url`. Used so the 8MB data snapshot can live at the repo root
/// instead of being copied into every build's resource bundle.
public let repositoryRoot: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()  // Sources/PeachEngine
    .deletingLastPathComponent()  // Sources
    .deletingLastPathComponent()  // repo root

/// Directory holding the frozen data snapshot. See SNAPSHOT.md.
public let dataDirectory: URL = repositoryRoot.appendingPathComponent("Data")

/// Read a newline-delimited word list, trimming blanks.
///
/// `directory` defaults to `dataDirectory`, which is derived from `#filePath`
/// and therefore only exists on the machine that compiled the package. That is
/// fine for the tests and the benchmark, which run from the source tree.
///
/// It is NOT fine for an app. An app bundle has no repo root, so the SwiftUI
/// target passes `Bundle.main.resourceURL` instead. Note the trap: the iOS
/// Simulator shares the Mac filesystem, so the baked-in `#filePath` path still
/// resolves there and a naive app would appear to work in the simulator and
/// fail on a real device.
public func readWordList(
    _ name: String,
    in directory: URL = dataDirectory
) throws -> [String] {
    let text = try String(
        contentsOf: directory.appendingPathComponent(name),
        encoding: .utf8
    )
    return text.split(separator: "\n").compactMap {
        let word = $0.trimmingCharacters(in: .whitespaces)
        return word.isEmpty ? nil : word
    }
}
