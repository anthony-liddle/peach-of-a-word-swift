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

    /// Every word the daily can deal, and therefore every word Endless can deal
    /// too, since `EndlessSource` draws from the same calendar.
    @Test("covers every crown the calendar can deal")
    func coversTheCalendar() throws {
        let entries = readSourceEntries()
        let missing = try calendarWords().filter { entries[$0] == nil }
        #expect(missing.isEmpty, "no entry for \(missing.prefix(10))")
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
