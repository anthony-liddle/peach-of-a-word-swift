/// Count of each letter a-z in a word.
///
/// Backed by a heap-allocated `[Int8]`. This was previously an
/// `InlineArray<26, Int8>`, a fixed-size array stored inline in the struct with
/// no allocation, which measured 2.5x faster over a full pass of the boundary
/// list (16.7 ms against 41.6 ms, release, M3 Pro).
///
/// The inline version was dropped anyway. `InlineArray` requires iOS 26 and
/// macOS 26, and it was the only thing in this package that did, so it alone
/// set the deployment floor. Twenty five milliseconds on an operation that runs
/// once per puzzle does not buy an OS minimum that would exclude most devices
/// in use, including quite possibly the one phone this game is being built for.
///
/// The measurement is kept in docs/MEASUREMENTS.md rather than deleted. It is
/// still true, and it is still the most interesting number in the port: Swift's
/// default value type was the fast option and the literal translation of the
/// TypeScript `Int8Array(26)` was the slow one. The floor is simply worth more
/// than the milliseconds.
public struct LetterCounts: Sendable {
    private var counts = [Int8](repeating: 0, count: 26)

    /// Non-letters and non-ASCII bytes are ignored, matching the TypeScript.
    public init(_ word: String) {
        // Iterating `.utf8` rather than `Character` is both faster and closer
        // to the original's `charCodeAt`. Swift's `Character` is a grapheme
        // cluster, which is the right default for text and the wrong unit here.
        for byte in word.utf8 where byte >= 97 && byte <= 122 {
            counts[Int(byte) - 97] += 1
        }
    }

    /// True if a word needing `need` can be spelled from this rack, each tile
    /// used at most once.
    public func canForm(_ need: LetterCounts) -> Bool {
        for i in 0..<26 where need.counts[i] > counts[i] {
            return false
        }
        return true
    }
}

/// Filter a word list to those formable from the rack, length >= the minimum.
/// The rack's letter counts are computed once for the whole pass.
///
/// `some Sequence<String>` is an opaque parameter type: the caller may pass an
/// Array, a Set, or anything else that iterates Strings, and the compiler
/// specialises for the concrete type. It is the Swift answer to TypeScript's
/// `Iterable<string>`, but resolved at compile time rather than at runtime.
public func formableFrom(rack: String, words: some Sequence<String>) -> [String] {
    let rackCounts = LetterCounts(rack)
    var out: [String] = []
    for word in words where word.count >= minWordLength && rackCounts.canForm(LetterCounts(word)) {
        out.append(word)
    }
    return out
}
