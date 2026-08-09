/// Sort a word's letters for a stable canonical rack form.
private func sortLetters(_ word: String) -> String {
    String(word.sorted())
}

/// Summed find score for a band of words at a known rung.
private func bandScore(_ words: some Sequence<String>, rung: Rung) -> Int {
    words.reduce(0) { $0 + findScore($1, rung: rung) }
}

/// Build a full puzzle from a source word.
///
/// - `validationWords`: every ENABLE word formable from the rack.
/// - `commonWords`: every set word formable from the rack, intersected with the
///   validation set so the completion denominator is always achievable.
/// - the rarity ladder: every formable validation word outside the set, graded
///   by SCOWL membership. The two rarity pools carry the words BEYOND a SCOWL
///   size band (the compact complement: ENABLE minus the band), so:
///     - uncommon = in size 70 (not beyond 70), and not in the set
///     - rare     = beyond size 70 but in size 95 (not beyond 95)
///     - mythic   = beyond size 95
///   The four bands are disjoint and together partition the validation set.
public func createPuzzle(
    sourceWord: String,
    dictionary: some ValidationDictionary,
    commonPool: some WordSource,
    beyond70Pool: some WordSource,
    beyond95Pool: some WordSource
) -> Puzzle {
    let validationWords = Set(dictionary.formableWords(rack: sourceWord))
    // The source word is in ENABLE and formable from itself, so it is
    // guaranteed present; assert nothing, just rely on the formable set.
    let commonWords = Set(commonPool.formableWords(rack: sourceWord)
        .filter { validationWords.contains($0) })
    let beyond70 = Set(beyond70Pool.formableWords(rack: sourceWord)
        .filter { validationWords.contains($0) })
    let beyond95 = Set(beyond95Pool.formableWords(rack: sourceWord)
        .filter { validationWords.contains($0) })

    // In size 70 (not beyond it) and not a set word.
    let uncommonWords = validationWords.subtracting(beyond70).subtracting(commonWords)
    // Beyond 70 but within 95. Set words live in size 70, so none leak in here.
    let rareWords = beyond70.subtracting(beyond95)
    // Beyond 95. Set words never reach this far.
    let mythicWords = beyond95

    // Par: the set points — every common word at length, source word included,
    // no rarity bonuses. The named ladder runs against this. Off-page finds
    // still earn their points into the score, so they climb faster and overflow
    // the bar past the top named rank, but they are NOT part of the
    // denominator. Using the huge ENABLE-union-SCOWL-95 off-page tail as the
    // ceiling would make the ladder unclimbable; set points are the stable,
    // per-rack-consistent scale. The set defines what a full climb is worth,
    // not what must be found, so no unfound word gates the climb.
    let reachableScore = bandScore(commonWords, rung: .set)

    return Puzzle(
        sourceWord: sourceWord,
        letters: sortLetters(sourceWord),
        validationWords: validationWords,
        commonWords: commonWords,
        uncommonWords: uncommonWords,
        rareWords: rareWords,
        mythicWords: mythicWords,
        reachableScore: reachableScore
    )
}
