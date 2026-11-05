import CryptoKit
import Foundation
import Testing
@testable import PeachEngine

/// The growing peach's drawings, held to the peach's box and to the table
/// Antoine approved.
@Suite("the growing peach")
struct GrowthStageTests {
    /// The SHA-256 of `canonicalGrowthTable()`. `tools/growth-stages.py` prints
    /// the same hash from the approved drawings, so the Swift table and the
    /// drawings cannot drift apart without this failing.
    static let tableSHA256 = "4ec330c3fd5adf0d79a06be20e67fa2acfae5ba620d1bd7e61acb4221108ee1d"

    @Test("every part is absolute M, L, C and Z, and parses", arguments: GrowthStage.allCases)
    func parses(stage: GrowthStage) throws {
        #expect(!stage.parts.isEmpty, "\(stage) has nothing to draw")
        for part in stage.parts {
            let letters = part.d.filter(\.isLetter)
            #expect(letters.allSatisfy { "MLCZ".contains($0) }, "\(stage): \(part.d)")
            #expect(try !costumeCommands(part.d).isEmpty, "\(stage): \(part.d)")
        }
    }

    /// The costumes' guard, for the same reason: a cubic lies inside the hull
    /// of its four points, so every point inside the box, less half the
    /// stroke, keeps every edge of every stage inside the title's frame.
    @Test("every point stays inside the peach's box, strokes included", arguments: GrowthStage.allCases)
    func staysInTheBox(stage: GrowthStage) throws {
        for part in stage.parts {
            let pad = (part.strokeWidth ?? 0) / 2
            for command in try costumeCommands(part.d) {
                for (x, y) in command.points {
                    #expect((pad...(100 - pad)).contains(x), "\(stage): x \(x) in \(part.d)")
                    #expect((pad...(100 - pad)).contains(y), "\(stage): y \(y) in \(part.d)")
                }
            }
        }
    }

    @Test("is the table that was approved")
    func approved() {
        let digest = SHA256.hash(data: Data(canonicalGrowthTable().utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        #expect(hex == Self.tableSHA256)
    }

    @Test("one drawing for each rank, then the crown")
    func oneForEachRank() {
        #expect(GrowthStage.allCases.count == tiers.count + 1)
        #expect(GrowthStage.allCases.last == .crown)
    }

    @Test("each says what the peach is, differently")
    func spoken() {
        let spoken = GrowthStage.allCases.map(\.spoken)
        #expect(Set(spoken).count == GrowthStage.allCases.count)
        #expect(GrowthStage.blossom.spoken == "in blossom")
    }

    /// The rank's own drawing, the crown only once the basket is full, and the
    /// top named rank with set words still unfound is Perfectly Peachy, not
    /// the crown: completion is a word count, not a rank.
    @Test("a standing grows the peach to its rank, and the full basket crowns it")
    func stageForAStanding() {
        func standing(_ index: Int, found: Int, of total: Int) -> TierStanding {
            TierStanding(index: index, id: "tier-\(index)", score: 0, reachable: 100, fraction: 0,
                         setPoints: 0, offPagePoints: 0, setFound: found, setTotal: total,
                         next: nil, isTop: index == tiers.count - 1)
        }
        let ranks = GrowthStage.allCases.filter { $0 != .crown }
        for (index, stage) in ranks.enumerated() {
            #expect(GrowthStage(standing: standing(index, found: 1, of: 20)) == stage)
        }
        #expect(GrowthStage(standing: standing(5, found: 19, of: 20)) == .perfectlyPeachy)
        #expect(GrowthStage(standing: standing(5, found: 20, of: 20)) == .crown)
        #expect(GrowthStage(standing: standing(3, found: 20, of: 20)) == .crown)
        #expect(GrowthStage(standing: standing(0, found: 0, of: 20)) == .firstSprout)
    }

    /// Where a stage drawn from the peach stands: the peach scaled about the
    /// origin by `scale`, then moved by `x` and `y`, as `peach_parts()` in
    /// `tools/growth-stages.py` draws it. Ripening's body and highlight are its
    /// own unripe colours. The crowned stage wears its crown in the leaf's
    /// place. Perfectly Peachy is the peach itself, which the hash holds to
    /// the web's and `PeachMarkTests` holds `PeachMark` to.
    struct Placement: Sendable, CustomTestStringConvertible {
        let stage: GrowthStage
        let scale: Double
        let x: Double
        let y: Double
        var dropsLeaf = false
        var ownColours = false
        var testDescription: String { stage.rawValue }
    }

    static let fromThePeach: [Placement] = [
        Placement(stage: .ripening, scale: 0.72, x: 14, y: 24, ownColours: true),
        Placement(stage: .sweet, scale: 0.86, x: 7, y: 12),
        Placement(stage: .crown, scale: 1, x: 0, y: 0, dropsLeaf: true),
    ]

    /// A number as the generator writes one. Python's `f"{x:.1f}"` and C's
    /// `%.1f` both round the double's exact value, halves to even.
    static func rounded(_ v: Double, places: Int = 1) -> Double {
        Double(String(format: "%.\(places)f", v))!
    }

    static func placed(_ command: CostumeCommand, _ p: Placement) -> CostumeCommand {
        let at = { (pt: (Double, Double)) in
            (rounded(pt.0 * p.scale + p.x), rounded(pt.1 * p.scale + p.y))
        }
        switch command {
        case let .move(x, y): let q = at((x, y)); return .move(q.0, q.1)
        case let .line(x, y): let q = at((x, y)); return .line(q.0, q.1)
        case let .curve(c1, c2, to): return .curve(c1: at(c1), c2: at(c2), to: at(to))
        case .close: return .close
        }
    }

    /// Antoine, 4 November 2026: a stage drawn from the peach stops following
    /// it only when `DRAWN_ON_THEIR_OWN` in the generator names it, and the
    /// illustrations' import names one only when told to. Every other one is
    /// today's peach, placed: its outlines point for point at one decimal,
    /// its paint the peach's, its strokes scaled with it. The crowned stage
    /// included, under its crown.
    @Test("every stage drawn from the peach is today's peach, unless it's named as drawn on its own",
          arguments: fromThePeach)
    func followsThePeach(_ p: Placement) throws {
        #expect(GrowthStage.drawnOnTheirOwn.isSubset(of: Self.fromThePeach.map(\.stage)),
                "DRAWN_ON_THEIR_OWN names a stage that isn't drawn from the peach")
        if GrowthStage.drawnOnTheirOwn.contains(p.stage) { return }
        let skip = p.dropsLeaf ? 1 : 0
        let peach = Array(GrowthStage.perfectlyPeachy.parts.dropFirst(skip))
        let parts = p.stage.parts
        try #require(parts.count >= peach.count, "\(p.stage) has fewer parts than the peach")
        for (k, (part, from)) in zip(parts, peach).enumerated() {
            let name = "\(p.stage)'s part \(k + 1)"
            let drawn = try costumeCommands(part.d)
            let expected = try costumeCommands(from.d).map { Self.placed($0, p) }
            #expect(drawn == expected, "\(name) is not the peach's outline, placed: \(part.d)")
            let own = p.ownColours && [1, 2].contains(k + skip)
            if !own { #expect(part.fill == from.fill, "\(name) is not the peach's colour") }
            #expect(part.opacity == from.opacity, "\(name) is not the peach's opacity")
            #expect(part.stroke == from.stroke, "\(name) is not the peach's stroke")
            #expect(part.strokeWidth == from.strokeWidth.map { Self.rounded($0 * p.scale, places: 2) },
                    "\(name)'s stroke is not the peach's, scaled")
            #expect(part.faceOnly == from.faceOnly, "\(name) is not the face where the peach's is")
        }
        if p.dropsLeaf {
            let leaf = GrowthStage.perfectlyPeachy.parts[0].d
            #expect(!parts.map(\.d).contains(leaf), "\(p.stage) still wears the leaf")
        }
    }
}

/// The stage the title remembers, so it can draw the peach as it stood before
/// the word lists load.
@Suite("the remembered stage")
struct RememberedStageTests {
    final class CountingStore: KeyValueStore {
        let inner = InMemoryStore()
        var writes = 0
        func data(forKey key: String) -> Data? { inner.data(forKey: key) }
        func set(_ data: Data?, forKey key: String) {
            writes += 1
            inner.set(data, forKey: key)
        }
    }

    @Test("a day's stage survives a relaunch")
    func survives() {
        let store = InMemoryStore()
        GameStorage(store: store).rememberStage(.blossom, dayIndex: 300)
        #expect(GameStorage(store: store).rememberedStage(dayIndex: 300) == .blossom)
    }

    @Test("another day's stage is not today's")
    func onlyItsOwnDay() {
        let storage = GameStorage(store: InMemoryStore())
        #expect(storage.rememberedStage(dayIndex: 300) == nil)
        storage.rememberStage(.sweet, dayIndex: 299)
        #expect(storage.rememberedStage(dayIndex: 300) == nil)
        storage.rememberStage(.littleBud, dayIndex: 300)
        #expect(storage.rememberedStage(dayIndex: 300) == .littleBud)
    }

    @Test("a stage this build does not know, or a corrupt one, reads as none")
    func unknownReadsAsNone() {
        let store = InMemoryStore()
        let storage = GameStorage(store: store)
        store.set(Data(#"{"day":300,"stage":"giant-peach"}"#.utf8), forKey: GameStorage.stageKey)
        #expect(storage.rememberedStage(dayIndex: 300) == nil)
        store.set(Data("not json".utf8), forKey: GameStorage.stageKey)
        #expect(storage.rememberedStage(dayIndex: 300) == nil)
        store.set(Data(#"{"stage":"blossom"}"#.utf8), forKey: GameStorage.stageKey)
        #expect(storage.rememberedStage(dayIndex: 300) == nil, "a stage with no day matched a day")
    }

    @Test("a find that keeps the stage writes nothing")
    func writesOnlyAChange() {
        let store = CountingStore()
        let storage = GameStorage(store: store)
        storage.rememberStage(.blossom, dayIndex: 300)
        storage.rememberStage(.blossom, dayIndex: 300)
        #expect(store.writes == 1)
        storage.rememberStage(.ripening, dayIndex: 300)
        #expect(store.writes == 2)
    }
}
