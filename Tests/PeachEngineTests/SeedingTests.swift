import Foundation
import Testing
@testable import PeachEngine

// `Seeding` is DEBUG only, like the seeds that call it, so this suite is too.
// Without the gate `swift test -c release` does not build.
#if DEBUG

/// The seeds' way back to a phone that has never been played.
///
/// Issue #73: the `bea` seed wrote its inputs on top of whatever the simulator
/// already held. A sweep of positive `-dayOffset` launches had left words on
/// thirty days after today, those filled the back-fill's fourteen-day walk, and
/// no basket day was rebuilt. `eraseAll` is what the seed now calls first, so
/// this pins that it leaves nothing behind that the back-fill could read.
@Suite("seeding erases the store")
struct SeedingTests {
    let storage = GameStorage(store: InMemoryStore())
    static let today = 268

    @Test("words on later days, the streak and the outcomes are all gone")
    func eraseAllLeavesAFreshInstall() {
        // The shape that broke the test: words dated after today in both
        // stores, a live streak, a written outcome map and a spent back-fill.
        for day in (Self.today - 3)...(Self.today + 20) {
            storage.saveDayProgress(dayIndex: day, sourceWord: "w\(day)", found: ["a"],
                                    fromArchive: day != Self.today)
        }
        _ = storage.adoptStreak(count: 5, lastClearedDayIndex: Self.today - 1,
                                todayIndex: Self.today)
        storage.seeding.replaceOutcomes([Self.today - 2: DayOutcome(
            reached: DayOutcome.cleared, on: Self.today - 2, fromStreak: false)])
        _ = storage.backFillOutcomes(firstPlayableDayIndex: 173) { _, _, _ in nil }
        #expect(!storage.daysWithProgress().isEmpty)
        #expect(storage.hasBackFilledOutcomes())

        storage.seeding.eraseAll()

        #expect(storage.daysWithProgress().isEmpty, "a day's words survived the erase")
        #expect(storage.allOutcomes().isEmpty, "an outcome survived the erase")
        #expect(storage.currentStreak(todayIndex: Self.today) == 0, "the streak survived")
        #expect(!storage.hasBackFilledOutcomes(), "the back-fill still reads as spent")
    }
}
#endif
