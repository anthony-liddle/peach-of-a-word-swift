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
private struct WordChip: View {
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

    var body: some View {
        Button {
            // The definition reveal is out of scope for v1. This is a real
            // button with a real label and a real target so the reveal drops in
            // later without restructuring the list.
        } label: {
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
            // Grow, claim the grown bounds as the hit region, then collapse the
            // layout back. The touch area stays large; the row does not.
            .padding(.vertical, touchInset)
            .contentShape(Rectangle())
            .padding(.vertical, -touchInset)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "\(found.word), \(found.category.spokenName), "
            + "\(found.score) \(found.score == 1 ? "point" : "points")"
        )
    }
}

struct FoundListView: View {
    let puzzle: Puzzle
    let found: [String]
    let standing: TierStanding

    // One classification pass, shared by the summary and the groups, so a word
    // is never Rare in one readout and something else in the other.
    private var words: [FoundWord] { classifyFound(found, in: puzzle) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if found.isEmpty {
                Text("Found words will collect here.")
                    .font(CuteFont.body(15, relativeTo: .subheadline))
                    .foregroundStyle(Cute.inkFaint)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 24)
            } else {
                summary
                ForEach(buildGroups(words, in: puzzle)) { group in
                    if !group.setWords.isEmpty || !group.offPageWords.isEmpty {
                        groupView(group)
                    }
                }
            }
        }
    }

    /// The completion count, then bare per-rung tallies.
    ///
    /// **Never a denominator on the rarity rungs.** Advertising how many
    /// off-page words exist turns open-ended discovery into a grind. Completion
    /// is the set, and that is the one place an "X of Y" belongs.
    private var summary: some View {
        let counts: [(WordCategory, String)] = [
            (.uncommon, "Uncommon"), (.rare, "Rare"), (.mythic, "Mythic"),
        ].compactMap { category, name in
            let n = words.filter { $0.category == category }.count
            return n > 0 ? (category, "\(n) \(name)") : nil
        }

        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                RarityMark(category: .set)
                Text("\(standing.setFound) of \(standing.setTotal) words")
                    .font(CuteFont.body(15, weight: "SemiBold", relativeTo: .subheadline))
                    .foregroundStyle(Cute.ink)
                    .monospacedDigit()
            }
            if !counts.isEmpty {
                HStack(spacing: 6) {
                    ForEach(Array(counts.enumerated()), id: \.offset) { index, entry in
                        if index > 0 {
                            Text("·").foregroundStyle(Cute.inkFaint)
                        }
                        HStack(spacing: 4) {
                            RarityMark(category: entry.0)
                            Text(entry.1)
                        }
                    }
                }
                .font(CuteFont.body(13, relativeTo: .footnote))
                .foregroundStyle(Cute.inkSoft)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func groupView(_ group: LengthGroup) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(group.length) letters")
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
                Text("also found")
                    .font(CuteFont.body(12, relativeTo: .caption))
                    .italic()
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
