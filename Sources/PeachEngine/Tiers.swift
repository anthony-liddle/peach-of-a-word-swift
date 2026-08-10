/// The next rank up, and the fraction needed to reach it.
public struct NextRank: Sendable, Equatable {
    public let index: Int
    public let threshold: Double

    public init(index: Int, threshold: Double) {
        self.index = index
        self.threshold = threshold
    }
}

/// A computed standing on the named points ladder.
///
/// The rank is score as a fraction of the rack's reachable score, so every find
/// (set or off-page) moves it up and rarity pays more. Theme-neutral: the
/// displayed rank name is skinned over `index` in the UI, which this port does
/// not include. `setFound`/`setTotal` are carried for the completion
/// celebration, never to grade the ladder.
public struct TierStanding: Sendable, Equatable {
    /// Index into the named ladder (0 to 5).
    public let index: Int
    public let id: String
    /// Points earned so far: length scores plus rarity bonuses.
    public let score: Int
    /// Par: total set points available on the rack (the denominator).
    public let reachable: Int
    /// score / reachable, 0 to 1, and above 1 once off-page points overflow.
    public let fraction: Double
    /// Points from set (on-page) finds, for the two-color bar.
    public let setPoints: Int
    /// Points from off-page finds, for the two-color bar.
    public let offPagePoints: Int
    /// Set words found. Feeds `isComplete`, not the rank.
    public let setFound: Int
    /// Total set words. Feeds `isComplete`, not the rank.
    public let setTotal: Int
    /// The next rank, or nil at the top named rank.
    ///
    /// A genuine Optional, unlike the TypeScript's `| null`: the compiler will
    /// not let a caller read `.index` off it without handling the nil case.
    public let next: NextRank?
    /// True once the top named rank is reached (below full completion).
    public let isTop: Bool

    public init(
        index: Int, id: String, score: Int, reachable: Int, fraction: Double,
        setPoints: Int, offPagePoints: Int, setFound: Int, setTotal: Int,
        next: NextRank?, isTop: Bool
    ) {
        self.index = index
        self.id = id
        self.score = score
        self.reachable = reachable
        self.fraction = fraction
        self.setPoints = setPoints
        self.offPagePoints = offPagePoints
        self.setFound = setFound
        self.setTotal = setTotal
        self.next = next
        self.isTop = isTop
    }
}

/// Compute the standing on the named points ladder.
///
/// The rank is score (length plus rarity bonuses) as a fraction of par. There
/// is no set gate and no source-word gate: the old set-fraction goal that
/// walled a player at "X of Y" is gone. `setFound` and `setTotal` are still
/// tallied, but only for completion, never to grade the ladder.
public func computeTier(found: Set<String>, puzzle: Puzzle) -> TierStanding {
    var score = 0
    var setPoints = 0
    var offPagePoints = 0
    var setFound = 0

    for word in found {
        let rung = classifyWord(word, in: puzzle)
        let points = findScore(word, rung: rung)
        score += points
        if rung == .set {
            setPoints += points
            setFound += 1
        } else {
            offPagePoints += points
        }
    }

    let reachable = puzzle.reachableScore
    let fraction = reachable > 0 ? Double(score) / Double(reachable) : 0

    // Highest rank whose threshold the fraction meets.
    var index = 0
    for i in tiers.indices where fraction >= tiers[i].threshold {
        index = i
    }

    // `tiers[index + 1]` would trap on the last rank. Swift arrays do not
    // return undefined for an out-of-bounds read the way JavaScript does; they
    // crash, so the bound is checked explicitly and turned into an Optional.
    let next = index + 1 < tiers.count
        ? NextRank(index: index + 1, threshold: tiers[index + 1].threshold)
        : nil

    return TierStanding(
        index: index,
        id: tiers[index].id,
        score: score,
        reachable: reachable,
        fraction: fraction,
        setPoints: setPoints,
        offPagePoints: offPagePoints,
        setFound: setFound,
        setTotal: puzzle.commonWords.count,
        next: next,
        isTop: index == tiers.count - 1
    )
}
