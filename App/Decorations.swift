import SwiftUI

/// Cute motifs for the app's two regions with slack in them.
///
/// Ported from the web's `Decorations.tsx`, which floats peaches, a dinosaur
/// and sparkles in the page margins. The app has no margins to float anything
/// in, so this is the two places that do have room: the colophon at the foot of
/// the scrolling list, and the empty found list before the first word lands.
/// Nothing goes on the play surface, where 62pt of chrome was a project and the
/// SE at XXL already sits on the `minimumListHeight` floor.
///
/// **The motif is not the web's, and that is deliberate.** The web decorates
/// with `✦`, U+2726, which is the exact glyph its own Rare mark uses, so its
/// decoration dilutes a mark that carries meaning.
///
/// Every mark in this app is spoken for, in shape and in colour:
///
///   `♥` U+2665  set        the accent pink
///   `★` U+2605  Uncommon   the discovery purple
///   `✦` U+2726  Rare       the discovery purple
///   `❖` U+2756  Mythic     the discovery purple
///   `PeachMark` source     peach orange with a mint leaf
///
/// So a star of any number of points is out: pointed and filled is what all
/// three off-page rungs look like at a glance, and eight points rather than
/// four or five is not a difference a player should have to notice. This uses
/// `✿` U+273F, a florette. Round and soft where every mark is pointed, which is
/// the test: nobody glancing at a screen carrying both mistakes a flower for a
/// rung.
///
/// **The colour had to move too.** The first version drew stars in `Cute.crown`,
/// which is the peach's own orange, so decoration would have read as small
/// source marks. Green is the one hue no mark uses, and this is the mint of
/// `PeachMark`'s leaf, so the two motifs read as belonging to each other
/// without the decoration borrowing the peach's meaning.
///
/// **Drawn in a background, never in the layout.** Every use is
/// `.background`, which does not influence the size of the thing it sits
/// behind, so no decoration can move a single point of furniture. That is a
/// stronger guarantee than measuring afterwards and finding it did not:
/// `LayoutBudget` measures the rack against the height of the scrolling list,
/// and the empty-list decoration disappears the moment the first word lands,
/// which is precisely the shove `FirstFindShove` exists to catch.
///
/// No animation. The web twinkles these; nothing here does.
enum Deco {
    /// The decorative motif. See the note above for why it is neither the
    /// web's glyph nor any kind of star.
    static let florette = "\u{273F}"

    /// `PeachMark`'s leaf, which is the only green in the app and belongs to no
    /// mark. Kept here rather than in `Cute` because it is a decoration colour:
    /// putting it in the palette would invite it onto something that means
    /// something.
    static let leaf = Color(hex: 0x8FD3B6)
}

/// A single faint florette, sized and placed by the caller.
private struct Bloom: View {
    var size: CGFloat
    var opacity: Double

    var body: some View {
        Text(Deco.florette)
            .font(.system(size: size))
            .foregroundStyle(Deco.leaf)
            .opacity(opacity)
    }
}

/// The colophon's decoration: one peach and a scatter of florettes.
///
/// One peach, reusing `PeachMark` rather than drawing a second one. A peach
/// that differs slightly from the app's peach is worse than no peach, and this
/// is the same reasoning that put the reveal card's mark and the found list's
/// source mark on the same shape.
///
/// Placed to the sides. The colophon's text block is narrower than the full
/// width it is centred in, so there is room at the edges that costs nothing,
/// and nothing is drawn behind the words.
struct ColophonDecoration: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Inside the left margin, and measured rather than eyeballed:
                // the credits block is centred and about 300pt wide in a 402pt
                // colophon, so its leading edge is near 52pt. A 26pt peach
                // centred at 0.06 spans roughly 12 to 38pt and clears the text.
                // The first attempt put a 34pt peach at 0.11 and it sat on the
                // word "Set".
                PeachMark()
                    .frame(width: 26, height: 26)
                    .opacity(0.55)
                    .position(x: geo.size.width * 0.06, y: geo.size.height * 0.30)

                Bloom(size: 14, opacity: 0.75)
                    .position(x: geo.size.width * 0.94, y: geo.size.height * 0.22)
                Bloom(size: 10, opacity: 0.6)
                    .position(x: geo.size.width * 0.88, y: geo.size.height * 0.52)
                Bloom(size: 9, opacity: 0.55)
                    .position(x: geo.size.width * 0.05, y: geo.size.height * 0.72)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The empty found list's decoration: florettes around the line that says the
/// basket is empty.
///
/// This is the screen Bea sees first every morning, and until now it was one
/// sentence alone in the region. No peach here: the peach means the source word
/// everywhere else in the app, and putting one on an empty board would promise
/// something the board has not given yet.
struct EmptyBasketDecoration: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // All of them below the line, not beside it. The sentence is
                // centred and runs nearly the full width, so there is no clear
                // horizontal space at its own height: the first attempt put a
                // florette on the word "No". The slack in this region is
                // underneath, which is where these go.
                // In the lower part of the frame, which is the gap under the
                // sentence. Not beside it: the sentence is centred and runs
                // nearly the full width, so there is no clear space at its own
                // height, and an early attempt put a florette on the word "No".
                Bloom(size: 15, opacity: 0.7)
                    .position(x: geo.size.width * 0.13, y: geo.size.height * 0.66)
                Bloom(size: 10, opacity: 0.5)
                    .position(x: geo.size.width * 0.29, y: geo.size.height * 0.92)
                Bloom(size: 13, opacity: 0.62)
                    .position(x: geo.size.width * 0.87, y: geo.size.height * 0.62)
                Bloom(size: 9, opacity: 0.45)
                    .position(x: geo.size.width * 0.71, y: geo.size.height * 0.9)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
