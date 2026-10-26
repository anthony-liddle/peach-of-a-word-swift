import Testing
@testable import PeachEngine

/// A find's line in the well: the mark that leads it, what it shows, and what
/// VoiceOver says, all from one value.
@Suite("the well's line")
struct WellLineTests {

    /// The shared parity fixture: finds on 24 October 2026's board, `literary`.
    ///
    /// **These exact inputs and lines are also `FIXTURE` in the web's
    /// `src/ui/wellLine.test.ts`.** Change one and change the other, or the
    /// two platforms' lines can drift apart with both suites still green.
    /// The spoken form here is the find alone: the web adds " New rank." or
    /// the completion line after it, which this app says elsewhere.
    static let fixture: [(word: String, points: Int, rung: Rung,
                          mark: Rung?, shown: String, spoken: String)] = [
        ("tel", 5, .mythic, .mythic, "tel, 5 points", "Mythic find: tel, 5 points."),
        ("relit", 9, .mythic, .mythic, "relit, 9 points", "Mythic find: relit, 9 points."),
        ("aret", 5, .rare, .rare, "aret, 5 points", "Rare find: aret, 5 points."),
        ("airt", 4, .uncommon, .uncommon, "airt, 4 points", "Uncommon find: airt, 4 points."),
        ("early", 5, .set, nil, "early, 5 points", "early, 5 points."),
        ("lay", 1, .set, nil, "lay, 1 point", "lay, 1 point."),
    ]

    @Test("matches the web's lines, character for character, on the same finds")
    func matchesTheWeb() {
        for find in Self.fixture {
            let line = WellLine(find: find.word, points: find.points, rung: find.rung)
            #expect(line.mark == find.mark, "\(find.word)")
            #expect(line.shown == find.shown, "\(find.word)")
            #expect(line.spoken == find.spoken, "\(find.word)")
        }
    }

    @Test("an Uncommon, Rare or Mythic find leads with its own mark",
          arguments: [Rung.uncommon, .rare, .mythic])
    func offPageLeadsWithItsMark(rung: Rung) {
        let line = WellLine(find: "tel", points: 5, rung: rung)
        #expect(line.mark == rung)
        #expect(line.shown == "tel, 5 points")
    }

    @Test("a word in the basket has no mark")
    func basketHasNoMark() {
        #expect(WellLine(find: "lay", points: 1, rung: .set).mark == nil)
    }

    /// A mark read aloud says nothing useful, so the rarity is said in words.
    @Test("the spoken form names the rarity in words",
          arguments: zip([Rung.uncommon, .rare, .mythic], ["Uncommon", "Rare", "Mythic"]))
    func spokenNamesTheRarity(rung: Rung, name: String) {
        #expect(WellLine(find: "tel", points: 5, rung: rung).spoken
                == "\(name) find: tel, 5 points.")
    }

    /// The source word's line and every rejection say one thing to the eye
    /// and the ear, as they always have, and carry no mark.
    @Test("a plain line shows and says the same text, with no mark")
    func plainLine() {
        let line = WellLine(plain: "Already found. Keep going.")
        #expect(line.mark == nil)
        #expect(line.shown == "Already found. Keep going.")
        #expect(line.spoken == "Already found. Keep going.")
    }
}
