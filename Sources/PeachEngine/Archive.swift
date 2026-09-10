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

/// The days drawn after today, so the calendar does not stop mid-week.
///
/// **Today's row has to be the last row of the content, and that is a landing
/// requirement rather than a visual one.** The sheet opens by anchoring to the
/// bottom, which costs nothing and resolves nothing. Anything drawn below
/// today's row would push today off the bottom by exactly that much, and the
/// alternative, asking `scrollTo` to find today, is what issue #65 is: a lazy
/// container's estimate of the content above today settled 873pt wrong and the
/// scroll resolved against it.
///
/// So the run on stops at the end of today's week, and never later. The cap at
/// the month's end is the same requirement seen from the other side: a week that
/// crossed into the next month would open a new month section, heading and all,
/// and every row of it would sit below today's.
///
/// The two reasons the run on exists are both kept. A calendar that stops
/// mid-week is not a calendar, and `.notYet` had nowhere to appear while the
/// range ended at today.
///
/// - Parameters:
///   - weekdayOffset: today's position in its own week, 0 for the first weekday
///     and 6 for the last. The caller resolves it against the reader's calendar,
///     because the week does not start on the same day everywhere.
///   - daysLeftInMonth: days after today in today's month.
public func archiveRunOn(todayIndex: Int, weekdayOffset: Int, daysLeftInMonth: Int) -> [Int] {
    guard (0...6).contains(weekdayOffset), daysLeftInMonth > 0 else { return [] }
    let toEndOfWeek = 6 - weekdayOffset
    let count = min(toEndOfWeek, daysLeftInMonth)
    guard count > 0 else { return [] }
    return (1...count).map { todayIndex + $0 }
}

/// Whether the board on screen should be replaced with today's.
///
/// **An archive board never rolls over, and that is the single most likely bug
/// in this feature.** `rollOverIfNewDay` rebuilds whenever the board's day
/// differs from today, which is correct for every board that existed before the
/// archive and wrong for every board the archive opens: a past board differs by
/// definition, so without this the first foregrounding would swap a July board
/// for today's while it was still being played. The code would look right in
/// review, because it is right for the only case it was written against.
public func shouldRollOver(boardDayIndex: Int, todayIndex: Int, isArchive: Bool) -> Bool {
    guard !isArchive else { return false }
    return boardDayIndex != todayIndex
}

/// Whether this day's completion has already been celebrated.
///
/// **Read from the stored outcome, never from the restored found list**, and the
/// substitution is the point rather than an implementation detail.
///
/// `GameModel.adopt` used to seed its `completionSeen` flag by recomputing
/// `isComplete` over the words it had just restored. That is correct only while
/// a completed day always has its words: the found list is pruned and the
/// outcome is not, so a board completed in September and reopened after its
/// words have aged out restores an empty list, seeds `false`, and fires the
/// whole peak a second time while the calendar is already drawing that day
/// filled.
///
/// **The outcome remembers what the found list is allowed to forget.** That is
/// the whole reason the two facts are stored separately and pruned on different
/// schedules, and it is why this reads a different source from the one directly
/// to hand.
public func completionAlreadySeen(outcome: DayOutcome?) -> Bool {
    guard let outcome else { return false }
    return outcome.reached >= DayOutcome.basket
}
