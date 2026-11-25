import Foundation

// Peach rush: one run a day against the clock on today's board, whose words
// carry into the basket when it ends (Antoine, 25 November 2026). The design
// is `reports/2026-11-24 Timed Mode.md` in the vault, and its update with
// Antoine's answers is the plan.
//
// Everything here is pure, so `swift test` holds it without the app: the
// record, the run in flight, which state the title's button is in, the clock
// as arithmetic, the time marks VoiceOver hears, the best word and the share.

/// How long a run lasts: Bea's 1:30, or 3:00 with Longer clock on.
public enum RunLength {
    public static let standard: Double = 90
    public static let longer: Double = 180

    public static func seconds(longerClock: Bool) -> Double {
        longerClock ? longer : standard
    }
}

/// A day's run, kept. One a day: the first, and only.
public struct RunRecord: Codable, Equatable, Sendable {
    /// The storage day the run was on.
    public var day: Int
    /// Newest first, as the basket keeps its own.
    public var words: [String]
    public var points: Int
    public var peachFound: Bool
    /// The player chose End, rather than the clock running out.
    public var endedEarly: Bool
    /// Whole seconds left when it ended: 0 when the clock ran out.
    public var secondsLeft: Int
    /// The run's length, so its result and its share say 1:30 or 3:00.
    public var length: Double
    /// The run's words filled the basket, and the full basket's card hasn't
    /// played yet: it plays when the basket next opens.
    public var completionOwed: Bool
    /// The peach of a word the run found, while its card hasn't been seen:
    /// it opens once, on the first screen after the run ends.
    public var owedPeachCard: String?

    public init(day: Int, words: [String], points: Int, peachFound: Bool,
                endedEarly: Bool, secondsLeft: Int, length: Double,
                completionOwed: Bool = false) {
        self.day = day
        self.words = words
        self.points = points
        self.peachFound = peachFound
        self.endedEarly = endedEarly
        self.secondsLeft = secondsLeft
        self.length = length
        self.completionOwed = completionOwed
    }

    private enum CodingKeys: String, CodingKey {
        case day, words, points, peachFound, endedEarly, secondsLeft, length, completionOwed, owedPeachCard
    }

    /// A record kept before `completionOwed` and `owedPeachCard` existed reads
    /// as owing nothing.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        day = try c.decode(Int.self, forKey: .day)
        words = try c.decode([String].self, forKey: .words)
        points = try c.decode(Int.self, forKey: .points)
        peachFound = try c.decode(Bool.self, forKey: .peachFound)
        endedEarly = try c.decode(Bool.self, forKey: .endedEarly)
        secondsLeft = try c.decode(Int.self, forKey: .secondsLeft)
        length = try c.decode(Double.self, forKey: .length)
        completionOwed = try c.decodeIfPresent(Bool.self, forKey: .completionOwed) ?? false
        owedPeachCard = try c.decodeIfPresent(String.self, forKey: .owedPeachCard)
    }
}

/// A run started and not ended: what it has found and how long it has left.
/// Saved at each find and each pause, so a call or iOS ending the app behind
/// it costs nothing.
public struct RunInFlight: Codable, Equatable, Sendable {
    public var day: Int
    public var words: [String]
    public var points: Int
    public var peachFound: Bool
    public var remaining: Double
    public var length: Double

    public init(day: Int, words: [String], points: Int, peachFound: Bool,
                remaining: Double, length: Double) {
        self.day = day
        self.words = words
        self.points = points
        self.peachFound = peachFound
        self.remaining = remaining
        self.length = length
    }

    /// The run as kept when it ends with what it has: by End, or by a new day
    /// or the basket arriving while it waits.
    public func ended(early: Bool) -> RunRecord {
        RunRecord(day: day, words: words, points: points, peachFound: peachFound,
                  endedEarly: early, secondsLeft: early ? Int(remaining.rounded(.up)) : 0,
                  length: length)
    }
}

/// What the title's button offers today.
public enum RunOffer: Equatable, Sendable {
    /// No button: the basket started before a run was played.
    case none
    /// A run to start.
    case fresh
    /// A run in flight, paused, with this long left.
    case paused(remaining: Double)
    /// Today's run, played: the button opens its result again.
    case played(RunRecord)
}

/// The rule (Antoine, 24 November 2026, rule A): one run a day, on today's
/// board, offered until the basket's first find. A run already played is
/// shown, never replayed, and a run in flight waits to be resumed.
public func runOffer(today: Int, record: RunRecord?, inFlight: RunInFlight?,
                     basketFinds: Int) -> RunOffer {
    if let record, record.day == today { return .played(record) }
    if let inFlight, inFlight.day == today { return .paused(remaining: inFlight.remaining) }
    return basketFinds == 0 ? .fresh : .none
}

/// The run's clock, as arithmetic on a monotonic time the caller supplies.
///
/// **Not the wall clock.** The app passes the system's uptime, so changing the
/// phone's time mid-run neither adds seconds nor takes them away.
public struct RunClock: Equatable, Sendable {
    /// Seconds left when the clock last stopped, or when it started.
    public private(set) var held: Double
    /// When the clock last started, on the caller's monotonic time, or nil
    /// while it is stopped.
    public private(set) var startedAt: Double?

    public init(remaining: Double) {
        held = max(0, remaining)
        startedAt = nil
    }

    public var isRunning: Bool { startedAt != nil }

    public func remaining(at now: Double) -> Double {
        guard let startedAt else { return held }
        return max(0, held - max(0, now - startedAt))
    }

    public mutating func start(at now: Double) {
        guard startedAt == nil else { return }
        startedAt = now
    }

    public mutating func stop(at now: Double) {
        held = remaining(at: now)
        startedAt = nil
    }
}

/// The time marks VoiceOver hears, in seconds left: a minute, 30 seconds and
/// 10 seconds. Never every second.
public let runTimeMarks: [Int] = [60, 30, 10]

/// The mark to say on a tick that moved the clock from `before` to `after`
/// seconds left, if any.
///
/// **Only on the tick that crosses it, and only while it is still true.** A
/// mark is due when the clock passes it and is still within a second of it. A
/// tick that jumps past a mark by more than that, after a stall, says nothing
/// for it, since "30 seconds left." at 0:05 is untrue, and so is "10 seconds
/// left.". Two marks are never said at once. Resuming a paused run is not a
/// crossing, so it says nothing either: the caller says the time left.
public func runMarkDue(before: Double, after: Double) -> Int? {
    runTimeMarks.last { mark in
        let m = Double(mark)
        return before > m && after <= m && after > m - 1
    }
}

/// The highest-scoring find, a tie going to the earliest found, as the found
/// list's "Best word" does. `words` is newest first.
public func bestRunWord(_ words: [String], score: (String) -> Int) -> (word: String, points: Int)? {
    var best: (word: String, points: Int)?
    for word in words.reversed() {
        let points = score(word)
        if best == nil || points > best!.points { best = (word, points) }
    }
    return best
}

/// "1:30", as the clock shows it. Whole seconds, rounded up, so the clock
/// reads 0:01 until the run is over.
public func runClockText(_ seconds: Double) -> String {
    let whole = Int(max(0, seconds).rounded(.up))
    return "\(whole / 60):" + String(format: "%02d", whole % 60)
}

/// "1 minute 12 seconds", as VoiceOver says the time.
public func runSpokenTime(_ seconds: Double) -> String {
    let whole = Int(max(0, seconds).rounded(.up))
    let minutes = whole / 60
    let rest = whole % 60
    switch (minutes, rest) {
    case (0, _): return counted(rest, "second")
    case (_, 0): return counted(minutes, "minute")
    default: return "\(counted(minutes, "minute")) \(counted(rest, "second"))"
    }
}

/// The run's own share, three lines (Antoine, 24 November 2026: share A):
///
///     🍑 Peach of a Word · Nov 14
///     ⏱️ Peach rush · 1:30
///     14 words · 57 points 🍑
///
/// The last 🍑 says the run found the peach of a word, and the word itself is
/// never in it. The basket's share is unchanged.
public func buildRunShareText(name: String, record: RunRecord, boardDate: Date,
                              timeZone: TimeZone = .current) -> String {
    [
        "\u{1F351} Peach of a Word · \(shortDate(boardDate, timeZone: timeZone))",
        "\u{23F1}\u{FE0F} \(name) · \(runClockText(record.length))",
        "\(counted(record.words.count, "word")) · \(counted(record.points, "point"))"
            + (record.peachFound ? " \u{1F351}" : ""),
    ].joined(separator: "\n")
}
