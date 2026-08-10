import Foundation

/// Failures the engine can raise.
///
/// A Swift `enum` conforming to `Error` is the idiomatic shape: a `throws`
/// function's failures are a closed set the caller can switch over
/// exhaustively, rather than TypeScript's `throw new Error(...)` where the
/// thrown value is `unknown` and its message is the only signal.
public enum EngineError: Error, Equatable {
    case emptyCalendar
}

/// Whole calendar days from the epoch to the given local date.
///
/// Built from the calendar Y/M/D components, never from
/// `(now - epoch) / dayMs`. Dividing an elapsed interval drifts across
/// daylight-saving boundaries and would make the daily differ on reload. This
/// is rollover at local midnight in `timeZone`.
///
/// The `timeZone` parameter is a deliberate deviation from the TypeScript,
/// which reads `date.getFullYear()` and friends and so silently uses the
/// machine's zone. Swift's `Date` is a bare instant with no local accessors at
/// all, so the zone has to come from somewhere; making it a parameter rather
/// than reaching for `Calendar.current` is what lets the DST and far-from-UTC
/// tests exist and keeps the suite independent of the machine it runs on.
public func dayIndex(
    _ date: Date,
    epoch: EpochDate = dailyEpoch,
    timeZone: TimeZone
) -> Int {
    var local = Foundation.Calendar(identifier: .gregorian)
    local.timeZone = timeZone
    let components = local.dateComponents([.year, .month, .day], from: date)

    var utc = Foundation.Calendar(identifier: .gregorian)
    utc.timeZone = TimeZone(identifier: "UTC")!

    // Re-anchoring both dates in UTC is the port of the TypeScript's
    // `Date.UTC(...)` trick: it strips the zone from both sides so the
    // subtraction counts calendar days rather than elapsed hours.
    let today = utc.date(from: DateComponents(year: components.year,
                                              month: components.month,
                                              day: components.day))!
    let start = utc.date(from: DateComponents(year: epoch.year,
                                              month: epoch.month,
                                              day: epoch.day))!
    let days = (today.timeIntervalSince1970 - start.timeIntervalSince1970) / 86_400
    return Int(days.rounded(.down))
}

/// A well-distributed seed for a reshuffled cycle. Cycle 0 never reaches here.
///
/// The TypeScript is `(cycle * 0x9e3779b1) >>> 0`. That is a DOUBLE multiply
/// followed by a mod-2^32 coercion, NOT a wrapping 32-bit multiply. Writing
/// `UInt32(cycle) &* 0x9e37_79b1` here would look right and produce different
/// numbers. Widening to Int64 first reproduces the JavaScript exactly, because
/// the product stays well inside Double's 53-bit exact range for any cycle this
/// will ever see.
func seedForCycle(_ cycle: Int) -> UInt32 {
    UInt32(truncatingIfNeeded: Int64(cycle) * 0x9e37_79b1)
}

/// The index order for a cycle over a calendar of n words.
///
/// Cycle 0 is the committed calendar order itself (identity), so the first pass
/// plays the frozen sequence exactly as generated. Every later cycle is a fresh
/// deterministic permutation, and its first word is forced to differ from the
/// previous cycle's last word so no word repeats across a cycle boundary.
func cycleOrder(cycle: Int, n: Int) -> [Int] {
    if cycle == 0 { return Array(0..<n) }
    var order = seededPermutation(n, seed: seedForCycle(cycle))
    if n < 2 { return order }
    // Recursive, exactly as the TypeScript is. Fine for the cycle depths this
    // sees (one per full pass through a 626-word calendar, so roughly one
    // every 20 months), and it keeps the port readable next to the original.
    let previousLast = cycleOrder(cycle: cycle - 1, n: n)[n - 1]
    if order[0] == previousLast {
        order.swapAt(0, 1)
    }
    return order
}

/// The source word for a given day, read from the frozen daily calendar.
///
/// The day index splits into a cycle and a position. The first cycle is the
/// calendar in its committed order; once exhausted, each later cycle is a fresh
/// deterministic shuffle, so the sequence never repeats a word within a pass and
/// never repeats across a pass boundary. Appending words to the calendar leaves
/// every first-cycle day fixed, which is the whole point of the freeze.
///
/// `throws` rather than the TypeScript's bare `throw new Error(...)`: the
/// caller is forced by the compiler to write `try`, so an empty calendar cannot
/// be ignored by accident.
public func dailySourceWord(
    calendar: [String],
    date: Date,
    epoch: EpochDate = dailyEpoch,
    timeZone: TimeZone
) throws -> String {
    guard !calendar.isEmpty else { throw EngineError.emptyCalendar }

    // Guard against pre-epoch dates by flooring at cycle/position 0.
    let safeIndex = max(0, dayIndex(date, epoch: epoch, timeZone: timeZone))
    let n = calendar.count
    let cycle = safeIndex / n
    let position = safeIndex % n
    return calendar[cycleOrder(cycle: cycle, n: n)[position]]
}
