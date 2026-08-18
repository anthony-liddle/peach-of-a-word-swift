import Foundation

/// The daily share block.
///
/// A pure function over a value that **has no source word in it**. The web
/// guarantees spoiler safety with a discriminated union whose daily case has no
/// source-word affordance; this is the same guarantee by the same means. The
/// answer cannot leak into a daily share because there is nothing here to leak
/// it from, and `ShareTextTests` proves it against the real puzzle.
///
/// It lives in the engine rather than the app so those tests can run under
/// `swift test`, which is the same reasoning that put `GameStorage` here.
public struct DailyShareResult: Sendable {
    /// The app's display name.
    public let title: String
    /// The puzzle's date, shown short so a group compares the same rack.
    public let date: Date
    /// The earned headline: the completion crown once every set word is found,
    /// otherwise the current named rank. Passed in, because the names are a
    /// theme skin the engine deliberately does not own.
    public let tierLabel: String
    public let setFound: Int
    public let setTotal: Int
    public let uncommon: Int
    public let rare: Int
    public let mythic: Int
    public let setPoints: Int
    public let offPagePoints: Int
    public let totalPoints: Int
    /// What the two halves of the score are called, on the points line.
    ///
    /// Theme vocabulary, passed in for the same reason `tierLabel` is: the
    /// engine does not own skinned words. The web ships letterpress as well as
    /// cute, and the container noun is the case there and the basket here, so a
    /// label spelled out in this file would put one theme's word in the other
    /// theme's share. Lowercase, because they sit inside a sentence.
    public let setLabel: String
    public let offPageLabel: String

    public init(
        title: String, date: Date, tierLabel: String,
        setFound: Int, setTotal: Int,
        uncommon: Int, rare: Int, mythic: Int,
        setPoints: Int, offPagePoints: Int, totalPoints: Int,
        setLabel: String, offPageLabel: String
    ) {
        self.title = title
        self.date = date
        self.tierLabel = tierLabel
        self.setFound = setFound
        self.setTotal = setTotal
        self.uncommon = uncommon
        self.rare = rare
        self.mythic = mythic
        self.setPoints = setPoints
        self.offPagePoints = offPagePoints
        self.totalPoints = totalPoints
        self.setLabel = setLabel
        self.offPageLabel = offPageLabel
    }
}

private let setSquare = "\u{1F7E5}"       // red
private let offPageSquare = "\u{1F7EA}"   // purple
/// Fixed width, the way Wordle's grid is fixed, so the row reads at a glance.
private let scoreRowWidth = 10

private let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

/// Short calendar date, "Aug 9", from the date's local components.
private func shortDate(_ date: Date, timeZone: TimeZone) -> String {
    var cal = Foundation.Calendar(identifier: .gregorian)
    cal.timeZone = timeZone
    let c = cal.dateComponents([.month, .day], from: date)
    return "\(months[(c.month ?? 1) - 1]) \(c.day ?? 1)"
}

/// The score-composition row: the two-tone bar rendered as squares.
///
/// Always the fixed width, split by points. Rounded to nearest, but a real haul
/// must never round away to nothing, so a non-zero off-page total guarantees at
/// least one purple square and a non-zero set total at least one red.
private func scoreRow(setPoints: Int, offPagePoints: Int) -> String {
    let total = setPoints + offPagePoints
    var purple = total == 0
        ? 0
        : Int((Double(offPagePoints) / Double(total) * Double(scoreRowWidth)).rounded())
    if offPagePoints > 0 && purple == 0 { purple = 1 }
    if setPoints > 0 && purple == scoreRowWidth { purple = scoreRowWidth - 1 }
    let red = scoreRowWidth - purple
    return String(repeating: setSquare, count: red)
        + String(repeating: offPageSquare, count: purple)
}

/// The rarity line, naming only the rungs with at least one find.
///
/// **Counts, never denominators.** Advertising how many obscure words a rack
/// holds would turn open-ended discovery into a grind, and a share that did it
/// would spread that to everyone who read it.
private func rarityLine(uncommon: Int, rare: Int, mythic: Int) -> String? {
    var parts: [String] = []
    if uncommon > 0 { parts.append("\(uncommon) Uncommon") }
    if rare > 0 { parts.append("\(rare) Rare") }
    if mythic > 0 { parts.append("\(mythic) Mythic") }
    guard !parts.isEmpty else { return nil }
    return "\u{2726} " + parts.joined(separator: " \u{00B7} ")
}

/// The words line: the earned headline, the completion count, then how many
/// finds came from beyond the set.
///
/// The completion count keeps its "of", because it is a real fraction: the app
/// shows it from the first second of play, so a recipient learns nothing a
/// player would not see immediately. The off-page number is a count of finds and
/// never a denominator, for the same reason the rarity rungs never show one, so
/// it is added rather than divided and it is dropped entirely at zero.
///
/// It is derived from the rungs rather than passed alongside them, so the two
/// lines cannot disagree: `39 Uncommon · 26 Rare · 2 Mythic` is the same 67.
private func wordsLine(_ result: DailyShareResult) -> String {
    let offPageFound = result.uncommon + result.rare + result.mythic
    let base = "\(result.tierLabel) \u{00B7} \(result.setFound) of \(result.setTotal) words"
    return offPageFound > 0 ? base + " + \(offPageFound)" : base
}

/// The points line: the score row's split, written out, then the total.
///
/// **The labels are what make the slash safe.** A bare `99/388` reads as a
/// fraction, and the line above it contains a real one; naming the halves means
/// the slash can only be read as a divider. That was Bea's fix, and it is why
/// the labels are not decoration that can be dropped.
///
/// With no off-page points there is nothing to split, so the line degrades to
/// the single total it carried before, rather than spending two labels to say
/// zero. That happens on exactly the boards where the rarity line and the
/// off-page count drop too.
private func pointsLine(_ result: DailyShareResult) -> String {
    guard result.offPagePoints > 0 else { return "\(result.totalPoints) pts" }
    return "\(result.setPoints) \(result.setLabel)/\(result.offPagePoints) "
        + "\(result.offPageLabel) \u{00B7} \(result.totalPoints) total points"
}

/// Build the daily share block.
///
/// ```
/// 🍑 Peach of a Word · Aug 18
/// Peachy Keen Supreme · 33 of 33 words + 67
/// 🟥🟥🟪🟪🟪🟪🟪🟪🟪🟪
/// ✦ 39 Uncommon · 26 Rare · 2 Mythic
/// 99 basket/388 wild · 487 total points
/// ```
///
/// The two-tone split reaches the text because the squares alone could not
/// carry it: the row is quantised to ten, so a 99/388 board and a 100/387 board
/// draw the same picture. The numbers say which it was.
public func buildShareText(
    _ result: DailyShareResult,
    timeZone: TimeZone = .current
) -> String {
    var lines = [
        "\u{1F351} \(result.title) \u{00B7} \(shortDate(result.date, timeZone: timeZone))",
        wordsLine(result),
        scoreRow(setPoints: result.setPoints, offPagePoints: result.offPagePoints),
    ]
    if let rarity = rarityLine(uncommon: result.uncommon, rare: result.rare,
                               mythic: result.mythic) {
        lines.append(rarity)
    }
    lines.append(pointsLine(result))
    return lines.joined(separator: "\n")
}
