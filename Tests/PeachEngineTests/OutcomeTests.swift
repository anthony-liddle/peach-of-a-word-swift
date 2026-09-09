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
