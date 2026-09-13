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
}
