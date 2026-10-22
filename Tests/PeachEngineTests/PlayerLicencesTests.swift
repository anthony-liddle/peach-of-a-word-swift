import Foundation
import Testing
@testable import PeachEngine

/// The Licences screen's texts: every one present, each on one page of the
/// list and shown there whole, and the word lists' notice the very notice the
/// repository records.
///
/// **SCOWL asks that its notice appear in all copies,** so the player's
/// version in `App/Licences/WordLists.txt` must carry it word for word. It is
/// held to `Data/ATTRIBUTION.md`'s quotation rather than to a copy here, so the
/// two records cannot drift apart while both look fine.
@Suite("the licences a player reads")
struct PlayerLicencesTests {
    /// The source tree first, then a bundled copy, as `AppVocabularyTests`
    /// finds `App/`; `Data/` resolves the same way through `dataDirectory`.
    /// Xcode Cloud's test phase and CI's checkout-less job run without the
    /// checkout: run that job's steps locally against the tree alone, every
    /// test here failed to open its file.
    static let app: URL = {
        let fromSource = repositoryRoot.appendingPathComponent("App")
        if FileManager.default.fileExists(atPath: fromSource.path) { return fromSource }
        for bundle in Bundle.allBundles {
            guard let resources = bundle.resourceURL else { continue }
            let candidate = resources.appendingPathComponent("App")
            if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
        }
        return fromSource
    }()

    /// "Data/..." or "App/...", wherever the suite is running.
    static func file(_ path: String) -> URL {
        let parts = path.split(separator: "/", maxSplits: 1).map(String.init)
        return (parts[0] == "Data" ? dataDirectory : app).appendingPathComponent(parts[1])
    }

    static func text(_ path: URL) throws -> String {
        try String(contentsOf: path, encoding: .utf8)
    }

    /// Whitespace collapsed, so a line wrapped at 80 columns in one file and
    /// unwrapped in the other compares as the same words.
    static func words(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// Every licence text the app ships, written out here rather than read off
    /// `Licences`, so a text dropped from every page fails below instead of
    /// quietly leaving this list too.
    static let texts = [
        "Data/Soundscape-LICENSE.txt", "Data/Soundscape-LICENSE-CHROMIUM.txt",
        "App/Licences/WordLists.txt", "App/Licences/Wiktionary.txt",
        "App/Fonts/OFL-Fredoka.txt", "App/Fonts/OFL-Nunito.txt",
    ]

    @Test("every text the screen reads is there", arguments: texts)
    func present(path: String) throws {
        let text = try Self.text(Self.file(path))
        #expect(text.count > 100, "\(path) is too short to be a licence")
    }

    @Test("every text is on exactly one page")
    func everyTextOnOnePage() {
        let shown = Licences.all.flatMap(\.files)
        #expect(Set(shown) == Set(Self.texts), "a page shows a text the app does not ship, or none shows one it does")
        #expect(shown.count == Set(shown).count, "a text is on two pages")
    }

    @Test("the list is Soundscape, the word lists, Wiktionary and the typefaces, in that order")
    func listOrder() {
        #expect(Licences.list.map(\.id) == ["soundscape", "word-lists", "wiktionary", "typefaces"])
    }

    /// The page shows `Licences.paragraphs` of each text, one `Text` each. Put
    /// back together they must be the file, word for word: a paragraph dropped,
    /// a list line lost to a join, or a notice cut short fails here.
    @Test("each page shows its texts whole", arguments: Licences.all)
    func pageShowsItsTextsWhole(page: Licences.Page) throws {
        for path in page.files {
            let text = try Self.text(Self.file(path))
            let shown = Licences.paragraphs(text).joined(separator: " ")
            #expect(Self.words(shown) == Self.words(text), "\(page.id) does not show \(path) whole")
        }
    }

    @Test("the word lists' text carries SCOWL's notice as the repository quotes it")
    func scowlNotice() throws {
        let attribution = try Self.text(dataDirectory.appendingPathComponent("ATTRIBUTION.md"))
        // The notice is the block quoted under the SCOWL heading.
        let quoted = attribution.components(separatedBy: "\n")
            .drop { !$0.hasPrefix("## SCOWL") }
            .prefix { !$0.hasPrefix("## Wiktionary") }
            .filter { $0.hasPrefix(">") }
            .map { $0.dropFirst().trimmingCharacters(in: .whitespaces) }
            .joined(separator: " ")
        let notice = Self.words(quoted)
        #expect(notice.hasPrefix("The collective work is Copyright 2000-2020 by Kevin Atkinson"))
        let player = Self.words(try Self.text(Self.app.appendingPathComponent("Licences/WordLists.txt")))
        #expect(player.contains(notice), "WordLists.txt does not carry SCOWL's notice word for word")
    }

    @Test("the Wiktionary text names the licence and links it")
    func wiktionary() throws {
        let text = try Self.text(Self.app.appendingPathComponent("Licences/Wiktionary.txt"))
        #expect(text.contains("Attribution-ShareAlike 4.0"))
        #expect(text.contains("https://creativecommons.org/licenses/by-sa/4.0/"))
    }
}
