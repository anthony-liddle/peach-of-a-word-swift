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

    /// `PeachMark`'s own paths, from `public/favicon-cute.svg`, written out
    /// absolute: the leaf, the body and the highlight.
    static let peachLeaf = "M50 12 C54 4 64 3 68 8 C66 14 59 17 54 16 Z"
    static let peachBody = "M50 16 C70 16 84 32 84 52 C84 74 68 90 50 90 C32 90 16 74 16 52 C16 32 30 16 50 16 Z"
    static let peachHighlight = "M50 16 C41 16 33 20 27 27 C34 31 42 32 50 32 C58 32 66 31 73 27 C67 20 59 16 50 16 Z"

    @Test("Perfectly Peachy is today's peach, and the crown wears its crown in the leaf's place")
    func theTopIsThePeach() {
        let peach = GrowthStage.perfectlyPeachy.parts.map(\.d)
        #expect(Array(peach.prefix(3)) == [Self.peachLeaf, Self.peachBody, Self.peachHighlight])
        let crowned = GrowthStage.crown.parts.map(\.d)
        #expect(!crowned.contains(Self.peachLeaf), "the crown still wears the leaf")
        #expect(Array(crowned.prefix(peach.count - 1)) == Array(peach.dropFirst()),
                "the crown is not today's peach under it")
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
