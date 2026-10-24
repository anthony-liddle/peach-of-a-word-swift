import Foundation

/// When the daily reminder fires.
///
/// **One notification a day, scheduled ahead, never one that repeats,** so a
/// day already played can be left out: a repeating notification would fire
/// on a board that has words, which is the nag this is built not to be. The
/// app asks for the schedule again whenever it opens, when the day turns over
/// or the clock changes, when the time is changed, and at the day's first
/// find, so the end of the fortnight is only reached by a phone left unopened
/// for a fortnight.
///
/// It lives in the engine, not the app, so `swift test` can hold it.
public enum ReminderSchedule {
    /// How many days ahead are scheduled at once, today included.
    ///
    /// iOS keeps at most 64 pending notification requests for an app ("a limit
    /// of 64 for how many simultaneous notification requests can be
    /// active/pending at one time per app", an Apple engineer, developer
    /// forums thread 811171). Fourteen leaves fifty of margin.
    public static let daysAhead = 14

    /// The time it fires by default, in minutes after midnight: 7 pm.
    ///
    /// It fires only on a day with no words, so its time is the moment a day
    /// unplayed so far is worth a word: late enough that a day played at any
    /// usual hour has already cancelled it, early enough to play before bed.
    public static let defaultMinutes = 19 * 60

    /// The days to fire on, as wall-clock dates, soonest first.
    ///
    /// **Year, month, day, hour and minute, and no time zone,** so each fires
    /// at that time on the phone's clock wherever the phone is, and across
    /// daylight saving. Measured on 23 October 2026 with
    /// `UNCalendarNotificationTrigger.nextTriggerDate()`: 7 pm on 2 November
    /// came out as 03:00 UTC with the zone set to Los Angeles, 00:00 UTC in New
    /// York and 19:00 UTC in London, and 7 pm either side of the night US
    /// clocks go back as 02:00 and 03:00 UTC.
    ///
    /// **Each day is checked as the game keys it:** `played` is asked for the
    /// storage day of that date in the calendar's zone, which is how progress
    /// is saved (`dayIndex` against `storageEpoch`). Every day is asked, not
    /// only today, since a phone whose clock went back has words on a day
    /// still to come.
    ///
    /// - Parameters:
    ///   - now: the moment of scheduling.
    ///   - minutes: the time, in minutes after local midnight.
    ///   - calendar: the phone's calendar, in the phone's zone.
    ///   - played: whether the storage day given has words.
    public static func fireDates(
        now: Date, minutes: Int, calendar: Foundation.Calendar, played: (Int) -> Bool
    ) -> [DateComponents] {
        let today = calendar.startOfDay(for: now)
        let clamped = min(max(minutes, 0), 24 * 60 - 1)
        var dates: [DateComponents] = []
        for ahead in 0..<daysAhead {
            guard let day = calendar.date(byAdding: .day, value: ahead, to: today) else { continue }
            if played(dayIndex(day, epoch: storageEpoch, timeZone: calendar.timeZone)) { continue }
            var fire = calendar.dateComponents([.year, .month, .day], from: day)
            fire.hour = clamped / 60
            fire.minute = clamped % 60
            // Today's, only while its time is still to come.
            if ahead == 0, let at = calendar.date(from: fire), at <= now { continue }
            dates.append(fire)
        }
        return dates
    }
}
