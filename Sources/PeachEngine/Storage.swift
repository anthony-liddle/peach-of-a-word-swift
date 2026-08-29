import Foundation

/// Local persistence for the streak and per-day progress. No backend, matching
/// the web version.
///
/// This lives in the engine package rather than the app for two reasons. It is
/// pure logic over engine concepts (`storageEpoch`, `dayIndex`,
/// `streakTierIndex`) with no UI in it, and putting it here means `swift test`
/// covers it. The app supplies the `UserDefaults`-backed store; the tests supply
/// an in-memory one. That is the same split the web version uses with its
/// `KeyValueStore` interface, and for the same reason.

/// The one thing storage needs from its backing: get and set bytes by key.
public protocol KeyValueStore: AnyObject {
    func data(forKey key: String) -> Data?
    func set(_ data: Data?, forKey key: String)
}

/// An in-memory store, for tests and for any environment where the real one is
/// unavailable. Progress held here does not survive relaunch.
public final class InMemoryStore: KeyValueStore {
    private var contents: [String: Data]

    public init(contents: [String: Data] = [:]) {
        self.contents = contents
    }

    public func data(forKey key: String) -> Data? { contents[key] }

    public func set(_ data: Data?, forKey key: String) {
        if let data { contents[key] = data } else { contents.removeValue(forKey: key) }
    }
}

/// Found words saved for one day, plus the word they belong to.
///
/// The source word is stored so a day can be rejected rather than
/// misattributed: if the calendar is regenerated and a date now serves a
/// different word, yesterday's finds must not appear under it. The web version
/// guards the same way, and it is also how the endless rehydration guard works
/// there (`data.sourceEntry(stored.sourceWord)`, only rehydrate a word the
/// shipped data still knows).
struct DayProgress: Codable {
    var sourceWord: String
    var found: [String]
}

struct StreakState: Codable {
    var count: Int
    var lastClearedDayIndex: Int?

    static let empty = StreakState(count: 0, lastClearedDayIndex: nil)
}

/// Everything persisted, as one value under one key.
///
/// Decoding is deliberately lenient: every field has a default and is read with
/// `decodeIfPresent`. Swift's synthesised `Codable` is strict, and a strict
/// decode would mean that adding one field in a future version, or shipping one
/// malformed key, silently throws away a streak. Unknown keys are ignored by
/// `Codable` already.
struct PersistedState: Codable {
    static let currentVersion = 1

    var version: Int
    var days: [String: DayProgress]
    var streak: StreakState

    static let empty = PersistedState(
        version: currentVersion, days: [:], streak: .empty
    )

    init(version: Int, days: [String: DayProgress], streak: StreakState) {
        self.version = version
        self.days = days
        self.streak = streak
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // A missing version is treated as the current one rather than as
        // corruption, so a hand-edited or partially written blob keeps its
        // streak. A version we do not understand is handled in GameStorage.read.
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? Self.currentVersion
        days = try c.decodeIfPresent([String: DayProgress].self, forKey: .days) ?? [:]
        streak = try c.decodeIfPresent(StreakState.self, forKey: .streak) ?? .empty
    }
}

/// Reads and writes the persisted state.
///
/// Every failure path starts clean rather than throwing. A launch crash from bad
/// persisted state is the worst failure this app could have, so a corrupt,
/// truncated, or future-versioned blob is treated as "no saved progress".
public final class GameStorage {
    /// Namespaced and versioned, so a future incompatible format can take a new
    /// key and leave this one untouched rather than overwriting it.
    static let storageKey = "peach-of-a-word/v1"

    /// Days retained. Fourteen is what the web keeps. At roughly 50 found words
    /// of 8 characters, a day is well under 1 KB and fourteen days is a few KB,
    /// which is why `UserDefaults` is the right home for this (see the app's
    /// `UserDefaultsStore`).
    static let maxDaysKept = 14

    private let store: KeyValueStore

    public init(store: KeyValueStore) {
        self.store = store
    }

    // MARK: Reading and writing

    private func read() -> PersistedState {
        guard let data = store.data(forKey: Self.storageKey) else { return .empty }
        do {
            let decoded = try JSONDecoder().decode(PersistedState.self, from: data)
            // A blob written by a newer version of the app cannot be understood
            // here. Start clean rather than guess at its shape.
            guard decoded.version <= PersistedState.currentVersion else { return .empty }
            return decoded
        } catch {
            // Corrupt, truncated, or not JSON at all. Play, do not crash.
            return .empty
        }
    }

    private func write(_ state: PersistedState) {
        var state = state
        state.version = PersistedState.currentVersion
        // Keep only the most recent days so storage never grows without bound.
        let ordered = state.days.keys
            .compactMap(Int.init)
            .sorted(by: >)
        for key in ordered.dropFirst(Self.maxDaysKept) {
            state.days.removeValue(forKey: String(key))
        }
        guard let data = try? JSONEncoder().encode(state) else { return }
        store.set(data, forKey: Self.storageKey)
    }

    // MARK: Day progress

    /// Found words saved for a day, but only if the source word still matches.
    ///
    /// A mismatch means the calendar moved under this date, so the stored words
    /// belong to a different puzzle and are discarded rather than restored.
    public func loadDayProgress(dayIndex: Int, sourceWord: String) -> [String] {
        guard let day = read().days[String(dayIndex)], day.sourceWord == sourceWord else {
            return []
        }
        return day.found
    }

    public func saveDayProgress(dayIndex: Int, sourceWord: String, found: [String]) {
        var state = read()
        state.days[String(dayIndex)] = DayProgress(sourceWord: sourceWord, found: found)
        write(state)
    }

    // MARK: Streak

    /// Record that a daily reached the streak rank. Consecutive days extend the
    /// streak, a gap restarts it, and recording the same day twice is a no-op.
    public func recordDailyCleared(dayIndex: Int) {
        var state = read()
        let last = state.streak.lastClearedDayIndex
        if last == dayIndex { return }
        state.streak.count = (last == dayIndex - 1) ? state.streak.count + 1 : 1
        state.streak.lastClearedDayIndex = dayIndex
        write(state)
    }

    /// The streak as of today. A missed day shows it as broken.
    public func currentStreak(todayIndex: Int) -> Int {
        let streak = read().streak
        guard let last = streak.lastClearedDayIndex else { return 0 }
        return last >= todayIndex - 1 ? streak.count : 0
    }

    /// Take a streak transferred from the web build, if it beats what is here.
    ///
    /// **Why both fields.** A streak is two values, and carrying only `count`
    /// produces a state the app cannot otherwise reach: a 53 with no record of
    /// when it was last extended. The next morning `currentStreak` sees
    /// `last < today - 1`, reads it as broken, and the first clear restarts at
    /// 1. The player would get the number, feel good about it, and lose it
    /// overnight, which is worse than never transferring.
    ///
    /// **Why the indices are comparable at all.** Both surfaces key days off
    /// `storageEpoch`, fixed at 2026-01-01 and documented as never moving, and
    /// both count whole calendar days by re-anchoring local Y/M/D into UTC. So
    /// an incoming `lastClearedDayIndex` needs no translation.
    ///
    /// The assumption inside that: each side computes local midnight on
    /// whichever device is computing. The web reads `date.getFullYear()` and so
    /// silently uses the browser's zone; this app is passed `.current`. The two
    /// indices therefore agree only while both devices are in the same time
    /// zone. Across zones near midnight they can differ by one, which would
    /// show up as a streak arriving a day stale or a day early. That is
    /// acceptable for a one-time handoff in one place and would not be for
    /// anything recurring.
    ///
    /// **The rule, in order.** Liveness first, because it is the condition that
    /// prevents an actively bad outcome rather than merely a suboptimal one.
    ///
    /// 1. Is the incoming streak still alive by this app's own rule,
    ///    `last >= todayIndex - 1`? A 53 that stopped a week ago is already
    ///    dead. Accepting it would show 53 today and reset tomorrow.
    /// 2. Is it strictly higher than what is here *live*, from
    ///    `currentStreak(todayIndex:)` rather than the stored `count`? A stored
    ///    count that is itself dead has an effective value of 0, so comparing
    ///    raw counts would let a dead 12 reject a live 53, which is exactly the
    ///    case the transfer exists for. Equal is rejected too, and not only as
    ///    a no-op: adopting an equal streak whose `lastCleared` is more recent
    ///    would make today's clear on this device a no-op and cost a day.
    ///
    /// Returns whether the streak was taken, so a caller can tell the player.
    @discardableResult
    public func adoptStreak(count: Int, lastClearedDayIndex: Int, todayIndex: Int) -> Bool {
        // A count of zero or less is not a streak, and a day that has not
        // happened yet cannot have been cleared. Both mean the input is wrong
        // rather than merely unlucky; a future index would additionally freeze
        // the streak, since every real day after it reads as a gap.
        guard count > 0, lastClearedDayIndex <= todayIndex else { return false }
        guard lastClearedDayIndex >= todayIndex - 1 else { return false }
        guard count > currentStreak(todayIndex: todayIndex) else { return false }

        var state = read()
        state.streak.count = count
        state.streak.lastClearedDayIndex = lastClearedDayIndex
        write(state)
        return true
    }
}
