import Foundation
import Testing
@testable import PeachEngine

/// Peach rush, the parts that need no app: which state the title's button is
/// in, the record kept, the run in flight, the clock, the time marks, the best
/// word and the share. On the fixture's board, `serenade`, which is no
/// calendar day's.
@Suite("peach rush")
struct TimedRunTests {
    static let today = 330
    static let record = RunRecord(day: today, words: ["near", "sea"], points: 4,
                                  peachFound: false, endedEarly: false, secondsLeft: 0, length: 90)
    static let waiting = RunInFlight(day: today, words: ["sea"], points: 1,
                                     peachFound: false, remaining: 48, length: 90)

    // MARK: The rule

    @Test("a fresh day offers a run, until the basket's first find")
    func offeredUntilTheFirstFind() {
        #expect(runOffer(today: Self.today, record: nil, inFlight: nil, basketFinds: 0) == .fresh)
        #expect(runOffer(today: Self.today, record: nil, inFlight: nil, basketFinds: 1) == .none)
    }

    @Test("a played run is shown, whatever the basket holds, and never offered again")
    func playedIsShown() {
        for finds in [0, 1, 60] {
            #expect(runOffer(today: Self.today, record: Self.record, inFlight: nil, basketFinds: finds)
                    == .played(Self.record))
        }
    }

    @Test("a run in flight waits to be resumed")
    func inFlightWaits() {
        #expect(runOffer(today: Self.today, record: nil, inFlight: Self.waiting, basketFinds: 0)
                == .paused(remaining: 48))
    }

    @Test("another day's record or run in flight offers nothing of its own")
    func anotherDaysIsNotToday() {
        var old = Self.record
        old.day -= 1
        var oldWaiting = Self.waiting
        oldWaiting.day -= 1
        #expect(runOffer(today: Self.today, record: old, inFlight: oldWaiting, basketFinds: 0) == .fresh)
    }

    // MARK: The store

    @Test("only a day's first run is kept")
    func onlyTheFirstIsKept() {
        let storage = GameStorage(store: InMemoryStore())
        #expect(storage.recordRun(Self.record))
        var second = Self.record
        second.points = 99
        #expect(!storage.recordRun(second))
        #expect(storage.runRecord(dayIndex: Self.today) == Self.record)
    }

    @Test("a run in flight survives a relaunch, and goes when cleared")
    func inFlightSurvives() {
        let store = InMemoryStore()
        GameStorage(store: store).saveRunInFlight(Self.waiting)
        #expect(GameStorage(store: store).runInFlight() == Self.waiting)
        GameStorage(store: store).saveRunInFlight(nil)
        #expect(GameStorage(store: store).runInFlight() == nil)
    }

    @Test("a run left in flight on an earlier day ends with what it had, as that day's")
    func aNewDayEndsYesterdaysRun() {
        let storage = GameStorage(store: InMemoryStore())
        var yesterdays = Self.waiting
        yesterdays.day = Self.today - 1
        storage.saveRunInFlight(yesterdays)
        #expect(storage.endRunLeftBefore(todayIndex: Self.today) == Self.today - 1)
        #expect(storage.runInFlight() == nil)
        let kept = storage.runRecord(dayIndex: Self.today - 1)
        #expect(kept?.words == ["sea"])
        #expect(kept?.secondsLeft == 0)
        #expect(kept?.endedEarly == false)
    }

    @Test("today's run in flight is left alone at launch")
    func todaysRunIsLeftAlone() {
        let storage = GameStorage(store: InMemoryStore())
        storage.saveRunInFlight(Self.waiting)
        #expect(storage.endRunLeftBefore(todayIndex: Self.today) == nil)
        #expect(storage.runInFlight() == Self.waiting)
    }

    @Test("a run's record touches none of the basket's keys")
    func apartFromTheBasket() {
        let store = InMemoryStore()
        let storage = GameStorage(store: store)
        storage.recordRun(Self.record)
        storage.saveRunInFlight(Self.waiting)
        for key in [GameStorage.storageKey, GameStorage.archiveKey, GameStorage.outcomesKey,
                    GameStorage.stageKey, GameStorage.boardKey] {
            #expect(store.data(forKey: key) == nil, "a run wrote the basket's \(key)")
        }
        #expect(storage.currentStreak(todayIndex: Self.today) == 0)
        #expect(storage.outcome(dayIndex: Self.today) == nil)
    }

    // MARK: The clock

    @Test("the clock runs on the time it's given, and holds while stopped")
    func theClock() {
        var clock = RunClock(remaining: 90)
        #expect(clock.remaining(at: 1_000) == 90)
        clock.start(at: 1_000)
        #expect(clock.remaining(at: 1_012) == 78)
        clock.stop(at: 1_012)
        #expect(clock.remaining(at: 5_000) == 78)
        clock.start(at: 5_000)
        #expect(clock.remaining(at: 5_078) == 0)
        #expect(clock.remaining(at: 9_000) == 0)
    }

    @Test("the clock reads whole seconds, rounded up, and says them in words")
    func clockWords() {
        #expect(runClockText(90) == "1:30")
        #expect(runClockText(180) == "3:00")
        #expect(runClockText(7.2) == "0:08")
        #expect(runClockText(0.1) == "0:01")
        #expect(runClockText(0) == "0:00")
        #expect(runSpokenTime(72) == "1 minute 12 seconds")
        #expect(runSpokenTime(60) == "1 minute")
        #expect(runSpokenTime(1) == "1 second")
        #expect(runSpokenTime(180) == "3 minutes")
    }

    // MARK: The time marks

    @Test("ticked every fifth of a second, each mark falls due once, in order")
    func marksInOrder() {
        for length in [RunLength.standard, RunLength.longer] {
            var said: [Int] = []
            var before = length
            var t = length
            while t > 0 {
                t = max(0, t - 0.2)
                if let mark = runMarkDue(before: before, after: t) { said.append(mark) }
                before = t
            }
            #expect(said == [60, 30, 10])
        }
    }

    @Test("a stall past a mark says nothing for it, and two never come at once")
    func aStallSaysNothingUntrue() {
        #expect(runMarkDue(before: 45, after: 5) == nil)
        #expect(runMarkDue(before: 61, after: 29.5) == 30)
        #expect(runMarkDue(before: 10.4, after: 10.2) == nil)
        #expect(runMarkDue(before: 10.1, after: 9.9) == 10)
    }

    @Test("resuming a paused run is no crossing")
    func resumingSaysNothing() {
        #expect(runMarkDue(before: 30, after: 30) == nil)
        #expect(runMarkDue(before: 29.9, after: 29.7) == nil)
    }

    // MARK: The best word and the share

    @Test("the best word is the highest scoring, a tie going to the earliest found")
    func bestWord() {
        let points = ["sea": 1, "near": 3, "dean": 3, "serenade": 15]
        let best = bestRunWord(["dean", "near", "sea"], score: { points[$0]! })
        #expect(best?.word == "near")
        #expect(best?.points == 3)
        #expect(bestRunWord(["serenade", "dean"], score: { points[$0]! })!.word == "serenade")
        #expect(bestRunWord([], score: { _ in 0 }) == nil)
    }

    private let utc = TimeZone(identifier: "UTC")!

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = DateComponents()
        (c.year, c.month, c.day, c.hour) = (y, m, d, 12)
        var cal = Foundation.Calendar(identifier: .gregorian)
        cal.timeZone = utc
        return cal.date(from: c)!
    }

    @Test("the run's share is its three lines, with the peach when it was found")
    func share() {
        var record = Self.record
        #expect(buildRunShareText(name: "Peach rush", record: record, boardDate: date(2026, 11, 14),
                                  timeZone: utc) == """
        🍑 Peach of a Word · Nov 14
        ⏱️ Peach rush · 1:30
        2 words · 4 points
        """)
        record.peachFound = true
        record.length = RunLength.longer
        record.words = ["serenade"]
        record.points = 15
        #expect(buildRunShareText(name: "Peach rush", record: record, boardDate: date(2026, 11, 14),
                                  timeZone: utc) == """
        🍑 Peach of a Word · Nov 14
        ⏱️ Peach rush · 3:00
        1 word · 15 points 🍑
        """)
    }

    @Test("no run's share can carry the board's word or any word found")
    func shareIsSpoilerSafe() {
        let puzzle = Fixture.puzzle
        let all = Array(puzzle.validationWords)
        let record = RunRecord(day: Self.today, words: all, points: 99, peachFound: true,
                               endedEarly: false, secondsLeft: 0, length: 90)
        let body = buildRunShareText(name: "Peach rush", record: record, boardDate: date(2026, 11, 14),
                                     timeZone: utc)
            .lowercased()
            .replacingOccurrences(of: "peach of a word", with: "")
            .replacingOccurrences(of: "peach rush", with: "")
        let leaked = all.contains { word in
            body.split(whereSeparator: { !$0.isLetter }).contains { $0 == Substring(word) }
        }
        // A boolean, so a failure prints no word.
        #expect(!leaked, "the run's share carries a word from the board")
    }
}
