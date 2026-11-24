import Foundation
import Observation

// MARK: - A flag, as the server takes it

/// Why a player flags a word, as the server names it (`src/flags/wire.ts` in
/// the web repo, which the server and the web share).
///
/// The app's words for each are `FlagCopy`'s; these are only the wire's.
public enum FlagReason: String, CaseIterable, Codable, Sendable {
    case notAWord = "not-a-word"
    case offensive
    case definition
    case shouldCount = "should-count"
    case rarer
    case moreCommon = "more-common"
}

// MARK: - The picker's groups

/// Which card a flag is made on. The peach card is the board's own long word;
/// a found word's card has a definition or doesn't.
public enum FlagCard: Sendable {
    case peach, definition, noDefinition
}

/// One of the picker's groups: its kind, which the app words as a heading, and
/// the reasons under it, in order.
public struct FlagGroup: Equatable, Sendable {
    public enum Kind: Sendable { case takeItOut, fixItsCard, itsGrade }
    public let kind: Kind
    public let reasons: [FlagReason]
}

/// The picker's groups, choices first, without the reasons this phone has
/// already flagged on the word. The web's `groupsFor`, rule for rule.
///
/// "Its grade" is on a found word's card only: the peach has no grade. A basket
/// word can only be rarer and a Mythic word only more common. Once either grade
/// reason is flagged, the whole group goes, so a word gets one grade flag from
/// each phone; taking it back brings the group back (Antoine, 23 November).
public func flagGroups(card: FlagCard, grade: Rung?, flagged: Set<FlagReason>) -> [FlagGroup] {
    var groups = [
        FlagGroup(kind: .takeItOut, reasons: card == .peach ? [.offensive] : [.notAWord, .offensive]),
        FlagGroup(kind: .fixItsCard, reasons: [.definition]),
    ]
    let gradeFlagged = flagged.contains(.rarer) || flagged.contains(.moreCommon)
    if card != .peach, let grade, !gradeFlagged {
        let reasons: [FlagReason] = switch grade {
        case .set: [.rarer]
        case .mythic: [.moreCommon]
        case .uncommon, .rare: [.rarer, .moreCommon]
        }
        groups.append(FlagGroup(kind: .itsGrade, reasons: reasons))
    }
    return groups
        .map { FlagGroup(kind: $0.kind, reasons: $0.reasons.filter { !flagged.contains($0) }) }
        .filter { !$0.reasons.isEmpty }
}

// MARK: - The day a flag names

/// The calendar day of a board, as the server reads it: YYYY-MM-DD, counted
/// from `storageEpoch` in the calendar's own day components, never from a
/// clock, so a time zone or a clock change can't move it.
public func flagDay(storageDay: Int) -> String {
    var utc = Calendar(identifier: .gregorian)
    utc.timeZone = TimeZone(identifier: "UTC")!
    let start = utc.date(from: DateComponents(
        year: storageEpoch.year, month: storageEpoch.month, day: storageEpoch.day
    ))!
    let date = utc.date(byAdding: .day, value: storageDay, to: start)!
    let c = utc.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
}

/// The first day a board can name, as the server counts it: `dailyEpoch`.
public let flagFirstDay = String(
    format: "%04d-%02d-%02d", dailyEpoch.year, dailyEpoch.month, dailyEpoch.day
)

// MARK: - The server's own check

/// The server's shape check (`checkFlag` in the web's `src/flags/wire.ts`),
/// for the fields the app sends. A flag that fails it is dropped alone before a
/// batch is made, so it can never take the good flags beside it down with it:
/// the server refuses a whole request if any one flag fails (Antoine, 23
/// November).
///
/// A day after the server's today is well shaped. The server drops that flag
/// alone, so a phone whose clock runs fast loses only its own flag.
func isWellShaped(_ f: DeviceFlag, version: String) -> Bool {
    func matches(_ s: String, _ pattern: String) -> Bool {
        s.range(of: pattern, options: .regularExpression) != nil
    }
    return matches(f.id, "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")
        && matches(f.word, "^[a-z]{3,8}$")
        && matches(version, "^[0-9A-Za-z.() +-]{1,24}$")
        && isRealDay(f.day)
        && f.day >= flagFirstDay
}

private func isRealDay(_ day: String) -> Bool {
    guard day.range(of: "^\\d{4}-\\d{2}-\\d{2}$", options: .regularExpression) != nil else {
        return false
    }
    let parts = day.split(separator: "-").compactMap { Int($0) }
    var utc = Calendar(identifier: .gregorian)
    utc.timeZone = TimeZone(identifier: "UTC")!
    guard let date = utc.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) else {
        return false
    }
    let c = utc.dateComponents([.year, .month, .day], from: date)
    return c.year == parts[0] && c.month == parts[1] && c.day == parts[2]
}

// MARK: - This phone's flags

/// Where the list is kept. `UserDefaults` is one; the tests hand in a stand-in.
public protocol FlagStorage: AnyObject {
    func data(forKey key: String) -> Data?
    func set(_ value: Any?, forKey key: String)
}

extension UserDefaults: FlagStorage {}

/// A request to the flag server: a POST of flags, or a DELETE of IDs to forget.
public struct FlagRequest: Sendable {
    public enum Method: String, Sendable { case post = "POST", delete = "DELETE" }
    public let method: Method
    /// The JSON body, exactly as it goes.
    public let body: Data
}

/// Sends a request and gives back the server's status, or nil for no
/// connection. The app's sends to the server only in a Release build; every
/// other build and every test hands in a stand-in. See `FlagServer` in the app.
public typealias FlagTransport = @Sendable (FlagRequest) async -> Int?

/// A flag this phone made.
public struct DeviceFlag: Codable, Equatable, Identifiable, Sendable {
    public enum State: String, Codable, Sendable { case waiting, sent }
    public let id: String
    public let word: String
    public let reason: FlagReason
    /// The board's calendar day, YYYY-MM-DD.
    public let day: String
    /// When it was made. A waiting flag's 60 days count from here.
    public let madeAt: Date
    public internal(set) var state: State
    /// A POST carrying it went out, answered or not.
    public internal(set) var tried: Bool
    /// When a POST carrying it last went out.
    public internal(set) var triedAt: Date?
    /// When the server took it. A sent flag's 60 days count from here, as the
    /// server's do.
    public internal(set) var sentAt: Date?
}

public enum FlagResult: Sendable { case made, already, full }

/// What prompts a send. A flag just made or taken back goes at once; the
/// others retry no more than once every 10 minutes.
public enum FlagSendReason: Sendable { case made, launch, online, active }

/// This phone's flags: the list in `UserDefaults`, and the sender. The web's
/// `createFlags` (`src/flags/flags.ts`), rule for rule.
///
/// **What a flag is dropped for.** Only these, and quietly:
/// - failing the server's own shape check, run here on each waiting flag before
///   a batch is made, so a broken flag goes alone;
/// - the server refusing a batch's shape anyway, a 400 or a 413, since it will
///   never be taken;
/// - 60 days without going, so nothing waits for ever.
///
/// Anything else keeps it waiting: a 403 is the kill switch, a 429 the rate
/// limit, a 5xx or no connection a server or a network that will come back.
///
/// **Taking one back.** A flag that never went leaves the phone only. One whose
/// POST went out, answered or not, may be on the server, so the phone asks the
/// server to forget it too, and keeps asking until it has: the privacy page
/// promises a take-back for 60 days.
@MainActor
@Observable
public final class FlagStore {
    /// The `UserDefaults` key the list lives under.
    public static let key = "wordFlags"
    /// At most this many wait at once; the card says so in place of its flag.
    public static let maxWaiting = 50
    /// How long a flag lasts, on the server and here.
    public static let keepDays = 60
    /// The most flags, or IDs to forget, in one request: the server's limit.
    public static let maxPerRequest = 20
    /// The largest body the server reads.
    public static let maxBodyBytes = 4096
    static let retry: TimeInterval = 10 * 60

    struct Forget: Codable, Equatable {
        let id: String
        /// When it may have reached the server: its sending, or its last attempt.
        let since: Date
    }

    struct Saved: Codable, Equatable {
        var version = 1
        var flags: [DeviceFlag] = []
        var forget: [Forget] = []
        var lastTry: Date?

        init() {}

        /// Reads each flag on its own, so one this build can't read (a reason
        /// it doesn't know, a missing field) is left out alone.
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            version = try c.decode(Int.self, forKey: .version)
            flags = try c.decode([Lossy<DeviceFlag>].self, forKey: .flags).compactMap(\.value)
            forget = (try? c.decode([Lossy<Forget>].self, forKey: .forget))?.compactMap(\.value) ?? []
            lastTry = try? c.decode(Date.self, forKey: .lastTry)
        }
    }

    private struct Lossy<T: Decodable>: Decodable {
        let value: T?
        init(from decoder: Decoder) throws { value = try? T(from: decoder) }
    }

    @ObservationIgnored private let storage: FlagStorage
    @ObservationIgnored private let transport: FlagTransport
    @ObservationIgnored private let now: @MainActor () -> Date
    @ObservationIgnored private let newId: @MainActor () -> String
    @ObservationIgnored private let version: String
    @ObservationIgnored private let online: @MainActor () -> Bool
    @ObservationIgnored private var sending: Task<Void, Never>?
    @ObservationIgnored private var again = false

    private var saved: Saved

    public init(
        storage: FlagStorage,
        transport: @escaping FlagTransport,
        now: @escaping @MainActor () -> Date,
        newId: @escaping @MainActor () -> String,
        version: String,
        online: @escaping @MainActor () -> Bool
    ) {
        self.storage = storage
        self.transport = transport
        self.now = now
        self.newId = newId
        self.version = version
        self.online = online
        saved = Self.read(storage)
    }

    private static func read(_ storage: FlagStorage) -> Saved {
        guard let data = storage.data(forKey: key),
              let s = try? JSONDecoder().decode(Saved.self, from: data),
              s.version == 1
        else { return Saved() }
        return s
    }

    private func update(_ change: (inout Saved) -> Void) {
        change(&saved)
        if let data = try? JSONEncoder().encode(saved) {
            storage.set(data, forKey: Self.key)
        }
    }

    private func isOld(_ start: Date) -> Bool {
        now().timeIntervalSince(start) > TimeInterval(Self.keepDays) * 86_400
    }

    /// Where a flag's 60 days start: its sending once sent, its making until then.
    private func start(of f: DeviceFlag) -> Date {
        f.state == .sent ? (f.sentAt ?? f.madeAt) : f.madeAt
    }

    private func prune() {
        if saved.flags.contains(where: { isOld(start(of: $0)) })
            || saved.forget.contains(where: { isOld($0.since) }) {
            update { s in
                s.flags.removeAll { isOld(start(of: $0)) }
                s.forget.removeAll { isOld($0.since) }
            }
        }
    }

    // MARK: Reading

    /// This phone's flags still in their 60 days, oldest first.
    public var list: [DeviceFlag] {
        saved.flags.filter { !isOld(start(of: $0)) }
    }

    /// Whether the waiting list is at its cap, so the card's flag gives way.
    public var isFull: Bool {
        saved.flags.filter { $0.state == .waiting }.count >= Self.maxWaiting
    }

    // MARK: Changing

    public func flag(word: String, reason: FlagReason, day: String) async -> FlagResult {
        prune()
        if saved.flags.contains(where: { $0.word == word && $0.reason == reason }) {
            return .already
        }
        if isFull { return .full }
        let flag = DeviceFlag(
            id: newId(), word: word, reason: reason, day: day, madeAt: now(),
            state: .waiting, tried: false, triedAt: nil, sentAt: nil
        )
        update { $0.flags.append(flag) }
        await send(.made)
        return .made
    }

    public func takeBack(_ id: String) async {
        guard let f = saved.flags.first(where: { $0.id == id }) else { return }
        let since = f.sentAt ?? f.triedAt ?? f.madeAt
        update { s in
            s.flags.removeAll { $0.id == id }
            if f.tried { s.forget.append(Forget(id: id, since: since)) }
        }
        if f.tried { await send(.made) }
    }

    // MARK: Sending

    /// Sends what's waiting. A flag just made or taken back goes at once; the
    /// other moments retry no more than once every 10 minutes.
    public func send(_ why: FlagSendReason) async {
        prune()
        let pending = saved.flags.contains { $0.state == .waiting } || !saved.forget.isEmpty
        guard pending, online() else { return }
        if why != .made, let last = saved.lastTry, now().timeIntervalSince(last) < Self.retry {
            return
        }
        if let sending {
            again = true
            await sending.value
            return
        }
        let at = now()
        update { $0.lastTry = at }
        let task = Task { await self.pass() }
        sending = task
        await task.value
        sending = nil
        if again {
            again = false
            await send(.made)
        }
    }

    /// The flag as the server takes it: these fields and no others.
    private func wire(_ f: DeviceFlag) -> [String: String] {
        ["id": f.id, "word": f.word, "day": f.day, "reason": f.reason.rawValue,
         "platform": "ios", "version": version]
    }

    private func body(_ object: [String: Any]) -> Data {
        (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])) ?? Data()
    }

    /// One pass over everything waiting. Stops at the first answer that means later.
    private func pass() async {
        prune()
        let refused = Set(saved.flags.filter { $0.state == .waiting && !isWellShaped($0, version: version) }.map(\.id))
        if !refused.isEmpty { update { $0.flags.removeAll { refused.contains($0.id) } } }

        while true {
            let batch = saved.flags.filter { $0.state == .waiting }.prefix(Self.maxPerRequest)
            if batch.isEmpty { break }
            let ids = Set(batch.map(\.id))
            // Marked before it goes, so an app closed mid-request still counts
            // it as possibly on the server.
            let at = now()
            update { s in
                for i in s.flags.indices where ids.contains(s.flags[i].id) {
                    s.flags[i].tried = true
                    s.flags[i].triedAt = at
                }
            }
            let status = await transport(FlagRequest(method: .post, body: body(["flags": batch.map(wire)])))
            if status == 202 {
                let took = now()
                update { s in
                    for i in s.flags.indices where ids.contains(s.flags[i].id) {
                        s.flags[i].state = .sent
                        s.flags[i].sentAt = took
                    }
                }
            } else if status == 400 || status == 413 {
                update { $0.flags.removeAll { ids.contains($0.id) } }
            } else {
                return
            }
        }

        while true {
            let batch = saved.forget.prefix(Self.maxPerRequest)
            if batch.isEmpty { break }
            let ids = batch.map(\.id)
            let status = await transport(FlagRequest(method: .delete, body: body(["ids": ids])))
            if status == 204 || status == 400 || status == 413 {
                let gone = Set(ids)
                update { $0.forget.removeAll { gone.contains($0.id) } }
            } else {
                return
            }
        }
    }
}
