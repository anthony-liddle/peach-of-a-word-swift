import SwiftUI

/// The crown card. The peak of the game.
///
/// Finding every common word a rack can spell is the rarest thing that happens
/// here, and until now it was the least marked: no card, no confetti, no
/// haptic. The hierarchy the web established is that the source word is a
/// moment and completion is the peak, so this has to be visibly and physically
/// above the peach card.
///
/// It does not end anything. Off-page words remain to be found, the board stays
/// live behind the sheet, and dismissing returns straight to it.
struct CompletionCard: View {
    let setTotal: Int
    let score: Int
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var landed = false
    @State private var showConfetti = true

    var body: some View {
        ZStack {
            Cute.pageBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    // The peach ornament, larger than the source card's, and
                    // wearing the crown that gives the card its name.
                    ZStack(alignment: .top) {
                        PeachMark()
                            .frame(width: 112, height: 112)
                            .padding(.top, 16)
                        Crown()
                            .fill(Cute.crown)
                            .frame(width: 46, height: 26)
                            .offset(y: -2)
                    }
                    .scaleEffect(landed || reduceMotion ? 1 : 0.4)
                    .opacity(landed || reduceMotion ? 1 : 0)

                    VStack(spacing: 8) {
                        // The cute skin for the completion crown, from the web's
                        // CROWN_NAMES. It sits above the six named ranks and is
                        // reached by word count, not by points.
                        Text(cuteCrownName)
                            .font(CuteFont.display(26, relativeTo: .title))
                            .foregroundStyle(Cute.accent)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        // The cute skin, from themeCopy.ts:197. This shipped
                        // for a while carrying the letterpress line ("the rack
                        // can spell, found"), which is type-case vocabulary
                        // standing in the middle of the peach celebration.
                        // A rack is letterpress; these letters grow, and what
                        // you do with them is pick. AppVocabularyTests asserts
                        // the string so the next drift fails a test rather
                        // than waiting to be noticed a fourth time.
                        Text("Every common word these letters can grow, picked.")
                            .font(CuteFont.body(15, relativeTo: .subheadline))
                            .foregroundStyle(Cute.inkSoft)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(spacing: 4) {
                        Text("\(setTotal) of \(counted(setTotal, "word"))")
                            .font(CuteFont.body(16, weight: "Bold", relativeTo: .body))
                            .foregroundStyle(Cute.ink)
                        Text("\(counted(score, "point")) so far")
                            .font(CuteFont.body(14, relativeTo: .footnote))
                            .foregroundStyle(Cute.inkFaint)
                    }
                    .monospacedDigit()

                    // Deliberately not "Done". Completion is not the end of the
                    // rack: the off-page ladder is still open and the board is
                    // still live behind this sheet.
                    Button(action: onDismiss) {
                        Text("Keep playing")
                            .font(CuteFont.body(15, weight: "SemiBold", relativeTo: .subheadline))
                            .tracking(2.1)
                            .textCase(.uppercase)
                            .foregroundStyle(Cute.paper)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 52)
                            .background(Capsule().fill(Cute.accent))
                    }
                    .buttonStyle(PillPressStyle())
                    .padding(.top, 4)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 28)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)

            if showConfetti {
                Confetti { showConfetti = false }
                    .ignoresSafeArea()
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(Feel.bounce.delay(0.05)) { landed = true }
        }
        .accessibilityElement(children: .contain)
    }
}

/// A small three-peak crown, matching the base theme's `mark--source`
/// silhouette, which the web draws as "three peaks on a base".
private struct Crown: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        return Path { p in
            p.move(to: CGPoint(x: 0, y: h))
            p.addLine(to: CGPoint(x: 0.08 * w, y: 0.18 * h))
            p.addLine(to: CGPoint(x: 0.30 * w, y: 0.62 * h))
            p.addLine(to: CGPoint(x: 0.50 * w, y: 0))
            p.addLine(to: CGPoint(x: 0.70 * w, y: 0.62 * h))
            p.addLine(to: CGPoint(x: 0.92 * w, y: 0.18 * h))
            p.addLine(to: CGPoint(x: w, y: h))
            p.closeSubpath()
        }
    }
}

#Preview("Completion") {
    Color.clear.sheet(isPresented: .constant(true)) {
        CompletionCard(setTotal: 27, score: 118) {}
            .presentationDetents([.medium, .large])
    }
}
