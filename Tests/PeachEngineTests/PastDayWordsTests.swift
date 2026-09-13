import Foundation
import Testing
@testable import PeachEngine

/// Where a day's words live, and that they survive a day becoming yesterday.
///
/// The daily blob holds the board in play. Every day that is no longer in play
/// lives under the archive key, which is never pruned. The guards here are
/// about the move between the two, which is the only moment a day's words are
/// in reach of being dropped.
@Suite("a past day keeps its words")
struct PastDayWordsTests {
    static let today = 255
    static let yesterday = 254

    let store = InMemoryStore()
    var storage: GameStorage { GameStorage(store: store) }

    /// Read straight out of a store, so a guard can say which key holds a day
    /// rather than only that something does.
    private func daysUnder(_ key: String) -> Set<String> {
        guard let data = store.data(forKey: key),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let days = json["days"] as? [String: Any]
        else { return [] }
        return Set(days.keys)
    }

    /// A player's history, built the way a player builds one: play a day, then
    /// the day turns over and the next one starts. Nothing here reaches past
    /// the API the app uses.
    private func playDailyRun(from first: Int, through last: Int) {
        for day in first...last {
            storage.saveDayProgress(dayIndex: day, sourceWord: "word\(day)",
                                    found: ["a\(day)", "b\(day)", "c\(day)"],
                                    fromArchive: false)
            storage.retirePastDays(todayIndex: day + 1)
        }
    }

    @Test("a day's words survive the rollover that moves them")
    func wordsSurviveTheRollover() {
        // Three weeks of play, so the day under test is well past any bound a
        // fourteen day window would have held.
        playDailyRun(from: Self.today - 21, through: Self.yesterday)

        let oldest = Self.today - 21
        let back = storage.loadDayProgress(dayIndex: oldest, sourceWord: "word\(oldest)")
        #expect(back.count == 3, "3 words went into the rollover, \(back.count) came out")
    }

    /// The midnight straggler. A board built for yesterday and still on screen
    /// at 00:01 is being played, and its words are in the daily blob under
    /// yesterday's index.
    @Test("a board played across midnight keeps every word through the rollover")
    func theMidnightStragglerKeepsEveryWord() {
        playDailyRun(from: Self.today - 21, through: Self.today - 2)
        storage.saveDayProgress(dayIndex: Self.yesterday, sourceWord: "yesterda",
                                found: ["yes"], fromArchive: false)
        // Still today's board as far as the app is concerned: not an archive
        // board, and the rollover has not run.
        storage.saveDayProgress(dayIndex: Self.yesterday, sourceWord: "yesterda",
                                found: ["yes", "day"], fromArchive: false)
        let before = storage.loadDayProgress(dayIndex: Self.yesterday, sourceWord: "yesterda")

        storage.retirePastDays(todayIndex: Self.today)

        let after = storage.loadDayProgress(dayIndex: Self.yesterday, sourceWord: "yesterda")
        #expect(before.count == 2, "the straggler lost a word before the rollover")
        #expect(after.count == 2, "\(before.count) words before the rollover, \(after.count) after")
    }

    @Test("after a rollover today is in the daily blob and yesterday is in the archive")
    func theTwoStoresSplitAtTheRollover() {
        playDailyRun(from: Self.today - 21, through: Self.today - 2)
        storage.saveDayProgress(dayIndex: Self.yesterday, sourceWord: "yesterda",
                                found: ["yes"], fromArchive: false)
        storage.retirePastDays(todayIndex: Self.today)
        storage.saveDayProgress(dayIndex: Self.today, sourceWord: "todayone",
                                found: ["today"], fromArchive: false)

        #expect(daysUnder(GameStorage.storageKey) == [String(Self.today)],
                "the daily blob holds \(daysUnder(GameStorage.storageKey).count) days")
        #expect(daysUnder(GameStorage.archiveKey).contains(String(Self.yesterday)),
                "the archive key does not hold yesterday")
    }

    /// A store that stops accepting writes, standing in for the process being
    /// killed partway through a move.
    ///
    /// Both movers write two keys. There is no transaction across them, so one
    /// of the two orders is safe and the other loses words, and which one is
    /// safe was only ever stated in a comment.
    private final class DiesAfterAWrite: KeyValueStore {
        private var contents: [String: Data] = [:]
        private var writesLeft: Int
        init(_ writesLeft: Int) { self.writesLeft = writesLeft }
        func data(forKey key: String) -> Data? { contents[key] }
        func set(_ data: Data?, forKey key: String) {
            guard writesLeft > 0 else { return }
            writesLeft -= 1
            if let data { contents[key] = data } else { contents.removeValue(forKey: key) }
        }
    }

    @Test("a kill partway through the rollover leaves the words readable")
    func aKillDuringTheRolloverKeepsTheWords() {
        // One write to plant the day, then one more before the store dies,
        // which lands in the middle of the move.
        let store = DiesAfterAWrite(2)
        let storage = GameStorage(store: store)
        storage.saveDayProgress(dayIndex: Self.yesterday, sourceWord: "yesterda",
                                found: ["yes", "day"], fromArchive: false)

        storage.retirePastDays(todayIndex: Self.today)

        let back = storage.loadDayProgress(dayIndex: Self.yesterday, sourceWord: "yesterda")
        #expect(back.count == 2,
                "a kill mid rollover left \(back.count) of 2 words readable")
    }

    /// The same test for the other mover: a day still in the daily blob, opened
    /// from the calendar, written to the archive, killed before the cleanup.
    @Test("a kill partway through an archive write leaves the words readable")
    func aKillDuringAnArchiveWriteKeepsTheWords() {
        let store = DiesAfterAWrite(2)
        let storage = GameStorage(store: store)
        storage.saveDayProgress(dayIndex: Self.yesterday, sourceWord: "yesterda",
                                found: ["yes"], fromArchive: false)

        storage.saveDayProgress(dayIndex: Self.yesterday, sourceWord: "yesterda",
                                found: ["yes", "day"], fromArchive: true)

        let back = storage.loadDayProgress(dayIndex: Self.yesterday, sourceWord: "yesterda")
        #expect(back.count == 2,
                "a kill mid archive write left \(back.count) of 2 words readable")
    }

    /// The same defect by a second door, and the one a rollover-shaped guard
    /// cannot see. Between midnight and the next foregrounding the app has not
    /// rolled over, so yesterday is still in the daily blob. Opening it from the
    /// calendar makes it an archive board, and a find then writes it somewhere
    /// else. If the old copy is left behind, the read finds the stale one.
    @Test("a day opened from the calendar before the rollover keeps its new word")
    func aCalendarVisitBeforeTheRolloverIsNotLost() {
        playDailyRun(from: Self.today - 21, through: Self.today - 2)
        storage.saveDayProgress(dayIndex: Self.yesterday, sourceWord: "yesterda",
                                found: ["yes"], fromArchive: false)
        // Tapped in the calendar while it is still in the daily blob.
        storage.saveDayProgress(dayIndex: Self.yesterday, sourceWord: "yesterda",
                                found: ["yes", "day"], fromArchive: true)

        let back = storage.loadDayProgress(dayIndex: Self.yesterday, sourceWord: "yesterda")
        #expect(back.count == 2, "found a second word, read \(back.count) back")
        #expect(daysUnder(GameStorage.storageKey).isEmpty,
                "the day was left in the daily blob as well: \(daysUnder(GameStorage.storageKey))")
    }
}
