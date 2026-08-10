/// Deterministic, seeded shuffling. Shared by the daily cycle reshuffle and the
/// calendar generator so both draw the same stream from the same seed.

/// A source of uniform values in [0, 1).
///
/// `mutating func` rather than a `() -> Double` closure, deliberately: a
/// closure would capture its state by reference, so anything holding one would
/// share a cursor with everything else holding a copy. As a protocol with a
/// mutating requirement, the state lives in the conforming value, and copying
/// the holder forks the stream. `EndlessSource` depends on this.
public protocol RandomSource {
    mutating func next() -> Double
}

/// Deterministic PRNG. Same seed, same stream.
///
/// A faithful port of the JavaScript `mulberry32`, which is written in terms of
/// `Math.imul` (a 32-bit wrapping multiply) and `>>> 0`, an unsigned 32-bit
/// coercion. Swift's `&*` and `&+` are the wrapping operators; the plain `*`
/// and `+` would trap on overflow instead of wrapping, which is Swift being
/// strict about something JavaScript does silently. Doing the arithmetic in
/// `UInt32` makes the `>>> 0` coercions unnecessary: the type already is that.
public struct Mulberry32: RandomSource {
    private var a: UInt32

    public init(seed: UInt32) {
        a = seed
    }

    /// The next value in [0, 1).
    public mutating func next() -> Double {
        a = a &+ 0x6d2b_79f5
        var t = (a ^ (a >> 15)) &* (1 | a)
        t = ((t &+ ((t ^ (t >> 7)) &* (61 | t))) ^ t)
        return Double(t ^ (t >> 14)) / 4_294_967_296.0
    }
}

/// A fresh seeded Fisher-Yates permutation of [0, n). Pure in n and seed.
public func seededPermutation(_ n: Int, seed: UInt32) -> [Int] {
    var rng = Mulberry32(seed: seed)
    var order = Array(0..<n)
    var i = n - 1
    while i > 0 {
        order.swapAt(i, Int(rng.next() * Double(i + 1)))
        i -= 1
    }
    return order
}
