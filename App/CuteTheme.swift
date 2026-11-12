import SwiftUI
import UIKit

/// The cute theme, read from the web repo's `src/index.css` custom properties
/// under `[data-theme='cute']` and expressed in SwiftUI rather than ported as
/// CSS.
///
/// **Every colour has a dark value, Cocoa, since the dark mode build.** The
/// game follows the phone, or the player's choice in Settings
/// (`AppearanceSetting`). Cocoa is the light theme's own ink turned into the
/// night, measured in the vault's `reports/2026-11-11 Dark Mode.md`.
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
    static let paper = Color(light: 0xFFF4EE, dark: 0x2B1A14)
    static let paperDeep = Color(light: 0xFFFFFF, dark: 0x3B2720)
    static let paperEdge = Color(light: 0xFFD9C8, dark: 0x5A3D31)
    static let rule = Color(light: 0xFFE0D2, dark: 0x4A3229, darkHigh: 0x7A5747)

    // Ink
    static let ink = Color(light: 0x6B4636, dark: 0xFFEADF, darkHigh: 0xFFF6F0)       // warm cocoa, 6.9:1 on the bg
    static let inkSoft = Color(light: 0x6F5142, dark: 0xF0CFBF, darkHigh: 0xFBE3D7)   // 6:1
    static let inkFaint = Color(light: 0x7E5C4A, dark: 0xD9B3A1, darkHigh: 0xF1D1C2)  // 5:1

    // Accents
    static let accent = Color(light: 0xC42E60, dark: 0xFF8BAE, darkHigh: 0xFFA9C3)      // candy pink
    static let accentDeep = Color(light: 0xA8264F, dark: 0xFF6F99, darkHigh: 0xFF93B4)
    static let crown = Color(light: 0xFF9E58, dark: 0xFF9E58)       // peach
    static let discovery = Color(light: 0x6E4FB8, dark: 0xC4B0FF, darkHigh: 0xD6C8FF)   // the rarity ladder purple

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
    static let crownDeep = Color(light: 0xA0531A, dark: 0xFFB47E, darkHigh: 0xFFC79C)   // source-word text, 4.7:1

    /// A finished day on the calendar: the pink at 0.32 over the paper, held as
    /// a solid.
    ///
    /// As a 0.32 wash it took its colour from whatever was behind it. Past days
    /// draws it over flat paper, but the title's week strip draws it over the
    /// page's gradient, and at the foot `ink` on it fell to 4.33:1. Solid, it is
    /// the colour Past days always rendered, and `ink` reads on it at 4.68:1
    /// wherever the cell sits (`LightContrastTests`). Dark's is the same blend,
    /// Cocoa's pink over Cocoa's page, and Increase Contrast's its own pink's.
    static let finishedDay = Color(light: 0xECB5C1, dark: 0x6F3E45, darkHigh: 0x6F484C)

    /// The big pink buttons' fill: Play, Pick word, and the way out of every
    /// card and sheet. The pink today, but its own token: on a dark page these
    /// are the brightest thing on screen, and if they glare first thing in the
    /// morning they tone down here, in one place, without moving the pink in
    /// text, the heart or the meter. `AppearanceContrastTests` holds every
    /// button to it.
    static let button = Color(light: 0xC42E60, dark: 0xFF8BAE, darkHigh: 0xFFA9C3)

    // Tiles
    static let tileFace = Color(light: 0xFFFFFF, dark: 0x3B2720)
    static let tileEdge = Color(light: 0xFFD9C8, dark: 0x5A3D31, darkHigh: 0xA27A68)
    static let surfaceShadow = Color(light: 0xFFC9B4, dark: 0x150C08)

    /// `--page-bg: linear-gradient(180deg, #fff4ee, #ffe6dc)`
    /// The foot of the page gradient, for anything pinned to the bottom edge
    /// that must sit on the page rather than on a band of its own.
    static let pageFoot = Color(light: 0xFFE6DC, dark: 0x22140F)

    static let pageBackground = LinearGradient(
        colors: [paper, pageFoot],
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
    /// A colour in each appearance: light, dark, and dark with Increase
    /// Contrast on, which is `dark` unless the dark mode report measured a
    /// reason to move it.
    ///
    /// **Resolved by UIKit, per view, from its traits,** so a sheet, the Safari
    /// page and the status bar all follow the same appearance the page does,
    /// and nothing holds a colour from before the appearance changed. Light has
    /// no Increase Contrast value of its own: the light theme already reads at
    /// 4.5:1 everywhere, and its Increase Contrast pass is a later one.
    ///
    /// Written as literals in this one form so `AppearanceContrastTests` can
    /// read every value from the source, as the web's `indexCss.test.ts`
    /// reads its stylesheet. The values are the dark mode report's Cocoa,
    /// from its `palettes.json`, not picked here.
    init(light: UInt32, dark: UInt32, darkHigh: UInt32? = nil) {
        self.init(uiColor: UIColor { traits in
            let hex: UInt32
            if traits.userInterfaceStyle == .dark {
                hex = traits.accessibilityContrast == .high ? (darkHigh ?? dark) : dark
            } else {
                hex = light
            }
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }

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
