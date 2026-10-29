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
        #expect(costumeDays.map { [$0.month, $0.day] } == [[10, 31], [11, 26], [12, 24], [12, 31], [1, 1]])
        #expect(costumeDays.map(\.costume.rawValue) == ["ghost", "pie-crust", "antlers", "top-hat", "top-hat"])
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

/// A winter costume day, by raw value so the suite reads the table as the web
/// writes it.
struct WinterDay: Sendable, CustomTestStringConvertible {
    let name: String
    let costume: String
    let spoken: String
    /// Month, day, and how many years after the first day it falls.
    let days: [[Int]]
    let before: [Int]
    let after: [Int]

    var testDescription: String { name }

    /// New Year's Eve and Day share the top hat, so they are one span: the day
    /// before is 30 December and the day after 2 January. Christmas Eve's day
    /// after is Christmas Day, which will have its own costume, so a day's
    /// neighbours are held to not wearing that day's costume rather than to
    /// wearing nothing.
    static let all = [
        WinterDay(name: "Thanksgiving", costume: "pie-crust", spoken: "wearing a pie crust hat",
                  days: [[11, 26, 0]], before: [11, 25, 0], after: [11, 27, 0]),
        WinterDay(name: "Christmas Eve", costume: "antlers", spoken: "wearing antlers and a red nose",
                  days: [[12, 24, 0]], before: [12, 23, 0], after: [12, 25, 0]),
        WinterDay(name: "New Year's Eve and Day", costume: "top-hat", spoken: "wearing a top hat",
                  days: [[12, 31, 0], [1, 1, 1]], before: [12, 30, 0], after: [1, 2, 1]),
    ]
}

/// The winter's costume days, held to Halloween's rules: by the board's own
/// date, never today's. The web holds the same in `src/ui/costumeDay.test.tsx`.
/// A replayed board and another day's board played on the day are the app's
/// to get right, and `WinterCostumesOnTheDay` holds it to them.
@Suite("the winter's costume days")
struct WinterCostumeDayTests {
    private func storageDay(_ year: Int, _ day: [Int]) -> Int {
        var utc = Foundation.Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let epoch = utc.date(from: DateComponents(year: storageEpoch.year,
                                                  month: storageEpoch.month, day: storageEpoch.day))!
        let date = utc.date(from: DateComponents(year: year + day[2], month: day[0], day: day[1]))!
        return utc.dateComponents([.day], from: epoch, to: date).day!
    }

    @Test("the day's board wears it, in any year", arguments: WinterDay.all)
    func theDay(_ winter: WinterDay) {
        for year in 2026...2028 {
            for day in winter.days {
                #expect(boardCostume(storageDay: storageDay(year, day))?.rawValue == winter.costume,
                        "\(day) in \(year)")
            }
        }
    }

    @Test("the day before and the day after do not wear it", arguments: WinterDay.all)
    func neighbours(_ winter: WinterDay) {
        #expect(boardCostume(storageDay: storageDay(2026, winter.before))?.rawValue != winter.costume)
        #expect(boardCostume(storageDay: storageDay(2026, winter.after))?.rawValue != winter.costume)
    }

    @Test("a board with no day never wears it", arguments: WinterDay.all)
    func noDay(_ winter: WinterDay) {
        #expect(boardCostume(storageDay: nil)?.rawValue != winter.costume)
    }

    @Test("a preview date stands in for the board's", arguments: WinterDay.all)
    func preview(_ winter: WinterDay) {
        let day = winter.days[0]
        let date = String(format: "%04d-%02d-%02d", 2026 + day[2], day[0], day[1])
        #expect(boardCostume(storageDay: storageDay(2026, [11, 20, 0]), preview: date)?.rawValue
                == winter.costume)
    }

    @Test("it says what the peach is wearing", arguments: WinterDay.all)
    func spoken(_ winter: WinterDay) {
        #expect(Costume(rawValue: winter.costume)?.spoken == winter.spoken)
    }
}
