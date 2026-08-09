/// Classify a found word by precedence: in the set, else the first rarity rung
/// it falls in. The order states the model plainly:
///
///   set  >  uncommon (SCOWL 70)  >  rare (SCOWL 95)  >  mythic (beyond 95)
///
/// The puzzle's four bands are disjoint, so the precedence is belt and braces
/// rather than strictly required. Only ever called on a valid found word, which
/// is in exactly one band.
public func classifyWord(_ word: String, in puzzle: Puzzle) -> Rung {
    if puzzle.commonWords.contains(word) { return .set }
    if puzzle.uncommonWords.contains(word) { return .uncommon }
    if puzzle.rareWords.contains(word) { return .rare }
    return .mythic
}
