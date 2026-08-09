/// Set size for a source word, computed through the engine's own `createPuzzle`
/// so it matches the live game exactly.
///
/// This is `commonWords.count`: the completion denominator the "X of Y" counter
/// shows, crown-inclusive (the source word is itself a set word for any common
/// crown). Reused by the calendar generator and the eligibility floor.
///
/// NEVER reimplement the set rules elsewhere. That warning survives the port
/// because it is the fossil of a real bug: two computations of the same fact
/// that agreed by coincidence until they didn't.
public func sourceSetSize(
    _ word: String,
    dictionary: some ValidationDictionary,
    commonPool: some WordSource,
    beyond70Pool: some WordSource,
    beyond95Pool: some WordSource
) -> Int {
    createPuzzle(
        sourceWord: word,
        dictionary: dictionary,
        commonPool: commonPool,
        beyond70Pool: beyond70Pool,
        beyond95Pool: beyond95Pool
    ).commonWords.count
}

/// True when a source word's set clears `minSetSize` (crown-inclusive).
public func isEligibleSource(
    _ word: String,
    dictionary: some ValidationDictionary,
    commonPool: some WordSource,
    beyond70Pool: some WordSource,
    beyond95Pool: some WordSource
) -> Bool {
    sourceSetSize(word,
                  dictionary: dictionary,
                  commonPool: commonPool,
                  beyond70Pool: beyond70Pool,
                  beyond95Pool: beyond95Pool) >= minSetSize
}

/// The candidates whose set clears the floor, input order preserved.
public func eligibleSourceWords(
    _ candidates: some Sequence<String>,
    dictionary: some ValidationDictionary,
    commonPool: some WordSource,
    beyond70Pool: some WordSource,
    beyond95Pool: some WordSource
) -> [String] {
    candidates.filter {
        isEligibleSource($0,
                         dictionary: dictionary,
                         commonPool: commonPool,
                         beyond70Pool: beyond70Pool,
                         beyond95Pool: beyond95Pool)
    }
}
