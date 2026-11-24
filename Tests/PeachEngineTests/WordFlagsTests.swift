import Foundation
import Testing
@testable import PeachEngine

/// The device's flags: the waiting list in `UserDefaults`, and the sender.
///
/// Ported from the web's `src/flags/flags.test.ts`, rule for rule, so the two
/// devices keep the same promises: one flag per word and reason, at most 50
/// waiting, 60 days, dropped only on a 400 or a 413, and a take-back that asks
/// the server to forget any flag that may have reached it.
///
/// Every test hands in its own transport, so nothing here reaches a network,
/// and the made-up words are nobody's board.
@MainActor
@Suite("the device's flags")
struct WordFlagsTests {
    nonisolated static let t0 = Date(timeIntervalSince1970: 1_782_907_200) // 2026-07-01 12:00 UTC
    nonisolated static let day: TimeInterval = 86_400

    /// What the server answers: a status, or no connection.
    enum Answer { case status(Int), offline }

    /// A server that answers with the statuses given, in turn, the last one
    /// for ever after, and records each request.
    @MainActor
    final class Server {
        struct Call {
            let method: FlagRequest.Method
            let body: [String: Any]
            var flags: [[String: Any]] { body["flags"] as? [[String: Any]] ?? [] }
            var ids: [String] { body["ids"] as? [String] ?? [] }
        }

        private var answers: [Answer]
        private(set) var calls: [Call] = []

        init(_ answers: [Answer]) { self.answers = answers }

        func answer(_ request: FlagRequest) -> Int? {
            let body = (try? JSONSerialization.jsonObject(with: request.body)) as? [String: Any] ?? [:]
            calls.append(Call(method: request.method, body: body))
            let next = answers.count > 1 ? answers.removeFirst() : answers[0]
            switch next {
            case .status(let code): return code
            case .offline: return nil
            }
        }

        func forget() { calls.removeAll() }
    }

    final class Memory: FlagStorage {
        var values: [String: Data] = [:]
        func data(forKey key: String) -> Data? { values[key] }
        func set(_ value: Any?, forKey key: String) { values[key] = value as? Data }
    }

    final class Clock {
        var now = WordFlagsTests.t0
        func later(_ seconds: TimeInterval) { now += seconds }
    }

    struct Setup {
        let flags: FlagStore
        let server: Server
        let storage: Memory
        let clock: Clock
    }

    static func setup(
        _ answers: [Answer] = [.status(202)],
        storage: Memory = Memory(),
        version: String = "1.4 (125)",
        online: (@MainActor () -> Bool)? = nil
    ) -> Setup {
        let server = Server(answers)
        let clock = Clock()
        var n = 0
        let flags = FlagStore(
            storage: storage,
            transport: { request in await server.answer(request) },
            now: { clock.now },
            newId: {
                n += 1
                return "00000000-0000-4000-8000-" + String(format: "%012d", n)
            },
            version: version,
            online: online ?? { true }
        )
        return Setup(flags: flags, server: server, storage: storage, clock: clock)
    }

    /// The i-th of many made-up words, in letters only, as the server takes them.
    static func nth(_ prefix: String, _ i: Int) -> String {
        let a = UnicodeScalar(97 + i / 26)!, b = UnicodeScalar(97 + i % 26)!
        return prefix + String(Character(a)) + String(Character(b))
    }

    static let july1 = "2026-07-01"

    // MARK: - Making a flag

    @Test func keepsOneFlagPerWordAndReason() async {
        let s = Self.setup([.offline])
        #expect(await s.flags.flag(word: "zorp", reason: .definition, day: Self.july1) == .made)
        #expect(await s.flags.flag(word: "zorp", reason: .definition, day: Self.july1) == .already)
        #expect(await s.flags.flag(word: "zorp", reason: .offensive, day: Self.july1) == .made)
        #expect(s.flags.list.map { "\($0.word) \($0.reason.rawValue)" } == ["zorp definition", "zorp offensive"])
    }

    @Test func keepsAtMostFiftyWaitingAndSaysSo() async {
        let s = Self.setup([.offline])
        for i in 0..<FlagStore.maxWaiting {
            #expect(await s.flags.flag(word: Self.nth("w", i), reason: .definition, day: Self.july1) == .made)
        }
        #expect(s.flags.isFull)
        #expect(await s.flags.flag(word: "blick", reason: .definition, day: Self.july1) == .full)
        #expect(s.flags.list.count == FlagStore.maxWaiting)
    }

    @Test func savesTheListAndReadsItBackAfterARelaunch() async {
        let s = Self.setup([.offline])
        _ = await s.flags.flag(word: "zorp", reason: .definition, day: Self.july1)
        #expect(s.storage.values[FlagStore.key] != nil)
        let again = FlagStore(
            storage: s.storage, transport: { _ in nil }, now: { Self.t0 },
            newId: { "x" }, version: "1.4 (125)", online: { true }
        )
        #expect(again.list.map(\.word) == ["zorp"])
    }

    @Test func readsADamagedListAsEmptyRatherThanFailing() {
        let storage = Memory()
        storage.values[FlagStore.key] = Data("{not json".utf8)
        let flags = FlagStore(
            storage: storage, transport: { _ in 202 }, now: { Self.t0 },
            newId: { "x" }, version: "1.4 (125)", online: { true }
        )
        #expect(flags.list.isEmpty)
    }

    // MARK: - Sending

    @Test func sendsAFlagTheMomentItIsMadeWithOnlyTheFieldsTheServerTakes() async throws {
        let s = Self.setup([.status(202)])
        _ = await s.flags.flag(word: "zorp", reason: .rarer, day: Self.july1)
        #expect(s.server.calls.count == 1)
        let call = try #require(s.server.calls.first)
        #expect(call.method == .post)
        #expect(call.body.keys.sorted() == ["flags"])
        let sent = try #require(call.flags.first)
        #expect(sent.keys.sorted() == ["day", "id", "platform", "reason", "version", "word"])
        #expect(sent["id"] as? String == "00000000-0000-4000-8000-000000000001")
        #expect(sent["word"] as? String == "zorp")
        #expect(sent["day"] as? String == "2026-07-01")
        #expect(sent["reason"] as? String == "rarer")
        #expect(sent["platform"] as? String == "ios")
        #expect(sent["version"] as? String == "1.4 (125)")
        #expect(s.flags.list.first?.state == .sent)
    }

    @Test func sendsWhatIsWaitingInBatchesOfTwenty() async {
        // Each flag made offline tries once and stops at the first failure.
        let s = Self.setup(Array(repeating: .offline, count: 45) + [.status(202)])
        for i in 0..<45 {
            _ = await s.flags.flag(word: Self.nth("zo", i), reason: .definition, day: Self.july1)
        }
        s.clock.later(11 * 60)
        s.server.forget()
        await s.flags.send(.online)
        #expect(s.server.calls.map(\.flags.count) == [20, 20, 5])
        #expect(s.flags.list.allSatisfy { $0.state == .sent })
    }

    @Test(arguments: [
        (Answer.status(403), "the kill switch"),
        (.status(429), "the rate limit"),
        (.status(500), "a server error"),
        (.status(503), "no store"),
        (.offline, "no connection"),
    ])
    func keepsAFlagWaiting(on answer: Answer, why: String) async {
        let s = Self.setup([answer])
        _ = await s.flags.flag(word: "zorp", reason: .definition, day: Self.july1)
        #expect(s.flags.list.count == 1, "\(why)")
        #expect(s.flags.list.first?.state == .waiting, "\(why)")
    }

    @Test(arguments: [400, 413])
    func dropsAFlagTheServerRefusesQuietly(status: Int) async {
        let s = Self.setup([.status(status)])
        _ = await s.flags.flag(word: "zorp", reason: .definition, day: Self.july1)
        #expect(s.flags.list.isEmpty)
    }

    @Test func retriesAtMostOnceEveryTenMinutesButNeverHoldsBackAFlagJustMade() async {
        let s = Self.setup([.offline])
        _ = await s.flags.flag(word: "zorp", reason: .definition, day: Self.july1)
        #expect(s.server.calls.count == 1)
        s.clock.later(60)
        await s.flags.send(.active)
        await s.flags.send(.online)
        #expect(s.server.calls.count == 1)
        _ = await s.flags.flag(word: "blick", reason: .definition, day: Self.july1)
        #expect(s.server.calls.count == 2)
        s.clock.later(10 * 60)
        await s.flags.send(.launch)
        #expect(s.server.calls.count == 3)
    }

    @Test func sendsNothingWhileThePhoneSaysItIsOffline() async {
        let s = Self.setup([.status(202)], online: { false })
        _ = await s.flags.flag(word: "zorp", reason: .definition, day: Self.july1)
        #expect(s.server.calls.isEmpty)
        #expect(s.flags.list.first?.state == .waiting)
    }

    // MARK: - Sixty days

    @Test func dropsAFlagStillWaitingAtSixtyDaysQuietly() async {
        let s = Self.setup([.offline])
        _ = await s.flags.flag(word: "zorp", reason: .definition, day: Self.july1)
        s.clock.later(59 * Self.day)
        await s.flags.send(.launch)
        #expect(s.flags.list.count == 1)
        s.clock.later(1 * Self.day + 1)
        await s.flags.send(.launch)
        #expect(s.flags.list.isEmpty)
    }

    @Test func keepsEveryFlagUnderSixtyDaysOldInTheListSentOrWaiting() async {
        let s = Self.setup([.status(202)])
        for i in 0..<60 {
            _ = await s.flags.flag(word: Self.nth("zo", i), reason: .definition, day: Self.july1)
            s.clock.later(Self.day / 2)
        }
        #expect(s.flags.list.count == 60)
    }

    // MARK: - Taking a flag back

    @Test func takesBackAFlagThatNeverWentWithoutTellingTheServer() async throws {
        let s = Self.setup([.offline], online: { false })
        _ = await s.flags.flag(word: "zorp", reason: .definition, day: Self.july1)
        #expect(s.server.calls.isEmpty)
        await s.flags.takeBack(try #require(s.flags.list.first).id)
        #expect(s.flags.list.isEmpty)
        #expect(s.server.calls.isEmpty)
    }

    @Test func takesBackASentFlagFromTheServerToo() async throws {
        let s = Self.setup([.status(202), .status(204)])
        _ = await s.flags.flag(word: "zorp", reason: .definition, day: Self.july1)
        let id = try #require(s.flags.list.first).id
        await s.flags.takeBack(id)
        #expect(s.flags.list.isEmpty)
        let last = try #require(s.server.calls.last)
        #expect(last.method == .delete)
        #expect(last.body.keys.sorted() == ["ids"])
        #expect(last.ids == [id])
    }

    @Test func asksTheServerToForgetAFlagWhoseSendingGotNoAnswer() async throws {
        let s = Self.setup([.offline, .offline, .status(204)])
        _ = await s.flags.flag(word: "zorp", reason: .definition, day: Self.july1)
        let id = try #require(s.flags.list.first).id
        await s.flags.takeBack(id)
        #expect(s.flags.list.isEmpty)
        s.clock.later(11 * 60)
        await s.flags.send(.online)
        let last = try #require(s.server.calls.last)
        #expect(last.method == .delete)
        #expect(last.ids == [id])
    }

    @Test func keepsATakeBackMadeOfflineAndSendsItWithTheFlagsOnceBack() async throws {
        let s = Self.setup([.status(202), .offline, .status(202), .status(204)])
        _ = await s.flags.flag(word: "zorp", reason: .definition, day: Self.july1)
        let id = try #require(s.flags.list.first).id
        await s.flags.takeBack(id)
        #expect(s.server.calls.last?.method == .delete)
        s.clock.later(11 * 60)
        _ = await s.flags.flag(word: "blick", reason: .definition, day: Self.july1)
        #expect(s.server.calls.dropFirst(2).map(\.method) == [.post, .delete])
        #expect(s.server.calls.last?.ids == [id])
    }

    // MARK: - Sixty days from when the server took it

    @Test func keepsAFlagThatWaitedSixtyDaysFromItsSending() async throws {
        let s = Self.setup([.offline, .status(202), .status(204)])
        _ = await s.flags.flag(word: "zorp", reason: .definition, day: Self.july1)
        s.clock.later(10 * Self.day)
        await s.flags.send(.launch)
        #expect(s.flags.list.first?.state == .sent)
        s.clock.later(55 * Self.day)
        await s.flags.send(.launch)
        #expect(s.flags.list.count == 1)
        await s.flags.takeBack(try #require(s.flags.list.first).id)
        #expect(s.server.calls.last?.method == .delete)
    }

    @Test func stillAsksTheServerToForgetAFlagLastTriedOnDay59OnDay61() async throws {
        let s = Self.setup([.offline, .offline, .offline, .status(204)])
        _ = await s.flags.flag(word: "zorp", reason: .definition, day: Self.july1)
        s.clock.later(59 * Self.day)
        await s.flags.send(.launch)
        let id = try #require(s.flags.list.first).id
        await s.flags.takeBack(id)
        s.clock.later(2 * Self.day)
        let before = s.server.calls.count
        await s.flags.send(.launch)
        let after = s.server.calls.dropFirst(before)
        #expect(after.map(\.method) == [.delete])
        #expect(after.first?.ids == [id])
    }

    // MARK: - A stored flag the server would refuse

    /// A list as a newer or broken build might have left it: one bad flag
    /// between two good ones.
    static func stored(bad: [String: Any]) -> Data {
        func flag(_ id: String, _ over: [String: Any]) -> [String: Any] {
            var f: [String: Any] = [
                "id": id, "word": "bad", "reason": "definition", "day": "2026-06-23",
                "madeAt": t0.timeIntervalSince1970, "state": "waiting", "tried": false,
            ]
            for (k, v) in over { f[k] = v }
            return f
        }
        let list: [String: Any] = [
            "version": 1,
            "flags": [
                flag("00000000-0000-4000-8000-000000000001", [:]),
                flag("00000000-0000-4000-8000-000000000002", bad.merging(["word": "hide"]) { a, _ in a }),
                flag("00000000-0000-4000-8000-000000000003", ["word": "hide", "reason": "rarer"]),
            ],
            "forget": [],
        ]
        return try! JSONSerialization.data(withJSONObject: list)
    }

    /// Ways a stored flag can be one the server would refuse.
    enum Corrupt: String, CaseIterable, Sendable {
        case unknownReason = "a reason the server has never had"
        case capitals = "a word in capitals"
        case noDay = "a flag with no day"
        case beforeTheGame = "a day before the game began"
        case unrealDay = "a day that isn't one"
        case badId = "an ID that is not one"

        var fields: [String: Any] {
            switch self {
            case .unknownReason: ["reason": "bogus"]
            case .capitals: ["word": "BAD"]
            case .noDay: ["day": NSNull()]
            case .beforeTheGame: ["day": "2026-06-01"]
            case .unrealDay: ["day": "2026-02-30"]
            case .badId: ["id": "not-an-id"]
            }
        }
    }

    @Test(arguments: Corrupt.allCases)
    func aBadStoredFlagIsDroppedAloneAndTheGoodOnesStillGo(corrupt: Corrupt) async {
        let what = corrupt.rawValue
        let storage = Memory()
        storage.values[FlagStore.key] = Self.stored(bad: corrupt.fields)
        let s = Self.setup([.status(202)], storage: storage)
        await s.flags.send(.launch)
        let sent = s.server.calls.flatMap(\.flags).compactMap { $0["id"] as? String }
        #expect(sent == ["00000000-0000-4000-8000-000000000001", "00000000-0000-4000-8000-000000000003"], "\(what)")
        #expect(s.flags.list.map(\.id) == sent, "\(what)")
        #expect(s.flags.list.allSatisfy { $0.state == .sent }, "\(what)")
    }

    /// A phone whose clock runs fast sends its own board's day, ahead of the
    /// server's. The server drops that flag alone (web #208), so the phone
    /// sends it like any other rather than deciding for the server.
    @Test func sendsADayAheadOfTheServersForTheServerToJudge() async {
        let s = Self.setup([.status(202)])
        _ = await s.flags.flag(word: "few", reason: .shouldCount, day: "2026-07-03")
        #expect(s.server.calls.first?.flags.first?["day"] as? String == "2026-07-03")
    }

    // MARK: - The size of a request

    /// The longest of each field: an 8-letter word, the longest reason, and a
    /// version as long as the server takes, 24 characters, far past the app's
    /// "1.4 (125)". Measured on the bodies the sender actually sends.
    @Test func keepsTheBiggestBatchWithinTheServersLimit() async throws {
        let longest = FlagReason.allCases.max { $0.rawValue.count < $1.rawValue.count }!
        let s = Self.setup([.offline], version: String(repeating: "9", count: 24))
        for i in 0..<FlagStore.maxWaiting {
            _ = await s.flags.flag(word: Self.nth("abcdef", i), reason: longest, day: Self.july1)
        }
        s.clock.later(11 * 60)
        s.server.forget()
        await s.flags.send(.launch)
        let first = try #require(s.server.calls.first)
        let bytes = try JSONSerialization.data(withJSONObject: first.body).count
        #expect(first.flags.count == FlagStore.maxPerRequest)
        #expect(bytes <= FlagStore.maxBodyBytes)
    }

    // MARK: - The day a board names

    @Test func namesABoardByItsCalendarDay() {
        // Storage day 0 is 2026-01-01; the first board, 23 June, is day 173.
        #expect(flagDay(storageDay: 0) == "2026-01-01")
        #expect(flagDay(storageDay: 173) == "2026-06-23")
        #expect(flagDay(storageDay: 365) == "2027-01-01")
        #expect(flagFirstDay == "2026-06-23")
    }
}
