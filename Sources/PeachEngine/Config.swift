/// Game rules. Numbers the GDD flags as tunable live here as named constants,
/// not scattered literals: the scoring curve, the tier ladder, the epochs.
///
/// These are top-level constants rather than members of an enum namespace,
/// deliberately: it is the closest Swift shape to the TypeScript module of
/// exported consts this is ported from, which keeps the two readable side by
/// side. In Swift 6 a global `let` must be immutable and `Sendable`; every type
/// here satisfies that.

/// Minimum playable word length, honoring the original game.
public let minWordLength = 3

/// The source word is always exactly 8 letters.
public let sourceWordLength = 8

/// Minimum set size for a source word to headline a puzzle. Crown-inclusive:
/// the same "X of Y" count the completion counter shows, which includes the
/// source word itself. A daily under this floor felt thin, so sub-floor words
/// stay real words found inside other racks but never headline a day.
public let minSetSize = 15

/// Where a found word sits relative to the set. The set is the goal and carries
/// no rarity label; everything off the page is graded on the three-rung ladder.
/// The source word is orthogonal: it is also a set word, flagged separately.
///
/// A Swift `enum` with a raw value. Unlike the TypeScript string-union it ports
/// (`'set' | 'uncommon' | 'rare' | 'mythic'`), a `switch` over it is checked for
/// exhaustiveness by the compiler, so adding a rung later breaks every site that
/// needs updating, rather than silently falling through.
public enum Rung: String, Sendable, CaseIterable {
    case set, uncommon, rare, mythic
}

extension Rung {
    /// DRAFT, TUNABLE. The rarity bonus added on top of the length score for an
    /// off-page find. A set word is the on-page baseline and carries no bonus.
    ///
    /// These pay for the discovery the game is built around, but stay modest
    /// because the ladder denominator is the set points: a small, stable
    /// scale. Measured on real racks, a bonus of 3/6/12 let four off-page hits
    /// top the ladder while the common words sat untouched, so these are tuned
    /// down to keep the guardrail honest: topping needs roughly 7 to 21
    /// off-page finds, so breadth still matters.
    public var bonus: Int {
        switch self {
        case .set: 0
        case .uncommon: 1
        case .rare: 2
        case .mythic: 4
        }
    }
}

/// Score for a word of the given length. 0 below the minimum length.
///
/// `case 8...` is a one-sided range pattern: eight letters or more. The
/// TypeScript this ports used a lookup object plus a `?? (length > 8 ? 15 : 0)`
/// fallback, where the above-8 branch was never tested. Here it is a visible
/// case, and it has a test.
public func scoreForLength(_ length: Int) -> Int {
    switch length {
    case 3: 1
    case 4: 3
    case 5: 5
    case 6: 7
    case 7: 11
    case 8...: 15
    default: 0
    }
}

/// A rung on the named points ladder. Names are theme-skinned in the UI, which
/// this port does not include.
public struct TierDef: Sendable, Equatable {
    /// Theme-neutral id; the displayed name is a per-theme skin over the index.
    public let id: String
    /// Fraction of the rack's reachable score needed to reach this rank (0 to 1).
    public let threshold: Double

    public init(id: String, threshold: Double) {
        self.id = id
        self.threshold = threshold
    }
}

/// The named ladder: six ranks by score as a fraction of the rack's reachable
/// score, low to high. DRAFT, TUNABLE thresholds.
///
/// The top named rank sits at 0.80, not 1.00: finding everything is the
/// completion peak, which sits above this whole ladder. There is no source-word
/// gate on the named ranks; the crown is its own separate moment.
public let tiers: [TierDef] = [
    TierDef(id: "tier-0", threshold: 0),
    TierDef(id: "tier-1", threshold: 0.08),
    TierDef(id: "tier-2", threshold: 0.22),
    TierDef(id: "tier-3", threshold: 0.4),
    TierDef(id: "tier-4", threshold: 0.6),
    TierDef(id: "tier-5", threshold: 0.8),
]

/// A calendar date with no time and no zone: the anchor for a day index.
public struct EpochDate: Sendable, Equatable {
    public let year: Int
    /// 1 to 12. Note this differs from JavaScript's 0-based `Date` month, and
    /// matches Foundation's `DateComponents`, which is also 1-based. The
    /// TypeScript had to write `epoch.month - 1` at the call site; this does not.
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }
}

/// Day one of the daily sequence (local calendar date). The day index is the
/// number of whole calendar days from this date. Tunable: a calendar
/// regeneration may re-anchor it.
public let dailyEpoch = EpochDate(year: 2026, month: 6, day: 23)

/// Fixed origin for the per-day storage and streak key. This NEVER moves, even
/// when `dailyEpoch` is re-anchored by a calendar regeneration.
///
/// The crown for a date is selected from the movable `dailyEpoch`, but progress
/// and streak are keyed by days since this fixed origin, so re-anchoring the
/// calendar cannot shift the day keys and a streak survives a regeneration with
/// no migration. Persisted records are already days since this date, so it must
/// stay 2026-01-01.
public let storageEpoch = EpochDate(year: 2026, month: 1, day: 1)

/// Named-ladder rank a daily must reach to count toward the streak. Index 3 is
/// the 0.40 rung of the six-rank ladder, a sensible "this day counts" mark.
/// Tied to the ladder, so revisit if `tiers` changes.
public let streakTierIndex = 3
