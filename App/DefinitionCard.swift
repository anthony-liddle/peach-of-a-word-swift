import SwiftUI

/// What a found word says when you tap it.
///
/// **Shaped from the web's quiet register, not from `SourceRevealCard`.**
/// `Reveal.tsx` renders two registers from one component and the difference
/// between them is the whole design: the crown register carries a kicker, a
/// definition section, an etymology section and the celebration around them;
/// the quiet register carries the word, a rule, one paragraph, the way back and
/// the credit. `.reveal--quiet` in the web's stylesheet is explicit about why:
/// "smaller and plainer so the celebration hierarchy holds", and it drops the
/// crown's amber entirely.
///
/// So this is a separate view rather than a mode of the crown card. Reusing
/// `SourceRevealCard` would have meant a peach, a celebration line and a kicker
/// on a card whose job is to answer "what does that mean", and every one of
/// them would have had to be conditioned away. A found word wants a definition
/// and very little else.
///
/// **What is deliberately not carried across from the crown card:** the peach
/// and its landing animation, `Vocabulary.sourceFound`, `Vocabulary.revealKicker`,
/// the section headings, and the etymology. The web's quiet register has none of
/// them either. What is carried is the close button and the sheet behaviour,
/// because those are how this app dismisses a card and a second idiom for one
/// gesture is worse than a shared one.
///
/// **The rule under the word is tinted by category**, which is the one piece of
/// colour the quiet register keeps: `--good` for a set word, `--discovery` for
/// anything off the page. `WordCategory.tint` already holds that mapping for
/// the rarity marks, so the rule and the mark cannot disagree.
///
/// ---
///
/// **Three defects in the corpus are known and are deliberately not worked
/// around here.** They are orchard's to fix, they are unbundled from the
/// sense-ranking work, and a Swift-side patch would hide them from the queue
/// that has to see them:
///
/// - **96** glosses carry spaces around a hyphen. `gin` reads "non - aged" and
///   `ship` reads "water - borne". A regex could close those 96 and would also
///   quietly rewrite any gloss where a spaced hyphen is correct punctuation.
///   (Reported as 92; counted at 96 against orchard v1.5.0.)
/// - `sector` carries an editor's question: "noun. A section. (Can we add an
///   example for this sense?)"
/// - `meal` reads "noun. Correct quotes", which is not a definition of anything
///   and which no pattern finds, because there is nothing wrong with it as a
///   sentence. (Reported without the part-of-speech prefix and with a full
///   stop; neither is in the file.)
///
/// The third is the one that matters for how the coverage figure should be
/// read. Every set word has a ROW on all 626 racks, which is exact and is a
/// presence check; `meal` has a row too.
/// Where a definition card was opened from, which decides where it says it
/// goes back to.
///
/// The card's dismiss button read "Back to the basket" wherever it opened,
/// and from inside a rung list that is false: it returns to the rung list, and
/// the sheet underneath already has a correctly labelled "Back to the basket"
/// of its own. Two identical labels, two destinations, one of them wrong.
///
/// The label is resolved through `Vocabulary` rather than assembled here. A
/// themed string built at a call site is how one escapes the module that owns
/// it, and `AppVocabularyTests` cannot see it when it does: its scanner
/// compares string literals, and `"Back to the \(Vocabulary.container)"` is
/// not the literal `"Back to the basket"`. `RungSheet` had exactly that, and
/// this change removes it.
enum DefinitionOrigin: Equatable {
    /// The found list, which is the board's own list of everything.
    case foundList
    /// One rung's sheet, named as the player sees it.
    case rung(named: String)

    var closeLabel: String {
        switch self {
        case .foundList: Vocabulary.revealClose
        case .rung(let name): Vocabulary.closeToRung(name)
        }
    }
}

/// The definition card as a sheet, and the only place it is constructed.
///
/// **Two paths reach this, and nothing else may build one.** A found-list chip
/// opens a definition, and now so does a word inside a rung sheet. Two call
/// sites constructing `DefinitionCard` themselves is the shape this project
/// keeps finding: they agree on the day they are written and drift the first
/// time one of them is changed, because nothing forces them to agree. So the
/// construction lives here, both paths call this, and
/// `OneDefinitionCardTests` asserts that `DefinitionCard(` appears exactly
/// once in the app's source.
///
/// The detents are part of what is shared. A card that opened at a different
/// height depending on how it was reached would be the same divergence in a
/// quieter form.
struct DefinitionSheet: View {
    let word: String
    let category: WordCategory
    /// The gloss, or nil when the corpus has none for this word.
    var definition: String?
    /// Where this was opened from, which names the way out.
    var origin: DefinitionOrigin = .foundList
    let onDismiss: () -> Void

    var body: some View {
        DefinitionCard(
            word: word,
            category: category,
            definition: definition,
            closeLabel: origin.closeLabel,
            onDismiss: onDismiss
        )
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

struct DefinitionCard: View {
    let word: String
    let category: WordCategory
    /// The gloss, or nil when the corpus has none for this word.
    var definition: String?
    /// What the way out says, which depends on where this was opened from.
    /// Resolved by `DefinitionOrigin`, never assembled here.
    var closeLabel: String = Vocabulary.revealClose
    let onDismiss: () -> Void

    /// The line for a word with no gloss.
    ///
    /// **Carried verbatim from the web and kept out of `Copy.swift`, which is
    /// the opposite of where it was expected to live.** The brief asked for
    /// "the app's own themed equivalent from `Copy.swift`"; there is none, and
    /// the reason there is none is that the web does not theme this string
    /// either. It is a module constant in `Reveal.tsx`, absent from
    /// `themeCopy.ts`, rendered identically under letterpress and cute.
    ///
    /// `Copy.swift` states the same rule for itself: "Strings carrying no
    /// metaphor stay out, deliberately, exactly as the web leaves out SHUFFLE,
    /// CLEAR and the rejection messages." This sentence carries no metaphor. No
    /// basket, no peach, nothing that changes if the theme changes. Putting it
    /// there would have meant editing the comment that justifies the file's
    /// existence in order to file one string against its stated rule.
    ///
    /// **It reads as honest rather than broken, which is the point of the
    /// second sentence.** The first half says the app has nothing; the second
    /// half says the player was still right. Same reasoning as the disabled
    /// tile's refusal: a no is allowed to be a no, and it is not allowed to
    /// imply the player made a mistake.
    private static let noDefinition =
        "No definition on hand for this one. It is still a real word you found."

    var body: some View {
        ZStack {
            Cute.pageBackground.ignoresSafeArea()

            // Scrollable for the same reason the crown card is: a sheet detent
            // is a fixed height, and at accessibility text sizes one long gloss
            // is taller than it. Without this the stack compresses and the
            // definition truncates, which on a card whose only job is the
            // definition is the whole card failing.
            ScrollView {
                VStack(spacing: 0) {
                    // Lowercase, as `.reveal__word` sets it. The corpus keys
                    // are lowercase already; this is belt and braces against a
                    // future caller passing something else.
                    Text(word.lowercased())
                        .font(CuteFont.display(26, relativeTo: .title2))
                        .foregroundStyle(Cute.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)

                    // `.reveal__sep`: 3rem by 2px, centred, tinted by category.
                    Capsule()
                        .fill(category.tint)
                        .frame(width: 48, height: 2)
                        .padding(.vertical, 16)

                    Text(definition ?? Self.noDefinition)
                        // Identified, so a UI test can ask this element what it
                        // says instead of enumerating every static text on the
                        // screen looking for prose. That enumeration is not
                        // merely inelegant: `allElementsBoundByIndex` over the
                        // whole tree walks a seeded board's several hundred
                        // chips per call, and the test that did it took
                        // **1120 seconds** against 8 for its siblings. Same
                        // idiom as `FoundSummaryCount`, and for the same
                        // reason: name the element, do not go looking for it.
                        .accessibilityIdentifier("DefinitionProse")
                        .font(CuteFont.body(15, relativeTo: .subheadline))
                        .foregroundStyle(Cute.ink)
                        // The miss line is dimmed rather than restyled, which
                        // is the web's `.reveal__def--none { opacity: 0.85 }`.
                        // Dimming says "there is nothing here" without making
                        // the sentence look like an error.
                        .opacity(definition == nil ? 0.85 : 1)
                        .multilineTextAlignment(.leading)
                        // Left-aligned inside a centred card, as the crown
                        // card's sections are, and for the same reason: this is
                        // a paragraph rather than an announcement, and centred
                        // prose is hard to read past two lines.
                        .frame(maxWidth: .infinity, alignment: .leading)
                        // Without this the text takes one line inside the
                        // sheet's fixed-height detent and truncates.
                        .fixedSize(horizontal: false, vertical: true)

                    Button(action: onDismiss) {
                        Text(closeLabel)
                            .font(CuteFont.body(15, weight: "SemiBold", relativeTo: .subheadline))
                            .tracking(2.1)
                            .textCase(.uppercase)
                            .foregroundStyle(Cute.paper)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 52)
                            .background(Capsule().fill(Cute.accent))
                    }
                    .buttonStyle(PillPressStyle())
                    .padding(.top, 24)

                    // **Gated on there being content to credit, where the web
                    // prints it either way.** That divergence is taken from
                    // this app's own precedent rather than invented: the crown
                    // card gates the same line on `entry != nil`, and
                    // `Data/ATTRIBUTION.md` records the argument, that
                    // crediting a source that was not used would be worse than
                    // saying nothing. On a miss no Wiktionary text is on
                    // screen, so there is nothing owed and nothing claimed.
                    if definition != nil {
                        Text("Definition from Wiktionary, CC BY-SA 4.0.")
                            .font(CuteFont.body(11, relativeTo: .caption2))
                            .foregroundStyle(Cute.inkFaint)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 16)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 32)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .accessibilityElement(children: .contain)
    }
}

#Preview("Definition, set word") {
    Color.clear.sheet(isPresented: .constant(true)) {
        DefinitionCard(
            word: "resident",
            category: .set,
            definition: "noun. A person who lives somewhere permanently or on "
                + "a long-term basis."
        ) {}
        .presentationDetents([.medium, .large])
    }
}

#Preview("Definition, mythic") {
    Color.clear.sheet(isPresented: .constant(true)) {
        DefinitionCard(
            word: "sentried",
            category: .mythic,
            definition: "verb. simple past and past participle of sentry"
        ) {}
        .presentationDetents([.medium, .large])
    }
}

/// The miss, which is reachable in normal play: rare coverage is about 72
/// percent rack-weighted.
#Preview("Definition, none on hand") {
    Color.clear.sheet(isPresented: .constant(true)) {
        DefinitionCard(word: "eir", category: .rare) {}
            .presentationDetents([.medium])
    }
}
