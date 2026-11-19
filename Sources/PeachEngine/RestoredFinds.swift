/// The saved finds a board restores when its day opens: those its word lists
/// still accept.
///
/// **The denied half of the two-list rule.** A word that leaves the lists, as
/// orchard v1.11.2's hate words did, goes from a saved day when the day opens,
/// and takes its points with it. The web has done this since it saved finds,
/// in `buildSlice`. The app kept such a word and graded it Mythic, since
/// `classifyWord` grades anything outside the three bands that way, so a word
/// a player found before it was denied would have climbed a rung instead of
/// going. The next save writes the list without it.
///
/// The other half, words retired rather than denied keeping their old grade,
/// comes with the retired list. There is none yet, so every word the lists no
/// longer accept is one that was denied.
public func restoredFinds(_ saved: [String], on puzzle: Puzzle) -> [String] {
    saved.filter { puzzle.validationWords.contains($0) }
}
