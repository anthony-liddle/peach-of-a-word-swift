import Foundation
import Testing
@testable import PeachEngine

@Suite("package smoke")
struct SmokeTests {
    /// The word counts that actually parse out of the frozen snapshot.
    ///
    /// These are NOT meta.json's counts; see `metaJSONIsStale` below. They are
    /// `wc -l` plus one, because none of the shipped lists ends in a newline.
    static let expectedCounts = [
        ("enable.txt", 172_562),
        ("scowl95-additions.txt", 254_728),
        ("common-pool.txt", 10_879),
        ("beyond-size-70.txt", 315_922),
        ("beyond-size-95.txt", 5_389),
    ]

    @Test("the frozen data snapshot is present and the expected size",
          arguments: expectedCounts)
    func snapshotPresent(name: String, count: Int) throws {
        #expect(try readWordList(name).count == count)
    }

    /// The validation dictionary is ENABLE unioned with the SCOWL 95 additions,
    /// exactly as the web's `loadGameData` assembles it. This is the number the
    /// dictionary-load measurement is about.
    @Test("the boundary list is the union of enable and the SCOWL 95 additions")
    func boundarySize() throws {
        let boundary = try readWordList("enable.txt") + readWordList("scowl95-additions.txt")
        #expect(boundary.count == 427_290)
        // Disjoint by construction: the additions are what SCOWL 95 adds *on
        // top of* ENABLE, so the union has no duplicates to collapse.
        #expect(Set(boundary).count == 427_290)
    }

    /// meta.json's counts describe the files in this snapshot.
    ///
    /// This test used to assert the opposite. `metaJSONIsStale` pinned a real
    /// defect: meta.json was generated 2026-06-24, the lists were re-baked
    /// 2026-08-03 with the curated patch applied, and nothing regenerated the
    /// metadata, so every count described a build that no longer shipped. The
    /// boundary was out by 2,882 words, and the figure escaped into a published
    /// essay as "430,000 words" when the real number was 427,290.
    ///
    /// Fixed upstream 2026-08-11: `pnpm data:bake` now rewrites meta.json from
    /// the artifacts it produces, and `src/data/meta.test.ts` asserts every
    /// count against the committed file it describes. This snapshot was taken
    /// after that fix, so the claim inverts.
    ///
    /// Kept rather than deleted, which its predecessor's own comment suggested.
    /// A deleted test leaves this repo with no opinion about a file it ships,
    /// and the web-side guard cannot see a snapshot copied wrong. This one can.
    /// It is the check that catches a partial re-snapshot, lists updated and
    /// metadata forgotten, which is the exact shape of the original bug.
    ///
    /// Derived, never hardcoded. Literal expectations here would be a third
    /// record of the same fact and would rot the way meta.json did.
    @Test("meta.json's counts describe the lists in this snapshot")
    func metaJSONMatchesShippedLists() throws {
        struct Meta: Codable {
            struct Counts: Codable {
                let enable: Int
                let scowl95Additions: Int
                let boundary: Int
                let common: Int
                let beyond70: Int
                let beyond95: Int
            }
            let counts: Counts
        }
        let url = dataDirectory.appendingPathComponent("meta.json")
        let meta = try JSONDecoder().decode(Meta.self, from: try Data(contentsOf: url))

        let enable = try readWordList("enable.txt").count
        let additions = try readWordList("scowl95-additions.txt").count

        #expect(meta.counts.enable == enable)
        #expect(meta.counts.scowl95Additions == additions)
        #expect(meta.counts.common == (try readWordList("common-pool.txt").count))
        #expect(meta.counts.beyond70 == (try readWordList("beyond-size-70.txt").count))
        #expect(meta.counts.beyond95 == (try readWordList("beyond-size-95.txt").count))

        // The boundary is the union the app assembles, and the pair is disjoint
        // by construction, so it is the sum.
        #expect(meta.counts.boundary == enable + additions)
    }
}
