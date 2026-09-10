import SwiftUI
import PeachEngine

/// The goal bar: a points climb toward the rack's reachable score.
///
/// **Everything here is read off `TierStanding`.** Nothing is recomputed. The
/// score, the split, the fraction, the rank index and the next rung all come
/// from the one standing the rest of the screen reads, so the label, the bar and
/// the totals cannot drift apart. This project has already found two web bugs
/// caused by computing the same fact twice.
struct TierMeterView: View {
    let standing: TierStanding
    let streak: Int

    /// The day this board belongs to, when it is not today's.
    ///
    /// Nil for the live daily. Non-nil turns the caption's trailing slot from
    /// the streak into the date, which is two fixes in one: a past board gets
    /// the "which day am I on" signal it otherwise has nowhere to put, and the
    /// streak stops being shown beside a board it has nothing to do with.
    var archiveDate: Date?

    /// Opens the calendar of past days.
    var onOpenArchive: () -> Void = {}

    /// Leaves a past board for the live daily.
    var onReturnToToday: () -> Void = {}

    /// Off-page points can push the score past reachable. The bar fills to full
    /// and the named rank caps at the top; the overflow is the climb toward the
    /// completion peak, which this bar does not measure.
    private var percent: Int { min(100, Int((standing.fraction * 100).rounded())) }

    /// The reserved height for the caption row. Scaled, so Dynamic Type still
    /// grows it, but fixed at any given size so the content cannot move it.
    @ScaledMetric(relativeTo: .caption) private var captionHeight: CGFloat = 17

    /// Completion is the word-count peak above the named ladder. Once reached,
    /// the label holds the crown so the achievement stays visible while play
    /// continues. It is not a points rank.
    private var completed: Bool { isComplete(standing) }

    private var label: String {
        completed ? Vocabulary.crownName : Vocabulary.tierNames[min(standing.index, Vocabulary.tierNames.count - 1)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // A baseline-aligned row, rank on the left and the bold total on the
            // right, spaced apart.
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(CuteFont.display(18, relativeTo: .headline))
                    .foregroundStyle(completed ? Cute.crown : Cute.ink)
                Spacer(minLength: 8)
                Text(counted(standing.score, "point"))
                    .font(CuteFont.body(15, weight: "Bold", relativeTo: .subheadline))
                    .foregroundStyle(Cute.ink)
                    .monospacedDigit()
            }
            // Width reserved for the archive button, which is drawn as an
            // overlay rather than as a third item in this row. See
            // `archiveButton` for why.
            .padding(.trailing, archiveReserve)

            track

            // A fixed single-line height, reserved.
            //
            // This row wrapped to two lines at the top rank and pushed the whole
            // layout down, mid-play, as the score changed. Shortening the copy
            // fixes today's string; reserving the height fixes the class, so no
            // future wording can shift the board underneath someone's thumb.
            HStack(spacing: 8) {
                Text("\(percent)%")
                    .monospacedDigit()
                Group {
                    if archiveDate != nil {
                        // Yields. Three tenants do not fit one reserved
                        // line at XXXL, and this is the one the bar
                        // directly above already says.
                        EmptyView()
                    } else if let next = standing.next {
                        Text("Next: \(Vocabulary.tierNames[next.index]) at \(Int((next.threshold * 100).rounded()))%")
                    } else {
                        // "Top rank" is enough. The explanation that the full
                        // set is the peak does not need to live here
                        // permanently; the completion card says it properly.
                        Text(Vocabulary.ladderPeak)
                    }
                }
                Spacer(minLength: 4)
                if let archiveDate {
                    // The date and the way back live in the caption's own row.
                    //
                    // **A row of their own was built first, then measured out of
                    // existence.** `LayoutBudget.testArchiveSweep` priced it at
                    // 24.5, 27.5 and 22.5 points on an iPhone SE 3, taking the
                    // list from 150.00 to 125.50 at L and from 86.50 at XXXL
                    // into the scrolling fallback. XXXL has about sixteen points
                    // of slack and one line of text at that size already costs
                    // sixteen, so a second text row does not fit on that phone
                    // at all: the shape asked for does not exist there.
                    //
                    // This row is reserved height already paid for, and on an
                    // archive board its other two tenants are idle: a streak has
                    // nothing to do with a past board, and the next rank is
                    // legible from the bar directly above. So the date and the
                    // way back take space rather than adding it, and the fixed
                    // layout keeps every size it had.
                    Text(archiveDate, format: .dateTime.weekday(.abbreviated)
                        .day().month(.abbreviated))
                        .accessibilityIdentifier("ArchiveDateRow")
                    Spacer(minLength: 6)
                    Button(action: onReturnToToday) {
                        Text(Vocabulary.backToToday)
                            .foregroundStyle(Cute.accentDeep)
                    }
                    .buttonStyle(.plain)
                } else if streak > 0 {
                    // A flame and a number said nothing about what it counted.
                    // The word is short enough to just print.
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                        Text(counted(streak, "day"))
                            .monospacedDigit()
                    }
                    .foregroundStyle(Cute.crown)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(height: captionHeight)
            .font(CuteFont.body(12, relativeTo: .caption))
            .foregroundStyle(Cute.inkFaint)
        }
        // The 44pt target, laid over the meter rather than inside a row of it.
        //
        // Anchored to the top trailing corner, where the width above was
        // reserved for it. The meter is taller than 44pt at every size this
        // layout survives, so the button sits entirely within bounds it did not
        // create.
        .overlay(alignment: .topTrailing) { archiveButton }
        // The button is lifted out of the combined element, or it becomes a
        // fragment of one long label with no way to activate it. `MessageLine`
        // and the rack both record the same trap: a container that combines its
        // children swallows anything tappable inside it.
        .accessibilityElement(children: .contain)
    }

    /// Width held back on the top row so the overlay has somewhere to sit.
    ///
    /// Slightly under the target, because the row already ends in a gutter and
    /// the glyph is centred in its 44pt box: reserving the full 44 would leave a
    /// visible gap between the points total and the icon.
    @ScaledMetric(relativeTo: .subheadline) private var archiveReserve: CGFloat = 34

    /// The way in to the archive, and the only navigation affordance in the app.
    ///
    /// **It rides this row rather than sitting in a toolbar, and that was
    /// measured rather than preferred.** On an iPhone SE 3 at XXXL the fixed
    /// layout has about sixteen points of slack before it falls back to
    /// scrolling, and the smallest real tap target is forty-four; nothing that
    /// could hold one fits in a row of its own. A third item in an `HStack` that
    /// already exists costs **zero vertical points** and turns the question into
    /// width on a 375pt screen, which the `ViewThatFits` budget never sees.
    ///
    /// The trade is the rank label's width, and this row already competes: see
    /// `Vocabulary.ladderPeak`, which was shortened after being measured against
    /// the caption at accessibility sizes rather than guessed at.
    ///
    /// **"Costs zero vertical points" is a claim about the design and was not
    /// true of the first implementation, which is why it was measured.** A 44pt
    /// button placed as a third item in the top row sets that row's height to
    /// 44, where the text alone was about 26. Measured on an iPhone SE 3 that
    /// cost the found list 21pt at L and 13pt at XXXL, taking the XXXL cell from
    /// 86.50 to 73.50 against a floor near 70: it still fitted, with about three
    /// points to spare, on the cell the source already calls one small
    /// regression away from falling back.
    ///
    /// Drawn as an overlay instead. The meter is at least 60pt tall, so a 44pt
    /// box anchored to its top trailing corner adds no height at all, and the
    /// row above reserves the width so nothing is drawn over the points total.
    private var archiveButton: some View {
        Button(action: onOpenArchive) {
            Image(systemName: "calendar")
                .font(CuteFont.body(15, weight: "SemiBold", relativeTo: .subheadline))
                .foregroundStyle(Cute.accentDeep)
                .frame(width: Cute.minTapTarget, height: Cute.minTapTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Vocabulary.archiveTitle)
    }

    /// Three segments fill the track: on-page set points, off-page discovery
    /// points, then the transparent remainder.
    ///
    /// **The two-tone fill is the point of this bar.** Set points render in the
    /// on-page colour and off-page points in the discovery purple, so where the
    /// score came from reads at a glance. Set plus off-page is the score, so the
    /// coloured portion is exactly the fraction reached.
    private var track: some View {
        GeometryReader { geo in
            let total = max(standing.reachable, standing.score)
            let unit = total > 0 ? geo.size.width / CGFloat(total) : 0
            HStack(spacing: 0) {
                Rectangle().fill(Cute.accent)
                    .frame(width: min(geo.size.width, CGFloat(standing.setPoints) * unit))
                Rectangle().fill(Cute.discovery)
                    .frame(width: min(geo.size.width, CGFloat(standing.offPagePoints) * unit))
                Spacer(minLength: 0)
            }
        }
        // A fixed height, so the GeometryReader above only ever reads width.
        // Deriving a height from one is what broke Dynamic Type in an earlier
        // session: a GeometryReader consumes all offered space rather than
        // reporting an intrinsic size.
        .frame(height: 12)
        .motion(Feel.settle, value: standing.score)
        .background(Cute.paperDeep)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Cute.ink, lineWidth: 1))
    }
}
