/// Why a guess was accepted or rejected.
///
/// A Swift enum with associated values: the discriminated union the TypeScript
/// approximates with a `kind` field. The difference is enforcement. In
/// TypeScript, reading `.score` off a result requires narrowing by `kind`
/// first, and the narrowing is a convention the compiler checks only where you
/// remember to ask. Here, `score` does not exist except inside a `case .valid`
/// binding: there is nothing to read on a `.tooShort`.
///
/// The same shape is what stopped the daily share from leaking the answer in
/// the web version: a union where the source word simply is not a field on the
/// daily case, so no amount of careless access can reach it.
public enum GuessResult: Sendable, Equatable {
    case valid(word: String, score: Int, rung: Rung, isSourceWord: Bool)
    case tooShort
    case notAWord
    case alreadyFound
}

/// Normalize raw input to the canonical form used everywhere: lowercase a-z.
public func normalizeGuess(_ input: String) -> String {
    // The TypeScript used `.toLowerCase().replace(/[^a-z]/g, '')`. Filtering
    // over `unicodeScalars` avoids pulling in a regex for a one-line character
    // test, and keeps it to ASCII, which is all the word lists contain.
    String(String.UnicodeScalarView(
        input.lowercased().unicodeScalars.filter { $0 >= "a" && $0 <= "z" }
    ))
}

/// Validate a guess against a resolved puzzle and the set already found.
///
/// A guess is valid when it is 3+ letters, formable from the rack, and in
/// ENABLE. The puzzle's `validationWords` already encodes all three (it is the
/// formable ENABLE set), so membership there is the single source of truth.
public func validateGuess(
    _ input: String,
    puzzle: Puzzle,
    found: Set<String>
) -> GuessResult {
    let word = normalizeGuess(input)

    if word.count < minWordLength { return .tooShort }
    if !puzzle.validationWords.contains(word) { return .notAWord }
    if found.contains(word) { return .alreadyFound }

    let rung = classifyWord(word, in: puzzle)
    return .valid(
        word: word,
        score: findScore(word, rung: rung),
        rung: rung,
        isSourceWord: word == puzzle.sourceWord
    )
}
