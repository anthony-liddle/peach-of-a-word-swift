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

/// The one-time streak transfer from the web build.
///
/// The two surfaces key days off the same fixed `storageEpoch`, so an incoming
/// `lastClearedDayIndex` is directly comparable with no translation. These
/// tests are the accept rule; the transfer is a throwaway path, but the rule it
/// runs on is not, which is why it lives in `GameStorage` rather than in a URL
/// handler where nothing could reach it.
@Suite("adopting a transferred streak")
struct AdoptStreakTests {
    let store = InMemoryStore()
    var storage: GameStorage { GameStorage(store: store) }

    private let today = 220

    @Test("a live, higher streak is adopted, both fields")
    func adoptsLiveHigher() {
        let s = storage
        #expect(s.adoptStreak(count: 53, lastClearedDayIndex: today, todayIndex: today))
        #expect(s.currentStreak(todayIndex: today) == 53)
        // Tomorrow is the field that would be missing if only the count crossed:
        // with lastCleared carried, clearing tomorrow extends rather than resets.
        s.recordDailyCleared(dayIndex: today + 1)
        #expect(s.currentStreak(todayIndex: today + 1) == 54)
    }

    /// The failure the transfer exists to avoid, in the form it would take if
    /// only `count` crossed: a 53 with no idea when it was last extended reads
    /// as broken the next morning and restarts at 1.
    @Test("a streak that stopped days ago is rejected, however large")
    func rejectsDead() {
        let s = storage
        #expect(s.adoptStreak(count: 53, lastClearedDayIndex: today - 7, todayIndex: today) == false)
        #expect(s.currentStreak(todayIndex: today) == 0)
    }

    /// Yesterday still counts as live: the rule is `last >= today - 1`, the same
    /// one `currentStreak` reads. A player who cleared yesterday and has not
    /// played yet today has not broken anything.
    @Test("yesterday counts as live")
    func yesterdayIsLive() {
        let s = storage
        #expect(s.adoptStreak(count: 12, lastClearedDayIndex: today - 1, todayIndex: today))
        #expect(s.currentStreak(todayIndex: today) == 12)
    }

    /// The case that makes the comparison read `currentStreak` rather than the
    /// stored `count`. A stored 12 that stopped a week ago has an effective
    /// value of 0, so a live 53 must win. Comparing raw counts would reject it.
    @Test("a live streak beats a larger stored streak that is itself dead")
    func liveBeatsDeadStored() {
        let s = storage
        s.recordDailyCleared(dayIndex: today - 8)
        for d in (today - 7)...(today - 5) { s.recordDailyCleared(dayIndex: d) }
        #expect(s.currentStreak(todayIndex: today) == 0)   // dead, though count is 4

        #expect(s.adoptStreak(count: 53, lastClearedDayIndex: today, todayIndex: today))
        #expect(s.currentStreak(todayIndex: today) == 53)
    }

    @Test("a smaller live streak never overwrites a larger one")
    func rejectsSmaller() {
        let s = storage
        s.recordDailyCleared(dayIndex: today)
        #expect(s.adoptStreak(count: 1, lastClearedDayIndex: today, todayIndex: today) == false)
        #expect(s.currentStreak(todayIndex: today) == 1)
    }

    /// Equal is rejected, not merely "not an improvement".
    ///
    /// Adopting an equal streak can cost a day: a stored 9 last cleared
    /// yesterday, overwritten by an incoming 9 last cleared today, would make
    /// today's clear on this device a no-op instead of the tenth day.
    @Test("an equal streak is rejected, because adopting it can cost a day")
    func rejectsEqual() {
        let s = storage
        s.recordDailyCleared(dayIndex: today - 1)
        s.adoptStreak(count: 9, lastClearedDayIndex: today - 1, todayIndex: today - 1)
        #expect(s.currentStreak(todayIndex: today) == 9)

        #expect(s.adoptStreak(count: 9, lastClearedDayIndex: today, todayIndex: today) == false)
        // Today is still available to extend, which adopting would have spent.
        s.recordDailyCleared(dayIndex: today)
        #expect(s.currentStreak(todayIndex: today) == 10)
    }

    /// Transferring with today already complete on the other surface. The path
    /// exists because she may well play on web in the morning and transfer in
    /// the evening, and it had never been exercised on either surface.
    @Test("playing today after transferring a streak that already counts today")
    func todayAlreadyCountedDoesNotDoubleCount() {
        let s = storage
        #expect(s.adoptStreak(count: 53, lastClearedDayIndex: today, todayIndex: today))

        // She then plays today here too and reaches the streak rank.
        s.recordDailyCleared(dayIndex: today)
        #expect(s.currentStreak(todayIndex: today) == 53)   // not 54

        // And tomorrow still extends normally.
        s.recordDailyCleared(dayIndex: today + 1)
        #expect(s.currentStreak(todayIndex: today + 1) == 54)
    }

    @Test("a streak from the future is rejected")
    func rejectsFuture() {
        let s = storage
        // Clocks disagree, or someone typed a number in. Either way this is not
        // a day that has happened, and accepting it would freeze the streak:
        // every real day after it would read as already recorded or as a gap.
        #expect(s.adoptStreak(count: 99, lastClearedDayIndex: today + 1, todayIndex: today) == false)
        #expect(s.currentStreak(todayIndex: today) == 0)
    }

    @Test("a non-positive count is rejected")
    func rejectsNonPositive() {
        let s = storage
        #expect(s.adoptStreak(count: 0, lastClearedDayIndex: today, todayIndex: today) == false)
        #expect(s.adoptStreak(count: -5, lastClearedDayIndex: today, todayIndex: today) == false)
        #expect(s.currentStreak(todayIndex: today) == 0)
    }

    @Test("adopting leaves day progress alone")
    func leavesProgressAlone() {
        let s = storage
        s.saveDayProgress(dayIndex: today, sourceWord: "motorway", found: ["tram"])
        #expect(s.adoptStreak(count: 53, lastClearedDayIndex: today, todayIndex: today))
        #expect(s.loadDayProgress(dayIndex: today, sourceWord: "motorway") == ["tram"])
    }
}

/// What a rollover does to what is already on disk.
///
/// The app now rebuilds the board when it is foregrounded on a later day, which
/// is the first path that changes the day index without a fresh launch. Two
/// things were worth checking rather than assuming, because both are places a
/// mistake would lose something a player earned.
@Suite("a day rolling over under a running app")
struct RolloverTests {
    let store = InMemoryStore()
    var storage: GameStorage { GameStorage(store: store) }

    private let yesterday = 219
    private let today = 220

    /// Progress is written on every find, under the day the board was built
    /// for, so a rollover has nothing to save. This says so rather than
    /// trusting it: it is the case where a mistake costs her a day's words.
    @Test("yesterday's words are already saved, and the new day starts empty")
    func yesterdayIsSafe() {
        let s = storage
        s.saveDayProgress(dayIndex: yesterday, sourceWord: "yesterda",
                          found: ["yes", "day", "stay"])

        // The rollover loads the new day's key with the new day's word.
        #expect(s.loadDayProgress(dayIndex: today, sourceWord: "motorway") == [])
        // And yesterday is untouched, which is what makes the empty board above
        // a fresh start rather than a loss.
        #expect(s.loadDayProgress(dayIndex: yesterday, sourceWord: "yesterda")
                == ["yes", "day", "stay"])
    }

    /// The streak reads from `lastClearedDayIndex`, and this is the first code
    /// path that moves the day under it without relaunching.
    @Test("a streak cleared yesterday survives the rollover and extends today")
    func streakSurvives() {
        let s = storage
        s.recordDailyCleared(dayIndex: yesterday - 1)
        s.recordDailyCleared(dayIndex: yesterday)
        #expect(s.currentStreak(todayIndex: yesterday) == 2)

        // The app comes back on a new day and asks again with the new index.
        #expect(s.currentStreak(todayIndex: today) == 2,
                "yesterday's clear should still count on the morning after")

        // And clearing the new day extends rather than restarts, which is the
        // half that would break if a rollover reset anything.
        s.recordDailyCleared(dayIndex: today)
        #expect(s.currentStreak(todayIndex: today) == 3)
    }

    /// The failure the rollover would cause if it forgot the once-per-session
    /// guard: the new day's first clear dropped, because the flag still said
    /// this session had already recorded one.
    ///
    /// The guard lives in `GameModel`, which this bundle cannot import, so what
    /// is asserted here is the storage half: recording the same day twice is a
    /// no-op, and recording a *different* day is not, so nothing in storage
    /// stops the new day being recorded. If the streak fails to move on the
    /// morning after, the flag is where to look.
    @Test("recording the new day is not blocked by yesterday's record")
    func newDayCanStillBeRecorded() {
        let s = storage
        s.recordDailyCleared(dayIndex: yesterday)
        s.recordDailyCleared(dayIndex: yesterday)      // twice, still one day
        #expect(s.currentStreak(todayIndex: yesterday) == 1)

        s.recordDailyCleared(dayIndex: today)
        #expect(s.currentStreak(todayIndex: today) == 2)
    }
}
