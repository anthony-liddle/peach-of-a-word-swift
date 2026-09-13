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

    init(sourceWord: String, found: [String]) {
        self.sourceWord = sourceWord
        self.found = found
    }

    /// **Field by field, like `PersistedState` and `DayOutcome`.** The
    /// synthesised decode this used to have throws on a blob missing any field,
    /// and `GameStorage.read` turns a throw into `.empty`, so one added field in
    /// a later build would cost the streak of anyone who rolled back. Measured
    /// in `2026-09-13 Archive Day Progress.md`: a required field threw, an
    /// optional one did not, and the whole blob went with it either way.
    ///
    /// A day that decodes to an empty source word matches no puzzle, so a
    /// half-written entry reads as no progress rather than as someone else's.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sourceWord = c.lenient(.sourceWord, "")
        found = c.lenient(.found, [])
    }
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

    /// How many days the one time back-fill rebuilds from their own words.
    ///
    /// **This was the prune's bound and is now a cap on work.** It used to mean
    /// "days retained", fourteen because that is what the web keeps, and the
    /// prune enforced it by dropping the lowest day index on every write. That
    /// bound is gone: every past day keeps its words under `archiveKey`.
    ///
    /// The number survives because the back-fill still has a reason to stop.
    /// Rebuilding a day's outcome from its found words costs a puzzle build, so
    /// the walk is held to the most recent days and the streak accounts for the
    /// rest, which is what it was always going to do for days beyond the words.
    /// Fourteen keeps that launch at the cost it was measured at.
    static let backFillWalkLimit = 14

    /// `backFillWalkLimit`, readable from outside the module.
    ///
    /// Exposed so a caller sizing work to the walk says the same number as the
    /// walk rather than repeating it.
    public static var backFillWalkDayCount: Int { backFillWalkLimit }

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

    /// **Nothing is trimmed here any more, and nothing needs to be.** This used
    /// to keep the fourteen highest day indices, which bounded the blob by
    /// dropping the lowest. That was a sound bound for a product where the only
    /// day ever written was today, and it became a defect the moment a past day
    /// could be opened: a day played from the calendar is a low index by
    /// definition, so the prune discarded the words in the same call that saved
    /// them. See `archiveKey`.
    ///
    /// The blob is bounded by what goes into it instead. `saveDayProgress` puts
    /// only the board in play here, and `retirePastDays` moves a day out as soon
    /// as it stops being that board, so `days` holds one entry, or two while a
    /// board is in flight across midnight.
    private func write(_ state: PersistedState) {
        var state = state
        state.version = PersistedState.currentVersion
        guard let data = try? JSONEncoder().encode(state) else { return }
        store.set(data, forKey: Self.storageKey)
    }

    // MARK: Day progress

    /// Found words saved for a day, but only if the source word still matches.
    ///
    /// A mismatch means the calendar moved under this date, so the stored words
    /// belong to a different puzzle and are discarded rather than restored.
    /// **The daily blob first, then the archive.** A day settles in exactly one
    /// of them, so the order is a tiebreak, and every case where both hold the
    /// day has the daily blob holding words at least as new as the archive's.
    ///
    /// Two cases put a day in both. A process killed partway through a move
    /// leaves it in both, and the writers order themselves so the daily copy is
    /// never the older one: see `saveDayProgress`. And if the device clock goes
    /// backwards, a day already retired can become the board in play again, and
    /// the copy being played now is the one in the daily blob. When the clock
    /// catches up, `retirePastDays` moves that copy over the archived one and
    /// the two agree again.
    ///
    /// A mismatched source word means the calendar moved under this date, so the
    /// stored words belong to a different puzzle and are discarded rather than
    /// restored. Checked in both stores, not only the first.
    public func loadDayProgress(dayIndex: Int, sourceWord: String) -> [String] {
        let key = String(dayIndex)
        if let day = read().days[key], day.sourceWord == sourceWord {
            return day.found
        }
        if let day = readArchive().days[key], day.sourceWord == sourceWord {
            return day.found
        }
        return []
    }

    /// Whether the one-time archive expansion has already happened.
    ///
    /// **Asked before the work, not after.** `backFillOutcomes` needs a
    /// classifier, and building one costs a puzzle per retained day. Without
    /// this the caller pays that on every launch and the flag then throws the
    /// answer away, which is the same wasted launch walk `archiveDays` was moved
    /// off the launch path to avoid.
    public func hasBackFilledOutcomes() -> Bool {
        readOutcomes().backFilled
    }

    /// Every day holding found words, across both stores, newest first.
    ///
    /// **Unbounded now, where it used to be held to fourteen by the prune.** The
    /// back-fill walks this to rebuild outcomes from play, and each day it walks
    /// costs a puzzle build, so the caller caps it. See `backFillWalkLimit`.
    public func daysWithProgress() -> [Int] {
        Set(read().days.keys).union(readArchive().days.keys)
            .compactMap(Int.init)
            .sorted(by: >)
    }

    /// Every day's words, both stores merged, with the live board winning.
    ///
    /// The same precedence as `loadDayProgress`, and for the same reason.
    func allDayProgress() -> [String: DayProgress] {
        readArchive().days.merging(read().days) { _, live in live }
    }

    /// Save a day's found words, in the store that day belongs to.
    ///
    /// **`fromArchive` decides which store, and it has no default.** It is the
    /// same fact `recordDailyCleared` needs and it is required here for the same
    /// reason: only the caller knows whether the board on screen is the live one
    /// or one opened from the calendar, and a call site added later must not be
    /// able to guess wrong by saying nothing.
    ///
    /// The live board writes the daily blob, which stays small and is therefore
    /// cheap on the path that runs on every accepted word. An archive board
    /// writes the archive key, which is never pruned and can be large.
    ///
    /// **A day lands in one store and is removed from the other**, which is what
    /// makes the read order above a tiebreak rather than a decision. Only the
    /// archive path has to clean up: a day can sit in the daily blob and then be
    /// opened from the calendar before the rollover has moved it, but nothing
    /// can put an already retired day back on the live board except a clock that
    /// went backwards, which `retirePastDays` resolves. So the live path pays no
    /// archive read, and stays at a quarter of a millisecond however long the
    /// history gets.
    public func saveDayProgress(
        dayIndex: Int, sourceWord: String, found: [String], fromArchive: Bool
    ) {
        let key = String(dayIndex)
        let progress = DayProgress(sourceWord: sourceWord, found: found)
        guard fromArchive else {
            var state = read()
            state.days[key] = progress
            write(state)
            return
        }
        // **Three writes when the day is still in the daily blob, and the third
        // is not the interesting one.** There is no transaction across two keys,
        // so every gap between writes has to be safe on its own.
        //
        // Writing the archive first and then removing the live copy is not
        // enough, which a guard found rather than a reading of it: the live copy
        // left behind is the OLD word list, the read prefers the daily blob, and
        // a kill in that gap hands back the stale list and then overwrites the
        // newer archived one at the next rollover. The word is lost, quietly,
        // which is the defect this whole change exists to close.
        //
        // So the live copy is brought up to date first. After that every gap is
        // safe: a kill leaves the new words in the daily blob, or in both, or in
        // the archive alone, and the read finds them in all three.
        var state = read()
        let wasLive = state.days[key] != nil
        if wasLive {
            state.days[key] = progress
            write(state)
        }

        var archive = readArchive()
        archive.days[key] = progress
        writeArchive(archive)

        if wasLive {
            state.days.removeValue(forKey: key)
            write(state)
        }
    }

    /// Move every day that is no longer the board in play into the archive key.
    ///
    /// Called when the app learns what day it is: at launch, and at the
    /// rollover. **Not when a board is merely opened from the calendar**, because
    /// `saveDayProgress` already removes a day from the daily blob when it
    /// writes it to the archive, and a day nobody has played needs no moving.
    ///
    /// **A day in flight across midnight is moved by this, deliberately.** It
    /// stays in the daily blob only for as long as the app has not noticed the
    /// date change, which is exactly the window in which she is still playing
    /// that board. The rollover that takes the board off her screen is the same
    /// rollover that moves its words, so the two never disagree.
    ///
    /// Costs one small read when there is nothing to move, which is every launch
    /// after the first of a day.
    public func retirePastDays(todayIndex: Int) {
        var state = read()
        let past = state.days.keys.compactMap(Int.init).filter { $0 < todayIndex }
        guard !past.isEmpty else { return }

        var archive = readArchive()
        for day in past {
            guard let progress = state.days.removeValue(forKey: String(day)) else { continue }
            archive.days[String(day)] = progress
        }
        // Archive first, then the daily blob, for the reason `saveDayProgress`
        // gives: a kill between the two writes must leave a day in both stores
        // rather than in neither. `state` is only mutated in memory above, so
        // nothing is removed from disk until the archive copy is on it.
        writeArchive(archive)
        write(state)
    }

    // MARK: Streak

    /// Record that a daily reached the streak rank. Consecutive days extend the
    /// streak, a gap restarts it, and recording the same day twice is a no-op.
    ///
    /// **The streak must not move backwards, and the two cases below are what
    /// stop it.** Handed a July index and nothing else, this compares against
    /// `lastClearedDayIndex`, sees a gap, and restarts a live seventy-day
    /// streak at 1. That is the worst single outcome this feature can produce,
    /// so the rule is enforced here, in the engine, where it runs under `swift
    /// test` rather than only where it is called.
    ///
    /// Two cases record. Nothing else does.
    ///
    /// **Today, whichever way the board was opened.** Tapping today's cell in
    /// the calendar reaches the board through the archive route, and it is
    /// still today. Refusing every board that came from the archive would cost
    /// her the day she is actually playing, which is the mirror of the defect
    /// this guard exists for and no better than it.
    ///
    /// **Yesterday, but only from a board that was not opened from the
    /// archive.** A board opened at 23:58 and cleared at 00:01 records under
    /// the day it was built for, because `storageDayIndex` is captured once
    /// when the board is adopted and never recomputed while it is in play. By
    /// then that day is yesterday. It works today, nobody would think to test
    /// it, and refusing it would silently drop the clear and cost her the day.
    /// Yesterday reached from the calendar is the same two numbers and a
    /// different event, and it must not record: the run it would restart is
    /// live, and the run it would revive has already lapsed. Only the caller
    /// knows which event this is, so the caller says.
    ///
    /// **`fromArchive` has no default, deliberately.** The guard used to read
    /// the pair of indices and infer the rest, which was right for as long as
    /// the only way to arrive with yesterday's index was the midnight crossing.
    /// The calendar made yesterday openable hours later and the inference did
    /// not change with it. A default would let the next call site reopen that
    /// by saying nothing.
    ///
    /// The old form was one range, `>= todayIndex - 1` and `<= todayIndex`,
    /// which admits exactly these two days and no others. Nothing was narrowed
    /// by writing it out as cases. It is written as cases because the two days
    /// no longer follow the same rule.
    ///
    /// The upper bound survives as an equality. A day that has not happened
    /// cannot have been cleared, and accepting a future index would freeze the
    /// streak, since every real day after it then reads as a gap. That is the
    /// same reasoning `adoptStreak` records for the same reason.
    public func recordDailyCleared(dayIndex: Int, todayIndex: Int, fromArchive: Bool) {
        let isToday = dayIndex == todayIndex
        let isMidnightCrossing = dayIndex == todayIndex - 1 && !fromArchive
        guard isToday || isMidnightCrossing else { return }
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
    /// Found at least one word, and did not reach the rank that counts.
    ///
    /// **This is "Incomplete" as it was deliberately narrowed.** The state the
    /// calendar wanted was "opened, not completed", and a board opened and
    /// abandoned with no finds leaves no trace at all: `foundDidChange` is the
    /// only writer of persisted state and is reached only from a successful
    /// find. Writing on open would have put an exception in the property that
    /// taps, delete, clear and shuffle never write, for a case that is rare and
    /// nearly always indistinguishable from never having opened the board. So
    /// the state was conceded and redefined, and a zero-find day reads as
    /// "No record" rather than as "you did not finish".
    public static let played = 0
    /// Reached `streakTierIndex`, the rank that counts toward the streak.
    public static let cleared = 1
    /// Every set word found. The peak.
    public static let basket = 2

    public var reached: Int
    /// The storage day index on which this was achieved. Equal to the day's own
    /// index when it was played on the day, greater when it was caught up after.
    public var on: Int
    /// True when the streak's run is the only thing establishing this day,
    /// rather than a record of the play itself.
    ///
    /// **It is not a claim about the web, and it used to be.** The field was
    /// called `web` and VoiceOver read it as "played on the web", on the theory
    /// that an expanded run was the transfer. The run is not all transfer: the
    /// streak kept counting in this app after the transfer landed, so every day
    /// played here since would have been labelled as the web's, permanently, by
    /// the one write that is never revised.
    ///
    /// What a run does establish is that the day reached the streak rank, and
    /// that is all this says. Such a day may claim `cleared` and never `basket`,
    /// because a run records no basket completion: a missing crown on one of
    /// these means "not known", not "not achieved".
    public var fromStreak: Bool

    public init(reached: Int, on: Int, fromStreak: Bool) {
        self.reached = reached
        self.on = on
        self.fromStreak = fromStreak
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
        reached = c.lenient(.reached, Self.played)
        on = c.lenient(.on, 0)
        fromStreak = c.lenient(.fromStreak, false)
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

/// Found words for every day that is no longer the board in play.
///
/// Same lenient decode as `OutcomeState`, for the same reason: this is written
/// once per day at the rollover and read on every archive board, and a strict
/// decode would turn one unreadable field into a whole history discarded.
struct ArchiveProgressState: Codable {
    static let currentVersion = 1

    var version: Int
    var days: [String: DayProgress]

    static let empty = ArchiveProgressState(version: currentVersion, days: [:])

    init(version: Int, days: [String: DayProgress]) {
        self.version = version
        self.days = days
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = c.lenient(.version, Self.currentVersion)
        days = c.lenient(.days, [:])
    }
}

extension GameStorage {
    /// A third key, and like `outcomesKey` the reason belongs beside it.
    ///
    /// **Never pruned.** Every day the player has ever played keeps its words
    /// here, which is the whole point: a day the calendar draws as finished must
    /// open with the words that finished it, whether that was yesterday or in
    /// June. The bound this replaces held fourteen days and reached 83% of the
    /// calendar the day it shipped, growing to 97% within a year, measured in
    /// `2026-09-13 Archive Day Progress.md`.
    ///
    /// **The daily blob stays small because this exists.** `storageKey` now
    /// holds only the board in play, plus a day still in flight across midnight,
    /// and it is the one rewritten on every accepted word. Keeping the history
    /// out of it is what keeps that write at a quarter of a millisecond instead
    /// of growing with the calendar: at three years of words the merged blob
    /// would cost 21 ms per find, which is longer than a frame.
    ///
    /// **Invisible to an older build**, which has never heard of this key and
    /// therefore cannot rewrite it. A TestFlight rollback loses nothing here, and
    /// `PersistedState.currentVersion` stays at 1 because a new key is not a
    /// change to the old one's format.
    static let archiveKey = "peach-of-a-word/archive/v1"

    func readArchive() -> ArchiveProgressState {
        guard let data = store.data(forKey: Self.archiveKey) else { return .empty }
        // Corrupt or truncated costs the archived words and nothing else. The
        // board in play and the streak live under a different key.
        return (try? JSONDecoder().decode(ArchiveProgressState.self, from: data)) ?? .empty
    }

    func writeArchive(_ state: ArchiveProgressState) {
        var state = state
        state.version = ArchiveProgressState.currentVersion
        guard let data = try? JSONEncoder().encode(state) else { return }
        store.set(data, forKey: Self.archiveKey)
    }

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

    /// Replace the whole map, keeping the back-fill marker.
    ///
    /// **A replace, deliberately, not a merge.** The one caller that wants this
    /// is putting a known history in place, and merging would leave whatever was
    /// there before showing through: a seeded calendar came back with two cells
    /// that were meant to be empty carrying values from an earlier seed, and it
    /// was only caught by checking the render against the spec cell by cell.
    ///
    /// The marker survives because it records something about the streak
    /// expansion rather than about any day, and re-arming it here would make a
    /// dead run expand a second time over the map that just replaced it.
    /// Put the archive back to never expanded: no days, and the flag down.
    ///
    /// **For a seed that wants to watch the expansion happen rather than plant
    /// its result.** `adoptStreak` re-arms the flag too, but only when it
    /// actually takes, and it refuses a count that does not beat the live one.
    /// A seed run twice would then clear the days without re-arming and leave an
    /// empty calendar, which looks exactly like the expansion having produced
    /// nothing.
    ///
    /// Internal, not `#if DEBUG`. See `Seeding`.
    func rearmBackFill() {
        var outcomes = readOutcomes()
        outcomes.days = [:]
        outcomes.backFilled = false
        writeOutcomes(outcomes)
    }

    /// Replace the whole outcome map.
    ///
    /// **The one write the storage design refuses.** Everything else here adds a
    /// day or raises one; this can lower or erase any of them, which is exactly
    /// what the separate, never-pruned key exists to prevent. Its only callers
    /// are the seeds that plant a calendar to look at, and the tests.
    ///
    /// **Internal, where this used to be `public` behind `#if DEBUG`.** The gate
    /// was right about what it was protecting and wrong about how. It kept a
    /// shipping app from reaching this, and it also kept the whole engine suite
    /// from compiling in the configuration that ships, because a test that calls
    /// this is a test that cannot exist in Release. The module boundary does the
    /// same job without that cost: the app imports `PeachEngine` as a module and
    /// cannot see anything internal to it, in any configuration, while the tests
    /// use `@testable import` and can. See `Seeding` for the app's way in.
    func replaceOutcomes(_ outcomes: [Int: DayOutcome]) {
        var state = readOutcomes()
        state.days = Dictionary(
            uniqueKeysWithValues: outcomes.map { (String($0.key), $0.value) }
        )
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
        backFillOutcomes(
            firstPlayableDayIndex: firstPlayableDayIndex, fromPlay: { _, _, _ in nil }
        ).fromStreak
    }

    /// Build the archive once, taking the play record over the run wherever it
    /// reaches further.
    ///
    /// **The run is the weakest true statement about a day, and some days can do
    /// better.** A run establishes only that the day reached the streak rank. A
    /// day whose found words are still stored was played here and can be
    /// classified exactly as live play classifies it, which is the difference
    /// between a recent basket day keeping its heart and losing it for good:
    /// this write is never revised, so no later pass can recover what is not
    /// taken now. The words themselves are no longer pruned, but the walk that
    /// reaches them is capped at `backFillWalkLimit`, so the same one chance
    /// applies to any day beyond it.
    ///
    /// **The play record may only ever raise a day inside the run, never lower
    /// it.** `classify` recomputes a rung from stored words, and that
    /// computation depends on the lexicon, the tier thresholds and the scoring,
    /// none of which are frozen. If any of them moved between the build that
    /// stored the words and the build running this, a day that genuinely cleared
    /// can recompute below the rank and would be written as `incomplete`
    /// permanently. Inside the run, the rung is floored at `cleared`, so the
    /// worst this can do is agree with the run.
    ///
    /// - Parameters:
    ///   - firstPlayableDayIndex: the daily epoch in storage days.
    ///   - classify: given a day index, the source word stored with its
    ///     progress, and the words found, the rung that day reached, or nil if
    ///     it cannot be classified. Passed in because classifying needs the word
    ///     lists, which the engine does not hold.
    /// - Returns: how many days each source accounted for.
    @discardableResult
    public func backFillOutcomes(
        firstPlayableDayIndex: Int,
        fromPlay classify: (Int, String, [String]) -> Int?
    ) -> BackFillCounts {
        var outcomes = readOutcomes()
        guard !outcomes.backFilled else { return BackFillCounts(fromPlay: 0, fromStreak: 0) }
        // Marked done even when there is nothing to expand, so this does not run
        // on every launch forever. `adoptStreak` re-arms it if a transfer lands
        // later.
        outcomes.backFilled = true

        let state = read()
        let streak = state.streak
        // Both stores. The play record used to live entirely in the daily blob;
        // now everything older than the board in play is under `archiveKey`.
        let dayProgress = allDayProgress()
        var run: ClosedRange<Int>?
        if streak.count > 0, let last = streak.lastClearedDayIndex {
            let firstOfRun = max(firstPlayableDayIndex, last - streak.count + 1)
            if firstOfRun <= last { run = firstOfRun...last }
        }

        var counts = BackFillCounts(fromPlay: 0, fromStreak: 0)

        // The play record first. Enumerated from the days that have progress,
        // which the caller caps, rather than from the run, which can be any
        // length. A day that reaches neither is covered by the run below.
        for (key, progress) in dayProgress {
            guard let day = Int(key), outcomes.days[key] == nil else { continue }
            // An empty board must not claim to have been played. Same rule, and
            // the same reason, as the guard in the caller that records live play.
            guard !progress.found.isEmpty else { continue }
            guard let reached = classify(day, progress.sourceWord, progress.found) else { continue }

            if run?.contains(day) == true, reached < DayOutcome.cleared {
                // The run knows more than the recomputation found. Take the run.
                outcomes.days[key] = DayOutcome(
                    reached: DayOutcome.cleared, on: day, fromStreak: true
                )
                counts.fromStreak += 1
            } else {
                // A board can only have been played on its own day here, because
                // nothing could open a past one until the archive existed and
                // this runs once, before it can have been used.
                outcomes.days[key] = DayOutcome(reached: reached, on: day, fromStreak: false)
                counts.fromPlay += 1
            }
        }

        // Then the run, for every day the play record could not speak for.
        if let run {
            for day in run where outcomes.days[String(day)] == nil {
                outcomes.days[String(day)] = DayOutcome(
                    reached: DayOutcome.cleared, on: day, fromStreak: true
                )
                counts.fromStreak += 1
            }
        }

        writeOutcomes(outcomes)
        return counts
    }
}

/// What one run of the archive back-fill accounted for, by source.
public struct BackFillCounts: Equatable, Sendable {
    /// Days classified from words still held in the main blob.
    public var fromPlay: Int
    /// Days the streak's run established, including any the play record could
    /// not raise above it.
    public var fromStreak: Int

    public init(fromPlay: Int, fromStreak: Int) {
        self.fromPlay = fromPlay
        self.fromStreak = fromStreak
    }
}

#if DEBUG
extension GameStorage {
    /// The seeds' door into the writes the storage design otherwise refuses.
    ///
    /// **Debug only, and a door rather than a set of public functions.** The
    /// capabilities behind it are internal, so a shipping app cannot reach them
    /// whatever the build flags say. This is what lets the app's own seeds reach
    /// them anyway, and it puts that fact at the call site: `storage.seeding`
    /// reads as debug scaffolding in a way `storage.replaceOutcomes` did not.
    ///
    /// A Release build has no `seeding`, so a call to one of these from
    /// shipping code fails to compile, which is the check the old `#if DEBUG`
    /// was there to provide.
    public var seeding: Seeding { Seeding(storage: self) }

    public struct Seeding {
        let storage: GameStorage

        /// Replace the whole outcome map. See `GameStorage.replaceOutcomes`.
        public func replaceOutcomes(_ outcomes: [Int: DayOutcome]) {
            storage.replaceOutcomes(outcomes)
        }

        /// Put the archive back to never expanded. See
        /// `GameStorage.rearmBackFill`.
        public func rearmBackFill() { storage.rearmBackFill() }
    }
}
#endif
