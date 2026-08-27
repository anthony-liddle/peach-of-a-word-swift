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
/// **The line needed no edit when the definition corpus landed, and that is
/// worth one sentence rather than none.** It already said "Definitions and
/// etymologies", because `etymology.tsv` carries a gloss as well as an origin
/// and the crown card renders both. What changed is only the reach: the same
/// sentence now covers 24,892 glosses behind every tappable chip rather than
/// 820 behind the crowns. A credit written for the app as a whole was already
/// the right shape for a corpus that grew.
///
/// The reveal cards carry the same credit underneath the content itself. Both,
/// deliberately: a card credits what is on screen at the moment it is on
/// screen, and this credits the app as a whole to someone who never finds a
/// crown. `DefinitionCard` says "Definition from Wiktionary" rather than
/// "Definitions and etymologies", because it shows one and not the other.
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
            // Below the type credit, which is where `Game.tsx` puts it, and set
            // apart from the credits by a hair of space rather than by a rule
            // or a heading. The web spends `margin-top: 0.9rem` against a
            // 0.875rem font, so a shade over one em; 8pt on top of the stack's
            // own 3pt is the same gesture at this size.
            //
            // Obliqued rather than `.italic()`, because Nunito has no italic
            // face and `.italic()` would render the upright while reading in
            // the source as though the styling had been matched. See
            // `CuteFont.bodyOblique`.
            Text(Vocabulary.dedication)
                .font(CuteFont.bodyOblique(11, relativeTo: .caption2))
                .padding(.top, 8)
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
        // The dedication is spoken too. It is quiet, not secret, and the one
        // person it names is as likely to meet it here as on screen.
        .accessibilityLabel(
            "Credits. Words from ENABLE and SCOWL. "
            + "Definitions and etymologies from Wiktionary, CC BY-SA 4.0. "
            + Vocabulary.typeCredit + " " + Vocabulary.dedication
        )
    }
}

#Preview("Colophon") {
    ZStack {
        Cute.pageBackground.ignoresSafeArea()
        Colophon()
    }
}
