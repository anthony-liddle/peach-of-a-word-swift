import Foundation
import Testing
@testable import PeachEngine

@Suite("dailySourceWord")
struct DailySourceWordTests {
    let calendar = ["alpha", "bravo", "charlie", "delta", "echo"]
    let epoch = EpochDate(year: 2026, month: 1, day: 1)
    let utc = TimeZone(identifier: "UTC")!

    /// Day `n` of the sequence, as a Date at noon UTC.
    func day(_ n: Int) -> Date {
        var cal = Foundation.Calendar(identifier: .gregorian)
        cal.timeZone = utc
        let start = cal.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 12))!
        return cal.date(byAdding: .day, value: n, to: start)!
    }

    func word(on n: Int) throws -> String {
        try dailySourceWord(calendar: calendar, date: day(n), epoch: epoch, timeZone: utc)
    }

    @Test("is deterministic for a given date")
    func deterministic() throws {
        #expect(try word(on: 166) == (try word(on: 166)))
    }

    @Test("maps the first cycle to the frozen calendar order")
    func firstCycle() throws {
        #expect(try (0..<calendar.count).map { try word(on: $0) } == calendar)
    }

    @Test("yields a fixed first-cycle word, unaffected by appending words after it")
    func frozen() throws {
        #expect(try word(on: 2) == "charlie")
        let appended = calendar + ["foxtrot", "golf"]
        #expect(try dailySourceWord(calendar: appended, date: day(2), epoch: epoch, timeZone: utc)
                == "charlie")
    }

    @Test("reshuffles into a new pass after exhaustion")
    func reshuffles() throws {
        let n = calendar.count
        let firstPass = try (0..<n).map { try word(on: $0) }
        let secondPass = try (0..<n).map { try word(on: n + $0) }
        #expect(secondPass.sorted() == calendar.sorted())
        #expect(secondPass != firstPass)
    }

    @Test("does not repeat a word across a cycle boundary")
    func boundary() throws {
        let n = calendar.count
        #expect(try word(on: n) != (try word(on: n - 1)))
        #expect(try word(on: 2 * n) != (try word(on: 2 * n - 1)))
    }

    @Test("floors pre-epoch dates at day zero rather than reading backwards")
    func preEpoch() throws {
        #expect(try word(on: -5) == calendar[0])
    }

    @Test("throws on an empty calendar")
    func empty() {
        #expect(throws: EngineError.emptyCalendar) {
            try dailySourceWord(calendar: [], date: day(0), epoch: epoch, timeZone: utc)
        }
    }

    // seedForCycle is a Double multiply then a mod-2^32 coercion in JavaScript,
    // NOT a wrapping 32-bit multiply. Porting it as &* would silently diverge.
    //
    // These values came out of Node. The plan's oracle contingency was applied
    // (the generated fixture covers dayIndex only), so the PRNG paths are
    // pinned by hardcoded Node output instead: same tripwire, no extra
    // infrastructure. See docs/REPORT.md.
    @Test("matches the TypeScript seedForCycle exactly",
          arguments: [(1, UInt32(2_654_435_761)), (2, 1_013_904_226),
                      (3, 3_668_339_987), (1000, 145_972_072)])
    func seedsMatchJavaScript(cycle: Int, expected: UInt32) {
        #expect(seedForCycle(cycle) == expected)
    }

    @Test("matches the TypeScript cycleOrder exactly")
    func cycleOrderMatchesJavaScript() {
        #expect(cycleOrder(cycle: 0, n: 5) == [0, 1, 2, 3, 4])  // identity
        #expect(cycleOrder(cycle: 1, n: 5) == [3, 4, 0, 1, 2])
        #expect(cycleOrder(cycle: 2, n: 5) == [0, 1, 3, 2, 4])
        #expect(cycleOrder(cycle: 3, n: 5) == [2, 0, 3, 4, 1])
        // Degenerate sizes: the boundary swap must not run.
        #expect(cycleOrder(cycle: 1, n: 1) == [0])
        #expect(cycleOrder(cycle: 1, n: 2) == [0, 1])
        // The real calendar size.
        #expect(Array(cycleOrder(cycle: 1, n: 626).prefix(8))
                == [247, 540, 229, 208, 595, 334, 214, 136])
    }
}

@Suite("dailySourceWord against the shipped calendar")
struct ShippedCalendarTests {
    struct CalendarFile: Codable { let words: [String] }

    @Test("reads the frozen 626-word calendar and serves day zero")
    func shipped() throws {
        let url = dataDirectory.appendingPathComponent("daily-calendar.json")
        let file = try JSONDecoder().decode(CalendarFile.self, from: try Data(contentsOf: url))
        #expect(file.words.count == 626)
        #expect(Array(file.words.prefix(3)) == ["mnemonic", "validity", "conflict"])

        var cal = Foundation.Calendar(identifier: .gregorian)
        let utc = TimeZone(identifier: "UTC")!
        cal.timeZone = utc
        let epochDay = cal.date(from: DateComponents(year: 2026, month: 6, day: 23, hour: 12))!
        #expect(try dailySourceWord(calendar: file.words, date: epochDay,
                                    epoch: dailyEpoch, timeZone: utc) == "mnemonic")
    }

    /// The share's off-page find count rests on this.
    ///
    /// The count is `uncommon + rare + mythic`, and that equals the off-page
    /// finds only if the source word is a set word: `commonWords` is the common
    /// pool intersected with the formable set, so a source word outside the pool
    /// would be graded on the rarity ladder instead. `createPuzzle` guarantees
    /// the source word is in `validationWords` (it is formable from itself) and
    /// says nothing about `commonWords`, so this is a fact about the shipped
    /// calendar rather than a property of the builder.
    ///
    /// It also decides whether the two repos agree: the web skips set words
    /// before bucketing, while the Swift app excludes the source word by giving
    /// it its own category. Those two rules produce the same counts exactly when
    /// this holds, so a calendar word outside the pool would make the phone's
    /// share and the web's disagree by one on the same board.
    @Test("every calendar source word is a set word on its own rack")
    func sourceWordsAreSetWords() throws {
        let url = dataDirectory.appendingPathComponent("daily-calendar.json")
        let file = try JSONDecoder().decode(CalendarFile.self, from: try Data(contentsOf: url))
        let pool = Set(try readWordList("common-pool.txt", in: dataDirectory))
        #expect(wordsOutside(pool, in: file.words) == [])
    }

    /// The guard's negative control: it has to be able to fail.
    @Test("the guard catches a source word the common pool does not hold")
    func guardCatchesOutsider() {
        #expect(wordsOutside(["apple", "pear"], in: ["apple", "quince"]) == ["quince"])
    }
}

/// Source words the pool does not contain, in calendar order.
private func wordsOutside(_ pool: some Collection<String>, in words: [String]) -> [String] {
    let pool = Set(pool)
    return words.filter { !pool.contains($0) }
}
