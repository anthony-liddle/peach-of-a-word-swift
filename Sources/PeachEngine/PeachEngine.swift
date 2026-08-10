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
///
/// The source tree first, then a bundled copy.
///
/// `#filePath` bakes in the path of the machine that compiled the package, and
/// that path existing at *build* time does not mean it exists at *run* time.
/// Xcode Cloud proved it: the build phase has the checkout at
/// `/Volumes/workspace/repository`, the test phase does not, so every test
/// reading a word list failed with "no such file" against a path that had been
/// correct an hour earlier. The comment on `readWordList` already warned that an
/// app bundle has no repo root; the same is true of a test bundle running
/// somewhere else.
///
/// So this resolves at first use rather than at compile time, and falls back to
/// a `Data` directory inside any loaded bundle. Nothing changes for `swift test`
/// or the benchmark, which run from the source tree and take the first branch.
public let dataDirectory: URL = resolveDataDirectory()

private func resolveDataDirectory() -> URL {
    let fromSource = repositoryRoot.appendingPathComponent("Data")
    if FileManager.default.fileExists(atPath: fromSource.path) { return fromSource }
    for bundle in Bundle.allBundles + Bundle.allFrameworks {
        guard let resources = bundle.resourceURL else { continue }
        let candidate = resources.appendingPathComponent("Data")
        if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
    }
    // Deliberately returns the source path rather than nil. A missing snapshot
    // must fail loudly at the point of reading, naming the file it wanted,
    // rather than being silently swapped for an empty directory.
    return fromSource
}

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
