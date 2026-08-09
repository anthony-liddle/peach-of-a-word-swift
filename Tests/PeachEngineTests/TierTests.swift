import Testing
@testable import PeachEngine

@Suite("computeTier (named points ladder, set-points denominator)")
struct TierTests {
    // Synthetic words chosen by length so the scores are easy to reason about.
    // Lengths: 3=1, 4=3, 5=5, 6=7, 7=11, 8=15; off-page adds uncommon +1 /
    // rare +2 / mythic +4.
    static let source = "srcsrcsr"                                     // 8 letters, set, 15
    static let set = [source, "aaaa", "bbbb", "ccccc", "ddddd", "eee"]  // 15+3+3+5+5+1 = 32
    static let uncommon = ["ffffff"]                                    // 7 + 1 = 8
    static let rare = ["ggggggg"]                                       // 11 + 2 = 13
    static let mythic = ["hhhhhhhh"]                                    // 15 + 4 = 19

    let puzzle = Puzzle(
        sourceWord: source,
        letters: "srcsrcsr",
        validationWords: Set(set + uncommon + rare + mythic),
        commonWords: Set(set),
        uncommonWords: Set(uncommon),
        rareWords: Set(rare),
        mythicWords: Set(mythic),
        reachableScore: 32
    )

    @Test("runs against the set points, not the huge off-page tail")
    func denominator() {
        #expect(puzzle.reachableScore == 32)
    }

    @Test("starts at the first rank with nothing found")
    func empty() {
        let t = computeTier(found: [], puzzle: puzzle)
        #expect(t.index == 0)
        #expect(t.score == 0)
        #expect(t.fraction == 0)
        #expect(t.setFound == 0)
        #expect(t.setTotal == 6)
        #expect(t.next == NextRank(index: 1, threshold: 0.08))
    }

    @Test("lets an off-page find climb the ladder (rarity pays more)")
    func offPageClimbs() {
        // The mythic word is 19 of 32 (~0.59): past the 0.40 rung, on points alone.
        let t = computeTier(found: Set(Self.mythic), puzzle: puzzle)
        #expect(t.score == 19)
        #expect(abs(t.fraction - 19.0 / 32.0) < 1e-12)
        #expect(t.index == 3)
    }

    @Test("splits points into set and off-page for the two-color bar")
    func split() {
        let t = computeTier(found: ["ccccc", "hhhhhhhh"], puzzle: puzzle)
        #expect(t.setPoints == 5)
        #expect(t.offPagePoints == 19)
        #expect(t.score == 24)
    }

    @Test("counts set words for the completion celebration, separate from the rank")
    func setCounting() {
        let t = computeTier(found: [Self.source, "aaaa", "hhhhhhhh"], puzzle: puzzle)
        #expect(t.setFound == 2)  // source and aaaa are set words; hhhhhhhh is not
        #expect(t.setTotal == 6)
    }

    // The whole reason for this model: the old set gate walled a player at
    // "21 of 23" even with rare finds and the source word. Under points,
    // off-page finds carry past unfound set words to the TOP named rank.
    @Test("reaches the top named rank with set words unfound (the 21 of 23 guard)")
    func topWithUnfoundSet() {
        let found: Set<String> = Set(
            [Self.source, "bbbb", "ccccc", "ddddd"] + Self.uncommon + Self.rare + Self.mythic
        )
        let t = computeTier(found: found, puzzle: puzzle)
        #expect(t.setFound == 4)  // 2 of 6 set words still unfound
        #expect(t.index == 5)     // top named rank, not walled below it
        #expect(t.isTop)
        #expect(t.next == nil)
        // And it is still NOT complete: the ladder topped, the page did not clear.
        #expect(!isComplete(t))
    }

    @Test("keeps the top named rank below full completion, with points overflowing")
    func overflow() {
        // 0.80 * 32 = 25.6. source + ddddd + ccccc + bbbb = 28 of 32.
        let nearTop = computeTier(found: [Self.source, "ddddd", "ccccc", "bbbb"], puzzle: puzzle)
        #expect(nearTop.setFound < nearTop.setTotal)
        #expect(nearTop.index == 5)

        // Off-page points overflow past 1.0 but unlock no higher named rank.
        let everything = computeTier(found: puzzle.validationWords, puzzle: puzzle)
        #expect(everything.fraction > 1)
        #expect(everything.index == 5)
        #expect(everything.isTop)
        #expect(isComplete(everything))  // every set word found
    }
}
