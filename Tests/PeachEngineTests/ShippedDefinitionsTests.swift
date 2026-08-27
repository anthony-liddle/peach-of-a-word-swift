import Foundation
import Testing
@testable import PeachEngine

/// What the shipped gloss corpus actually contains.
///
/// **Every assertion here is a presence check and the names say so.** A row
/// exists, or it does not. Whether the row says something useful is not
/// checkable from here and is not claimed: 80 glosses of 3,444 were read by
/// hand, three classes of defect turned up, and one of those was found only
/// because `one` and `ten` happened to be in the sample. `meal` reads "Correct
/// quotes." and passes every test in this file, correctly, because it has a
/// row. Naming these `hasARow` rather than `hasADefinition` is the whole
/// discipline: the day someone quotes one of these tests as evidence of
/// content, the name should stop them.
///
/// Enabled by the corpus's presence, matching `ShippedSourceEntriesTests`, so a
/// checkout without `Data/definitions.tsv` skips rather than fails.
@Suite(
    "the shipped definition corpus",
    .enabled(
        if: !readDefinitions().isEmpty,
        "Data/\(definitionsFileName) is not committed"
    )
)
struct ShippedDefinitionsTests {
    private struct CalendarFile: Codable { let words: [String] }

    private func calendarWords() throws -> [String] {
        let url = dataDirectory.appendingPathComponent("daily-calendar.json")
        return try JSONDecoder()
            .decode(CalendarFile.self, from: try Data(contentsOf: url))
            .words
    }

    /// **A row count, not a coverage figure**, and it exists because three
    /// different numbers for this one file are in circulation. The brief that
    /// asked for this feature said 24,877; `meta.json` records
    /// `definitionsCovered: 24833` and is carried through from the web
    /// untouched, because that file has to stay byte-identical with the web's
    /// `serialiseMeta`; the file at orchard v1.5.0 has 24,892 rows.
    ///
    /// Pinned here so the corpus itself is the thing counted. If a future
    /// release moves it, this fails and the number gets looked at rather than
    /// inherited.
    @Test("has the row count orchard v1.5.0 publishes")
    func rowCount() {
        #expect(readDefinitions().count == 24_892)
    }

    /// Every crown has a gloss row.
    ///
    /// Cheap: 626 dictionary lookups against a table already parsed. The set
    /// words behind them are not checked here, because that needs a
    /// `createPuzzle` per rack and 626 of those run for about 47 seconds in
    /// Release and minutes in Debug, against a suite that currently finishes in
    /// under four. That sweep was run once, off to the side, and is reported in
    /// the pull request: 21,988 of 21,988 set-word slots have a row, on all 626
    /// racks, with no distinct set word missing. `oneRacksSetWordsAllHaveARow`
    /// below keeps a single rack of it permanently.
    @Test("every crown the calendar can deal has a row")
    func everyCrownHasARow() throws {
        let definitions = readDefinitions()
        let missing = try calendarWords().filter { definitions[$0] == nil }
        #expect(missing.isEmpty, "no row for \(missing.sorted().prefix(10))")
    }

    /// One real rack, built from the shipped lists, every set word checked.
    ///
    /// One rather than 626, because this is the invariant and the sweep is the
    /// measurement. A single `createPuzzle` is the price of catching a corpus
    /// that stops covering set words at all, which is the regression that would
    /// matter; catching it on rack 1 of 626 is enough to know.
    ///
    /// `serenade` rather than today's rack, deliberately: a test keyed on the
    /// date passes on roughly one day in however many and fails on the rest,
    /// which this repository has already shipped once. See `LayoutBudget`.
    @Test("every set word on one real rack has a row")
    func oneRacksSetWordsAllHaveARow() throws {
        let data = dataDirectory
        let enable = try readWordList("enable.txt", in: data)
        let additions = try readWordList("scowl95-additions.txt", in: data)
        let puzzle = createPuzzle(
            sourceWord: "serenade",
            dictionary: ListDictionary(enable + additions),
            commonPool: ListWordSource(try readWordList("common-pool.txt", in: data)),
            beyond70Pool: ListWordSource(try readWordList("beyond-size-70.txt", in: data)),
            beyond95Pool: ListWordSource(try readWordList("beyond-size-95.txt", in: data))
        )
        let definitions = readDefinitions()
        let missing = puzzle.commonWords.filter { definitions[$0] == nil }
        #expect(missing.isEmpty, "no row for \(missing.sorted().prefix(10))")
        // Guards the guard: a puzzle that built nothing would pass the line
        // above by having nothing to check.
        #expect(puzzle.commonWords.count > 20)
    }

    /// The three known corpus defects, pinned as present rather than patched.
    ///
    /// **This test asserts that the bugs are still there, which is the point.**
    /// They belong to orchard and are deliberately unbundled from the
    /// sense-ranking work, so the app must not work around them: a regex that
    /// closed the 92 spaced hyphens would also rewrite any gloss where a spaced
    /// hyphen is correct, and it would hide the class from the queue that has
    /// to fix it.
    ///
    /// Pinning them means the day a corpus release fixes one, this fails, and
    /// the failure is the notification. Delete the line, do not loosen it.
    /// **Two of the four figures came over slightly wrong and are corrected
    /// against the file rather than transcribed.** The spaced-hyphen class was
    /// described as 92 glosses; at orchard v1.5.0 it is 96. `meal` was
    /// described as reading "Correct quotes."; it reads "noun. Correct quotes",
    /// with the part-of-speech prefix every gloss carries and no full stop.
    /// Neither changes what the defects are, and both are pinned here as
    /// measured so the next person counts rather than inherits.
    @Test("the known corpus defects are present and unpatched")
    func knownDefectsAreStillHere() {
        let definitions = readDefinitions()
        #expect(definitions["gin"]?.contains("non - aged") == true)
        #expect(definitions["ship"]?.contains("water - borne") == true)
        #expect(definitions["sector"]?.contains("(Can we add an example for this sense?)") == true)
        #expect(definitions["meal"] == "noun. Correct quotes")

        let spacedHyphens = definitions.values.filter { $0.contains(" - ") }.count
        #expect(spacedHyphens == 96)
    }
}
