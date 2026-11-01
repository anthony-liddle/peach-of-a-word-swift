import Foundation
import Testing
@testable import PeachEngine

/// Which board the peach dresses up for: by the board's own date, never
/// today's. The web holds the same rules in `src/ui/costumeDay.test.tsx`.
@Suite("the days the peach dresses up")
struct CostumeDayTests {
    /// A board's day as the app keys it: days since `storageEpoch`.
    private func storageDay(_ year: Int, _ month: Int, _ day: Int) -> Int {
        var utc = Foundation.Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let epoch = utc.date(from: DateComponents(year: storageEpoch.year,
                                                  month: storageEpoch.month, day: storageEpoch.day))!
        let date = utc.date(from: DateComponents(year: year, month: month, day: day))!
        return utc.dateComponents([.day], from: epoch, to: date).day!
    }

    @Test("a row for each day, Halloween and the winter")
    func table() {
        #expect(costumeDays.map { [$0.month, $0.day, $0.weekday, $0.nth] }
                == [[10, 31, nil, nil], [11, nil, 4, 4], [12, 21, nil, nil], [12, 24, nil, nil],
                    [12, 25, nil, nil], [12, 31, nil, nil], [1, 1, nil, nil]])
        #expect(costumeDays.map(\.costume.rawValue)
                == ["ghost", "pie-crust", "beanie", "antlers", "santa-hat", "top-hat", "top-hat"])
    }

    @Test("31 October's board wears it, in any year")
    func theDay() {
        #expect(boardCostume(storageDay: storageDay(2026, 10, 31)) == .ghost)
        #expect(boardCostume(storageDay: storageDay(2027, 10, 31)) == .ghost)
        #expect(boardCostume(storageDay: storageDay(2028, 10, 31)) == .ghost)
    }

    @Test("no other day's board wears it")
    func otherDays() {
        #expect(boardCostume(storageDay: storageDay(2026, 10, 30)) == nil)
        #expect(boardCostume(storageDay: storageDay(2026, 11, 1)) == nil)
        #expect(boardCostume(storageDay: storageDay(2026, 1, 2)) == nil)
    }

    @Test("a board with no day never wears it")
    func noDay() {
        #expect(boardCostume(storageDay: nil) == nil)
    }

    @Test("a preview date stands in for the board's")
    func preview() {
        #expect(boardCostume(storageDay: storageDay(2026, 10, 20), preview: "2026-10-31") == .ghost)
        #expect(boardCostume(storageDay: storageDay(2026, 10, 31), preview: "2026-10-30") == nil)
        // A malformed preview is ignored, so the board's own date rules.
        #expect(boardCostume(storageDay: storageDay(2026, 10, 31), preview: "halloween") == .ghost)
    }
}

/// A board's day as the app keys it, for a date written as year, month and day.
private func storageDay(on ymd: [Int]) -> Int {
    var utc = Foundation.Calendar(identifier: .gregorian)
    utc.timeZone = TimeZone(identifier: "UTC")!
    let epoch = utc.date(from: DateComponents(year: storageEpoch.year,
                                              month: storageEpoch.month, day: storageEpoch.day))!
    let date = utc.date(from: DateComponents(year: ymd[0], month: ymd[1], day: ymd[2]))!
    return utc.dateComponents([.day], from: epoch, to: date).day!
}

/// A winter costume day, by raw value so the suite reads the table as the web
/// writes it.
struct WinterDay: Sendable, CustomTestStringConvertible {
    let name: String
    let costume: String
    let spoken: String
    /// Its boards, as year, month and day.
    let days: [[Int]]
    /// The boards either side of them.
    let neighbours: [[Int]]

    var testDescription: String { name }

    static let years = 2026...2028

    /// A fixed date in each of the years the suite tries.
    static func every(_ month: Int, _ day: Int) -> [[Int]] {
        years.map { [$0, month, day] }
    }

    /// The days either side of each date.
    static func either(_ days: [[Int]]) -> [[Int]] {
        days.flatMap { [[$0[0], $0[1], $0[2] - 1], [$0[0], $0[1], $0[2] + 1]] }
    }

    /// Thanksgiving, the fourth Thursday of November, in years that reach both
    /// ends of its week: the 22nd in 2029 and the 28th in 2030.
    static let thanksgivings = [[2026, 11, 26], [2027, 11, 25], [2028, 11, 23],
                                [2029, 11, 22], [2030, 11, 28]]

    /// New Year's Eve and Day share the top hat, so they are one span: the day
    /// before is 30 December and the day after 2 January. Christmas Eve and
    /// Christmas Day are neighbours, each in its own costume, so a day's
    /// neighbours are held to not wearing that day's costume rather than to
    /// wearing nothing.
    static let all = [
        WinterDay(name: "Thanksgiving", costume: "pie-crust", spoken: "wearing a pie crust hat",
                  days: thanksgivings, neighbours: either(thanksgivings)),
        WinterDay(name: "The winter solstice", costume: "beanie", spoken: "wearing a knit beanie and scarf",
                  days: every(12, 21), neighbours: either(every(12, 21))),
        WinterDay(name: "Christmas Eve", costume: "antlers", spoken: "wearing antlers and a red nose",
                  days: every(12, 24), neighbours: either(every(12, 24))),
        WinterDay(name: "Christmas Day", costume: "santa-hat", spoken: "wearing a Santa hat",
                  days: every(12, 25), neighbours: either(every(12, 25))),
        WinterDay(name: "New Year's Eve and Day", costume: "top-hat", spoken: "wearing a top hat",
                  days: years.flatMap { [[$0, 12, 31], [$0 + 1, 1, 1]] },
                  neighbours: years.flatMap { [[$0, 12, 30], [$0 + 1, 1, 2]] }),
    ]
}

/// The winter's costume days, held to Halloween's rules: by the board's own
/// date, never today's. The web holds the same in `src/ui/costumeDay.test.tsx`.
/// A replayed board and another day's board played on the day are the app's
/// to get right, and `WinterCostumesOnTheDay` holds it to them.
@Suite("the winter's costume days")
struct WinterCostumeDayTests {
    @Test("the day's board wears it, in any year", arguments: WinterDay.all)
    func theDay(_ winter: WinterDay) {
        for day in winter.days {
            #expect(boardCostume(storageDay: storageDay(on: day))?.rawValue == winter.costume, "\(day)")
        }
    }

    @Test("the day before and the day after do not wear it", arguments: WinterDay.all)
    func neighbours(_ winter: WinterDay) {
        for day in winter.neighbours {
            #expect(boardCostume(storageDay: storageDay(on: day))?.rawValue != winter.costume, "\(day)")
        }
    }

    @Test("a board with no day never wears it", arguments: WinterDay.all)
    func noDay(_ winter: WinterDay) {
        #expect(boardCostume(storageDay: nil)?.rawValue != winter.costume)
    }

    @Test("a preview date stands in for the board's", arguments: WinterDay.all)
    func preview(_ winter: WinterDay) {
        let day = winter.days[0]
        let date = String(format: "%04d-%02d-%02d", day[0], day[1], day[2])
        #expect(boardCostume(storageDay: storageDay(on: [2026, 11, 20]), preview: date)?.rawValue
                == winter.costume)
    }

    @Test("it says what the peach is wearing", arguments: WinterDay.all)
    func spoken(_ winter: WinterDay) {
        #expect(Costume(rawValue: winter.costume)?.spoken == winter.spoken)
    }
}

/// Thanksgiving goes by the fourth Thursday of November, not a fixed date.
/// The web holds the same in `src/ui/costumeDay.test.tsx`.
@Suite("Thanksgiving goes by the fourth Thursday of November")
struct ThanksgivingTests {
    @Test("26 Nov 2026, 25 Nov 2027 and 23 Nov 2028 wear it")
    func theThursdays() {
        #expect(boardCostume(storageDay: storageDay(on: [2026, 11, 26])) == .pieCrust)
        #expect(boardCostume(storageDay: storageDay(on: [2027, 11, 25])) == .pieCrust)
        #expect(boardCostume(storageDay: storageDay(on: [2028, 11, 23])) == .pieCrust)
    }

    @Test("26 Nov 2027, the Friday after, does not")
    func notTheFriday() {
        #expect(boardCostume(storageDay: storageDay(on: [2027, 11, 26])) == nil)
    }

    @Test("the day before and the day after wear nothing, in any year")
    func neighbours() {
        for day in WinterDay.either(WinterDay.thanksgivings) {
            #expect(boardCostume(storageDay: storageDay(on: day)) == nil, "\(day)")
        }
    }

    @Test("a preview goes by the year's own Thursday")
    func preview() {
        let plain = storageDay(on: [2026, 11, 20])
        #expect(boardCostume(storageDay: plain, preview: "2027-11-25") == .pieCrust)
        #expect(boardCostume(storageDay: plain, preview: "2027-11-26") == nil)
    }
}
