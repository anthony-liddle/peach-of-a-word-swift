/// Points for a single word, by its length alone (no rarity bonus).
public func scoreWord(_ word: String) -> Int {
    scoreForLength(word.count)
}

/// Points for a found word: its length score plus the rarity bonus for its rung.
///
/// This is the single scoring path for everything the player earns, so the
/// score, the bar, the glossary, the share, and the reachable total all agree.
/// A set word gets no bonus (the on-page baseline); off-page rungs pay more.
public func findScore(_ word: String, rung: Rung) -> Int {
    scoreForLength(word.count) + rung.bonus
}
