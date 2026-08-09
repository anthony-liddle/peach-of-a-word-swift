import Testing
@testable import PeachEngine

@Suite("EndlessSource")
struct EndlessSourceTests {
    // The calendar holds only eligible words; a sub-floor word is never in it.
    let calendar = ["alpha", "bravo", "charlie", "delta", "echo"]

    /// A deterministic stand-in for a random source, so every draw is
    /// reproducible. A struct conforming to RandomSource, so a copy of the
    /// EndlessSource holding it forks this too.
    struct TestRNG: RandomSource {
        private var a: UInt32
        init(seed: UInt32 = 1) { a = seed }
        mutating func next() -> Double {
            a = a &* 1_664_525 &+ 1_013_904_223
            return Double(a) / 4_294_967_296.0
        }
    }

    /// Build a source wired to a seeded test RNG.
    func source(seed: UInt32 = 1, exclude: String? = nil,
                previous: String? = nil,
                calendar: [String]? = nil) throws -> EndlessSource<TestRNG> {
        try EndlessSource(calendar: calendar ?? self.calendar,
                          exclude: exclude, previous: previous,
                          rng: TestRNG(seed: seed))
    }

    // `inout` is Swift's explicit pass-by-reference marker, needed because
    // `next()` is mutating and this helper has to advance the caller's copy
    // rather than a local one. Part of the cost of the value-semantics choice.
    func draw(_ s: inout EndlessSource<TestRNG>, _ count: Int) -> [String] {
        (0..<count).map { _ in s.next() }
    }

    @Test("only ever draws a word from the calendar (never a sub-floor word)")
    func staysInPool() throws {
        var s = try source()
        let pool = Set(calendar)
        for word in draw(&s, 200) { #expect(pool.contains(word)) }
    }

    @Test("yields every word exactly once across a full pass")
    func fullPass() throws {
        var s = try source()
        #expect(draw(&s, calendar.count).sorted() == calendar.sorted())
    }

    @Test("never repeats a word before the pool is exhausted")
    func noEarlyRepeat() throws {
        var s = try source(seed: 7)
        for _ in 0..<4 {
            #expect(Set(draw(&s, calendar.count)).count == calendar.count)
        }
    }

    @Test("does not repeat the previous word across a pass boundary",
          arguments: UInt32(1)...UInt32(25))
    func passBoundary(seed: UInt32) throws {
        var s = try source(seed: seed)
        let drawn = draw(&s, calendar.count + 1)
        #expect(drawn[calendar.count] != drawn[calendar.count - 1])
    }

    @Test("never draws the excluded daily word")
    func excluded() throws {
        var s = try source(seed: 3, exclude: "charlie")
        for word in draw(&s, 200) { #expect(word != "charlie") }
    }

    @Test("yields every remaining word exactly once per pass when one is excluded")
    func excludedPass() throws {
        var s = try source(seed: 3, exclude: "charlie")
        let remaining = calendar.filter { $0 != "charlie" }
        #expect(draw(&s, remaining.count).sorted() == remaining.sorted())
    }

    @Test("does not open with the word already on screen",
          arguments: UInt32(1)...UInt32(25))
    func notPrevious(seed: UInt32) throws {
        var s = try source(seed: seed, previous: "delta")
        #expect(s.next() != "delta")
    }

    @Test("is deterministic and reproducible for a given rng")
    func reproducible() throws {
        var a = try source(seed: 9)
        var b = try source(seed: 9)
        #expect(draw(&a, 17) == draw(&b, 17))
    }

    @Test("reshuffles rather than replaying the same order every pass")
    func reshuffles() throws {
        var s = try source(seed: 4)
        let first = draw(&s, calendar.count)
        #expect(draw(&s, calendar.count) != first)
    }

    @Test("falls back to the whole calendar when the exclusion would empty it")
    func fallback() throws {
        var s = try source(exclude: "alpha", calendar: ["alpha"])
        #expect(s.next() == "alpha")
    }

    @Test("throws on an empty calendar")
    func emptyCalendar() {
        #expect(throws: EngineError.emptyCalendar) {
            _ = try EndlessSource(calendar: [], exclude: nil, previous: nil,
                                  rng: TestRNG())
        }
    }

    // No TypeScript counterpart, and the whole reason for choosing a struct: in
    // TypeScript the source is a closure, so handing it to two callers hands
    // them one shared cursor. Here a copy is an independent stream.
    //
    // The draws deliberately cross a pass boundary. Staying inside one pass
    // would prove nothing: both copies would just be reading the same
    // already-computed `order` at the same position. Only a reshuffle calls
    // `rng.next()`, so only crossing the boundary shows whether the generator
    // forked with the copy or is still shared. It is exactly the assertion that
    // fails if `rng` is a captured closure instead of a stored RandomSource.
    @Test("a copy is an independent stream, across a pass boundary")
    func valueSemantics() throws {
        var a = try source(seed: 11)
        _ = draw(&a, 3)       // mid-pass, cursor at 3 of 5
        var b = a             // a copy, not a reference
        #expect(draw(&a, 8) == draw(&b, 8))  // 8 draws: two reshuffles each
    }
}
