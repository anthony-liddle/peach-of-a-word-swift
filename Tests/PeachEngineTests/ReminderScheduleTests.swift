import Foundation
import Testing
@testable import PeachEngine

/// The daily reminder's schedule: which days, at what time on the clock.
@Suite("the daily reminder's schedule")
struct ReminderScheduleTests {
    static let la = "America/Los_Angeles"
    static let tokyo = "Asia/Tokyo"

    static func calendar(_ zone: String) -> Foundation.Calendar {
        var c = Foundation.Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: zone)!
        return c
    }

    static func date(_ zone: String, _ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int = 0) -> Date {
        calendar(zone).date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    /// The game's day for `date` in `zone`, as progress is keyed.
    static func storageDay(_ date: Date, _ zone: String) -> Int {
        dayIndex(date, epoch: storageEpoch, timeZone: TimeZone(identifier: zone)!)
    }

    static func fire(_ now: Date, _ zone: String, minutes: Int = 19 * 60,
                     played: (Int) -> Bool = { _ in false }) -> [DateComponents] {
        ReminderSchedule.fireDates(now: now, minutes: minutes, calendar: calendar(zone), played: played)
    }

    @Test("a day already played is skipped")
    func skipsAPlayedDay() {
        let now = Self.date(Self.la, 2026, 10, 23, 9)
        let today = Self.storageDay(now, Self.la)
        let dates = Self.fire(now, Self.la) { $0 == today }
        #expect(dates.first?.month == 10 && dates.first?.day == 24)
        #expect(!dates.contains { $0.month == 10 && $0.day == 23 })
    }

    @Test("an unplayed day keeps its reminder while its time is to come")
    func keepsAnUnplayedDay() {
        let dates = Self.fire(Self.date(Self.la, 2026, 10, 23, 9), Self.la)
        #expect(dates.first?.month == 10 && dates.first?.day == 23)
    }

    /// A day to come can have words too, on a phone whose clock went back or
    /// that crossed the date line westward, so every day is asked, not only
    /// today.
    @Test("a played day later in the fortnight is skipped as well")
    func skipsALaterPlayedDay() {
        let now = Self.date(Self.la, 2026, 10, 23, 9)
        let later = Self.storageDay(now, Self.la) + 3
        let dates = Self.fire(now, Self.la) { $0 == later }
        #expect(!dates.contains { $0.month == 10 && $0.day == 26 })
        #expect(dates.contains { $0.month == 10 && $0.day == 25 })
    }

    @Test("today's is left out once its time has gone")
    func todayAfterItsTime() {
        let dates = Self.fire(Self.date(Self.la, 2026, 10, 23, 20), Self.la)
        #expect(dates.first?.day == 24)
    }

    @Test("it moves with the time")
    func movesWithTheTime() {
        let now = Self.date(Self.la, 2026, 10, 23, 6)
        for minutes in [7 * 60 + 30, 19 * 60, 21 * 60 + 45] {
            let dates = Self.fire(now, Self.la, minutes: minutes)
            #expect(!dates.isEmpty)
            #expect(dates.allSatisfy { $0.hour == minutes / 60 && $0.minute == minutes % 60 })
        }
    }

    @Test("one a day, a fortnight ahead, well under iOS's 64")
    func aFortnight() {
        let dates = Self.fire(Self.date(Self.la, 2026, 10, 23, 6), Self.la)
        #expect(dates.count == ReminderSchedule.daysAhead)
        #expect(Set(dates.map { "\($0.month!)-\($0.day!)" }).count == dates.count)
        #expect(ReminderSchedule.daysAhead < 64)
    }

    /// 1 November 2026, when the clocks go back in Los Angeles: 7 pm stays
    /// 7 pm on the clock, either side of it.
    @Test("daylight saving keeps the time on the clock")
    func daylightSaving() throws {
        let cal = Self.calendar(Self.la)
        let dates = Self.fire(Self.date(Self.la, 2026, 10, 30, 12), Self.la)
        for fire in dates.prefix(4) {
            let at = try #require(cal.date(from: fire))
            #expect(cal.component(.hour, from: at) == 19, "\(fire)")
        }
        // The same wall-clock time, an hour further from UTC after the change.
        let before = try #require(dates.first { $0.month == 10 && $0.day == 31 }.flatMap(cal.date(from:)))
        let after = try #require(dates.first { $0.month == 11 && $0.day == 2 }.flatMap(cal.date(from:)))
        #expect(after.timeIntervalSince(before) == 2 * 86_400 + 3_600)
    }

    /// No zone in the dates, so they fire at that time on whatever clock the
    /// phone keeps when the day comes.
    @Test("the dates carry no time zone")
    func noZone() {
        let dates = Self.fire(Self.date(Self.la, 2026, 10, 23, 6), Self.la)
        #expect(!dates.isEmpty)
        #expect(dates.allSatisfy { $0.timeZone == nil && $0.calendar == nil })
    }

    /// One instant, 03:00 UTC on 23 October: still the 22nd in Los Angeles and
    /// already the 23rd in Tokyo. Each phone's reminder skips its own played
    /// day, the one the game keyed that day's words on, so a reminder can
    /// never be checked against another zone's day.
    @Test("the day it checks is the day the game keys, in any zone")
    func zonesAgree() {
        let instant = Self.date("UTC", 2026, 10, 23, 3)
        for (zone, localDay) in [(Self.la, 22), (Self.tokyo, 23)] {
            let gameDay = Self.storageDay(instant, zone)
            var asked: [Int] = []
            let dates = Self.fire(instant, zone, minutes: 23 * 60) {
                asked.append($0)
                return $0 == gameDay
            }
            #expect(asked.contains(gameDay), "\(zone)")
            #expect(!dates.contains { $0.month == 10 && $0.day == localDay }, "\(zone)")
            #expect(dates.contains { $0.month == 10 && $0.day == localDay + 1 }, "\(zone)")
        }
    }
}
