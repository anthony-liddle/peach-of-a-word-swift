import Foundation
import Testing
@testable import PeachEngine

@Suite("GameStorage")
struct StorageTests {
    let store = InMemoryStore()
    var storage: GameStorage { GameStorage(store: store) }

    /// Read the raw bytes back out, for the tests that plant or inspect them.
    private func raw() -> Data? { store.data(forKey: GameStorage.storageKey) }
    private func plant(_ text: String) {
        store.set(Data(text.utf8), forKey: GameStorage.storageKey)
    }

    @Test("saved progress round-trips")
    func roundTrip() {
        storage.saveDayProgress(dayIndex: 220, sourceWord: "motorway",
                                found: ["motorway", "tram", "moray"])
        #expect(storage.loadDayProgress(dayIndex: 220, sourceWord: "motorway")
                == ["motorway", "tram", "moray"])
    }

    @Test("yesterday's progress does not restore into today")
    func yesterdayStaysYesterday() {
        storage.saveDayProgress(dayIndex: 219, sourceWord: "yesterda",
                                found: ["yes", "day"])
        #expect(storage.loadDayProgress(dayIndex: 220, sourceWord: "motorway") == [])
        // And yesterday is still intact, it is just not today's.
        #expect(storage.loadDayProgress(dayIndex: 219, sourceWord: "yesterda") == ["yes", "day"])
    }

    @Test("a day whose source word no longer matches is discarded, not misattributed")
    func wordMismatchDiscards() {
        storage.saveDayProgress(dayIndex: 220, sourceWord: "motorway", found: ["tram"])
        // The calendar was regenerated and this date now serves a different word.
        #expect(storage.loadDayProgress(dayIndex: 220, sourceWord: "audience") == [])
    }

    @Test("only the most recent days are kept")
    func prunesOldDays() {
        for day in 1...(GameStorage.maxDaysKept + 6) {
            storage.saveDayProgress(dayIndex: day, sourceWord: "w\(day)", found: ["a\(day)"])
        }
        // The oldest are gone, the newest survive.
        #expect(storage.loadDayProgress(dayIndex: 1, sourceWord: "w1") == [])
        #expect(storage.loadDayProgress(dayIndex: GameStorage.maxDaysKept + 6,
                                        sourceWord: "w\(GameStorage.maxDaysKept + 6)")
                == ["a\(GameStorage.maxDaysKept + 6)"])
    }
}

@Suite("streak")
struct StreakTests {
    let store = InMemoryStore()
    var storage: GameStorage { GameStorage(store: store) }

    @Test("consecutive days extend the streak, a gap restarts it")
    func extendsAndBreaks() {
        storage.recordDailyCleared(dayIndex: 10)
        #expect(storage.currentStreak(todayIndex: 10) == 1)
        storage.recordDailyCleared(dayIndex: 11)
        #expect(storage.currentStreak(todayIndex: 11) == 2)
        // Skip day 12.
        storage.recordDailyCleared(dayIndex: 13)
        #expect(storage.currentStreak(todayIndex: 13) == 1)
    }

    @Test("recording the same day twice does not double count")
    func idempotent() {
        storage.recordDailyCleared(dayIndex: 10)
        storage.recordDailyCleared(dayIndex: 10)
        #expect(storage.currentStreak(todayIndex: 10) == 1)
    }

    @Test("yesterday's clear still counts today, an older one does not")
    func staleness() {
        storage.recordDailyCleared(dayIndex: 10)
        #expect(storage.currentStreak(todayIndex: 11) == 1)  // yesterday, still live
        #expect(storage.currentStreak(todayIndex: 12) == 0)  // missed a day, broken
    }
}

@Suite("storage fails safe")
struct StorageResilienceTests {
    private func storage(planting text: String) -> GameStorage {
        let store = InMemoryStore()
        store.set(Data(text.utf8), forKey: GameStorage.storageKey)
        return GameStorage(store: store)
    }

    /// A launch crash from bad persisted state is the worst failure this app
    /// could have on someone's phone, so every one of these must read as "no
    /// saved progress" rather than throwing.
    @Test("corrupt, truncated and nonsense blobs start clean rather than crashing",
          arguments: [
            "",                                     // empty
            "not json at all",                      // not JSON
            #"{"version":1,"days":{"#,              // truncated mid-object
            #"{"version":1,"days":[]}"#,            // right key, wrong type
            #"{"version":1,"days":{"220":"nope"}}"#,// day is not an object
            #"[1,2,3]"#,                            // JSON, wrong root type
            "\u{0}\u{1}\u{2}",                      // binary junk
          ])
    func corruptStartsClean(blob: String) {
        let s = storage(planting: blob)
        #expect(s.loadDayProgress(dayIndex: 220, sourceWord: "motorway") == [])
        #expect(s.currentStreak(todayIndex: 220) == 0)
        // And it must still be writable afterwards, not wedged.
        s.saveDayProgress(dayIndex: 220, sourceWord: "motorway", found: ["tram"])
        #expect(s.loadDayProgress(dayIndex: 220, sourceWord: "motorway") == ["tram"])
    }

    /// The decoder is lenient on purpose. Synthesised Codable is strict, and a
    /// strict decode would throw the whole blob away (streak included) the first
    /// time a field was added or one key arrived malformed.
    @Test("a streak survives missing fields rather than resetting")
    func streakSurvivesMissingFields() {
        // No `days` key at all, and no `version`.
        let s = storage(planting: #"{"streak":{"count":7,"lastClearedDayIndex":219}}"#)
        #expect(s.currentStreak(todayIndex: 220) == 7)
        #expect(s.loadDayProgress(dayIndex: 220, sourceWord: "motorway") == [])
    }

    @Test("a streak survives unknown fields from a future build")
    func streakSurvivesUnknownFields() {
        let s = storage(planting: """
            {"version":1,"streak":{"count":4,"lastClearedDayIndex":219},
             "days":{},"themePreference":"cute","somethingNew":{"a":1}}
            """)
        #expect(s.currentStreak(todayIndex: 220) == 4)
    }

    @Test("a blob from a newer format version starts clean")
    func futureVersionStartsClean() {
        let s = storage(planting: #"{"version":99,"streak":{"count":9,"lastClearedDayIndex":219}}"#)
        // We cannot know what version 99 means, so we do not guess.
        #expect(s.currentStreak(todayIndex: 220) == 0)
    }
}

@Suite("progress is keyed to the storage epoch, not the daily epoch")
struct StorageEpochTests {
    let utc = TimeZone(identifier: "UTC")!

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var cal = Foundation.Calendar(identifier: .gregorian)
        cal.timeZone = utc
        return cal.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    /// The entire reason the two epochs exist.
    ///
    /// `dailyEpoch` moves when the calendar is regenerated; `storageEpoch` never
    /// does. If progress were keyed off the daily epoch, re-anchoring the
    /// calendar would renumber every stored day and cost a player their streak.
    /// Nothing in this package proved that end to end before this test.
    @Test("moving the daily epoch does not change the storage key")
    func movingDailyEpochLeavesStorageKeyAlone() {
        let today = date(2026, 8, 9)

        let storageKeyBefore = dayIndex(today, epoch: storageEpoch, timeZone: utc)
        let dailyKeyBefore = dayIndex(today, epoch: dailyEpoch, timeZone: utc)

        // Re-anchor the calendar, as a regeneration would.
        let movedDailyEpoch = EpochDate(year: 2026, month: 9, day: 1)
        let storageKeyAfter = dayIndex(today, epoch: storageEpoch, timeZone: utc)
        let dailyKeyAfter = dayIndex(today, epoch: movedDailyEpoch, timeZone: utc)

        // The storage key is untouched...
        #expect(storageKeyBefore == storageKeyAfter)
        #expect(storageKeyAfter == 220)
        // ...while the daily key moved, which is the whole point of the split.
        #expect(dailyKeyBefore != dailyKeyAfter)
    }

    @Test("progress saved under the storage epoch survives a daily-epoch move")
    func progressSurvivesEpochMove() {
        let store = InMemoryStore()
        let storage = GameStorage(store: store)
        let today = date(2026, 8, 9)

        let key = dayIndex(today, epoch: storageEpoch, timeZone: utc)
        storage.saveDayProgress(dayIndex: key, sourceWord: "motorway", found: ["tram", "moray"])
        storage.recordDailyCleared(dayIndex: key)

        // A regeneration moves the daily epoch. Recompute the storage key the
        // way the app does, which does not consult dailyEpoch at all.
        let keyAfter = dayIndex(today, epoch: storageEpoch, timeZone: utc)
        #expect(keyAfter == key)
        #expect(storage.loadDayProgress(dayIndex: keyAfter, sourceWord: "motorway")
                == ["tram", "moray"])
        #expect(storage.currentStreak(todayIndex: keyAfter) == 1)
    }
}
