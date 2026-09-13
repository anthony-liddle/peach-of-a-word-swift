import Foundation
import Testing
@testable import PeachEngine

/// Taking the play record over the streak's run where it reaches further.
///
/// **This is a one-shot write on a phone, and the reason it has its own suite.**
/// The expansion runs on the first launch after the archive arrives, is never
/// revised, and reads found words that are pruned to a fortnight. Whatever it
/// decides about a day it decides permanently, so both directions matter: a
/// recent basket day has to keep its heart, and a day the recomputation cannot
/// vouch for must not lose the rank the run already proved.
@Suite("back-fill from play")
struct BackFillFromPlayTests {
    let store = InMemoryStore()
    var storage: GameStorage { GameStorage(store: store) }

    /// Bea's numbers: a run of 70 ending on storage day 251, epoch at 173.
    static let firstPlayable = 173
    static let today = 251
    static let firstOfRun = 182

    private func armTheRun() {
        storage.adoptStreak(count: 70, lastClearedDayIndex: Self.today,
                            todayIndex: Self.today)
    }

    /// A classifier standing in for the real one, which needs the word lists.
    private func classifier(_ rungs: [Int: Int]) -> (Int, String, [String]) -> Int? {
        { day, _, _ in rungs[day] }
    }

    @Test("a day whose words survive keeps the basket the run cannot express")
    func basketSurvives() {
        armTheRun()
        storage.saveDayProgress(dayIndex: 250, sourceWord: "chestnut", found: ["chest"], fromArchive: false)

        let counts = storage.backFillOutcomes(firstPlayableDayIndex: Self.firstPlayable,
                                              fromPlay: classifier([250: DayOutcome.basket]))

        let day = storage.outcome(dayIndex: 250)
        #expect(day?.reached == DayOutcome.basket, "the run overwrote a real basket")
        #expect(day?.fromStreak == false, "a day classified from its words credited the streak")
        #expect(counts.fromPlay == 1)
        #expect(counts.fromStreak == 69, "the run should fill every day it still speaks for")
    }

    /// **The permanent downgrade this guard exists to stop.** `classify`
    /// recomputes a rung from stored words against the lexicon, thresholds and
    /// scoring of whichever build is running. If any of those moved since the
    /// day was played, a day that genuinely cleared can come back below the rank.
    /// Inside the run it is floored, so the worst case is agreeing with the run.
    @Test("a recomputation below the rank cannot lower a day inside the run")
    func theRunIsAFloor() {
        armTheRun()
        storage.saveDayProgress(dayIndex: 250, sourceWord: "chestnut", found: ["chest"], fromArchive: false)

        storage.backFillOutcomes(firstPlayableDayIndex: Self.firstPlayable,
                                 fromPlay: classifier([250: DayOutcome.played]))

        let day = storage.outcome(dayIndex: 250)
        #expect(day?.reached == DayOutcome.cleared,
                "a recomputation wrote a cleared day down to incomplete, permanently")
        #expect(day?.fromStreak == true, "the run is what established this, so say so")
    }

    @Test("a day outside the run is taken from its words alone")
    func outsideTheRun() {
        armTheRun()
        // 181 is the day before the run starts.
        storage.saveDayProgress(dayIndex: 181, sourceWord: "validity", found: ["valid"], fromArchive: false)

        storage.backFillOutcomes(firstPlayableDayIndex: Self.firstPlayable,
                                 fromPlay: classifier([181: DayOutcome.played]))

        let day = storage.outcome(dayIndex: 181)
        #expect(day?.reached == DayOutcome.played, "a day outside the run was floored anyway")
        #expect(day?.fromStreak == false)
    }

    @Test("a day the classifier cannot speak for falls to the run")
    func unclassifiedFallsToTheRun() {
        armTheRun()
        storage.saveDayProgress(dayIndex: 250, sourceWord: "chestnut", found: ["chest"], fromArchive: false)

        storage.backFillOutcomes(firstPlayableDayIndex: Self.firstPlayable,
                                 fromPlay: classifier([:]))

        #expect(storage.outcome(dayIndex: 250)?.reached == DayOutcome.cleared)
        #expect(storage.outcome(dayIndex: 250)?.fromStreak == true)
    }

    /// Same rule, and the same reason, as the guard on live recording: a board
    /// opened and abandoned with no finds is "no record", not "you did not
    /// finish". Without this the classifier is asked about a day that has an
    /// entry only because something wrote an empty one.
    @Test("an empty found list is not classified as played")
    func emptyFoundListIsNotPlay() {
        storage.saveDayProgress(dayIndex: 100, sourceWord: "validity", found: [], fromArchive: false)

        var asked: [Int] = []
        storage.backFillOutcomes(firstPlayableDayIndex: Self.firstPlayable) { day, _, _ in
            asked.append(day)
            return DayOutcome.played
        }

        #expect(asked.isEmpty, "the classifier was asked about a board with no finds")
        #expect(storage.outcome(dayIndex: 100) == nil)
    }

    /// **The flag is what stops a second expansion, and nothing else is.**
    /// Calling twice in a row proves nothing: the second call writes nothing
    /// because every day already has an outcome, so that passes with the flag
    /// removed. The flag only shows itself when the map is empty and it is the
    /// one remaining reason not to expand again.
    @Test("the flag alone stops a second expansion")
    func theFlagIsWhatStopsIt() {
        armTheRun()
        let first = storage.backFillOutcomes(firstPlayableDayIndex: Self.firstPlayable,
                                             fromPlay: classifier([:]))
        #expect(first.fromStreak == 70)

        // The flag kept, the days taken away.
        store.set(Data(#"{"version":1,"days":{},"backFilled":true}"#.utf8),
                  forKey: GameStorage.outcomesKey)

        let second = storage.backFillOutcomes(firstPlayableDayIndex: Self.firstPlayable,
                                              fromPlay: classifier([:]))

        #expect(second == BackFillCounts(fromPlay: 0, fromStreak: 0))
        #expect(storage.allOutcomes().isEmpty, "the run was expanded a second time")
    }

    /// The caller is told before it builds anything, because building a
    /// classifier costs a puzzle per retained day.
    @Test("a caller can ask whether the expansion has already run")
    func theFlagIsReadable() {
        #expect(storage.hasBackFilledOutcomes() == false)
        storage.backFillOutcomes(firstPlayableDayIndex: Self.firstPlayable,
                                 fromPlay: classifier([:]))
        #expect(storage.hasBackFilledOutcomes())
    }

    /// The field was called `web` and never shipped: `main` has no outcomes key
    /// at all, so nothing a released build wrote can carry it. A debug install
    /// that still holds the old name reads it as an unknown key and defaults.
    @Test("the old web field no longer decodes, and defaults to false")
    func legacyFieldDefaults() {
        store.set(Data(#"{"version":1,"days":{"200":{"reached":1,"on":200,"web":true}}}"#.utf8),
                  forKey: GameStorage.outcomesKey)

        let day = storage.outcome(dayIndex: 200)
        #expect(day?.reached == DayOutcome.cleared, "the rest of the entry was lost with the field")
        #expect(day?.fromStreak == false, "a retired field name was still believed")
    }
}
