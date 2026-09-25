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
/// **That last sentence no longer holds, and the property is spent
/// deliberately at every length.** The card opens at large on every crown, so
/// the board is covered whenever this is on screen. What bought that:
///
/// Measured on an iPhone 16 Pro, the medium detent is about 437pt. The card's
/// fixed furniture, before a word of prose, is 361pt. The *shortest* entry in
/// the corpus renders 513pt and the longest renders 1,209pt. So no crown
/// carrying an entry has ever fitted the medium detent, and 615 of the 626
/// calendar crowns carry one. Medium was preserving the board on eleven days a
/// year, and on those eleven the card is a mark, a line, a word and a kicker,
/// which is not a card anyone needs the board behind.
///
/// A content-measured detent was built and then dropped for that reason. It
/// would have carried a `UIHostingController` and forty lines to buy a better
/// opening height on eleven days, and it would have left the actual complaint
/// unfixed: at 1,209pt the way out is off screen at any detent, because the
/// content is taller than the phone. See `CardWayOut`, which is the part
/// that fixes it.
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
    /// Who wrote the definition. The etymology is Wiktionary's in every case;
    /// the definition is not, for two of the crowns, which is why this card
    /// needs to be told rather than assuming one author for both.
    ///
    /// **Not defaulted, on purpose.** An empty default would compile here and
    /// credit Wiktionary for words it did not write.
    let provenance: GlossProvenance
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
            VStack(spacing: 0) {
                ScrollView {
                    RevealContent(word: word, entry: entry, provenance: provenance,
                                  landed: landed || reduceMotion)
                }
                .scrollBounceBehavior(.basedOnSize)

                CardWayOut(label: Vocabulary.revealClose, onDismiss: onDismiss)
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(Feel.bounce.delay(0.05)) { landed = true }
        }
        .accessibilityElement(children: .contain)
    }
}

/// The part of the card that scrolls: the celebration, the word, and the prose.
///
/// Separated from the part that does not scroll. Everything here is allowed to
/// run to any length, because `withdraw` measures 1,209pt against an 874pt
/// phone and no arrangement makes that fit.
private struct RevealContent: View {
    let word: String
    var entry: SourceEntry?
    let provenance: GlossProvenance
    /// The peach's landing state. It scales, which does not affect layout.
    var landed: Bool

    var body: some View {
        VStack(spacing: 18) {
                PeachMark()
                    .frame(width: 96, height: 96)
                    .scaleEffect(landed ? 1 : 0.4)
                    .opacity(landed ? 1 : 0)

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

                    // The credit rides with the content and appears only when
                    // there is content, which is the web's arrangement in
                    // `Reveal.tsx`. It stays inside the scroll rather than
                    // moving into the pinned bar with the button: it was tried
                    // there, and at AX5 it took four lines of large type and
                    // left the prose a sliver. Attribution has to be reachable,
                    // which scrolling to the end of the thing being attributed
                    // satisfies; it does not have to be permanently on screen
                    // at the cost of the text it credits.
                    // **Two authors are possible on this card and only here.**
                    // `eighteen` and `fourteen` are crowns whose definition was
                    // written for this game while their etymology is still
                    // Wiktionary's, so the line splits the claim rather than
                    // picking one. It splits inside one sentence: at AX5 a
                    // second credit row costs more height than the distinction
                    // is worth, under a card that is already the longest in the
                    // game.
                    //
                    // Gated on the etymology actually being on screen, matching
                    // the section above it. In the shipped corpus every row has
                    // one, so this changes nothing today; it means the credit
                    // follows the content rather than the entry, which is the
                    // rule the comment above already states.
                    Text(provenance.credit(
                        for: word,
                        includingEtymology: !entry.etymology.isEmpty
                    ))
                        .font(CuteFont.body(11, relativeTo: .caption2))
                        .foregroundStyle(Cute.inkFaint)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 32)
            .frame(maxWidth: .infinity)
    }
}

/// The part of a card that does not scroll: the way out.
///
/// **Shared by both cards that open over the board**, this one and
/// `DefinitionCard`, because the definition card had the same defect this bar
/// was built to fix and had not been given it. Its button sat at the foot of
/// the scrolling prose, so at AX5 on an iPhone SE it was never wholly on screen
/// at rest: at best 77pt of a 115pt button on the shortest gloss, and more
/// than a screen away on a long one (#68). One construction, so the two ways out
/// cannot drift apart again.
///
/// **Why this is pinned rather than sitting at the foot of the prose.** Bea
/// asked to "show all of the etymology and definition plus button no matter the
/// length", and the length is the problem: the longest entry in the corpus
/// renders 1,209pt of card on an 874pt phone. There is no detent that puts a
/// button below that content on screen, because the content is taller than the
/// screen. A taller opening height makes the card nicer to read and leaves the
/// button exactly as unreachable, which is what the measured-detent version of
/// this change would have shipped.
///
/// Pinning is the only arrangement that satisfies the phrase as written. The
/// prose scrolls under this bar and the way out is on screen on every card, at
/// every text size, including the 9,047pt AX5 case that this card's own history
/// records.
///
/// **Only the button is pinned.** The CC BY-SA credit was pinned here too at
/// first, on the reasoning that attribution is owed to the reader rather than
/// to a file. At AX5 that reasoning cost more than it bought: the credit took
/// four lines of accessibility-sized type, the bar took over half the screen,
/// and the prose it credits was reduced to a sliver. It sits at the foot of
/// the scrolling content instead, which keeps it reachable without letting it
/// crowd out the thing it is crediting.
struct CardWayOut: View {
    /// What the way out says, which depends on where the card was opened.
    let label: String
    let onDismiss: () -> Void

    var body: some View {
        Button(action: onDismiss) {
            Text(label)
                .font(CuteFont.body(15, weight: "SemiBold", relativeTo: .subheadline))
                .tracking(2.1)
                .textCase(.uppercase)
                .foregroundStyle(Cute.paper)
                // Two lines and a floor, because the label is tracked out and
                // uppercased and at AX5 it truncated to "BACK TO THE...". A
                // way out that cannot say what it does is barely better than
                // one below the fold, which is the whole subject here.
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 52)
                .padding(.vertical, 6)
                .background(Capsule().fill(Cute.accent))
        }
        .buttonStyle(PillPressStyle())
        // **The label grows to AX1 and stops**, which is the rule the play
        // screen's controls follow and for the same reason. The bar is pinned,
        // so every point it grows is taken from the prose above it, and the
        // prose is what a reader at AX5 opened the card to read. Unbounded, the
        // label ran to two lines of AX5 type in a 115pt pill. It stays words:
        // the reader who turned the text up still has to read what the way out
        // says. See `Controls`.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .padding(.horizontal, 28)
        .padding(.top, 12)
        .padding(.bottom, 20)
        // Opaque, so prose scrolling underneath does not show through the bar.
        // The page background rather than a card colour, because this is the
        // same surface the content sits on and a second tone here would read as
        // a toolbar bolted to the bottom of a card.
        .background(Cute.pageBackground)
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
            ),
            provenance: GlossProvenance(projectWords: [])
        ) {}
        .presentationDetents([.large])
    }
}

/// What ships today, and what a crown with no entry would render.
#Preview("Source reveal, no content") {
    Color.clear.sheet(isPresented: .constant(true)) {
        SourceRevealCard(
            word: "motorway",
            provenance: GlossProvenance(projectWords: [])
        ) {}
            .presentationDetents([.large])
    }
}

/// The split case: a crown this project wrote the definition for.
///
/// `eighteen` and `fourteen` are the only two, and both are live calendar
/// crowns, so this is a card a player opens on two days of the cycle. The
/// definition is ours and the etymology is Wiktionary's, and the credit has to
/// say both in one sentence.
#Preview("Source reveal, our definition and their etymology") {
    Color.clear.sheet(isPresented: .constant(true)) {
        SourceRevealCard(
            word: "eighteen",
            entry: SourceEntry(
                definition: "numeral. The cardinal number occurring after "
                    + "seventeen and before nineteen.",
                etymology: "From Middle English eightetene, from Old English "
                    + "eahtatiene."
            ),
            provenance: GlossProvenance(projectWords: ["eighteen"])
        ) {}
        .presentationDetents([.large])
    }
}
