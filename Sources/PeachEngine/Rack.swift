/// Rack ordering that will not hand the player the crown.
///
/// The rack shows the source word's letters SORTED (see `PuzzleBuilder`), so the
/// identity permutation spells `aeemnptv`, not `pavement`, and is harmless. What
/// gives the day away is a permutation that happens to undo that sort. With one
/// repeated letter that is a 1-in-20,160 event per draw, and it reached a real
/// player: the rack read PAVE / MENT.
///
/// Two things are guarded, and one predicate covers both. In the narrow rack the
/// first four tiles are a visible top row; PAVE above a scrambled MENT is most of
/// the answer on its own. A full spell necessarily begins with that same prefix,
/// so testing the prefix catches the whole-word case too.

/// Tiles per row in the narrow rack grid. Mirrors `RACK_ROW` in the TypeScript.
public let rackRow = 4

/// True when the rack, read left to right, leads with the source word.
///
/// `letters` is the sorted rack; `order` indexes into it. Comparing the rendered
/// string against the source word is the honest test: comparing `order` against
/// the identity permutation would test the wrong thing entirely.
public func rackGivesAway(
    order: [Int],
    letters: String,
    word: String
) -> Bool {
    let rack = Array(letters)
    let crown = Array(word)
    let span = min(rackRow, min(order.count, crown.count))
    // A rack with nothing on it gives nothing away. Stated rather than left to
    // fall out of the loop, because the TypeScript has to agree here too and an
    // empty-span disagreement is exactly the kind of divergence no eight-letter
    // fixture would ever reach.
    if span == 0 { return false }
    for i in 0..<span {
        if rack[order[i]] != crown[i] { return false }
    }
    return true
}

/// Break a giving-away order by moving a differing letter to the front.
///
/// A total escape hatch for the redraw loop below, so it cannot spin. It can
/// only fail if every tile carries `word[0]`, which no eight-letter source word
/// does, and in that case there is no non-revealing order to find anyway.
private func forceDiffer(
    order: [Int],
    letters: String,
    word: String
) -> [Int] {
    var out = order
    let rack = Array(letters)
    let first = Array(word)[0]
    if let swap = out.firstIndex(where: { rack[$0] != first }), swap > 0 {
        out.swapAt(0, swap)
    }
    return out
}

/// A guarded rack order, redrawing from `draw` until the rack keeps its secret.
///
/// The caller owns the stream: the daily passes a seeded one so every player
/// gets the same rack, and the Shuffle button passes the system RNG so a press
/// still surprises. Both reject the same orders, which is the point of sharing
/// this. Expected draws is 1.001, so the loop is a formality in practice; the
/// bound and the fallback are there so it is a formality in theory too.
public func guardedRackOrder(
    letters: String,
    word: String,
    draw: (Int) -> [Int]
) -> [Int] {
    for attempt in 0..<32 {
        let order = draw(attempt)
        if !rackGivesAway(order: order, letters: letters, word: word) {
            return order
        }
    }
    return forceDiffer(order: draw(0), letters: letters, word: word)
}

/// A 32-bit FNV-1a hash of the source word.
///
/// `Math.imul(hash, 0x01000193) >>> 0` in the TypeScript. `Math.imul` genuinely
/// IS a wrapping 32-bit multiply, so `&*` is the faithful port here — unlike
/// `seedForCycle` in Daily.swift, where the JavaScript is a Double multiply and
/// `&*` would silently produce different numbers. The two cases look alike and
/// are not; that is why this note exists.
///
/// The seed comes from the WORD, not the day index. Two day indices exist
/// (`dailyEpoch` selects the crown, `storageEpoch` keys progress) and the first
/// is explicitly re-anchorable by a calendar regeneration, which would silently
/// re-deal every rack. The word is the thing the rack is actually made of, so
/// seeding from it survives re-anchoring and the append-only calendar alike.
func seedForWord(_ word: String) -> UInt32 {
    var hash: UInt32 = 0x811c_9dc5
    for scalar in word.unicodeScalars {
        hash ^= UInt32(scalar.value)
        hash = hash &* 0x0100_0193
    }
    return hash
}

/// Salt the word seed per redraw, so attempt N is a different permutation.
func seedForAttempt(_ word: String, attempt: Int) -> UInt32 {
    // `(seed + attempt * 0x9e3779b1) >>> 0` is Double arithmetic followed by a
    // mod-2^32 coercion, NOT wrapping 32-bit maths. Widening to Int64 first
    // reproduces it exactly, the same fix `seedForCycle` needs.
    let mixed = Int64(seedForWord(word)) + Int64(attempt) * 0x9e37_79b1
    return UInt32(truncatingIfNeeded: mixed)
}

/// The daily rack order: seeded, so identical for every player on a given day,
/// and guarded, so it never leads with the crown.
///
/// "Take the next seeded permutation" rather than "reshuffle on first open" is
/// load-bearing. A reshuffle would be a fresh random draw per device, which is
/// exactly the bug this replaces; walking the seed stream keeps the rack a
/// function of the word alone.
public func dailyRackOrder(letters: String, word: String) -> [Int] {
    guardedRackOrder(letters: letters, word: word) { attempt in
        seededPermutation(letters.count, seed: seedForAttempt(word, attempt: attempt))
    }
}
