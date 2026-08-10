import SwiftUI

/// The source-word moment.
///
/// The largest missing beat in the app until now: the whole game is built
/// around cracking the eight-letter word, and finding it passed in silence.
///
/// **A sheet, not a modal overlay.** Sheets drag to dismiss, which is what
/// people expect on a phone; the web's full-screen overlay is a web pattern.
/// It also matters that this is not blocking: on most days the source word is
/// found first, on sight, in the opening seconds, and play continues after. A
/// medium detent leaves the board visible behind it and a drag puts it away.
///
/// **What it does not do.** iOS ships no definitions, pending the WordNet
/// decision, so there is no reveal content to show. Nothing here pretends
/// otherwise. See the report for whether that leaves the card thin.
struct SourceRevealCard: View {
    let word: String
    let points: Int
    /// How many set words this rack yields, which is `commonWords.count`.
    let wordsGrown: Int
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var landed = false

    var body: some View {
        ZStack {
            Cute.pageBackground.ignoresSafeArea()

            // Scrollable, because a sheet detent is a fixed height and at
            // accessibility text sizes the content is taller than it. Without
            // this the stack compressed and both the celebration line and the
            // kicker truncated to one line with an ellipsis, which is the worst
            // possible outcome for the one line Bea reacted to.
            ScrollView {
            VStack(spacing: 18) {
                PeachMark()
                    .frame(width: 96, height: 96)
                    .scaleEffect(landed || reduceMotion ? 1 : 0.4)
                    .opacity(landed || reduceMotion ? 1 : 0)

                VStack(spacing: 8) {
                    // The line Bea reacted to, added in web PR #76 after her
                    // idea. It is the reason this beat exists.
                    Text("You found the Peach of a Word!")
                        .font(CuteFont.display(22, relativeTo: .title2))
                        .foregroundStyle(Cute.accent)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(word)
                        .font(CuteFont.display(38, relativeTo: .largeTitle))
                        .foregroundStyle(Cute.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)

                    Text("The peach every word grew from")
                        .font(CuteFont.body(15, relativeTo: .subheadline))
                        .italic()
                        .foregroundStyle(Cute.inkFaint)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Without a definition the card was thin: a message, a word, a
                // kicker and a number. This is not filler, it is the set count
                // the engine already computed, and it finishes the sentence the
                // kicker starts. "The peach every word grew from" wants to know
                // how many. Remove it the day real reveal content exists.
                VStack(spacing: 4) {
                    Text(counted(points, "point"))
                        .font(CuteFont.body(16, weight: "Bold", relativeTo: .body))
                        .foregroundStyle(Cute.inkSoft)
                    Text("\(counted(wordsGrown, "word")) grew from it")
                        .font(CuteFont.body(14, relativeTo: .footnote))
                        .foregroundStyle(Cute.inkFaint)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .monospacedDigit()

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
            .padding(.vertical, 32)
            .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(Feel.bounce.delay(0.05)) { landed = true }
        }
        .accessibilityElement(children: .contain)
    }
}

#Preview("Source reveal") {
    Color.clear.sheet(isPresented: .constant(true)) {
        SourceRevealCard(word: "motorway", points: 15, wordsGrown: 27) {}
            .presentationDetents([.medium])
    }
}
