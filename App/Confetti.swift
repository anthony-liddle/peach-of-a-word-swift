import SwiftUI

/// Confetti, for completion only.
///
/// **This is the one place it belongs.** Completion is the rarest thing in the
/// game; the source word is usually cracked in the opening seconds. Spending
/// the biggest visual gesture on the common event would leave nothing for the
/// rare one, so the source word escalates by feel and this escalates by sight.
///
/// Peaches, hearts, stars and sparkles, in the cute palette, which is the same
/// vocabulary the rarity marks use.
struct Confetti: View {
    var pieceCount: Int = 42
    /// Called when the last piece has fallen, so the host can tear it down
    /// rather than leaving a view animating forever.
    var onDone: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var falling = false

    private struct Piece: Identifiable {
        let id: Int
        let x: CGFloat          // 0 to 1 across the width
        let drift: CGFloat      // sideways travel, in points
        let delay: Double
        let duration: Double
        let spin: Double
        let size: CGFloat
        let kind: Int
    }

    /// Built once, deterministically per appearance, so pieces do not
    /// re-randomise on every re-render mid-fall.
    @State private var pieces: [Piece] = []

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                ForEach(pieces) { piece in
                    shape(piece)
                        .font(.system(size: piece.size))
                        .frame(width: piece.size, height: piece.size)
                        .position(
                            x: piece.x * geo.size.width + (falling ? piece.drift : 0),
                            y: falling ? geo.size.height + 60 : -60
                        )
                        .rotationEffect(.degrees(falling ? piece.spin : 0))
                        .opacity(falling ? 0.9 : 0)
                        .animation(
                            .easeIn(duration: piece.duration).delay(piece.delay),
                            value: falling
                        )
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            // Reduce Motion suppresses this entirely. It is pure motion, which
            // is exactly the case the setting exists for, and the card carries
            // the moment on its own without it.
            guard !reduceMotion else { onDone(); return }
            pieces = (0..<pieceCount).map { index in
                Piece(
                    id: index,
                    x: .random(in: 0.02...0.98),
                    drift: .random(in: -50...50),
                    delay: .random(in: 0...0.55),
                    duration: .random(in: 1.5...2.6),
                    spin: .random(in: -420...420),
                    size: .random(in: 12...22),
                    kind: index % 4
                )
            }
            // Deliberately a tick later than `pieces`. Setting both in the same
            // update creates the views already in their final state, so there is
            // nothing to animate from and the confetti never appears: it just
            // exists off the bottom of the screen from the first frame.
            DispatchQueue.main.async { falling = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.6) { onDone() }
        }
    }

    @ViewBuilder
    private func shape(_ piece: Piece) -> some View {
        switch piece.kind {
        case 0: PeachMark(showsFace: false)
        case 1: Text("\u{2665}").foregroundStyle(Cute.accent)      // heart
        case 2: Text("\u{2605}").foregroundStyle(Cute.discovery)   // star
        default: Text("\u{2726}").foregroundStyle(Cute.crown)      // sparkle
        }
    }
}
