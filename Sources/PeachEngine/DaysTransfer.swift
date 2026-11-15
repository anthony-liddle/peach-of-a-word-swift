import Foundation

public struct DaysTransfer: Equatable, Sendable {
    public struct Streak: Equatable, Sendable {
        public let count: Int
        public let lastClearedDayIndex: Int
        public init(count: Int, lastClearedDayIndex: Int) {
            self.count = count
            self.lastClearedDayIndex = lastClearedDayIndex
        }
    }

    public struct Day: Equatable, Sendable {
        public let sourceWord: String
        public let found: [String]
        public init(sourceWord: String, found: [String]) {
            self.sourceWord = sourceWord
            self.found = found
        }
    }

    public static let maxLength = 2_000_000

    public let streak: Streak?
    public let days: [Int: Day]
    public let unreadableWords: Int

    public init(streak: Streak?, days: [Int: Day], unreadableWords: Int) {
        self.streak = streak
        self.days = days
        self.unreadableWords = unreadableWords
    }

    public init?(text: String) {
        return nil
    }
}
