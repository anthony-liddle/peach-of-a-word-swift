import SwiftUI

/// The credit, in the app rather than only in the repository.
///
/// `ATTRIBUTION.md` records the terms and satisfies SCOWL's requirement that its
/// notice travel with the word lists, but a file in a repository says nothing to
/// the person actually playing, and the web set the bar with an in-app credit.
/// This is that, ported.
///
/// **No Wiktionary line.** The web credits it for definitions and etymologies;
/// this app ships none, and the source-word card names the word without ever
/// defining it. Crediting a source that is not used would be worse than saying
/// nothing.
///
/// It sits at the foot of the found list, which is the quietest place the app
/// has: reachable by scrolling past everything, never on the play surface. That
/// is where the web puts its footer, and a credit that interrupts a game is a
/// credit nobody thanks you for.
struct Colophon: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Words from ENABLE and SCOWL.")
            Text(Vocabulary.typeCredit)
        }
        .font(CuteFont.body(11, relativeTo: .caption2))
        .foregroundStyle(Cute.inkFaint)
        .frame(maxWidth: .infinity, alignment: .center)
        .multilineTextAlignment(.center)
        .padding(.top, 26)
        // One element to VoiceOver rather than two orphaned fragments, and it
        // says what the lines are for, which "Words from ENABLE and SCOWL" on
        // its own does not.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Credits. Words from ENABLE and SCOWL. \(Vocabulary.typeCredit)"
        )
    }
}

#Preview("Colophon") {
    ZStack {
        Cute.pageBackground.ignoresSafeArea()
        Colophon()
    }
}
