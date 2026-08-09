@testable import PeachEngine

// The web repo's puzzle.test.ts fixture, shared between PuzzleTests and
// ValidateTests so both grade against the same rack.
enum Fixture {
    static let enable = [
        "serenade", "sneer", "eased", "sea", "near", "dean", "sane",
        "zebra",  // not formable from serenade (needs z, b)
        "ad",     // too short
    ]
    static let common = ["sea", "near", "dean", "serenade"]
    // 'sneer' is in size 70       -> uncommon (not beyond 70)
    // 'eased' is beyond 70, in 95 -> rare
    // 'sane'  is beyond 95        -> mythic
    static let beyond70 = ["eased", "sane"]
    static let beyond95 = ["sane"]

    static let puzzle = createPuzzle(
        sourceWord: "serenade",
        dictionary: ListDictionary(enable),
        commonPool: ListWordSource(common),
        beyond70Pool: ListWordSource(beyond70),
        beyond95Pool: ListWordSource(beyond95)
    )
}
