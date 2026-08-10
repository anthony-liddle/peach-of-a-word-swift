/// A source of words formable from a rack. Backed by a baked word list.
///
/// A Swift `protocol` is the near-exact analogue of the TypeScript `interface`
/// this ports. The difference that matters: a Swift type must *declare* that it
/// conforms, whereas TypeScript interfaces are structural: anything with a
/// matching shape satisfies them implicitly.
public protocol WordSource {
    /// All words in this source, length >= the minimum, formable from the rack.
    func formableWords(rack: String) -> [String]
}

/// The validation dictionary (ENABLE). Adds single-word membership.
///
/// Named `ValidationDictionary`, not `Dictionary`: Swift's standard library
/// already owns that name. This is the first place the port could not keep the
/// TypeScript's naming.
public protocol ValidationDictionary: WordSource {
    /// True if the word is in the dictionary (ignores formability).
    func has(_ word: String) -> Bool
}

/// A fully resolved puzzle: a source word and everything derived from it.
///
/// A `struct`, so it has value semantics: passing one to a function hands over
/// an independent copy, and there is no way for a caller to mutate a Puzzle
/// another part of the program is holding. The TypeScript approximated this
/// with `readonly` fields and `ReadonlySet`, which the compiler enforces but
/// which vanish at runtime.
public struct Puzzle: Sendable, Equatable {
    /// The 8-letter answer.
    public let sourceWord: String
    /// The 8 rack letters, sorted for a stable canonical form.
    public let letters: String
    /// Every ENABLE word formable from the rack (the full validation set).
    public let validationWords: Set<String>
    /// Every set word formable from the rack. The completion denominator, by count.
    public let commonWords: Set<String>
    /// Off-page finds in SCOWL size 70 but not in the set. The first rung.
    /// Disjoint from `commonWords`, `rareWords`, and `mythicWords`; together
    /// the four partition the validation set.
    public let uncommonWords: Set<String>
    /// Off-page finds in SCOWL size 95 but not in size 70. The second rung.
    public let rareWords: Set<String>
    /// Off-page finds valid in ENABLE but beyond SCOWL size 95. The top rung.
    public let mythicWords: Set<String>
    /// Par: the total SET points available on this rack, every common word
    /// scored by length, source word included, with no rarity bonuses. The
    /// denominator the named points ladder runs against, so each rack is judged
    /// against its own ceiling.
    ///
    /// This is the single most load-bearing decision in the model. Note that
    /// the TypeScript's doc comment on this field claims something different
    /// ("every findable word scored by length plus its rarity bonus") and is
    /// stale; `puzzle.ts` computes set points only. No TypeScript test catches
    /// the divergence, because `tiers.test.ts` hand-builds its fixture.
    public let reachableScore: Int

    public init(
        sourceWord: String,
        letters: String,
        validationWords: Set<String>,
        commonWords: Set<String>,
        uncommonWords: Set<String>,
        rareWords: Set<String>,
        mythicWords: Set<String>,
        reachableScore: Int
    ) {
        self.sourceWord = sourceWord
        self.letters = letters
        self.validationWords = validationWords
        self.commonWords = commonWords
        self.uncommonWords = uncommonWords
        self.rareWords = rareWords
        self.mythicWords = mythicWords
        self.reachableScore = reachableScore
    }
}
