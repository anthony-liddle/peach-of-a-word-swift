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

private func calendarWords() -> [String] {
    // Walk up from this file to the package root, so the test does not depend
    // on the working directory the runner happens to choose.
    var dir = URL(fileURLWithPath: #filePath)
    for _ in 0..<3 { dir = dir.deletingLastPathComponent() }
    let url = dir.appendingPathComponent("Data/daily-calendar.json")
    let data = try! Data(contentsOf: url)
    struct Calendar: Decodable { let words: [String] }
    return try! JSONDecoder().decode(Calendar.self, from: data).words
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
    func dailyIsPure() {
        for word in calendarWords().prefix(20) {
            let letters = String(word.sorted())
            #expect(dailyRackOrder(letters: letters, word: word)
                    == dailyRackOrder(letters: letters, word: word))
        }
    }

    @Test("The daily rack never leads with the crown, across the calendar")
    func dailyNeverLeaks() {
        // The regression this file exists for. Unguarded, the expected count is
        // 0.04 full spells and 0.80 top rows per 626-day pass; a real player hit
        // the first of those (PAVE / MENT) on a live morning.
        let leaks = calendarWords().filter { word in
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
    func dailyIsAPermutation() {
        for word in calendarWords() {
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
