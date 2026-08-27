import Foundation

/// The gloss corpus behind the tappable found-word chips.
///
/// **A separate parser from `parseSourceEntries`, deliberately, and the
/// duplication is the cheaper mistake.** The two files are both TSV keyed on a
/// word and they are not the same shape: this one is `word\tdefinition`, two
/// columns; `etymology.tsv` is `word\tetymology\tdefinition`, three columns in
/// an order that is the reverse of the card's reading order. That reversal has
/// its own guard test because getting it wrong produces a card that renders
/// perfectly and says the wrong thing under each heading.
///
/// One parser taking a column count would put those two orders behind a
/// parameter, which is precisely the shape in which they get confused. Two
/// functions of eight lines each cannot be.
public let definitionsFileName = "definitions.tsv"

/// Parse orchard's definition corpus into word to gloss.
///
/// `maxSplits: 1` rather than an unbounded split: a gloss may legitimately
/// contain a tab, and a row is two fields by definition rather than by counting
/// what turned up. Without the cap a tabbed gloss would be read as a malformed
/// three-field row and the word would silently lose its definition.
///
/// `omittingEmptySubsequences: false` for the same reason `parseSourceEntries`
/// carries it: with the default, a row whose gloss is empty yields one field
/// instead of two and is rejected by the count guard as though it were
/// malformed. Rejecting it is in fact the intent, but it should be this
/// function's decision rather than a split option's side effect.
///
/// **An empty gloss is dropped rather than stored.** A word mapped to an empty
/// string would open a card with a heading and nothing under it, which reads as
/// broken. Dropped, it takes the miss line instead, which reads as honest. The
/// corpus has no such row today; the guard is for the day it does, and that day
/// is not predictable from here.
public func parseDefinitions(_ tsv: String) -> [String: String] {
    var definitions: [String: String] = [:]
    for row in tsv.split(separator: "\n") {
        let fields = row.split(
            separator: "\t",
            maxSplits: 1,
            omittingEmptySubsequences: false
        )
        guard fields.count == 2, !fields[0].isEmpty, !fields[1].isEmpty else { continue }
        definitions[String(fields[0])] = String(fields[1])
    }
    return definitions
}

/// Read the definition corpus from a directory, or return nothing if it is
/// absent.
///
/// **Does not throw, and that contract is copied from `readSourceEntries` on
/// purpose rather than by habit.** The reasoning there was that a build
/// assembled without the data should start anyway, and it is the reason every
/// consumer of the reveal card could ship ahead of the corpus. The same holds
/// here and matters more: this file feeds a control the player taps, so the
/// failure mode of a `throws` would be a launch path that has to catch and
/// ignore an error to reach a board.
///
/// An empty table is a complete answer. Every word then takes the miss line,
/// which is a sentence the card is already built to render and which reads as
/// honest rather than as broken. The cost, accepted here as it is there, is
/// that a corpus present but unreadable is indistinguishable from one that is
/// absent; the consequence either way is the same card.
public func readDefinitions(
    _ name: String = definitionsFileName,
    in directory: URL = dataDirectory
) -> [String: String] {
    guard let text = try? String(
        contentsOf: directory.appendingPathComponent(name),
        encoding: .utf8
    ) else {
        return [:]
    }
    return parseDefinitions(text)
}
