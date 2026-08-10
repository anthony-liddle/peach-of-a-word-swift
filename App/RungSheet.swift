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
    let onDismiss: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
                    FlowLayout {
                        ForEach(words) { WordChip(found: $0) }
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
