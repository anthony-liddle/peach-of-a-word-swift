import Foundation
import Testing
@testable import PeachEngine

/// The permutation that undoes the sort, i.e. the rack that spells the word.
private func revealingOrder(_ word: String) -> [Int] {
    var pool = Array(word.sorted()).enumerated().map { ($0.offset, $0.element) }
    return word.map { letter in
        let at = pool.firstIndex { $0.1 == letter }!
        return pool.remove(at: at).0
    }
}

private func render(_ order: [Int], _ letters: String) -> String {
    let rack = Array(letters)
    return String(order.map { rack[$0] })
}

/// The calendar, from the source tree if it is there and from the bundle if it
/// is not.
///
/// **This blocked delivery for six builds.** The first version walked `#filePath`
/// to the package root and read `Data/daily-calendar.json` with `try!`. That
/// works under `swift test`, which runs from the checkout, and it works in Xcode
/// locally. It does not work in Xcode Cloud's test action, which runs the test
/// bundle without the checkout that `#filePath` points at, so the read threw,
/// `try!` trapped, and the whole `xctest` process died. Builds 14 to 19 all
/// failed the same way, the Archive succeeded every time, and because the test
/// action failed the TestFlight post-action never ran. Nothing reached testers
/// after build 13.
///
/// Two separate mistakes, and the fix needs both halves:
///
/// **The path had no fallback.** `Oracle.swift` and `AppVocabularyTests` both
/// solved this already, in this repository, for this exact runner: source tree
/// first, bundled copy second. `project.yml` copies `Data` into the test bundle
/// as a folder reference precisely so that fallback has something to find. This
/// function was written as though that history did not exist.
///
/// **`try!` turned a failure into a crash.** A thrown error fails one test and
/// the run continues. A trap takes the process down, so every test running
/// beside it is reported as crashed too, and the cause is buried under
/// collateral: six failures on the board, three of them tests that read no
/// files at all. `throws` here means a missing calendar fails these three tests
/// and says why, rather than deleting the evidence.
private func calendarWords() throws -> [String] {
    struct Calendar: Decodable { let words: [String] }

    // Walk up from this file to the package root, so the test does not depend
    // on the working directory the runner happens to choose.
    var dir = URL(fileURLWithPath: #filePath)
    for _ in 0..<3 { dir = dir.deletingLastPathComponent() }
    let fromSource = dir.appendingPathComponent("Data/daily-calendar.json")

    var url = fromSource
    if !FileManager.default.fileExists(atPath: fromSource.path) {
        // `Data` is a folder reference in the test bundle, so the file keeps its
        // directory and is looked up by subdirectory rather than by name alone.
        let bundled = Bundle.allBundles.lazy.compactMap {
            $0.url(forResource: "daily-calendar", withExtension: "json",
                   subdirectory: "Data")
                ?? $0.url(forResource: "daily-calendar", withExtension: "json")
        }.first
        guard let bundled else {
            throw CalendarMissing(searched: fromSource)
        }
        url = bundled
    }

    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode(Calendar.self, from: data).words
}

/// Named rather than a bare string, so the failure says which path was tried.
private struct CalendarMissing: Error, CustomStringConvertible {
    let searched: URL
    var description: String {
        "daily-calendar.json is neither in the source tree at \(searched.path) "
        + "nor in any loaded bundle. In Xcode Cloud the checkout is absent, so "
        + "the bundled copy is the one that has to be found."
    }
}

@Suite("Rack ordering never leads with the crown")
struct RackTests {
    @Test("Rejects the order that spells the whole word")
    func rejectsFullSpell() {
        let word = "pavement"
        #expect(rackGivesAway(
            order: revealingOrder(word),
            letters: String(word.sorted()),
            word: word
        ))
    }

    @Test("Rejects a top row of PAVE over a scrambled second row")
    func rejectsTopRow() {
        let word = "pavement"
        let letters = String(word.sorted())
        let order = revealingOrder(word)
        let hinted = Array(order[0..<rackRow]) + order[rackRow...].reversed()
        #expect(render(hinted, letters).hasPrefix("pave"))
        #expect(rackGivesAway(order: hinted, letters: letters, word: word))
    }

    @Test("Accepts identity, which spells the sorted letters, not the word")
    func acceptsIdentity() {
        let word = "pavement"
        let letters = String(word.sorted())
        let identity = Array(0..<letters.count)
        #expect(render(identity, letters) == "aeemnptv")
        #expect(!rackGivesAway(order: identity, letters: letters, word: word))
    }

    @Test("Escapes even when every draw reveals, rather than spinning")
    func escapesRatherThanSpinning() {
        let word = "pavement"
        let letters = String(word.sorted())
        let order = guardedRackOrder(letters: letters, word: word) { _ in
            revealingOrder(word)
        }
        #expect(!rackGivesAway(order: order, letters: letters, word: word))
    }

    @Test("The daily rack is a pure function of the word")
    func dailyIsPure() throws {
        for word in try calendarWords().prefix(20) {
            let letters = String(word.sorted())
            #expect(dailyRackOrder(letters: letters, word: word)
                    == dailyRackOrder(letters: letters, word: word))
        }
    }

    @Test("The daily rack never leads with the crown, across the calendar")
    func dailyNeverLeaks() throws {
        // The regression this file exists for. Unguarded, the expected count is
        // 0.04 full spells and 0.80 top rows per 626-day pass; a real player hit
        // the first of those (PAVE / MENT) on a live morning.
        let leaks = try calendarWords().filter { word in
            let letters = String(word.sorted())
            return rackGivesAway(
                order: dailyRackOrder(letters: letters, word: word),
                letters: letters,
                word: word
            )
        }
        #expect(leaks.isEmpty)
    }

    @Test("The daily rack is a genuine permutation of the sorted letters")
    func dailyIsAPermutation() throws {
        for word in try calendarWords() {
            let letters = String(word.sorted())
            let order = dailyRackOrder(letters: letters, word: word)
            #expect(order.sorted() == Array(0..<letters.count))
            #expect(String(render(order, letters).sorted()) == letters)
        }
    }

    /// The two engines must deal the SAME rack, or a player comparing the app
    /// against the web build sees two different puzzles for one day. Generated
    /// by the TypeScript `dailyRackOrder` and pasted here; regenerate with
    /// `scripts/rack-parity.mjs` in the web repo if the seeding ever changes.
    @Test("Matches the TypeScript engine word for word")
    func matchesTypeScript() {
        for (word, expected) in rackParityVectors {
            let letters = String(word.sorted())
            #expect(dailyRackOrder(letters: letters, word: word) == expected,
                    "rack for \(word) diverged from the web engine")
        }
    }
}
