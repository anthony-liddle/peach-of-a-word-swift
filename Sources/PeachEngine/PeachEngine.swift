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

/// Read a newline-delimited word list, trimming blanks. Used by the benchmark
/// and by any test that wants the real lists rather than a fixture.
public func readWordList(_ name: String) throws -> [String] {
    let text = try String(
        contentsOf: dataDirectory.appendingPathComponent(name),
        encoding: .utf8
    )
    return text.split(separator: "\n").compactMap {
        let word = $0.trimmingCharacters(in: .whitespaces)
        return word.isEmpty ? nil : word
    }
}
