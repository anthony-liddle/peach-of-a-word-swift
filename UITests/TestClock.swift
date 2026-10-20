import Foundation

/// The phone's today, as the app under test sees it.
///
/// `PEACH_DAY_OFFSET`, set inside the simulator with `launchctl setenv`, moves
/// the app's Debug clock by that many days on every launch, and the test runner
/// inherits the same variable, the way `ui-tests-off-utc` moves the zone. A test
/// that works a date out from today reads it here, so a run moved a year ahead
/// checks the year ahead rather than a split clock. Unset, it is zero and `now`
/// is `Date()`.
///
///     xcrun simctl spawn "$UDID" launchctl setenv PEACH_DAY_OFFSET 400
enum TestClock {
    static var dayOffset: Int {
        Int(ProcessInfo.processInfo.environment["PEACH_DAY_OFFSET"] ?? "") ?? 0
    }

    static var now: Date {
        Calendar.current.date(byAdding: .day, value: dayOffset, to: Date()) ?? Date()
    }

    /// The `-dayOffset` that puts the app on the next 15th of a month, on or
    /// after today.
    ///
    /// For a test that looks in the archive's current month and needs days on
    /// both sides of today. On the 1st the month has no past day, and on its
    /// last day no future one, so such a test fails on a day or two of every
    /// month and passes on all the others. On a 15th both always exist, and a
    /// launch that crosses midnight only moves it to the 16th. The app adds
    /// `PEACH_DAY_OFFSET` to this, and `now` already carries it, so the two
    /// still agree on a run moved ahead.
    ///
    /// **Forward, never back.** Foundation reads `-dayOffset -3` as a key with
    /// no value and the app stays on today, so after the 15th this is the next
    /// month's 15th rather than this month's.
    static var midMonthDayOffset: String {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        let next = cal.nextDate(after: today, matching: DateComponents(day: 15),
                                matchingPolicy: .nextTime)!
        let target = cal.component(.day, from: today) == 15 ? today : next
        return String(cal.dateComponents([.day], from: today, to: target).day!)
    }
}
