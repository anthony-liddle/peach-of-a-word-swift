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

        // Re-arm the expansion. A transfer can land after the app has already
        // launched and marked the back-fill done, and without this the run she
        // just handed over would never be expanded into the calendar.
        var outcomes = readOutcomes()
        if outcomes.backFilled {
            outcomes.backFilled = false
            writeOutcomes(outcomes)
        }
        return true
    }
}

// MARK: - Day outcomes

extension KeyedDecodingContainer {
    /// Decode a field, or fall back. **Never throws.**
    ///
    /// A missing key, a key of the wrong type, and a malformed value all give
    /// the fallback. `decodeIfPresent` alone covers only the first of those: it
    /// throws on the other two, and a throw inside a hand-written `init(from:)`
    /// propagates out and costs the caller the whole value.
    func lenient<T: Decodable>(_ key: Key, _ fallback: T) -> T {
        ((try? decodeIfPresent(T.self, forKey: key)) ?? nil) ?? fallback
    }
}

/// What happened on one day's board: how far it got, when that happened, and
/// whether it was earned here or transferred from the web.
///
/// **`reached` is an `Int` rather than an enum, deliberately.** An enum with a
/// raw value throws on a case this build has not heard of, and this is exactly
/// the field a later build would extend. Read it with `>=` against the constants
/// below and a rung from the future still reads as at least a full basket,
/// rather than as nothing at all. That is the opposite of the usual advice in
/// this package, where `Rung` is an enum precisely so a `switch` over it is
/// checked; the difference is that a `Rung` is computed and this is read back
/// off a disk that a newer build may have written.
public struct DayOutcome: Codable, Equatable, Sendable {
    /// Opened, and no more. Not written today: the zero-find case was conceded
    /// rather than given a write on a path that currently never writes. Named
    /// anyway, so the ladder has its floor.
    public static let opened = 0
    /// Reached `streakTierIndex`, the rank that counts toward the streak.
    public static let cleared = 1
    /// Every set word found. The peak.
    public static let basket = 2

    public var reached: Int
    /// The storage day index on which this was achieved. Equal to the day's own
    /// index when it was played on the day, greater when it was caught up after.
    public var on: Int
    /// True when this came from the web back-fill rather than from play here.
    /// Such a day may claim `cleared` and never `basket`: the web never recorded
    /// basket completion, so a missing crown there means "not known".
    public var web: Bool

    public init(reached: Int, on: Int, web: Bool) {
        self.reached = reached
        self.on = on
        self.web = web
    }

    /// Every field defaults, and every field is read leniently.
    ///
    /// `PersistedState`'s decoder defaults every MISSING field and still loses
    /// the whole blob to one field that is present and the wrong type, because a
    /// throwing `decodeIfPresent` propagates out to `read`'s catch. That is a
    /// narrower guarantee than its own comment claims. This type does not
    /// inherit it: one bad field costs that field, never the entry.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        reached = c.lenient(.reached, Self.opened)
        on = c.lenient(.on, 0)
        web = c.lenient(.web, false)
    }
}

/// The container under the outcomes key.
struct OutcomeState: Codable {
    static let currentVersion = 1

    var version: Int
    var days: [String: DayOutcome]
    /// Whether the one-time expansion of a transferred streak run has happened.
    ///
    /// Kept here rather than beside the streak so the whole archive, including
    /// the record of how it was built, lives under one key and moves together.
    var backFilled: Bool

    static let empty = OutcomeState(version: currentVersion, days: [:], backFilled: false)

    init(version: Int, days: [String: DayOutcome], backFilled: Bool) {
        self.version = version
        self.days = days
        self.backFilled = backFilled
    }

    /// **Deliberately NOT version-gated, and that is the difference from
    /// `PersistedState`.**
    ///
    /// `GameStorage.read` discards a blob stamped newer than this build, which
    /// is right for a value whose shape it cannot guess at. It is wrong here.
    /// Discarding would throw away the archive on a rollback, which is the exact
    /// problem the separate key exists to avoid. Fields here are additive only,
    /// so an older build reads what it understands and `Codable` ignores the
    /// rest.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = c.lenient(.version, Self.currentVersion)
        days = c.lenient(.days, [:])
        backFilled = c.lenient(.backFilled, false)
    }
}

extension GameStorage {
    /// A second key, and the reason is worth stating where it is used.
    ///
    /// The outcomes map is never pruned and is written at most twice a day,
    /// where the main blob is pruned to fourteen days and is rewritten on every
    /// find. Keeping them apart means the find path never carries the archive's
    /// weight, and it means an older build that has never heard of this key
    /// cannot rewrite it. A TestFlight rollback therefore loses nothing here,
    /// rather than silently dropping the history on the next find.
    ///
    /// It is also why `PersistedState.currentVersion` stays at 1. Adding this
    /// fact needed no change to that blob at all, and a bump would mean an older
    /// build reading a newer blob, failing the `version <=` guard in `read`, and
    /// starting clean: the streak gone, for a field it did not need to
    /// understand.
    static let outcomesKey = "peach-of-a-word/outcomes/v1"

    private func readOutcomes() -> OutcomeState {
        guard let data = store.data(forKey: Self.outcomesKey) else { return .empty }
        // Corrupt or truncated costs the outcomes and nothing else. The streak
        // lives under a different key and is not in reach of this failure.
        return (try? JSONDecoder().decode(OutcomeState.self, from: data)) ?? .empty
    }

    private func writeOutcomes(_ state: OutcomeState) {
        var state = state
        state.version = OutcomeState.currentVersion
        guard let data = try? JSONEncoder().encode(state) else { return }
        store.set(data, forKey: Self.outcomesKey)
    }

    /// What happened on a day, or nil if nothing was ever recorded for it.
    ///
    /// Nil means "no record", which the calendar must draw as *before this*
    /// rather than as *you did not finish*.
    public func outcome(dayIndex: Int) -> DayOutcome? {
        readOutcomes().days[String(dayIndex)]
    }

    /// Record how far a day's board got. **There is no prune here, and that is
    /// the point of the type existing separately.**
    public func recordOutcome(dayIndex: Int, _ outcome: DayOutcome) {
        var state = readOutcomes()
        state.days[String(dayIndex)] = outcome
        writeOutcomes(state)
    }

    /// Every outcome, keyed by day index, for drawing the grid.
    ///
    /// Keys that are not integers are dropped rather than crashing: they cannot
    /// be produced by this code, and a hand-edited or foreign blob is not worth
    /// a trap.
    public func allOutcomes() -> [Int: DayOutcome] {
        var result: [Int: DayOutcome] = [:]
        for (key, value) in readOutcomes().days {
            if let day = Int(key) { result[day] = value }
        }
        return result
    }
}

extension GameStorage {
    /// Expand a transferred streak run into one outcome per day it covers. Once.
    ///
    /// **Why this exists at all.** A streak is a run-length encoding of cleared
    /// days: `recordDailyCleared` only increments when `last == dayIndex - 1`, so
    /// `count: 70, lastClearedDayIndex: L` proves that every day from `L - 69` to
    /// `L` reached the streak rank. That is seventy days of history the web never
    /// stored per-day and this app never stored at all, and it is destroyed by
    /// the first clear after a missed day, when `count` is set back to 1. This
    /// converts it into something durable before that happens.
    ///
    /// **It reads the STORED pair, never `currentStreak(todayIndex:)`.** That
    /// function returns 0 once the run is dead, and a dead run is still a true
    /// record of the days it covers. Reading the live value would silently expand
    /// nothing in exactly the case this was written for.
    ///
    /// **It clamps at the first playable day.** A run reaching back past the
    /// daily epoch would write outcomes for dates that have no board. Bea's
    /// seventy days start nine days after the epoch, so this is theoretical
    /// today; it stops being theoretical the moment a run is longer or
    /// `dailyEpoch` is re-anchored, which `Config.swift` documents as a thing
    /// that can happen.
    ///
    /// **It never overwrites a day that already has an outcome.** A day played
    /// here carries a richer record than the run can express, and the run can
    /// only ever claim `cleared`: the web did not record basket completion, so an
    /// expanded day must not claim it.
    ///
    /// - Parameter firstPlayableDayIndex: the daily epoch in storage days. Passed
    ///   in rather than derived here for the same reason `dayIndex` takes a time
    ///   zone: the engine does not reach for ambient values.
    /// - Returns: how many days were written, so a caller can tell whether the
    ///   expansion actually found anything.
    @discardableResult
    public func backFillOutcomesFromStreak(firstPlayableDayIndex: Int) -> Int {
        var outcomes = readOutcomes()
        guard !outcomes.backFilled else { return 0 }
        // Marked done even when there is nothing to expand, so this does not run
        // on every launch forever. `adoptStreak` re-arms it if a transfer lands
        // later.
        outcomes.backFilled = true

        let streak = read().streak
        guard streak.count > 0, let last = streak.lastClearedDayIndex else {
            writeOutcomes(outcomes)
            return 0
        }

        let firstOfRun = max(firstPlayableDayIndex, last - streak.count + 1)
        guard firstOfRun <= last else {
            writeOutcomes(outcomes)
            return 0
        }

        var written = 0
        for day in firstOfRun...last where outcomes.days[String(day)] == nil {
            outcomes.days[String(day)] = DayOutcome(
                reached: DayOutcome.cleared, on: day, web: true
            )
            written += 1
        }
        writeOutcomes(outcomes)
        return written
    }
}
