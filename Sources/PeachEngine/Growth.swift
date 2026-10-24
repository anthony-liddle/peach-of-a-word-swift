import Foundation

/// The title's peach as it grows with today's rank: one drawing for each of
/// the six ranks, then the crown once the basket is full.
///
/// **Drawn the costumes' way.** Each part is SVG path data in the peach's own
/// 100x100 box, absolute M, L, C and Z, read by `costumeCommands` and drawn by
/// the layer a costume is drawn by, so no stage can leave the peach's
/// footprint, and the title's 96pt frame holds every one. Perfectly Peachy is
/// today's peach, the `PeachMark` paths, and the crown is that peach with a
/// crown in the leaf's place.
///
/// **Generated, not transcribed.** The table is in `GrowthStages.swift`,
/// written by `tools/growth-stages.py` from the drawings Antoine approved on
/// 24 October 2026, and `GrowthStageTests` pins its hash, so a hand edit to
/// either fails the suite until the two agree again.
///
/// **The raw values are what the title remembers between launches** (see
/// `GameStorage.rememberStage`), so they are names, not positions: a stage
/// this build has never heard of reads as none, rather than as whichever
/// drawing now sits at its index.
public enum GrowthStage: String, CaseIterable, Sendable {
    case firstSprout = "first-sprout"
    case littleBud = "little-bud"
    case blossom
    case ripening
    case sweet
    case perfectlyPeachy = "perfectly-peachy"
    case crown

    /// The stage a standing has reached: its rank's drawing, or the crown once
    /// every set word is found, which is when the title names the crown too.
    public init(standing: TierStanding) {
        if isComplete(standing) {
            self = .crown
            return
        }
        let ranks = Self.allCases.filter { $0 != .crown }
        self = ranks[min(max(standing.index, 0), ranks.count - 1)]
    }

    /// What the peach is at this stage, said after "The peach is".
    public var spoken: String { table.spoken }
    public var parts: [CostumePart] { table.parts }
}

struct GrowthTable: Sendable {
    let spoken: String
    let parts: [CostumePart]
}

/// The table as one canonical text, the way `canonicalCostumeTable()` writes
/// the costumes': the stage's own line, then one line per part, fields joined
/// by `|`, empty where unset. `tools/growth-stages.py` prints the SHA-256 of
/// the same text from the approved drawings.
public func canonicalGrowthTable() -> String {
    var lines: [String] = []
    for stage in GrowthStage.allCases {
        lines.append("\(stage.rawValue)|\(stage.spoken)")
        for p in stage.parts {
            lines.append([
                stage.rawValue,
                p.d,
                p.fill ?? "",
                p.opacity.map(jsNumber) ?? "",
                p.stroke ?? "",
                p.strokeWidth.map(jsNumber) ?? "",
                String(p.faceOnly),
            ].joined(separator: "|"))
        }
    }
    return lines.joined(separator: "\n")
}
