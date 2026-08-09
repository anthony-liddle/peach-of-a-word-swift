import Testing
@testable import PeachEngine

@Suite("createPuzzle")
struct CreatePuzzleTests {
    let puzzle = Fixture.puzzle

    @Test("derives the rack as the sorted source letters")
    func rack() {
        #expect(puzzle.letters == "adeeenrs")
    }

    @Test("collects the formable ENABLE words as the validation set")
    func validation() {
        #expect(puzzle.validationWords
                == ["serenade", "sneer", "eased", "sea", "near", "dean", "sane"])
    }

    @Test("collects the formable set words as the completion denominator")
    func common() {
        #expect(puzzle.commonWords == Set(Fixture.common))
    }

    @Test("partitions the off-page finds into the three rarity rungs")
    func rungs() {
        #expect(puzzle.uncommonWords == ["sneer"])
        #expect(puzzle.rareWords == ["eased"])
        #expect(puzzle.mythicWords == ["sane"])
    }

    @Test("keeps the four bands disjoint and covering the whole validation set")
    func partition() {
        let union = puzzle.commonWords
            .union(puzzle.uncommonWords)
            .union(puzzle.rareWords)
            .union(puzzle.mythicWords)
        #expect(union == puzzle.validationWords)
        let sizes = puzzle.commonWords.count + puzzle.uncommonWords.count
            + puzzle.rareWords.count + puzzle.mythicWords.count
        #expect(sizes == puzzle.validationWords.count)  // no overlap
    }

    // Par is the SET points, not every findable word. This is the assertion
    // that pins the decision the TypeScript's stale doc comment contradicts.
    @Test("scores par from the set points alone, with no rarity bonuses")
    func par() {
        // sea 1 + near 3 + dean 3 + serenade 15 = 22
        #expect(puzzle.reachableScore == 22)
    }
}
