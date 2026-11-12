import SwiftUI
import PeachEngine

/// The daily share, which travels with the summary row, and opens on the two
/// cards for the big finds as well (`CompletionCard`, `CardWayOut`), built
/// from the same values each time.
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
        .accessibilityLabel("Share your result")
        .modifier(ExposedShareText(text: shareText))
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

/// `-exposeShare 1` puts a Share's text in its accessibility value, so
/// `ShareFromTheCards` can hold a card's Share to the found list's. Without
/// it the text only exists inside the system's share sheet. Debug builds only,
/// and opt in, so VoiceOver never reads the whole share in normal use.
private struct ExposedShareText: ViewModifier {
    let text: String

    func body(content: Content) -> some View {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "exposeShare") {
            content.accessibilityValue(text)
        } else {
            content
        }
        #else
        content
        #endif
    }
}
