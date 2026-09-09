/// What one cell of the calendar draws.
///
/// A pure function over a day and its stored outcome, in the engine rather than
/// in the view, so the six states are decided once and tested rather than
/// assembled out of nested `if let` inside a `ForEach`. The grid then has nothing
/// left to decide, which is what keeps a ninety-row `LazyVGrid` cheap.

/// The state of one day in the archive.
///
/// Seven cases, not six. The list in the brief covers the days that exist; a
/// grid also has to draw the ones that do not yet, because `dailySourceWord`
/// will happily compute any date including next year and the archive must refuse
/// it.
public enum DayMark: Equatable, Sendable {
    /// After today. Computable, deliberately not playable.
    case notYet
    /// Before the app, or opened and never played. **Must read as *before this*,
    /// never as *you did not finish*.** Those two are the same absence in
    /// storage and very different things to a player looking at a streak.
    case noRecord
    /// Found at least one word, below the rank that counts.
    case incomplete
    /// Reached the rank that counts toward the streak.
    /// - Parameters:
    ///   - onTheDay: recorded on the day itself rather than caught up later.
    ///   - web: transferred from the web build rather than earned here.
    case cleared(onTheDay: Bool, web: Bool)
    /// Every set word found. The peak, and above the named ladder.
    case basket(onTheDay: Bool)
}

/// The mark for one day.
///
/// `reached` is compared with `>=` rather than `==` throughout, so a rung
/// written by a later build reads as at least a full basket rather than falling
/// through to `incomplete`. That is the whole reason `DayOutcome.reached` is an
/// `Int` and not an enum.
public func dayMark(for dayIndex: Int, outcome: DayOutcome?, todayIndex: Int) -> DayMark {
    // Checked before the outcome, deliberately. A future day carrying a record
    // is a bug or a clock change somewhere, and drawing it as playable would
    // hand out tomorrow's board; drawing it as "not yet" is true either way.
    guard dayIndex <= todayIndex else { return .notYet }
    guard let outcome else { return .noRecord }

    if outcome.reached >= DayOutcome.basket {
        // No `web` here on purpose. The web never recorded basket completion, so
        // the back-fill cannot produce this; a basket carrying the flag came
        // from somewhere else and is not the web's claim to make.
        return .basket(onTheDay: outcome.on == dayIndex)
    }
    if outcome.reached >= DayOutcome.cleared {
        return .cleared(onTheDay: outcome.on == dayIndex, web: outcome.web)
    }
    return .incomplete
}

/// Every day the archive can offer, oldest first.
///
/// Empty before the first board exists, rather than a range that runs backwards.
public func archiveDayIndices(firstPlayableDayIndex: Int, todayIndex: Int) -> [Int] {
    guard firstPlayableDayIndex <= todayIndex else { return [] }
    return Array(firstPlayableDayIndex...todayIndex)
}
