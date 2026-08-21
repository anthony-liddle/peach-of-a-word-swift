import Foundation
import Testing
@testable import PeachEngine

/// `.italic()` renders upright in this app, so calling it is worse than not.
///
/// Both bundled families are variable fonts with no italic instance. Fredoka
/// ships six weights, Nunito ships eight, and `CTFontGetSymbolicTraits` reports
/// no italic trait on any of them. SwiftUI does not synthesise one: a custom
/// font with no italic face simply has no italic to select, so `.italic()` is a
/// no-op that leaves the glyphs upright.
///
/// **The cost is not the missing slant, it is the lie in the source.** Three
/// call sites carried `.italic()` and rendered upright, one of them the compose
/// well's placeholder, which appears in every screenshot of this app. Anyone
/// reading those files believed the styling was applied. A no-op that reads as
/// intent survives review indefinitely, because the diff always looks right.
///
/// `CuteFont.displayOblique` and `CuteFont.bodyOblique` are the working
/// version: the upright sheared by hand through CoreText, which is what a
/// browser does to fake an italic anyway.
///
/// This scans source text for the same reason `AppVocabularyTests` does. `App/`
/// belongs to the Xcode target rather than to this package, so there is nothing
/// to import and no way to ask a rendered view what its glyphs did.
@Suite("italic selects nothing")
struct ItalicSelectsNothingTests {

    private static let appDirectory: URL = {
        let fromSource = repositoryRoot.appendingPathComponent("App")
        if FileManager.default.fileExists(atPath: fromSource.path) { return fromSource }
        for bundle in Bundle.allBundles {
            guard let resources = bundle.resourceURL else { continue }
            let candidate = resources.appendingPathComponent("App")
            if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
        }
        return fromSource
    }()

    private static let sources: [(name: String, text: String)] = {
        let names = (try? FileManager.default.contentsOfDirectory(
            atPath: appDirectory.path
        )) ?? []
        return names.filter { $0.hasSuffix(".swift") }.sorted().compactMap { name in
            guard let text = try? String(
                contentsOf: appDirectory.appendingPathComponent(name),
                encoding: .utf8
            ) else { return nil }
            return (name, text)
        }
    }()

    /// Code only, with line comments removed.
    ///
    /// The comments have to go, and not as tidying: the fix for this defect is
    /// a comment at each site saying "obliqued, not `.italic()`", so a scanner
    /// that read raw text would be failed by its own explanation. Quote state is
    /// tracked so a `//` inside a string literal is not mistaken for a comment.
    static func code(in source: String) -> String {
        var out = ""
        for line in source.split(separator: "\n", omittingEmptySubsequences: false) {
            var inString = false
            var previous: Character?
            var kept = ""
            var index = line.startIndex
            while index < line.endIndex {
                let character = line[index]
                if character == "\"" && previous != "\\" { inString.toggle() }
                if !inString, character == "/", previous == "/" {
                    kept.removeLast()
                    break
                }
                kept.append(character)
                previous = character
                index = line.index(after: index)
            }
            out += kept + "\n"
        }
        return out
    }

    @Test("no view calls italic, which would render upright")
    func noItalicCalls() {
        let offenders = Self.sources
            .filter { Self.code(in: $0.text).contains(".italic()") }
            .map(\.name)
        #expect(offenders == [], "these render upright; use CuteFont.bodyOblique")
    }

    /// Guards the test above against passing on zero files, and against a
    /// comment stripper so eager it deletes the code it is meant to read.
    @Test("scanned real code, so an empty result means something")
    func scannedRealCode() {
        #expect(Self.sources.count > 5)
        let stripped = Self.sources.map { Self.code(in: $0.text) }.joined()
        #expect(stripped.contains("CuteFont.bodyOblique"))
        #expect(stripped.contains("struct Colophon"))
        // The doc comments naming `.italic()` are exactly what a raw-text scan
        // would trip on, so prove they were stripped rather than assumed absent.
        #expect(Self.sources.contains { $0.text.contains(".italic()") })
        #expect(!stripped.contains(".italic()"))
    }
}
