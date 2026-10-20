import CryptoKit
import Foundation
import Testing
@testable import PeachEngine

/// The one trade of two future days, Antoine's amendment to the append-only
/// calendar, 2026-10-20: 31 October 2026 and 17 May 2027 trade words, so the
/// peach's Halloween board is `skeleton`. A trade re-dates those two days and
/// no other. The web pins the same hashes in `scripts/build-calendar.test.ts`,
/// so the two copies of the calendar cannot drift apart.
@Suite("the one trade of two future days")
struct CalendarTradeTests {
    static func raw() throws -> String {
        try String(contentsOf: dataDirectory.appendingPathComponent("daily-calendar.json"), encoding: .utf8)
    }

    static func sha256(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    @Test("is the calendar the web ships, byte for byte")
    func sameAsTheWeb() throws {
        #expect(Self.sha256(try Self.raw())
            == "ea5b0dc1855d28c947fecafc365f4c50095dfed1a59d46cc965590a6b719e8d2")
    }

    @Test("moved no other index: traded back, it is the calendar before")
    func nothingElseMoved() throws {
        let back = try Self.raw()
            .replacingOccurrences(of: "\"skeleton\"", with: "\"\u{0}\"")
            .replacingOccurrences(of: "\"genetics\"", with: "\"skeleton\"")
            .replacingOccurrences(of: "\"\u{0}\"", with: "\"genetics\"")
        #expect(Self.sha256(back)
            == "dddc844300ab461a1ba1bd217daefa6fcc1e9e5a2abb23bdefbb841d73f17163")
    }

    @Test("moves no other date, in this cycle or any reshuffled one after it")
    func everyOtherDateStays() throws {
        let now = try DailySequencePinTests.calendarWords()
        var before = now
        before.swapAt(130, 328)
        let utc = TimeZone(identifier: "UTC")!
        var cal = Foundation.Calendar(identifier: .gregorian)
        cal.timeZone = utc
        let start = cal.date(from: DateComponents(year: 2026, month: 6, day: 23, hour: 12))!
        let trade: (String) -> String = { $0 == "skeleton" ? "genetics" : $0 == "genetics" ? "skeleton" : $0 }
        for d in 0..<(365 * 6) {
            let date = cal.date(byAdding: .day, value: d, to: start)!
            let today = try dailySourceWord(calendar: now, date: date, timeZone: utc)
            let then = try dailySourceWord(calendar: before, date: date, timeZone: utc)
            #expect(today == trade(then), "\(date)")
        }
    }
}
