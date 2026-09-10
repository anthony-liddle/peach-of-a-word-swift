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
        let planted = DayOutcome(reached: DayOutcome.basket, on: Self.today + 5, web: false)
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
        #expect(mark(200, DayOutcome(reached: DayOutcome.played, on: 200, web: false))
                == .incomplete)
    }

    @Test("cleared on the day")
    func clearedOnTheDay() {
        #expect(mark(200, DayOutcome(reached: DayOutcome.cleared, on: 200, web: false))
                == .cleared(onTheDay: true, web: false))
    }

    @Test("cleared after the day")
    func clearedAfterTheDay() {
        #expect(mark(200, DayOutcome(reached: DayOutcome.cleared, on: 251, web: false))
                == .cleared(onTheDay: false, web: false))
    }

    @Test("basket on the day")
    func basketOnTheDay() {
        #expect(mark(200, DayOutcome(reached: DayOutcome.basket, on: 200, web: false))
                == .basket(onTheDay: true))
    }

    @Test("basket after the day")
    func basketAfterTheDay() {
        #expect(mark(200, DayOutcome(reached: DayOutcome.basket, on: 251, web: false))
                == .basket(onTheDay: false))
    }

    // MARK: The annotation

    @Test("a transferred day is cleared, on its own day, and says so")
    func webDay() {
        #expect(mark(200, DayOutcome(reached: DayOutcome.cleared, on: 200, web: true))
                == .cleared(onTheDay: true, web: true))
    }

    /// The web never recorded basket completion, so the back-fill never claims
    /// it. If a `web` day ever carries a basket it came from somewhere else, and
    /// the mark should not quietly relabel it.
    @Test("a basket is never reported as a web day")
    func basketCarriesNoWebFlag() {
        let day = mark(200, DayOutcome(reached: DayOutcome.basket, on: 200, web: true))
        #expect(day == .basket(onTheDay: true))
    }

    // MARK: Forward compatibility

    /// `reached` is compared with `>=` so a rung written by a later build reads
    /// as at least a full basket rather than falling through to incomplete.
    @Test("a rung from a newer build reads as at least a basket")
    func newerRungReadsAsBasket() {
        #expect(mark(200, DayOutcome(reached: 7, on: 200, web: false))
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
        let done = DayOutcome(reached: DayOutcome.basket, on: 200, web: false)
        #expect(completionAlreadySeen(outcome: done))
    }

    @Test("a day cleared but not filled has not had its celebration")
    func clearedDayHasNotBeenSeen() {
        let cleared = DayOutcome(reached: DayOutcome.cleared, on: 200, web: false)
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
            dayIndex: 200, DayOutcome(reached: DayOutcome.basket, on: 200, web: false))

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
        storage.recordDailyCleared(dayIndex: 250, todayIndex: 250)
        storage.recordDailyCleared(dayIndex: 251, todayIndex: 251)
        #expect(storage.currentStreak(todayIndex: 251) == 2)
    }

    /// A board opened at 23:58 and cleared at 00:01 records under the day it was
    /// built for, which is now yesterday. That works today, and a strict
    /// equality guard would silently break it.
    @Test("a board finished just after midnight still counts for the day it belongs to")
    func yesterdayStillCounts() {
        storage.recordDailyCleared(dayIndex: 250, todayIndex: 250)
        storage.recordDailyCleared(dayIndex: 251, todayIndex: 252)
        #expect(storage.currentStreak(todayIndex: 252) == 2,
                "a clear that landed just after midnight was refused")
    }

    /// The guard itself. Completing a board from three weeks ago must not
    /// restart a live seventy-day streak at 1.
    @Test("clearing a board from weeks ago does not touch the streak")
    func archiveClearIsRefused() {
        storage.adoptStreak(count: 70, lastClearedDayIndex: 251, todayIndex: 251)
        storage.recordDailyCleared(dayIndex: 200, todayIndex: 251)
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
        storage.recordDailyCleared(dayIndex: 251, todayIndex: 251)
        storage.recordDailyCleared(dayIndex: 300, todayIndex: 251)

        // Tomorrow must still extend. If the future index was accepted,
        // `lastCleared` is 300, tomorrow reads as a gap, and the streak restarts
        // at 1: the freeze the guard exists to prevent.
        storage.recordDailyCleared(dayIndex: 252, todayIndex: 252)
        #expect(storage.currentStreak(todayIndex: 252) == 2,
                "a future index was accepted, which froze the streak")
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

/// How far past today the calendar keeps drawing.
///
/// **A pure function in the engine rather than a private method on the model**,
/// because the App target compiles no unit tests: anything left there is
/// reachable only from a UI test, and this is arithmetic with four cases that
/// each want naming. The calendar facts it needs are passed in, the same way
/// `dayIndex` takes a time zone rather than reaching for `Calendar.current`.
@Suite("the run on past today")
struct ArchiveRunOnTests {
    /// The last day of the week, so nothing is drawn past today.
    @Test("a day at the end of its week runs on by nothing")
    func endOfWeek() {
        #expect(archiveRunOn(todayIndex: 252, weekdayOffset: 6, daysLeftInMonth: 20) == [])
    }

    /// The first day of the week, so the rest of that week is drawn.
    @Test("a day at the start of its week runs on for the other six")
    func startOfWeek() {
        #expect(archiveRunOn(todayIndex: 252, weekdayOffset: 0, daysLeftInMonth: 20)
                == [253, 254, 255, 256, 257, 258])
    }

    /// Nothing to run on to, whatever the weekday.
    @Test("the last day of a month runs on by nothing")
    func endOfMonth() {
        #expect(archiveRunOn(todayIndex: 252, weekdayOffset: 2, daysLeftInMonth: 0) == [])
    }

    /// **The cap, and the reason it exists.** A week that crosses into the next
    /// month stops at the month's end rather than opening a section whose rows
    /// would sit below today's, which is the one thing the landing cannot have.
    @Test("a week crossing a month boundary stops at the month's end")
    func crossesTheMonthBoundary() {
        #expect(archiveRunOn(todayIndex: 252, weekdayOffset: 2, daysLeftInMonth: 2)
                == [253, 254])
    }

    @Test("a negative or nonsense weekday offset draws nothing rather than trapping")
    func nonsenseInput() {
        #expect(archiveRunOn(todayIndex: 252, weekdayOffset: 9, daysLeftInMonth: 5) == [])
        #expect(archiveRunOn(todayIndex: 252, weekdayOffset: -1, daysLeftInMonth: 5) == [])
    }
}
