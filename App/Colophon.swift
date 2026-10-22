import SwiftUI

/// The foot of the found list: the dedication, and nothing else.
///
/// **It carried the credits until 22 October 2026,** with How the words work
/// and the privacy link under them. Antoine moved all of that to Settings,
/// which the title screen reaches, and kept this line here:
/// - the word lists', Wiktionary's and the typefaces' credits are on the
///   Licences list, each over its full text (`LicencesPage`);
/// - How the words work and the privacy policy are Settings' own rows;
/// - each definition card and the reveal card keep their own Wiktionary line,
///   which credits what is on screen while it is on screen.
///
/// `Data/ATTRIBUTION.md` still travels in the bundle, so SCOWL's notice
/// appears in every copy whether or not anyone opens Licences.
///
/// **It sits at the foot of the found list,** the quietest place the app has:
/// reachable by scrolling past everything, never on the play surface. That is
/// where the web puts its footer, and the web's colophon keeps its credits,
/// since the web has no Settings.
struct Colophon: View {
    var body: some View {
        // **Centred.** Bea's reason is the whole brief: "it made it feel more
        // intentional". Left-aligned it read as the next item in the list
        // above it; centred it reads as placed. The web centres it too.
        //
        // Obliqued rather than `.italic()`, because Nunito has no italic face
        // and `.italic()` would render the upright while reading in the source
        // as though the styling had been matched. See `CuteFont.bodyOblique`.
        Text(Vocabulary.dedication)
            .font(CuteFont.bodyOblique(11, relativeTo: .caption2))
            .foregroundStyle(Cute.inkFaint)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
            // A background rather than an overlay or a stack member: a
            // background does not influence the size of what it sits behind,
            // so no decoration here can move the colophon's height, and the
            // colophon's height is inside the scrolling list the rack is
            // budgeted against.
            .background(ColophonDecoration())
            .padding(.top, 26)
            // Spoken, as it always was. It is quiet, not secret, and the one
            // person it names is as likely to meet it here as on screen.
            .accessibilityIdentifier("Colophon")
    }
}

#Preview("Colophon") {
    ZStack {
        Cute.pageBackground.ignoresSafeArea()
        Colophon()
    }
}
