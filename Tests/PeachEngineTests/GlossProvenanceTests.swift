import Foundation
import Testing
@testable import PeachEngine

/// Which credit line a card carries, and why it is decided per word.
///
/// Three surfaces credited Wiktionary for every gloss. For the 38 words whose
/// definition was written for this project that is false, and they are the
/// words a player is most likely to read: the odd ones that got curated by hand
/// in the first place.
///
/// **The provenance file is the only thing that knows.** A project gloss is not
/// detectable from the text: it carries the same `noun. ` shaping as every
/// other row, because `shapeSense` runs over both. Nothing about the string
/// says who wrote it, which is exactly why orchard ships a sidecar naming them.
@Suite("a gloss is credited to whoever wrote it")
struct GlossProvenanceTests {
    private let sample = GlossProvenance(projectWords: ["tulpa", "eighteen"])

    @Test("a project word's card does not credit Wiktionary")
    func projectWordIsNotWiktionary() {
        let line = sample.credit(for: "tulpa", includingEtymology: false)
        #expect(!line.contains("Wiktionary"))
        #expect(line == "Written for this game.")
    }

    @Test("a Wiktionary word's card still credits Wiktionary")
    func wiktionaryWordStillSaysSo() {
        let line = sample.credit(for: "denote", includingEtymology: false)
        #expect(line == "Definition from Wiktionary, CC BY-SA 4.0.")
    }

    /// `eighteen` and `fourteen` are the only two words that are both a project
    /// gloss and a calendar crown with an etymology, so this is a card a player
    /// opens on two days of the cycle rather than a hypothesis. The definition
    /// is ours and the etymology is Wiktionary's, and the line has to say both
    /// without becoming two lines: on a phone a second credit row costs more
    /// height than the distinction is worth.
    @Test("a crown whose definition is ours splits the claim in one sentence")
    func crownSplitsTheClaim() {
        let line = sample.credit(for: "eighteen", includingEtymology: true)
        #expect(
            line == "Definition written for this game. "
                + "Etymology from Wiktionary, CC BY-SA 4.0."
        )
        #expect(!line.contains("\n"))
    }

    @Test("a crown from Wiktionary credits both together")
    func crownFromWiktionary() {
        let line = sample.credit(for: "peaches", includingEtymology: true)
        #expect(line == "Definition and etymology from Wiktionary, CC BY-SA 4.0.")
    }

    /// The corpus is lowercase and a card may ask with whatever case the board
    /// dealt, so the lookup folds rather than trusting the caller.
    @Test("the lookup does not depend on the caller's casing")
    func lookupFoldsCase() {
        #expect(sample.isProject("TULPA"))
        #expect(sample.isProject("Tulpa"))
    }

    @Test("a blank line and a comment are not words")
    func parserIgnoresNonRows() {
        let parsed = parseGlossProvenance(
            "# a comment\n\ntulpa\tproject\ndenote\twiktionary\n"
        )
        #expect(parsed == ["tulpa"])
    }
}

/// The shipped sidecar, against the corpus it describes.
@Suite(
    "the shipped gloss provenance",
    .enabled(
        if: !readGlossProvenance().isEmpty,
        "Data/\(glossProvenanceFileName) is not committed"
    )
)
struct ShippedGlossProvenanceTests {
    /// **38 at orchard v1.7.0**, the glosses rewritten on 2026-09-24 to carry
    /// this project's own words rather than text with another dictionary's
    /// apparatus in it. Pinned so a release that changes the number gets looked
    /// at rather than inherited.
    ///
    /// **40 at orchard v1.8.0**: fagot and sulla, whose shipped glosses had
    /// been a denied spelling and a slur sense, were given curated rows
    /// carrying only their ordinary sense.
    @Test("names the 40 words whose gloss is this project's own")
    func namesTheForty() {
        #expect(readGlossProvenance().count == 40)
    }

    /// Every named word has to be IN the corpus, or the sidecar is crediting
    /// something that does not ship and some row is silently still credited to
    /// Wiktionary.
    @Test("every named word has a row in the definition corpus")
    func namedWordsAreInTheCorpus() {
        let definitions = readDefinitions()
        let missing = readGlossProvenance().filter { definitions[$0] == nil }
        #expect(missing.isEmpty, "not in definitions.tsv: \(missing.sorted())")
    }

    /// The two that are also crowns. Their row is split down the middle: the
    /// definition column is this project's and the etymology column is
    /// Wiktionary's, which is the case `crownSplitsTheClaim` covers.
    @Test("eighteen and fourteen are the project words that also have etymology")
    func theTwoSplitRows() {
        let entries = readSourceEntries()
        let both = readGlossProvenance()
            .filter { entries[$0]?.etymology.isEmpty == false }
        #expect(both.sorted() == ["eighteen", "fourteen"])
    }
}
