import Foundation

public struct DaysImportPlan: Equatable, Sendable {
    public let days: [Int: DaysTransfer.Day]
    public let differentWord: Int
    public let tomorrow: Int
    public let unreadableWords: Int
    public let streak: DaysTransfer.Streak?
}

public struct DaysImportResult: Equatable, Sendable {
    public var cameAcross = 0
    public var finished = 0
    public var peaches = 0
    public var streakTaken = false
    public var streak = 0
    public var differentWord = 0
    public var tomorrow = 0
    public var unknownWords = 0
}

extension GameStorage {
    public func planImport(
        _ transfer: DaysTransfer, todayIndex: Int, firstPlayableDayIndex: Int,
        crown: (Int) -> String?
    ) -> DaysImportPlan {
        DaysImportPlan(days: [:], differentWord: 0, tomorrow: 0, unreadableWords: 0, streak: nil)
    }

    public func applyImport(
        _ plan: DaysImportPlan, todayIndex: Int, firstPlayableDayIndex: Int,
        puzzles: [Int: Puzzle]
    ) -> DaysImportResult {
        DaysImportResult()
    }

    @discardableResult
    public func raiseOutcome(dayIndex: Int, reached: Int, on: Int) -> Bool {
        false
    }
}
