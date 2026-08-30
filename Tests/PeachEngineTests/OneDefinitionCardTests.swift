import Foundation
import Testing
@testable import PeachEngine

/// Two paths open a definition. There must be exactly one card.
///
/// A found-list chip opens a definition, and so does a word inside a rung
/// sheet. The interesting failure is not that either is broken today: it is
/// that nothing would stop them diverging tomorrow. Two call sites building the
/// same card agree on the day they are written, and then one of them gains a
/// detent, or a parameter, or a different lookup for the gloss, and the two
/// paths quietly answer the same question differently.
///
/// This is the moment that divergence would be created, so this is the moment
/// to make it impossible. `DefinitionSheet` is the single construction, both
/// paths call it, and this asserts that the app builds a `DefinitionCard`
/// exactly once.
///
/// **Structural rather than behavioural, deliberately.** A test that presented
/// both paths and compared what appeared would be comparing two renderings and
/// could pass while the inputs differed. Counting the construction sites says
/// the stronger thing: there is only one place where the card and its detents
/// are decided, so there is nothing to keep in agreement.
@Suite("one definition card, two paths to it")
struct OneDefinitionCardTests {

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
                contentsOf: appDirectory.appendingPathComponent(name), encoding: .utf8
            ) else { return nil }
            return (name, text)
        }
    }()

    /// Construction sites, ignoring the declaration and anything in a comment.
    private static func constructions(of type: String) -> [String] {
        sources.flatMap { source -> [String] in
            source.text.split(separator: "\n").compactMap { rawLine in
                let line = rawLine.trimmingCharacters(in: .whitespaces)
                guard line.contains("\(type)(") else { return nil }
                // The declaration itself, and prose about it, are not calls.
                if line.hasPrefix("//") || line.hasPrefix("///") { return nil }
                if line.contains("struct \(type)") { return nil }
                return "\(source.name): \(line)"
            }
        }
    }

    /// No file but the card's own may build one.
    ///
    /// Stated as "nowhere else" rather than "exactly once", because
    /// `DefinitionCard.swift` legitimately builds several: `DefinitionSheet`
    /// makes the real one and the previews make throwaways. Previews are not
    /// paths a player can take, so counting them told me four and meant
    /// nothing. What matters is that every path outside that file goes through
    /// `DefinitionSheet`.
    @Test("no view outside the card's own file builds a DefinitionCard")
    func nothingElseConstructsIt() {
        let elsewhere = Self.constructions(of: "DefinitionCard")
            .filter { !$0.hasPrefix("DefinitionCard.swift:") }
        #expect(elsewhere == [],
                "these should present DefinitionSheet instead: \(elsewhere)")
    }

    @Test("the shared sheet is the thing that builds it")
    func theSheetBuildsIt() {
        guard let card = Self.sources.first(where: { $0.name == "DefinitionCard.swift" })
        else { Issue.record("DefinitionCard.swift not found"); return }
        guard let sheet = card.text.range(of: "struct DefinitionSheet"),
              let next = card.text.range(of: "struct DefinitionCard")
        else { Issue.record("DefinitionSheet not found"); return }
        #expect(card.text[sheet.lowerBound..<next.lowerBound].contains("DefinitionCard("),
                "DefinitionSheet should be what constructs the card")
    }

    /// The other half: both paths actually go through it.
    ///
    /// Without this, the test above would still pass if a path stopped opening
    /// a definition at all, which is the way it would break for Bea rather than
    /// for a reviewer.
    @Test("both the found list and the rung sheet reach it")
    func bothPathsPresentIt() {
        let sites = Self.constructions(of: "DefinitionSheet")
        let files = Set(sites.map { $0.split(separator: ":")[0] })
        #expect(files.contains("ContentView.swift"),
                "the found-list chip path should present DefinitionSheet")
        #expect(files.contains("RungSheet.swift"),
                "the rung-sheet word path should present DefinitionSheet")
    }

    /// No view writes its own way-out label.
    ///
    /// The dismiss labels are themed strings and belong in `Copy.swift`. The
    /// failure this watches for is not a view using the wrong one: it is a view
    /// building the right one itself, which is how a themed string escapes the
    /// module that owns it.
    ///
    /// **`AppVocabularyTests` cannot see that, and this is why.** Its guard
    /// compares string literals, so `"Back to the \(Vocabulary.container)"`
    /// never matches the literal `"Back to the basket"` and passes. `RungSheet`
    /// carried exactly that duplicate until the card was made context aware.
    /// Matching on the opening words catches the assembled form too, because
    /// the prefix is a literal whatever follows it.
    @Test("only Copy.swift writes a way-out label")
    func labelsLiveInCopy() {
        let offenders = Self.sources.filter { $0.name != "Copy.swift" }
            .flatMap { source -> [String] in
                source.text.split(separator: "\n").compactMap { rawLine in
                    let line = rawLine.trimmingCharacters(in: .whitespaces)
                    guard line.contains("\"Back to") else { return nil }
                    if line.hasPrefix("//") || line.hasPrefix("///") { return nil }
                    return "\(source.name): \(line)"
                }
            }
        #expect(offenders == [],
                "these should read a label from Vocabulary: \(offenders)")
    }

    /// The two destinations differ, and neither is generic.
    ///
    /// A bare "Back" would be the obvious fix and it is system language in a
    /// game that does not speak it, so the rung form names the rung.
    @Test("the rung label names the rung and is not the basket's")
    func rungLabelIsItsOwn() {
        guard let copy = Self.sources.first(where: { $0.name == "Copy.swift" })
        else { Issue.record("Copy.swift not found"); return }
        #expect(copy.text.contains("closeToRung"))
        #expect(copy.text.contains("\"Back to \\(name)\""),
                "the rung label should name the rung")
        // The generic form, which was rejected on purpose. Checked on code
        // lines only: the first version matched the prose in `closeToRung`'s
        // own doc comment, which explains why a bare Back was rejected, so the
        // guard failed on the sentence describing the thing it forbids.
        let code = copy.text.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.hasPrefix("//") }
            .joined(separator: "\n")
        #expect(!code.contains("\"Back\""), "a bare Back is system language")
    }

    /// The detents belong to the shared sheet too.
    ///
    /// A card that opened at a different height depending on how it was reached
    /// would be the same divergence in a quieter form, and it is the one that
    /// would not look like a bug in a diff.
    @Test("neither path sets its own detents on the card")
    func detentsAreShared() {
        for name in ["ContentView.swift", "RungSheet.swift"] {
            guard let source = Self.sources.first(where: { $0.name == name }) else {
                Issue.record("\(name) not found"); continue
            }
            let lines = source.text.split(separator: "\n").map(String.init)
            for (index, line) in lines.enumerated() where line.contains("DefinitionSheet(") {
                // The modifiers that follow a construction, up to the next
                // case or closing brace, must not include a detent of its own.
                let following = lines[index..<min(index + 8, lines.count)].joined(separator: " ")
                #expect(!following.contains(".presentationDetents"),
                        "\(name) sets its own detents on a DefinitionSheet")
            }
        }
    }
}
