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

    /// meta.json's counts do not describe the shipped files, and this test
    /// pins that rather than papering over it.
    ///
    /// meta.json was generated 2026-06-24; the lists were re-baked 2026-08-03
    /// with the curated dictionary patch applied. Nothing regenerated the
    /// metadata, so its counts describe a build that no longer ships. The
    /// brief's "430,000 words" comes from `meta.json.counts.boundary` (430,172)
    /// and the real figure is 427,290, close enough not to be noticed, which
    /// is exactly what makes it the same failure mode as the completion
    /// duplication: two records of one fact, drifting quietly.
    ///
    /// Recorded as a finding, not fixed. The web repo is out of scope here.
    @Test("meta.json's counts are stale relative to the shipped lists")
    func metaJSONIsStale() throws {
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

        #expect(meta.counts.enable == 172_727)      // actual 172_562, -165
        #expect(meta.counts.common == 10_861)       // actual  10_879, +18
        #expect(meta.counts.beyond70 == 318_691)    // actual 315_922, -2_769
        #expect(meta.counts.beyond95 == 5_399)      // actual   5_389, -10
        #expect(meta.counts.boundary == 430_172)    // actual 427_290, -2_882

        // The claim under test: they disagree. If a future re-snapshot makes
        // these match, delete this test, because the drift will have been fixed.
        let actualBoundary = try readWordList("enable.txt").count
            + readWordList("scowl95-additions.txt").count
        #expect(meta.counts.boundary != actualBoundary)
    }
}
