import Foundation

/// What the reveal card shows for a crown, once there is anything to show.
///
/// Named and shaped to match the web's `SourceEntry` in `src/data/types.ts`,
/// because both render the same two sections from the same corpus and a second
/// vocabulary for one concept is how the two cards drift apart.
///
/// Both fields are non-optional and may be empty. The card renders each section
/// only when its field is non-empty, which is what `Reveal.tsx` does, so an
/// empty string and a missing field mean the same thing at the point of use and
/// there is nothing for an `Optional` to distinguish.
public struct SourceEntry: Sendable, Equatable {
    /// The gloss. "noun. The nocturnal, insectivorous, burrowing mammal..."
    public let definition: String
    /// The origin, as prose. "Borrowed from Afrikaans aardvark..."
    public let etymology: String

    public init(definition: String, etymology: String) {
        self.definition = definition
        self.etymology = etymology
    }
}

/// The corpus filename, as orchard publishes it inside `etymology.tar.gz`.
public let sourceEntriesFileName = "etymology.tsv"

/// Parse orchard's reveal corpus.
///
/// **The column order is word, etymology, definition.** That is the order the
/// file is published in, and it is the reverse of the card's reading order and
/// of `SourceEntry`'s own field order. Reversing it by accident produces a card
/// that renders perfectly and says the wrong thing under each heading, which is
/// the kind of defect that ships. `SourceEntriesTests.columnOrder` is the guard.
///
/// `omittingEmptySubsequences: false` on the field split is load-bearing rather
/// than defensive. With the default, a row whose definition is empty yields two
/// fields instead of three, the row is read as malformed, and a word silently
/// loses its etymology as well. The row count guard below then does the
/// rejecting, deliberately, rather than a split option doing it invisibly.
public func parseSourceEntries(_ tsv: String) -> [String: SourceEntry] {
    var entries: [String: SourceEntry] = [:]
    for row in tsv.split(separator: "\n") {
        let fields = row.split(
            separator: "\t",
            maxSplits: 2,
            omittingEmptySubsequences: false
        )
        guard fields.count == 3, !fields[0].isEmpty else { continue }
        entries[String(fields[0])] = SourceEntry(
            definition: String(fields[2]),
            etymology: String(fields[1])
        )
    }
    return entries
}

/// Read the reveal corpus from a directory, or return nothing if it is absent.
///
/// **Absent is the normal state, not an error, and that is the whole point of
/// this signature.** The corpus is Wiktionary text under CC BY-SA 4.0 and is
/// not committed to this repository; the decision about whether it ever will be
/// is open. Everything that consumes it is committed and tested, so the machine
/// is finished and the content is a separate act.
///
/// So this does not `throw`. A `throws` here would put the licensing decision
/// on the app's launch path: the day the file is absent, which is today, the
/// game would have to catch and ignore an error to start. Returning an empty
/// table says the same thing without pretending something went wrong, and the
/// card's own empty-entry fallback then does the rest.
///
/// The cost is that a corpus which is present but unreadable is indistinguishable
/// from one that is absent. That is accepted: the only consequence either way is
/// a reveal card with no content, which is exactly what ships today.
public func readSourceEntries(
    _ name: String = sourceEntriesFileName,
    in directory: URL = dataDirectory
) -> [String: SourceEntry] {
    guard let text = try? String(
        contentsOf: directory.appendingPathComponent(name),
        encoding: .utf8
    ) else {
        return [:]
    }
    return parseSourceEntries(text)
}
