import Foundation
import Testing
@testable import PeachEngine

/// Whether a past day can hold its found words.
///
/// The archive lets any day from the daily epoch onward be opened and played.
/// `write` keeps the fourteen highest day indices, an ordering that was a proxy
/// for "most recently played" while today was the only playable board. A past
/// day is a low index by definition, so the prune reaches it.
@Suite("archive day progress")
struct ArchiveProgressTests {
    /// 2026-06-23 counted from the fixed storage epoch of 2026-01-01.
    /// Read straight out of a store, so a guard can say which key holds a day
    /// rather than only that something does.
    private func daysUnder(_ store: InMemoryStore, _ key: String) -> Set<String> {
        guard let data = store.data(forKey: key),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let days = json["days"] as? [String: Any]
        else { return [] }
        return Set(days.keys)
    }

    static let firstPlayable = 173
    /// 2026-09-13, the day this was measured.
    static let today = 255

    /// A store holding the fourteen recent days the prune used to keep, played
    /// the way a player plays them: each as the live board, each turning over.
    ///
    /// **Only the call syntax changed when these came out of the report.**
    /// `saveDayProgress` now requires the caller to say whether the board was
    /// opened from the calendar, so every call here names it. The days below
    /// were played live; the days under test were opened from the calendar,
    /// which is what makes them past days. Every assertion is as it was.
    private func storageWithAFullWindow() -> (GameStorage, InMemoryStore) {
        let store = InMemoryStore()
        let storage = GameStorage(store: store)
        for back in stride(from: GameStorage.backFillWalkDayCount - 1, through: 0, by: -1) {
            let day = Self.today - back
            storage.saveDayProgress(
                dayIndex: day, sourceWord: "recently", found: ["recent"],
                fromArchive: false
            )
            storage.retirePastDays(todayIndex: day + 1)
        }
        return (storage, store)
    }

    @Test("the first playable day keeps the words it was just given")
    func theFirstPlayableDayKeepsItsWords() {
        let (storage, _) = storageWithAFullWindow()
        let crown = ["mnemonic", "mnemonic".uppercased().lowercased()]

        storage.saveDayProgress(
            dayIndex: Self.firstPlayable, sourceWord: "mnemonic", found: crown,
            fromArchive: true
        )
        let back = storage.loadDayProgress(
            dayIndex: Self.firstPlayable, sourceWord: "mnemonic"
        )

        #expect(back.count == crown.count,
                "saved \(crown.count) words, loaded \(back.count) back")
    }

    /// The worse shape. The day being saved survives, and an older day that the
    /// player never touched in this session loses its words instead.
    @Test("saving a past day does not destroy a different day's words")
    func savingAPastDayDoesNotEvictAnother() {
        let store = InMemoryStore()
        let storage = GameStorage(store: store)

        // A sparse history: one early day, then thirteen recent ones. Thirteen
        // left exactly one slot, so the next save filled the window.
        storage.saveDayProgress(dayIndex: Self.firstPlayable, sourceWord: "mnemonic",
                                found: ["mnemonic", "omen"], fromArchive: true)
        for back in stride(from: GameStorage.backFillWalkDayCount - 2, through: 0, by: -1) {
            let day = Self.today - back
            storage.saveDayProgress(
                dayIndex: day, sourceWord: "recently", found: ["recent"],
                fromArchive: false
            )
            storage.retirePastDays(todayIndex: day + 1)
        }
        let beforeCount = storage.loadDayProgress(
            dayIndex: Self.firstPlayable, sourceWord: "mnemonic"
        ).count

        // A middling day, played now, above the early one and below the recent.
        storage.saveDayProgress(dayIndex: Self.firstPlayable + 30,
                                sourceWord: "distance", found: ["distant"],
                                fromArchive: true)

        let afterCount = storage.loadDayProgress(
            dayIndex: Self.firstPlayable, sourceWord: "mnemonic"
        ).count
        // The day just saved. If this survives while the early one does not,
        // the loss landed on a day the player never opened.
        let saved = storage.loadDayProgress(
            dayIndex: Self.firstPlayable + 30, sourceWord: "distance"
        ).count
        #expect(saved == 1, "the day just saved did not survive either")
        #expect(afterCount == beforeCount,
                "an untouched day went from \(beforeCount) words to \(afterCount)")
    }

    /// The route this pass adds, which neither guard above can see. Both of
    /// those are about a day opened from the calendar. This one is about a day
    /// the player played live, on its own day, and then simply left alone: the
    /// symptom arrived at by ageing rather than by the prune ordering. The
    /// discovery report called that "the bound working", which was true of the
    /// product this used to be.
    @Test("a day played live still has its words months later")
    func aDayPlayedLiveSurvivesAgeing() {
        let store = InMemoryStore()
        let storage = GameStorage(store: store)

        let played = Self.firstPlayable
        storage.saveDayProgress(dayIndex: played, sourceWord: "mnemonic",
                                found: ["mnemonic", "omen", "mien"], fromArchive: false)

        // Eighty two days of play on top of it, one turnover at a time. Well
        // past fourteen, and past the whole calendar as it stood.
        for day in (played + 1)...Self.today {
            storage.retirePastDays(todayIndex: day)
            storage.saveDayProgress(dayIndex: day, sourceWord: "w\(day)",
                                    found: ["a\(day)"], fromArchive: false)
        }

        let back = storage.loadDayProgress(dayIndex: played, sourceWord: "mnemonic")
        #expect(back.count == 3,
                "a day played live \(Self.today - played) days ago has \(back.count) words")
    }

    /// **The only migration there is, and the path every existing device
    /// takes.** A phone running the merged build has fourteen days of words in
    /// `peach-of-a-word/v1` and no archive key at all. Nothing converts that
    /// blob: the first launch calls `retirePastDays` before it adopts a board
    /// and before the back-fill walks, and the days move then.
    ///
    /// Planted as raw JSON rather than written through the new API, because the
    /// point is a blob this build did not write.
    @Test("an upgraded device keeps the fourteen days it arrives with")
    func theUpgradeFromTheMergedBuild() {
        let days = (0..<14).map { back -> String in
            let day = Self.today - 1 - back
            return "\"\(day)\":{\"sourceWord\":\"w\(day)\",\"found\":[\"a\(day)\",\"b\(day)\"]}"
        }.joined(separator: ",")
        let blob = "{\"version\":1,\"days\":{\(days)},"
            + "\"streak\":{\"count\":72,\"lastClearedDayIndex\":\(Self.today - 1)}}"

        let store = InMemoryStore()
        store.set(Data(blob.utf8), forKey: GameStorage.storageKey)
        let storage = GameStorage(store: store)

        // What the first launch on the new build does, before anything else.
        storage.retirePastDays(todayIndex: Self.today)

        for back in 0..<14 {
            let day = Self.today - 1 - back
            #expect(storage.loadDayProgress(dayIndex: day, sourceWord: "w\(day)")
                    == ["a\(day)", "b\(day)"],
                    "day \(day) did not survive the upgrade")
        }
        #expect(storage.daysWithProgress().count == 14,
                "the walk was offered \(storage.daysWithProgress().count) of 14 days")
        // And the streak came through the same read untouched.
        #expect(storage.currentStreak(todayIndex: Self.today) == 72)

        // **Where they landed, which is the part that can actually fail.**
        // Reading them back proves nothing on its own: an upgrade that never
        // migrated would leave all fourteen in the daily blob, where the read
        // still finds them. What it would cost is the thing the split exists
        // for, the daily blob growing with the history on the path that runs on
        // every accepted word.
        #expect(daysUnder(store, GameStorage.archiveKey).count == 14,
                "the archive holds \(daysUnder(store, GameStorage.archiveKey).count) days")
        #expect(daysUnder(store, GameStorage.storageKey).isEmpty,
                "the daily blob still holds \(daysUnder(store, GameStorage.storageKey).count) days")
    }

    /// **The walk the back-fill does is now unbounded, and that is the caller's
    /// problem to cap.** It used to be held to fourteen by the prune, silently:
    /// nothing said so except a docstring, and the back-fill was sized to it.
    /// This guard states the fact the caller depends on, so the day someone
    /// removes the cap there is the day this stops making sense.
    @Test("every day with words is offered to the walk, however many there are")
    func theWalkIsUnbounded() {
        let store = InMemoryStore()
        let storage = GameStorage(store: store)
        let span = GameStorage.backFillWalkDayCount * 5
        for day in 1...span {
            storage.saveDayProgress(dayIndex: day, sourceWord: "w\(day)",
                                    found: ["a\(day)"], fromArchive: false)
            storage.retirePastDays(todayIndex: day + 1)
        }
        #expect(storage.daysWithProgress().count == span,
                "the walk was offered \(storage.daysWithProgress().count) of \(span) days")
        // Newest first, which is what makes a prefix the most recent days.
        #expect(storage.daysWithProgress().first == span)
    }

    /// What the cap costs, which is nothing the player can see. A day the walk
    /// does not reach is classified by the streak instead, the same way a day
    /// whose words were never stored always was.
    @Test("a day beyond the cap still gets its outcome from the run")
    func aDayBeyondTheCapFallsToTheRun() {
        let store = InMemoryStore()
        let storage = GameStorage(store: store)
        let span = 40
        for day in 1...span {
            storage.saveDayProgress(dayIndex: day, sourceWord: "w\(day)",
                                    found: ["a\(day)"], fromArchive: false)
            storage.retirePastDays(todayIndex: day + 1)
        }
        storage.adoptStreak(count: span, lastClearedDayIndex: span, todayIndex: span)

        // A classifier that answers only for the days a capped walk built
        // puzzles for: the most recent `backFillWalkDayCount`.
        let reached = Set((span - GameStorage.backFillWalkDayCount + 1)...span)
        storage.backFillOutcomes(firstPlayableDayIndex: 1) { day, _, _ in
            reached.contains(day) ? DayOutcome.basket : nil
        }

        // Inside the walk: its own rung, from its own words.
        #expect(storage.outcome(dayIndex: span)?.reached == DayOutcome.basket)
        // Beyond it: still recorded, credited to the run.
        let old = storage.outcome(dayIndex: 1)
        #expect(old?.reached == DayOutcome.cleared, "a day beyond the cap has no outcome")
        #expect(old?.fromStreak == true, "a day beyond the cap did not credit the streak")
    }
}
