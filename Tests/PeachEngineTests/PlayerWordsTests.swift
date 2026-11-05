import Foundation
import Testing
@testable import PeachEngine

/// No player reads an em dash or one of the words `Voice/AI Tells.md` bans.
///
/// Antoine's rewrite of every string, The Game's Own Words, took the machine
/// tells out by hand. This keeps them out. It reads what a player can read or
/// hear: every string literal in `App/` and in the engine, which is where the
/// well, the share and the cards' credits are written, and the TestFlight note,
/// which Bea and the other testers read.
///
/// The words are the vault's hard bans: "quiet", outright, and the tell-words
/// list. Matched from the start of a word, so "quiet" catches "quietly" too.
/// `AI Tells.md` excuses a few of them when they're literal ("unlock", say, of
/// a real lock). Nothing in a word game is, so here they are all banned, and a
/// literal one that turns up is a sentence to rewrite rather than an exception.
///
/// Read as source text, for the reason `AppVocabularyTests` gives: the copy is
/// in the app target, which this package can't import. Comments aren't
/// literals, so commentary about the rule can name what it bans.
@Suite("the player's words")
struct PlayerWordsTests {

    /// A directory from the source tree, or the copy bundled beside the tests.
    ///
    /// The same order as `AppVocabularyTests.appDirectory`: Xcode Cloud's test
    /// phase has no checkout, so `project.yml` copies these into the bundle.
    /// A folder reference keeps only its last name, so `Sources/PeachEngine`
    /// is bundled as `PeachEngine`, as `CostumeTests` reads it.
    private static func directory(_ path: String) -> URL? {
        let fromSource = repositoryRoot.appendingPathComponent(path)
        if FileManager.default.fileExists(atPath: fromSource.path) { return fromSource }
        let bundled = URL(fileURLWithPath: path).lastPathComponent
        for bundle in Bundle.allBundles {
            guard let resources = bundle.resourceURL else { continue }
            let candidate = resources.appendingPathComponent(bundled)
            if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
        }
        return nil
    }

    /// Every file in a directory with the given suffix, as (name, text).
    private static func files(in path: String, suffix: String) -> [(file: String, text: String)] {
        guard let dir = directory(path),
              let names = try? FileManager.default.contentsOfDirectory(atPath: dir.path)
        else { return [] }
        return names.filter { $0.hasSuffix(suffix) }.sorted().compactMap { name in
            guard let text = try? String(contentsOf: dir.appendingPathComponent(name),
                                         encoding: .utf8) else { return nil }
            return ("\(path)/\(name)", text)
        }
    }

    /// The string literals of `App/` and the engine, each with its file.
    static let literals: [(file: String, text: String)] = {
        (files(in: "App", suffix: ".swift") + files(in: "Sources/PeachEngine", suffix: ".swift"))
            .flatMap { source in
                AppVocabularyTests.stringLiterals(in: source.text).map { (source.file, $0) }
            }
    }()

    /// The testers' note, which is the whole file.
    static let testFlightNotes: [(file: String, text: String)] =
        files(in: "TestFlight", suffix: ".txt")

    /// `Voice/AI Tells.md`'s hard bans, as word starts.
    static let bannedWords = [
        "quiet", "delve", "foster", "elevate", "unlock", "tapestry", "multifaceted",
        "nuanced", "game-changer", "game changer", "revolutioni", "unprecedented",
        "empower", "landscape", "navigat", "crucial", "realm", "pivotal", "robust",
        "seamless", "cutting-edge", "cutting edge",
    ]

    /// What's wrong with one string, or nothing.
    ///
    /// The scanner keeps what follows a backslash and drops the backslash, so
    /// an em dash written as an escape arrives as `u{2014}`. Both are caught.
    static func problems(in text: String) -> [String] {
        var found: [String] = []
        if text.contains("\u{2014}") || text.lowercased().contains("u{2014}") {
            found.append("an em dash")
        }
        let lower = text.lowercased()
        for word in bannedWords {
            let pattern = "\\b" + NSRegularExpression.escapedPattern(for: word)
            if lower.range(of: pattern, options: .regularExpression) != nil {
                found.append("\"\(word)\"")
            }
        }
        return found
    }

    private static func offenders(_ strings: [(file: String, text: String)]) -> [String] {
        strings.flatMap { item in
            problems(in: item.text).map { "\(item.file): \($0) in \"\(item.text)\"" }
        }
    }

    @Test("no string in the app or the engine has an em dash or a banned word")
    func noTellsInTheCode() {
        #expect(Self.offenders(Self.literals) == [])
    }

    @Test("the TestFlight note has no em dash or banned word")
    func noTellsInTheNote() {
        #expect(!Self.testFlightNotes.isEmpty, "no TestFlight note was found to read")
        #expect(Self.offenders(Self.testFlightNotes) == [])
    }

    /// Guards the two above against passing on nothing, which is how a
    /// source-scanning test fails without anyone noticing.
    @Test("read the real strings, so an empty result means something")
    func readTheRealStrings() {
        let files = Set(Self.literals.map(\.file))
        #expect(files.contains("App/Copy.swift"))
        #expect(files.contains("Sources/PeachEngine/WellLine.swift"))
        #expect(Self.literals.count > 500)
        // A string a player reads on the board, so the scan is known to reach one.
        #expect(Self.literals.contains { $0.text.contains("You found the Peach of a Word!") })
    }

    @Test("the check catches each kind of tell")
    func catchesEachKind() {
        #expect(Self.problems(in: "A daily word game \u{2014} for Bea") == ["an em dash"])
        let escaped = AppVocabularyTests.stringLiterals(in: #"let a = "for \u{2014} Bea""#)
        #expect(escaped.flatMap(Self.problems) == ["an em dash"])
        #expect(Self.problems(in: "Quietly, the peach grows.") == ["\"quiet\""])
        #expect(Self.problems(in: "Navigating the basket") == ["\"navigat\""])
        // From the start of a word only, so a word that merely contains one passes.
        #expect(Self.problems(in: "Ripening, then Sweet").isEmpty)
    }
}
