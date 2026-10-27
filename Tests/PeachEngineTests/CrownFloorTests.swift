import Foundation
import Testing
@testable import PeachEngine

/// Every crown on the calendar clears `minSetSize`, but its named exceptions.
///
/// The floor admits crowns; a committed day never moves. So when a list change
/// takes a crown under the floor, the crown keeps its day and is named here at
/// its exact size, with its reason, and the floor still holds for every other
/// crown. The web names the same exceptions in `scripts/lib/floor.ts`, where
/// its calendar build checks them.
@Suite("every crown clears the floor, but its named exceptions")
struct CrownFloorTests {
    /// Crowns below the floor by decision: the size each holds, and why.
    static let exceptions: [String: (size: Int, reason: String)] = [
        "approach": (
            size: 14,
            reason: "crap left every basket in orchard v1.10.0 (Antoine, 2026-10-27). approach keeps "
                + "27 December 2027 for the 1.0 build: no fresh crown can replace it until the "
                + "etymology fetcher reads entries Wiktionary has, such as ultimate and neighbor."
        ),
    ]

    @Test("holds every crown to the floor, and each exception to its size")
    func everyCrown() throws {
        // The basket as createPuzzle builds it, the common pool's words the
        // rack can spell that the boundary accepts, without building the other
        // three bands: a whole puzzle per crown took seven minutes.
        let boundary = Set(try readWordList("enable.txt") + readWordList("scowl95-additions.txt"))
        let common = ListWordSource(try readWordList("common-pool.txt"))
        for word in try DailySequencePinTests.calendarWords() {
            let size = common.formableWords(rack: word).filter { boundary.contains($0) }.count
            if let exception = Self.exceptions[word] {
                #expect(size == exception.size, "\(word) is named at \(exception.size)")
            } else {
                #expect(size >= minSetSize, "\(word) holds \(size), under the floor of \(minSetSize)")
            }
        }
    }

    @Test("names approach, one under the floor")
    func theExceptions() {
        #expect(Self.exceptions.keys.sorted() == ["approach"])
        #expect(Self.exceptions["approach"]?.size == minSetSize - 1)
    }
}
