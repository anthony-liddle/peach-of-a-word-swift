import Foundation
import Testing
@testable import PeachEngine

/// The theme vocabulary guard, ported from the web's
/// `src/ui/themeCopy.test.ts` "the vocabulary lives only in the copy module".
///
/// The web has two themes and concentrates every skinned string in
/// `themeCopy.ts`, so its guard asserts that no skinned literal is spelled out
/// in a component. This app ships only the cute theme, so the rule collapses
/// into something simpler and stricter: **letterpress vocabulary may not appear
/// anywhere at all.**
///
/// It reads the app's source text rather than importing it. `App/` belongs to
/// the Xcode target, not to this SwiftPM package, so there is nothing to import
/// and no way to call a view and read back its label. That is a real limitation
/// and it is the reason this file scans strings instead of asserting on values.
/// The web's version has the same shape for a different reason: a literal
/// spelled out in a component renders identically under both themes, so no
/// per-theme test can catch it and only reading the source can.
///
/// Written after the third instance of the same defect. The reveal kicker and
/// the loading line were caught in the web repo; the completion line shipped
/// here, saying "the rack can spell, found" inside the peach celebration.
@Suite("theme vocabulary")
struct AppVocabularyTests {

    // MARK: - Reading the app's sources

    private static let appDirectory = repositoryRoot.appendingPathComponent("App")

    /// Every `App/*.swift` file, as (name, text).
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

    /// The string literals in a Swift source, with comments excluded.
    ///
    /// The web can scan raw file text because its comments happen not to
    /// contain the guarded phrases. This app's do: `FoundWords.swift` explains
    /// a colour by naming the web's `"in the set"` heart, and `Feel.swift`
    /// describes the haptic ladder in terms of the source word. Those are
    /// commentary about the port and must not be flagged, so this walks the
    /// characters and keeps only what is actually inside quotes.
    ///
    /// Handles line comments and both string forms. There are no block comments
    /// in `App/`, and a `/*` appearing later would be scanned as code rather
    /// than skipped, which fails towards a false positive rather than a silent
    /// pass.
    static func stringLiterals(in source: String) -> [String] {
        var literals: [String] = []
        var current = ""
        var inString = false, inMultiline = false, inComment = false, escaped = false
        let chars = Array(source)
        var i = 0

        while i < chars.count {
            let c = chars[i]

            if inComment {
                if c == "\n" { inComment = false }
                i += 1
                continue
            }
            if inString {
                if escaped { escaped = false; current.append(c); i += 1; continue }
                if c == "\\" { escaped = true; i += 1; continue }
                let closes = inMultiline
                    ? (c == "\"" && i + 2 < chars.count
                        && chars[i + 1] == "\"" && chars[i + 2] == "\"")
                    : (c == "\"")
                if closes {
                    literals.append(current)
                    current = ""
                    inString = false
                    i += inMultiline ? 3 : 1
                    inMultiline = false
                    continue
                }
                current.append(c)
                i += 1
                continue
            }
            if c == "/" && i + 1 < chars.count && chars[i + 1] == "/" {
                inComment = true
                i += 2
                continue
            }
            if c == "\"" {
                inString = true
                inMultiline = i + 2 < chars.count
                    && chars[i + 1] == "\"" && chars[i + 2] == "\""
                i += inMultiline ? 3 : 1
                continue
            }
            i += 1
        }
        return literals
    }

    // MARK: - The guard

    /// Letterpress vocabulary, from `themeCopy.ts`.
    ///
    /// The distinctive half of each pair only. Short shared words ("Set",
    /// "Wild") are omitted for the same reason the web omits them: they turn up
    /// in identifiers and would only add noise. Substrings rather than whole
    /// strings, so a reworded sentence around the same metaphor still trips.
    static let letterpressPhrases = [
        "Set the type",
        "Setting the type",
        "Set word",
        "Set letters to make a word",
        "No words set yet",
        "The case is full",
        "The glossary",
        "Back to the case",
        "in the set.",
        "The full set is the peak",
        "Set in Fraunces",
        "can spell, found",
        "the type was cut for",
        "The Complete Works",
        // The printer's fleuron. A glyph rather than a sentence, but the same
        // rule, and the ornament this app draws is a peach.
        "\u{2767}",
    ] + [
        // The six letterpress rank names. The cute ladder is First Sprout,
        // Little Bud, Blossom, Ripening, Sweet, Perfectly Peachy.
        "Blank Page", "First Impression", "Galley Proof",
        "Press Run", "Bound Edition", "Fine Press",
    ]

    @Test("no letterpress vocabulary reaches a user-facing string")
    func noLetterpressLeaks() {
        let offenders = Self.sources.flatMap { source in
            Self.stringLiterals(in: source.text)
                .flatMap { literal in
                    Self.letterpressPhrases
                        .filter { literal.contains($0) }
                        .map { "\(source.name): \"\($0)\"" }
                }
        }
        #expect(offenders == [], "letterpress vocabulary in the peach theme")
    }

    /// Guards the test above against a bad path quietly passing on zero files,
    /// which is the failure mode that makes a source-scanning test worthless.
    /// The web's version does the same and names `Game.tsx`.
    @Test("scanned the real sources, so an empty result means something")
    func scannedRealSources() {
        #expect(Self.sources.count > 5)
        #expect(Self.sources.map(\.name).contains("CompletionCard.swift"))
        #expect(Self.sources.map(\.name).contains("ContentView.swift"))
        // And the scanner returns literals rather than an empty list, which
        // would make every `contains` check above vacuously pass.
        let all = Self.sources.flatMap { Self.stringLiterals(in: $0.text) }
        #expect(all.count > 50)
    }

    @Test("the scanner reads quotes and ignores commentary")
    func scannerIgnoresComments() {
        let sample = """
            // "Set the type" named in a comment
            let a = "kept"  // "Back to the case" trailing
            let b = "esc \\" still one literal"
            """
        let found = Self.stringLiterals(in: sample)
        #expect(found.contains("kept"))
        #expect(!found.contains("Set the type"))
        #expect(!found.contains("Back to the case"))
        #expect(found.contains(#"esc " still one literal"#))
    }

    // MARK: - The strings this app does skin

    /// Ported from `themeCopy.test.ts:136`, which asserts the cute completion
    /// line. Asserted against the source text for the reason given at the top
    /// of this file: there is no way to import an `App/` view from here.
    @Test("the completion card carries the cute line, not the letterpress one")
    func completionLineIsSkinned() throws {
        let card = try #require(
            Self.sources.first { $0.name == "CompletionCard.swift" }
        )
        let literals = Self.stringLiterals(in: card.text)
        #expect(literals.contains("Every common word these letters can grow, picked."))
    }

    /// The rest of the cute vocabulary this app actually uses, so the guard is
    /// not only an absence check. An absence test passes on an app with no
    /// strings in it at all.
    @Test("the cute vocabulary the app does carry is present", arguments: [
        ("SourceRevealCard.swift", "The peach every word grew from"),
        ("ContentView.swift", "Pick letters to make a word"),
        ("ContentView.swift", "Pick word"),
    ])
    func cuteVocabularyPresent(file: String, phrase: String) throws {
        let source = try #require(Self.sources.first { $0.name == file })
        #expect(Self.stringLiterals(in: source.text).contains { $0.contains(phrase) })
    }
}
