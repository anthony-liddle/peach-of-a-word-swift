import Testing
@testable import PeachEngine

@Suite("isComplete")
struct CompletionTests {
    /// A standing with only the two fields completion reads. The rest are
    /// filled with values that must not influence the answer.
    func standing(setFound: Int, setTotal: Int, score: Int = 0) -> TierStanding {
        TierStanding(
            index: 0, id: "tier-0", score: score, reachable: 100,
            fraction: 0, setPoints: 0, offPagePoints: 0,
            setFound: setFound, setTotal: setTotal,
            next: nil, isTop: false
        )
    }

    @Test("is a word count, not a points threshold")
    func wordCount() {
        // A huge score with set words unfound is not completion.
        #expect(!isComplete(standing(setFound: 20, setTotal: 23, score: 9_999)))
        // Every set word found is completion, whatever the score.
        #expect(isComplete(standing(setFound: 23, setTotal: 23, score: 0)))
    }

    @Test("treats finding more than the set as complete")
    func overshoot() {
        // Defensive: `>=`, matching both web call sites.
        #expect(isComplete(standing(setFound: 24, setTotal: 23)))
    }

    // The guard useGame.ts:602 is missing. An empty set is not "complete"; it
    // is a rack that should never have shipped. minSetSize = 15 means this
    // cannot happen today, which is exactly why the two web call sites agree by
    // accident rather than by construction.
    @Test("an empty set is never complete")
    func emptySet() {
        #expect(!isComplete(standing(setFound: 0, setTotal: 0)))
    }
}
