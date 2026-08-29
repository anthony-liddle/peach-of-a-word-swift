import Foundation

/// The cute theme's vocabulary, in one place.
///
/// Ported from the web's `src/ui/themeCopy.ts`, and the reason it exists is the
/// same. The web keeps every skinned string in one module because a literal
/// spelled out in a component renders identically under both themes and no
/// per-theme test can catch it. This app ships one theme, so the failure mode is
/// different but not smaller: a string written straight into a view is a string
/// nobody compares against the theme, and four of them drifted into
/// placeholder-generic without anyone deciding to.
///
/// **The basket is the point.** Four strings were wrong in the same way and the
/// common thread was a noun that had never been carried over at all. Fixing the
/// four would have fixed four; putting the noun here fixes the class, because
/// the fifth string now has somewhere to come from. The web says the same thing
/// at `themeCopy.ts:100` and for the same reason: changing basket to crate is
/// one line, and it has to be the same word in every place at once.
///
/// Strings carrying no metaphor stay out, deliberately, exactly as the web
/// leaves out SHUFFLE, CLEAR and the rejection messages. Skinning those would
/// double the surface to maintain for nothing.
enum Vocabulary {

    // MARK: - The container noun

    /// What words are picked into.
    ///
    /// Six strings below are built from this, so swapping it for "crate" is
    /// this line. Basket reads hand-picked; crate reads like a harvest haul.
    /// Whichever it is, it has to be the same word everywhere, which is why
    /// none of the strings below spell it out.
    static let container = "basket"

    /// Sentence-case form, for where the noun starts a phrase.
    static var containerCapitalized: String {
        container.prefix(1).uppercased() + container.dropFirst()
    }

    /// The two halves of the score, as the share's points line names them.
    ///
    /// Mirrors the web's `onPageLabel` and `offPageLabel`, which label the same
    /// two colours under its meter. Capitalised here as they are there, and
    /// lowercased by the share where they sit inside a sentence, so the two
    /// repos keep one pair of words rather than two.
    ///
    /// "Wild" is the web's word for words growing outside the cultivated set,
    /// and is the least literal substitution in the cute vocabulary.
    static let onPageLabel = containerCapitalized
    static let offPageLabel = "Wild"

    // MARK: - The strings

    /// Under the masthead, and on the splash: what you do here.
    static let mastheadSubline = "Pick the peaches"

    /// Held on screen while the word lists load, before the board exists. The
    /// subline in the continuous present: the app is doing the thing it is
    /// about to invite you to do.
    static let loadingLine = "Picking the peaches."

    /// The submit control. Uppercased by the view, so it is sentence case here.
    static let submitWord = "Pick word"

    /// The composing well before a letter is picked.
    static let inputPlaceholder = "Pick letters to make a word"

    /// The found list with nothing in it yet.
    ///
    /// **The metaphor inverts, and this is not a translation error.** The web's
    /// letterpress skin says "No words set yet. The case is full", because type
    /// not yet set is still sitting in its compartments. Fruit runs the other
    /// way: it leaves the tree and goes into the basket, so an empty basket is
    /// the state a full case describes. The web documents this at
    /// `themeCopy.ts:185` and calls it mirrored rather than translated.
    static let emptyFoundList = "No words picked yet. The \(container) is empty."

    /// The found list's heading, mirroring the web's `glossaryTitle`.
    ///
    /// The app had no heading at all, which is one of the three ways Bea
    /// noticed the list not matching the web. Built from `container` like the
    /// rest, so the noun stays swappable in one place.
    static let glossaryTitle = "The \(container)"

    /// The kicker above the word on the source-word reveal card.
    static let revealKicker = "The peach every word grew from"

    /// The reveal card's way back to the board.
    static let revealClose = "Back to the \(container)"

    /// Shown in place of the next rank once the ladder is topped out.
    ///
    /// **Deliberately not the web's sentence.** The web says "Top rank. The full
    /// basket is the peak." That is three characters longer than the string
    /// which already wrapped this row and pushed the board down mid-play, and
    /// the row carries the percentage and the streak as well. The reserved
    /// height added since means it would truncate instead of push, which is
    /// worse: a caption trailing off mid-sentence reads as broken, where a short
    /// one reads as deliberate.
    ///
    /// So the basket is carried and the restatement is dropped. Measured on a
    /// simulator at accessibility-XXXL, on a completed board, against the
    /// reserved height, rather than guessed:
    ///
    /// - "The full basket" truncated to "The full b..."
    /// - "Basket full" fits, and the row reads `100%  Basket full  1 day`
    ///
    /// The row competes with the percentage and the streak, both of which grow
    /// too, so the budget is smaller than the caption alone suggests.
    static let ladderPeak = "\(containerCapitalized) full"

    /// The completion card's one line.
    static let completionLine = "Every common word these letters can grow, picked."

    /// The visible line at the moment the eight-letter word lands. Cute makes
    /// the game's own joke: "a peach of a" is an old phrase for a fine example
    /// of a thing, which is exactly what the source word is in a rack.
    static let sourceFound = "You found the Peach of a Word!"

    /// The type credit, for the colophon. The typefaces differ per theme on the
    /// web as well as the verb; these are the cute pair.
    static let typeCredit = "Set in Fredoka and Nunito."

    /// The dedication, last line of the colophon.
    ///
    /// Four words, lowercase, no full stop, exactly as `Game.tsx` spells them.
    /// The title says what the game is to everyone; this says who it is for to
    /// the one person meant to notice it, which is why it is unornamented and
    /// why it is not on the play surface.
    ///
    /// It shipped on the web and not here, and she went looking for it. A
    /// dedication that exists in one place and not the other is worse than one
    /// that never existed, because its absence reads as a decision.
    static let dedication = "for Bea"

    // MARK: - The ladder

    /// The six named ranks, cute skin. The engine owns the ladder structure and
    /// these are a skin over the index, the same way the rarity marks swap.
    static let tierNames = [
        "First Sprout", "Little Bud", "Blossom", "Ripening", "Sweet", "Perfectly Peachy",
    ]

    /// The rank above the six, reached by finding every set word rather than by
    /// points.
    static let crownName = "Peachy Keen Supreme"
}

/// Counted nouns, in one place.
///
/// Written after a find reported "toy, 1 points". The bug was trivial; the
/// reason it existed is that six different strings each did their own
/// pluralising and only some of them remembered. Every counted noun in the app
/// now goes through here, including the ones that cannot currently be one,
/// because "cannot currently be one" is exactly the assumption that rots.
func counted(_ n: Int, _ singular: String, plural: String? = nil) -> String {
    "\(n) \(n == 1 ? singular : (plural ?? singular + "s"))"
}
