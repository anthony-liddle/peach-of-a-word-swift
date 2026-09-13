import SwiftUI
import UIKit

/// The cute theme, read from the web repo's `src/index.css` custom properties
/// under `[data-theme='cute']` and expressed in SwiftUI rather than ported as
/// CSS.
///
/// The hex values are copied exactly. The shapes and shadows are copied in
/// spirit: a hard offset shadow with no blur, which is what
/// `0 5px 0 var(--surface-shadow)` produces, reads as the same soft-bubble look
/// once the radius is right.
///
/// Fonts are the real thing: Fredoka for display and Nunito for body, both
/// bundled from the Google Fonts repository under the OFL. See `CuteFont`.
enum Cute {
    // Surfaces
    static let paper = Color(hex: 0xFFF4EE)
    static let paperDeep = Color(hex: 0xFFFFFF)
    static let paperEdge = Color(hex: 0xFFD9C8)
    static let rule = Color(hex: 0xFFE0D2)

    // Ink
    static let ink = Color(hex: 0x6B4636)       // warm cocoa, 6.9:1 on the bg
    static let inkSoft = Color(hex: 0x6F5142)   // 6:1
    static let inkFaint = Color(hex: 0x7E5C4A)  // 5:1

    // Accents
    static let accent = Color(hex: 0xC42E60)      // candy pink
    static let accentDeep = Color(hex: 0xA8264F)
    static let crown = Color(hex: 0xFF9E58)       // peach
    static let discovery = Color(hex: 0x6E4FB8)   // the rarity ladder purple

    /// The source word as *text*, which is not the same value as the peach.
    ///
    /// `crown` above is a fill: it sits behind or inside a drawn mark, where a
    /// light peach is the point. Setting words in it would land around 2:1 on
    /// this background and fail AA outright. The web hit this first and keeps a
    /// separate `--crown-deep` (`#a0531a`, 4.7:1) for exactly this job, so this
    /// is that value rather than a new guess.
    ///
    /// The distinction is invisible in a screenshot and obvious in a
    /// stylesheet, which is why matching the web by eye would have shipped the
    /// fill.
    static let crownDeep = Color(hex: 0xA0531A)   // source-word text, 4.7:1

    // Tiles
    static let tileFace = Color(hex: 0xFFFFFF)
    static let tileEdge = Color(hex: 0xFFD9C8)
    static let surfaceShadow = Color(hex: 0xFFC9B4)

    /// `--page-bg: linear-gradient(180deg, #fff4ee, #ffe6dc)`
    static let pageBackground = LinearGradient(
        colors: [Color(hex: 0xFFF4EE), Color(hex: 0xFFE6DC)],
        startPoint: .top,
        endPoint: .bottom
    )

    // Shapes
    static let tileRadius: CGFloat = 18
    static let cardRadius: CGFloat = 22

    /// Apple's minimum tap target, which is also the number the web version
    /// settled on independently.
    static let minTapTarget: CGFloat = 44
}

/// The two bundled faces, matching `--font-display` and `--font-body`.
///
/// Both are variable fonts from the Google Fonts repository, under the OFL
/// (licences sit beside them in App/Fonts). `Font.custom` looks them up by the
/// PostScript name of a named instance, which is why these are spelled
/// "Fredoka-SemiBold" rather than "Fredoka" plus a weight.
///
/// `relativeTo:` is what keeps Dynamic Type working with a custom face. Without
/// it a custom font is a fixed size and stops scaling entirely.
enum CuteFont {
    /// Fredoka SemiBold. The wordmark, the tiles, the letters on the stick.
    static func display(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("Fredoka-SemiBold", size: size, relativeTo: style)
    }

    /// Fredoka SemiBold, sheared into a synthetic oblique.
    ///
    /// The web renders "Peach" in italic Fredoka, but Fredoka has no italic
    /// face: the browser fakes one by slanting the upright. SwiftUI will not do
    /// that. Both `Text.italic()` and `Font.italic()` were tried and neither
    /// changed a glyph, because a custom font with no italic face simply has no
    /// italic to select.
    ///
    /// So the shear is applied by hand through CoreText, which is the same
    /// thing the browser does. The cost is that a `CTFont`-backed `Font` carries
    /// no `relativeTo:`, so Dynamic Type has to be applied to the point size
    /// manually with `UIFontMetrics`.
    static func displayOblique(
        _ size: CGFloat,
        relativeTo style: UIFont.TextStyle = .largeTitle
    ) -> Font {
        let scaled = UIFontMetrics(forTextStyle: style).scaledValue(for: size)
        // c is the horizontal shear term. 0.18 is close to the ~11 degree slant
        // browsers use for synthetic obliques.
        var shear = CGAffineTransform(a: 1, b: 0, c: 0.18, d: 1, tx: 0, ty: 0)
        let upright = CTFontCreateWithName("Fredoka-SemiBold" as CFString, scaled, nil)
        return Font(CTFontCreateCopyWithAttributes(upright, scaled, &shear, nil))
    }

    /// Nunito, sheared into a synthetic oblique.
    ///
    /// The same problem `displayOblique` solves, one family over, and it has to
    /// be solved twice because the shear names a face. The bundled Nunito ships
    /// eight named instances, Black through ExtraLight, and not one of them is
    /// italic: `CTFontGetSymbolicTraits` reports no italic trait on any of
    /// them. So `.italic()` selects nothing and renders the upright, silently,
    /// which is the failure mode worth naming because it does not look like a
    /// failure. It looks like a design that chose not to be italic.
    ///
    /// The web's dedication is italic, so matching it needs the browser's own
    /// trick: slant the upright by hand. Same 0.18 shear as the display face,
    /// and the same cost, that a `CTFont`-backed `Font` carries no
    /// `relativeTo:` and Dynamic Type has to be applied to the point size with
    /// `UIFontMetrics` instead.
    static func bodyOblique(
        _ size: CGFloat,
        weight: String = "Regular",
        relativeTo style: UIFont.TextStyle = .body
    ) -> Font {
        let scaled = UIFontMetrics(forTextStyle: style).scaledValue(for: size)
        var shear = CGAffineTransform(a: 1, b: 0, c: 0.18, d: 1, tx: 0, ty: 0)
        let upright = CTFontCreateWithName("Nunito-\(weight)" as CFString, scaled, nil)
        return Font(CTFontCreateCopyWithAttributes(upright, scaled, &shear, nil))
    }

    /// Nunito. Everything else.
    static func body(
        _ size: CGFloat,
        weight: String = "Regular",
        relativeTo style: Font.TextStyle = .body
    ) -> Font {
        .custom("Nunito-\(weight)", size: size, relativeTo: style)
    }
}

extension Color {
    /// Build a Color from a 24-bit RGB literal, so the CSS hex values can be
    /// copied across unchanged and stay greppable against `src/index.css`.
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

extension View {
    /// The hard offset shadow the cute theme uses everywhere.
    ///
    /// CSS writes `box-shadow: 0 5px 0 <colour>`, which is a flat slab of colour
    /// sitting directly beneath the shape with no blur and no spread. SwiftUI's
    /// `.shadow()` always blurs, and `radius: 0` gets closer but still renders a
    /// soft edge and tints through translucency. The faithful version is an
    /// offset copy of the same shape drawn behind, which is what this does.
    func cuteSlab(_ shape: some Shape, color: Color, y: CGFloat) -> some View {
        background(shape.fill(color).offset(y: y))
    }
}
