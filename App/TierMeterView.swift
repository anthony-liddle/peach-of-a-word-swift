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
                    if let next = standing.next {
                        Text("Next: \(Vocabulary.tierNames[next.index]) at \(Int((next.threshold * 100).rounded()))%")
                    } else {
                        // "Top rank" is enough. The explanation that the full
                        // set is the peak does not need to live here
                        // permanently; the completion card says it properly.
                        Text(Vocabulary.ladderPeak)
                    }
                }
                Spacer(minLength: 4)
                if streak > 0 {
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(label). \(standing.score) of \(standing.reachable) points, \(percent) percent."
            + (streak > 0 ? " Streak \(streak)." : "")
        )
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
