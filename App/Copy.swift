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

    /// The explainer's title, and Settings' row that opens it. Sentence case,
    /// matching the app's other headings. The web's dialog title is title case
    /// while its own trigger is sentence case, which is an inconsistency there
    /// rather than a style to carry over.
    static let explainerTitle = "How the words work"

    // MARK: - Privacy

    /// Settings' row for the privacy policy. It was also the colophon link's
    /// spoken name, until the colophon kept only the dedication.
    static let privacyLinkSpoken = "Privacy policy"

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
    /// discharged twice over: Licences credits ENABLE and SCOWL on screen, over
    /// SCOWL's notice, and `Data/ATTRIBUTION.md` ships inside the bundle
    /// carrying the notices.
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

    /// The legend's caption and the one label in it that carries the metaphor.
    ///
    /// The rung names are shared vocabulary and the source word is called the
    /// source word on both surfaces; only the set's own name is themed, which
    /// is why this is the single string here rather than five.
    static let legendCaption = "Key"
    static let keyInContainer = "in the \(container)"
    static let keySourceWord = "source word"

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
    ///
    /// **"Basket full" was untrue at the top of the ladder, so it is "Top rung"
    /// now.** The ladder tops out long before the basket does: on one board
    /// measured on 2026-09-27, at 16 of 36 basket words. "Basket full" there
    /// made a claim about the basket that the bar does not measure. The app
    /// already calls the ranks rungs, and "Top rung" is shorter than the string
    /// that fitted, so the budget above still holds. The web's sentence is true
    /// in both states because it names the peak rather than claiming it; this
    /// one cannot carry that much, so it says where the bar is and leaves the
    /// peak to `basketFull` and the completion card.
    static let ladderPeak = "Top rung"

    /// The same caption once the basket really is full: every set word found.
    /// True only then, so shown only then.
    static let basketFull = "\(containerCapitalized) full"

    // MARK: - The archive

    /// What the calendar of past boards is called, and the label on the control
    /// that opens it.
    ///
    /// Plain rather than themed. "Past days" says what it is at a glance and
    /// survives being read aloud by VoiceOver, where a cute noun would have to be
    /// decoded first. The basket vocabulary is for the thing you fill, not for
    /// the way back to a day you already filled.
    static let archiveTitle = "Past days"
    // Spoken as "Previous month, August 2026", so the button says where it goes
    // rather than which way it points.
    static let archivePreviousMonth = "Previous month"
    static let archiveNextMonth = "Next month"
    static let archiveNoEarlierMonth = "no earlier month"
    static let archiveNoLaterMonth = "no later month"

    /// The six states, as a player reads them. Also the VoiceOver text, so the
    /// screen and the announcement cannot say different things.
    /// An empty past day.
    ///
    /// **"Not played" claimed a fact the app does not have.** The empty cells on
    /// Bea's calendar are the days before her transferred run, and she may well
    /// have played every one of them on the web: the transfer carries two bits
    /// and only one survived. Saying "not played" about those is the same
    /// mistake as marking transferred days as lesser, from the other direction.
    ///
    /// The boards are still there and still playable, so this says the thing
    /// that is true of every empty cell regardless of what happened on the web.
    static let markNoRecord = "Still on the tree"
    static let markIncomplete = "Started"
    static let markCleared = "Finished"
    static let markBasket = "\(containerCapitalized) full"
    static let markNotYet = "Not yet"
    /// Said after the state, so "Finished, caught up later" reads as one phrase.
    static let markCaughtUpLater = "caught up later"
    /// Said of a day the streak's run establishes and nothing else does.
    ///
    /// **Not "played on the web", which is what this said and could not know.**
    /// The run expanded on first launch covers the transfer and every day played
    /// here since, and the record cannot tell them apart. This says the thing
    /// that is true of all of them.
    static let markFromStreak = "kept by your streak"
    static let markToday = "today"

    /// The way back from a past board.
    ///
    /// Text rather than an icon, because a date is information and this is the
    /// action, and the two sat as two calendar glyphs in the same row before:
    /// one beside the points and one beside the date, two affordances for one
    /// thing to do.
    static let backToToday = "Back to today"

    /// The completion card's one line.
    static let completionLine = "Every common word these letters can grow, picked."

    /// The visible line at the moment the eight-letter word lands. Cute makes
    /// the game's own joke: "a peach of a" is an old phrase for a fine example
    /// of a thing, which is exactly what the source word is in a rack.
    static let sourceFound = "You found the Peach of a Word!"

    /// The dedication, the colophon's one line since the credits moved to
    /// Licences. It was the colophon's last line before that.
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

    // MARK: - The title screen

    /// The title's button on a day not yet started.
    static let titlePlay = "Play"

    /// The title's button once today's board has words.
    static let titleContinue = "Continue"

    /// The title's button once today's basket is full.
    ///
    /// **"Continue" would not be true of it.** A full basket has nothing left
    /// to continue toward; the board stays playable for the words past it, and
    /// this says where the button goes rather than promising work left. The
    /// reveal card's way out says the same thing for the same place.
    static let titleBasketFull = revealClose

    /// The title's way to a past board it chooses.
    static let titleRandomDay = "A day at random"
    static let titleRandomDayHint = "Opens a past board, one not finished if there is one"

    /// The way back to the title, the chevron before the rank's name, spoken.
    ///
    /// **"Back to", and where.** A bare "Back" is system language this game
    /// does not speak, which `OneDefinitionCardTests` holds Copy to, and it
    /// caught a first draft of this. iOS names a back button's destination too:
    /// its label is the screen it returns to. The title screen's own name is
    /// the game's, "Peach of a Word", which would read as the app's name rather
    /// than as a way out, so the label says both, as "Back to today" and "Back
    /// to the basket" do. #93's peach was "Home", with this as its hint, and
    /// wore the day's costume; the chevron wears nothing.
    static let backToTitle = "Back to the title screen"

    /// The title's line under the button once the board is known: the rank, and
    /// the basket as the share block counts it.
    static func titleStanding(rank: String, found: Int, total: Int) -> String {
        "\(rank) \u{00B7} \(found) of \(total) words"
    }

    // MARK: - How to play

    static let howToPlayTitle = "How to play"

    /// What a player needs before the first tile, in the game's own words.
    ///
    /// **Every line checked against the game on 2026-10-21.** Two of the
    /// design pass's mocked lines were not true of every board: "One word
    /// uses all eight letters" fails on the 222 of 626 boards whose letters
    /// also spell another eight-letter word, and "read where it came from"
    /// fails on the 11 crowns with no etymology. The last line says what is
    /// true of all of them.
    static let howToPlayPick = "Tap letters to make a word of three letters or more, then pick it."
    static var howToPlayClimb: String {
        "Every word climbs the ladder, from \(tierNames[0]) to \(tierNames[tierNames.count - 1]). "
            + "Longer and rarer words climb faster."
    }
    static let howToPlayBasket = "The \(container) is every common word the letters can spell. "
        + "Rarer finds are Uncommon, Rare or Mythic."
    static let howToPlayPeach = "All eight letters come from one word, the peach of a word. "
        + "Find it to open its card: what it means and, most days, where it came from."

    // MARK: - Settings

    static let settingsTitle = "Settings"
    static let close = "Close"

    /// The sound switch's name, and the line under it.
    ///
    /// **The line is held to every cue the game plays,** not only to finds: a
    /// tile ticks as it lands, a find plays a note, and a word that is not one
    /// plays its own. The Ring/Silent sentence is the review notes' claim in
    /// the review notes' words.
    static let soundSwitch = "Sound"
    static let soundNote = "A tick for each letter, a note for each word, a sound for a miss. "
        + "The Ring/Silent switch silences them too."

    static let licencesTitle = "Licences"
    static let licencesNote = "The sound library, the word lists, the definitions and the typefaces."

    /// The privacy row's line, under its title. The colophon's link said it
    /// as "Privacy: your basket stays on your phone", standing alone.
    static let privacyNote = "Your \(container) stays on your phone."

    /// What the privacy row does, for VoiceOver. It said "Opens in Safari"
    /// while the row handed off to Safari; the page now opens inside the app,
    /// from the game's own site.
    static let privacyHint = "Opens the policy from the game's website"

    /// The Licences list's entries: a title, and a sentence on what each
    /// covers, which heads its page too.
    ///
    /// **Written for a player, not for the repository.** `Data/ATTRIBUTION.md`
    /// opens with its own history and stays the repository's record; the
    /// screen says what each notice is for and then shows it.
    ///
    /// **The credits are here since the colophon kept only the dedication,**
    /// in the colophon's words where it had them: the word lists' line, the
    /// Wiktionary line, which says the text is adapted and names its licence,
    /// whose address is on its page, and the typefaces' line.
    static let licenceSoundscapeTitle = "Soundscape"
    static let licenceSoundscape =
        "The library that plays the game's sounds, under the MIT licence."
    static let licenceNoticesTitle = "Code Soundscape adapts"
    static let licenceChromium = "Parts of Soundscape follow the design of Chromium's audio code, "
        + "and carry its seven notices: Chromium's own, four of Google's, Intel's, and Sun's "
        + "for the maths library fdlibm."
    static let licenceWordListsTitle = "The word lists"
    static let licenceWordLists = "Words from ENABLE and SCOWL, with a curated patch layer. "
        + "ENABLE is in the public domain; SCOWL's notice is on its page."
    static let licenceWiktionaryTitle = "Definitions and word histories"
    static let licenceWiktionary = "Etymologies and most definitions adapted from Wiktionary, "
        + "CC BY-SA 4.0. A few definitions were written for this game."
    static let licenceTypefacesTitle = "The typefaces"
    static let licenceTypefaces = "Set in Fredoka and Nunito, both under the SIL Open Font License."
    static let licenceFredokaTitle = "Fredoka"
    static let licenceFredoka = "The face of the tiles and the headings."
    static let licenceNunitoTitle = "Nunito"
    static let licenceNunito = "The face of everything else."

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
