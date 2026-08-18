import SwiftUI
import PeachEngine

/// The daily share, which travels with the summary row.
///
/// It moved out of `FoundListView` when the summary was pinned, because it has
/// always lived on that row and the row is now somewhere else. Its own file
/// rather than folded into `FoundSummary`, since building the share text is a
/// separate job from laying out a status line.
struct ShareSummaryButton: View {
    let puzzle: Puzzle
    let found: [String]
    let standing: TierStanding
    let boardDate: Date

    var body: some View {
        ShareLink(item: shareText) {
            Label("Share", systemImage: "square.and.arrow.up")
                .font(CuteFont.body(13, weight: "SemiBold", relativeTo: .footnote))
                .foregroundStyle(Cute.accent)
        }
        .accessibilityLabel("Share today's result")
    }

    /// Spoiler safe by construction: `DailyShareResult` has no source-word
    /// field, which `ShareTextTests` proves against the real puzzle.
    private var shareText: String {
        let words = classifyFound(found, in: puzzle)
        let complete = isComplete(standing)
        return buildShareText(DailyShareResult(
            title: "Peach of a Word",
            date: boardDate,
            tierLabel: complete
                ? Vocabulary.crownName
                : Vocabulary.tierNames[min(standing.index, Vocabulary.tierNames.count - 1)],
            setFound: standing.setFound,
            setTotal: standing.setTotal,
            uncommon: words.filter { $0.category == .uncommon }.count,
            rare: words.filter { $0.category == .rare }.count,
            mythic: words.filter { $0.category == .mythic }.count,
            setPoints: standing.setPoints,
            offPagePoints: standing.offPagePoints,
            totalPoints: standing.score,
            // Lowercased because the points line is a sentence, not a legend.
            setLabel: Vocabulary.onPageLabel.lowercased(),
            offPageLabel: Vocabulary.offPageLabel.lowercased()
        ))
    }
}
