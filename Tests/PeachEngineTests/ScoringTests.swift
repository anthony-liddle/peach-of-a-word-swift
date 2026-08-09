import Testing
@testable import PeachEngine

@Suite("scoreWord")
struct ScoreWordTests {
    // `arguments:` runs the test body once per tuple, each reported separately.
    // It is the Swift Testing answer to a hand-rolled loop of expectations: a
    // failure names the case that failed rather than just the line.
    @Test("follows the GDD curve: 3=1, 4=3, 5=5, 6=7, 7=11, 8=15",
          arguments: [("cat", 1), ("cats", 3), ("scale", 5),
                      ("scaled", 7), ("scalene", 11), ("serenade", 15)])
    func curve(word: String, points: Int) {
        #expect(scoreWord(word) == points)
    }

    @Test("scores below the minimum length as zero")
    func belowMinimum() {
        #expect(scoreWord("at") == 0)
        #expect(scoreWord("") == 0)
    }

    // No TypeScript counterpart: the `length > 8 -> 15` branch is untested
    // there. A Swift switch with `case 8...` makes it explicit, so test it.
    @Test("caps at the 8-letter score for anything longer")
    func aboveSourceLength() {
        #expect(scoreForLength(9) == 15)
        #expect(scoreForLength(20) == 15)
    }
}

@Suite("findScore")
struct FindScoreTests {
    @Test("adds the rarity bonus on top of the length curve, none for a set word")
    func bonuses() {
        #expect(findScore("cat", rung: .set) == 1)
        #expect(findScore("serenade", rung: .set) == 15)
        #expect(findScore("cat", rung: .uncommon) == 1 + 1)
        #expect(findScore("scale", rung: .rare) == 5 + 2)
        #expect(findScore("scaled", rung: .mythic) == 7 + 4)
    }
}

@Suite("the tier ladder")
struct TierLadderTests {
    @Test("has six ranks with the top at 0.80 of par")
    func ladder() {
        #expect(tiers.count == 6)
        #expect(tiers.map(\.threshold) == [0, 0.08, 0.22, 0.4, 0.6, 0.8])
        #expect(tiers.last?.threshold == 0.8)
    }

    @Test("keeps the storage epoch fixed and separate from the daily epoch")
    func epochs() {
        // storageEpoch never moves, even when dailyEpoch is re-anchored by a
        // calendar regeneration. Persisted day keys depend on it.
        #expect(storageEpoch == EpochDate(year: 2026, month: 1, day: 1))
        #expect(dailyEpoch == EpochDate(year: 2026, month: 6, day: 23))
        #expect(storageEpoch != dailyEpoch)
    }
}
