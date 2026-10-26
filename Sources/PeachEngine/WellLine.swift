/// A line in the well: the mark that leads it, what it shows, and what
/// VoiceOver says.
///
/// **One value for the eye and the ear,** so the two cannot drift. The shown
/// form leads an Uncommon, Rare or Mythic find with that rarity's mark, the
/// one the found list draws: `❖ tel, 5 points`. A mark read aloud says nothing
/// useful, so the spoken form names the rarity in words, the web's form:
/// "Mythic find: tel, 5 points." The announcement is never the shown form cut
/// short either: truncation is something a frame does to a drawing, and the
/// channel with no width should not inherit the width's problems.
///
/// The web builds the same lines in `src/ui/wellLine.ts`, and both repos hold
/// them to one fixture (`WellLineTests`).
public struct WellLine: Equatable, Sendable {
    /// The rarity whose mark leads the shown line. Nil for a word in the
    /// basket, and for every line that is not a find.
    public let mark: Rung?
    /// What the line shows after its mark, with no closing period.
    public let shown: String
    /// What a screen reader hears.
    public let spoken: String

    /// A line that says the same thing to the eye and the ear: the source
    /// word's, and every rejection.
    public init(plain text: String) {
        mark = nil
        shown = text
        spoken = text
    }

    /// A find's line, for any find but the source word.
    public init(find word: String, points: Int, rung: Rung) {
        let line = "\(word), \(counted(points, "point"))"
        mark = rung == .set ? nil : rung
        shown = line
        spoken = rung.findName.map { "\($0) find: \(line)." } ?? "\(line)."
    }
}

extension Rung {
    /// The rarity's name, as the found list's sheets and key print it. Nil for
    /// the basket, which is the goal and carries no rarity. The web's
    /// `RUNG_NAMES`.
    var findName: String? {
        switch self {
        case .set: nil
        case .uncommon: "Uncommon"
        case .rare: "Rare"
        case .mythic: "Mythic"
        }
    }
}

/// Counted nouns, in one place.
///
/// Written after a find reported "toy, 1 points". The bug was trivial; the
/// reason it existed is that six different strings each did their own
/// pluralising and only some of them remembered. Every counted noun in the app
/// now goes through here, including the ones that cannot currently be one,
/// because "cannot currently be one" is exactly the assumption that rots.
///
/// In the engine since the well's line moved here, so the app and the line
/// share it rather than each keeping a copy.
public func counted(_ n: Int, _ singular: String, plural: String? = nil) -> String {
    "\(n) \(n == 1 ? singular : (plural ?? singular + "s"))"
}
