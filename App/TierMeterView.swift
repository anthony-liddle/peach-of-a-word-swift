import SwiftUI
import PeachEngine

/// The six named ranks, cute skin, from the web repo's `themeCopy.ts`.
/// The engine owns the ladder structure; these are a skin over the index.
let cuteTierNames = [
    "First Sprout", "Little Bud", "Blossom", "Ripening", "Sweet", "Perfectly Peachy",
]

/// The completion crown: the rank above the six, reached by finding every set
/// word rather than by points.
let cuteCrownName = "Peachy Keen Supreme"

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

    /// Completion is the word-count peak above the named ladder. Once reached,
    /// the label holds the crown so the achievement stays visible while play
    /// continues. It is not a points rank.
    private var completed: Bool { isComplete(standing) }

    private var label: String {
        completed ? cuteCrownName : cuteTierNames[min(standing.index, cuteTierNames.count - 1)]
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
                Text("\(standing.score) \(standing.score == 1 ? "point" : "points")")
                    .font(CuteFont.body(15, weight: "Bold", relativeTo: .subheadline))
                    .foregroundStyle(Cute.ink)
                    .monospacedDigit()
            }

            track

            HStack(spacing: 8) {
                Text("\(percent)%")
                    .monospacedDigit()
                // Allowed to wrap rather than truncate. At accessibility text
                // sizes a single line lost the end of the sentence, and losing
                // words is worse than taking a second line.
                Group {
                    if let next = standing.next {
                        Text("Next: \(cuteTierNames[next.index]) at \(Int((next.threshold * 100).rounded()))%")
                    } else {
                        Text("Top rank. The full set is the peak.")
                    }
                }
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                if streak > 0 {
                    // The streak has been stored and read since persistence
                    // landed but had nowhere to live, because the toolbar is out
                    // of scope. This is its natural home.
                    Label("\(streak)", systemImage: "flame.fill")
                        .labelStyle(.titleAndIcon)
                        .foregroundStyle(Cute.crown)
                        .monospacedDigit()
                        .accessibilityLabel("Streak: \(streak) \(streak == 1 ? "day" : "days")")
                }
            }
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
        .background(Cute.paperDeep)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Cute.ink, lineWidth: 1))
    }
}
