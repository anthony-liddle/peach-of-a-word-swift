import Foundation
import Testing
@testable import PeachEngine

/// The stored fact that a board was finished, to what standard, and when.
///
/// The app has never recorded any of this: `foundDidChange` computes both facts
/// live, uses them to fire the celebration and bump the streak, and throws them
/// away. Everything the calendar draws depends on this being stored, which is
/// why it is the first piece built.
@Suite("day outcomes")
struct OutcomeTests {
    let store = InMemoryStore()
    var storage: GameStorage { GameStorage(store: store) }

    private func plant(_ key: String, _ text: String) {
        store.set(Data(text.utf8), forKey: key)
    }

    @Test("an outcome round-trips")
    func roundTrip() {
        storage.recordOutcome(
            dayIndex: 200,
            DayOutcome(reached: DayOutcome.basket, on: 251, web: false)
        )
        let out = storage.outcome(dayIndex: 200)
        #expect(out?.reached == DayOutcome.basket)
        #expect(out?.on == 251)
        #expect(out?.web == false)
    }

    @Test("a day with no record has no outcome")
    func absentDayHasNone() {
        #expect(storage.outcome(dayIndex: 200) == nil)
    }

    /// The whole point of the second key. Day progress is pruned to fourteen
    /// because it is written on every find and is heavy; an outcome is about
    /// thirty bytes and is written at most twice a day, so it is kept forever.
    @Test("outcomes are never pruned, unlike day progress")
    func neverPruned() {
        let span = GameStorage.maxDaysKept + 20
        for day in 1...span {
            storage.recordOutcome(
                dayIndex: day,
                DayOutcome(reached: DayOutcome.cleared, on: day, web: false)
            )
            storage.saveDayProgress(dayIndex: day, sourceWord: "w\(day)", found: ["a"])
        }
        // Day progress for the oldest day is gone, as it always was.
        #expect(storage.loadDayProgress(dayIndex: 1, sourceWord: "w1") == [])
        // Its outcome is not.
        #expect(storage.outcome(dayIndex: 1)?.reached == DayOutcome.cleared)
        #expect(storage.allOutcomes().count == span)
    }

    /// Structural, not incidental. An older build that has never heard of the
    /// outcomes key cannot rewrite it, which is what makes a TestFlight rollback
    /// lose nothing. If an outcome write ever touched the main blob, that
    /// property would be gone and this test is what says so.
    @Test("recording an outcome does not touch the blob that holds the streak")
    func outcomeWriteLeavesTheMainBlobAlone() {
        storage.recordDailyCleared(dayIndex: 220)
        storage.saveDayProgress(dayIndex: 220, sourceWord: "motorway", found: ["tram"])
        let before = store.data(forKey: GameStorage.storageKey)

        storage.recordOutcome(
            dayIndex: 100,
            DayOutcome(reached: DayOutcome.basket, on: 251, web: true)
        )

        #expect(store.data(forKey: GameStorage.storageKey) == before,
                "an outcome write rewrote the blob that carries the streak")
        #expect(storage.currentStreak(todayIndex: 220) == 1)
    }

    @Test("a corrupt outcomes blob costs the outcomes and not the streak")
    func corruptOutcomesKeepsTheStreak() {
        storage.recordDailyCleared(dayIndex: 220)
        plant(GameStorage.outcomesKey, "{not json at all")

        #expect(storage.outcome(dayIndex: 200) == nil)
        #expect(storage.currentStreak(todayIndex: 220) == 1)
    }

    /// `PersistedState`'s decoder defaults every MISSING field, and still loses
    /// the blob to a field that is present and the wrong type. This map must not
    /// inherit that: one bad field costs that field, not the entry.
    @Test("a malformed field in one entry defaults rather than discarding the entry")
    func malformedFieldDefaults() {
        plant(GameStorage.outcomesKey,
              #"{"version":1,"days":{"200":{"reached":"basket","on":251,"web":true}}}"#)

        let out = storage.outcome(dayIndex: 200)
        #expect(out != nil, "one bad field discarded the whole entry")
        #expect(out?.reached == DayOutcome.opened, "the bad field did not default")
        #expect(out?.on == 251, "a good field beside a bad one was lost")
        #expect(out?.web == true)
    }

    @Test("an outcome from a newer build decodes rather than throwing")
    func forwardCompatibleReach() {
        plant(GameStorage.outcomesKey,
              #"{"version":2,"days":{"200":{"reached":7,"on":251,"web":false,"future":"x"}}}"#)

        let out = storage.outcome(dayIndex: 200)
        #expect(out != nil, "a newer outcomes blob was discarded rather than read")
        // Compared with >=, never ==, so a rung this build has not heard of still
        // reads as at least a full basket rather than as nothing.
        #expect((out?.reached ?? 0) >= DayOutcome.basket)
    }

    /// The load-bearing invariant, kept where a future change trips over it.
    @Test("adding outcomes does not move the storage format version")
    func versionStaysOne() {
        // `GameStorage.read` discards any blob whose version exceeds this
        // build's. Bumping this to add a field means an older TestFlight build
        // reads the newer blob, discards it, and takes the streak with it.
        #expect(PersistedState.currentVersion == 1)

        storage.recordDailyCleared(dayIndex: 220)
        storage.recordOutcome(
            dayIndex: 100,
            DayOutcome(reached: DayOutcome.cleared, on: 251, web: true)
        )

        let blob = try! JSONSerialization.jsonObject(
            with: store.data(forKey: GameStorage.storageKey)!
        ) as! [String: Any]
        #expect(blob["version"] as? Int == 1)
    }
}

/// Expanding a transferred streak run into per-day outcomes.
///
/// The run is the only record of seventy cleared days that exists anywhere: the
/// web never stored per-day completion, and `recordDailyCleared` destroys the run
/// on the first clear after a miss. This is the one-time conversion of a
/// perishable encoding into a durable one.
@Suite("streak back-fill")
struct BackFillTests {
    let store = InMemoryStore()
    var storage: GameStorage { GameStorage(store: store) }

    /// Bea's real numbers, as recorded on 2026-09-09: a run of 70 ending on
    /// storage day 251, which is 2026-09-09. The daily epoch, 2026-06-23, is
    /// storage day 173.
    static let firstPlayable = 173
    static let today = 251

    @Test("a run is expanded into one outcome per day it covers")
    func expandsTheRun() {
        storage.adoptStreak(count: 70, lastClearedDayIndex: Self.today,
                            todayIndex: Self.today)

        let written = storage.backFillOutcomesFromStreak(
            firstPlayableDayIndex: Self.firstPlayable)

        #expect(written == 70)
        // 251 - 69 = 182 is the first day of the run.
        #expect(storage.outcome(dayIndex: 182)?.reached == DayOutcome.cleared)
        #expect(storage.outcome(dayIndex: 251)?.reached == DayOutcome.cleared)
        #expect(storage.outcome(dayIndex: 181) == nil, "the run was expanded one day too far")
        #expect(storage.allOutcomes().count == 70)
    }

    @Test("an expanded day says it was played on the web, on its own day")
    func marksTheDaysAsWeb() {
        storage.adoptStreak(count: 70, lastClearedDayIndex: Self.today,
                            todayIndex: Self.today)
        storage.backFillOutcomesFromStreak(firstPlayableDayIndex: Self.firstPlayable)

        let day = storage.outcome(dayIndex: 200)
        #expect(day?.web == true)
        #expect(day?.on == 200, "a web day was recorded as caught up later")
        // The web never recorded basket completion, so no expanded day may claim it.
        #expect(day?.reached != DayOutcome.basket)
    }

    /// The clamp. Theoretical for a 70-day run starting nine days after the
    /// epoch, and not theoretical the moment a run is longer or `dailyEpoch` is
    /// re-anchored, which `Config.swift` says can happen.
    @Test("the back-fill clamps at the first playable day")
    func clampsAtTheEpoch() {
        storage.adoptStreak(count: 300, lastClearedDayIndex: Self.today,
                            todayIndex: Self.today)

        let written = storage.backFillOutcomesFromStreak(
            firstPlayableDayIndex: Self.firstPlayable)

        // 251 - 173 + 1 = 79 days actually have a board.
        #expect(written == 79)
        #expect(storage.outcome(dayIndex: Self.firstPlayable) != nil)
        #expect(storage.outcome(dayIndex: Self.firstPlayable - 1) == nil,
                "the back-fill wrote an outcome for a day with no board")
        #expect(storage.allOutcomes().keys.min() == Self.firstPlayable)
    }

    /// The whole reason the snapshot note exists. A run that has since died is
    /// still a true record of the days it covers.
    @Test("a dead run is still expanded, because its history is still true")
    func deadRunStillExpands() {
        storage.adoptStreak(count: 70, lastClearedDayIndex: Self.today,
                            todayIndex: Self.today)
        let muchLater = Self.today + 40

        // Dead by the app's own rule, so the meter would show nothing.
        #expect(storage.currentStreak(todayIndex: muchLater) == 0)

        let written = storage.backFillOutcomesFromStreak(
            firstPlayableDayIndex: Self.firstPlayable)

        #expect(written == 70, "the back-fill read the live streak instead of the stored pair")
    }

    @Test("the back-fill runs once, however often it is called")
    func runsOnce() {
        storage.adoptStreak(count: 70, lastClearedDayIndex: Self.today,
                            todayIndex: Self.today)
        #expect(storage.backFillOutcomesFromStreak(firstPlayableDayIndex: Self.firstPlayable) == 70)
        #expect(storage.backFillOutcomesFromStreak(firstPlayableDayIndex: Self.firstPlayable) == 0)
        #expect(storage.allOutcomes().count == 70)
    }

    @Test("a day already played here keeps its own record")
    func doesNotOverwriteRealPlay() {
        storage.recordOutcome(
            dayIndex: 200, DayOutcome(reached: DayOutcome.basket, on: 200, web: false))
        storage.adoptStreak(count: 70, lastClearedDayIndex: Self.today,
                            todayIndex: Self.today)

        storage.backFillOutcomesFromStreak(firstPlayableDayIndex: Self.firstPlayable)

        let day = storage.outcome(dayIndex: 200)
        #expect(day?.reached == DayOutcome.basket, "the back-fill downgraded a real basket")
        #expect(day?.web == false, "a day played here was relabelled as a web day")
    }

    @Test("no streak means nothing to expand")
    func nothingToExpand() {
        #expect(storage.backFillOutcomesFromStreak(firstPlayableDayIndex: Self.firstPlayable) == 0)
        #expect(storage.allOutcomes().isEmpty)
    }

    /// The ordering problem: a transfer can arrive after the app has already
    /// launched and marked the back-fill done. Adopting one has to re-arm it, or
    /// the run she just handed over is never expanded.
    @Test("adopting a transfer re-arms a back-fill that has already run")
    func adoptingReArmsTheBackFill() {
        // First launch, nothing to expand, marked done.
        #expect(storage.backFillOutcomesFromStreak(firstPlayableDayIndex: Self.firstPlayable) == 0)

        // The transfer lands afterwards.
        storage.adoptStreak(count: 70, lastClearedDayIndex: Self.today,
                            todayIndex: Self.today)

        #expect(storage.backFillOutcomesFromStreak(firstPlayableDayIndex: Self.firstPlayable) == 70,
                "a transfer that arrived after first launch was never expanded")
    }
}
