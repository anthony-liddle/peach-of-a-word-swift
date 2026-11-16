import Foundation

/// What a paste would bring, worked out before anything is written: the days
/// the app will take, and how many stay behind and why. The app's question,
/// "Bring 14 days from the web?", reads it.
///
/// **Cheap on purpose.** It needs only the calendar, never a board. Words a
/// day's board doesn't accept show up only once its puzzle is built, so they
/// are counted in the result, not here.
public struct DaysImportPlan: Equatable, Sendable {
    /// The days to bring: today or earlier, from the first board on, with the
    /// calendar's crown, and not held on this phone under another crown.
    public let days: [Int: DaysTransfer.Day]
    /// Days whose crown here isn't the one the web had, or which this phone
    /// holds under another. Their words stay on the web.
    public let differentWord: Int
    /// Days after this phone's today, as a browser east of the phone can hold
    /// near midnight. They stay behind, and bringing the text again tomorrow
    /// brings them.
    public let tomorrow: Int
    /// Words the parse couldn't read at all.
    public let unreadableWords: Int
    /// The web's streak, going or not. A run that has ended still says which
    /// days reached the rank.
    public let streak: DaysTransfer.Streak?
}

/// What an import did, for the one message the player sees after it.
///
/// **It counts only what changed** (rule 7): a day whose words grew or whose
/// outcome rose. Bringing the same text twice says nothing came across.
public struct DaysImportResult: Equatable, Sendable {
    /// Days whose words grew or whose outcome rose, the run's days included.
    public var cameAcross = 0
    /// Of those, the days now at the streak's rank or above.
    public var finished = 0
    /// Of those, the days whose words now include the day's own word.
    public var peaches = 0
    /// Whether the web's streak replaced the phone's.
    public var streakTaken = false
    /// The phone's streak afterwards, as of today.
    public var streak = 0
    public var differentWord = 0
    public var tomorrow = 0
    /// Words that stayed behind: unreadable, or not on that day's board.
    public var unknownWords = 0
}

extension GameStorage {
    /// Sort a paste's days, writing nothing.
    ///
    /// - Parameter crown: the calendar's crown for a storage day. Handed in, as
    ///   `backFillOutcomes` is handed its classifier, since the calendar lives in
    ///   the app. Only called for days from `firstPlayableDayIndex` on: before
    ///   the first board the calendar hands back day 0's crown rather than none.
    public func planImport(
        _ transfer: DaysTransfer, todayIndex: Int, firstPlayableDayIndex: Int,
        crown: (Int) -> String?
    ) -> DaysImportPlan {
        let held = allDayProgress()
        var days: [Int: DaysTransfer.Day] = [:]
        var differentWord = 0
        var tomorrow = 0
        for (day, entry) in transfer.days {
            // Before the first board there was no web game to play it on.
            guard day >= firstPlayableDayIndex else { continue }
            if day > todayIndex {
                tomorrow += 1
                continue
            }
            // Rule 2: the calendar's crown for the day, or the words stay on
            // the web. `loadDayProgress` would hide them under any other crown.
            guard crown(day) == entry.sourceWord else {
                differentWord += 1
                continue
            }
            // Rule 1: a day the phone holds under another crown is left alone,
            // rather than written over by the web's.
            if let mine = held[String(day)], !mine.sourceWord.isEmpty,
               mine.sourceWord != entry.sourceWord {
                differentWord += 1
                continue
            }
            days[day] = entry
        }
        return DaysImportPlan(
            days: days, differentWord: differentWord, tomorrow: tomorrow,
            unreadableWords: transfer.unreadableWords, streak: transfer.streak
        )
    }

    /// Bring the planned days in. **The one write here the app never revises,**
    /// so it adds and raises and never takes anything away.
    ///
    /// In order:
    /// 1. **Each day's words** (rules 1, 3, 5): only the words its board
    ///    accepts, after the phone's own, in the store the day belongs to. Its
    ///    outcome raised from the merged words, never lowered, and floored at
    ///    cleared inside the web's run.
    /// 2. **The streak** (rule 4): the existing accept rule, then today again if
    ///    today has reached the rank, so a clear the phone made today stays on
    ///    top of a longer web streak that ended yesterday.
    /// 3. **The web's run** (rule 6): its days with no record become finished,
    ///    from the streak, as the back-fill fills a run.
    ///
    /// - Parameter puzzles: each planned day's board, built by the caller, off
    ///   the main actor, since a build takes about 90 ms in Release. A day
    ///   without one is left as it was.
    /// - Important: the caller reloads the board on screen afterwards, before
    ///   any find can save its old word list over the merged one (rule 1).
    @discardableResult
    public func applyImport(
        _ plan: DaysImportPlan, todayIndex: Int, firstPlayableDayIndex: Int,
        puzzles: [Int: Puzzle]
    ) -> DaysImportResult {
        var result = DaysImportResult()
        result.differentWord = plan.differentWord
        result.tomorrow = plan.tomorrow
        result.unknownWords = plan.unreadableWords

        let run = plan.streak.flatMap {
            Self.run(count: $0.count, lastClearedDayIndex: $0.lastClearedDayIndex,
                     firstPlayableDayIndex: firstPlayableDayIndex, todayIndex: todayIndex)
        }

        var outcomes = readOutcomes()
        var outcomesChanged = false
        /// Every day that changed, and whether its words now hold its crown.
        var changed: [Int: Bool] = [:]

        // 1. Each day's words, and the outcome they reach.
        for day in plan.days.keys.sorted() {
            guard let entry = plan.days[day], let puzzle = puzzles[day] else { continue }
            let accepted = entry.found.filter { puzzle.validationWords.contains($0) }
            result.unknownWords += entry.found.count - accepted.count
            guard !accepted.isEmpty else { continue }

            let mine = loadDayProgress(dayIndex: day, sourceWord: entry.sourceWord)
            let known = Set(mine)
            let merged = mine + accepted.filter { !known.contains($0) }
            if merged.count > mine.count {
                saveDayProgress(dayIndex: day, sourceWord: entry.sourceWord, found: merged,
                                fromArchive: day != todayIndex)
                changed[day] = merged.contains(entry.sourceWord)
            }

            var reached = rungReached(computeTier(found: Set(merged), puzzle: puzzle))
            let webAlone = rungReached(computeTier(found: Set(accepted), puzzle: puzzle))
            var fromStreak = false
            if run?.contains(day) == true, reached < DayOutcome.cleared {
                reached = DayOutcome.cleared
                fromStreak = true
            }
            let key = String(day)
            let stored = outcomes.days[key]
            if let stored, stored.reached >= reached { continue }
            // Every web find was made on its own day. Reached only with the
            // phone's words too, it's no earlier than the phone's own record.
            let on = fromStreak || webAlone >= reached ? day : max(day, stored?.on ?? day)
            outcomes.days[key] = DayOutcome(reached: reached, on: on, fromStreak: fromStreak)
            outcomesChanged = true
            changed[day] = changed[day] ?? merged.contains(entry.sourceWord)
        }
        if outcomesChanged { writeOutcomes(outcomes) }

        // 2. The streak, then today on top of it.
        let wasBackFilled = readOutcomes().backFilled
        if let streak = plan.streak {
            result.streakTaken = adoptStreak(
                count: streak.count, lastClearedDayIndex: streak.lastClearedDayIndex,
                todayIndex: todayIndex
            )
        }
        if (outcome(dayIndex: todayIndex)?.reached ?? DayOutcome.played) >= DayOutcome.cleared {
            recordDailyCleared(dayIndex: todayIndex, todayIndex: todayIndex, fromArchive: false)
        }

        // 3. The web's run, over the days with no record. `adoptStreak` lowers
        // the archive's expansion marker so a cold launch expands the run it
        // took. The run it took is this one, expanded here, so the marker goes
        // back up: left down, no board opened before the next cold launch could
        // raise its day (`raiseOutcomeOnOpening`).
        outcomes = readOutcomes()
        var runChanged = result.streakTaken && outcomes.backFilled != wasBackFilled
        if let run {
            for day in run where outcomes.days[String(day)] == nil {
                outcomes.days[String(day)] = DayOutcome(reached: DayOutcome.cleared, on: day, fromStreak: true)
                changed[day] = false
                runChanged = true
            }
        }
        outcomes.backFilled = wasBackFilled
        if runChanged { writeOutcomes(outcomes) }

        result.cameAcross = changed.count
        result.finished = changed.keys.filter {
            (outcome(dayIndex: $0)?.reached ?? DayOutcome.played) >= DayOutcome.cleared
        }.count
        result.peaches = changed.values.filter { $0 }.count
        result.streak = currentStreak(todayIndex: todayIndex)
        return result
    }

    /// Raise a day's outcome to `reached`, never lowering it: the stored rung is
    /// the high-water mark. Live play's rule, shared with the import so the two
    /// can't drift. Returns whether anything was written.
    @discardableResult
    public func raiseOutcome(dayIndex: Int, reached: Int, on: Int) -> Bool {
        if let stored = outcome(dayIndex: dayIndex), stored.reached >= reached { return false }
        recordOutcome(dayIndex: dayIndex, DayOutcome(reached: reached, on: on, fromStreak: false))
        return true
    }

    /// The days a streak's run covers, from the first board on and no later
    /// than today. Nil for a run with no days in that range.
    static func run(
        count: Int, lastClearedDayIndex last: Int, firstPlayableDayIndex: Int, todayIndex: Int
    ) -> ClosedRange<Int>? {
        guard count > 0 else { return nil }
        let first = max(firstPlayableDayIndex, last - count + 1)
        let end = min(last, todayIndex)
        return first <= end ? first...end : nil
    }
}
