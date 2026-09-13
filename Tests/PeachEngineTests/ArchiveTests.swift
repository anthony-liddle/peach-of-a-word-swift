import Foundation
import Testing
@testable import PeachEngine

/// What one cell of the calendar draws.
///
/// Kept in the engine rather than the view so the six states are decided by a
/// pure function with a test, not by a chain of `if let` inside a `ForEach`. The
/// grid then has nothing to decide.
@Suite("archive day marks")
struct ArchiveTests {
    static let today = 251

    private func mark(_ day: Int, _ outcome: DayOutcome?) -> DayMark {
        dayMark(for: day, outcome: outcome, todayIndex: Self.today)
    }

    // MARK: The seventh state, which the list of six does not contain

    @Test("tomorrow is not yet playable")
    func tomorrowIsNotYet() {
        #expect(mark(Self.today + 1, nil) == .notYet)
    }

    /// `dailySourceWord` will happily compute any day, including next year, so
    /// the refusal has to be here rather than left to the calendar's range.
    @Test("a future day with an outcome is still not yet playable")
    func futureBeatsAnyRecord() {
        let planted = DayOutcome(reached: DayOutcome.basket, on: Self.today + 5, fromStreak: false)
        #expect(mark(Self.today + 5, planted) == .notYet)
    }

    @Test("today is playable")
    func todayIsPlayable() {
        #expect(mark(Self.today, nil) == .noRecord)
    }

    // MARK: The six

    @Test("a day with no outcome has no record")
    func noRecord() {
        #expect(mark(200, nil) == .noRecord)
    }

    @Test("a day played below the rank is incomplete")
    func incomplete() {
        #expect(mark(200, DayOutcome(reached: DayOutcome.played, on: 200, fromStreak: false))
                == .incomplete)
    }

    @Test("cleared on the day")
    func clearedOnTheDay() {
        #expect(mark(200, DayOutcome(reached: DayOutcome.cleared, on: 200, fromStreak: false))
                == .cleared(onTheDay: true, fromStreak: false))
    }

    @Test("cleared after the day")
    func clearedAfterTheDay() {
        #expect(mark(200, DayOutcome(reached: DayOutcome.cleared, on: 251, fromStreak: false))
                == .cleared(onTheDay: false, fromStreak: false))
    }

    @Test("basket on the day")
    func basketOnTheDay() {
        #expect(mark(200, DayOutcome(reached: DayOutcome.basket, on: 200, fromStreak: false))
                == .basket(onTheDay: true))
    }

    @Test("basket after the day")
    func basketAfterTheDay() {
        #expect(mark(200, DayOutcome(reached: DayOutcome.basket, on: 251, fromStreak: false))
                == .basket(onTheDay: false))
    }

    // MARK: The annotation

    @Test("a transferred day is cleared, on its own day, and says so")
    func webDay() {
        #expect(mark(200, DayOutcome(reached: DayOutcome.cleared, on: 200, fromStreak: true))
                == .cleared(onTheDay: true, fromStreak: true))
    }

    /// A run records no basket completion, so the expansion never claims one.
    /// If a flagged day ever carries a basket it came from somewhere else, and
    /// the mark should not quietly hand the run the credit.
    @Test("a basket never reports the streak as its source")
    func basketCarriesNoStreakFlag() {
        let day = mark(200, DayOutcome(reached: DayOutcome.basket, on: 200, fromStreak: true))
        #expect(day == .basket(onTheDay: true))
    }

    // MARK: Forward compatibility

    /// `reached` is compared with `>=` so a rung written by a later build reads
    /// as at least a full basket rather than falling through to incomplete.
    @Test("a rung from a newer build reads as at least a basket")
    func newerRungReadsAsBasket() {
        #expect(mark(200, DayOutcome(reached: 7, on: 200, fromStreak: false))
                == .basket(onTheDay: true))
    }

    // MARK: The range the grid draws

    @Test("the archive runs from the first playable day to today")
    func archiveRange() {
        let days = archiveDayIndices(firstPlayableDayIndex: 173, todayIndex: Self.today)
        #expect(days.first == 173)
        #expect(days.last == Self.today)
        #expect(days.count == 79)
    }

    @Test("an archive is empty before the first board exists")
    func archiveBeforeTheEpoch() {
        #expect(archiveDayIndices(firstPlayableDayIndex: 173, todayIndex: 172).isEmpty)
    }
}

/// The two guards that decide whether a past board behaves like a past board.
///
/// Both are in the engine rather than in `GameModel` because the app target
/// compiles no unit tests: everything left in the model is reachable only from a
/// UI test, and these two are the items most likely to ship looking fine.
@Suite("archive guards")
struct ArchiveGuardTests {
    // MARK: The rollover

    @Test("a live board rolls over when the day has changed")
    func liveBoardRollsOver() {
        #expect(shouldRollOver(boardDayIndex: 250, todayIndex: 251, isArchive: false))
    }

    @Test("a live board on today's day does not roll over")
    func liveBoardOnTodayStays() {
        #expect(!shouldRollOver(boardDayIndex: 251, todayIndex: 251, isArchive: false))
    }

    /// The single most likely bug in the feature. `rollOverIfNewDay` rebuilds
    /// whenever the board's day differs from today, and an archive board differs
    /// by definition, so the first foregrounding would replace a July board with
    /// today's while she was still playing it.
    @Test("an archive board never rolls over, however old it is")
    func archiveBoardNeverRollsOver() {
        #expect(!shouldRollOver(boardDayIndex: 182, todayIndex: 251, isArchive: true),
                "a foregrounding replaced an archive board with today's")
        #expect(!shouldRollOver(boardDayIndex: 250, todayIndex: 251, isArchive: true))
    }

    // MARK: The celebration

    /// `adopt` seeds `completionSeen` from the restored found list. On a day
    /// whose words have aged out of the fourteen-day window that list is empty,
    /// so re-completing an already-completed board fires the whole peak again
    /// while the grid is drawing that day filled.
    @Test("a day already recorded as a full basket has had its celebration")
    func completedDayHasBeenSeen() {
        let done = DayOutcome(reached: DayOutcome.basket, on: 200, fromStreak: false)
        #expect(completionAlreadySeen(outcome: done))
    }

    @Test("a day cleared but not filled has not had its celebration")
    func clearedDayHasNotBeenSeen() {
        let cleared = DayOutcome(reached: DayOutcome.cleared, on: 200, fromStreak: false)
        #expect(!completionAlreadySeen(outcome: cleared))
    }

    @Test("a day with no record has not had its celebration")
    func unknownDayHasNotBeenSeen() {
        #expect(!completionAlreadySeen(outcome: nil))
    }

    /// The point of the substitution: the outcome remembers what the found list
    /// is allowed to forget.
    @Test("a completed day whose words were pruned has still had its celebration")
    func prunedButCompletedDayHasBeenSeen() {
        let store = InMemoryStore()
        let storage = GameStorage(store: store)
        storage.recordOutcome(
            dayIndex: 200, DayOutcome(reached: DayOutcome.basket, on: 200, fromStreak: false))

        // The words are gone; nothing was ever saved under this day.
        #expect(storage.loadDayProgress(dayIndex: 200, sourceWord: "motorway") == [])
        // The outcome is not.
        #expect(completionAlreadySeen(outcome: storage.outcome(dayIndex: 200)))
    }
}

/// The streak guard, which is the rule that must not move backwards.
@Suite("streak cannot move backwards")
struct StreakGuardTests {
    let store = InMemoryStore()
    var storage: GameStorage { GameStorage(store: store) }

    @Test("clearing today extends the streak as it always did")
    func todayStillCounts() {
        storage.recordDailyCleared(dayIndex: 250, todayIndex: 250, fromArchive: false)
        storage.recordDailyCleared(dayIndex: 251, todayIndex: 251, fromArchive: false)
        #expect(storage.currentStreak(todayIndex: 251) == 2)
    }

    /// A board opened at 23:58 and cleared at 00:01 records under the day it was
    /// built for, which is now yesterday. That works today, and a strict
    /// equality guard would silently break it.
    @Test("a board finished just after midnight still counts for the day it belongs to")
    func yesterdayStillCounts() {
        storage.recordDailyCleared(dayIndex: 250, todayIndex: 250, fromArchive: false)
        // `false` carries the whole test. This is the only call in the suite
        // where the flag changes the answer: yesterday's index arriving from a
        // board that was opened as today's.
        storage.recordDailyCleared(dayIndex: 251, todayIndex: 252, fromArchive: false)
        #expect(storage.currentStreak(todayIndex: 252) == 2,
                "a clear that landed just after midnight was refused")
    }

    /// The guard itself. Completing a board from three weeks ago must not
    /// restart a live seventy-day streak at 1.
    @Test("clearing a board from weeks ago does not touch the streak")
    func archiveClearIsRefused() {
        storage.adoptStreak(count: 70, lastClearedDayIndex: 251, todayIndex: 251)
        storage.recordDailyCleared(dayIndex: 200, todayIndex: 251, fromArchive: false)
        #expect(storage.currentStreak(todayIndex: 251) == 70,
                "an archive board reset a live streak")
    }

    /// The assertion here is the consequence, not the reading, and the first
    /// version of this test got that wrong. Asserting the streak is still 1
    /// straight after the bogus clear passes either way: with the guard nothing
    /// was written, and without it `lastCleared` becomes 300 with a count of 1,
    /// which still reads as 1 today. The defect only shows up the next day.
    @Test("a day that has not happened yet cannot be cleared")
    func futureClearIsRefused() {
        storage.recordDailyCleared(dayIndex: 251, todayIndex: 251, fromArchive: false)
        storage.recordDailyCleared(dayIndex: 300, todayIndex: 251, fromArchive: false)

        // Tomorrow must still extend. If the future index was accepted,
        // `lastCleared` is 300, tomorrow reads as a gap, and the streak restarts
        // at 1: the freeze the guard exists to prevent.
        storage.recordDailyCleared(dayIndex: 252, todayIndex: 252, fromArchive: false)
        #expect(storage.currentStreak(todayIndex: 252) == 2,
                "a future index was accepted, which froze the streak")
    }

    /// The two numbers as they sit on disk. `currentStreak` folds them into one
    /// answer, and "untouched" is a claim about both, so these guards read the
    /// pair rather than its reading.
    private func storedStreak() -> (count: Int, last: Int?) {
        guard let data = store.data(forKey: GameStorage.storageKey),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let streak = json["streak"] as? [String: Any]
        else { return (0, nil) }
        return (streak["count"] as? Int ?? 0, streak["lastClearedDayIndex"] as? Int)
    }

    /// The reported defect, at the size it was found: 72 became 1 on one
    /// accepted find. Yesterday's index reaching the engine from the calendar
    /// is indistinguishable from the midnight crossing unless the caller says
    /// which it is.
    @Test("yesterday from the archive does not restart a live streak")
    func yesterdayFromTheArchiveIsRefused() {
        storage.adoptStreak(count: 72, lastClearedDayIndex: 252, todayIndex: 252)
        storage.recordDailyCleared(dayIndex: 251, todayIndex: 252, fromArchive: true)

        let streak = storedStreak()
        #expect(streak.count == 72, "an archive board reset a live streak to \(streak.count)")
        #expect(streak.last == 252, "an archive board moved the last cleared day backwards")
    }

    /// The same day from the same place, with today still unplayed. Catching up
    /// is not graded, so a day filled in later must not revive a run that has
    /// already lapsed. Before the fix this wrote 71 and handed back a streak
    /// that had been broken for a day.
    @Test("yesterday from the archive does not revive a lapsed streak")
    func yesterdayFromTheArchiveDoesNotRepair() {
        storage.adoptStreak(count: 70, lastClearedDayIndex: 250, todayIndex: 250)
        storage.recordDailyCleared(dayIndex: 251, todayIndex: 252, fromArchive: true)

        let streak = storedStreak()
        #expect(streak.count == 70, "catching up repaired a broken streak, to \(streak.count)")
        #expect(streak.last == 250, "catching up moved the last cleared day")
        #expect(storage.currentStreak(todayIndex: 252) == 0, "a lapsed streak came back")
    }

    /// The mirror of the defect, and the thing a blunter fix would cost. Today
    /// reached from the calendar is still today, so it must record. Verified
    /// against the running app before this guard was written: tapping today in
    /// the calendar arrives with `fromArchive` false, because `openArchiveDay`
    /// sets the flag from `storageDay != today`. This guard holds the engine to
    /// the rule anyway, since the call site is not where the rule lives.
    @Test("today from the archive still extends the streak")
    func todayFromTheArchiveStillCounts() {
        storage.adoptStreak(count: 72, lastClearedDayIndex: 251, todayIndex: 251)
        storage.recordDailyCleared(dayIndex: 252, todayIndex: 252, fromArchive: true)
        #expect(storage.currentStreak(todayIndex: 252) == 73,
                "today was refused because of how it was opened")
    }

    /// The existing guard, restated with the flag set. A day from weeks ago
    /// reaches the engine only from the archive, and it must still touch
    /// nothing.
    @Test("a day from weeks ago from the archive still touches nothing")
    func weeksAgoFromTheArchiveIsRefused() {
        storage.adoptStreak(count: 70, lastClearedDayIndex: 251, todayIndex: 251)
        storage.recordDailyCleared(dayIndex: 200, todayIndex: 251, fromArchive: true)

        let streak = storedStreak()
        #expect(streak.count == 70, "an archive board reset a live streak")
        #expect(streak.last == 251, "an archive board moved the last cleared day")
    }
}

/// Selecting a board by index rather than by date.
///
/// The archive knows which day it wants as a number. Going index -> Date ->
/// index to ask for it would reintroduce the time-zone question that `dayIndex`
/// exists to answer once, so the index form is the primitive and the date form
/// is the wrapper.
@Suite("source word by index")
struct SourceWordByIndexTests {
    let calendar = ["alpha", "bravo", "charlie", "delta"]

    @Test("the first cycle is the committed order")
    func firstCycleIsCommittedOrder() {
        for i in calendar.indices {
            #expect(sourceWord(calendar: calendar, dailyIndex: i) == calendar[i])
        }
    }

    @Test("a pre-epoch index floors at the first day rather than trapping")
    func negativeIndexFloors() {
        #expect(sourceWord(calendar: calendar, dailyIndex: -5) == calendar[0])
    }

    /// The wrapper and the primitive must not be able to disagree, which is the
    /// whole reason one is written in terms of the other.
    @Test("the date form agrees with the index form")
    func dateFormAgrees() throws {
        let utc = TimeZone(identifier: "UTC")!
        let epoch = EpochDate(year: 2026, month: 6, day: 23)
        let start = Foundation.Calendar(identifier: .gregorian).date(
            from: DateComponents(timeZone: utc, year: 2026, month: 6, day: 23))!

        for offset in 0..<8 {
            let day = start.addingTimeInterval(Double(offset) * 86_400)
            let byDate = try dailySourceWord(
                calendar: calendar, date: day, epoch: epoch, timeZone: utc)
            #expect(byDate == sourceWord(calendar: calendar, dailyIndex: offset))
        }
    }

    @Test("an empty calendar has no word for any index")
    func emptyCalendar() {
        #expect(sourceWord(calendar: [], dailyIndex: 3) == nil)
    }
}
