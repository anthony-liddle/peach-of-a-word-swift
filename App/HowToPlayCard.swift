import SwiftUI

/// How to play, one card: four lines in the game's own words.
///
/// **On a first launch after installing, Play opens it**, and its button,
/// "Pick the peaches", goes on to the board: the splash's invitation, kept for
/// the moment it is an invitation. From the title's link, at any time, it ends
/// with Close. A phone that already has progress never sees it unasked, which
/// is every phone updating into this build, Bea's included.
struct HowToPlayCard: View {
    /// First run ends by starting the game; later, it only closes.
    let firstRun: Bool
    let onDone: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ZStack {
            Cute.pageBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(Vocabulary.howToPlayTitle)
                            .font(CuteFont.display(28, relativeTo: .largeTitle))
                            .foregroundStyle(Cute.ink)
                            .accessibilityAddTraits(.isHeader)
                        line(TileGlyph(), Vocabulary.howToPlayPick)
                        line(LadderGlyph(), Vocabulary.howToPlayClimb)
                        line(MarksGlyph(), Vocabulary.howToPlayBasket)
                        line(PeachMark(showsFace: false).frame(width: 22, height: 22),
                             Vocabulary.howToPlayPeach)
                    }
                    .padding(.horizontal, 26)
                    .padding(.vertical, 28)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollBounceBehavior(.basedOnSize)
                SheetCloseButton(title: firstRun ? Vocabulary.mastheadSubline : Vocabulary.close,
                                 identifier: "HowToPlayDone", action: onDone)
            }
        }
    }

    /// One line, with its mark beside it. The mark is decoration; the line is
    /// read whole.
    ///
    /// **At accessibility sizes the mark sits above its line,** as the rung
    /// sheet's header stacks: beside it, the mark's column cost the text a
    /// fifth of an SE's width, and at AX5 a line broke after every two words.
    private func line(_ glyph: some View, _ text: String) -> some View {
        let stacked = dynamicTypeSize.isAccessibilitySize
        let layout = stacked ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 14))
        return layout {
            glyph
                .frame(width: 34, alignment: stacked ? .leading : .center)
                .accessibilityHidden(true)
            Text(text)
                .font(CuteFont.body(17, relativeTo: .body))
                .foregroundStyle(Cute.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Whether How to play has been shown on this phone.
///
/// **Judged at the tap on Play, from the store,** not at launch: a phone with
/// any stored day, outcome or streak has played, and never sees the card
/// unasked. Seen once, it is never shown unasked again.
enum HowToPlayFirstRun {
    static let key = "howToPlaySeen"

    static var seen: Bool { UserDefaults.standard.bool(forKey: key) }

    static func markSeen() { UserDefaults.standard.set(true, forKey: key) }
}

/// A tile, small, with a letter on it.
private struct TileGlyph: View {
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
        Text("a")
            .font(.custom("Fredoka-SemiBold", fixedSize: 15))
            .foregroundStyle(Cute.ink)
            .frame(width: 22, height: 28)
            .background(shape.fill(Cute.tileFace))
            .overlay(shape.stroke(Cute.tileEdge, lineWidth: 1))
    }
}

/// The ladder, as rising bars in the accent.
private struct LadderGlyph: View {
    var body: some View {
        Image(systemName: "chart.bar.fill")
            .font(.system(size: 20))
            .foregroundStyle(Cute.accent)
    }
}

/// The basket's heart over two of the rarer marks.
private struct MarksGlyph: View {
    var body: some View {
        VStack(spacing: 0) {
            RarityMark(category: .set)
            HStack(spacing: 1) {
                RarityMark(category: .rare)
                RarityMark(category: .mythic)
            }
        }
    }
}
