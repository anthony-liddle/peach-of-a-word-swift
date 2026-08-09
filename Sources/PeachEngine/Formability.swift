/// Count of each letter a-z, held inline as a fixed-size value type.
///
/// `InlineArray<26, Int8>` is a fixed-size array stored *in* the struct rather
/// than in a separately allocated heap buffer, so constructing one allocates
/// nothing. Swift's ordinary `Array` cannot do this: it is a reference to a
/// heap buffer with copy-on-write semantics, which is what `letterCountsArray`
/// below deliberately uses so the two can be compared. TypeScript's
/// `Int8Array(26)` is always the heap-allocated shape.
///
/// Requires macOS 26, which is why Package.swift pins that platform.
public struct LetterCounts: Sendable {
    private var counts: InlineArray<26, Int8> = .init(repeating: 0)

    /// Non-letters and non-ASCII bytes are ignored, matching the TypeScript.
    public init(_ word: String) {
        // Iterating `.utf8` rather than `Character` is both faster and closer
        // to the original's `charCodeAt`. Swift's `Character` is a grapheme
        // cluster — the right default for text, the wrong unit here.
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

/// The literal translation of the TypeScript `Int8Array(26)`: a heap-allocated
/// buffer per call. Kept alongside `LetterCounts` only so Task 15 can measure
/// what the allocation costs across the full boundary list.
public func letterCountsArray(_ word: String) -> [Int8] {
    var counts = [Int8](repeating: 0, count: 26)
    for byte in word.utf8 where byte >= 97 && byte <= 122 {
        counts[Int(byte) - 97] += 1
    }
    return counts
}

/// `canForm` over the array-backed representation. Must agree with
/// `LetterCounts.canForm` on every input; there is a test that says so.
public func canFormArray(_ rackCounts: [Int8], _ word: String) -> Bool {
    let need = letterCountsArray(word)
    for i in 0..<26 where need[i] > rackCounts[i] {
        return false
    }
    return true
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
