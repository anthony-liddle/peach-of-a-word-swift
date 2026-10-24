import Foundation
import Testing
@testable import PeachEngine

/// The calendar's peach: the days whose saved words include the day's own
/// word, the peach of a word.
///
/// **By the rule a board is restored by,** `loadDayProgress`'s, so the mark
/// says what opening the day would show: the live store first, then the
/// archive, and a store whose source word is not the day's is passed over.
@Suite("the days you found the peach of a word")
struct PeachDaysTests {
    static let today = 296

    private func storage() -> GameStorage {
        GameStorage(store: InMemoryStore())
    }

    /// The day's word from the calendar, as the app would give it.
    private func calendar(_ words: [Int: String]) -> (Int) -> String? {
        { words[$0] }
    }

    @Test("a day whose words include its own has the peach")
    func aDayWithItsWordFound() {
        let storage = storage()
        storage.saveDayProgress(dayIndex: Self.today, sourceWord: "industry",
                                found: ["dust", "industry", "stir"], fromArchive: false)
        let days = storage.daysWithTheirWordFound([Self.today],
                                                  sourceWord: calendar([Self.today: "industry"]))
        #expect(days == [Self.today])
    }

    @Test("a past day, retired to the archive, keeps its peach")
    func aRetiredDayKeepsIt() {
        let storage = storage()
        let day = Self.today - 3
        storage.saveDayProgress(dayIndex: day, sourceWord: "courtesy",
                                found: ["courtesy"], fromArchive: false)
        storage.retirePastDays(todayIndex: Self.today)
        let days = storage.daysWithTheirWordFound([day], sourceWord: calendar([day: "courtesy"]))
        #expect(days == [day])
    }

    @Test("a day with words but not its own has none")
    func aDayWithoutItsWord() {
        let storage = storage()
        storage.saveDayProgress(dayIndex: Self.today, sourceWord: "industry",
                                found: ["dust", "stir", "rusty"], fromArchive: false)
        let days = storage.daysWithTheirWordFound([Self.today],
                                                  sourceWord: calendar([Self.today: "industry"]))
        #expect(days.isEmpty)
    }

    /// Another eight-letter word from the same letters is not the day's word:
    /// 222 boards have one.
    @Test("another eight-letter word is not the peach of a word")
    func anotherLongWord() {
        let storage = storage()
        storage.saveDayProgress(dayIndex: Self.today, sourceWord: "sterling",
                                found: ["ringlets"], fromArchive: false)
        let days = storage.daysWithTheirWordFound([Self.today],
                                                  sourceWord: calendar([Self.today: "sterling"]))
        #expect(days.isEmpty)
    }

    /// A day kept by a streak transfer has an outcome and no words.
    @Test("a day with no saved words has none")
    func aDayWithNoWords() {
        let storage = storage()
        storage.recordOutcome(dayIndex: Self.today - 1,
                              DayOutcome(reached: DayOutcome.cleared, on: Self.today - 1,
                                         fromStreak: true))
        let days = storage.daysWithTheirWordFound([Self.today - 1, Self.today],
                                                  sourceWord: calendar([:]))
        #expect(days.isEmpty)
    }

    /// The calendar moved under this date, so its saved words are another
    /// puzzle's, and opening the day restores none of them.
    @Test("a day whose stored word is not the calendar's has none")
    func theCalendarMoved() {
        let storage = storage()
        storage.saveDayProgress(dayIndex: Self.today, sourceWord: "industry",
                                found: ["industry"], fromArchive: false)
        let days = storage.daysWithTheirWordFound([Self.today],
                                                  sourceWord: calendar([Self.today: "skeleton"]))
        #expect(days.isEmpty)
    }

    /// Before the word lists load there is no calendar, and the stored word is
    /// the day's. It differs only for a date the calendar moved.
    @Test("with no calendar yet, the stored word stands in")
    func noCalendarYet() {
        let storage = storage()
        storage.saveDayProgress(dayIndex: Self.today, sourceWord: "industry",
                                found: ["industry"], fromArchive: false)
        let days = storage.daysWithTheirWordFound([Self.today], sourceWord: { _ in nil })
        #expect(days == [Self.today])
    }

    /// The same answer `loadDayProgress` gives, case by case, both stores
    /// filled and disagreeing: the live store's word moved, the archive's not.
    @Test("agrees with what opening the day restores")
    func agreesWithTheRestore() {
        let storage = storage()
        let words = [Self.today - 2: "courtesy", Self.today - 1: "industry", Self.today: "skeleton"]
        // Archived: the right word, found.
        storage.saveDayProgress(dayIndex: Self.today - 2, sourceWord: "courtesy",
                                found: ["courtesy", "court"], fromArchive: true)
        // Archived and right, then a live copy under a moved word, found.
        storage.saveDayProgress(dayIndex: Self.today - 1, sourceWord: "industry",
                                found: ["dust"], fromArchive: true)
        storage.saveDayProgress(dayIndex: Self.today - 1, sourceWord: "dusters",
                                found: ["dusters"], fromArchive: false)
        // Live, the right word, not found.
        storage.saveDayProgress(dayIndex: Self.today, sourceWord: "skeleton",
                                found: ["eels"], fromArchive: false)
        let marked = storage.daysWithTheirWordFound(words.keys, sourceWord: calendar(words))
        for (day, word) in words {
            let restored = storage.loadDayProgress(dayIndex: day, sourceWord: word)
            #expect(marked.contains(day) == restored.contains(word), "day \(day)")
        }
        #expect(marked == [Self.today - 2])
    }
}
