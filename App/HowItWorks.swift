import SwiftUI

/// The quiet explainer reachable from the colophon.
///
/// How a puzzle is built, the two word lists doing different jobs, and an
/// honest note on why a word can feel common and still land outside the
/// basket. Ported from the web's `HowItWorks.tsx`; the copy lives in
/// `Vocabulary` and the reasoning for what was substituted is there.
///
/// **A sheet, not an overlay.** The web uses a modal dialog with a focus trap,
/// which is the web's answer to the same problem. This app already presents
/// three sheets and drag to dismiss is what a phone offers for free, so this
/// matches the idiom rather than the markup.
///
/// **Large only.** Same finding as `SourceRevealCard`: the medium detent is
/// about 437pt and this is seven paragraphs of prose, so medium would open on a
/// fragment of it every time.
struct HowItWorks: View {
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Cute.pageBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(Vocabulary.explainerTitle)
                            .font(CuteFont.display(24, relativeTo: .title2))
                            .foregroundStyle(Cute.ink)
                            .padding(.bottom, 2)

                        ForEach(Array(Vocabulary.explainerParagraphs.enumerated()),
                                id: \.offset) { _, paragraph in
                            Text(paragraph)
                                .font(CuteFont.body(15, relativeTo: .subheadline))
                                .foregroundStyle(Cute.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        // The two lists, as links rather than as prose links.
                        //
                        // The web makes ENABLE and SCOWL inline anchors inside
                        // the second paragraph. Doing that here would mean an
                        // AttributedString with tap targets a few characters
                        // wide, well under the 44pt minimum, inside body text
                        // that already wraps. A labelled pair under the prose
                        // is the same two destinations at a size a thumb can
                        // hit, and it keeps the paragraph readable as a
                        // sentence.
                        //
                        // **A `Link`, so the page opens in the browser, not in
                        // this app.** These were an in-app Safari view until
                        // 2026-09-26, which meant a tap here made the app load a
                        // third party's page itself: the one network request it
                        // ever made. Handing the URL to the system means the app
                        // makes none, which is what the privacy page and the App
                        // Store label say. Coming back is the system's back
                        // gesture rather than a Done button, the price of that.
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Vocabulary.explainerLinks, id: \.name) { link in
                                if let url = URL(string: link.url) {
                                    Link(destination: url) {
                                        HStack(spacing: 6) {
                                            Text("Read about \(link.name)")
                                                .font(CuteFont.body(15, weight: "SemiBold",
                                                                    relativeTo: .subheadline))
                                            Image(systemName: "arrow.up.right")
                                                .font(.footnote)
                                        }
                                        .foregroundStyle(Cute.accent)
                                        .frame(minHeight: 44, alignment: .leading)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 32)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollBounceBehavior(.basedOnSize)

                // Pinned, for the reason `SourceRevealCard` records: this is
                // longer than the phone at any text size, so a way out at the
                // foot of the prose is a way out below the fold.
                Button(action: onDismiss) {
                    Text("Close")
                        .font(CuteFont.body(15, weight: "SemiBold", relativeTo: .subheadline))
                        .tracking(2.1)
                        .textCase(.uppercase)
                        .foregroundStyle(Cute.paper)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 52)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Cute.accent))
                }
                .buttonStyle(PillPressStyle())
                .padding(.horizontal, 28)
                .padding(.top, 12)
                .padding(.bottom, 20)
                .background(Cute.pageBackground)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

// Named for the type rather than for the heading. Spelling the heading out
// here duplicates `Vocabulary.explainerTitle`, which is what
// `AppVocabularyTests` is for and what it caught.
#Preview("Explainer") {
    Color.clear.sheet(isPresented: .constant(true)) {
        HowItWorks {}
            .presentationDetents([.large])
    }
}
