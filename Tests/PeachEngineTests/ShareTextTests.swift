import Foundation
import Testing
@testable import PeachEngine

@Suite("daily share text")
struct ShareTextTests {
    let utc = TimeZone(identifier: "UTC")!

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var cal = Foundation.Calendar(identifier: .gregorian)
        cal.timeZone = utc
        return cal.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    private func result(
        tier: String = "Blossom", setFound: Int = 12, setTotal: Int = 27,
        uncommon: Int = 5, rare: Int = 3, mythic: Int = 0,
        setPoints: Int = 52, offPagePoints: Int = 37, total: Int = 89
    ) -> DailyShareResult {
        DailyShareResult(
            title: "Peach of a Word", date: date(2026, 8, 9), tierLabel: tier,
            setFound: setFound, setTotal: setTotal,
            uncommon: uncommon, rare: rare, mythic: mythic,
            setPoints: setPoints, offPagePoints: offPagePoints, totalPoints: total
        )
    }

    @Test("matches the web's block, line for line")
    func format() {
        #expect(buildShareText(result(), timeZone: utc) == """
            \u{1F351} Peach of a Word \u{00B7} Aug 9
            Blossom \u{00B7} 12 of 27 words
            \u{1F7E5}\u{1F7E5}\u{1F7E5}\u{1F7E5}\u{1F7E5}\u{1F7E5}\u{1F7EA}\u{1F7EA}\u{1F7EA}\u{1F7EA}
            \u{2726} 5 Uncommon \u{00B7} 3 Rare
            89 pts
            """)
    }

    @Test("drops the rarity line entirely when there are no off-page finds")
    func noRarityLine() {
        let text = buildShareText(
            result(uncommon: 0, rare: 0, mythic: 0, setPoints: 52, offPagePoints: 0, total: 52),
            timeZone: utc
        )
        #expect(!text.contains("\u{2726}"))
        #expect(text.split(separator: "\n").count == 4)
    }

    @Test("the score row is always the fixed width")
    func fixedWidth() {
        for (set, off) in [(0, 0), (100, 0), (0, 100), (1, 99), (99, 1), (50, 50)] {
            let row = buildShareText(result(setPoints: set, offPagePoints: off),
                                     timeZone: utc).split(separator: "\n")[2]
            #expect(row.count == 10, "set \(set) off \(off)")
        }
    }

    @Test("a real haul never rounds away to nothing")
    func neverRoundsAway() {
        // One off-page point against a big set total would round to zero purple.
        let row = buildShareText(result(setPoints: 200, offPagePoints: 1),
                                 timeZone: utc).split(separator: "\n")[2]
        #expect(row.contains("\u{1F7EA}"))
        // And the reverse: a nearly all off-page board keeps one red square.
        let row2 = buildShareText(result(setPoints: 1, offPagePoints: 200),
                                  timeZone: utc).split(separator: "\n")[2]
        #expect(row2.contains("\u{1F7E5}"))
    }

    /// The guarantee that matters.
    ///
    /// The daily is reproducible: a recipient can go and play the same rack, so
    /// the answer must stay hidden. `DailyShareResult` has no source-word field
    /// at all, which is the same protection the web gets from its discriminated
    /// union. This proves it against the real puzzle rather than against a
    /// fixture, so a future field that did carry the word would fail here.
    @Test("no daily share can contain the source word or any found word")
    func spoilerSafe() throws {
        let data = dataDirectory
        let enable = try readWordList("enable.txt", in: data)
            + readWordList("scowl95-additions.txt", in: data)
        let puzzle = createPuzzle(
            sourceWord: "motorway",
            dictionary: ListDictionary(enable),
            commonPool: ListWordSource(try readWordList("common-pool.txt", in: data)),
            beyond70Pool: ListWordSource(try readWordList("beyond-size-70.txt", in: data)),
            beyond95Pool: ListWordSource(try readWordList("beyond-size-95.txt", in: data))
        )
        let standing = computeTier(found: puzzle.commonWords, puzzle: puzzle)
        let text = buildShareText(
            DailyShareResult(
                title: "Peach of a Word", date: date(2026, 8, 9),
                tierLabel: "Peachy Keen Supreme",
                setFound: standing.setFound, setTotal: standing.setTotal,
                uncommon: 0, rare: 0, mythic: 0,
                setPoints: standing.setPoints, offPagePoints: standing.offPagePoints,
                totalPoints: standing.score
            ),
            timeZone: utc
        )
        let lower = text.lowercased()
        #expect(!lower.contains(puzzle.sourceWord))
        // And no other word from the rack either, which catches a leak that
        // happened to print a found word rather than the answer.
        for word in puzzle.validationWords where word.count >= 4 {
            #expect(!lower.contains(word), "leaked \(word)")
        }
    }
}
