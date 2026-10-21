import Testing
@testable import PeachEngine

/// The title's "A day at random": before today, unfinished first.
@Suite("a past day at random")
struct RandomPastDayTests {
    /// SplitMix64, so a draw is the same on every run.
    struct Seeded: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
    }

    let first = 173
    let today = 200

    func finished(_ day: Int) -> DayOutcome {
        DayOutcome(reached: DayOutcome.cleared, on: day, fromStreak: false)
    }

    func draws(_ outcomes: [Int: DayOutcome], count: Int = 500) -> [Int?] {
        var generator = Seeded(state: 21)
        return (0..<count).map { _ in
            randomPastDay(firstPlayableDayIndex: first, todayIndex: today,
                          outcomes: outcomes, using: &generator)
        }
    }

    @Test("never today, never a day to come, never before the first board")
    func onlyThePast() {
        // Today unplayed and a future day with a record: neither may be drawn.
        let picks = draws([today + 3: DayOutcome(reached: DayOutcome.played, on: today, fromStreak: false)])
        #expect(picks.allSatisfy { $0 != nil })
        #expect(picks.compactMap { $0 }.allSatisfy { $0 >= first && $0 < today })
    }

    @Test("prefers a day not finished, whether never played or started and left")
    func prefersUnfinished() {
        var outcomes: [Int: DayOutcome] = [:]
        for day in first..<today { outcomes[day] = finished(day) }
        outcomes[180] = nil
        outcomes[190] = DayOutcome(reached: DayOutcome.played, on: 190, fromStreak: false)
        #expect(Set(draws(outcomes).compactMap { $0 }) == [180, 190])
    }

    @Test("falls back to any past day when every one is finished")
    func fallsBack() {
        var outcomes: [Int: DayOutcome] = [:]
        for day in first..<today { outcomes[day] = finished(day) }
        outcomes[195] = DayOutcome(reached: DayOutcome.basket, on: 195, fromStreak: false)
        let picks = draws(outcomes).compactMap { $0 }
        #expect(picks.count == 500)
        #expect(picks.allSatisfy { $0 >= first && $0 < today })
        // Spread over the past rather than stuck on one day.
        #expect(Set(picks).count > 10)
    }

    @Test("draws nothing when there is no past day")
    func noPast() {
        var generator = Seeded(state: 1)
        #expect(randomPastDay(firstPlayableDayIndex: first, todayIndex: first,
                              outcomes: [:], using: &generator) == nil)
    }
}
