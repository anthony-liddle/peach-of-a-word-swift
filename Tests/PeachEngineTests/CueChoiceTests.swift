import Testing
@testable import PeachEngine

/// Which cue a submit plays, with the web's precedence.
///
/// **Checked against the web by reading it line for line**, `useGame.ts`
/// `submit` (lines 671 to 691 on `main` at `5584eb7`) and
/// `SoundscapeAudioEngine.ts` `playFound` (40 to 46):
///
/// - 675 to 677: any rejection plays `invalid` and stops there, before
///   completion is looked at.
/// - 681 to 686: a find that takes the basket from not complete to complete
///   plays `edition`, whatever else it is.
/// - 689: otherwise the source word plays `source`.
/// - 690: otherwise `found-<length>-<rung>`, with the length held to the
///   file's 3 to 8 and a mythic find naming its theme (41 to 44).
///
/// Each row below is one of those branches, in the web's terms, so the rows
/// could be lifted into a table the web's tests read too. They are not shared
/// today: the web repository was read, not changed, in this pass.
///
/// **Where the two could drift is the completion fact, not this function.**
/// The web works it out from counts on the board in memory, before and after
/// this find. The app passes `completesBasket` from `resolve()`: complete after
/// the find, and not celebrated yet, where "celebrated" survives a past day
/// whose words were pruned and then found again. On that board the web would
/// play `edition` a second time and the app plays the find's own cue. That is
/// the haptic's rule since pass 1, and the cards'.
@Suite("the cue a submit plays")
struct CueChoiceTests {
    static func found(_ length: Int, _ rung: Rung = .set, source: Bool = false) -> GuessResult {
        .valid(word: String(repeating: "e", count: length), score: 1, rung: rung, isSourceWord: source)
    }

    struct Row: CustomTestStringConvertible, Sendable {
        let moment: String
        let result: GuessResult
        let completesBasket: Bool
        let cue: String
        var testDescription: String { moment }
    }

    static let rows: [Row] = [
        // 690: a word found, at each rung
        Row(moment: "a set find", result: found(5), completesBasket: false, cue: "found-5-set"),
        Row(moment: "an uncommon find", result: found(4, .uncommon), completesBasket: false, cue: "found-4-uncommon"),
        Row(moment: "a rare find", result: found(6, .rare), completesBasket: false, cue: "found-6-rare"),
        // 43: a mythic find names the theme, and the app's is cute
        Row(moment: "a mythic find", result: found(7, .mythic), completesBasket: false, cue: "found-7-mythic-cute"),
        // 41: the length held to the file's 3 to 8, at both ends
        Row(moment: "a find shorter than 3", result: found(2), completesBasket: false, cue: "found-3-set"),
        Row(moment: "a find of no letters", result: found(0, .rare), completesBasket: false, cue: "found-3-rare"),
        Row(moment: "a mythic find shorter than 3", result: found(1, .mythic), completesBasket: false, cue: "found-3-mythic-cute"),
        Row(moment: "a find longer than 8", result: found(9), completesBasket: false, cue: "found-8-set"),
        Row(moment: "a mythic find longer than 8", result: found(12, .mythic), completesBasket: false, cue: "found-8-mythic-cute"),
        // 689: the source word
        Row(moment: "the source word", result: found(8, source: true), completesBasket: false, cue: "source"),
        // 685 to 686: completion replaces the find's cue, and the source word's
        Row(moment: "a find completing the basket", result: found(4), completesBasket: true, cue: "edition"),
        Row(moment: "the source word completing the basket", result: found(8, source: true), completesBasket: true, cue: "edition"),
        // 675 to 677: each rejection, before completion is looked at
        Row(moment: "too short", result: .tooShort, completesBasket: false, cue: "invalid"),
        Row(moment: "not a word", result: .notAWord, completesBasket: false, cue: "invalid"),
        Row(moment: "already found", result: .alreadyFound, completesBasket: false, cue: "invalid"),
        Row(moment: "a rejection, told it completes", result: .notAWord, completesBasket: true, cue: "invalid"),
    ]

    @Test("plays the web's cue", arguments: rows)
    func row(_ row: Row) {
        #expect(cue(for: row.result, completesBasket: row.completesBasket).name == row.cue)
    }

    /// Every length the file has, at every rung, so no length is a special
    /// case by accident.
    @Test("plays each length's own cue, 3 to 8, at each rung")
    func everyLength() {
        for length in Cue.foundLengths {
            for rung in Rung.allCases {
                let theme = rung == .mythic ? "mythic-cute" : rung.rawValue
                #expect(cue(for: Self.found(length, rung), completesBasket: false).name
                    == "found-\(length)-\(theme)")
            }
        }
    }

    /// The haptic and the sound read one precedence, so they cannot disagree
    /// about which beat a find was: the sound is `findBeat`'s, named.
    @Test("follows the haptic's beat for every find")
    func followsTheBeat() {
        for source in [false, true] {
            for completes in [false, true] {
                let beat = findBeat(isSourceWord: source, completesBasket: completes)
                let name = cue(for: Self.found(5, source: source), completesBasket: completes).name
                switch beat {
                case .completion: #expect(name == "edition")
                case .sourceWord: #expect(name == "source")
                case .find: #expect(name == "found-5-set")
                }
            }
        }
    }

    /// A tile placed plays `tick`; the app plays it beside the tile's haptic,
    /// in `addTile`. The table's rows that play nothing, a used tile, delete,
    /// clear and shuffle, are the app's: it asks for no cue there, which
    /// `CueAtEachMoment` checks in the UI tests.
    @Test("a tile placed plays tick")
    func tick() {
        #expect(Cue.tick.name == "tick")
    }
}
