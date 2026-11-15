import Foundation
import Testing
@testable import PeachEngine

/// Bringing a web player's days into the app: the rules from the 5 November
/// report, "Moving From The Web To The App", section 4, one or more tests each.
///
/// **This is a write the app never revises.** Outcomes only ever rise and a
/// day's words are never taken away, so whatever the import decides about a day
/// it decides for good. Every rule here is about what it must never do.
///
/// The fixture's board, `serenade`, reaches each rung with these words, pinned
/// by `theFixtureReachesWhatTheseTestsAssume`:
/// - played: "sea", or "near", or both;
/// - cleared: "serenade", or "near" and "sane";
/// - basket: "sea", "near", "dean" and "serenade".
/// "zebra" isn't a word on it.
@Suite("importing days from the web")
struct DaysImportTests {
    let store = InMemoryStore()
    var storage: GameStorage { GameStorage(store: store) }

    static let first = 173       // 23 June 2026, the first board
    static let today = 318       // 15 November 2026
    static let crown = "serenade"

    /// The calendar, standing in for the real one: every day is `serenade`,
    /// except one day given another crown.
    static func calendar(otherOn other: Int? = nil) -> (Int) -> String? {
        { day in day == other ? "nebulous" : crown }
    }

    static func transfer(
        streak: (Int, Int)? = nil, _ days: [Int: [String]], crown: String = crown
    ) -> DaysTransfer {
        DaysTransfer(
            streak: streak.map { DaysTransfer.Streak(count: $0.0, lastClearedDayIndex: $0.1) },
            days: days.mapValues { DaysTransfer.Day(sourceWord: crown, found: $0) },
            unreadableWords: 0
        )
    }

    /// Plan, build every planned day's puzzle, apply: the app's whole path but
    /// the paste and the question.
    @discardableResult
    func bring(
        _ transfer: DaysTransfer, today: Int = today, calendar: @escaping (Int) -> String? = calendar()
    ) -> DaysImportResult {
        let plan = storage.planImport(
            transfer, todayIndex: today, firstPlayableDayIndex: Self.first, crown: calendar
        )
        let puzzles = Dictionary(uniqueKeysWithValues: plan.days.keys.map { ($0, Fixture.puzzle) })
        return storage.applyImport(
            plan, todayIndex: today, firstPlayableDayIndex: Self.first, puzzles: puzzles
        )
    }

    func played(_ day: Int, _ words: [String]) {
        storage.saveDayProgress(dayIndex: day, sourceWord: Self.crown, found: words,
                                fromArchive: day != Self.today)
    }

    @Test("the fixture reaches what these tests assume")
    func theFixtureReachesWhatTheseTestsAssume() {
        func rung(_ words: [String]) -> Int { rungReached(computeTier(found: Set(words), puzzle: Fixture.puzzle)) }
        #expect(rung(["sea"]) == DayOutcome.played)
        #expect(rung(["sea", "near"]) == DayOutcome.played)
        #expect(rung(["sane"]) == DayOutcome.played)
        #expect(rung(["serenade"]) == DayOutcome.cleared)
        #expect(rung(["near", "sane"]) == DayOutcome.cleared)
        #expect(rung(["sea", "near", "dean", "serenade"]) == DayOutcome.basket)
        #expect(!Fixture.puzzle.validationWords.contains("zebra"))
    }

    // MARK: The plan, which is what the question shows

    @Test("the plan sorts each day before anything is written")
    func thePlanSortsTheDays() {
        played(300, ["sea"])
        let before = store.snapshot()
        let plan = storage.planImport(
            Self.transfer([
                172: ["sea"],             // before the first board
                250: ["sea"],             // another crown in the calendar
                300: ["near"],
                317: ["serenade"],
                319: ["sea"],             // tomorrow here
            ]),
            todayIndex: Self.today, firstPlayableDayIndex: Self.first,
            crown: Self.calendar(otherOn: 250)
        )
        #expect(Set(plan.days.keys) == [300, 317])
        #expect(plan.differentWord == 1)
        #expect(plan.tomorrow == 1)
        #expect(store.snapshot() == before, "the plan wrote something")
    }

    /// Rule 2's other half: rule 1 leaves alone a day the phone holds under
    /// another crown, rather than writing the web's words over it.
    @Test("a day the phone holds under another crown is left alone")
    func thePhonesOtherCrownIsLeftAlone() {
        storage.saveDayProgress(dayIndex: 300, sourceWord: "nebulous", found: ["blue"], fromArchive: true)
        let result = bring(Self.transfer([300: ["sea"]]))
        #expect(storage.loadDayProgress(dayIndex: 300, sourceWord: "nebulous") == ["blue"])
        #expect(storage.loadDayProgress(dayIndex: 300, sourceWord: Self.crown).isEmpty)
        #expect(result.differentWord == 1)
        #expect(result.cameAcross == 0)
    }

    // MARK: Rule 1, nothing on the phone is lost

    @Test("a day only the web played comes across, in the store it belongs to")
    func aWebDayComesAcross() {
        bring(Self.transfer([300: ["sea", "near"], Self.today: ["serenade"]]))
        #expect(storage.loadDayProgress(dayIndex: 300, sourceWord: Self.crown) == ["sea", "near"])
        #expect(storage.readArchive().days["300"]?.found == ["sea", "near"])
        #expect(storage.read().days["300"] == nil)
        #expect(storage.read().days[String(Self.today)]?.found == ["serenade"])
        #expect(storage.readArchive().days[String(Self.today)] == nil)
    }

    @Test("a day both played keeps every word: the phone's first, then the web's new ones")
    func bothSidesWords() {
        played(300, ["near", "sea"])
        bring(Self.transfer([300: ["sea", "dean", "serenade", "near"]]))
        #expect(storage.loadDayProgress(dayIndex: 300, sourceWord: Self.crown)
                == ["near", "sea", "dean", "serenade"])
    }

    // MARK: Rule 3, only words the app accepts

    @Test("a word that isn't on that day's board stays behind, and is counted")
    func wordsOffTheBoardStayBehind() {
        let result = bring(Self.transfer([300: ["sea", "zebra", "near"]]))
        #expect(storage.loadDayProgress(dayIndex: 300, sourceWord: Self.crown) == ["sea", "near"])
        #expect(result.unknownWords == 1)
    }

    @Test("a day with no word the board accepts writes nothing")
    func aDayOfOnlyUnknownWords() {
        let result = bring(Self.transfer([300: ["zebra"]]))
        #expect(storage.allDayProgress()["300"] == nil)
        #expect(storage.outcome(dayIndex: 300) == nil)
        #expect(result.cameAcross == 0)
    }

    // MARK: Rule 5, outcomes worked out again

    @Test("a day's outcome comes from its merged words, on its own day when the web's alone reach it")
    func outcomeFromWords() {
        bring(Self.transfer([300: ["sea", "near", "dean", "serenade"], 301: ["serenade"], 302: ["sea"]]))
        #expect(storage.outcome(dayIndex: 300) == DayOutcome(reached: DayOutcome.basket, on: 300, fromStreak: false))
        #expect(storage.outcome(dayIndex: 301) == DayOutcome(reached: DayOutcome.cleared, on: 301, fromStreak: false))
        #expect(storage.outcome(dayIndex: 302) == DayOutcome(reached: DayOutcome.played, on: 302, fromStreak: false))
    }

    @Test("reached only by both sides' words together, it's on the later of the day and the phone's own")
    func reachedTogether() {
        played(300, ["near"])
        storage.recordOutcome(dayIndex: 300, DayOutcome(reached: DayOutcome.played, on: 305, fromStreak: false))
        bring(Self.transfer([300: ["sane"]]))
        #expect(storage.outcome(dayIndex: 300) == DayOutcome(reached: DayOutcome.cleared, on: 305, fromStreak: false))
    }

    @Test("an outcome is never lowered")
    func neverLowered() {
        played(300, ["sea", "near", "dean", "serenade"])
        storage.recordOutcome(dayIndex: 300, DayOutcome(reached: DayOutcome.basket, on: 300, fromStreak: false))
        bring(Self.transfer([300: ["sea"]]))
        #expect(storage.outcome(dayIndex: 300)?.reached == DayOutcome.basket)
    }

    @Test("a day with no words on the web is skipped")
    func emptyDaysAreSkipped() {
        let result = bring(Self.transfer([300: []]))
        #expect(storage.outcome(dayIndex: 300) == nil)
        #expect(result.cameAcross == 0)
    }

    @Test("inside the web's run, a day's words can't put it below the rank the run proves")
    func theRunIsAFloor() {
        bring(Self.transfer(streak: (5, 302), [300: ["sea"]]))
        #expect(storage.outcome(dayIndex: 300) == DayOutcome(reached: DayOutcome.cleared, on: 300, fromStreak: true))
    }

    // MARK: Rule 6, the web's run

    @Test("the web's run fills the days that have no record, and only those")
    func theRunFillsEmptyDays() {
        storage.recordOutcome(dayIndex: 298, DayOutcome(reached: DayOutcome.played, on: 298, fromStreak: false))
        bring(Self.transfer(streak: (5, 300), [:]))
        for day in [296, 297, 299, 300] {
            #expect(storage.outcome(dayIndex: day) == DayOutcome(reached: DayOutcome.cleared, on: day, fromStreak: true), "\(day)")
        }
        #expect(storage.outcome(dayIndex: 298)?.reached == DayOutcome.played, "the run wrote over a record")
        #expect(storage.outcome(dayIndex: 295) == nil)
    }

    @Test("a run that has ended still comes across as finished days")
    func anEndedRun() {
        let result = bring(Self.transfer(streak: (3, 250), [:]))
        #expect(storage.outcome(dayIndex: 248)?.reached == DayOutcome.cleared)
        #expect(storage.outcome(dayIndex: 250)?.reached == DayOutcome.cleared)
        #expect(result.cameAcross == 3)
        #expect(result.streakTaken == false)
    }

    @Test("the run stops at the first board and at today")
    func theRunsBounds() {
        bring(Self.transfer(streak: (400, 200), [:]))
        #expect(storage.outcome(dayIndex: Self.first)?.reached == DayOutcome.cleared)
        #expect(storage.outcome(dayIndex: Self.first - 1) == nil)
        bring(Self.transfer(streak: (2, Self.today + 1), [:]))
        #expect(storage.outcome(dayIndex: Self.today + 1) == nil)
    }

    // MARK: Rule 4, the streak

    @Test("a streak still going and longer than the phone's is taken")
    func theStreakIsTaken() {
        let result = bring(Self.transfer(streak: (40, Self.today - 1), [:]))
        #expect(storage.currentStreak(todayIndex: Self.today) == 40)
        #expect(result.streakTaken)
        #expect(result.streak == 40)
    }

    @Test("a phone streak as long or longer stays, and the result says so")
    func thePhonesStreakStays() {
        storage.recordDailyCleared(dayIndex: Self.today - 1, todayIndex: Self.today - 1, fromArchive: false)
        storage.recordDailyCleared(dayIndex: Self.today, todayIndex: Self.today, fromArchive: false)
        let result = bring(Self.transfer(streak: (2, Self.today), [:]))
        #expect(!result.streakTaken)
        #expect(result.streak == 2)
    }

    /// The trap. The phone cleared today, and the web's longer streak ended
    /// yesterday: taken alone, the web's pair would take today off the streak.
    @Test("the trap: a clear the phone made today stays on top of a longer web streak")
    func theTrap() {
        played(Self.today, ["serenade"])
        storage.recordOutcome(dayIndex: Self.today, DayOutcome(reached: DayOutcome.cleared, on: Self.today, fromStreak: false))
        storage.recordDailyCleared(dayIndex: Self.today, todayIndex: Self.today, fromArchive: false)
        bring(Self.transfer(streak: (40, Self.today - 1), [:]))
        #expect(storage.currentStreak(todayIndex: Self.today) == 41)
        #expect(storage.read().streak.lastClearedDayIndex == Self.today)
    }

    @Test("today cleared on the web is recorded, even before a find in the app")
    func todayFromTheWeb() {
        bring(Self.transfer(streak: (6, Self.today), [Self.today: ["serenade"]]))
        #expect(storage.currentStreak(todayIndex: Self.today) == 6)
        #expect(storage.read().streak.lastClearedDayIndex == Self.today)
    }

    @Test("taking the streak leaves the archive's expansion marked done, since the import did it")
    func theBackFillStaysDone() {
        storage.backFillOutcomesFromStreak(firstPlayableDayIndex: Self.first)
        #expect(storage.hasBackFilledOutcomes())
        bring(Self.transfer(streak: (40, Self.today - 1), [:]))
        #expect(storage.hasBackFilledOutcomes(), "a board opened now couldn't raise its day")
    }

    // MARK: Rules 7 and 8, twice, and what the player is told

    @Test("bringing the same days twice changes nothing, and says nothing came across")
    func twiceChangesNothing() {
        played(300, ["near"])
        let transfer = Self.transfer(streak: (5, Self.today), [300: ["sane", "sea"], 301: ["serenade"], Self.today: ["serenade"]])
        bring(transfer)
        let after = store.snapshot()
        let again = bring(transfer)
        #expect(store.snapshot() == after)
        #expect(again.cameAcross == 0)
        #expect(!again.streakTaken)
    }

    @Test("the result counts what came across, what's finished, the peaches, and what stayed behind")
    func theResultCounts() {
        played(302, ["sea"])
        storage.recordOutcome(dayIndex: 302, DayOutcome(reached: DayOutcome.played, on: 302, fromStreak: false))
        let result = bring(
            Self.transfer(streak: (2, 301), [
                250: ["sea"],                 // another crown here
                300: ["sea", "zebra"],        // played, one word unknown
                301: ["serenade"],            // finished, with its peach
                302: ["sea"],                 // nothing new
                319: ["sea"],                 // tomorrow here
            ]),
            calendar: Self.calendar(otherOn: 250)
        )
        #expect(result.cameAcross == 2)
        #expect(result.finished == 2, "the run makes 300 finished too")
        #expect(result.peaches == 1)
        #expect(result.differentWord == 1)
        #expect(result.tomorrow == 1)
        #expect(result.unknownWords == 1)
    }

    @Test("a day whose board couldn't be built is left as it was")
    func noPuzzleNoWrite() {
        let plan = storage.planImport(
            Self.transfer([300: ["sea"]]), todayIndex: Self.today,
            firstPlayableDayIndex: Self.first, crown: Self.calendar()
        )
        let result = storage.applyImport(plan, todayIndex: Self.today, firstPlayableDayIndex: Self.first, puzzles: [:])
        #expect(storage.allDayProgress()["300"] == nil)
        #expect(result.cameAcross == 0)
    }

    // MARK: The raise the import shares with live play

    @Test("a raise writes only a higher rung")
    func raiseOnlyUpward() {
        #expect(storage.raiseOutcome(dayIndex: 300, reached: DayOutcome.cleared, on: 300))
        #expect(!storage.raiseOutcome(dayIndex: 300, reached: DayOutcome.played, on: 301))
        #expect(!storage.raiseOutcome(dayIndex: 300, reached: DayOutcome.cleared, on: 302))
        #expect(storage.raiseOutcome(dayIndex: 300, reached: DayOutcome.basket, on: 303))
        #expect(storage.outcome(dayIndex: 300) == DayOutcome(reached: DayOutcome.basket, on: 303, fromStreak: false))
    }
}

extension InMemoryStore {
    /// Every key's bytes, to tell whether anything at all was written.
    func snapshot() -> [String: Data] {
        Dictionary(uniqueKeysWithValues: [
            GameStorage.storageKey, GameStorage.archiveKey, GameStorage.outcomesKey,
        ].compactMap { key in data(forKey: key).map { (key, $0) } })
    }
}
