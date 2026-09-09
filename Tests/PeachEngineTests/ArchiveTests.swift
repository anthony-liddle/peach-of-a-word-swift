import Foundation
import Testing
@testable import PeachEngine

/// What one cell of the calendar draws.
///
/// Kept in the engine rather than the view so the six states are decided by a
/// pure function with a test, not by a chain of `if let` inside a `ForEach`. The
/// grid then has nothing to decide.
@Suite("archive day marks")
struct ArchiveTests {
    static let today = 251

    private func mark(_ day: Int, _ outcome: DayOutcome?) -> DayMark {
        dayMark(for: day, outcome: outcome, todayIndex: Self.today)
    }

    // MARK: The seventh state, which the list of six does not contain

    @Test("tomorrow is not yet playable")
    func tomorrowIsNotYet() {
        #expect(mark(Self.today + 1, nil) == .notYet)
    }

    /// `dailySourceWord` will happily compute any day, including next year, so
    /// the refusal has to be here rather than left to the calendar's range.
    @Test("a future day with an outcome is still not yet playable")
    func futureBeatsAnyRecord() {
        let planted = DayOutcome(reached: DayOutcome.basket, on: Self.today + 5, web: false)
        #expect(mark(Self.today + 5, planted) == .notYet)
    }

    @Test("today is playable")
    func todayIsPlayable() {
        #expect(mark(Self.today, nil) == .noRecord)
    }

    // MARK: The six

    @Test("a day with no outcome has no record")
    func noRecord() {
        #expect(mark(200, nil) == .noRecord)
    }

    @Test("a day played below the rank is incomplete")
    func incomplete() {
        #expect(mark(200, DayOutcome(reached: DayOutcome.played, on: 200, web: false))
                == .incomplete)
    }

    @Test("cleared on the day")
    func clearedOnTheDay() {
        #expect(mark(200, DayOutcome(reached: DayOutcome.cleared, on: 200, web: false))
                == .cleared(onTheDay: true, web: false))
    }

    @Test("cleared after the day")
    func clearedAfterTheDay() {
        #expect(mark(200, DayOutcome(reached: DayOutcome.cleared, on: 251, web: false))
                == .cleared(onTheDay: false, web: false))
    }

    @Test("basket on the day")
    func basketOnTheDay() {
        #expect(mark(200, DayOutcome(reached: DayOutcome.basket, on: 200, web: false))
                == .basket(onTheDay: true))
    }

    @Test("basket after the day")
    func basketAfterTheDay() {
        #expect(mark(200, DayOutcome(reached: DayOutcome.basket, on: 251, web: false))
                == .basket(onTheDay: false))
    }

    // MARK: The annotation

    @Test("a transferred day is cleared, on its own day, and says so")
    func webDay() {
        #expect(mark(200, DayOutcome(reached: DayOutcome.cleared, on: 200, web: true))
                == .cleared(onTheDay: true, web: true))
    }

    /// The web never recorded basket completion, so the back-fill never claims
    /// it. If a `web` day ever carries a basket it came from somewhere else, and
    /// the mark should not quietly relabel it.
    @Test("a basket is never reported as a web day")
    func basketCarriesNoWebFlag() {
        let day = mark(200, DayOutcome(reached: DayOutcome.basket, on: 200, web: true))
        #expect(day == .basket(onTheDay: true))
    }

    // MARK: Forward compatibility

    /// `reached` is compared with `>=` so a rung written by a later build reads
    /// as at least a full basket rather than falling through to incomplete.
    @Test("a rung from a newer build reads as at least a basket")
    func newerRungReadsAsBasket() {
        #expect(mark(200, DayOutcome(reached: 7, on: 200, web: false))
                == .basket(onTheDay: true))
    }

    // MARK: The range the grid draws

    @Test("the archive runs from the first playable day to today")
    func archiveRange() {
        let days = archiveDayIndices(firstPlayableDayIndex: 173, todayIndex: Self.today)
        #expect(days.first == 173)
        #expect(days.last == Self.today)
        #expect(days.count == 79)
    }

    @Test("an archive is empty before the first board exists")
    func archiveBeforeTheEpoch() {
        #expect(archiveDayIndices(firstPlayableDayIndex: 173, todayIndex: 172).isEmpty)
    }
}
