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

    /// The source tree first, then a bundled copy. Same reason as
    /// `dataDirectory` and the oracle: Xcode Cloud's test phase does not carry
    /// the checkout, so a guard that reads source text has to be given the
    /// source text.
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

    // MARK: - The vocabulary itself

    /// `Copy.swift`'s string literals, with the interpolations resolved.
    ///
    /// The scanner sees `"The \(container) is empty."` as
    /// `The (container) is empty.`, because it treats a backslash as an escape
    /// and keeps what follows. Rather than asserting that mangled form, the
    /// interpolations are substituted back, so the expectations below can be
    /// the web's actual strings and a reader can compare them by eye.
    static let vocabularyLiterals: [String] = {
        let source = sources.first { $0.name == "Copy.swift" }?.text ?? ""
        return stringLiterals(in: source).map {
            $0.replacingOccurrences(of: "(container)", with: "basket")
              .replacingOccurrences(of: "(containerCapitalized)", with: "Basket")
        }
    }()

    /// The container noun exists at all, which is the thing that was missing.
    ///
    /// Four strings drifted into placeholder-generic and the common thread was
    /// a noun that had never been ported. This asserts the noun and, below,
    /// that the strings are built from it rather than spelling it out, so
    /// changing basket to crate stays a one-line change.
    @Test("the container noun is defined once and the strings are built from it")
    func containerNoun() throws {
        let copy = try #require(Self.sources.first { $0.name == "Copy.swift" })
        #expect(Self.stringLiterals(in: copy.text).contains("basket"))
        // Spelled out rather than interpolated would still render correctly and
        // would silently break the one-line swap, so it is worth its own check.
        for literal in Self.stringLiterals(in: copy.text) where literal != "basket" {
            #expect(
                !literal.lowercased().contains("basket"),
                "a string spells out the container noun instead of interpolating it: \(literal)"
            )
        }
    }

    /// The cute values, against the web's `themeCopy.ts`.
    ///
    /// Ported from `themeCopy.test.ts`, which asserts the same strings for the
    /// same reason. Four of these were placeholder-generic until the vocabulary
    /// module landed, and a value test is the only thing that stops them
    /// drifting back: nothing about "Found words will collect here." is
    /// detectably wrong to a machine.
    @Test("every skinned string carries its cute value", arguments: [
        // The four that were generic.
        "Pick the peaches",
        "No words picked yet. The basket is empty.",
        "Back to the basket",
        "Basket full",
        // The one that was outright letterpress, from themeCopy.test.ts:136.
        "Every common word these letters can grow, picked.",
        // The one that was missing entirely.
        "Picking the peaches.",
        // The ones that were already right, so the guard is not only a
        // regression list. An absence test passes on an app with no strings.
        "Pick word",
        "Pick letters to make a word",
        "The peach every word grew from",
        "You found the Peach of a Word!",
        "Peachy Keen Supreme",
    ])
    func cuteValue(phrase: String) {
        #expect(
            Self.vocabularyLiterals.contains(phrase),
            "missing from Copy.swift: \(phrase)"
        )
    }

    /// The retired placeholders, which must not come back anywhere.
    ///
    /// Separate from the value test above because a value can be present while
    /// a stale duplicate still renders somewhere else. This is the check that a
    /// half-finished revert would fail.
    @Test("no retired placeholder string survives", arguments: [
        "A game about finding words in words",
        "Found words will collect here.",
        "Every common word the rack can spell, found.",
    ])
    func retiredPlaceholder(phrase: String) {
        let offenders = Self.sources.filter {
            Self.stringLiterals(in: $0.text).contains { $0.contains(phrase) }
        }.map(\.name)
        #expect(offenders == [], "retired placeholder still in use: \(phrase)")
    }

    /// The skinned strings live in `Copy.swift` and nowhere else.
    ///
    /// This is the closest thing to the web's "vocabulary lives only in the
    /// copy module" rule that is enforceable here, and it is what would have
    /// caught the original four: a themed string spelled out in a view is a
    /// string nobody compares against the theme.
    ///
    /// It cannot catch a *new* generic string, and no test can. "Found words
    /// will collect here." is grammatical, on topic, and wrong only by
    /// comparison with a file in another repository. That judgement is human,
    /// and pretending otherwise would be a check that looks like coverage
    /// without being any.
    @Test("no view duplicates a string the vocabulary already owns")
    func noDuplicatedVocabulary() {
        let owned = Set(Self.vocabularyLiterals.filter { $0.count > 8 })
        let offenders = Self.sources
            .filter { $0.name != "Copy.swift" }
            .flatMap { source in
                Self.stringLiterals(in: source.text)
                    .filter { owned.contains($0) }
                    .map { "\(source.name): \"\($0)\"" }
            }
        #expect(offenders == [], "spelled out in a view instead of read from Vocabulary")
    }
}
