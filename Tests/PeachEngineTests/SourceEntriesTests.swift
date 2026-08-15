import Foundation
import Testing
@testable import PeachEngine

/// The reveal corpus, decoded.
///
/// orchard publishes `etymology.tsv` as three tab-separated columns in the
/// order **word, etymology, definition**. That order is the opposite of the
/// card's reading order and of the web's `SourceEntry`, which is why the column
/// order gets its own test rather than being asserted incidentally: getting it
/// backwards produces a card that is wrong in a way that still renders.
@Suite("source entries")
struct SourceEntriesTests {

    /// One row in the shipped shape, taken verbatim from the corpus.
    private let aardvark = """
        aardvark\tBorrowed from Afrikaans aardvark (now rare).\tnoun. The nocturnal, burrowing mammal Orycteropus afer.
        """

    @Test("reads the columns in the corpus's order, not the card's")
    func columnOrder() {
        let entries = parseSourceEntries(aardvark)
        #expect(entries["aardvark"]?.etymology == "Borrowed from Afrikaans aardvark (now rare).")
        #expect(entries["aardvark"]?.definition
                == "noun. The nocturnal, burrowing mammal Orycteropus afer.")
    }

    @Test("keys every row by its word")
    func keysByWord() {
        let entries = parseSourceEntries("one\te1\td1\ntwo\te2\td2")
        #expect(Set(entries.keys) == ["one", "two"])
    }

    @Test("has no entry for a word the corpus does not carry")
    func unknownWord() {
        #expect(parseSourceEntries(aardvark)["motorway"] == nil)
    }

    /// Blank lines are not a hypothetical: the corpus is newline-terminated, so
    /// a naive split yields a trailing empty row on every real file.
    @Test("ignores blank lines rather than keying an empty word")
    func blankLines() {
        let entries = parseSourceEntries("\none\te1\td1\n\n")
        #expect(entries.count == 1)
        #expect(entries[""] == nil)
    }

    /// The failure mode this guards is silent: with `omittingEmptySubsequences`
    /// left at its default, a row with an empty definition drops the field
    /// entirely and the next column slides into its place.
    @Test("an empty definition stays empty rather than shifting a column")
    func emptyTrailingColumn() {
        let entries = parseSourceEntries("one\tfrom somewhere\t")
        #expect(entries["one"]?.etymology == "from somewhere")
        #expect(entries["one"]?.definition == "")
    }

    /// Definitions carry semicolons and commas; etymologies carry parentheses,
    /// quotation marks and Greek. Only the tab separates fields.
    @Test("splits on tabs only, so prose punctuation survives")
    func prosePunctuation() {
        let row = "one\tFrom Ancient Greek ἀνώμαλος (anṓmalos), via Latin.\tadjective. Odd; unusual."
        let entries = parseSourceEntries(row)
        #expect(entries["one"]?.etymology == "From Ancient Greek ἀνώμαλος (anṓmalos), via Latin.")
        #expect(entries["one"]?.definition == "adjective. Odd; unusual.")
    }

    /// A row that is not three columns is corrupt, and a corrupt row should not
    /// take the other 819 with it.
    @Test("drops a malformed row without losing the rest of the file")
    func malformedRow() {
        let entries = parseSourceEntries("one\te1\td1\nbroken\ntwo\te2\td2")
        #expect(Set(entries.keys) == ["one", "two"])
    }

    // MARK: - Reading it off disk

    /// **The property that lets this ship before the licensing decision.**
    ///
    /// The corpus is CC BY-SA and is not committed. Everything that consumes it
    /// is. So a missing file is the normal state of this repository today, not
    /// an error, and it must produce an empty table rather than a throw: the
    /// app has to launch and play without it.
    @Test("a missing corpus is empty, not an error")
    func missingFileIsEmpty() throws {
        let empty = FileManager.default.temporaryDirectory
            .appendingPathComponent("peach-no-corpus-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: empty) }

        #expect(readSourceEntries(in: empty).isEmpty)
    }

    @Test("reads the corpus from a directory when it is there")
    func readsFromDirectory() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("peach-corpus-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try aardvark.write(
            to: dir.appendingPathComponent("etymology.tsv"),
            atomically: true,
            encoding: .utf8
        )

        #expect(readSourceEntries(in: dir)["aardvark"]?.definition.hasPrefix("noun.") == true)
    }
}
