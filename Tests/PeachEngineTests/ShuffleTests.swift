import Testing
@testable import PeachEngine

@Suite("seededPermutation")
struct ShuffleTests {
    @Test("is a true permutation of [0, n)")
    func isPermutation() {
        #expect(seededPermutation(50, seed: 123).sorted() == Array(0..<50))
    }

    @Test("is deterministic for a given n and seed")
    func deterministic() {
        #expect(seededPermutation(20, seed: 7) == seededPermutation(20, seed: 7))
    }

    @Test("differs across seeds")
    func seedSensitive() {
        #expect(seededPermutation(20, seed: 1) != seededPermutation(20, seed: 2))
    }

    // Bit-for-bit agreement with the TypeScript mulberry32. These values came
    // out of Node, not out of this implementation, so they catch a Swift port
    // that is internally consistent but wrong.
    //
    // `Math.imul` is a 32-bit wrapping multiply; a port using Swift's plain `*`
    // would trap, and one using the wrong width would silently diverge. This is
    // the tripwire for both.
    @Test("matches the JavaScript mulberry32 stream exactly")
    func matchesJavaScript() {
        #expect(seededPermutation(20, seed: 7)
                == [9, 19, 7, 4, 5, 10, 12, 16, 18, 2, 15, 13, 3, 14, 6, 8, 11, 17, 1, 0])
        #expect(Array(seededPermutation(50, seed: 123).prefix(10))
                == [33, 30, 36, 18, 28, 5, 26, 48, 9, 34])
        #expect(seededPermutation(5, seed: calendarSeed) == [4, 3, 0, 2, 1])
    }
}

@Suite("generateCalendar")
struct CalendarTests {
    let eligible = ["alpha", "bravo", "charlie", "delta", "echo"]

    @Test("first run contains exactly the eligible words, none extra")
    func exact() {
        #expect(generateCalendar(eligible: eligible, existing: []).sorted() == eligible.sorted())
    }

    @Test("does not march alphabetically (the seeded shuffle)")
    func shuffled() {
        #expect(generateCalendar(eligible: eligible, existing: []) != eligible.sorted())
    }

    @Test("is deterministic: same inputs yield an identical calendar")
    func deterministic() {
        #expect(generateCalendar(eligible: eligible, existing: [])
                == generateCalendar(eligible: eligible, existing: []))
    }

    // The freeze. This is the load-bearing invariant: a new eligible word lands
    // at the end and every existing position is untouched. A failure here
    // re-dates every day after the change and breaks the promise that a given
    // day is a fixed puzzle.
    @Test("appends new eligible words to the end and never moves an existing one")
    func appendOnly() {
        let existing = generateCalendar(eligible: eligible, existing: [])
        let grown = generateCalendar(eligible: eligible + ["foxtrot", "golf"], existing: existing)

        #expect(Array(grown.prefix(existing.count)) == existing)
        #expect(grown.dropFirst(existing.count).sorted() == ["foxtrot", "golf"])
        #expect(grown.count == existing.count + 2)
    }

    @Test("never reorders or removes when nothing new is eligible")
    func stable() {
        let existing = generateCalendar(eligible: eligible, existing: [])
        #expect(generateCalendar(eligible: eligible, existing: existing) == existing)
    }
}
