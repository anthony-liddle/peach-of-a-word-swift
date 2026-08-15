import SwiftUI

/// The credit, in the app rather than only in the repository.
///
/// `ATTRIBUTION.md` records the terms, but a file in a repository says nothing
/// to the person actually playing, and the web set the bar with an in-app
/// credit. This is that, ported.
///
/// The notice itself travels in `Data/ATTRIBUTION.md`, which is inside the
/// folder reference bundled into the app, so SCOWL's requirement that its notice
/// appear in all copies is met by the copy rather than by the repository. Until
/// 2026-08-11 that directory instead held a copy of the app's MIT `LICENSE`,
/// which read as though it licensed word lists nobody here owns.
///
/// **The Wiktionary line, added 2026-08-14 with the content it credits.** This
/// comment used to explain the opposite: the web credited Wiktionary for
/// definitions and etymologies, this app shipped none, and crediting a source
/// that is not used would be worse than saying nothing. That was right while it
/// was true. The reveal corpus now ships as `Data/etymology.tsv` under CC BY-SA
/// 4.0, so the credit is owed, and share-alike means owed to the player rather
/// than only to `ATTRIBUTION.md`.
///
/// The reveal card carries the same credit underneath the content itself. Both,
/// deliberately: the card credits what is on screen at the moment it is on
/// screen, and this credits the app as a whole to someone who never finds a
/// crown.
///
/// It sits at the foot of the found list, which is the quietest place the app
/// has: reachable by scrolling past everything, never on the play surface. That
/// is where the web puts its footer, and a credit that interrupts a game is a
/// credit nobody thanks you for.
struct Colophon: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Words from ENABLE and SCOWL.")
            Text("Definitions and etymologies from Wiktionary, CC BY-SA 4.0.")
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
            "Credits. Words from ENABLE and SCOWL. "
            + "Definitions and etymologies from Wiktionary, CC BY-SA 4.0. "
            + Vocabulary.typeCredit
        )
    }
}

#Preview("Colophon") {
    ZStack {
        Cute.pageBackground.ignoresSafeArea()
        Colophon()
    }
}
