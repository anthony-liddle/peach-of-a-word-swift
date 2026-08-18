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

    /// The shared parity fixture.
    ///
    /// **These exact inputs are also `exampleResult` in the web's
    /// `src/ui/share/shareText.test.ts`, and the expected block below is the
    /// same string.** Before this, both repos asserted an exact block over
    /// different inputs, so the test named "matches the web's block" could not
    /// detect drift in either direction: change one repo's separator and both
    /// suites stayed green. Same input, same expected output, in both suites,
    /// is the cheapest thing that actually fails when the two formats diverge.
    ///
    /// The numbers are Bea's worked example, and they are internally consistent
    /// on purpose: 39 + 26 + 2 = 67 off-page finds, 99 + 388 = 487 points, and
    /// 388/487 rounds to the 8 purple squares in the row.
    private func result(
        tier: String = "Peachy Keen Supreme", setFound: Int = 33, setTotal: Int = 33,
        uncommon: Int = 39, rare: Int = 26, mythic: Int = 2,
        setPoints: Int = 99, offPagePoints: Int = 388, total: Int = 487,
        setLabel: String = "basket", offPageLabel: String = "wild"
    ) -> DailyShareResult {
        DailyShareResult(
            title: "Peach of a Word", date: date(2026, 8, 18), tierLabel: tier,
            setFound: setFound, setTotal: setTotal,
            uncommon: uncommon, rare: rare, mythic: mythic,
            setPoints: setPoints, offPagePoints: offPagePoints, totalPoints: total,
            setLabel: setLabel, offPageLabel: offPageLabel
        )
    }

    @Test("matches the web's block, line for line, on the same inputs")
    func format() {
        #expect(buildShareText(result(), timeZone: utc) == """
            \u{1F351} Peach of a Word \u{00B7} Aug 18
            Peachy Keen Supreme \u{00B7} 33 of 33 words + 67
            \u{1F7E5}\u{1F7E5}\u{1F7EA}\u{1F7EA}\u{1F7EA}\u{1F7EA}\u{1F7EA}\u{1F7EA}\u{1F7EA}\u{1F7EA}
            \u{2726} 39 Uncommon \u{00B7} 26 Rare \u{00B7} 2 Mythic
            99 basket/388 wild \u{00B7} 487 total points
            """)
    }

    /// The words line's off-page count is the rarity line's rungs, summed.
    ///
    /// Derived rather than passed, so the two lines cannot disagree: there is no
    /// second tally to fall out of step with the first. It is a count of finds,
    /// never a denominator, for the same reason the rungs never show one.
    @Test("the off-page count is the rungs summed")
    func offPageCount() {
        let line = buildShareText(result(uncommon: 5, rare: 3, mythic: 1),
                                  timeZone: utc).split(separator: "\n")[1]
        #expect(line == "Peachy Keen Supreme \u{00B7} 33 of 33 words + 9")
    }

    @Test("the words line drops the off-page count when there are no off-page finds")
    func noOffPageCount() {
        let line = buildShareText(
            result(uncommon: 0, rare: 0, mythic: 0, setPoints: 99, offPagePoints: 0, total: 99),
            timeZone: utc
        ).split(separator: "\n")[1]
        #expect(line == "Peachy Keen Supreme \u{00B7} 33 of 33 words")
    }

    /// The split appears only when there is something to split.
    ///
    /// An all-set board has nothing in the purple half, so a line reading
    /// "99 basket/0 wild" would spend two labels to say zero. The block degrades
    /// to the single total it carried before the split existed, alongside the
    /// rarity line and the off-page count, which drop on the same board.
    @Test("the points line falls back to the plain total with no off-page points")
    func noSplitWithoutOffPagePoints() {
        let text = buildShareText(
            result(uncommon: 0, rare: 0, mythic: 0, setPoints: 99, offPagePoints: 0, total: 99),
            timeZone: utc
        )
        #expect(text.split(separator: "\n").last == "99 pts")
        #expect(!text.contains("basket"))
    }

    @Test("drops the rarity line entirely when there are no off-page finds")
    func noRarityLine() {
        let text = buildShareText(
            result(uncommon: 0, rare: 0, mythic: 0, setPoints: 99, offPagePoints: 0, total: 99),
            timeZone: utc
        )
        #expect(!text.contains("\u{2726}"))
        #expect(text.split(separator: "\n").count == 4)
    }

    /// The labels are theme vocabulary, passed in like the tier label.
    ///
    /// The engine does not own them for the same reason it does not own the
    /// rank names: the web ships letterpress as well as cute, where the
    /// container is the case rather than the basket. Both labels reach the
    /// block from the caller's copy module, so a theme cannot leak the other
    /// theme's noun into a share.
    @Test("the labels come from the caller, so letterpress reads as letterpress")
    func themedLabels() {
        let line = buildShareText(result(setLabel: "set", offPageLabel: "off-page"),
                                  timeZone: utc).split(separator: "\n").last
        #expect(line == "99 set/388 off-page \u{00B7} 487 total points")
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
    ///
    /// **The themed strings are chrome and are stripped before the assertion**,
    /// which the web's version has always done for the title and the tier and
    /// which the point labels now make load-bearing here too. A label is a word,
    /// and a rack can form it: `downhill` is a real calendar rack that spells
    /// `wild`, and 17 of them spell `case`. Without the strip, the first such
    /// day would fail this test for a leak that never happened.
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
        let share = DailyShareResult(
            title: "Peach of a Word", date: date(2026, 8, 18),
            tierLabel: "Peachy Keen Supreme",
            setFound: standing.setFound, setTotal: standing.setTotal,
            uncommon: 0, rare: 0, mythic: 0,
            setPoints: standing.setPoints, offPagePoints: standing.offPagePoints,
            totalPoints: standing.score,
            setLabel: "basket", offPageLabel: "wild"
        )
        var body = buildShareText(share, timeZone: utc).lowercased()
        for chrome in [share.title, share.tierLabel, share.setLabel, share.offPageLabel] {
            body = body.replacingOccurrences(of: chrome.lowercased(), with: "")
        }
        #expect(!body.contains(puzzle.sourceWord))
        // And no other word from the rack either, which catches a leak that
        // happened to print a found word rather than the answer.
        for word in puzzle.validationWords where word.count >= 4 {
            #expect(!body.contains(word), "leaked \(word)")
        }
    }
}
