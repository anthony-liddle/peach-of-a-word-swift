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

    // MARK: - How the words work

    /// The explainer's title. Sentence case, matching the colophon's trigger
    /// and the app's other headings. The web's dialog title is title case while
    /// its own trigger is sentence case, which is an inconsistency there rather
    /// than a style to carry over.
    static let explainerTitle = "How the words work"

    /// The colophon's quiet way in.
    static let explainerTrigger = "How the words work"

    /// The explainer body, ported from the web's `HowItWorks.tsx`.
    ///
    /// **Substituted rather than copied, and the noun is the reason.** The web's
    /// body is not themed at all: there is no `themeCopy.ts` entry for it, and
    /// it says "the day's set" and "outside the set" in both themes. This app
    /// never says set to a player. Its word for that collection is the
    /// `container` above, so the paragraphs are built from it and the
    /// substitution is one value rather than a dozen edits, which is why the
    /// noun lives in this file at all.
    ///
    /// Nothing else is reworded. The rung names carry over untouched, since
    /// Uncommon, Rare and Mythic are shared vocabulary.
    ///
    /// **The number is 427,000 and the web's 430,000 is wrong.** Both surfaces
    /// ship `boundary: 426900` in `meta.json`. Hardcoded rather than read from
    /// that file: an approximate number that is right beats a live number that
    /// couples a sentence of prose to a data file, and this sentence only ever
    /// wanted a sense of scale.
    ///
    /// The claims here are load-bearing and are asserted by
    /// `ExplainerClaimsTests`. The web pins the same ones in
    /// `HowItWorks.test.tsx`, on the model rather than the wording.
    static let explainerParagraphs: [String] = [
        "Every puzzle is built from two word lists doing different jobs.",

        "ENABLE and SCOWL, together with a small patch list we keep by hand, "
        + "decide what counts as a word: about 427,000 of them. Almost anything "
        + "real you type is accepted. You will rarely be told a real word is "
        + "not a word.",

        "SCOWL also sorts those words into bands by how common they are, from "
        + "everyday to obscure. The common band makes up the day's \(container), "
        + "and the bands past it decide how rare everything else is.",

        "The day's eight letters come from a common eight-letter word, chosen "
        + "and checked ahead of time, and the same for everyone that day. The "
        + "\(container) is every common word those letters can spell.",

        "The goal is a ladder of named ranks, climbed by points. Every valid "
        + "word moves you up, and rarer words move you further. Above the "
        + "ladder sits completion: finding every common word the letters can "
        + "spell. It is reachable, rare, and never required for a day to feel "
        + "good.",

        "Words you find beyond the \(container) are graded by how far past "
        + "common they sit: Uncommon, then Rare, then Mythic, the deeper into "
        + "the dictionary you go. They all score. They are not lesser, they are "
        + "extra.",

        "A word can feel common to you and still land outside the "
        + "\(container). That is not your instinct being wrong. Common here is "
        + "a statistical line drawn across a word list, and a statistical line "
        + "does not always agree with a real person's vocabulary. A word you "
        + "use every week can sit just outside the band. When that happens, you "
        + "still found a real word. It simply was not on today's short list.",
    ]

    /// The two lists the explainer names, and where to read about them.
    ///
    /// **These links carry no licence obligation.** The attribution is already
    /// discharged twice over: the colophon credits ENABLE and SCOWL on screen,
    /// and `Data/ATTRIBUTION.md` ships inside the bundle carrying the notices.
    /// These are here because they are interesting. Keeping that straight
    /// matters, because an explainer that quietly becomes a second attribution
    /// surface is one that can drift from the first without anyone noticing.
    static let explainerLinks: [(name: String, url: String)] = [
        ("ENABLE",
         "https://www.bananagrammer.com/2013/12/the-amazing-enable-word-list-project.html"),
        // Classic SCOWL (v1), not its renamed successor ESDB. The homepage now
        // leads with ESDB, but this game uses v1: Mythic is defined as valid in
        // ENABLE and beyond SCOWL size 95, and ESDB dropped the size 95 level.
        // Same link and the same reason as the web's.
        ("SCOWL", "https://wordlist.aspell.net/scowl_v1-readme/"),
    ]

    /// The found list's heading, mirroring the web's `glossaryTitle`.
    ///
    /// The app had no heading at all, which is one of the three ways Bea
    /// noticed the list not matching the web. Built from `container` like the
    /// rest, so the noun stays swappable in one place.
    static let glossaryTitle = "The \(container)"

    /// The kicker above the word on the source-word reveal card.
    static let revealKicker = "The peach every word grew from"

    /// The way back to the board, from a card the board presented.
    static let revealClose = "Back to the \(container)"

    /// The way back to a rung's list, from a definition opened inside it.
    ///
    /// **Named rather than generic.** A bare "Back" is the obvious fix and it
    /// is system language in a game that deliberately does not speak it.
    /// Naming the rung is both truthful and in voice.
    ///
    /// The rung names are shared vocabulary rather than cute inventions, so
    /// they are passed in rather than listed again here; `FoundSummary` owns
    /// the list of them.
    static func closeToRung(_ name: String) -> String { "Back to \(name)" }

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
