import SwiftUI
import PeachEngine

/// A wrapping row layout, the equivalent of CSS `flex-wrap: wrap`.
///
/// SwiftUI has no wrapping stack, so this is the one piece of layout that had to
/// be written by hand rather than expressed. The web says
/// `display: flex; flex-wrap: wrap; gap: 0.3rem 0.75rem` and is done.
struct FlowLayout: Layout {
    // The web uses `gap: 0.3rem 0.75rem`: a small row gap and a larger column
    // gap. The asymmetry is the point. An equal gap makes wrapped rows read as
    // separate lines rather than as one continuous flow of words.
    //
    // Rows are sized from the chips' own heights, which are now sized from the
    // text rather than from a tap target. See `WordChip`.
    var horizontalSpacing: CGFloat = 12
    var verticalSpacing: CGFloat = 5

    /// Split the subviews into rows that fit the proposed width.
    private func rows(_ subviews: Subviews, width: CGFloat) -> [[(Int, CGSize)]] {
        var rows: [[(Int, CGSize)]] = [[]]
        var x: CGFloat = 0
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = rows[rows.count - 1].isEmpty ? size.width : size.width + horizontalSpacing
            if x + needed > width && !rows[rows.count - 1].isEmpty {
                rows.append([(index, size)])
                x = size.width
            } else {
                rows[rows.count - 1].append((index, size))
                x += needed
            }
        }
        return rows
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let laid = rows(subviews, width: width)
        let height = laid.reduce(into: CGFloat.zero) { total, row in
            total += (row.map(\.1.height).max() ?? 0) + verticalSpacing
        }
        return CGSize(width: width, height: max(0, height - verticalSpacing))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize,
                       subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(subviews, width: bounds.width) {
            var x = bounds.minX
            let rowHeight = row.map(\.1.height).max() ?? 0
            for (index, size) in row {
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (rowHeight - size.height) / 2),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + horizontalSpacing
            }
            y += rowHeight + verticalSpacing
        }
    }
}

/// One found word: its mark, the word, and what it was worth.
struct WordChip: View {
    let found: FoundWord
    /// The chip's LAYOUT height, matching the web's `min-height: 24px`.
    ///
    /// This is not the tap target. The touch region is expanded separately
    /// below, so a small chip carries a large one without inflating the row.
    ///
    /// **Why 24 and not 44, on the record rather than as a quietly lowered
    /// standard.** 44pt is Apple's figure for standalone controls. WCAG 2.5.8
    /// sets 24 by 24 as the minimum and carves out an explicit exception for
    /// inline targets constrained by the line height of surrounding text, which
    /// is exactly what these are: words in a flowing paragraph, not buttons in
    /// a row. Sizing them as standalone controls gave roughly 30pt of box
    /// around 20pt of text and broke the flow the list depends on. The web
    /// settled the same question the same way, and its 24px chips are tapped
    /// daily on a phone without complaint.
    @ScaledMetric(relativeTo: .body) private var chipHeight: CGFloat = 24

    /// How far the touch region extends past the chip on each side, taking the
    /// effective target to roughly 44pt without costing a single point of row
    /// height.
    @ScaledMetric(relativeTo: .body) private var touchInset: CGFloat = 10

    /// **Deliberately not a button.**
    ///
    /// These were built as real buttons with real 44pt targets so the definition
    /// reveal could drop in later. But the reveal is blocked on the WordNet
    /// decision, and in the meantime a control that invites a tap and then
    /// ignores it is worse than a label: it reads as broken, and VoiceOver
    /// announces "button" and promises an action that never comes.
    ///
    /// So they are inert until there is something to show. The chip structure,
    /// the marks, the points and the row rhythm are all unchanged; restoring
    /// the button is wrapping this in one when the reveal lands, not a rebuild.
    var body: some View {
        Group {
            HStack(spacing: 5) {
                RarityMark(category: found.category)
                Text(found.word)
                    .font(CuteFont.body(17, relativeTo: .body))
                    .foregroundStyle(Cute.ink)
                if found.category.isOffPage {
                    // Off-page finds show what they were worth. Set words do not:
                    // the group's "X of Y" already accounts for them, and a
                    // number on every chip would bury the ones that earned extra.
                    Text("+\(found.score)")
                        .font(CuteFont.body(13, weight: "SemiBold", relativeTo: .caption))
                        .foregroundStyle(Cute.discovery)
                        .monospacedDigit()
                }
            }
            .frame(minHeight: chipHeight)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(found.word), \(found.category.spokenName), "
            + counted(found.score, "point")
        )
    }
}

struct FoundListView: View {
    let puzzle: Puzzle
    let found: [String]
    let standing: TierStanding
    /// The date the board belongs to, so a share names the right day even if
    /// midnight has passed while the app stayed open.
    var boardDate: Date = Date()

    init(puzzle: Puzzle, found: [String], standing: TierStanding,
         boardDate: Date = Date()) {
        self.puzzle = puzzle
        self.found = found
        self.standing = standing
        self.boardDate = boardDate
        self.words = classifyFound(found, in: puzzle)
    }

    // One classification pass, shared by the summary and the groups, so a word
    // is never Rare in one readout and something else in the other.
    /// Classified once, at init.
    ///
    /// This was a computed property read eight times per render, so
    /// `classifyFound` ran over every found word eight times for one pass of
    /// the view. Measured at 43 microseconds over 75 words, so it was never the
    /// input problem it was investigated as, and it is still the same
    /// one-source-of-truth shape this project keeps hitting.
    private let words: [FoundWord]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if found.isEmpty {
                Text(Vocabulary.emptyFoundList)
                    .font(CuteFont.body(15, relativeTo: .subheadline))
                    .foregroundStyle(Cute.inkFaint)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 24)
            } else {
                // The summary is no longer here. It is pinned above the scroll
                // as `FoundSummary`, because a status line you have to scroll
                // to find is not a status line.
                ForEach(buildGroups(words, in: puzzle)) { group in
                    if !group.setWords.isEmpty || !group.offPageWords.isEmpty {
                        groupView(group)
                    }
                }
            }
            Colophon()
        }
    }


    private func groupView(_ group: LengthGroup) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(counted(group.length, "letter"))
                    .font(CuteFont.display(15, relativeTo: .subheadline))
                    .foregroundStyle(Cute.inkSoft)
                Spacer(minLength: 8)
                if group.setTotal > 0 {
                    Text("\(group.setFound) of \(group.setTotal)")
                        .font(CuteFont.body(13, relativeTo: .footnote))
                        .foregroundStyle(Cute.inkFaint)
                        .monospacedDigit()
                }
            }
            .accessibilityElement(children: .combine)

            if !group.setWords.isEmpty {
                FlowLayout() {
                    ForEach(group.setWords) { WordChip(found: $0) }
                }
            }

            // Only when a group carries both. Without it a row reads "1 of 2"
            // above two chips and looks wrong, because the count describes the
            // set list only. Set-only groups stay clean and label-free.
            if group.needsAlsoFound {
                // Obliqued rather than italicised, matching the web's
                // `.found__rung-note`. See `CuteFont.bodyOblique`.
                Text("also found")
                    .font(CuteFont.bodyOblique(12, relativeTo: .caption1))
                    .foregroundStyle(Cute.inkFaint)
                    .padding(.top, 2)
            }

            if !group.offPageWords.isEmpty {
                FlowLayout() {
                    ForEach(group.offPageWords) { WordChip(found: $0) }
                }
            }
        }
    }
}
