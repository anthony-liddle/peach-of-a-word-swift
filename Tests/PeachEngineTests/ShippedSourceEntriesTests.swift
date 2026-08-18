import Foundation
import Testing
@testable import PeachEngine

/// The guard that activates the day the corpus lands.
///
/// `Data/etymology.tsv` is not committed: it is Wiktionary text under CC BY-SA
/// 4.0 and whether it ships is an open decision. So these tests are enabled by
/// the corpus's presence rather than skipped by hand, and today they do not
/// run at all.
///
/// They are written now, ahead of the content, because they are the tests that
/// catch the two ways this can be quietly wrong: a corpus that does not cover
/// every crown the calendar can deal, and a corpus read with its columns the
/// wrong way round. Both produce a card that renders. Neither produces a crash.
///
/// **Watched fail before being trusted.** Against a corpus missing a crown, the
/// coverage test named the missing word; against one with the columns swapped,
/// the column test failed on the definition. Both corpora were temporary and
/// neither is committed.
@Suite(
    "the shipped reveal corpus",
    .enabled(
        if: !readSourceEntries().isEmpty,
        "Data/\(sourceEntriesFileName) is not committed, pending the licensing decision"
    )
)
struct ShippedSourceEntriesTests {
    private struct CalendarFile: Codable { let words: [String] }

    private func calendarWords() throws -> [String] {
        let url = dataDirectory.appendingPathComponent("daily-calendar.json")
        return try JSONDecoder()
            .decode(CalendarFile.self, from: try Data(contentsOf: url))
            .words
    }

    /// The crowns that deliberately have no reveal entry, as of orchard v1.3.0.
    ///
    /// Each was dropped from the corpus for carrying something that was not an
    /// etymology: `favorite` shipped Italian inflection tables, `planning` a Lua
    /// module error, `catering` a Wiktionary maintenance notice and nothing
    /// else. A player dealt one of these sees no Etymology section, which is
    /// the intended outcome rather than a gap.
    ///
    /// This is a fixed list rather than a tolerance, so a twelfth crown losing
    /// its entry still fails this test. Update it only alongside a corpus change
    /// that intends the drop.
    private static let deliberatelyUncovered: Set<String> = [
        "branding", "catering", "dripping", "emulator", "favorite", "mornings",
        "planning", "projects", "rattling", "sampling", "training",
    ]

    /// Every word the daily can deal, and therefore every word Endless can deal
    /// too, since `EndlessSource` draws from the same calendar, except the
    /// crowns listed above as deliberately uncovered.
    @Test("covers every crown the calendar can deal, bar the known drops")
    func coversTheCalendar() throws {
        let entries = readSourceEntries()
        let missing = Set(try calendarWords().filter { entries[$0] == nil })
        let unexpected = missing.subtracting(Self.deliberatelyUncovered)
        #expect(unexpected.isEmpty, "no entry for \(unexpected.sorted().prefix(10))")

        let restored = Self.deliberatelyUncovered.subtracting(missing)
        #expect(
            restored.isEmpty,
            "these crowns now have an entry and should leave the list: \(restored.sorted())"
        )
    }

    /// A crown with an entry but an empty field renders a card with one section
    /// missing, which is the fallback state rather than the intended one.
    @Test("carries both fields for every crown, not just a row")
    func bothFieldsPresent() throws {
        let entries = readSourceEntries()
        let hollow = try calendarWords().filter { word in
            guard let entry = entries[word] else { return false }
            return entry.definition.isEmpty || entry.etymology.isEmpty
        }
        #expect(hollow.isEmpty, "empty field on \(hollow.prefix(10))")
    }

    /// The column-order guard, against the shipped file rather than a literal.
    ///
    /// orchard's definitions are part-of-speech prefixed ("noun. ", "verb. ")
    /// and its etymologies are not, so the two columns are told apart by their
    /// own shape. Swap them and this fails; no other test on the real file
    /// would notice.
    @Test("reads definitions into the definition field")
    func columnsAreNotSwapped() throws {
        let entries = readSourceEntries()
        let prefixes = ["noun.", "verb.", "adjective.", "adverb.", "preposition.",
                        "conjunction.", "pronoun.", "interjection.", "determiner.",
                        "numeral.", "article.", "particle."]
        let words = try calendarWords()
        let looksLikeADefinition = words.compactMap { entries[$0] }
            .filter { entry in prefixes.contains { entry.definition.hasPrefix($0) } }

        // Not every row is prefixed, so this is a majority rather than a total.
        // Swapped columns take it to roughly zero, which is the signal.
        #expect(looksLikeADefinition.count > words.count / 2)
    }
}
