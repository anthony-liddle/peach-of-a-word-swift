import SwiftUI
import PeachEngine

/// The words she found at one rarity rung.
///
/// The web does this as an inline disclosure under the summary, specifically so
/// opening a rung does not evict the per-length grid below it. A sheet does not
/// have that problem, so the constraint does not carry over; only the reasoning
/// does, which is that seeing her Rare words should not cost her the view she
/// was already reading. The board stays behind the sheet and a drag brings it
/// back.
///
/// One sheet at a time. The web keeps rungs independently open because three
/// inline panels can coexist; a sheet cannot, so that decision is moot here
/// rather than ported.
///
/// **No denominator, here least of all.** This is the trophy case: her finds at
/// a rung, and never how many exist there. The count in the title is the length
/// of the list below it, from the same classification pass, so the two cannot
/// disagree.
struct RungSheet: View {
    let rung: WordCategory
    let name: String
    let words: [FoundWord]
    /// The glosses, so a word here can open its own definition.
    var definitions: [String: String] = [:]
    let onDismiss: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// The word whose definition is open, if any.
    ///
    /// **A second sheet over this one, rather than replacing it.** Bea was
    /// browsing a rung when she wanted a definition, and a definition is an
    /// aside inside that: replacing this sheet would answer the question and
    /// lose her place in the list she was reading. The idiom is established
    /// here, since `SFSafariViewController` presents over the explainer the
    /// same way.
    @State private var openWord: FoundWord?

    private var title: some View {
        HStack(spacing: 8) {
            RarityMark(category: rung)
            Text(name)
                .font(CuteFont.display(22, relativeTo: .title3))
                .foregroundStyle(Cute.ink)
        }
    }

    private var tally: some View {
        Text(counted(words.count, "word"))
            .font(CuteFont.body(14, relativeTo: .footnote))
            .foregroundStyle(Cute.inkFaint)
            .monospacedDigit()
    }

    @ViewBuilder
    private var header: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 4) { title; tally }
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(spacing: 8) { title; Spacer(minLength: 8); tally }
        }
    }

    var body: some View {
        ZStack {
            Cute.pageBackground.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // The header stacks at accessibility sizes rather than being
                // squeezed. Side by side it truncated to "Myt..." and "3
                // wor...", and a title trailing off mid-word reads as broken
                // in exactly the way the tier caption did.
                header
                    .padding(.horizontal, 24)
                .padding(.top, 26)
                .padding(.bottom, 14)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(name), \(counted(words.count, "word")) found")

                ScrollView {
                    // The same chip the found list uses, so a word cannot carry
                    // one mark here and another there. Alphabetical, because a
                    // list read for its own sake wants to be findable rather
                    // than chronological.
                    // Tappable, which they were not. The chip already carries
                    // the tap target and the press style; it was simply handed
                    // no action here, so a word she could see was a word she
                    // could not ask about.
                    FlowLayout {
                        ForEach(words) { word in
                            WordChip(found: word) { openWord = word }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollBounceBehavior(.basedOnSize)

                Button(action: onDismiss) {
                    Text("Back to the \(Vocabulary.container)")
                        .font(CuteFont.body(15, weight: "SemiBold", relativeTo: .subheadline))
                        .tracking(2.1)
                        .textCase(.uppercase)
                        .foregroundStyle(Cute.paper)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 52)
                        .background(Capsule().fill(Cute.accent))
                }
                .buttonStyle(PillPressStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .accessibilityElement(children: .contain)
        #if DEBUG
        // `-openRungWord 1` opens the first word's definition without a tap,
        // so the nested sheet can be screenshotted. Same reasoning as
        // `-openRung` above it.
        //
        // **Delayed, and the delay is the point.** Setting this straight from
        // `onAppear` presents the second sheet while the first is still
        // presenting, and the result is not what a tap produces: the rung sheet
        // does not end up underneath. That is the launch race this codebase has
        // hit before, recreated by the instrument meant to observe it, and it
        // made a screenshot that looked like a defect in the feature. A tap
        // cannot arrive before the sheet it is aimed at has settled, so the
        // hook waits and models the thing it is standing in for.
        .onAppear {
            guard UserDefaults.standard.bool(forKey: "openRungWord") else { return }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(600))
                openWord = words.first
            }
        }
        #endif
        .sheet(item: $openWord) { word in
            // The same construction the found-list chip reaches, and the only
            // one: see `DefinitionSheet`.
            DefinitionSheet(
                word: word.word,
                category: word.category,
                definition: definitions[word.word]
            ) { openWord = nil }
        }
    }
}

#Preview("Rung sheet") {
    Color.clear.sheet(isPresented: .constant(true)) {
        RungSheet(
            rung: .rare,
            name: "Rare",
            words: ["amor", "arty", "tryma", "moray", "matron"].map {
                FoundWord(word: $0, category: .rare, score: 5)
            }
        ) {}
        .presentationDetents([.medium, .large])
    }
}
