import Foundation
import Testing
@testable import PeachEngine

/// A run's words carry into its day's basket (Antoine, 25 November 2026,
/// reversing "nothing carries"): each counts as found on the board, with its
/// points and the peach of a word, and the rank, the streak and the calendar
/// follow from the basket.
///
/// This is the store's half, for a run that ends while its board isn't the
/// one in play: one left waiting overnight, ended at the next launch. The app
/// carries a run whose board is on screen through the board's own find path.
///
/// The fixture's set is sea, near, dean and serenade, par 22: `serenade`
/// alone is past the streak's rank, `sea` alone is below it, and all four are
/// a full basket.
@Suite("a run carried into its basket")
struct RunCarryTests {
    let store = InMemoryStore()
    var storage: GameStorage { GameStorage(store: store) }

    static let today = 330

    private func run(_ words: [String], day: Int = today) -> RunRecord {
        RunRecord(day: day, words: words, points: 0, peachFound: words.contains("serenade"),
                  endedEarly: false, secondsLeft: 0, length: 90)
    }

    /// Recorded first, as the app records a run before carrying it.
    @discardableResult
    private func carry(_ words: [String], day: Int = today, today: Int = today) -> Bool {
        let record = run(words, day: day)
        storage.recordRun(record)
        return storage.carryRun(record, puzzle: Fixture.puzzle, todayIndex: today)
    }

    private func basket(_ day: Int = today) -> [String] {
        storage.loadDayProgress(dayIndex: day, sourceWord: "serenade")
    }

    // MARK: The words

    @Test("a run's words go into its day's basket, newest first as the run kept them")
    func wordsCarry() {
        #expect(carry(["serenade", "sea"]), "the carry wrote nothing")
        #expect(basket() == ["serenade", "sea"])
    }

    @Test("a word the basket holds isn't doubled, and the basket's own come first")
    func noDoubles() {
        storage.saveDayProgress(dayIndex: Self.today, sourceWord: "serenade", found: ["near"],
                                fromArchive: false)
        carry(["sea", "near"])
        #expect(basket() == ["near", "sea"])
    }

    @Test("a word the board doesn't take stays out")
    func onlyTheBoardsWords() {
        carry(["sea", "zebra"])
        #expect(basket() == ["sea"])
    }

    @Test("a run with no words carries nothing, and records no day")
    func emptyRun() {
        #expect(!carry([]))
        #expect(storage.outcome(dayIndex: Self.today) == nil)
    }

    @Test("carried twice, the second carry writes nothing")
    func once() {
        carry(["serenade"])
        let again = storage.carryRun(run(["serenade"]), puzzle: Fixture.puzzle, todayIndex: Self.today)
        #expect(!again)
        #expect(basket() == ["serenade"])
    }

    @Test("yesterday's run, ended at today's launch, goes into yesterday and not today")
    func yesterdaysRunStaysYesterdays() {
        carry(["serenade"], day: Self.today - 1)
        #expect(basket(Self.today - 1) == ["serenade"])
        #expect(basket(Self.today).isEmpty, "yesterday's run reached today's basket")
        #expect(storage.outcome(dayIndex: Self.today) == nil, "yesterday's run gave today an outcome")
    }

    // MARK: The calendar and the streak

    @Test("the day's outcome rises to what the basket reaches, on the run's own day")
    func outcomeFollows() {
        carry(["serenade"], day: Self.today - 1)
        let day = storage.outcome(dayIndex: Self.today - 1)
        #expect(day?.reached == DayOutcome.cleared)
        #expect(day?.on == Self.today - 1, "a run played on its day read as caught up later")
    }

    @Test("today's run past the rank starts the streak")
    func todaysStreak() {
        carry(["serenade"])
        #expect(storage.currentStreak(todayIndex: Self.today) == 1)
    }

    @Test("yesterday's run, ended at today's launch, counts for yesterday's streak")
    func yesterdaysStreak() {
        carry(["serenade"], day: Self.today - 1)
        #expect(storage.currentStreak(todayIndex: Self.today) == 1)
    }

    @Test("a run below the rank, or from before yesterday, gives no streak")
    func noStreak() {
        carry(["sea"])
        #expect(storage.currentStreak(todayIndex: Self.today) == 0, "a run below the rank gave a streak")
        let older = RunCarryTests()
        older.carry(["serenade"], day: Self.today - 2)
        #expect(older.storage.currentStreak(todayIndex: Self.today) == 0, "a run two days back gave a streak")
    }

    // MARK: The full basket's card

    @Test("a run that fills the basket owes its card until it plays")
    func fillingOwes() {
        carry(["serenade", "dean", "near", "sea"])
        #expect(storage.owesCompletion(dayIndex: Self.today), "a full basket from a run owes nothing")
        storage.settleCompletion(dayIndex: Self.today)
        #expect(!storage.owesCompletion(dayIndex: Self.today), "the card played and is still owed")
    }

    @Test("a run that doesn't fill the basket owes nothing, nor does a basket already full")
    func notFillingOwesNothing() {
        carry(["serenade"])
        #expect(!storage.owesCompletion(dayIndex: Self.today))

        let full = RunCarryTests()
        full.storage.saveDayProgress(dayIndex: Self.today, sourceWord: "serenade",
                                     found: ["sea", "near", "dean", "serenade"], fromArchive: false)
        full.carry(["sea"])
        #expect(!full.storage.owesCompletion(dayIndex: Self.today))
    }

    @Test("a record kept before the marker existed still reads, owing nothing")
    func oldRecordsRead() throws {
        let old = #"{"day":330,"words":["sea"],"points":1,"peachFound":false,"endedEarly":false,"secondsLeft":0,"length":90}"#
        let record = try JSONDecoder().decode(RunRecord.self, from: Data(old.utf8))
        #expect(record.words == ["sea"])
        #expect(!record.completionOwed)
    }
}

/// The peach of a word's card a run found, owed until it's seen (Antoine, 25
/// November 2026): a run whose end shows no result, or whose result was left
/// before the card opened, opens it once, on the first screen after.
@Suite("a run's peach of a word, owed until seen")
struct OwedPeachCardTests {
    let storage = GameStorage(store: InMemoryStore())

    private func record(_ day: Int) {
        storage.recordRun(RunRecord(day: day, words: ["serenade"], points: 15, peachFound: true,
                                    endedEarly: false, secondsLeft: 0, length: 90))
    }

    @Test("a run's card, owed, is found with its day and word until it's settled")
    func owedUntilSettled() {
        record(330)
        #expect(storage.owedPeachCard() == nil)
        storage.owePeachCard("serenade", dayIndex: 330)
        #expect(storage.owedPeachCard()?.day == 330)
        #expect(storage.owedPeachCard()?.word == "serenade")
        storage.settlePeachCard(dayIndex: 330)
        #expect(storage.owedPeachCard() == nil, "the card was seen and is still owed")
    }

    @Test("a day with no run owes no card")
    func noRunNoCard() {
        storage.owePeachCard("serenade", dayIndex: 330)
        #expect(storage.owedPeachCard() == nil)
    }

    @Test("of two days owed, the latest is found first")
    func latestFirst() {
        record(329)
        record(330)
        storage.owePeachCard("serenade", dayIndex: 329)
        storage.owePeachCard("serenade", dayIndex: 330)
        #expect(storage.owedPeachCard()?.day == 330)
        storage.settlePeachCard(dayIndex: 330)
        #expect(storage.owedPeachCard()?.day == 329)
    }

    @Test("a record kept before the marker existed owes no card")
    func oldRecordsOweNothing() throws {
        let old = #"{"day":330,"words":["serenade"],"points":15,"peachFound":true,"endedEarly":false,"secondsLeft":0,"length":90}"#
        let decoded = try JSONDecoder().decode(RunRecord.self, from: Data(old.utf8))
        #expect(decoded.owedPeachCard == nil)
    }
}
