import Foundation
import Testing
@testable import PeachEngine

/// A day's outcome raised to what its board shows, as the board opens.
///
/// The board is recomputed from the word lists and the outcome is written only
/// by a find, so a word demoted out of the basket left a board one short reading
/// as a full basket over a calendar that still said finished. The next find then
/// played the full basket card and recorded the basket as caught up later.
///
/// The fixture's set is sea, near, dean and serenade: par 22. All four is a
/// full basket, `serenade` alone is 15 of 22 and past the streak's rank, and
/// `sea` alone is one point and below it.
@Suite("raise on opening")
struct RaiseOnOpeningTests {
    let store = InMemoryStore()
    var storage: GameStorage { GameStorage(store: store) }

    /// 21 October 2026, and the 27th the board is opened on.
    static let day = 293
    static let later = 299

    static let basket = ["sea", "near", "dean", "serenade"]
    static let cleared = ["serenade"]
    static let played = ["sea"]

    /// The one-time back-fill, run with no streak to expand, as every launch
    /// after the first has it.
    private func backFilled() {
        storage.backFillOutcomesFromStreak(firstPlayableDayIndex: 173)
    }

    private func record(_ reached: Int, on: Int, fromStreak: Bool = false) {
        storage.recordOutcome(dayIndex: Self.day,
                              DayOutcome(reached: reached, on: on, fromStreak: fromStreak))
    }

    @discardableResult
    private func open(_ found: [String]) -> Bool {
        storage.raiseOutcomeOnOpening(dayIndex: Self.day, found: found, puzzle: Fixture.puzzle)
    }

    /// The case it exists for: finished on the day, a full basket now.
    @Test("a finished day whose board is now a full basket is raised on its own day")
    func finishedToBasket() {
        backFilled()
        record(DayOutcome.cleared, on: Self.day)

        #expect(open(Self.basket), "a board above its record wrote nothing")

        let day = storage.outcome(dayIndex: Self.day)
        #expect(day?.reached == DayOutcome.basket, "the day still reads below its board")
        #expect(day?.on == Self.day, "a basket on the day was recorded as caught up later")
        #expect(day?.fromStreak == false)
        #expect(completionAlreadySeen(outcome: day),
                "the next find would play the full basket card for a basket nobody just completed")
    }

    @Test("a day caught up later keeps the day it was caught up on")
    func caughtUpLaterStaysLater() {
        backFilled()
        record(DayOutcome.cleared, on: Self.later)

        open(Self.basket)

        let day = storage.outcome(dayIndex: Self.day)
        #expect(day?.reached == DayOutcome.basket)
        #expect(day?.on == Self.later, "the raise moved a later finish onto the day itself")
    }

    @Test("a day with words and no record takes its own day")
    func noRecord() {
        backFilled()

        open(Self.cleared)

        let day = storage.outcome(dayIndex: Self.day)
        #expect(day?.reached == DayOutcome.cleared, "a board with words left the day with no record")
        #expect(day?.on == Self.day)
    }

    /// A word dropped from the lists can take a board below its record. The
    /// record is what was played, and stays.
    @Test("a board below its record never lowers it")
    func neverLowered() {
        backFilled()
        record(DayOutcome.basket, on: Self.day)

        #expect(!open(Self.cleared), "a lower board wrote over its record")
        #expect(storage.outcome(dayIndex: Self.day)?.reached == DayOutcome.basket,
                "a basket was taken back")
    }

    /// Scenario 2a: every word found, the demoted one too. The board and the
    /// record already agree, and nothing is written.
    @Test("a day already at its board is left exactly as it was")
    func agreeingDayUntouched() {
        backFilled()
        record(DayOutcome.basket, on: Self.day)
        let before = store.data(forKey: GameStorage.outcomesKey)

        #expect(!open(Self.basket))
        #expect(store.data(forKey: GameStorage.outcomesKey) == before,
                "a day whose record already matched its board was rewritten")
    }

    @Test("a finished day still finished keeps the run's credit")
    func runCreditKept() {
        backFilled()
        record(DayOutcome.cleared, on: Self.day, fromStreak: true)

        #expect(!open(Self.cleared))
        #expect(storage.outcome(dayIndex: Self.day)?.fromStreak == true,
                "a raise that raised nothing rewrote where the day came from")
    }

    /// A basket is something a run cannot record, so a run's day raised to one
    /// is the board's record, not the run's.
    @Test("a run's finished day raised to a basket is the board's own record")
    func runDayRaised() {
        backFilled()
        record(DayOutcome.cleared, on: Self.day, fromStreak: true)

        open(Self.basket)

        let day = storage.outcome(dayIndex: Self.day)
        #expect(day?.reached == DayOutcome.basket)
        #expect(day?.fromStreak == false, "a basket credited to the run")
    }

    @Test("an empty board claims nothing")
    func emptyBoard() {
        backFilled()

        #expect(!open([]))
        #expect(storage.outcome(dayIndex: Self.day) == nil, "an empty board claimed to have been played")
    }

    /// The back-fill passes over a day that already has an outcome, so a raise
    /// ahead of it would stand where the run's floor belongs.
    @Test("nothing is raised before the one-time back-fill")
    func waitsForTheBackFill() {
        #expect(!open(Self.played))
        #expect(storage.outcome(dayIndex: Self.day) == nil,
                "a raise ran ahead of the back-fill and took the day")
    }

    @Test("the streak does not move")
    func streakUntouched() {
        backFilled()
        storage.recordDailyCleared(dayIndex: Self.day, todayIndex: Self.day, fromArchive: false)
        record(DayOutcome.cleared, on: Self.day)
        let before = store.data(forKey: GameStorage.storageKey)

        open(Self.basket)

        #expect(store.data(forKey: GameStorage.storageKey) == before, "opening a board wrote the streak")
        #expect(storage.currentStreak(todayIndex: Self.later) == 0, "a past day's raise revived a streak")
    }
}
