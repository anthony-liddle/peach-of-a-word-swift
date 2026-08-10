import Foundation
import Testing
@testable import PeachEngine

@Suite("dayIndex")
struct DayIndexTests {
    let epoch = EpochDate(year: 2026, month: 1, day: 1)
    let la = TimeZone(identifier: "America/Los_Angeles")!

    /// Build a Date from local calendar components in a given zone. The Swift
    /// equivalent of JavaScript's `new Date(y, m, d, h, min)`, which silently
    /// uses the machine's zone, which is the thing this port refuses to do.
    func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0,
              zone: TimeZone) -> Date {
        var cal = Foundation.Calendar(identifier: .gregorian)
        cal.timeZone = zone
        return cal.date(from: DateComponents(year: y, month: m, day: d,
                                             hour: h, minute: min))!
    }

    @Test("is zero on the epoch date")
    func epochDay() {
        #expect(dayIndex(date(2026, 1, 1, 9, 30, zone: la), epoch: epoch, timeZone: la) == 0)
    }

    @Test("counts whole calendar days forward")
    func forward() {
        #expect(dayIndex(date(2026, 1, 2, zone: la), epoch: epoch, timeZone: la) == 1)
        #expect(dayIndex(date(2026, 2, 1, zone: la), epoch: epoch, timeZone: la) == 31)
    }

    @Test("ignores the time of day (local-midnight rollover)")
    func midnightRollover() {
        let early = dayIndex(date(2026, 1, 10, 0, 1, zone: la), epoch: epoch, timeZone: la)
        let late = dayIndex(date(2026, 1, 10, 23, 59, zone: la), epoch: epoch, timeZone: la)
        #expect(early == late)
    }

    @Test("does not drift across a daylight-saving boundary, in either direction")
    func dstBothWays() {
        // Forward: US DST begins 2026-03-08, a 23-hour day.
        let beforeSpring = dayIndex(date(2026, 3, 7, zone: la), epoch: epoch, timeZone: la)
        let afterSpring = dayIndex(date(2026, 3, 9, zone: la), epoch: epoch, timeZone: la)
        #expect(afterSpring - beforeSpring == 2)

        // Back: US DST ends 2026-11-01, a 25-hour day.
        let beforeFall = dayIndex(date(2026, 10, 31, zone: la), epoch: epoch, timeZone: la)
        let afterFall = dayIndex(date(2026, 11, 2, zone: la), epoch: epoch, timeZone: la)
        #expect(afterFall - beforeFall == 2)
    }

    @Test("gives the same instant different day indices in different zones")
    func zoneMatters() {
        // 2026-09-05 12:00 UTC is already the 6th in Kiritimati (+14) and still
        // the 5th in Kolkata (+5:30). The daily is a function of the LOCAL date,
        // so these must differ. If dayIndex used Calendar.current this test
        // would pass or fail depending on the machine it ran on.
        let instant = Date(timeIntervalSince1970: 1_788_609_600)  // 2026-09-05T12:00:00Z
        let kiritimati = dayIndex(instant, epoch: epoch,
                                  timeZone: TimeZone(identifier: "Pacific/Kiritimati")!)
        let kolkata = dayIndex(instant, epoch: epoch,
                               timeZone: TimeZone(identifier: "Asia/Kolkata")!)
        #expect(kiritimati == kolkata + 1)
    }

    @Test("matches the TypeScript engine on every generated instant")
    func matchesOracle() {
        let oracle = OracleFixture.shared
        let formatter = ISO8601DateFormatter()
        #expect(oracle.dayIndexCases.count == 22)
        for c in oracle.dayIndexCases {
            let instant = formatter.date(from: c.instant)!
            let zone = TimeZone(identifier: c.zone)!
            #expect(dayIndex(instant, epoch: oracle.epochDate, timeZone: zone) == c.dayIndex,
                    "\(c.zone) \(c.instant)")
        }
    }

    @Test("keeps the storage epoch and the daily epoch on different indices")
    func twoEpochs() {
        // The whole point of the split: re-anchoring the calendar must not move
        // the persisted day keys.
        let d = date(2026, 8, 9, zone: la)
        #expect(dayIndex(d, epoch: storageEpoch, timeZone: la) == 220)
        #expect(dayIndex(d, epoch: dailyEpoch, timeZone: la) == 47)
    }

    /// The tempting Swift one-liner, kept only for comparison. See the note in
    /// docs/PORT-LOG.md: it was expected to diverge from the faithful port on
    /// midnight-transition zones and does not.
    func dayIndexViaDateComponents(_ date: Date, epoch: EpochDate, timeZone: TimeZone) -> Int {
        var cal = Foundation.Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let start = cal.date(from: DateComponents(year: epoch.year, month: epoch.month,
                                                  day: epoch.day))!
        return cal.dateComponents([.day],
                                  from: cal.startOfDay(for: start),
                                  to: cal.startOfDay(for: date)).day!
    }

    @Test("the Foundation one-liner agrees with the faithful port everywhere tested")
    func oneLinerAgrees() {
        let oracle = OracleFixture.shared
        let formatter = ISO8601DateFormatter()
        for c in oracle.dayIndexCases {
            let instant = formatter.date(from: c.instant)!
            let zone = TimeZone(identifier: c.zone)!
            #expect(dayIndexViaDateComponents(instant, epoch: oracle.epochDate, timeZone: zone)
                    == c.dayIndex, "\(c.zone) \(c.instant)")
        }
    }
}
