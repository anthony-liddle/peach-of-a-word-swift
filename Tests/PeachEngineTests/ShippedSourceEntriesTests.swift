import Foundation
import Testing
@testable import PeachEngine

/// Every crown the calendar can deal gets its card: a meaning and an origin.
///
/// **What this used to allow, and what it cost.** It was written ahead of the
/// corpus and enabled by the file's presence, with eleven crowns listed as
/// deliberately uncovered after orchard v1.3.0 dropped their rows, and its
/// both-fields test skipped any crown with no row at all. So nothing held a
/// crown to having a card. On 4 November 2026 the crown was `favorite`, and
/// its card showed the word and nothing else. orchard v1.11.0 wrote the eleven
/// rows, and from then on there is no exception list and no skip: the corpus
/// ships, and a crown without both fields fails here by name and by day.
///
/// **Watched fail before being trusted.** On `main` before v1.11.0 it named
/// the eleven, each with its day, and nothing else.
@Suite("the shipped reveal corpus")
struct ShippedSourceEntriesTests {
    private struct CalendarFile: Codable { let words: [String] }

    private func calendarWords() throws -> [String] {
        let url = dataDirectory.appendingPathComponent("daily-calendar.json")
        return try JSONDecoder()
            .decode(CalendarFile.self, from: try Data(contentsOf: url))
            .words
    }

    /// The day a calendar index falls on, as `2026-11-04`, counted from the
    /// epoch in UTC so the name doesn't move with the machine's time zone.
    private func day(_ index: Int) -> String {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let start = utc.date(from: DateComponents(
            year: dailyEpoch.year, month: dailyEpoch.month, day: dailyEpoch.day
        ))!
        let date = utc.date(byAdding: .day, value: index, to: start)!
        let parts = utc.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
    }

    /// Every word the daily can deal, and therefore every word Endless can deal
    /// too, since `EndlessSource` draws from the same calendar.
    @Test("gives every crown in the calendar a meaning and an origin")
    func everyCrownHasItsCard() throws {
        let entries = readSourceEntries()
        let bare = try calendarWords().enumerated().compactMap { index, word -> String? in
            guard let entry = entries[word] else {
                return "\(word), \(day(index)): no row"
            }
            var missing: [String] = []
            if entry.definition.trimmingCharacters(in: .whitespaces).isEmpty {
                missing.append("no meaning")
            }
            if entry.etymology.trimmingCharacters(in: .whitespaces).isEmpty {
                missing.append("no origin")
            }
            return missing.isEmpty
                ? nil : "\(word), \(day(index)): \(missing.joined(separator: " and "))"
        }
        #expect(
            bare.isEmpty,
            "\(bare.count) crowns without both a meaning and an origin:\n\(bare.joined(separator: "\n"))"
        )
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
