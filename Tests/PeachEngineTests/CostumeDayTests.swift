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

    @Test("one row, 31 October, and it is the ghost sheet")
    func table() {
        #expect(costumeDays.count == 1)
        #expect(costumeDays.first?.month == 10)
        #expect(costumeDays.first?.day == 31)
        #expect(costumeDays.first?.costume == .ghost)
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
        #expect(boardCostume(storageDay: storageDay(2026, 1, 1)) == nil)
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
