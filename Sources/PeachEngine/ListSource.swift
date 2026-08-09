/// A `WordSource` backed by an in-memory word list.
///
/// The engine talks only to the `WordSource` / `ValidationDictionary`
/// protocols, so this list-backed form (used for the baked assets and for
/// tests) can be swapped for a sorted binary file or SQLite later without the
/// engine noticing.
public struct ListWordSource: WordSource {
    private let words: [String]

    public init(_ words: some Sequence<String>) {
        self.words = Array(words)
    }

    public func formableWords(rack: String) -> [String] {
        formableFrom(rack: rack, words: words)
    }
}

/// A `ValidationDictionary` (a `WordSource` plus membership) backed by a list.
public struct ListDictionary: ValidationDictionary {
    private let words: Set<String>

    public init(_ words: some Sequence<String>) {
        self.words = Set(words)
    }

    public func has(_ word: String) -> Bool {
        words.contains(word)
    }

    // Iterating a Set, so the returned order is unspecified. Every caller feeds
    // the result straight into a Set, so the order never escapes.
    public func formableWords(rack: String) -> [String] {
        formableFrom(rack: rack, words: words)
    }
}
