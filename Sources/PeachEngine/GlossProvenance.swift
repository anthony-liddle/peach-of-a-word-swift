import Foundation

/// Which glosses this project wrote, so a card can credit the right author.
///
/// **A separate parser again, for the reason `Definitions.swift` spells out.**
/// This file is `word\tprovenance`, and unlike the other two its second column
/// is not text to show anyone: it is a label to compare against. Folding it
/// into `parseDefinitions` would put a gloss and a label behind one return type
/// and invite a card to render the word `project` under a heading.
public let glossProvenanceFileName = "gloss-provenance.tsv"

/// The words whose gloss was written for this project rather than derived from
/// Wiktionary.
///
/// **Stated as an exclusion, and the file is written that way too.** orchard
/// emits only the rows that are not Wiktionary's, because that set is small and
/// named, where the complement is 24,858 rows that would have to be kept in
/// step with the corpus forever. A word absent from this set is credited to
/// Wiktionary, which is the safe direction to be wrong in: an unrecorded row
/// gets attributed rather than quietly claimed.
public struct GlossProvenance: Sendable, Equatable {
    public let projectWords: Set<String>

    public init(projectWords: Set<String>) {
        self.projectWords = Set(projectWords.map { $0.lowercased() })
    }

    /// Whether this project wrote the gloss for `word`.
    ///
    /// Folds case because the corpus is lowercase and a caller holds whatever
    /// the board dealt. A crown arrives capitalised in some surfaces, and a
    /// lookup that missed on that would silently credit Wiktionary for text it
    /// did not write, which is the exact failure this type exists to stop.
    public func isProject(_ word: String) -> Bool {
        projectWords.contains(word.lowercased())
    }

    /// The attribution line for one card.
    ///
    /// **A project gloss owes nobody, so it carries no licence.** "Written for
    /// this game." and nothing else. Appending CC BY-SA to it would be worse
    /// than the line it replaces: it would put someone else's licence on this
    /// project's own words.
    ///
    /// **The split case is one sentence, not two lines.** `eighteen` and
    /// `fourteen` are project glosses that are also crowns, so their card shows
    /// our definition above Wiktionary's etymology and has to say so. It says
    /// it in one paragraph, because on a phone a second credit row costs more
    /// height under an already long card than the distinction is worth, and the
    /// distinction survives being read as one sentence.
    public func credit(for word: String, includingEtymology: Bool) -> String {
        let ours = isProject(word)
        guard includingEtymology else {
            return ours
                ? "Written for this game."
                : "Definition from Wiktionary, CC BY-SA 4.0."
        }
        return ours
            ? "Definition written for this game. "
                + "Etymology from Wiktionary, CC BY-SA 4.0."
            : "Definition and etymology from Wiktionary, CC BY-SA 4.0."
    }
}

/// Parse orchard's provenance sidecar into the set of project-written words.
///
/// Only rows whose second field is exactly `project` are kept. Any other value,
/// including `wiktionary` and `unrecorded`, means the row is not this project's
/// to claim, so it is left out and the word is credited to Wiktionary by
/// absence. A malformed row is skipped for the same reason: the fallback should
/// be to attribute, never to claim.
public func parseGlossProvenance(_ tsv: String) -> Set<String> {
    var words: Set<String> = []
    for row in tsv.split(separator: "\n") {
        guard !row.hasPrefix("#") else { continue }
        let fields = row.split(separator: "\t", omittingEmptySubsequences: false)
        guard fields.count == 2, !fields[0].isEmpty, fields[1] == "project" else {
            continue
        }
        words.insert(String(fields[0]).lowercased())
    }
    return words
}

/// Read the provenance sidecar, or return nothing if it is absent.
///
/// **Does not throw, matching `readDefinitions`, and the empty answer is safe
/// here in a way it is not there.** An absent file means no word is known to be
/// this project's, so every card falls back to crediting Wiktionary. That
/// under-claims our own 38 rows and over-credits nobody, which is the direction
/// an attribution failure should fall.
public func readGlossProvenance(
    _ name: String = glossProvenanceFileName,
    in directory: URL = dataDirectory
) -> Set<String> {
    guard let text = try? String(
        contentsOf: directory.appendingPathComponent(name),
        encoding: .utf8
    ) else {
        return []
    }
    return parseGlossProvenance(text)
}
