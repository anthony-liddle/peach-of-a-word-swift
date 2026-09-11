import Foundation
import Testing
@testable import PeachEngine

/// The daily sequence, pinned against the committed calendar.
///
/// **Bea plays one of these every morning, and a change here is silent.** A
/// board that shifts by a day looks entirely normal: the rack is valid, the
/// words are real, the score works. Nothing in the app or in any other test
/// notices, and the only symptom is that her calendar and her memory disagree.
///
/// Written when `dailySourceWord(date:)` was split so that it delegates to
/// `sourceWord(calendar:dailyIndex:)` and the pre-epoch floor moved one function
/// deeper. That split was verified by running both versions over every date from
/// 2025-01-01 to 2030-12-31 and diffing, which found no difference. This keeps a
/// sample of that comparison in the suite, so the next change to the chain has
/// to survive `swift test` rather than a worktree someone remembered to build.
@Suite("the daily sequence is pinned")
struct DailySequencePinTests {
    /// The real calendar, not a fixture: a fixture would pin the function
    /// against itself and say nothing about the words actually shipped.
    ///
    /// **Through `dataDirectory`, and throwing rather than `try!`.** Two things
    /// the first version of this got wrong, both caught by CI rather than
    /// locally. It walked up from `#filePath` to the repository, which passed
    /// everywhere except `checkout-less-tests`, the job that exists to catch
    /// exactly that: it moves `Data` aside and runs the suite against the
    /// bundle alone. And it read the file in a `static let` with `try!`, so the
    /// miss was a fatal error that took the whole test process down instead of
    /// one named failure. `dataDirectory` resolves to the source tree when
    /// there is one and to a loaded bundle's `Data` when there is not.
    static func calendarWords() throws -> [String] {
        struct File: Decodable { let words: [String] }
        let url = dataDirectory.appendingPathComponent("daily-calendar.json")
        return try JSONDecoder().decode(File.self, from: Data(contentsOf: url)).words
    }

    private let utc = TimeZone(identifier: "UTC")!

    private func word(_ iso: String) throws -> String {
        var cal = Foundation.Calendar(identifier: .gregorian)
        cal.timeZone = utc
        let parts = iso.split(separator: "-").map { Int($0)! }
        let date = cal.date(from: DateComponents(
            year: parts[0], month: parts[1], day: parts[2], hour: 12
        ))!
        return try dailySourceWord(calendar: Self.calendarWords(), date: date, timeZone: utc)
    }

    /// Two of these are Bea's: 2026-07-02 is the first day of her seventy-day
    /// run and 2026-09-09 is the last, which is the pair the archive's back-fill
    /// expands and the pair her calendar draws.
    @Test("known dates keep their words", arguments: [
        ("2026-06-23", "mnemonic"),  // the epoch, day zero
        ("2026-06-24", "validity"),
        ("2026-07-02", "struggle"),  // the run starts
        ("2026-09-09", "workshop"),  // the run ends
        ("2027-01-01", "proclaim"),
        ("2028-03-09", "speeding"),  // near the end of the first cycle
        ("2030-12-31", "catholic"),  // well into the reshuffled cycles
    ])
    func pinned(date: String, expected: String) throws {
        #expect(try word(date) == expected, "the daily sequence moved at \(date)")
    }

    /// The floor, which is the half of the split that actually moved. Every date
    /// before the epoch reads as day zero rather than trapping on a negative
    /// modulo, so the whole pre-epoch region is insensitive to an index shift:
    /// that is why the comparison could only ever bite after the epoch.
    @Test("every date before the epoch reads as the first day", arguments: [
        "2026-06-22", "2026-01-01", "2025-01-01",
    ])
    func flooredBeforeTheEpoch(date: String) throws {
        #expect(try word(date) == (try Self.calendarWords())[0])
    }
}
