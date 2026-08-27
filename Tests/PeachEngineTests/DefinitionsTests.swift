import Foundation
import Testing
@testable import PeachEngine

/// The gloss parser, on invented input.
///
/// Separate from `ShippedDefinitionsTests`, which asks what the real corpus
/// contains. These ask what the function does with rows the corpus does not
/// currently have, which is the half that cannot be checked by reading the
/// file: today's corpus has no empty gloss and no tabbed one, and both are
/// things a future release could introduce without announcing it.
@Suite("the definition parser")
struct DefinitionsTests {

    @Test("reads word and gloss")
    func readsAPair() {
        let table = parseDefinitions("aah\tinterjection. Indication of amazement.")
        #expect(table["aah"] == "interjection. Indication of amazement.")
    }

    /// **The column count is a definition, not a count of what turned up.**
    /// Without `maxSplits: 1` a gloss containing a tab reads as a third field,
    /// the row is rejected as malformed, and the word silently loses its
    /// definition. Nothing in the shipped corpus exercises this today.
    @Test("a tab inside the gloss stays inside the gloss")
    func tabInsideTheGloss() {
        let table = parseDefinitions("aal\tnoun. The Indian mulberry\tor noni.")
        #expect(table["aal"] == "noun. The Indian mulberry\tor noni.")
    }

    /// A word mapped to an empty string would open a card with a rule and
    /// nothing under it. Dropped, it takes the miss line, which is a sentence
    /// the card is built to render.
    @Test("an empty gloss is dropped rather than stored empty")
    func emptyGlossIsDropped() {
        let table = parseDefinitions("aal\t\naah\tinterjection. Yes.")
        #expect(table["aal"] == nil)
        #expect(table["aah"] == "interjection. Yes.")
    }

    @Test("a row with no tab at all is skipped")
    func malformedRowIsSkipped() {
        let table = parseDefinitions("justaword\naah\tinterjection. Yes.")
        #expect(table["justaword"] == nil)
        #expect(table.count == 1)
    }

    @Test("an empty key is skipped")
    func emptyKeyIsSkipped() {
        #expect(parseDefinitions("\tnoun. Something.").isEmpty)
    }

    /// The non-throwing contract, copied from `readSourceEntries` and load
    /// bearing for the same reason: this file feeds a control the player taps,
    /// and a build assembled without it has to reach a board anyway.
    @Test("a missing corpus is empty, not an error")
    func missingFileIsEmpty() throws {
        let empty = FileManager.default.temporaryDirectory
            .appendingPathComponent("peach-no-defs-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: empty) }

        #expect(readDefinitions(in: empty).isEmpty)
    }

    @Test("reads the corpus from a directory when it is there")
    func readsFromDirectory() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("peach-defs-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try "aardvark\tnoun. The nocturnal, insectivorous, burrowing mammal.\n".write(
            to: dir.appendingPathComponent(definitionsFileName),
            atomically: true,
            encoding: .utf8
        )

        #expect(readDefinitions(in: dir)["aardvark"]?.hasPrefix("noun.") == true)
    }
}
