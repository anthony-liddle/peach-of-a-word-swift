import SwiftUI

/// The cute theme, read from the web repo's `src/index.css` custom properties
/// under `[data-theme='cute']` and expressed in SwiftUI rather than ported as
/// CSS.
///
/// The hex values are copied exactly. The shapes and shadows are copied in
/// spirit: a hard offset shadow with no blur, which is what
/// `0 5px 0 var(--surface-shadow)` produces, reads as the same soft-bubble look
/// once the radius is right.
///
/// Fonts are owed. The web uses Fredoka for display and Nunito for body. This
/// uses the system font with `.rounded` design, which is close enough in shape
/// to read as the same game and costs nothing. Bundling the real faces is a
/// later pass.
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
    /// The hard offset shadow the cute theme uses everywhere: no blur, straight
    /// down. CSS writes it `0 5px 0 <colour>`; SwiftUI needs `radius: 0`.
    func cuteDropShadow(_ color: Color = Cute.surfaceShadow, y: CGFloat = 5) -> some View {
        shadow(color: color, radius: 0, x: 0, y: y)
    }
}
