/// A source of endless words that draws without replacement.
///
/// Each pass is a fresh shuffle of the pool, handed out one word at a time, so
/// no word repeats until the pool is exhausted. Reaching the end reshuffles,
/// and the first word of the new pass is forced to differ from the last of the
/// old, the same boundary rule the daily cycle uses. The pool is the eligible
/// daily calendar minus the excluded word, so a sub-floor word can never
/// headline endless and endless can never serve the day's daily rack.
///
/// The daily's `cycleOrder` is deliberately not reused: its cycle 0 is the
/// identity permutation, so endless would replay the committed calendar order,
/// which is precisely the daily's own sequence. Both share `seededPermutation`
/// and the boundary rule; only the ordering of the first pass differs.
///
/// SHAPE NOTE. The TypeScript is a function returning a closure that captures a
/// mutable cursor. Two idiomatic Swift translations exist:
///
///   - this `struct` with a `mutating func`, which has VALUE semantics: a copy
///     is an independent stream, and every holder must declare it `var`;
///   - a `final class`, which has REFERENCE semantics and matches the closure
///     exactly, since two references share one cursor.
///
/// The struct is used here because value semantics are Swift's default and the
/// surprise (that handing a copy to someone else does not share the cursor)
/// is the thing worth understanding early. The cost is real: `var` on every
/// declaration, `inout` to pass it to a helper, a generic parameter that
/// spreads to every type that mentions this one, and no way to share one stream
/// between two owners without deliberately wrapping it.
///
/// The generic `R: RandomSource` is load-bearing, not decoration. A
/// `rng: @escaping () -> Double` parameter would look simpler and would quietly
/// destroy the value semantics: a closure captures its state by reference, so
/// two copies of this struct would share one generator and diverge as soon as
/// either crossed a pass boundary. Storing the generator as a `var` of a
/// protocol type with a `mutating` requirement is what makes a copy a genuine
/// fork.
public struct EndlessSource<R: RandomSource> {
    private let pool: [String]
    private var order: [Int] = []
    private var position: Int
    private var last: String?
    private var rng: R

    /// - Parameters:
    ///   - calendar: the eligible words to draw from.
    ///   - exclude: a word this source must never draw, in practice today's
    ///     daily word.
    ///   - previous: the word already on screen, so the very first draw differs
    ///     from it.
    ///   - rng: the randomness. Advanced once per pass, to seed that pass's
    ///     shuffle. Injectable so tests are reproducible.
    public init(
        calendar: [String],
        exclude: String? = nil,
        previous: String? = nil,
        rng: R
    ) throws {
        guard !calendar.isEmpty else { throw EngineError.emptyCalendar }
        let remaining = calendar.filter { $0 != exclude }
        // A calendar of only the excluded word still has to deal something.
        pool = remaining.isEmpty ? calendar : remaining
        position = pool.count  // Out of range, so the first draw shuffles.
        last = previous
        self.rng = rng
    }

    /// The next word. `mutating` because it advances the cursor; that keyword is
    /// how Swift marks a method that changes a value type, and it is why callers
    /// must hold this in a `var`.
    public mutating func next() -> String {
        let n = pool.count
        if position >= n {
            // Clamped before scaling: `UInt32(1.0 * 4_294_967_296)` overflows
            // and TRAPS. Mulberry32 cannot return 1.0, but an injected
            // RandomSource can, and a crash inside a library is a worse failure
            // than a wrapped seed.
            let unit = min(max(rng.next(), 0), 0.999_999_999_9)
            order = seededPermutation(n, seed: UInt32(unit * 4_294_967_296.0))
            if n > 1 && pool[order[0]] == last {
                order.swapAt(0, 1)
            }
            position = 0
        }
        let word = pool[order[position]]
        position += 1
        last = word
        return word
    }
}
