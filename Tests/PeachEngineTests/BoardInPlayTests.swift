import Foundation
import Testing
@testable import PeachEngine

/// The board in play, kept so a launch later the same day opens on it.
///
/// Bea opened a past day, closed the app, and came back to today's board
/// (5 November 2026). `BackToTheDayYouWereOn` holds what she sees; these hold
/// the rule the launch asks of the store: a past day's board, in play today,
/// and nothing else.
@Suite("the board in play")
struct BoardInPlayTests {
    final class CountingStore: KeyValueStore {
        let inner = InMemoryStore()
        var writes = 0
        func data(forKey key: String) -> Data? { inner.data(forKey: key) }
        func set(_ data: Data?, forKey key: String) {
            writes += 1
            inner.set(data, forKey: key)
        }
    }

    static let today = 308

    @Test("a past day in play today survives a relaunch")
    func aPastDaySurvives() {
        let store = InMemoryStore()
        GameStorage(store: store).rememberBoardInPlay(dayIndex: Self.today - 4, todayIndex: Self.today)
        #expect(GameStorage(store: store).pastBoardToResume(todayIndex: Self.today) == Self.today - 4)
    }

    @Test("today's board is nothing to resume, nor is no record")
    func todayIsNothingToResume() {
        let storage = GameStorage(store: InMemoryStore())
        #expect(storage.pastBoardToResume(todayIndex: Self.today) == nil)
        storage.rememberBoardInPlay(dayIndex: Self.today, todayIndex: Self.today)
        #expect(storage.pastBoardToResume(todayIndex: Self.today) == nil)
    }

    @Test("back to today after a past day forgets the past day")
    func backToTodayForgets() {
        let storage = GameStorage(store: InMemoryStore())
        storage.rememberBoardInPlay(dayIndex: Self.today - 4, todayIndex: Self.today)
        storage.rememberBoardInPlay(dayIndex: Self.today, todayIndex: Self.today)
        #expect(storage.pastBoardToResume(todayIndex: Self.today) == nil)
    }

    /// The title has had its day by then, and it leads to today.
    @Test("a past day left on an earlier day is not resumed")
    func notOnALaterDay() {
        let storage = GameStorage(store: InMemoryStore())
        storage.rememberBoardInPlay(dayIndex: Self.today - 4, todayIndex: Self.today - 1)
        #expect(storage.pastBoardToResume(todayIndex: Self.today) == nil)
    }

    /// A clock moved back puts the record's day ahead of today; the board is
    /// still today's to choose, not the record's.
    @Test("a record from a day after today is not resumed")
    func notFromTheFuture() {
        let storage = GameStorage(store: InMemoryStore())
        storage.rememberBoardInPlay(dayIndex: Self.today - 4, todayIndex: Self.today + 1)
        #expect(storage.pastBoardToResume(todayIndex: Self.today) == nil)
        storage.rememberBoardInPlay(dayIndex: Self.today + 1, todayIndex: Self.today)
        #expect(storage.pastBoardToResume(todayIndex: Self.today) == nil,
                "a day after today was offered as a past day")
    }

    @Test("a half-written or corrupt record resumes nothing")
    func corruptResumesNothing() {
        let store = InMemoryStore()
        let storage = GameStorage(store: store)
        store.set(Data("not json".utf8), forKey: GameStorage.boardKey)
        #expect(storage.pastBoardToResume(todayIndex: Self.today) == nil)
        store.set(Data(#"{"board":304}"#.utf8), forKey: GameStorage.boardKey)
        #expect(storage.pastBoardToResume(todayIndex: Self.today) == nil,
                "a board with no day it was in play on was resumed")
        store.set(Data(#"{"on":308}"#.utf8), forKey: GameStorage.boardKey)
        #expect(storage.pastBoardToResume(todayIndex: Self.today) == nil,
                "a record with no board was resumed")
        store.set(Data(#"{"board":"304","on":308}"#.utf8), forKey: GameStorage.boardKey)
        #expect(storage.pastBoardToResume(todayIndex: Self.today) == nil)
    }

    @Test("opening the board already remembered writes nothing")
    func writesOnlyAChange() {
        let store = CountingStore()
        let storage = GameStorage(store: store)
        storage.rememberBoardInPlay(dayIndex: Self.today - 4, todayIndex: Self.today)
        storage.rememberBoardInPlay(dayIndex: Self.today - 4, todayIndex: Self.today)
        #expect(store.writes == 1)
        storage.rememberBoardInPlay(dayIndex: Self.today, todayIndex: Self.today)
        #expect(store.writes == 2)
    }
}
