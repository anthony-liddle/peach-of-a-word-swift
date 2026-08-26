import PeachEngine
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
/// **The content sections.** A Definition section and an Etymology section,
/// each rendered only when its field is non-empty, which is the shape of the
/// web's `Reveal.tsx` and the reason `entry` is optional rather than the two
/// strings being required. This said `entry` is "always nil, because
/// `Data/etymology.tsv` is not committed pending the licensing decision". That
/// decision was taken on 2026-08-14 and the corpus has shipped since. `entry`
/// is now populated for 615 of the 626 calendar crowns, and nil for the other
/// eleven, where the card falls back to exactly what it rendered before: the
/// mark, the line, the word, the kicker.
///
/// That fallback is reachable in normal play, and deliberately so. It was not,
/// when this was written: the corpus covered all 626 calendar crowns. From
/// orchard v1.3.0 it covers 615 of them, because eleven rows were dropped for
/// carrying something that was not an etymology. `favorite` shipped Italian
/// inflection tables, since its Wiktionary page has an English section with no
/// Etymology subsection and an Italian one with three; `planning` shipped a Lua
/// module error; `catering` shipped a maintenance notice and nothing else.
///
/// So a player can be dealt `branding`, `catering`, `dripping`, `emulator`,
/// `favorite`, `mornings`, `planning`, `projects`, `rattling`, `sampling` or
/// `training` and see no Etymology section. That is the intended outcome: an
/// absent section reads as no etymology on hand, which is honest, where
/// `brothers` under the heading Etymology read as broken.
///
/// The fallback also still does its original job, keeping a missing file a
/// quiet card rather than a crash.
struct SourceRevealCard: View {
    let word: String
    /// The definition and etymology, when there are any.
    var entry: SourceEntry?
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
                    Text(Vocabulary.sourceFound)
                        .font(CuteFont.display(22, relativeTo: .title2))
                        .foregroundStyle(Cute.accent)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(word)
                        .font(CuteFont.display(38, relativeTo: .largeTitle))
                        .foregroundStyle(Cute.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)

                    // Obliqued rather than italicised. See
                    // `CuteFont.bodyOblique`.
                    Text(Vocabulary.revealKicker)
                        .font(CuteFont.bodyOblique(15, relativeTo: .subheadline))
                        .foregroundStyle(Cute.inkFaint)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // The points and set-count block that used to sit here is gone,
                // as its own comment asked: "Remove it the day real reveal
                // content exists." It was there because a card with no content
                // was a message, a word, a kicker and a number, and the number
                // was the only thing on it the player had earned. The two
                // sections below are what it was standing in for. The web's
                // Reveal has never shown a number.
                if let entry {
                    if !entry.definition.isEmpty {
                        RevealSection(heading: "Definition", prose: entry.definition)
                    }
                    if !entry.etymology.isEmpty {
                        RevealSection(heading: "Etymology", prose: entry.etymology)
                    }
                }

                Button(action: onDismiss) {
                    Text(Vocabulary.revealClose)
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

                // The credit rides with the content and appears only when there
                // is content, which is the web's arrangement in `Reveal.tsx`.
                //
                // It is written now rather than left for the day the corpus
                // lands, and that is the safer order rather than the eager one:
                // an attribution that is a property of the content cannot be
                // forgotten, whereas one that waits on a future commit can. It
                // renders nothing today, because `entry` is nil today.
                if entry != nil {
                    Text("Definition and etymology from Wiktionary, CC BY-SA 4.0.")
                        .font(CuteFont.body(11, relativeTo: .caption2))
                        .foregroundStyle(Cute.inkFaint)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
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

/// One titled block of reveal prose.
///
/// Left-aligned inside a card whose celebration is centred, because these are
/// paragraphs rather than announcements and centred prose is hard to read past
/// two lines. The web makes the same split.
private struct RevealSection: View {
    let heading: String
    /// Named `prose` rather than `body`, which `View` already owns.
    let prose: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(heading)
                .font(CuteFont.body(12, weight: "SemiBold", relativeTo: .caption))
                .tracking(1.4)
                .textCase(.uppercase)
                .foregroundStyle(Cute.inkFaint)
            Text(prose)
                .font(CuteFont.body(15, relativeTo: .subheadline))
                .foregroundStyle(Cute.ink)
                // Without this the text takes one line inside the sheet's
                // fixed-height detent and truncates. The same fix the
                // celebration line above needed, for the same reason.
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Source reveal, with content") {
    Color.clear.sheet(isPresented: .constant(true)) {
        SourceRevealCard(
            word: "motorway",
            entry: SourceEntry(
                definition: "noun. A road designed for fast traffic, with "
                    + "grade-separated junctions and restricted access.",
                etymology: "From motor + way, first attested in the 1900s."
            )
        ) {}
        .presentationDetents([.medium, .large])
    }
}

/// What ships today, and what a crown with no entry would render.
#Preview("Source reveal, no content") {
    Color.clear.sheet(isPresented: .constant(true)) {
        SourceRevealCard(word: "motorway") {}
            .presentationDetents([.medium])
    }
}
