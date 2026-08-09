import Testing
@testable import PeachEngine

@Suite("classifyWord")
struct ClassifyTests {
    // Hand-placed bands so the precedence is exercised directly. The four sets
    // are disjoint, as createPuzzle guarantees: a word lands in exactly one.
    let puzzle = Puzzle(
        sourceWord: "national",
        letters: "ailnnoat",
        validationWords: ["national", "nation", "ulna", "talon", "anti"],
        commonWords: ["national", "nation"],
        uncommonWords: ["ulna"],   // in SCOWL 70, not the set
        rareWords: ["talon"],      // in SCOWL 95, not 70
        mythicWords: ["anti"],     // beyond SCOWL 95
        reachableScore: 0
    )

    @Test("classifies a set word as set")
    func setWord() {
        #expect(classifyWord("nation", in: puzzle) == .set)
    }

    @Test("classifies the source word as set, like any other set word")
    func sourceWord() {
        #expect(classifyWord("national", in: puzzle) == .set)
    }

    @Test("classifies a size-70-not-set word as uncommon")
    func uncommon() {
        #expect(classifyWord("ulna", in: puzzle) == .uncommon)
    }

    @Test("classifies a size-95-not-70 word as rare")
    func rare() {
        #expect(classifyWord("talon", in: puzzle) == .rare)
    }

    @Test("classifies an ENABLE-beyond-95 word as mythic")
    func mythic() {
        #expect(classifyWord("anti", in: puzzle) == .mythic)
    }
}
